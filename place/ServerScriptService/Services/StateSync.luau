--!strict
-- Builds the player's PUBLIC state snapshot and pushes it to that client (coalesced). Server -> client only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Progression = require(ReplicatedStorage.Configs.Progression)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local PlayerDataService = require(script.Parent.PlayerDataService)

local StateSync = {}
local providers: { [string]: (Player) -> any } = {}
local pending: { [Player]: boolean } = {}

-- Other services contribute a named sub-table (e.g. "plot", "npc") without StateSync knowing them.
function StateSync.Provider(name: string, fn: (Player) -> any)
	providers[name] = fn
end

function StateSync.Snapshot(player: Player): any?
	local p = PlayerDataService.Get(player)
	if not p then return nil end
	local npcs = {}
	for id in p.npcs do npcs[#npcs + 1] = id end
	table.sort(npcs)
	local snap: { [string]: any } = {
		coins = p.coins, lifetime = p.lifetime, rebirth = p.rebirth,
		nextThreshold = Progression.nextThreshold(p.rebirth),
		maxRebirth = Balance.MaxRebirth,
		inv = Util.deepCopy(p.inv), npcs = npcs, slots = Util.deepCopy(p.slots),
		stats = Util.deepCopy(p.stats),
		mock = PlayerDataService.IsMock(),
	}
	for name, fn in providers do
		local ok, v = pcall(fn, player)
		if ok then snap[name] = v else warn("[StateSync] provider " .. name .. ": " .. tostring(v)) end
	end
	return snap
end

function StateSync.Push(player: Player)
	if pending[player] then return end
	pending[player] = true
	task.delay(0.05, function()
		pending[player] = nil
		if not player.Parent then return end
		local s = StateSync.Snapshot(player)
		if s then Net.fire("State", player, s) end
	end)
end

return StateSync
