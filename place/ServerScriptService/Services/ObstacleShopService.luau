--!strict
-- Obstacle shop catalog: obstacles are CONSUMABLE-COUNT items (owned count; placing uses one, removing frees it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Obstacles = require(ReplicatedStorage.Configs.Obstacles)
local ShopCore = require(script.Parent.ShopCore)

local Service = {}
local MAX_OWNED = Balance.Shop.MaxOwned   -- audit 2.3 (99)

function Service.Start()
	local n = 0
	for _, d in Obstacles.List do if not d.free then n += 1 end end
	-- show ~60% of the catalog per rotation (4..10 slots) so the shelf visibly changes as the catalog grows
	local count = math.clamp(math.floor(n * 0.6), 4, Balance.ShopObstacleSlots)
	ShopCore.register({
		kind = "obstacle", salt = Balance.ShopAssortmentSalt.Obstacle, catalog = Obstacles.List, count = count,
		staples = { "BasicPlatform" },   -- builders must never be stuck without the basic block
		groupOf = function(d: any) return d.category end,
		canBuy = function(profile: any, d: any): string?
			if (profile.inv[d.id] or 0) >= MAX_OWNED then return "MaxOwned" end
			return nil
		end,
		grant = function(_: Player, profile: any, d: any) profile.inv[d.id] = (profile.inv[d.id] or 0) + 1 end,
	})
end

return Service
