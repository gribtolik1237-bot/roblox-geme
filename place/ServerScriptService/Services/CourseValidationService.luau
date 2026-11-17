--!strict
-- Course analysis (D-006): builds the route graph from entry/exit edges, finds Start -> Finish, derives the stage list,
-- difficulty and two SEPARATE statuses: Player-playable and NPC-playable. It is a heuristic, NOT a guarantee.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Progression = require(ReplicatedStorage.Configs.Progression)
local Obstacles = require(ReplicatedStorage.Configs.Obstacles)
local Net = require(ReplicatedStorage.Shared.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateSync = require(script.Parent.StateSync)
local BuildService = require(script.Parent.BuildService)
local SessionService = require(script.Parent.SessionService)
local RewardMath = require(script.Parent.Parent.Systems.RewardMath)

local V2, V3 = Vector2.new, Vector3.new
local Service = {}
local cache: { [Player]: { version: number, result: any } } = {}

-- 2D segment helpers -----------------------------------------------------------------------------------
local function ptSeg(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local len2 = ab:Dot(ab)
	local t = if len2 < 1e-6 then 0 else math.clamp(ab:Dot(p - a) / len2, 0, 1)
	return (p - (a + ab * t)).Magnitude
end
local function ccw(a: Vector2, b: Vector2, c: Vector2): boolean return (c.Y - a.Y) * (b.X - a.X) > (b.Y - a.Y) * (c.X - a.X) end
local function crosses(a: Vector2, b: Vector2, c: Vector2, d: Vector2): boolean
	return ccw(a, c, d) ~= ccw(b, c, d) and ccw(a, b, c) ~= ccw(a, b, d)
end
local function segDist(a: Vector2, b: Vector2, c: Vector2, d: Vector2): number
	if crosses(a, b, c, d) then return 0 end
	return math.min(ptSeg(a, c, d), ptSeg(b, c, d), ptSeg(c, a, b), ptSeg(d, a, b))
end

type Node = { uid: number, id: string, def: any, o: any, entry: Vector3, exit: Vector3, eA: Vector2, eB: Vector2, xA: Vector2, xB: Vector2, fwd: Vector3 }

local function makeNode(o: any): Node
	local def = Obstacles.ById[o.id]
	local cf = CFrame.new(o.x, o.y, o.z) * CFrame.Angles(0, math.rad(o.r), 0)
	local entry, exit = cf:PointToWorldSpace(def.entry), cf:PointToWorldSpace(def.exit)
	local right = cf.RightVector * (def.size.X / 2 * 0.8)
	local function xz(v: Vector3): Vector2 return V2(v.X, v.Z) end
	return { uid = o.u, id = o.id, def = def, o = o, entry = entry, exit = exit, fwd = cf.LookVector,
		eA = xz(entry - right), eB = xz(entry + right), xA = xz(exit - right), xB = xz(exit + right) }
end

local function linked(a: { exit: Vector3, fwd: Vector3, xA: Vector2, xB: Vector2 }, b: Node): (boolean, number)
	local up = b.entry.Y - a.exit.Y
	if up > Balance.MaxStepUp or -up > Balance.MaxDrop then return false, 0 end
	local gap = segDist(a.xA, a.xB, b.eA, b.eB)
	if gap > Balance.MaxGap then return false, gap end
	if (b.entry - a.exit):Dot(a.fwd) < -1.5 then return false, gap end   -- must lead forward
	return true, gap
end

function Service.Compute(profile: any): any
	local objs = profile.plot.objects
	local W = Progression.plotSize(profile.rebirth).X
	local pw = math.max(W, 64)
	local D = Balance.StartAreaDepth
	local start = { exit = V3(0, Balance.DeckTop, -D), fwd = V3(0, 0, -1), xA = V2(-pw / 2 * 0.9, -D), xB = V2(pw / 2 * 0.9, -D) }
	local nodes: { [number]: Node } = {}
	local list: { Node } = {}
	local finish: Node? = nil
	for _, o in objs do
		if Obstacles.ById[o.id] then
			local n = makeNode(o)
			nodes[o.u] = n; list[#list + 1] = n
			if o.id == "FinishPad" then finish = n end
		end
	end
	local warnings: { string } = {}
	local r: any = { version = profile.plot.version, playerPlayable = false, npcPlayable = false, hasFinish = finish ~= nil, stages = {}, path = {},
		difficulty = "Easy", score = 0, lowQuality = true, warnings = warnings, objectCount = #objs, offPath = 0, incompatible = {}, maxGap = 0, breaks = {} }
	-- BFS Start -> Finish over directed links (also run without a Finish: the reachable part shows where the route breaks)
	local parent: { [number]: number } = {}
	local visited: { [number]: boolean } = {}
	local gapOf: { [number]: number } = {}
	local queue: { number } = {}
	for _, n in list do
		local ok, gap = linked(start, n)
		if ok then visited[n.uid] = true; parent[n.uid] = 0; gapOf[n.uid] = gap; queue[#queue + 1] = n.uid end
	end
	local head = 1
	while head <= #queue do
		local cur = nodes[queue[head]]; head += 1
		if finish and cur.uid == (finish :: Node).uid then break end
		for _, n in list do
			if not visited[n.uid] then
				local ok, gap = linked(cur, n)
				if ok then visited[n.uid] = true; parent[n.uid] = cur.uid; gapOf[n.uid] = gap; queue[#queue + 1] = n.uid end
			end
		end
	end
	if not finish or not visited[(finish :: Node).uid] then
		-- session 8 (owner: show the break IN THE WORLD): the exits of reachable pieces that lead nowhere = where the route stops.
		-- Plot-local points; the client draws a red "Gap" mark there while the hammer is in hand.
		local function add(p: Vector3, kind: string)
			if #r.breaks < 4 then r.breaks[#r.breaks + 1] = { x = p.X, y = p.Y, z = p.Z, kind = kind } end
		end
		local any = false
		for _, n in list do
			if visited[n.uid] and n.id ~= "FinishPad" then
				any = true
				local leads = false
				for _, m in list do
					if m ~= n and (linked(n, m)) then leads = true break end
				end
				if not leads then add(n.exit, "end") end
			end
		end
		if not any then add(V3(0, Balance.DeckTop, -D), "start") end
		if finish then r.finishEntry = { x = finish.entry.X, y = finish.entry.Y, z = finish.entry.Z } end
		if not finish then warnings[#warnings + 1] = "No Finish Pad placed yet"
		else warnings[#warnings + 1] = "No walkable route from the Start to the Finish: check gaps (max " .. Balance.MaxGap .. " studs) and alignment" end
		return r
	end
	-- reconstruct the path
	local path: { number } = {}
	local cur = (finish :: Node).uid
	while cur ~= 0 do table.insert(path, 1, cur); cur = parent[cur] end
	r.path = path
	r.playerPlayable = true
	local typeCount: { [string]: number } = {}
	local weightSum, order, maxGap, npcOk = 0, 0, 0, true
	local types: { [string]: boolean } = {}
	for idx, uid in path do
		local n = nodes[uid]
		maxGap = math.max(maxGap, gapOf[uid] or 0)
		if n.def.npc.supported == false then
			npcOk = false
			r.incompatible[#r.incompatible + 1] = n.def.name
		end
		if n.def.stage and n.id ~= "FinishPad" then
			order += 1
			typeCount[n.id] = (typeCount[n.id] or 0) + 1
			types[n.id] = true
			local w = RewardMath.sameTypeWeight(n.def.weight, typeCount[n.id])
			weightSum += w * (1 + 0.12 * math.min(gapOf[uid] or 0, 8))
			r.stages[#r.stages + 1] = { uid = uid, id = n.id, order = order, weight = n.def.weight, sameTypeIndex = typeCount[n.id], exit = n.exit, entry = n.entry, npc = n.def.npc.supported ~= false }
		end
	end
	local typeN = 0
	for _ in types do typeN += 1 end
	r.typeCount = typeN
	r.maxGap = maxGap
	r.score = weightSum + 0.01 * #path * 4
	r.difficulty = RewardMath.difficulty(r.score)
	r.lowQuality = #r.stages < Balance.MinStagesForFullReward or typeN < Balance.MinTypesForFullReward
	r.npcPlayable = npcOk and #r.stages >= 1
	r.offPath = #objs - #path
	if r.offPath > 0 then warnings[#warnings + 1] = ("%d object(s) are not on the route (they earn nothing)"):format(r.offPath) end
	if not npcOk then warnings[#warnings + 1] = "NPC-incompatible on the route: " .. table.concat(r.incompatible, ", ") end
	if r.lowQuality then warnings[#warnings + 1] = ("Low quality: need at least %d stages and %d different obstacle types for full rewards"):format(Balance.MinStagesForFullReward, Balance.MinTypesForFullReward) end
	warnings[#warnings + 1] = "Auto-check is a heuristic: do a test run to be sure"
	return r
end

function Service.Analyze(player: Player): any?
	local profile = PlayerDataService.Get(player)
	if not profile then return nil end
	local c = cache[player]
	if c and c.version == profile.plot.version then return c.result end
	local res = Service.Compute(profile)
	cache[player] = { version = profile.plot.version, result = res }
	return res
end

local function summary(res: any): any
	return { playerPlayable = res.playerPlayable, npcPlayable = res.npcPlayable, stages = #res.stages, difficulty = res.difficulty,
		difficultyLabel = RewardMath.label(res.difficulty), lowQuality = res.lowQuality, warnings = res.warnings, hasFinish = res.hasFinish, objectCount = res.objectCount,
		breaks = res.breaks, finishEntry = res.finishEntry }
end
Service.Summary = summary

local function refreshSign(player: Player)
	local profile, plot = PlayerDataService.Get(player), PlotService.Get(player)
	if not profile or not plot then return end
	local res = Service.Analyze(player)
	if not res then return end
	local stats = if res.playerPlayable then ("%d %s  |  %s"):format(#res.stages, if #res.stages == 1 then "stage" else "stages", RewardMath.label(res.difficulty)) else "Under construction"
	local status = ("Player %s   NPC %s"):format(if res.playerPlayable then "OK" else "--", if res.npcPlayable then "OK" else "--")
	PlotService.SetSignInfo(plot, profile.plot.name, player.DisplayName, stats, status)
	plot.model:SetAttribute("PlayerPlayable", res.playerPlayable)
	plot.model:SetAttribute("NpcPlayable", res.npcPlayable)
	StateSync.Push(player)
end

function Service.Start()
	StateSync.Provider("course", function(player: Player)
		local res = Service.Analyze(player)
		return if res then summary(res) else nil
	end)
	local pending: { [Player]: boolean } = {}
	local function soon(player: Player)
		if pending[player] then return end
		pending[player] = true
		task.delay(0.4, function() pending[player] = nil; if player.Parent then refreshSign(player) end end)
	end
	BuildService.Changed.Event:Connect(function(player: Player) soon(player) end)
	SessionService.Ready.Event:Connect(function(player: Player) task.delay(1, function() if player.Parent then refreshSign(player) end end) end)
	SessionService.Leaving.Event:Connect(function(player: Player) cache[player] = nil end)
	Net.handle("ValidateCourse", Balance.RateLimits.Validate, function(player: Player)
		local res = Service.Analyze(player)
		return if res then { ok = true, course = summary(res) } else { ok = false, err = "NoProfile" }
	end)
end

return Service
