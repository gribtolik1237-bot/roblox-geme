--!strict
-- Daily login gift with a 7-day streak (retention D1/D7, skill roblox-game-design: ~24 h cycle, shown only AFTER the tutorial).
-- Server-authoritative: the day is the SERVER's UTC day (Balance.Login.ResetUtcHour), one claim per day, idempotent key "login:<day>".
-- Missing a day restarts the streak at day 1. Reward = Balance.Login.Rewards[streakDay] * (1 + rebirth) so it keeps meaning after Rebirths.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateSync = require(script.Parent.StateSync)
local RewardService = require(script.Parent.RewardService)

local Service = {}

local function today(): number
	return math.floor((os.time() - (Balance.Login.ResetUtcHour or 0) * 3600) / 86400)
end

local function login(p: any): any
	if type(p.login) ~= "table" then p.login = { streak = 0, claimedDay = 0 } end
	return p.login
end

-- the streak day the NEXT claim would give (1..7)
local function nextDay(l: any, d: number): number
	if l.claimedDay == d - 1 then return (l.streak % #Balance.Login.Rewards) + 1 end
	return 1
end

local function rewardFor(p: any, day: number): number
	return math.floor(Balance.Login.Rewards[day] * (1 + (p.rebirth or 0)))
end

function Service.Info(p: any): any
	local l, d = login(p), today()
	local can = l.claimedDay ~= d and (p.stats.npcRuns or 0) > 0     -- never before the first NPC run (tutorial first)
	local shown = if l.claimedDay == d then l.streak else nextDay(l, d)
	local rewards = {}
	for i in Balance.Login.Rewards do rewards[i] = rewardFor(p, i) end
	return { canClaim = can, day = shown, claimedToday = l.claimedDay == d, rewards = rewards }
end

function Service.Claim(player: Player): any
	local p = PlayerDataService.Get(player)
	if not p then return { ok = false, err = "NoProfile" } end
	local l, d = login(p), today()
	if l.claimedDay == d then return { ok = false, err = "AlreadyClaimed" } end
	if (p.stats.npcRuns or 0) <= 0 then return { ok = false, err = "Locked" } end
	local day = nextDay(l, d)
	l.claimedDay, l.streak = d, day                -- state first: a duplicate request in flight loses
	local got = RewardService.Grant(player, rewardFor(p, day), "login", "login:" .. d)
	PlayerDataService.MarkDirty(player)
	StateSync.Push(player)
	return { ok = true, amount = got, day = day }
end

function Service.Start()
	StateSync.Provider("login", function(player: Player)
		local p = PlayerDataService.Get(player)
		return if p then Service.Info(p) else nil
	end)
	Net.handle("ClaimLogin", Balance.RateLimits.ClaimLogin, Service.Claim)
end

return Service
