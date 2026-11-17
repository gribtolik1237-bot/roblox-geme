--!nonstrict
-- Plot cosmetics (spec 17): a second goal for Coins. Bought and placed in one step on the owner's land, ONLY outside the course corridor (build zone +
-- start area + sign), never colliding, never queryable (see DecorModels). Limited per Rebirth (Progression.cosmeticLimit). Removing refunds 50%.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Progression = require(ReplicatedStorage.Configs.Progression)
local Decor = require(ReplicatedStorage.Configs.Decor)
local DecorModels = require(ReplicatedStorage.Shared.DecorModels)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local RewardService = require(script.Parent.RewardService)
local StateSync = require(script.Parent.StateSync)
local SessionService = require(script.Parent.SessionService)

local Service = {}
local models = {}     -- [player] = { [uid] = Model }
Service.RefundFraction = 0.5

-- Where decorations may stand (plot-local x/z, footprint radius r): on the owner's land cell, outside the corridor the course and start area use.
function Service.Allowed(profile, x, z, r)
	local size = Progression.plotSize(profile.rebirth)
	local halfW, len = size.X / 2 + 6, size.Y + 6
	local cell = Balance.PlotCell
	local inLand = math.abs(x) <= cell.X / 2 - r - 2 and z <= 90 - r - 2 and z >= -(cell.Y - 90) + r + 2
	local inCorridor = math.abs(x) < halfW + r and z < 24 + r and z > -len - r
	return inLand and not inCorridor
end

local function spawn(player, plot, rec)
	local m = DecorModels.build(rec.id)
	if not m then return end
	m:SetAttribute("Uid", rec.u)
	m:PivotTo(plot.cf * CFrame.new(rec.x, 0, rec.z) * CFrame.Angles(0, math.rad(rec.r), 0))
	m.Parent = plot.decor
	models[player] = models[player] or {}
	models[player][rec.u] = m
end

function Service.Place(player, req)
	local profile, plot = PlayerDataService.Get(player), PlotService.Get(player)
	if not profile or not plot then return { ok = false, err = "NoPlot" } end
	if type(req) ~= "table" or type(req.id) ~= "string" or not Decor.ById[req.id] then return { ok = false, err = "Invalid" } end
	if not (Net.isNum(req.x, -400, 400) and Net.isNum(req.z, -600, 400) and Net.isNum(req.r)) then return { ok = false, err = "Invalid" } end
	local def = Decor.ById[req.id]
	local list = profile.plot.decor
	if #list >= Progression.cosmeticLimit(profile.rebirth) then return { ok = false, err = "LimitReached" } end
	local x, z = math.floor(req.x + 0.5), math.floor(req.z + 0.5)
	local yaw = (math.floor(req.r / 15 + 0.5) * 15) % 360
	if not Service.Allowed(profile, x, z, def.r) then return { ok = false, err = "OutOfBounds" } end
	for _, o in list do                           -- no stacking on top of each other
		local od = Decor.ById[o.id]
		if od and math.sqrt((o.x - x) ^ 2 + (o.z - z) ^ 2) < (od.r + def.r) * 0.5 then return { ok = false, err = "Crowded" } end
	end
	if not RewardService.Spend(player, def.price) then return { ok = false, err = "NoCoins" } end   -- atomic check + deduct
	local uid = 1
	for _, o in list do uid = math.max(uid, o.u + 1) end
	local rec = { u = uid, id = def.id, x = x, z = z, r = yaw }
	table.insert(list, rec)
	spawn(player, plot, rec)
	PlayerDataService.MarkDirty(player); StateSync.Push(player)
	return { ok = true, uid = uid, x = x, z = z, r = yaw }
end

function Service.Remove(player, req)
	local profile = PlayerDataService.Get(player)
	if not profile or type(req) ~= "table" or not Net.isInt(req.uid, 1) then return { ok = false, err = "Invalid" } end
	for i, o in profile.plot.decor do
		if o.u == req.uid then
			table.remove(profile.plot.decor, i)
			local m = models[player] and models[player][o.u]
			if m then m:Destroy(); models[player][o.u] = nil end
			local def = Decor.ById[o.id]
			local back = def and math.floor(def.price * Service.RefundFraction) or 0
			if back > 0 then RewardService.Refund(player, back) end
			PlayerDataService.MarkDirty(player); StateSync.Push(player)
			return { ok = true, refund = back }
		end
	end
	return { ok = false, err = "NotFound" }
end

function Service.Start()
	StateSync.Provider("decor", function(player)
		local p = PlayerDataService.Get(player)
		return { count = #p.plot.decor, limit = Progression.cosmeticLimit(p.rebirth) }
	end)
	Net.handle("PlaceDecor", Balance.RateLimits.Decor, Service.Place)
	Net.handle("RemoveDecor", Balance.RateLimits.Decor, Service.Remove)
	SessionService.Ready.Event:Connect(function(player, profile, plot)
		models[player] = {}
		for _, rec in profile.plot.decor do spawn(player, plot, rec) end
	end)
	SessionService.Leaving.Event:Connect(function(player) models[player] = nil end)
end

return Service
