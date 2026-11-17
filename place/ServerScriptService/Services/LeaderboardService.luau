--!nonstrict
-- Leaderboards (spec 15): TOP MONEY (current Coins), TOP REBIRTHS, TOP OBBY (course creators). Backed by OrderedDataStores; when the
-- store is unavailable the board falls back to the players in THIS server and says so (source = "server").
-- TOP OBBY = 10000 * sum(weight * normalised criterion), every term capped at 1 and weighted <= 0.20, so no single criterion can dominate.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CourseValidationService = require(script.Parent.CourseValidationService)
local Rating = require(script.Parent.RatingService)

local L = {}
local B = Balance.Boards
local SUFFIX = if RunService:IsStudio() then "_STUDIO" else ""
local STORE = { money = "TrapLab_TopMoney_v1" .. SUFFIX, rebirths = "TrapLab_TopRebirths_v1" .. SUFFIX, obby = "TrapLab_TopObby_v1" .. SUFFIX }
L.Kinds = { "money", "rebirths", "obby" }

local cache, names, lastWrite, lastValue = {}, {}, {}, {}

function L.ObbyScore(player)
	local p = PlayerDataService.Get(player)
	if not p then return 0 end
	local an = CourseValidationService.Analyze(player)
	if not an or not an.playerPlayable then return 0 end          -- an unfinished course does not rank
	local W, C = B.ObbyWeights, B.Caps
	local quality = math.min(#an.stages / C.Stages, 1) * 0.5 + math.min((an.typeCount or 0) / C.Types, 1) * 0.5
	if an.lowQuality then quality *= Balance.LowQualityMult end
	local clears = math.min(p.plot.clears or 0, C.Clears) / C.Clears                 -- successful clears by OTHER players
	local popularity = math.min(p.plot.plays or 0, C.Plays) / C.Plays               -- how often others started it
	local avg = Rating.Average(p)
	local ratings = math.clamp((avg - Balance.Rating.PriorMean) / (Balance.Rating.Max - Balance.Rating.PriorMean), 0, 1)   -- no votes = 0, never a free bonus
	local difficulty = (table.find(Balance.DifficultyOrder, an.difficulty) or 1) / #Balance.DifficultyOrder
	local cutoff, vis = os.time() - B.VisitorWindowDays * 86400, 0
	for _, t in p.plot.visitors or {} do if t >= cutoff then vis += 1 end end
	local activity = math.min(vis, C.Visitors) / C.Visitors                          -- distinct real visitors in the last week
	local s = W.Quality * quality + W.Clears * clears + W.Popularity * popularity + W.Ratings * ratings + W.Difficulty * difficulty + W.Activity * activity
	return math.floor(10000 * s + 0.5)
end

function L.Values(player)
	local p = PlayerDataService.Get(player)
	if not p then return nil end
	return { money = math.floor(p.coins), rebirths = p.rebirth, obby = L.ObbyScore(player) }
end

local function store(kind)
	local ok, s = pcall(function() return DataStoreService:GetOrderedDataStore(STORE[kind]) end)
	return if ok then s else nil
end

-- audit 1.6: retries with exponential backoff, same pattern as PlayerDataService.retry (2, 4, 8 s between tries)
local MAX_TRIES = Balance.Data and Balance.Data.MaxTries or 4
local function setWithRetry(s, key, value, kind)
	local lastErr = nil
	for i = 1, MAX_TRIES do
		local ok, err = pcall(function() s:SetAsync(key, value) end)
		if ok then return true end
		lastErr = err
		warn(("[Leaderboard] write %s try %d/%d failed: %s"):format(kind, i, MAX_TRIES, tostring(err)))
		if i < MAX_TRIES then task.wait(math.min(2 ^ i, 8)) end
	end
	return false, lastErr
end

-- Writes this player's changed values (rate-limited per player; OrderedDataStore budget is small)
function L.Flush(player, force)
	if PlayerDataService.IsMock() then return end           -- data not saved (DataStore down): never publish unverified values to the global boards
	if not force and os.clock() - (lastWrite[player] or -1e9) < B.WriteEvery then return end
	local vals = L.Values(player)
	if not vals then return end
	lastWrite[player] = os.clock()
	lastValue[player] = lastValue[player] or {}
	for _, kind in L.Kinds do
		local v = vals[kind]
		if v > 0 and lastValue[player][kind] ~= v then
			local s = store(kind)
			if s then
				local last = lastValue[player]
				if setWithRetry(s, tostring(player.UserId), v, kind) and last then last[kind] = v end
			end
		end
	end
end

local function nameOf(userId)
	local pl = Players:GetPlayerByUserId(userId)
	if pl then return pl.DisplayName end
	if names[userId] then return names[userId] end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	names[userId] = if ok then n else "Player"
	return names[userId]
end

local function serverRows(kind)
	local rows = {}
	for _, pl in Players:GetPlayers() do
		local vals = L.Values(pl)
		if vals and vals[kind] > 0 then table.insert(rows, { userId = pl.UserId, name = pl.DisplayName, value = vals[kind] }) end
	end
	table.sort(rows, function(a, b) return a.value > b.value end)
	while #rows > B.Size do table.remove(rows) end
	for i, r in rows do r.rank = i end
	return rows
end

-- { rows = { {rank, userId, name, value} }, source = "global" | "server" } (cached for Balance.Boards.ReadEvery seconds)
function L.Fetch(kind)
	local c = cache[kind]
	if c and os.clock() - c.t < B.ReadEvery then return c end
	local s = store(kind)
	local ok, rows = false, nil
	if s then
		ok, rows = pcall(function()
			local list = {}
			for i, e in s:GetSortedAsync(false, B.Size):GetCurrentPage() do
				local uid = tonumber(e.key)
				if uid and e.value > 0 then list[#list + 1] = { rank = i, userId = uid, name = nameOf(uid), value = e.value } end
			end
			return list
		end)
	end
	local res = if ok then { t = os.clock(), rows = rows, source = "global" } else { t = os.clock(), rows = serverRows(kind), source = "server" }
	cache[kind] = res
	return res
end

-- Courses of the players online now, best first (same TOP OBBY formula)
function L.Popular()
	local list = {}
	for _, pl in Players:GetPlayers() do
		local p = PlayerDataService.Get(pl)
		if p then
			local avg, votes = Rating.Average(p)
			local an = CourseValidationService.Analyze(pl)
			if an and an.playerPlayable then
				table.insert(list, { ownerId = pl.UserId, owner = pl.DisplayName, name = p.plot.name, rating = avg, votes = votes, plays = p.plot.plays or 0,
					clears = p.plot.clears or 0, difficulty = an.difficulty, stages = #an.stages, score = L.ObbyScore(pl) })
			end
		end
	end
	table.sort(list, function(a, b) return a.score > b.score end)
	return list
end

function L.Start()
	Net.handle("GetBoards", Balance.RateLimits.Boards, function(player)
		local boards = {}
		for _, kind in L.Kinds do boards[kind] = L.Fetch(kind) end
		return { ok = true, boards = boards, popular = L.Popular() }
	end)
	Players.PlayerRemoving:Connect(function(player) L.Flush(player, true); lastWrite[player] = nil; lastValue[player] = nil end)
	task.spawn(function()
		while true do
			task.wait(30)
			for _, pl in Players:GetPlayers() do task.spawn(L.Flush, pl) end
		end
	end)
end

return L
