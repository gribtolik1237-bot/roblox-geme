--!strict
-- TRAP LAB balance & tuning. EVERY tunable number lives here (documented in BALANCE.md).
-- Values are PROVISIONAL starting values; they were NOT economy-playtested by players.
-- Session 8 (audit 4.1): a simulation with the real RewardMath formulas (docs/REPORT_AUDIT_S8.txt) found the late game jagged
-- (R7->R8 640 h, R9->R10 4763 h) and the first NPC purchase instant. Changed 10 values (<10% of the economy numbers):
-- StartCoins 750->300, Npc.StageBase 8->10, Npc.RepeatFloor 0.25->0.35, RebirthThreshold R6..R10, NPC prices Noob 120->350, Bacon 150->400.
local Balance = {}

Balance.DataVersion = 1
Balance.StartCoins = 300     -- was 750 (audit 4.1): the starter course is free; the first NPC is bought from ~3-6 min of NPC income
-- FTUE (roblox-game-design: reach the 'aha' fast, zero friction): a BRAND-NEW profile starts with this small ready course already
-- placed (items are owned, so it can be rebuilt/sold like any other). The first goal is to send the free Starter NPC through it.
-- Path: start edge z=-24 -> gaps of 3-4 studs (MaxGap 7) -> Finish. 4 stages, 3 types = full reward quality. NPC-verified (TESTING_REPORT T-FTUE-1).
Balance.StarterCourse = {
	{ id = "BasicPlatform", x = 0, y = 0, z = -34, r = 0 },
	{ id = "SmallJumpPlatform", x = 0, y = 0, z = -47, r = 0 },
	{ id = "BasicPlatform", x = 0, y = 0, z = -60, r = 0 },
	{ id = "LavaFloor", x = 0, y = 0, z = -81, r = 0 },
	{ id = "FinishPad", x = 0, y = 0, z = -103, r = 0 },
}
Balance.ShopIntervalSeconds = 300       -- both shops rotate every 5 minutes
Balance.MaxRebirth = 10
Balance.GridSize = 4                    -- horizontal snap (studs); fine mode = 1
Balance.LevelStep = 2                   -- vertical snap (studs)
Balance.MaxBuildHeight = 40             -- max base altitude of an obstacle (studs)
Balance.DeckTop = 2                     -- top surface height of standard platforms

-- Player scale (USER REQUEST: the course and the NPCs must look SMALL). The player is a giant (x2) in the lobby and on the plots, so the
-- course and NPCs look half size next to them; during a manual run the avatar is normal size (x1) = the size every obstacle/NPC
-- physics test was verified for. Movement scales with sqrt(scale) so jump height and pace stay proportionate to the body.
Balance.Avatar = { Lobby = 2, Run = 1, BaseWalkSpeed = 16, BaseJumpHeight = 7.2, LobbyZoom = 26 }

-- Plots ------------------------------------------------------------------
Balance.PlotCount = 8                   -- set Game Settings > Max Players to 8
Balance.PlotCell = Vector2.new(260, 420) -- fixed land cell per player (max expansion fits)
Balance.PlotRowOffset = 110             -- distance of start edge from lobby centre line
Balance.StartAreaDepth = 24             -- reserved start area (local z 0 .. -24)
Balance.PlotColumns = { -390, -130, 130, 390 }
Balance.Promenade = { BeltSpeed = 32, MarkerSpacing = 22 }

-- Index = rebirth count + 1 (r0 = index 1)
Balance.PlotWidth  = { 72, 88, 104, 120, 136, 152, 168, 184, 200, 216, 232 }
Balance.PlotLength = { 120, 144, 168, 192, 216, 240, 264, 288, 312, 336, 360 }
Balance.ObjectLimit = { 40, 70, 105, 145, 190, 240, 295, 355, 420, 490, 560 }
Balance.CosmeticLimit = { 12, 20, 30, 42, 56, 72, 90, 110, 132, 156, 180 }
-- Active NPC limit: 1 at r0, +1 per rebirth, hard server cap
Balance.NpcLimit = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10 }
Balance.NpcHardCap = 10
Balance.NpcPads = 10                     -- pads always exist; those above the limit are locked
Balance.NpcSlots = 5                    -- quick-select slots
Balance.ServerNpcCap = 24               -- absolute simultaneous NPCs on one server
-- Lifetime Earned Coins needed to REACH rebirth r (index = r). Coins are never deducted.
-- audit 4.1: R6..R10 lowered (were 2.5M, 8M, 25M, 80M, 250M): each step now ~1.5-2x the previous one in play time
Balance.RebirthThreshold = { 0, 5000, 20000, 75000, 250000, 800000, 1600000, 4000000, 8000000, 15000000, 25000000 }

-- Course geometry assumptions (player: WalkSpeed16 JumpPower50 => ~8.7 stud jump) ----
Balance.MaxGap = 7.0                    -- max horizontal gap between exit/entry for a link
Balance.MaxStepUp = 5.0
Balance.MaxDrop = 40.0
Balance.KillY = -30                     -- below plot ground => fell
Balance.MinStagesForFullReward = 4
Balance.MinTypesForFullReward = 3
Balance.LowQualityMult = 0.3

-- Manual run rewards --------------------------------------------------------
Balance.Manual = {
	BasePerStage = 12, Flat = 20,
	DifficultyMult = { Easy = 1.0, Normal = 1.5, Hard = 2.2, VeryHard = 3.2, Extreme = 4.5 },
	MaxReward = 2500,
	RepeatFraction = 0.0,               -- repeat clear of same version by same player: no coins
	SelfFraction = 0.5,                 -- owner clearing own course: 50% once per version
	CreatorShare = 0.25,                -- creator earns this share of visitor reward (first clear)
	CreatorDailyCap = 3000,
	MinSecondsPerStage = 1.2,           -- anti-teleport: faster than this per stage is rejected
	MaxRunSeconds = 900,
	CheckpointRadius = 14,
	FinishRadius = 10,
}

-- NPC run rewards ------------------------------------------------------------
Balance.Npc = {
	StageBase = 10,                     -- coins per stage at weight 1 (audit 4.1: was 8)
	FinishBonusFlat = 30,
	FinishBonusFraction = 0.4,          -- of the stage rewards already earned
	RepeatDecay = 0.15,                 -- per extra attempt on same version in window
	RepeatFloor = 0.35,                 -- audit 4.1: was 0.25 (late game with many NPCs lives at this floor)
	RepeatWindowSeconds = 3600,
	SameTypeDecay = 0.5,                -- k-th copy of same obstacle type pays 1/(1+d*(k-1))
	MinProgressForPayout = 1,           -- stages needed for any payout
	LaunchCooldown = 3,
	StuckSeconds = 6,
	AttemptTimeout = 240,
	MaxRetriesPerNode = 3,
}
-- NPC stat (1..10) -> real movement parameters
Balance.NpcStatMap = {
	WalkSpeedBase = 10, WalkSpeedPerPoint = 1.2,   -- 6 => 17.2
	JumpPowerBase = 38, JumpPowerPerPoint = 2.6,   -- 5 => 51
	BalanceNoisePerMissing = 0.12,   -- lateral wobble sigma = (11-balance)*this (studs)
	ControlSteerPerMissing = 0.08,   -- steering error sigma = (11-control)*this
	ControlJumpTimingPerMissing = 0.03, -- takeoff timing error (s)
	RecoveryChanceDivisor = 12,      -- P(recover) = recovery/this
}

-- Course difficulty order (also used for leaderboard scoring).
Balance.DifficultyOrder = { "Easy", "Normal", "Hard", "VeryHard", "Extreme" }

-- Daily login gift (LoginRewardService): 7-day streak, missing a day restarts it. Coins = Rewards[day] * (1 + rebirth). Only after the first NPC run.
Balance.Login = { Rewards = { 50, 75, 100, 150, 200, 250, 600 }, ResetUtcHour = 0 }

-- Course rating (spec 16): 5 criteria, whole stars 1..5, only AFTER clearing the course's current version, never your own course.
-- Shown value = Bayesian mean (prior 3 stars worth PriorWeight votes): (sum of every voter's 5-criteria mean + 3*PriorWeight) / (voters + PriorWeight).
Balance.Rating = { Criteria = { "Interest", "Build quality", "Difficulty", "Variety", "Overall" }, Min = 1, Max = 5, PriorMean = 3, PriorWeight = 5, MaxVoters = 150 }

-- Leaderboards (spec 15). TOP OBBY = 10000 * sum(weight_i * norm_i): no criterion may exceed 25% (the largest weight is 0.20).
Balance.Boards = {
	Size = 10, ReadEvery = 60, WriteEvery = 90,
	ObbyWeights = { Quality = 0.20, Clears = 0.20, Popularity = 0.15, Ratings = 0.20, Difficulty = 0.10, Activity = 0.15 },
	Caps = { Clears = 50, Plays = 100, Visitors = 20, Stages = 8, Types = 5 },
	VisitorWindowDays = 7,
}

-- Anti-abuse ------------------------------------------------------------------
Balance.RateLimits = { Buy = 0.5, Build = 0.08, Npc = 0.5, Run = 1.0, Rate = 1.0, Rebirth = 2.0, Generic = 0.2,
	-- audit 4.4: every Net.handle now reads its minimum interval (seconds per player) from HERE; values are the ones that were
	-- hard-coded in the services (unchanged). Build stays 0.08: one cheap server-side validation per click, no DataStore write.
	GetState = 0.5, GetShops = 0.3, Validate = 1, CourseName = 1, CourseSlots = 2, CancelRun = 0.5, NpcSlot = 0.25,
	Teleport = 2, Boards = 2, Decor = 0.25, GetDonate = 1, ClaimLogin = 2,
}
Balance.RatingEditCooldown = 3600       -- seconds before the same player may change a rating

-- Shops -------------------------------------------------------------------------
Balance.ShopObstacleSlots = 10
Balance.ShopNpcSlots = 6
Balance.ShopAssortmentSalt = { Obstacle = 7919, Npc = 104729 }

-- Moved here from code by the audit (2.3, session 8). VALUES UNCHANGED - only their home moved.
Balance.Shop = { MaxOwned = 99 }                                    -- ObstacleShopService: max copies of one obstacle
Balance.Build = { SaveSlots = 3, MagnetRange = 5 }                   -- BuildService course save slots; BuildController magnet reach (studs)
Balance.Data = { Autosave = 60, MaxTries = 4, MaxBytes = 3500000 }   -- PlayerDataService (MaxBytes < 4 MB DataStore limit); MaxTries also used by LeaderboardService
Balance.Run = { SpeedLimit = 170 }                                   -- ManualCourseRunService anti-cheat horizontal speed limit (studs/s)
Balance.Npc.KnockImpulse = { Horizontal = 55, Up = 26 }              -- NPCRunService knock (per unit of assembly mass)
Balance.Client = { BaseFov = 80, DefaultFov = 70 }                   -- FirstPersonController run FOV / normal FOV

return Balance
