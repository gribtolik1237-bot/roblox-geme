--!nonstrict
-- Daily Challenges (spec 14). Easy / Hard / Super Hard (Balance.Daily): accept a challenge, clear the required number of DIFFERENT courses by hand,
-- get a Coins multiplier for a limited time. The multiplier only affects Coins sources that already exist (RewardService.MULTIPLIABLE);
-- the challenge itself pays NO Coins. All state is server-side in the profile: reconnecting cannot re-apply a bonus, and the day changes
-- on the SERVER clock (UTC, Balance.Daily.ResetUtcHour) - changing the device clock does nothing. One completion per tier per day.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateSync = require(script.Parent.StateSync)

local Daily = {}
local D = Balance.Daily

function Daily.DayIndex() return math.floor((os.time() - D.ResetUtcHour * 3600) / 86400) end
function Daily.SecondsToReset() return (Daily.DayIndex() + 1) * 86400 + D.ResetUtcHour * 3600 - os.time() end

local function rolloverIfNewDay(profile)
	local d = profile.daily
	local today = Daily.DayIndex()
	if d.day ~= today then d.day = today; d.done = {}; d.active = false; d.progress = 0; d.counted = {} end   -- the running bonus is untouched: it just expires
end

local function bonusInfo(d)
	local left = d.bonusUntil - os.time()
	if d.bonusMult > 1 and left > 0 then return { mult = d.bonusMult, remaining = left } end
	return { mult = 1, remaining = 0 }
end

function Daily.View(player)
	local p = PlayerDataService.Get(player)
	if not p then return { ok = false, err = "NoProfile" } end
	rolloverIfNewDay(p)
	local tiers = {}
	for _, id in D.Order do
		local t = D[id]
		local status = if p.daily.done[id] then "done" elseif p.daily.active == id then "active" else "available"
		table.insert(tiers, { id = id, title = t.title, mult = t.mult, minutes = t.minutes, goal = t.goalRuns, minDifficulty = Balance.DifficultyOrder[t.minDifficulty],
			othersOnly = t.othersOnly, status = status, progress = if p.daily.active == id then p.daily.progress else 0 })
	end
	return { ok = true, tiers = tiers, resetIn = Daily.SecondsToReset(), bonus = bonusInfo(p.daily) }
end

function Daily.Accept(player, req)
	local p = PlayerDataService.Get(player)
	if not p then return { ok = false, err = "NoProfile" } end
	local id = if type(req) == "table" then req.tier else nil
	if type(id) ~= "string" or not table.find(D.Order, id) then return { ok = false, err = "Invalid" } end
	rolloverIfNewDay(p)
	if p.daily.done[id] then return { ok = false, err = "Done" } end
	if p.daily.active ~= id then p.daily.active = id; p.daily.progress = 0; p.daily.counted = {} end   -- progress counts only from acceptance
	PlayerDataService.MarkDirty(player); StateSync.Push(player)
	return Daily.View(player)
end

local function complete(player, p, id)
	local t, d = D[id], p.daily
	d.done[id] = true; d.active = false; d.progress = 0; d.counted = {}                   -- marked BEFORE the bonus: a duplicate event finds it done
	local now, cur = os.time(), bonusInfo(d)
	local untilT = now + t.minutes * 60
	if cur.mult > 1 then untilT = math.max(untilT, now + cur.remaining) end              -- bonuses never stack: best multiplier, longest time
	d.bonusMult = math.max(t.mult, cur.mult); d.bonusUntil = untilT
	PlayerDataService.MarkDirty(player); StateSync.Push(player)
	Net.fire("Notify", player, ("Daily challenge complete! x%d Coins for %d min"):format(d.bonusMult, math.ceil((untilT - now) / 60)), "ok")
end

-- Called for every cleared manual run. info.run: ownerId, version, difficulty, isSelf
function Daily.OnCleared(player, info)
	local p = PlayerDataService.Get(player)
	local run = info and info.run
	if not p or not run then return end
	if info.reason == "tooFast" or info.reason == "noProfile" then return end        -- a clear the server judged suspicious / unverified never counts
	rolloverIfNewDay(p)
	local id = p.daily.active
	if not id then return end
	local t = D[id]
	if t.othersOnly and run.isSelf then return end
	if (table.find(Balance.DifficultyOrder, run.difficulty) or 1) < t.minDifficulty then return end
	local key = run.ownerId .. ":" .. run.version
	if p.daily.counted[key] then return end                                               -- the same course version never counts twice
	p.daily.counted[key] = true
	p.daily.progress += 1
	if p.daily.progress >= t.goalRuns then complete(player, p, id)
	else
		PlayerDataService.MarkDirty(player); StateSync.Push(player)
		Net.fire("Notify", player, ("Daily challenge: %d/%d"):format(p.daily.progress, t.goalRuns), "info")
	end
end

function Daily.Start()
	local Manual = require(script.Parent.ManualCourseRunService)
	Net.handle("GetDaily", Balance.RateLimits.GetDaily, Daily.View)
	Net.handle("StartDaily", Balance.RateLimits.StartDaily, Daily.Accept)
	Manual.Cleared.Event:Connect(Daily.OnCleared)
end

return Daily
