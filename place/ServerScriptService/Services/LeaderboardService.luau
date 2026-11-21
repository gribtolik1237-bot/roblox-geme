--!strict
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
type BoardRow = { rank: number, userId: number, name: string, value: number }
type Board = { t: number, rows: { BoardRow }, source: string }
local B = Balance.Boards
local SUFFIX = if RunService:IsStudio() then "_STUDIO" else ""
local STORE = { money = "TrapLab_TopMoney_v1" .. SUFFIX, rebirths = "TrapLab_TopRebirths_v1" .. SUFFIX, obby = "TrapLab_TopObby_v1" .. SUFFIX }
L.Kinds = { "money", "rebirths", "obby" }

local cache: { [string]: Board } = {}
local names: { [number]: { n: string, ok: boolean, t: number } } = {}   -- D039-2: failures are retried, not cached forever
local inflight: { [string]: boolean } = {}                              -- D039-1: one GetSortedAsync wave per board at a time
local lastWrite: { [Player]: number } = {}
local lastValue: { [Player]: { [string]: number } } = {}

function L.ObbyScore(player: Player): number
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

function L.Values(player: Player): { [string]: number }
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
local function setWithRetry(s: OrderedDataStore, key: string, value: number, kind: string)
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
function L.Flush(player: Player, force: boolean?)
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

local NAME_RETRY, NAME_BATCH = 90, 15
-- D039-1/2 (chief, S13): resolve up to 100 names in parallel batches (not 100 sequential web calls), keep a failure only for
-- NAME_RETRY seconds and show "User <id>" meanwhile, so a rate-limit hiccup no longer leaves "Player" on the board for good.
local function resolveNames(uids: { number })
	local todo: { number } = {}
	for _, uid in uids do
		if not Players:GetPlayerByUserId(uid) then
			local e = names[uid]
			if not e or (not e.ok and os.clock() - e.t > NAME_RETRY) then todo[#todo + 1] = uid end
		end
	end
	for i = 1, #todo, NAME_BATCH do
		local left = 0
		for j = i, math.min(i + NAME_BATCH - 1, #todo) do
			left += 1
			local uid = todo[j]
			task.spawn(function()
				local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, uid)
				names[uid] = { n = if ok and type(n) == "string" then n else ("User " .. uid), ok = ok and type(n) == "string", t = os.clock() }
				left -= 1
			end)
		end
		local t0 = os.clock()
		while left > 0 and os.clock() - t0 < 10 do task.wait(0.05) end
	end
end

local function nameOf(userId: number): string
	local pl = Players:GetPlayerByUserId(userId)
	if pl then return pl.DisplayName end
	local e = names[userId]
	return if e then e.n else ("User " .. userId)
end

local function serverRows(kind: string): { BoardRow }
	local rows: { BoardRow } = {}
	for _, pl in Players:GetPlayers() do
		local vals = L.Values(pl)
		if vals and vals[kind] > 0 then table.insert(rows, { rank = 0, userId = pl.UserId, name = pl.DisplayName, value = vals[kind] }) end
	end
	table.sort(rows, function(a, b) return a.value > b.value end)
	while #rows > B.Size do table.remove(rows) end
	for i, r in rows do r.rank = i end
	return rows
end

-- { rows = { {rank, userId, name, value} }, source = "global" | "server" } (cached for Balance.Boards.ReadEvery seconds)
function L.Fetch(kind: string): Board
	local c = cache[kind]
	if c and os.clock() - c.t < B.ReadEvery then return c end
	if inflight[kind] then          -- another caller is already refreshing this board: serve the old list, or wait for the new one
		if c then return c end
		local t0 = os.clock()
		while inflight[kind] and os.clock() - t0 < 30 do task.wait(0.2) end
		return cache[kind] or { t = os.clock(), rows = serverRows(kind), source = "server" }
	end
	inflight[kind] = true
	local okStore, s = pcall(store, kind)      -- chief P3-1: nothing below may throw while inflight is set
	if not okStore then s = nil end
	local rows: { BoardRow }? = nil
	if s then
		local ok, entries = pcall(function(): { any }
			local out = {}
			for i, e in s:GetSortedAsync(false, B.Size):GetCurrentPage() do
				local uid = tonumber(e.key)
				if uid and e.value > 0 then out[#out + 1] = { rank = i, userId = uid, value = e.value } end
			end
			return out
		end)
		if ok then
			local uids = {}
			for i, e in entries do uids[i] = e.userId end
			pcall(resolveNames, uids)
			rows = {}
			for i, e in entries do (rows :: any)[i] = { rank = e.rank, userId = e.userId, name = nameOf(e.userId), value = e.value } end
		end
	end
	local res: Board
	if rows then
		res = { t = os.clock(), rows = rows, source = "global" }
	else
		local okRows, sr = pcall(serverRows, kind)
		res = { t = os.clock(), rows = if okRows then sr else {}, source = "server" }
	end
	cache[kind] = res
	inflight[kind] = nil
	return res
end

-- Courses of the players online now, best first (same TOP OBBY formula)
function L.Popular(): { { ownerId: number, owner: string, name: string, rating: number, votes: number, plays: number, clears: number, difficulty: string, stages: number, score: number } }
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
		local boards: { [string]: Board } = {}
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
