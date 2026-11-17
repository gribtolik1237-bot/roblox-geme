--!strict
-- Drives every placed obstacle with ONE Heartbeat. Motion is a pure function of server time (D-005), so the
-- NPC brain can predict hazards with PoseAt(). Hazard contacts are published through HazardTouched.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Obstacles = require(ReplicatedStorage.Configs.Obstacles)
local Net = require(ReplicatedStorage.Shared.Net)
local Behaviors = require(script.Parent.Behaviors)
local V3 = Vector3.new

local Runtime = {}
Runtime.HazardTouched = Instance.new("BindableEvent")   -- (hazardPart, hitPart, kind: "Kill"|"Knock")

type Entry = { model: Model, def: any, base: CFrame, phase: number, conns: { RBXScriptConnection }, state: any }
local active: { [Model]: Entry } = {}
local movers: { Entry } = {}
local hb: RBXScriptConnection? = nil

local function ease(u: number): number return u * u * (3 - 2 * u) end

local function ferryZ(b: any, t: number): number
	local T = 2 * (b.move + b.pause)
	local p = t % T
	local half = b.travel / 2
	if p < b.move then return half - b.travel * ease(p / b.move) end
	if p < b.move + b.pause then return -half end
	if p < 2 * b.move + b.pause then return -half + b.travel * ease((p - b.move - b.pause) / b.move) end
	return half
end
local function spinAngle(b: any, t: number): number return math.rad(b.dps) * t end

local function period(def: any): number
	local b = def.behavior
	if b.kind == "ferry" then return 2 * (b.move + b.pause) end
	if b.kind == "spin" then return 360 / b.dps end
	return 1
end

-- Pose of a moving part of `model` at server time t (used by the AI to predict hazards)
function Runtime.PoseAt(model: Model, t: number): CFrame?
	local e = active[model]
	if not e then return nil end
	local b = e.def.behavior
	local tt = t + e.phase * period(e.def)
	if b.kind == "ferry" then return e.base * CFrame.new(0, 1.05, ferryZ(b, tt)) end
	if b.kind == "spin" then return e.base * CFrame.Angles(0, spinAngle(b, tt), 0) * CFrame.new(0, 3.1, 0) end
	return nil
end
function Runtime.Get(model: Model): Entry? return active[model] end
function Runtime.Hazards(model: Model): { any }? local e = active[model]; return e and e.hazards end
function Runtime.Vanish(model: Model): any? local e = active[model]; return e and e.vanish end

local function charOf(hit: BasePart): (Model?, Humanoid?)
	local m = hit:FindFirstAncestorOfClass("Model")
	local h = m and m:FindFirstChildOfClass("Humanoid")
	return m, h
end

local poll: RBXScriptConnection? = nil
local debounce: { [Model]: number } = {}
local overlap = OverlapParams.new()
overlap.MaxParts = 40
local function pollHazards()
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for _, e in active do
		if e.hazards then
			for _, h in e.hazards do
				if not h.active or h.active(now) then
					for _, part in workspace:GetPartBoundsInBox(h.pose(now), h.size, overlap) do
						local char = part:FindFirstAncestorOfClass("Model")
						if char and char:FindFirstChildOfClass("Humanoid") and char ~= e.model then
							if not debounce[char] or clock - debounce[char] > 0.3 then
								debounce[char] = clock
								Runtime.HazardTouched:Fire(h.ref or e.model.PrimaryPart, part, h.kind)
							end
						end
					end
				end
			end
		end
	end
end

local lastStep = 0
local function stepMovers()
	local now = workspace:GetServerTimeNow()
	local dt = os.clock() - lastStep
	lastStep = os.clock()
	for _, e in movers do
		local b = e.def.behavior
		local st = e.state
		if e.update then e.update(e, now, dt) continue end
		if b.kind == "ferry" then
			local pose = Runtime.PoseAt(e.model, now)
			local nxt = Runtime.PoseAt(e.model, now + 0.05)
			if pose and nxt then
				st.fm:PivotTo(pose)
				st.ferry.AssemblyLinearVelocity = (nxt.Position - pose.Position) / 0.05
			end
		elseif b.kind == "spin" then
			local pose = Runtime.PoseAt(e.model, now)
			if pose then st.bar:PivotTo(pose) end
		elseif b.kind == "falling" then
			local tm: Model, tile: Part = st.tm, st.tile
			if st.mode == "shake" then
				local el = os.clock() - st.t0
				if el >= b.delay then st.mode = "fall"; st.t0 = os.clock(); tile.CanCollide = false; tile.CanQuery = false
				else tm:PivotTo(st.home * CFrame.new((math.random() - 0.5) * 0.25, 0, (math.random() - 0.5) * 0.25)) end
			elseif st.mode == "fall" then
				local el = os.clock() - st.t0
				tm:PivotTo(st.home * CFrame.new(0, -el * el * 60, 0))
				if el > 0.7 then for _, p in tm:GetDescendants() do if p:IsA("BasePart") then p.Transparency = 1 end end; st.mode = "gone"; st.t0 = os.clock() end
			elseif st.mode == "gone" then
				if os.clock() - st.t0 >= b.respawn then
					tm:PivotTo(st.home)
					for p, tr in st.orig do p.Transparency = tr end
					tile.CanCollide = true; tile.CanQuery = true; st.mode = "idle"
				end
			end
		end
	end
end

local function setupBoost(e: Entry, deck: Part, boost: number)
	local inside: { [Humanoid]: number } = {}
	table.insert(e.conns, deck.Touched:Connect(function(hit)
		local _, hum = charOf(hit)
		if not hum or hum.Health <= 0 then return end
		if not inside[hum] then
			if hum:GetAttribute("BaseSpeed") == nil then hum:SetAttribute("BaseSpeed", hum.WalkSpeed) end
			hum.WalkSpeed = math.max(hum.WalkSpeed, boost)
		end
		inside[hum] = os.clock()
	end))
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not e.model.Parent then conn:Disconnect(); return end
		for hum, t in inside do
			if os.clock() - t > 0.35 then
				inside[hum] = nil
				local base = hum:GetAttribute("BaseSpeed")
				if hum.Parent and base then hum.WalkSpeed = base; hum:SetAttribute("BaseSpeed", nil) end
			end
		end
	end)
	table.insert(e.conns, conn)
end

function Runtime.Register(model: Model, phase: number?)
	local def = Obstacles.ById[model:GetAttribute("ObstacleId") :: string]
	if not def or active[model] then return end
	local e: Entry = { model = model, def = def, base = model:GetPivot(), phase = phase or (model:GetAttribute("Phase") :: number?) or 0, conns = {}, state = {} }
	active[model] = e
	local b = def.behavior
	if b.kind == "ferry" then
		e.state.fm = model:FindFirstChild("FerryModel"); e.state.ferry = (e.state.fm :: Model).PrimaryPart
		table.insert(movers, e)
	elseif b.kind == "spin" then
		e.state.bar = model:FindFirstChild("BarModel")
		e.hazards = { { kind = "Knock", size = V3(b.reach * 2, 1.0, 1.3), jumpable = true, ref = (e.state.bar :: Model).PrimaryPart, pose = function(t) return Runtime.PoseAt(model, t) end } }
		table.insert(movers, e)
	elseif b.kind == "falling" then
		local tm = model:FindFirstChild("TileModel") :: Model
		local orig = {}
		for _, p in tm:GetDescendants() do if p:IsA("BasePart") then orig[p] = p.Transparency end end
		e.state.tm = tm; e.state.tile = tm.PrimaryPart; e.state.home = tm:GetPivot(); e.state.mode = "idle"; e.state.orig = orig
		table.insert(movers, e)
		table.insert(e.conns, (tm.PrimaryPart :: Part).Touched:Connect(function(hit)
			local _, hum = charOf(hit)
			if hum and e.state.mode == "idle" and hum.Health > 0 then e.state.mode = "shake"; e.state.t0 = os.clock() end
		end))
	elseif b.kind == "speed" then
		setupBoost(e, model:FindFirstChild("Deck") :: Part, b.boost)
	elseif b.kind == "teleport" then
		local pad, dest = model:FindFirstChild("Pad") :: Part, model:FindFirstChild("Dest") :: Part
		local busy: { [Model]: boolean } = {}
		table.insert(e.conns, pad.Touched:Connect(function(hit)
			local char, hum = charOf(hit)
			if not char or not hum or hum.Health <= 0 or busy[char] then return end
			local pl = Players:GetPlayerFromCharacter(char)
			if not pl then return end             -- NPCs may never teleport
			busy[char] = true
			Net.fire("Effect", pl, "Teleport", pad.Position)
			task.delay(0.5, function()
				if char.Parent and hum.Health > 0 then
					local pos = dest.Position + Vector3.new(0, 3.2, 0)
					char:SetAttribute("ServerTeleportAt", os.clock())
					char:PivotTo(CFrame.lookAt(pos, pos + e.base.LookVector))
				end
				task.delay(1, function() busy[char] = nil end)
			end)
		end))
	end
	-- hazard contact publishing
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local kind = if d:GetAttribute("Kill") then "Kill" elseif d:GetAttribute("Knock") then "Knock" else nil
			if kind then
				local last: { [Model]: number } = {}
				table.insert(e.conns, d.Touched:Connect(function(hit)
					local char, hum = charOf(hit)
					if not char or not hum then return end
					local now = os.clock()
					if last[char] and now - last[char] < 0.25 then return end
					last[char] = now
					Runtime.HazardTouched:Fire(d, hit, kind)
				end))
			end
		end
	end
	local beh = Behaviors[b.kind]
	if beh then
		e.conns = e.conns or {}
		beh(e, { fire = Net.fire })
		if e.update then table.insert(movers, e) end
	end
	if #movers > 0 and not hb then hb = RunService.Heartbeat:Connect(stepMovers) end
	if not poll then
		local acc = 0
		poll = RunService.Heartbeat:Connect(function(dt) acc += dt; if acc >= 0.1 then acc = 0; pollHazards() end end)
	end
end

function Runtime.Unregister(model: Model)
	local e = active[model]
	if not e then return end
	active[model] = nil
	for _, c in e.conns do c:Disconnect() end
	local i = table.find(movers, e)
	if i then table.remove(movers, i) end
	if #movers == 0 and hb then hb:Disconnect(); hb = nil end
end

function Runtime.Count(): number
	local n = 0
	for _ in active do n += 1 end
	return n
end

return Runtime
