--!strict
-- Authoritative building: validates EVERY request (owner, item ownership, bounds, overlap, limit), keeps the
-- serialisable object list in the profile, and mirrors it as models in the owner's plot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Balance = require(ReplicatedStorage.Configs.Balance)
local Progression = require(ReplicatedStorage.Configs.Progression)
local Obstacles = require(ReplicatedStorage.Configs.Obstacles)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local PlotMath = require(ReplicatedStorage.Shared.PlotMath)
local ObstacleModels = require(ReplicatedStorage.Shared.ObstacleModels)

local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateSync = require(script.Parent.StateSync)
local SessionService = require(script.Parent.SessionService)
local Runtime = require(script.Parent.Parent.Systems.ObstacleRuntime)

local BuildService = {}
BuildService.Changed = Instance.new("BindableEvent")   -- (player, kind) after a successful mutation

local models: { [Player]: { [number]: Model } } = {}
local rebuilding: { [Player]: boolean } = {}

function BuildService.IsRebuilding(player: Player): boolean
	return rebuilding[player] == true
end

local function placedCount(profile: any, id: string, ignore: number?): number
	local n = 0
	for _, o in profile.plot.objects do if o.id == id and o.u ~= ignore then n += 1 end end
	return n
end

local function available(profile: any, def: any): number
	if def.free then
		if def.unique then return 1 - placedCount(profile, def.id) end
		return math.huge
	end
	return (profile.inv[def.id] or 0) - placedCount(profile, def.id)
end

local function entryBox(o: any): PlotMath.Box?
	local d = Obstacles.ById[o.id]
	return d and PlotMath.box(d.size, o.x, o.y, o.z, o.r) or nil
end

-- returns ok, errCode, x, y, z, r (normalised)
local function validate(profile: any, def: any, x: any, y: any, z: any, r: any, ignoreUid: number?): (boolean, string?, number, number, number, number)
	if not (Net.isNum(x, -2000, 2000) and Net.isNum(y, -10, 200) and Net.isNum(z, -2000, 2000) and Net.isNum(r)) then
		return false, "Invalid", 0, 0, 0, 0
	end
	if y < -1 or y > Balance.MaxBuildHeight + 1 then return false, "OutOfBounds", 0, 0, 0, 0 end   -- reject, never clamp silently
	local nx, nz = Util.snap(x, 0.5), Util.snap(z, 0.5)
	local ny, nr = PlotMath.snapY(y), Util.clampRot(r)
	if def.symmetric then nr = nr % 180 end          -- 180 = 0 for symmetric pieces (entry/exit can't end up swapped)
	local size = Progression.plotSize(profile.rebirth)
	local box = PlotMath.box(def.size, nx, ny, nz, nr)
	if not PlotMath.inZone(box, size.X, size.Y) then return false, "OutOfBounds", nx, ny, nz, nr end
	for _, o in profile.plot.objects do
		if o.u ~= ignoreUid then
			local ob = entryBox(o)
			if ob and PlotMath.overlap(box, ob) then return false, "Overlap", nx, ny, nz, nr end
		end
	end
	return true, nil, nx, ny, nz, nr
end

local function spawnModel(player: Player, plot: any, o: any): Model?
	local m = ObstacleModels.build(o.id)
	if not m then return nil end
	m:SetAttribute("Uid", o.u)
	m:SetAttribute("X", o.x); m:SetAttribute("Y", o.y); m:SetAttribute("Z", o.z); m:SetAttribute("R", o.r)   -- plot-local pose for client previews
	m:SetAttribute("Phase", ((o.x * 7 + o.z * 13 + o.y * 3) % 97) / 97)
	m:PivotTo(PlotMath.cframe(plot.cf, o.x, o.y, o.z, o.r))
	m.Parent = plot.course
	Runtime.Register(m)
	models[player] = models[player] or {}
	models[player][o.u] = m
	return m
end

local function dropModel(player: Player, uid: number)
	local m = models[player] and models[player][uid]
	if m then Runtime.Unregister(m); m:Destroy(); models[player][uid] = nil end
end

local function bump(player: Player, profile: any, kind: string)
	profile.plot.version += 1
	profile.plot.changes += 1
	PlayerDataService.MarkDirty(player)
	StateSync.Push(player)
	BuildService.Changed:Fire(player, kind)
end

function BuildService.Place(player: Player, req: any): any
	if rebuilding[player] then return { ok = false, err = "CourseLoading" } end
	local profile, plot = PlayerDataService.Get(player), PlotService.Get(player)
	if not profile or not plot then return { ok = false, err = "NoPlot" } end
	if type(req) ~= "table" or not Net.isId(req.id) then return { ok = false, err = "Invalid" } end
	local def = Obstacles.ById[req.id]
	if not def then return { ok = false, err = "Unknown" } end
	if def.rebirth > profile.rebirth then return { ok = false, err = "Locked" } end
	if available(profile, def) <= 0 then return { ok = false, err = if def.unique then "AlreadyPlaced" else "NoItem" } end
	if #profile.plot.objects >= Progression.objectLimit(profile.rebirth) then return { ok = false, err = "LimitReached" } end
	local ok, err, x, y, z, r = validate(profile, def, req.x, req.y, req.z, req.r, nil)
	if not ok then return { ok = false, err = err } end
	local uid = profile.plot.nextUid
	profile.plot.nextUid = uid + 1
	local o = { u = uid, id = def.id, x = x, y = y, z = z, r = r }
	table.insert(profile.plot.objects, o)
	spawnModel(player, plot, o)
	bump(player, profile, "place")
	return { ok = true, uid = uid, x = x, y = y, z = z, r = r }
end

local function find(profile: any, uid: any): any?
	if not Net.isInt(uid, 1) then return nil end
	for _, o in profile.plot.objects do if o.u == uid then return o end end
	return nil
end

function BuildService.Move(player: Player, req: any): any
	if rebuilding[player] then return { ok = false, err = "CourseLoading" } end
	local profile, plot = PlayerDataService.Get(player), PlotService.Get(player)
	if not profile or not plot then return { ok = false, err = "NoPlot" } end
	if type(req) ~= "table" then return { ok = false, err = "Invalid" } end
	local o = find(profile, req.uid)
	if not o then return { ok = false, err = "NotFound" } end
	local def = Obstacles.ById[o.id]
	local ok, err, x, y, z, r = validate(profile, def, req.x, req.y, req.z, req.r, o.u)
	if not ok then return { ok = false, err = err } end
	o.x, o.y, o.z, o.r = x, y, z, r
	dropModel(player, o.u)
	spawnModel(player, plot, o)
	bump(player, profile, "move")
	return { ok = true, uid = o.u, x = x, y = y, z = z, r = r }
end

function BuildService.Remove(player: Player, req: any): any
	if rebuilding[player] then return { ok = false, err = "CourseLoading" } end
	local profile = PlayerDataService.Get(player)
	if not profile or not PlotService.Get(player) then return { ok = false, err = "NoPlot" } end
	local uid = if type(req) == "table" then req.uid else nil
	local o = find(profile, uid)
	if not o then return { ok = false, err = "NotFound" } end
	table.remove(profile.plot.objects, table.find(profile.plot.objects, o))
	dropModel(player, o.u)
	bump(player, profile, "remove")
	return { ok = true }
end

function BuildService.SetName(player: Player, req: any): any
	local profile, plot = PlayerDataService.Get(player), PlotService.Get(player)
	if not profile or not plot then return { ok = false, err = "NoPlot" } end
	local name = if type(req) == "table" then req.name else nil
	if not Net.isStr(name, 24) or #(name :: string):gsub("%s", "") < 1 then return { ok = false, err = "Invalid" } end
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(name :: string, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then return { ok = false, err = "Filter" } end
	profile.plot.name = filtered
	PlotService.SetSignInfo(plot, filtered, player.DisplayName, "", "")
	PlayerDataService.MarkDirty(player)
	StateSync.Push(player)
	return { ok = true, name = filtered }
end

function BuildService.Entries(player: Player): { any }
	local p = PlayerDataService.Get(player)
	return if p then p.plot.objects else {}
end
function BuildService.Model(player: Player, uid: number): Model?
	return models[player] and models[player][uid]
end
function BuildService.Available(player: Player, id: string): number
	local p, def = PlayerDataService.Get(player), Obstacles.ById[id]
	return if p and def then available(p, def) else 0
end

-- ===== course save slots (owner reference 1, T41): 3 snapshots of YOUR course. Load re-validates EVERY object against the current
-- profile (owned items, rebirth locks, zone, overlap, object limit); what no longer fits is skipped and reported. Clear returns all to the inventory.
local SAVE_SLOTS = Balance.Build.SaveSlots   -- audit 2.3 (3)
local function savesOf(profile: any): { [string]: any }
	if type(profile.courseSaves) ~= "table" then profile.courseSaves = {} end
	return profile.courseSaves
end
local function saveSummary(profile: any): { any }
	local out = {}
	for i = 1, SAVE_SLOTS do
		local s = savesOf(profile)[tostring(i)]
		out[i] = if s then { n = s.n, t = s.t } else false
	end
	return out
end
local function clearModels(player: Player)
	for _, m in models[player] or {} do Runtime.Unregister(m); m:Destroy() end
	models[player] = {}
end

local function spawnCourse(player: Player, profile: any, plot: any): boolean
	rebuilding[player] = true
	local ok, complete = pcall(function()
		for i, entry in profile.plot.objects do
			spawnModel(player, plot, entry)
			if i % 20 == 0 then
				task.wait()
				if not player.Parent or PlayerDataService.Get(player) ~= profile or PlotService.Get(player) ~= plot then return false end
			end
		end
		return true
	end)
	rebuilding[player] = nil
	if not ok then error(complete) end
	return complete
end

function BuildService.CourseSlots(player: Player, req: any): any
	if rebuilding[player] then return { ok = false, err = "CourseLoading" } end
	local profile, plot = PlayerDataService.Get(player), PlotService.Get(player)
	if not profile or not plot then return { ok = false, err = "NoPlot" } end
	if type(req) ~= "table" then return { ok = false, err = "Invalid" } end
	if req.action == "clear" then
		if #profile.plot.objects == 0 then return { ok = false, err = "Empty" } end
		clearModels(player)
		profile.plot.objects = {}
		bump(player, profile, "clear")
		return { ok = true }
	end
	if not Net.isInt(req.slot, 1, SAVE_SLOTS) then return { ok = false, err = "Invalid" } end
	local key = tostring(req.slot)
	local saves = savesOf(profile)
	if req.action == "save" then
		if #profile.plot.objects == 0 then return { ok = false, err = "Empty" } end
		local copy = {}
		for i, o in profile.plot.objects do copy[i] = { id = o.id, x = o.x, y = o.y, z = o.z, r = o.r } end
		saves[key] = { objects = copy, n = #copy, t = os.time() }
		PlayerDataService.MarkDirty(player)
		StateSync.Push(player)
		return { ok = true, n = #copy }
	elseif req.action == "load" then
		local s = saves[key]
		if type(s) ~= "table" or type(s.objects) ~= "table" then return { ok = false, err = "EmptySlot" } end
		local old = profile.plot.objects
		profile.plot.objects = {}
		local limit = Progression.objectLimit(profile.rebirth)
		local skipped = 0
		for _, o in s.objects do
			local def = if type(o) == "table" and Net.isId(o.id) then Obstacles.ById[o.id] else nil
			local ok, x, y, z, r = false, 0, 0, 0, 0
			if def and def.rebirth <= profile.rebirth and available(profile, def) > 0 and #profile.plot.objects < limit then
				local okV, _e, vx, vy, vz, vr = validate(profile, def, o.x, o.y, o.z, o.r, nil)
				ok, x, y, z, r = okV, vx, vy, vz, vr
			end
			if ok and def then
				local uid = profile.plot.nextUid
				profile.plot.nextUid = uid + 1
				table.insert(profile.plot.objects, { u = uid, id = def.id, x = x, y = y, z = z, r = r })
			else
				skipped += 1
			end
		end
		if #profile.plot.objects == 0 then profile.plot.objects = old; return { ok = false, err = "NothingFits" } end
		clearModels(player)
		if not spawnCourse(player, profile, plot) then return { ok = false, err = "NoPlot" } end
		bump(player, profile, "load")
		return { ok = true, loaded = #profile.plot.objects, skipped = skipped }
	end
	return { ok = false, err = "Invalid" }
end

local function rebuild(player: Player, profile: any, plot: any)
	models[player] = {}
	for _, o in profile.plot.objects do          -- migrate old courses: symmetric pieces stored at 180/270 become 0/90 (same look, correct direction)
		local d = Obstacles.ById[o.id]
		if d and d.symmetric and type(o.r) == "number" and o.r >= 180 then o.r -= 180; profile.plot.version += 1; PlayerDataService.MarkDirty(player) end
	end
	if spawnCourse(player, profile, plot) then StateSync.Push(player) end
end

function BuildService.Start()
	StateSync.Provider("plot", function(player: Player)
		local p = PlayerDataService.Get(player)
		local size = Progression.plotSize(p.rebirth)
		local placed: { [string]: number } = {}
		for _, o in p.plot.objects do placed[o.id] = (placed[o.id] or 0) + 1 end
		return { count = #p.plot.objects, limit = Progression.objectLimit(p.rebirth), version = p.plot.version,
			name = p.plot.name, width = size.X, length = size.Y, placed = placed,
			cosmeticLimit = Progression.cosmeticLimit(p.rebirth), saves = saveSummary(p) }
	end)
	SessionService.Ready.Event:Connect(function(player: Player, profile: any, plot: any)
		task.spawn(rebuild, player, profile, plot)
	end)
	SessionService.Leaving.Event:Connect(function(player: Player)
		for _, m in models[player] or {} do Runtime.Unregister(m) end
		models[player] = nil
	end)
	Net.handle("BuildPlace", Balance.RateLimits.Build, BuildService.Place)
	Net.handle("BuildMove", Balance.RateLimits.Build, BuildService.Move)
	Net.handle("BuildRemove", Balance.RateLimits.Build, BuildService.Remove)
	Net.handle("SetCourseName", Balance.RateLimits.CourseName, BuildService.SetName)
	Net.handle("CourseSlots", Balance.RateLimits.CourseSlots, BuildService.CourseSlots)
end

return BuildService
