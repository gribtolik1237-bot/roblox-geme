--!strict
-- Shared shop machinery (rotation sync, purchase pipeline). Obstacle shop and NPC shop are separate catalogs
-- registered by their own services; they share only time/authority/sync/purchase-safety rules (spec 7.6).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarities = require(ReplicatedStorage.Configs.Rarities)
local Balance = require(ReplicatedStorage.Configs.Balance)
local Net = require(ReplicatedStorage.Shared.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local RewardService = require(script.Parent.RewardService)
local StateSync = require(script.Parent.StateSync)
local Rotation = require(script.Parent.Parent.Systems.ShopRotation)

local ShopCore = {}

export type Spec = {
	kind: string, salt: number, catalog: { any }, count: number, staples: { string }?,
	groupOf: ((any) -> string?)?, canBuy: (any, any) -> string?, grant: (Player, any, any) -> (),
}
local shops: { [string]: { spec: Spec, byId: { [string]: any }, cache: { slot: number, ids: { string } }? } } = {}
local lastSaveAt: { [Player]: number } = {}

function ShopCore.register(spec: Spec)
	local byId = {}
	for _, d in spec.catalog do byId[d.id] = d end
	shops[spec.kind] = { spec = spec, byId = byId, cache = nil }
end

local function assortment(shop: any, slot: number): { string }
	if shop.cache and shop.cache.slot == slot then return shop.cache.ids end
	local items: { Rotation.Item } = {}
	for _, d in shop.spec.catalog do
		if not d.free then
			items[#items + 1] = { id = d.id, weight = Rarities.Info[d.rarity].weight, group = if shop.spec.groupOf then shop.spec.groupOf(d) else nil }
		end
	end
	local ids = Rotation.pick(slot, shop.spec.salt, items, math.min(shop.spec.count, #items), shop.spec.staples)
	shop.cache = { slot = slot, ids = ids }
	return ids
end

function ShopCore.Assortment(kind: string, slot: number?): { string }
	return assortment(shops[kind], slot or Rotation.slotIndex())
end

local function payload(): any
	local slot = Rotation.slotIndex()
	local out: { [string]: any } = { now = workspace:GetServerTimeNow(), interval = Balance.ShopIntervalSeconds, slot = slot, nextRefresh = Rotation.nextRefresh(slot) }
	for kind, shop in shops do out[kind] = assortment(shop, slot) end
	return out
end

function ShopCore.Buy(player: Player, req: any): any
	if type(req) ~= "table" or not Net.isId(req.id) or type(req.shop) ~= "string" then return { ok = false, err = "Invalid" } end
	local shop = shops[req.shop]
	local profile = PlayerDataService.Get(player)
	if not shop then return { ok = false, err = "Invalid" } end
	if not profile then return { ok = false, err = "NoProfile" } end
	local def = shop.byId[req.id]
	if not def or def.free then return { ok = false, err = "Unknown" } end
	-- must be on the server's CURRENT shelf (previous shelf honoured for 3 s after a refresh)
	local slot = Rotation.slotIndex()
	local inStock = table.find(assortment(shop, slot), req.id) ~= nil
	if not inStock and workspace:GetServerTimeNow() - slot * Balance.ShopIntervalSeconds < 3 then
		inStock = table.find(assortment(shop, slot - 1), req.id) ~= nil
	end
	if not inStock then return { ok = false, err = "NotInStock" } end
	if def.rebirth > profile.rebirth then return { ok = false, err = "Locked", need = def.rebirth } end
	local err = shop.spec.canBuy(profile, def)
	if err then return { ok = false, err = err } end
	-- check-and-deduct is atomic (no yield), so duplicate/concurrent requests cannot both pass
	if not RewardService.Spend(player, def.price) then return { ok = false, err = "NoCoins" } end
	shop.spec.grant(player, profile, def)
	PlayerDataService.MarkDirty(player)
	StateSync.Push(player)
	-- persist valuable purchases soon (throttled; autosave covers the rest)
	if os.clock() - (lastSaveAt[player] or -100) > 8 then
		lastSaveAt[player] = os.clock()
		task.delay(1.5, function() if player.Parent then PlayerDataService.SaveNow(player) end end)
	end
	return { ok = true, id = def.id, coins = profile.coins }
end

function ShopCore.Start()
	-- audit 1.2: the save throttle table must not keep departed players
	game:GetService("Players").PlayerRemoving:Connect(function(player: Player) lastSaveAt[player] = nil end)
	Net.handle("GetShops", Balance.RateLimits.GetShops, function() local p = payload(); p.ok = true; return p end)
	Net.handle("Buy", Balance.RateLimits.Buy, ShopCore.Buy)
	task.spawn(function()
		local last = Rotation.slotIndex()
		while true do
			task.wait(1)
			local s = Rotation.slotIndex()
			if s ~= last then last = s; Net.fireAll("ShopSync", payload()) end
		end
	end)
end

return ShopCore
