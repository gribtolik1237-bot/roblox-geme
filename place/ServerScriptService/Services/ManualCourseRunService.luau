--!strict
-- Manual runs (spec 10.1-10.3). The PLAY prompt ALWAYS starts the pressing player's own avatar - never an NPC.
-- The server owns the run: start, ordered checkpoints, falls, speed sanity, time limits and the reward.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Configs.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local CourseValidationService = require(script.Parent.CourseValidationService)
local RewardService = require(script.Parent.RewardService)
local StateSync = require(script.Parent.StateSync)
local SessionService = require(script.Parent.SessionService)
local BuildService = require(script.Parent.BuildService)
local Runtime = require(script.Parent.Parent.Systems.ObstacleRuntime)
local RewardMath = require(script.Parent.Parent.Systems.RewardMath)
local GroundCheck = require(script.Parent.Parent.Systems.GroundCheck)
local AvatarScale = require(script.Parent.Parent.Systems.AvatarScale)

local Service = {}
Service.Cleared = Instance.new("BindableEvent")   -- (player, info) after a PAID or unpaid valid clear

local runs: { [Player]: any } = {}
local lastStart: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?) Net.fire("Notify", player, text, kind or "info") end

-- (audit 2.4: the unused local isGround copy was removed - ground tests go through Systems.GroundCheck -> Shared.Util.isGround)

local function teleport(player: Player, pos: Vector3, look: Vector3?)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hrp then return end
	char:SetAttribute("ServerTeleportAt", os.clock())
	char:PivotTo(CFrame.lookAt(pos, pos + (look or Vector3.new(0, 0, -1))))
	hrp.AssemblyLinearVelocity = Vector3.zero
end

local function startPos(plot: any): Vector3
	return plot.cf:PointToWorldSpace(Vector3.new(0, 4.2, -6))
end

local function sendProgress(player: Player, run: any, state: string, extra: { [string]: any }?)
	local p: { [string]: any } = { state = state, stage = run.next - 1, total = #run.checkpoints, startedAt = run.serverStart, falls = run.falls, look = run.plot.cf.LookVector }
	if extra then for k, v in extra do p[k] = v end end
	Net.fire("RunState", player, p)
end

local function returnToSign(player: Player, run: any)
	local pos = run.plot.cf:PointToWorldSpace(Vector3.new(0, 9, 14))     -- high enough for the giant body that grows back below
	teleport(player, pos, run.plot.cf.LookVector)
	if player.Character then AvatarScale.Lobby(player.Character) end   -- the run is over: back to the giant lobby size
end

function Service.Active(player: Player): any? return runs[player] end

local function finish(player: Player, run: any, outcome: string, extra: { [string]: any }?)
	if run.done then return end            -- idempotent: only the first terminal event counts
	run.done = true
	runs[player] = nil
	local info: { [string]: any } = { outcome = outcome, time = os.clock() - run.startedAt }
	if extra then for k, v in extra do info[k] = v end end
	Net.fire("RunState", player, { state = "end", outcome = outcome, reward = info.reward or 0, creator = info.creator or 0, time = info.time, reason = info.reason, total = #run.checkpoints, stage = run.next - 1, ownerId = run.ownerId, isSelf = run.isSelf })
	if player.Parent and player.Character then returnToSign(player, run) end
end

local function reward(player: Player, run: any): (number, string?, number?)
	local profile = PlayerDataService.Get(player)
	if not profile then return 0, "noProfile" end
	local m = Balance.Manual
	local elapsed = os.clock() - run.startedAt
	if elapsed < #run.checkpoints * m.MinSecondsPerStage then return 0, "tooFast" end
	local key = run.ownerId .. ":" .. run.version
	if profile.clears[key] then return 0, "repeat" end
	profile.clears[key] = true
	profile.stats.manualClears += 1
	local base = RewardMath.manual(run.stagesCount, run.difficulty, run.lowQuality, run.isSelf)
	local got = RewardService.Grant(player, base, "manual", "manual:" .. run.id)
	local creator = 0
	if not run.isSelf and run.ownerPlayer and run.ownerPlayer.Parent then
		local op = PlayerDataService.Get(run.ownerPlayer)
		if op then
			local day = math.floor(os.time() / 86400)
			if op.daily.creatorDay ~= day then op.daily.creatorDay = day; op.daily.creatorEarned = 0 end
			local share = math.min(math.floor(base * m.CreatorShare), math.max(0, m.CreatorDailyCap - (op.daily.creatorEarned or 0)))
			if share > 0 then
				creator = RewardService.Grant(run.ownerPlayer, share, "creator", "creator:" .. run.id)
				op.daily.creatorEarned = (op.daily.creatorEarned or 0) + creator
				notify(run.ownerPlayer, ("%s cleared your course! +%d Coins"):format(player.DisplayName, creator), "ok")
			end
			op.plot.clears = (op.plot.clears or 0) + 1
		end
	end
	return got, nil, creator
end

local function complete(player: Player, run: any)
	if run.done then return end
	local got, reason, creator = reward(player, run)
	local profile = PlayerDataService.Get(player)
	if profile then PlayerDataService.MarkDirty(player) end
	Service.Cleared:Fire(player, { run = run, reward = got, reason = reason })
	finish(player, run, "cleared", { reward = got, creator = creator or 0, reason = reason })
end

local function fell(player: Player, run: any, why: string)
	run.falls += 1
	local pos = run.lastSafe or startPos(run.plot)
	teleport(player, pos + Vector3.new(0, 2.5, 0), run.plot.cf.LookVector)
	sendProgress(player, run, "fall", { why = why })
end

function Service.Start(player: Player, plot: any)
	if runs[player] then notify(player, "You are already running a course", "err") return end
	if os.clock() - (lastStart[player] or -10) < Balance.RateLimits.Run then return end
	lastStart[player] = os.clock()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then return end
	if not plot or plot.ownerId == 0 or not plot.owner then notify(player, "This plot has no owner", "err") return end
	local owner: Player = plot.owner
	local res = CourseValidationService.Analyze(owner)
	local ownerProfile = PlayerDataService.Get(owner)
	if not res or not ownerProfile or not res.playerPlayable then notify(player, "This course isn't finished yet", "err") return end
	local cps: { Vector3 } = {}
	for _, st in res.stages do cps[#cps + 1] = plot.cf:PointToWorldSpace(st.exit) + Vector3.new(0, 3, 0) end
	local goal: BasePart? = nil
	for _, m in plot.course:GetChildren() do
		if m:GetAttribute("ObstacleId") == "FinishPad" then goal = m:FindFirstChild("Goal") :: BasePart? end
	end
	if not goal then notify(player, "This course has no finish", "err") return end
	local run = { id = HttpService:GenerateGUID(false), player = player, plot = plot, ownerId = plot.ownerId, ownerPlayer = owner, version = res.version,
		stagesCount = #res.stages, difficulty = res.difficulty, lowQuality = res.lowQuality, checkpoints = cps, next = 1, finishPos = goal.Position,
		startedAt = os.clock(), serverStart = workspace:GetServerTimeNow(), lastSafe = nil, falls = 0, strikes = 0, done = false, isSelf = plot.ownerId == player.UserId }
	runs[player] = run
	local profile = PlayerDataService.Get(player)
	if profile then profile.stats.manualRuns += 1; PlayerDataService.MarkDirty(player) end
	if not run.isSelf then
		local vis = ownerProfile.plot.visitors                 -- distinct real visitors (activity criterion of TOP OBBY), bounded
		local key, lastPlay = tostring(player.UserId), ownerProfile.plot.visitors[tostring(player.UserId)]
		if not lastPlay or os.time() - lastPlay > 600 then     -- one account cannot inflate the popularity counter by spamming PLAY: one play per 10 min
			ownerProfile.plot.plays = (ownerProfile.plot.plays or 0) + 1
		end
		vis[key] = os.time()
		local n, oldestK, oldestT = 0, nil, math.huge
		for k, t in vis do n += 1; if t < oldestT then oldestK, oldestT = k, t end end
		if n > 60 and oldestK then vis[oldestK] = nil end
	end
	AvatarScale.Run(char :: Model)                                          -- normal size while running the course (user request: shrink for PLAY)
	teleport(player, startPos(plot), plot.cf.LookVector)
	run.lastPos, run.lastT = (char :: Model):GetPivot().Position, os.clock()
	Net.fire("RunState", player, { state = "start", total = #cps, startedAt = run.serverStart, name = ownerProfile.plot.name, owner = owner.DisplayName, difficulty = RewardMath.label(res.difficulty), isSelf = run.isSelf, lowQuality = res.lowQuality, look = plot.cf.LookVector })   -- look: the client turns the first-person camera down the course
end

local function step(player: Player, run: any)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return end
	local m = Balance.Manual
	local now = os.clock()
	if now - run.startedAt > m.MaxRunSeconds then finish(player, run, "timeout") return end
	-- speed sanity (ignored right after a server teleport / respawn)
	local tp = char:GetAttribute("ServerTeleportAt")
	local dt = now - run.lastT
	local flat = Vector3.new(hrp.Position.X - run.lastPos.X, 0, hrp.Position.Z - run.lastPos.Z).Magnitude
	run.lastPos, run.lastT = hrp.Position, now
	if not (tp and now - tp < 1.5) and dt > 0 and dt < 1 and flat / dt > Balance.Run.SpeedLimit then   -- audit 2.3 (170)
		run.strikes += 1
		if run.strikes >= 3 then notify(player, "Run cancelled: suspicious movement", "err"); finish(player, run, "cheat", { reason = "suspicious" }) return end
	end
	-- fell off the course (touching the pit/ground or dropping far below)
	if not (tp and now - tp < 1) then
		if GroundCheck.overGround(hrp, { char }) then run.groundHits = (run.groundHits or 0) + 1 else run.groundHits = 0 end
		if run.groundHits >= 2 or hrp.Position.Y < run.plot.cf.Position.Y - 25 then run.groundHits = 0; fell(player, run, "fall") return end
	end
	local cp = run.checkpoints[run.next]
	if cp then
		if (hrp.Position - cp).Magnitude <= m.CheckpointRadius and math.abs(hrp.Position.Y - cp.Y) <= 9 then
			run.next += 1; run.lastSafe = cp
			sendProgress(player, run, "progress")
		end
	elseif (hrp.Position - run.finishPos).Magnitude <= m.FinishRadius and math.abs(hrp.Position.Y - run.finishPos.Y) <= 9 then
		complete(player, run)
	end
end

function Service.Cancel(player: Player, silent: boolean?)
	local run = runs[player]
	if run then finish(player, run, "cancel") end
end

function Service.Init()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if not CollectionService:HasTag(prompt, "TL_PlayPrompt") then return end
		local sign = prompt:FindFirstAncestor("PlaySign")
		local plot = PlotService.GetByModel(sign and sign.Parent)
		if plot then Service.Start(player, plot) end
	end)
	Net.handle("CancelManual", Balance.RateLimits.CancelRun, function(player: Player) Service.Cancel(player); return { ok = true } end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.2 then return end
		acc = 0
		for player, run in runs do step(player, run) end
	end)
	Runtime.HazardTouched.Event:Connect(function(part: BasePart, hit: BasePart, kind: string)
		local char = hit:FindFirstAncestorOfClass("Model")
		local player = char and Players:GetPlayerFromCharacter(char)
		local run = player and runs[player]
		if not player or not run then return end            -- hazards only bite players DURING a run
		if kind == "Kill" then fell(player, run, "hazard")
		elseif kind == "Knock" then
			local hrp = (char :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local away = Vector3.new(hrp.Position.X - part.Position.X, 0, hrp.Position.Z - part.Position.Z)
				Net.fire("Knock", player, if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1), 70)
			end
		end
	end)
	SessionService.CharacterSpawned.Event:Connect(function(player: Player)
		local run = runs[player]
		if not run then return end
		task.delay(0.4, function()
			if runs[player] == run then
				if player.Character then AvatarScale.Run(player.Character) end   -- respawned mid-run: shrink again
				local pos = run.lastSafe or startPos(run.plot)
				teleport(player, pos + Vector3.new(0, 2.5, 0), run.plot.cf.LookVector)
			end
		end)
	end)
	SessionService.Leaving.Event:Connect(function(player: Player)
		local own = runs[player]
		if own then own.done = true; runs[player] = nil end
		for p, run in runs do        -- visitors on a plot whose owner leaves go home
			if run.ownerPlayer == player then finish(p, run, "ownerLeft") end
		end
	end)
	BuildService.Changed.Event:Connect(function(owner: Player)
		for p, run in runs do        -- editing the course invalidates running attempts (new version)
			if run.ownerPlayer == owner then finish(p, run, "changed") end
		end
	end)
end

return Service
