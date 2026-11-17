--!strict
-- Owner of every player's persistent profile. Versioned, session-locked, retried with backoff.
-- Studio without API access falls back to an in-memory mock with the same interface (DECISIONS D-010).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Configs.Balance)
local Util = require(ReplicatedStorage.Shared.Util)

local PlayerDataService = {}

local STORE_NAME = if RunService:IsStudio() then "TrapLab_Profiles_STUDIO_v1" else "TrapLab_Profiles_v1"
-- Seconds before another server's lock is considered dead. Studio stops kill the server before the final
-- save can release the lock, and the Studio store is separate from live servers, so a short value is safe there.
local LOCK_STALE = if RunService:IsStudio() then 3 else 120
-- audit 2.3: values live in Configs.Balance.Data (60 s / 4 tries / 3 500 000 bytes; DataStore hard limit is 4 MB)
local AUTOSAVE = Balance.Data.Autosave
local MAX_TRIES = Balance.Data.MaxTries
local MAX_BYTES = Balance.Data.MaxBytes
local SESSION = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
local lostLock: { [Player]: boolean } = {}
local store: any = nil
local usingMock = false
local started = false

PlayerDataService.Loaded = Instance.new("BindableEvent")   -- (player, profile)
PlayerDataService.Removing = Instance.new("BindableEvent") -- (player, profile) before the final save

-- In-memory store with the DataStore subset we use. JSON round-trip proves serialisability.
local Mock = {}
Mock.__index = Mock
function Mock.new() return setmetatable({ data = {} :: { [string]: string } }, Mock) end
function Mock:UpdateAsync(key: string, fn: (any) -> any)
	local raw = self.data[key]
	local old = if raw then HttpService:JSONDecode(raw) else nil
	local new = fn(old)
	if new == nil then return nil end
	self.data[key] = HttpService:JSONEncode(new)
	return HttpService:JSONDecode(self.data[key])
end
function Mock:GetAsync(key: string)
	local raw = self.data[key]
	return if raw then HttpService:JSONDecode(raw) else nil
end

local function template(): any
	return {
		version = Balance.DataVersion,
		coins = Balance.StartCoins, lifetime = 0, rebirth = 0,
		inv = {},
		npcs = { Starter = true },
		slots = { "Starter", false, false, false, false },
		plot = { objects = {}, decor = {}, version = 1, name = "My Course", changes = 0, nextUid = 1, plays = 0, clears = 0, visitors = {}, rating = { n = 0, sum = { 0, 0, 0, 0, 0 } }, raters = {} },
		stats = { manualRuns = 0, manualClears = 0, npcRuns = 0, npcStages = 0, npcFinishes = 0, earnedManual = 0, earnedNpc = 0 },
		daily = { day = 0, done = {}, bonusMult = 1, bonusUntil = 0, active = false, progress = 0, counted = {} },
		ratings = {},
		paid = {},          -- recent idempotency keys
		clears = {},        -- manual clears: ["ownerId:version"] = true
		attempts = {},      -- npc attempts per course version: [version] = {unix times}
		support = { donated = 0, receipts = {}, passes = {} },
		login = { streak = 0, claimedDay = 0 },   -- daily login gift (LoginRewardService)
		courseSaves = {},   -- 3 snapshots of the own course (T41): ["1".."3"] = { objects = {...}, n = count, t = unix }   -- Robux support shop (cosmetic only)
		meta = { created = os.time(), lastSave = 0, sessions = 0 },
	}
end
PlayerDataService.Template = template

-- FTUE: a brand-new profile gets the starter course (Balance.StarterCourse) placed and its items owned.
local function applyStarterCourse(data: any)
	for _, s in Balance.StarterCourse or {} do
		if s.id ~= "FinishPad" then data.inv[s.id] = (data.inv[s.id] or 0) + 1 end
		local uid = data.plot.nextUid
		data.plot.nextUid = uid + 1
		table.insert(data.plot.objects, { u = uid, id = s.id, x = s.x, y = s.y, z = s.z, r = s.r })
	end
	data.plot.version += 1
end
PlayerDataService.ApplyStarterCourse = applyStarterCourse

local function migrate(data: any)
	-- v1 is the first format. Future: if data.version < 2 then ... end
	Util.reconcile(data, template())
	data.version = Balance.DataVersion
end

local function key(p: Player): string return "P" .. p.UserId end

local function retry(fn: () -> any, tries: number): (boolean, any)
	local lastErr: any = nil
	for i = 1, tries do
		local ok, res = pcall(fn)
		if ok then return true, res end
		lastErr = res
		warn(("[PlayerData] try %d/%d failed: %s"):format(i, tries, tostring(res)))
		if i < tries then task.wait(math.min(2 ^ i, 8)) end
	end
	return false, lastErr
end

local function prune(profile: any)
	-- keep bounded tables bounded
	local function trim(t: { [any]: any }, limit: number)
		local n = Util.count(t)
		if n <= limit then return end
		for k in t do
			t[k] = nil
			n -= 1
			if n <= limit then break end
		end
	end
	trim(profile.paid, 200)
	trim(profile.clears, 300)
	trim(profile.attempts, 40)
	trim(profile.ratings, 200)
end

local function loadProfile(player: Player): any?
	for attempt = 1, 8 do
		local lockedByOther = false
		local ok, rec = retry(function()
			return store:UpdateAsync(key(player), function(old: any)
				if old and old.lock and old.lock.id ~= SESSION and os.time() - old.lock.t < LOCK_STALE then
					lockedByOther = true
					return nil
				end
				lockedByOther = false
				local r = old or {}
				r.lock = { id = SESSION, t = os.time() }
				return r
			end)
		end, MAX_TRIES)
		if not ok then return nil end
		if rec ~= nil then
			local isNew = rec.data == nil
			local data = rec.data or template()
			migrate(data)
			if isNew then applyStarterCourse(data) end
			data.meta.sessions += 1
			return data
		end
		if lockedByOther then
			warn(("[PlayerData] %s is locked by another session, waiting (%d/8)"):format(player.Name, attempt))
			task.wait(4)
		else
			return nil
		end
	end
	return nil
end

local queued: { [Player]: boolean } = {}

local function saveProfile(player: Player, profile: any, release: boolean): boolean
	if saving[player] then
		if not release then queued[player] = true end   -- never drop a save request: run it right after the current one
		return false
	end
	if lostLock[player] then return false end
	saving[player] = true
	prune(profile)
	local okSize, encoded = pcall(HttpService.JSONEncode, HttpService, profile)
	if not okSize then
		saving[player] = false
		warn("[PlayerData] profile not serialisable: " .. tostring(encoded))
		return false
	end
	if #encoded > MAX_BYTES then
		saving[player] = false
		warn(("[PlayerData] profile too large (%d bytes) - save refused"):format(#encoded))
		return false
	end
	local ok = retry(function()
		store:UpdateAsync(key(player), function(old: any)
			if old and old.lock and old.lock.id ~= SESSION and os.time() - old.lock.t < LOCK_STALE then
				lostLock[player] = true
				return nil
			end
			profile.meta.lastSave = os.time()
			return { data = profile, lock = if release then nil else { id = SESSION, t = os.time() } }
		end)
	end, MAX_TRIES)
	saving[player] = false
	if ok and not lostLock[player] then dirty[player] = false end
	if queued[player] and not release then
		queued[player] = nil
		task.defer(function() if profiles[player] == profile then saveProfile(player, profile, false) end end)
	end
	return ok and not lostLock[player]
end

local function onJoin(player: Player)
	local profile = loadProfile(player)
	if not profile then
		if player.Parent then player:Kick("TRAP LAB could not load your data. Please rejoin in a minute.") end
		return
	end
	if not player.Parent then
		saveProfile(player, profile, true)
		return
	end
	profiles[player] = profile
	dirty[player] = true
	PlayerDataService.Loaded:Fire(player, profile)
	-- autosave (also refreshes the session lock)
	task.spawn(function()
		task.wait(math.random() * 10)
		while profiles[player] do
			task.wait(AUTOSAVE)
			if profiles[player] then saveProfile(player, profile, false) end
		end
	end)
end

local function onLeave(player: Player)
	local profile = profiles[player]
	if not profile then return end
	PlayerDataService.Removing:Fire(player, profile)
	profiles[player] = nil
	while saving[player] do task.wait(0.1) end
	saveProfile(player, profile, true)
	dirty[player] = nil
	lostLock[player] = nil
	saving[player] = nil
end

function PlayerDataService.Start()
	if started then return end
	started = true
	local real = DataStoreService:GetDataStore(STORE_NAME)
	local ok, err = pcall(function() return real:GetAsync("__probe") end)
	-- Dev switch (Studio only): ServerStorage attribute DevFreshProfile = true -> every Play starts as a BRAND-NEW player in an
	-- in-memory store (FTUE tests) and NOTHING is saved, so the real Studio test profile can't be overwritten.
	if RunService:IsStudio() and game:GetService("ServerStorage"):GetAttribute("DevFreshProfile") == true then
		ok, err = false, "DevFreshProfile switch"
	end
	if ok then
		store = real
	elseif RunService:IsStudio() then
		usingMock = true
		store = Mock.new()
		warn("[PlayerData] DataStore unavailable in Studio (" .. tostring(err) .. ") -> IN-MEMORY MOCK. Progress is NOT saved.")
	else
		-- live server with a failing DataStore: keep the real store; loads will retry and kick safely
		store = real
		warn("[PlayerData] DataStore probe failed on a live server: " .. tostring(err))
	end
	Players.PlayerAdded:Connect(function(p) task.spawn(onJoin, p) end)
	Players.PlayerRemoving:Connect(function(p) task.spawn(onLeave, p) end)
	for _, p in Players:GetPlayers() do task.spawn(onJoin, p) end
	game:BindToClose(function()
		local pending = 0
		for p, prof in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(p, prof, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do task.wait(0.2) end
	end)
end

function PlayerDataService.Get(player: Player): any?
	return profiles[player]
end

function PlayerDataService.WaitFor(player: Player, timeout: number?): any?
	local t0 = os.clock()
	while player.Parent and not profiles[player] and os.clock() - t0 < (timeout or 60) do task.wait(0.1) end
	return profiles[player]
end

function PlayerDataService.MarkDirty(player: Player)
	dirty[player] = true
end

-- Force an immediate save (e.g. after a purchase or rebirth). Returns success.
function PlayerDataService.SaveNow(player: Player): boolean
	local prof = profiles[player]
	return prof ~= nil and saveProfile(player, prof, false)
end

function PlayerDataService.IsMock(): boolean return usingMock end
function PlayerDataService.StoreName(): string return STORE_NAME end

return PlayerDataService
