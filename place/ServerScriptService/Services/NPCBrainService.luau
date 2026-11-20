--!strict
-- Autonomous NPC controller (spec 10.5/10.6): follows the adapter route with REAL Humanoid physics. Stats matter:
--   speed/jump  -> WalkSpeed/JumpPower (and therefore which gaps it CAN cross; impossible ones are declined, not faked)
--   balance     -> lateral wobble amplitude on narrow/moving surfaces
--   control     -> steering error and take-off timing error
--   recovery    -> chance to recover from a stumble (never auto-win)
-- It never teleports and never moves along an animation track. Payment/verification live in NPCRunService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Obstacles = require(ReplicatedStorage.Configs.Obstacles)
local Runtime = require(script.Parent.Parent.Systems.ObstacleRuntime)
local Traversal = require(script.Parent.ObstacleTraversalService)

local NpcTypes = require(script.Parent.Parent.Systems.NpcTypes)
type Run = NpcTypes.Run
type Step = NpcTypes.Step
-- a hazard descriptor from ObstacleRuntime: pose(t) -> CFrame, size, optional active(t) and flags (periodic, jumpable, overhead, lanes...)
type Hazard = { pose: (number) -> CFrame, size: Vector3, active: ((number) -> boolean)?, [string]: any }

local Brain = {}
local plannedControl: (...any) -> (string?, number?)     -- forward declaration (T33 planner, defined below)
local V3 = Vector3.new
local function flat(v: Vector3): Vector3 return V3(v.X, 0, v.Z) end
local function hdist(a: Vector3, b: Vector3): number return (flat(a) - flat(b)).Magnitude end
local function gauss(rng: Random): number return rng:NextNumber() + rng:NextNumber() + rng:NextNumber() - 1.5 end

-- audit 4.2: keep only well-formed hazard descriptors (pose function + size Vector3) - every planner below indexes h.pose / h.size
local function validHazards(list: { any }?): { Hazard }
	local out: { Hazard } = {}
	for _, h in list or {} do
		if type(h) == "table" and type(h.pose) == "function" and typeof(h.size) == "Vector3"
			and (h.active == nil or type(h.active) == "function") then out[#out + 1] = h end
	end
	return out
end

-- Hazard prediction (spec 10.6: account for the TIMING of moving platforms / hazards, not just static geometry).
-- Every hazard descriptor is a pure function of server time, so the brain can ask "will I be hit if I keep walking?"
local function hazardHit(h: Hazard, p: Vector3, t: number, radius: number): boolean
	if not h.pose or not h.size then return false end          -- audit 4.2 defensive (validHazards already filters)
	if h.active and not h.active(t) then return false end
	local lp = h.pose(t):PointToObjectSpace(p)
	local hs = h.size / 2
	return math.abs(lp.X) <= hs.X + radius and math.abs(lp.Z) <= hs.Z + radius and math.abs(lp.Y) <= hs.Y + 2.6
end

-- Periodic zones (fire walls, spikes). A row of walls whose wave runs AGAINST the walker cannot be dashed through in one go
-- (offline model, BUG-011: 0 safe start times out of 56 for every speed 8..18), but the gaps between walls are safe pockets.
-- So we plan ONE zone at a time: walk up, stop in front of it while it is (or is about to be) active, cross when the whole
-- crossing (body radius + timing margins for the 0.1 s hazard poll and acceleration) lies in its dormant window, then re-plan.
-- Each zone has a body `reach` (how far the body can poke into it from outside): measured live, an idle R15 NPC's hands touch a
-- fire wall 1.3-1.9 studs from its root -> 2.0; legs/feet for floor traps -> 0.5. A zone may also set `slow`: a gauntlet is WALKED
-- (the brain decides every 0.1 s, so at 16+ studs/s it could not stop inside a pocket between two walls).
-- Plan: walk up, slow down smoothly, stand at the STAGING point (reach + gap before the zone), cross only when the whole
-- crossing lies in the zone's dormant window, then re-plan for the next zone. Returns action, speedCap.
local GAP, LEAD_MARGIN, TAIL_MARGIN, APPROACH, MAX_PERIODIC_HOLD = 0.6, 0.2, 0.3, 8, 14
local function periodicControl(b: any, hz: { Hazard }, hrp: BasePart, dir: Vector3, speed: number, nowT: number, now: number): (string, number?)
	local nearest
	for _, h in hz do
		if h.periodic and not h.lanes then
			local cf = h.pose(nowT)
			local reach = h.reach or 1.0
			local half = math.abs(dir:Dot(flat(cf.RightVector))) * h.size.X / 2 + math.abs(dir:Dot(flat(cf.LookVector))) * h.size.Z / 2
			local ahead = (flat(cf.Position) - flat(hrp.Position)):Dot(dir)
			if ahead > -(half + reach) and (not nearest or ahead < nearest.ahead) then nearest = { h = h, half = half, ahead = ahead, reach = reach } end
		end
	end
	if not nearest then b.pHold = nil return "go", nil end
	local reach = nearest.reach
	local top = math.min(speed, nearest.h.slow or speed)                          -- gauntlet pace
	local capTop = if top < speed then top else nil
	local dn, df = nearest.ahead - nearest.half, nearest.ahead + nearest.half     -- distance to the near / far edge of the zone
	if dn < reach - 0.1 then b.pHold = nil return "go", capTop end              -- body already touches the zone: too late to stop, get through
	local toStage = dn - (reach + GAP)                                            -- distance still to walk to the staging point
	if toStage > APPROACH then b.pHold = nil return "go", nil end                -- far away: walk up
	if toStage > 0.3 then return "go", math.clamp(3 + 3.5 * toStage, 4, top) end   -- approach slowly so that we stop AT the staging point
	local vEff = 0.8 * math.max(top, 4)                                           -- allow for acceleration from standstill
	local tIn = math.max(0, (dn - reach) / vEff)
	local tOut = (df + reach) / vEff
	local unsafe = false
	for tau = math.max(0, tIn - LEAD_MARGIN), tOut + TAIL_MARGIN, 0.05 do
		if nearest.h.active(nowT + tau) then unsafe = true break end
	end
	if not unsafe then b.pHold = nil return "go", capTop end
	b.pHold = b.pHold or now
	if now - b.pHold > MAX_PERIODIC_HOLD then return "go", capTop end         -- never wait forever (an NPC too slow for this zone takes the risk and fails honestly)
	return "hold", nil
end

-- Moving hazards that cannot be jumped (sliding / swinging walls, the high spinner bar). Standing and waiting for the straight
-- line down the middle to clear never works for a wall that sweeps the whole deck (BUG-012: Moving Wall, Prism Spinner: NPC
-- waited forever), so: plan ONE hazard at a time, stop at its staging point, and look for a LANE + start time for which the whole
-- crossing (simulated forward with the hazard's pose at each moment) is hit-free; steer into that lane (b.lane) and go.
local function projHalf(cf: CFrame, size: Vector3, dir: Vector3): number
	return math.abs(dir:Dot(flat(cf.RightVector))) * size.X / 2 + math.abs(dir:Dot(flat(cf.LookVector))) * size.Z / 2
end
local function movingControl(b: any, hz: { Hazard }, hrp: BasePart, dir: Vector3, lat: Vector3, speed: number, nowT: number, now: number, model: Model?): (string, number?)
	local nearest
	for _, h in hz do
		if not h.periodic and not h.jumpable and not h.lanes and not h.overhead then
			local half = 0
			for k = 0, 6 do half = math.max(half, projHalf(h.pose(nowT + k * 0.5), h.size, dir)) end      -- a rotating bar's extent changes with time
			local ahead = (flat(h.pose(nowT).Position) - flat(hrp.Position)):Dot(dir)
			local reach = h.reach or 2.0
			if ahead > -(half + reach) and (not nearest or ahead < nearest.ahead) then nearest = { h = h, half = half, ahead = ahead, reach = reach } end
		end
	end
	if not nearest then b.mHold = nil; b.mCross = nil; return "go", nil end
	local obstacleId = model and model:GetAttribute("ObstacleId")
	local isWall = obstacleId == "MovingWall"
	-- Once a wall has a clear lane, keep that lane and pace until the body passes it.
	local committed = b.mCross
	if isWall and committed and committed.hazard == nearest.h then
		b.lane = committed.lane
		return "go", committed.speed
	end
	b.mCross = nil
	local reach, half = nearest.reach, nearest.half
	local dn, df = nearest.ahead - half, nearest.ahead + half
	if dn < reach - 0.1 then b.mHold = nil return "go", nil end                  -- already touching its reach: keep going in the chosen lane
	local toStage = dn - (reach + GAP + (if isWall then 0.35 else 0))
	if toStage > APPROACH then b.mHold = nil return "go", nil end
	if toStage > 0.3 then return "go", math.clamp(3 + 3.5 * toStage, 4, speed) end
	-- Two phases at the staging point: (1) shift sideways into the lane while standing at this distance, (2) cross STRAIGHT.
	-- Lane coordinates are relative to the brain's path line (that is what b.lane steers by): lane = centre lane - c0.
	local vEff = 0.85 * speed
	local T = (df + reach) / vEff + 0.3
	local vLat = math.min(speed, 10)
	local radius = if isWall then 2.05 else 1.8
	local late = if isWall then 0.24 else 0.2
	local def = obstacleId and Obstacles.ById[obstacleId]
	local hw = math.max(1.5, (if def then def.size.X / 2 else 6) - 1.6)         -- keep inside the deck
	local c0 = (b.segFrom - model:GetPivot().Position):Dot(lat)
	local cl = (hrp.Position - b.segFrom):Dot(lat)                              -- where we stand now, in line coordinates
	local best, bestTs = nil, math.huge
	for _, laneC in { 0, -hw * 0.5, hw * 0.5, -hw, hw } do
		local lane = laneC - c0
		local ts = math.abs(lane - cl) / vLat
		if ts < bestTs then
			local clear = true
			for tau = 0, ts + T, 0.05 do
				local lateral, fwd = lane, vEff * (tau - ts)
				if tau <= ts then lateral = cl + (lane - cl) * (tau / math.max(ts, 1e-3)); fwd = 0 end
				local p = hrp.Position + dir * fwd + lat * (lateral - cl)
				-- the brain decides every 0.1 s and the body lags the decision by 0.05-0.15 s: check the hazard now AND a bit later
				if hazardHit(nearest.h, p, nowT + tau + 0.05, radius) or hazardHit(nearest.h, p, nowT + tau + late, radius) then clear = false break end
			end
			if clear then best, bestTs = lane, ts end
		end
	end
	if best then
		b.mHold = nil
		b.lane = best
		if bestTs > 0.15 then
			b.shiftVec = lat * math.clamp(best - cl, -4, 4)
			return "hold", if isWall then vLat else nil
		end
		if isWall then
			b.mCross = { hazard = nearest.h, lane = best, speed = vEff }
			return "go", vEff
		end
		return "go", nil
	end
	b.mHold = b.mHold or now
	if now - b.mHold > MAX_PERIODIC_HOLD then return "go", nil end
	return "hold", nil
end

-- Jump planner (T33). Laser Labyrinth (3 low beams on 3 rhythms) and Prism Spinner (jump the low bar, never INTO the high bar) failed
-- with the reactive jump (fire 0.36 s before a hit): two hits closer than one jump can cover, or the high bar passing over the jump.
-- Measured before: Prism 4/6, Laser 1/6. Now, standing ~1 stud before the deck, simulate the whole straight crossing for every start
-- delay (0.1 s steps, up to 12 s) and take the first one where every low-hazard hit is covered by a jump, jumps never overlap
-- (landing + 0.12 s before the next take-off) and no overhead hazard is above the body while airborne. Then wait, walk, jump on time.
local function overheadHit(h: Hazard, p: Vector3, t: number, r: number): boolean
	if not h.pose or not h.size then return false end
	local lp = h.pose(t):PointToObjectSpace(p)
	local hs = h.size / 2
	return math.abs(lp.X) <= hs.X + r and math.abs(lp.Z) <= hs.Z + r
end
local function needsPlan(hz: { any }): boolean
	local low, overhead = 0, false
	for _, h in hz do
		if h.overhead then overhead = true elseif h.jumpable and not h.periodic then low += 1 end
	end
	return overhead or low >= 2
end
local function planCrossing(b: any, hz: { Hazard }, hrp: BasePart, dir: Vector3, model: Model, nowT: number, preAir: number?): any
	local air = 2 * b.m.jumpPower / workspace.Gravity
	local pre = preAir or 0       -- > 0: the crossing STARTS with a take-off leap over a gap (session 6): airborne for `pre` seconds
	local v = 0.92 * b.m.walkSpeed
	local def = Obstacles.ById[model:GetAttribute("ObstacleId")]
	local along = (flat(model:GetPivot().Position) - flat(hrp.Position)):Dot(dir)
	local T = (along + (if def then def.size.Z / 2 else 10) + 1.5) / v
	local DT = 0.04
	for d = 0, 20, 0.1 do
		local hits = {}
		for tau = 0, T, DT do
			local p = hrp.Position + dir * v * tau
			if tau >= pre - 0.02 then        -- low beams pass UNDER the take-off leap
				for _, h in hz do
					if h.jumpable and not h.periodic and not h.overhead and hazardHit(h, p, nowT + d + tau, 0.9) then hits[#hits + 1] = tau break end
				end
			end
		end
		local jumps, ok, i, lastLand = {}, true, 1, (if pre > 0 then pre + 0.13 else -1)   -- no new jump before the leap has landed (+settle)
		while i <= #hits do
			local jt = hits[i] - 0.2
			if jt < 0.05 or jt < lastLand + 0.12 then ok = false break end
			while i <= #hits and hits[i] <= jt + air - 0.12 do i += 1 end
			if i <= #hits and hits[i] < jt + air + 0.12 then ok = false break end
			jumps[#jumps + 1] = jt
			lastLand = jt + air
		end
		if ok then
			local airborne = table.clone(jumps)
			if pre > 0 then table.insert(airborne, 1, 0) end     -- the take-off leap is in the air too: check the overhead bar for it
			for _, jt in airborne do
				for tau = jt, jt + air, DT do
					local p = hrp.Position + dir * v * tau
					for _, h in hz do if h.overhead and overheadHit(h, p, nowT + d + tau, 1.1) then ok = false break end end
					if not ok then break end
				end
				if not ok then break end
			end
		end
		if ok then return { t0 = nowT + d, jumps = jumps, i = 1, T = T, model = model } end
	end
	return nil
end
-- returns action, cap when the planner is in charge of this hazard; nil to fall back to the reactive logic
plannedControl = function(run: Run, b: any, step: Step, hz: { Hazard }, hrp: BasePart, dir: Vector3, grounded: boolean, now: number, nowT: number): (string?, number?)
	local model = step.hazardModel
	local isMovingLaser = model and model:GetAttribute("ObstacleId") == "MovingLaser"
	if not isMovingLaser and not needsPlan(hz) then return nil end
	local pl = b.jplan
	if pl and pl.model ~= model then pl = nil; b.jplan = nil end
	if not pl then
		local def = Obstacles.ById[model:GetAttribute("ObstacleId")]
		local edge = (flat(model:GetPivot().Position) - flat(hrp.Position)):Dot(dir) - (if def then def.size.Z / 2 else 10)
		local stage = step.stageEdge or 1.4                       -- a leap step stages at its take-off point (gap + margin)
		if edge > stage + 2.6 then return "go", nil end          -- walk up
		if edge > stage then return "go", 4 end                  -- slow down to the staging point just before the deck
		if hrp.AssemblyLinearVelocity.Magnitude > 2.5 then return "hold", nil end   -- settle first: the plan starts from standstill
		pl = planCrossing(b, hz, hrp, dir, model, nowT, if step.stageEdge then 2 * b.m.jumpPower / workspace.Gravity else 0) or { failed = true, model = model }
		b.jplan = pl
	end
	if pl.failed then return nil end
	if nowT < pl.t0 then return "hold", nil end
	local tau = nowT - pl.t0
	local jt = pl.jumps[pl.i]
	if jt and tau >= jt - 0.03 then
		-- jump the moment we touch ground (just after a landing the body may still be airborne): never silently skip a planned jump
		if grounded then run.hum.Jump = true; b.lastJump = now; pl.i += 1
		elseif tau > jt + 0.15 then pl.i += 1 end
	end
	if tau > pl.T + 1.0 then return nil end                     -- crossing done: hand back
	return "go", if isMovingLaser then 0.92 * b.m.walkSpeed else nil
end

-- returns "go" | "hold" | "retreat" (and may trigger a jump over a low hazard)
local function hazardControl(run: Run, b: any, step: Step, grounded: boolean, now: number): (string, number?)
	local hz = validHazards(Runtime.Hazards(step.hazardModel))
	if #hz == 0 then b.lane = nil return "go" end
	if not step.p then return "go" end
	local hrp = run.hrp
	local nowT = workspace:GetServerTimeNow()
	local dirV = flat(step.p - (b.segFrom or hrp.Position))          -- the PATH direction: stays stable while we shift sideways into a lane
	local dir = if dirV.Magnitude > 0.5 then dirV.Unit else run.forward
	local lat = V3(-dir.Z, 0, dir.X)
	local speed = b.m.walkSpeed
	local function pathPoint(tau: number, off: number?): Vector3 return hrp.Position + dir * speed * tau + lat * (off or 0) end

	-- lane hazards (electric floor): choose the lane that stays dark for the whole crossing
	local lanes, zlen = false, 0
	for _, h in hz do if h.lanes then lanes = true; zlen = math.max(zlen, h.size.Z) end end
	if lanes then
		local inside = false
		for _, h in hz do
			local lp = h.pose(nowT):PointToObjectSpace(hrp.Position)
			if math.abs(lp.X) <= h.size.X / 2 + 1 and math.abs(lp.Z) <= h.size.Z / 2 + 1 then inside = true end
		end
		if inside and b.lane then return "go" end        -- committed to a lane
		local horizon = (zlen + 2) / speed + 0.15
		for _, off in { -3, 3 } do
			local safe = true
			for tau = 0, horizon, 0.1 do
				for _, h in hz do if hazardHit(h, pathPoint(tau, off), nowT + tau, 0.9) then safe = false end end
			end
			if safe then b.lane = off return "go" end
		end
		b.lane = nil
		return "hold"
	end

	-- planned crossing for multi-beam / overhead obstacles (T33): decides WHEN to enter and WHEN to jump
	local pAct, pCapPlan = plannedControl(run, b, step, hz, hrp, dir, grounded, now, nowT)
	if pAct then return pAct, pCapPlan end

	-- am I being hit right where I stand (within the next fraction of a second)?
	for _, h in hz do
		if not h.periodic and not (h.overhead and grounded) then
			for _, tau in { 0, 0.12, 0.24 } do
				if hazardHit(h, hrp.Position, nowT + tau, 0.6) then      -- physical contact only: a bigger radius made NPCs standing at a staging point shuffle back and forth
					if h.jumpable then
						if grounded and now - b.lastJump > 0.5 then run.hum.Jump = true; b.lastJump = now end
						return "go"
					end
					return "retreat"
				end
			end
		end
	end
	-- will walking on hit me soon? (periodic zones are planned one at a time by periodicControl)
	local pAction, pCap = periodicControl(b, hz, hrp, dir, b.m.walkSpeed, nowT, now)
	if pAction == "hold" then return "hold" end
	local mAction, mCap = movingControl(b, hz, hrp, dir, lat, b.m.walkSpeed, nowT, now, step.hazardModel)
	if mAction == "hold" then return "hold", mCap end
	pCap = pCap or mCap
	for _, h in hz do
		if h.periodic then
			-- handled above
		elseif h.jumpable then
			-- low hazard (bar / beam): jump so that it passes UNDER us at the top of the jump (about 0.25 s after take-off)
			local hitAt = nil
			for tau = 0.04, 0.7, 0.04 do
				if hazardHit(h, pathPoint(tau), nowT + tau, 0.9) then hitAt = tau break end
			end
			if hitAt and hitAt <= 0.36 and grounded and now - b.lastJump > 0.6 then run.hum.Jump = true; b.lastJump = now end
		-- non-jumpable moving hazards: planned by movingControl above
		end
	end
	return "go", pCap
end

-- Maps 1..10 stats to real movement parameters (BALANCE.md)
function Brain.Mapped(stats: any): any
	local m = Balance.NpcStatMap
	return {
		walkSpeed = m.WalkSpeedBase + m.WalkSpeedPerPoint * stats.speed,
		jumpPower = m.JumpPowerBase + m.JumpPowerPerPoint * stats.jump,
		wobble = (11 - stats.balance) * m.BalanceNoisePerMissing,
		steer = (11 - stats.control) * m.ControlSteerPerMissing,
		timing = (11 - stats.control) * m.ControlJumpTimingPerMissing,
		recover = stats.recovery / m.RecoveryChanceDivisor,
	}
end

function Brain.Start(run: Run)
	local m = Brain.Mapped(run.def.stats)
	local maxDist, maxUp = Traversal.Capability(m.walkSpeed, m.jumpPower)
	run.brain = { m = m, i = 1, lastI = 0, rng = Random.new(run.seed), dev = 0, lastJump = 0, lastStumble = 0, maxDist = maxDist, maxUp = maxUp,
		stuckAt = os.clock(), bestD = math.huge, retries = 0, segFrom = nil, gatePassed = {}, lane = nil }
end

function Brain.Step(run: Run, dt: number)
	local b = run.brain
	if not b or run.ended then return end
	local hum, hrp = run.hum, run.hrp
	-- audit 4.2: never index a destroyed humanoid / root (hum.Jump, MoveTo below)
	if not hum or not hrp or not hum.Parent or not hrp.Parent or hum.Health <= 0 then return end
	local now = os.clock()
	local step = run.route.steps[b.i]
	if not step then hum:MoveTo(run.route.goal or hrp.Position) return end
	if (step.kind == "walk" and not step.p) or (step.kind == "leap" and (not step.p or not step.from or not step.dir)) then
		b.i += 1 return                -- audit 4.2: a malformed step is skipped instead of erroring every tick
	end
	if b.lastI ~= b.i then
		b.lastI = b.i; b.segFrom = hrp.Position; b.bestD = math.huge; b.stuckAt = now; b.leap = nil; b.ferry = nil; b.retries = 0; b.lane = nil; b.mCross = nil
	end
	local m = b.m
	if b.speedI ~= b.i and hum:GetAttribute("BaseSpeed") == nil then   -- adapt speed to the step: short hops need less run-up
		b.speedI = b.i
		if step.kind == "leap" then
			local air = 2 * m.jumpPower / workspace.Gravity
			hum.WalkSpeed = math.clamp((step.need + 1.0) / air, 9, m.walkSpeed)
		else hum.WalkSpeed = m.walkSpeed end
	end
	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	local waiting = false

	-- lateral wobble (Ornstein-Uhlenbeck): amplitude from Balance on unstable surfaces, from Control elsewhere
	local sigma = (if step.unstable or step.kind == "ferry" then m.wobble * 2.2 else 0) + m.steer * 0.6
	if b.holding then sigma = 0 end            -- standing still: no walking wobble (and no stumbles)
	b.dev += (-b.dev * 1.4 * dt) + sigma * math.sqrt(dt) * gauss(b.rng)
	if step.unstable and not b.holding and math.abs(b.dev) > 1.45 and now - b.lastStumble > 0.9 then
		b.lastStumble = now
		local side = if b.dev > 0 then 1 else -1
		local dirV = flat((step.p or hrp.Position) - b.segFrom)
		local dir = if dirV.Magnitude > 0.5 then dirV.Unit else run.forward
		local lat = V3(-dir.Z, 0, dir.X)
		if b.rng:NextNumber() < m.recover then
			b.dev = -side * 0.35                       -- recovers: steps back toward the middle
			run.onStumble(true)
		else
			b.dev = side * 2.6                          -- loses balance: really tumbles toward the edge (no free pass)
			hrp:ApplyImpulse(lat * side * hrp.AssemblyMass * 14)
			hum:ChangeState(Enum.HumanoidStateType.FallingDown)
			run.onStumble(false)
		end
	end

	if step.kind == "walk" then
		local action = "go"
		if step.gate and not b.gatePassed[b.i] then
			if step.gate(workspace:GetServerTimeNow()) then b.gatePassed[b.i] = true else action = "hold" end
		end
		if action == "go" and step.belt and step.belt < 0 and m.walkSpeed <= -step.belt + 3 then
			run.fail("cannot_cross", ("The belt runs against you at %.0f studs/s - this NPC (%.1f) can't outrun it"):format(-step.belt, m.walkSpeed))
			return
		end
		local cap = nil
		if action == "go" and step.hazardModel then action, cap = hazardControl(run, b, step, grounded, now) end
		if cap then hum.WalkSpeed = cap; b.capped = true            -- smooth approach to a staging point (periodic zones)
		elseif b.capped then b.capped = false; hum.WalkSpeed = m.walkSpeed end
		local dirV = flat(step.p - b.segFrom)
		local len = dirV.Magnitude
		local dir = if len > 0.5 then dirV.Unit else run.forward
		local lat = V3(-dir.Z, 0, dir.X)
		if action == "hold" then
			hum:MoveTo(hrp.Position + (b.shiftVec or V3(0, 0, 0))); b.shiftVec = nil; waiting = true       -- shiftVec: sideways move into a lane
		elseif action == "retreat" then
			hum:MoveTo(hrp.Position - dir * 4); waiting = true
		else
			-- aim at a point a few studs AHEAD on the path line, shifted sideways by the wobble: the body really sways
			local along = (flat(hrp.Position) - flat(b.segFrom)):Dot(dir)
			local ahead = flat(b.segFrom) + dir * math.clamp(along + 4.5, 0, math.max(len, 0.1))
			local off = (if b.mCross then 0 else b.dev) + (b.lane or 0)
			hum:MoveTo(V3(ahead.X, step.p.Y, ahead.Z) + lat * off)
			local wall = step.hazardModel and step.hazardModel:GetAttribute("ObstacleId") == "MovingWall"
			local destination = if wall then step.p + lat * off else step.p
			local tolerance = if wall then step.tol else step.tol + math.abs(off)
			if hdist(hrp.Position, destination) <= tolerance then b.i += 1 end
		end
	elseif step.kind == "leap" then
		if not b.leap then
			if not step.bounce and (step.need > b.maxDist or step.up > b.maxUp) then
				run.fail("cannot_cross", ("%s: gap %.1f studs / rise %.1f is beyond this NPC (reach %.1f / %.1f)"):format(step.name or "obstacle", step.need, step.up, b.maxDist, b.maxUp))
				return
			end
			-- take-off timing: poor Control mostly jumps EARLY (costs reach), rarely late; never walks off the edge on purpose
			local err = (b.rng:NextNumber() * 2 - 1) * m.timing * m.walkSpeed * 0.3
			b.leap = { lead = 1.0 + err, phase = if step.bounce then "air" else "approach", t0 = now }
		end
		local L = b.leap
		local held = false
		-- a leap ONTO a hazard deck that needs a timed crossing: wait at the take-off point until the crossing plan says go (session 6)
		if L.phase == "approach" and step.hazardModel and not L.hzOk then
			local hz = validHazards(Runtime.Hazards(step.hazardModel))
			if #hz == 0 or not needsPlan(hz) then
				L.hzOk = true
			else
				local act = hazardControl(run, b, step, grounded, now)
				local pl = b.jplan
				L.hzSince = L.hzSince or now
				if (pl and pl.model == step.hazardModel and (pl.failed or workspace:GetServerTimeNow() >= pl.t0)) or now - L.hzSince > 25 then
					L.hzOk = true                -- (25 s safety valve: never wait forever; the planner's own horizon is 20 s)
				else
					held = true; waiting = true
					hum:MoveTo(if act == "go" then step.from else hrp.Position)
				end
			end
		end
		if L.phase == "approach" and step.gate and not L.gated then
			if step.gate(workspace:GetServerTimeNow()) then L.gated = true else held = true; waiting = true; hum:MoveTo(hrp.Position) end
		end
		if not held then
			hum:MoveTo(step.p)
			if L.phase == "approach" then
				local toEdge = (flat(step.from) - flat(hrp.Position)):Dot(step.dir)
				if toEdge <= L.lead and grounded then hum.Jump = true; L.phase = "air"; L.t0 = now; b.lastJump = now end
			else
				if (hdist(hrp.Position, step.p) <= 2.6 and grounded) or now - L.t0 > (if step.bounce then 3.5 else 1.8) then b.i += 1 end
			end
		end
	elseif step.kind == "ferry" then
		local F = b.ferry
		if not F then F = { phase = "wait" }; b.ferry = F end
		local pose = Runtime.PoseAt(step.model, workspace:GetServerTimeNow())
		if not pose then b.i += 1 return end
		local fz = step.baseCF:PointToObjectSpace(pose.Position).Z
		if F.phase == "wait" then
			waiting = true
			hum:MoveTo(step.board)
			if fz >= 6.8 and hdist(hrp.Position, step.board) < 2.8 then F.phase = "board"; F.t1 = now end
		elseif F.phase == "board" then
			hum:MoveTo(pose.Position)
			if hdist(hrp.Position, pose.Position) < 2.4 and grounded then F.phase = "ride" end
			if now - F.t1 > 3 then F.phase = "wait" end
		elseif F.phase == "ride" then
			waiting = true
			hum:MoveTo(pose.Position + V3(b.dev * 0.5, 0, 0))
			if fz <= -6.8 then F.phase = "off" end
		else
			hum:MoveTo(step.exit)
			if hdist(hrp.Position, step.exit) <= 2.4 then b.i += 1 end
		end
	end

	-- stuck detection with bounded recovery (never an endless loop)
	local target = step.p or step.board
	if target then
		local d = hdist(hrp.Position, target)
		if d < b.bestD - 0.6 then b.bestD = d; b.stuckAt = now end
	end
	if waiting then b.stuckAt = now end
	b.holding = waiting
	if now - b.stuckAt > Balance.Npc.StuckSeconds then
		b.retries += 1
		if b.retries > Balance.Npc.MaxRetriesPerNode then
			run.fail("stuck", ("stuck at step %d (%s)"):format(b.i, step.kind))
			return
		end
		b.stuckAt = now; b.bestD = math.huge; hum.Jump = true
	end
end

return Brain
