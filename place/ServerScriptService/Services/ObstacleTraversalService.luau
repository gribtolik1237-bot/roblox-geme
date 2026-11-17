--!strict
-- NPC Traversal Adapters: turn the validated route (CourseValidationService path) into ordered movement steps
-- an autonomous NPC can execute. One adapter per obstacle kind; unsupported obstacles never reach here (NPC-incompatible).
-- Steps: walk {p, tol, unstable?, hazard?} | leap {from, p, need, up} | ferry {model, board, exit}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Obstacles = require(ReplicatedStorage.Configs.Obstacles)
local Runtime = require(script.Parent.Parent.Systems.ObstacleRuntime)

local NpcTypes = require(script.Parent.Parent.Systems.NpcTypes)
type Step = NpcTypes.Step
type Route = NpcTypes.Route

local T = {}
-- obstacle kinds whose hazards the brain must predict (descriptors come from ObstacleRuntime/Behaviors)
local HAZ = { spin = true, spin2 = true, slide = true, swing = true, sweep = true, periodic = true }

local function solidFor(model: Model?, i: number, t0: number, t1: number): boolean
	local v = model and Runtime.Vanish(model)
	if not v then return true end
	local t = t0
	while t <= t1 do
		if not v.visibleAt(i, t) then return false end
		t += 0.1
	end
	return true
end

local function flat(v: Vector3): Vector3 return Vector3.new(v.X, 0, v.Z) end
local function hdist(a: Vector3, b: Vector3): number return (flat(a) - flat(b)).Magnitude end

-- route: { steps = {...}, goal = Vector3 }. `objects` = profile.plot.objects, `modelOf(uid)` = server model of an object.
function T.BuildRoute(plotCF: CFrame, padLocal: Vector3, analysis: NpcTypes.Analysis, objects: { any }, modelOf: (number) -> Model?): Route
	local byUid: { [number]: any } = {}
	for _, o in objects do byUid[o.u] = o end
	local steps: { Step } = {}
	local function walk(p: Vector3, tol: number?, extra: { [string]: any }?)
		local s: Step = { kind = "walk", p = p, tol = tol or 2.0 }
		if extra then for k, v in extra do s[k] = v end end
		steps[#steps + 1] = s
	end
	-- start: walk along the start platform to the front edge
	local prevExit: Vector3 = Vector3.zero   -- set from the first piece: the start platform is a wide edge
	local havePrev = false
	local prevFwd = plotCF.LookVector
	walk(plotCF:PointToWorldSpace(Vector3.new(padLocal.X, 2, -21)), 2.5)
	local goal: Vector3? = nil
	for idx, uid in analysis.path do
		local o = byUid[uid]
		local def = Obstacles.ById[o.id]
		local cf = plotCF * CFrame.new(o.x, o.y, o.z) * CFrame.Angles(0, math.rad(o.r), 0)
		local fwd = cf.LookVector
		local entry, exit = cf:PointToWorldSpace(def.entry), cf:PointToWorldSpace(def.exit)
		local landing = entry + fwd * 1.6
		local bk = def.behavior.kind
		local landingExtra = nil
		if HAZ[bk] then landingExtra = { hazardModel = modelOf(uid) }
		elseif bk == "vanish" then
			local vm = modelOf(uid)
			-- plan the WHOLE crossing before stepping on tile 1: each tile must stay solid while we use it
			landingExtra = { unstable = true, gate = function(t) return solidFor(vm, 1, t, t + 0.8) and solidFor(vm, 2, t + 0.5, t + 1.4) and solidFor(vm, 3, t + 1.1, t + 2.0) end }
		elseif def.npc.belt then landingExtra = { belt = def.npc.belt } end
		if not havePrev then   -- first piece: the nearest point of the start platform's front edge
			havePrev = true
			local el = plotCF:PointToObjectSpace(entry)
			prevExit = plotCF:PointToWorldSpace(Vector3.new(math.clamp(el.X, -28, 28), 2, -24))
			walk(prevExit - plotCF.LookVector * 1.5, 1.6)   -- line up in front of the piece BEFORE the pit edge (never cut across it)
		end
		-- link from the previous piece: plain walk when touching, otherwise a leap across the gap
		local gap = hdist(prevExit, entry)
		-- session 8: a 90-degree TURN (BuildController magnet puts the turned piece across the course end, its entry edge starting at the
		-- previous exit). Its entry point is half its width ahead, but the floor between is the piece itself: step onto it and walk along
		-- the entry edge (the safe end band of hazard decks) instead of "jumping" that distance.
		local turn = idx > 1 and math.abs(prevFwd:Dot(fwd)) < 0.3 and gap > 1.0 and gap <= def.size.X / 2 + 1.5
		if def.behavior.kind ~= "ferry" then
			if turn then
				walk(prevExit + prevFwd * 1.0 + fwd * 1.2, 1.2)
				walk(landing, 2.0, landingExtra)
			elseif gap > 1.0 then
				local from = prevExit - prevFwd * 0.3
				local land = entry + fwd * 0.9
				walk(from, 0.9)
				local leap = { kind = "leap", from = from, p = land, need = hdist(from, land), up = land.Y - from.Y, dir = prevFwd, name = def.name }
				-- a sweeping-beam deck (Laser Labyrinth, Moving Laser) keeps a SAFE band at its entry edge (beams travel only +-amp): land there,
				-- settle and plan from standstill like a flush join. Only decks without such a band (Prism, spinners) plan before the jump.
				local safeBand = false
				if def.behavior.kind == "sweep" and def.behavior.amps then
					local reach = 0
					for _, a in def.behavior.amps do reach = math.max(reach, a) end
					safeBand = def.size.Z / 2 - (reach + 0.5) >= 2.5
				end
				if HAZ[bk] and not safeBand then
					-- session 6 fix (Prism 0/10 with a 3-stud gap): plan the hazard crossing at the TAKE-OFF point, before the jump. Landing on
					-- the deck first and planning there put the NPC inside the bar's sweep with nowhere safe to wait.
					leap.hazardModel = modelOf(uid)
					leap.stageEdge = gap + 2.0         -- the take-off point is ~gap+0.3..1.2 from the deck edge (arrival tolerance 0.9)
				end
				steps[#steps + 1] = leap
				walk(entry + fwd * 2.2, 1.6, landingExtra)
			else
				walk(landing, 2.0, landingExtra)       -- touching piece (also ramps / different heights): just walk on
			end
		end
		local b = def.behavior
		if o.id == "FinishPad" then
			local m = modelOf(uid)
			local g = m and m:FindFirstChild("Goal")
			goal = g and g.Position or cf:PointToWorldSpace(Vector3.new(0, 2, 0))
			walk(goal, 1.8)
		elseif def.npc.hops then
			for _, h in def.npc.hops do
				local take, land = cf:PointToWorldSpace(h.take), cf:PointToWorldSpace(h.land)
				walk(take, 0.9)
				steps[#steps + 1] = { kind = "leap", from = take, p = land, need = hdist(take, land), up = land.Y - take.Y, dir = fwd, name = def.name }
			end
			walk(exit - fwd * 0.8, 1.5)
		elseif b.kind == "ferry" then
			local back = cf:PointToWorldSpace(Vector3.new(0, 2, 12.6))
			walk(entry + fwd * 1.5, 2.0)
			steps[#steps + 1] = { kind = "ferry", model = modelOf(uid), board = back, exit = cf:PointToWorldSpace(Vector3.new(0, 2, -14)), name = def.name, baseCF = cf }
			walk(exit - fwd * 0.8, 1.8)
		elseif b.kind == "vanish" then
			local vm = modelOf(uid)
			local centers = {}
			for i, z in { 8, 0, -8 } do centers[i] = cf:PointToWorldSpace(Vector3.new(0, 2, z)) end
			walk(centers[1], 1.4, { unstable = true })
			for i = 2, 3 do
				local from = centers[i - 1] + fwd * 2.2
				steps[#steps + 1] = { kind = "leap", from = from, p = centers[i], need = hdist(from, centers[i]), up = 0, dir = fwd, name = def.name,
					gate = function(t) return not solidFor(vm, i - 1, t, t + 0.5) or (solidFor(vm, i - 1, t, t + 0.4) and solidFor(vm, i, t + 0.3, t + 1.1)) end }   -- hop now if our tile is about to vanish
			end
			walk(exit - fwd * 0.8, 1.8)
		elseif b.kind == "bounce" then
			local pad = cf:PointToWorldSpace(Vector3.new(0, 2.5, 7))
			walk(pad, 1.3)
			steps[#steps + 1] = { kind = "leap", bounce = true, from = pad, p = cf:PointToWorldSpace(Vector3.new(0, 10, -7)), need = 14, up = 8, dir = fwd, name = def.name }
			walk(exit - fwd * 0.8, 1.8)
		else
			local extra = {}
			if def.npc.unstable then extra.unstable = true end
			if def.npc.belt then extra.belt = def.npc.belt end
			if HAZ[b.kind] then extra.hazardModel = modelOf(uid) end
			if b.kind == "rotplat" then walk(cf:PointToWorldSpace(Vector3.new(0, def.top, 0)), 3.0, extra) end
			walk(exit - fwd * 0.8, 1.8, extra)
		end
		prevExit, prevFwd = exit, fwd
	end
	return { steps = steps, goal = goal }
end

-- What an NPC with these (mapped) movement parameters can physically do
function T.Capability(walkSpeed: number, jumpPower: number): (number, number)
	local g = workspace.Gravity
	local air = 2 * jumpPower / g
	local maxDist = walkSpeed * air * 0.9
	local maxUp = (jumpPower * jumpPower) / (2 * g) * 0.9
	return maxDist, maxUp
end

function T.hdist(a: Vector3, b: Vector3): number return hdist(a, b) end

return T
