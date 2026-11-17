--!strict
-- The ONLY module that changes Coins. Idempotent grants, atomic spends, Daily multiplier on eligible sources.
-- Eligible for the Daily multiplier (BALANCE.md): manual-run rewards and NPC stage/finish rewards. Nothing else.
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateSync = require(script.Parent.StateSync)

local RewardService = {}

local MULTIPLIABLE: { [string]: boolean } = { manual = true, npcStage = true, npcFinish = true }
local LIFETIME_SOURCES: { [string]: boolean } = {
	manual = true, creator = true, npcStage = true, npcFinish = true, daily = true, achievement = true, login = true,
}

-- audit 1.5: the coin change is already in the profile; a failing dirty-mark or sync must not throw out of a grant (the caller would
-- think nothing was paid) and must not be silent. MarkDirty is retried once on the next frame so the autosave still picks it up.
local function commit(player: Player, what: string)
	local okDirty, e1 = pcall(PlayerDataService.MarkDirty, player)
	if not okDirty then
		warn(("[Reward] MarkDirty failed after %s for %s: %s - retrying"):format(what, player.Name, tostring(e1)))
		task.defer(function()
			local ok2, e2 = pcall(PlayerDataService.MarkDirty, player)
			if not ok2 then warn(("[Reward] MarkDirty retry failed for %s: %s"):format(player.Name, tostring(e2))) end
		end)
	end
	local okSync, e3 = pcall(StateSync.Push, player)
	if not okSync then warn(("[Reward] StateSync.Push failed after %s for %s: %s"):format(what, player.Name, tostring(e3))) end
end

function RewardService.Multiplier(player: Player): number
	local p = PlayerDataService.Get(player)
	if p and p.daily.bonusMult > 1 and os.time() < p.daily.bonusUntil then return p.daily.bonusMult end
	return 1
end

-- Returns the amount actually granted (0 if idempotency key already used / invalid / no profile).
function RewardService.Grant(player: Player, amount: number, source: string, idemKey: string?): number
	local p = PlayerDataService.Get(player)
	if not p then return 0 end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return 0 end
	if idemKey then
		if p.paid[idemKey] then return 0 end
		p.paid[idemKey] = os.time()           -- claimed BEFORE any yield: concurrent duplicates lose
	end
	local final = amount
	if MULTIPLIABLE[source] then final = amount * RewardService.Multiplier(player) end
	final = math.floor(final)
	if final <= 0 then return 0 end
	p.coins += final
	if LIFETIME_SOURCES[source] then p.lifetime += final end
	if source == "manual" or source == "creator" then p.stats.earnedManual += final end
	if source == "npcStage" or source == "npcFinish" then p.stats.earnedNpc += final end
	commit(player, "grant " .. source)
	return final
end

-- Atomic check-and-deduct (single-threaded Luau: no yield between check and write).
function RewardService.Spend(player: Player, amount: number): boolean
	local p = PlayerDataService.Get(player)
	if not p or type(amount) ~= "number" or amount < 0 or amount ~= amount then return false end
	if p.coins < amount then return false end
	p.coins -= amount
	commit(player, "spend")
	return true
end

-- Refund after a failed purchase step (never touches lifetime)
function RewardService.Refund(player: Player, amount: number)
	local p = PlayerDataService.Get(player)
	if p and amount > 0 then
		p.coins += amount
		commit(player, "refund")
	end
end

return RewardService
