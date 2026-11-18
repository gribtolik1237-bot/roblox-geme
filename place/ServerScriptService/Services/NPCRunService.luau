--!strict
-- NPC attempts (spec 10.5, 11, 12.2). One attempt = one server run id. Stages are paid ONCE each on server-confirmed progress,
-- the attempt ends exactly once (fall / finish / cancel / owner leaves), coins are granted ONCE via RewardService,
-- then the NPC disappears with an effect, the pad/active slot is freed and the NPC stays in the collection.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Configs.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local NPCs = require(ReplicatedStorage.Configs.NPCs)

local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local CourseValidationService = require(script.Parent.CourseValidationService)
local RewardService = require(script.Parent.RewardService)
local StateSync = require(script.Parent.StateSync)
local SessionService = require(script.Parent.SessionService)
local BuildService = require(script.Parent.BuildService)
local Placement = require(script.Parent.NPCPlacementService)
local Brain = require(script.Parent.NPCBrainService)
local Traversal = require(script.Parent.ObstacleTraversalService)
local Runtime = require(script.Parent.Parent.Systems.ObstacleRuntime)
local RewardMath = require(script.Parent.Parent.Systems.RewardMath)
local GroundCheck = require(script.Parent.Parent.Systems.GroundCheck)

local NpcTypes = require(script.Parent.Parent.Systems.NpcTypes)
type Run = NpcTypes.Run

local Service = {}
Service.Ended = Instance.new("BindableEvent")   -- (player, summary) after payout

local runs: { [string]: Run } = {}                       -- [id] = run
local byModel: { [Model]: Run } = {}                     -- [Model] = run
local lastLaunch: { [Player]: { [number]: number } } = {} -- [player] = { [pad] = clock }

-- (audit 2.4: the unused local isGround copy was removed - ground tests go through Systems.GroundCheck -> Shared.Util.isGround)

local function notify(player: Player, text: string, kind: string?) Net.fire("Notify", player, text, kind or "info") end
local function event(run: Run, p: { [string]: any }) p.pad = run.pad; p.npc = run.def.name; p.total = #run.analysis.stages; Net.fire("NpcState", run.player, p) end

local function despawn(run: Run)
	local model = run.model
	byModel[model] = nil
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		local fx = Instance.new("Part"); fx.Anchored = true; fx.CanCollide = false; fx.CanQuery = false; fx.Transparency = 1; fx.Size = Vector3.one
		fx.Position = hrp.Position; fx.Parent = workspace.Runtime
		local pe = Instance.new("ParticleEmitter"); pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"; pe.Rate = 0
		pe.Lifetime = NumberRange.new(0.5, 0.9); pe.Speed = NumberRange.new(8, 16); pe.SpreadAngle = Vector2.new(180, 180); pe.Size = NumberSequence.new(1.2, 0)
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 220, 255)); pe.LightEmission = 1; pe.Parent = fx
		pe:Emit(26)
		task.delay(1.4, function() fx:Destroy() end)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then TweenService:Create(d, TweenInfo.new(0.55), { Transparency = 1 }):Play()
		elseif d:IsA("BillboardGui") then d.Enabled = false end
	end
	task.delay(0.8, function() Placement.Free(run.player, run.pad) end)   -- destroys the model, frees pad + active slot
end

-- Idempotent end of an attempt: the first caller wins, everything else is ignored.
local function endRun(run: Run, outcome: string, reason: string?)
	if run.ended then return end
	run.ended = true
	runs[run.id] = nil
	if outcome == "failed" and run.brain then   -- diagnostic: where in the route did it end (spec 10.6)
		local st = run.route.steps[run.brain.i]
		reason = (reason or "?") .. (" [step %d/%d %s]"):format(run.brain.i, #run.route.steps, st and st.kind or "-")
	end
	local player = run.player
	local confirmed = run.nextStage - 1
	local bonus = 0
	local allStages = confirmed >= #run.analysis.stages
	if outcome == "finished" and allStages then bonus = RewardMath.npcFinish(run.earned, run.prior, run.analysis.lowQuality) end
	local paid, paidBonus = 0, 0
	if confirmed >= Balance.Npc.MinProgressForPayout and run.earned > 0 then paid = RewardService.Grant(player, run.earned, "npcStage", "npcS:" .. run.id) end
	if bonus > 0 then paidBonus = RewardService.Grant(player, bonus, "npcFinish", "npcF:" .. run.id) end
	local profile = PlayerDataService.Get(player)
	if profile then
		profile.stats.npcRuns += 1; profile.stats.npcStages += confirmed
		if outcome == "finished" and allStages then profile.stats.npcFinishes += 1 end
		PlayerDataService.MarkDirty(player)
	end
	local e = Placement.Entry(player, run.pad)
	if e then e.status = "ending" end
	event(run, { state = "end", outcome = outcome, reason = reason, stage = confirmed, earned = paid, bonus = paidBonus })
	Service.Ended:Fire(player, { run = run, outcome = outcome, reason = reason, stages = confirmed, earned = paid, bonus = paidBonus, stumbles = run.stumbles, recoveries = run.recoveries, seconds = os.clock() - run.startedAt })
	local hum = run.hum
	if outcome ~= "finished" and hum and hum.Parent then hum:ChangeState(Enum.HumanoidStateType.FallingDown) end   -- tumble, then fade
	despawn(run)
end

function Service.Launch(player: Player, req: any): any
	if type(req) ~= "table" or not Net.isInt(req.pad, 1, Balance.NpcPads) then return { ok = false, err = "Invalid" } end
	local profile, plot = PlayerDataService.Get(player), PlotService.Get(player)
	if not profile or not plot then return { ok = false, err = "NoPlot" } end
	local entry = Placement.Entry(player, req.pad)
	if not entry then return { ok = false, err = "NotFound" } end
	if entry.status ~= "placed" then return { ok = false, err = "Busy" } end
	lastLaunch[player] = lastLaunch[player] or {}
	if os.clock() - (lastLaunch[player][req.pad] or -100) < Balance.Npc.LaunchCooldown then return { ok = false, err = "Rate" } end
	local analysis = CourseValidationService.Analyze(player)
	if not analysis or not analysis.playerPlayable then return { ok = false, err = "CourseNotReady" } end
	if not analysis.npcPlayable then return { ok = false, err = "NpcIncompatible", detail = table.concat(analysis.incompatible, ", ") } end
	local def = NPCs.ById[entry.npcId]
	local model = entry.model
	local hum, hrp = model:FindFirstChildOfClass("Humanoid"), model:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return { ok = false, err = "Server" } end
	lastLaunch[player][req.pad] = os.clock()
	-- prior attempts on THIS course version inside the window (anti-farm decay)
	local key = tostring(analysis.version)
	local list = profile.attempts[key] or {}
	local fresh = {}
	for _, t in list do if os.time() - t < Balance.Npc.RepeatWindowSeconds then fresh[#fresh + 1] = t end end
	local prior = #fresh
	fresh[#fresh + 1] = os.time()
	profile.attempts[key] = fresh
	local route = Traversal.BuildRoute(plot.cf, PlotService.PadLocal(req.pad), analysis, profile.plot.objects, function(uid) return BuildService.Model(player, uid) end)
	local run: Run = { id = HttpService:GenerateGUID(false), player = player, plot = plot, pad = req.pad, def = def, model = model, hum = hum, hrp = hrp,
		analysis = analysis, version = analysis.version, route = route, nextStage = 1, earned = 0, prior = prior, startedAt = os.clock(), ended = false,
		seed = math.random(1, 2 ^ 30), forward = plot.cf.LookVector } :: any
	run.fail = function(reason, detail) endRun(run, "failed", reason .. (if detail then (": " .. detail) else "")) end
	run.stumbles, run.recoveries = 0, 0
	run.onStumble = function(recovered)
		run.stumbles += 1
		if recovered then run.recoveries += 1 end
		event(run, { state = "stumble", recovered = recovered })
	end
	run.groundSince = os.clock() + 1.5
	runs[run.id] = run; byModel[model] = run
	entry.status = "running"; entry.total = #analysis.stages; entry.stage = 0
	Brain.Start(run)
	event(run, { state = "start", prior = prior })
	StateSync.Push(player)
	return { ok = true, run = run.id }
end

-- Pays every stage whose exit the NPC has reached this tick (several in one tick when stages are short). Bounded loop: at most the
-- remaining stages, stops at the first stage not reached yet (audit 1.1: no open-ended `while true`).
local function checkProgress(run: Run)
	local hrp = run.hrp
	local stages = run.analysis.stages
	for _ = run.nextStage, #stages do
		local st = stages[run.nextStage]
		if not st then break end
		local cp = run.plot.cf:PointToWorldSpace(st.exit) + Vector3.new(0, 3, 0)
		if (hrp.Position - cp).Magnitude <= 6.5 and math.abs(hrp.Position.Y - cp.Y) <= 6 then
			local coins = RewardMath.npcStage(st.weight, st.sameTypeIndex, run.prior, run.analysis.lowQuality)
			run.earned += coins; run.nextStage += 1
			local e = Placement.Entry(run.player, run.pad)
			if e then e.stage = run.nextStage - 1 end
			event(run, { state = "stage", stage = run.nextStage - 1, coins = coins, earned = run.earned })
		else break end
	end
end

local function step(run: Run, dt: number)
	if run.ended then return end
	if BuildService.IsRebuilding(run.player) then endRun(run, "cancelled", "changed") return end
	local hum, hrp = run.hum, run.hrp
	if not hrp.Parent or not hum.Parent then endRun(run, "failed", "lost") return end
	if os.clock() - run.startedAt > Balance.Npc.AttemptTimeout then endRun(run, "failed", "timeout") return end
	Brain.Step(run, dt)
	if run.ended then return end
	checkProgress(run)
	-- finish is checked BEFORE the fall test so a finish and a fall in the same window end the attempt once, as a finish
	local goal = run.route.goal
	if goal and (hrp.Position - goal).Magnitude <= 5.2 and math.abs(hrp.Position.Y - goal.Y) <= 6 then endRun(run, "finished") return end
	if os.clock() > run.groundSince then
		if GroundCheck.overGround(hrp, { run.model }) then run.groundHits = (run.groundHits or 0) + 1 else run.groundHits = 0 end
		if run.groundHits >= 2 or hrp.Position.Y < run.plot.cf.Position.Y - 20 then endRun(run, "failed", "fell") end   -- 2 consecutive checks: no flicker
	end
end

function Service.Start()
	Net.handle("LaunchNpc", Balance.RateLimits.Npc, Service.Launch)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then return end
		local d = acc; acc = 0
		for _, run in runs do step(run, d) end
	end)
	Runtime.HazardTouched.Event:Connect(function(part, hit, kind)
		local char = hit:FindFirstAncestorOfClass("Model")
		local run = char and byModel[char]
		if not run or run.ended then return end
		if kind == "Kill" then endRun(run, "failed", "hazard")
		elseif kind == "Knock" then
			local away = Vector3.new(run.hrp.Position.X - part.Position.X, 0, run.hrp.Position.Z - part.Position.Z)
			local dir = if away.Magnitude > 0.1 then away.Unit else run.forward
			local K = Balance.Npc.KnockImpulse   -- audit 2.3 (55 / 26)
			run.hrp:ApplyImpulse(dir * run.hrp.AssemblyMass * K.Horizontal + Vector3.new(0, run.hrp.AssemblyMass * K.Up, 0))
		end
	end)
	Placement.RecallRequested.Event:Connect(function(player, pad)
		for _, run in runs do if run.player == player and run.pad == pad then endRun(run, "cancelled") end end
	end)
	SessionService.Leaving.Event:Connect(function(player)
		for _, run in runs do if run.player == player then endRun(run, "cancelled", "left") end end
	end)
	BuildService.Changed.Event:Connect(function(player)
		local profile = PlayerDataService.Get(player)
		for _, run in runs do
			if run.player == player and (not profile or run.version ~= profile.plot.version) then endRun(run, "cancelled", "changed") end
		end
	end)
	game:BindToClose(function() for _, run in runs do endRun(run, "cancelled", "shutdown") end end)
end

function Service.Count() local n = 0 for _ in runs do n += 1 end return n end
function Service.All() return runs end   -- diagnostics / tests

return Service
