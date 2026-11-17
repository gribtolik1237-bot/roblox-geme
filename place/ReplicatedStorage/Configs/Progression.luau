--!strict
-- Rebirth-indexed lookups over Balance. Pure functions; safe on client (display) and server (authority).
local Balance = require(script.Parent.Balance)
local P = {}

local function at(arr: { number }, r: number): number
	return arr[math.clamp(math.floor(r), 0, Balance.MaxRebirth) + 1]
end

function P.plotSize(r: number): Vector2
	return Vector2.new(at(Balance.PlotWidth, r), at(Balance.PlotLength, r))
end
function P.objectLimit(r: number): number return at(Balance.ObjectLimit, r) end
function P.cosmeticLimit(r: number): number return at(Balance.CosmeticLimit, r) end
function P.npcLimit(r: number): number
	return math.min(at(Balance.NpcLimit, r), Balance.NpcHardCap)
end
-- Lifetime Coins needed to REACH rebirth count r
function P.threshold(r: number): number
	return at(Balance.RebirthThreshold, r)
end
-- Threshold for the next rebirth, nil at max
function P.nextThreshold(r: number): number?
	if r >= Balance.MaxRebirth then return nil end
	return P.threshold(r + 1)
end
function P.canRebirth(r: number, lifetime: number): boolean
	local nxt = P.nextThreshold(r)
	return nxt ~= nil and lifetime >= nxt
end

return P
