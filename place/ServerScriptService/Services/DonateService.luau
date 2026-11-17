--!strict
-- Robux purchases (spec 23): every grant happens here, on the server, after Roblox confirms the purchase (ProcessReceipt / game pass ownership).
-- The only effects are cosmetic: profile.support.donated (a counter) and the player attribute "Supporter". No Coins, no gameplay power.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Donate = require(ReplicatedStorage.Configs.Donate)
local PlayerDataService = require(script.Parent.PlayerDataService)

local DonateService = {}
local MAX_RECEIPTS = 200

local function support(p: any): any
	if type(p.support) ~= "table" then p.support = { donated = 0, receipts = {}, passes = {} } end
	local s = p.support
	s.donated = s.donated or 0; s.receipts = s.receipts or {}; s.passes = s.passes or {}
	return s
end

local function isSupporter(s: any): boolean
	return s.donated >= Donate.SupporterMin or next(s.passes) ~= nil
end

local function refresh(player: Player)
	local p = PlayerDataService.Get(player)
	if not p then return end
	local s = support(p)
	player:SetAttribute("Supporter", isSupporter(s))
end

local function prune(receipts: { [string]: number })
	local n, oldestKey, oldest = 0, nil, math.huge
	for k, t in receipts do
		n += 1
		if t < oldest then oldest = t; oldestKey = k end
	end
	if n > MAX_RECEIPTS and oldestKey then receipts[oldestKey] = nil end
end

-- Grants the reward of ONE confirmed purchase. Returns true when the purchase is handled (also when it was already handled before).
function DonateService.Process(player: Player, kind: string, assetId: number, purchaseId: string, robux: number): boolean
	local item = Donate.findByAsset(kind, assetId)
	if not item then return false end                 -- not one of our configured items
	local p = PlayerDataService.Get(player)
	if not p then return false end                    -- profile not loaded: Roblox will retry the receipt
	local s = support(p)
	if kind == "Product" then
		if s.receipts[purchaseId] then return true end   -- idempotent: this receipt was already granted
		s.receipts[purchaseId] = os.time()               -- claimed before any yield
		prune(s.receipts)
		if type(robux) == "number" and robux > 0 and robux == robux then s.donated += math.floor(robux) end
	else
		s.passes[item.id] = true
	end
	PlayerDataService.MarkDirty(player)
	refresh(player)
	Net.fire("Notify", player, "Thank you for supporting TRAP LAB!", "ok")
	return true
end

local function onReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local ok, handled = pcall(DonateService.Process, player, "Product", info.ProductId, tostring(info.PurchaseId), info.CurrencySpent or 0)
	if not ok or not handled then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local saved = false
	pcall(function() saved = PlayerDataService.SaveNow(player) end)   -- persist BEFORE confirming, so a crash cannot lose a paid grant
	if not saved then return Enum.ProductPurchaseDecision.NotProcessedYet end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
DonateService.OnReceipt = onReceipt

-- reply of the GetDonate remote (also used by tests, since a RemoteFunction callback cannot be read back)
function DonateService.Info(player: Player): any
	local p = PlayerDataService.Get(player)
	local s = if p then support(p) else { donated = 0, receipts = {}, passes = {} }
	local items = {}
	for _, it in Donate.Items do
		table.insert(items, { id = it.id, configured = it.assetId > 0, owned = s.passes[it.id] == true })
	end
	return { ok = true, items = items, donated = s.donated, supporter = isSupporter(s), supporterMin = Donate.SupporterMin }
end

local function checkPasses(player: Player)
	local p = PlayerDataService.WaitFor(player, 60)
	if not p or not player.Parent then return end
	for _, item in Donate.Items do
		if item.kind == "GamePass" and item.assetId > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, item.assetId)
			if ok and owns then support(p).passes[item.id] = true end
		end
	end
	refresh(player)
end

function DonateService.Start()
	MarketplaceService.ProcessReceipt = onReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if not purchased then return end
		-- never trust the client's flag alone: confirm ownership with Roblox
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and owns then DonateService.Process(player, "GamePass", passId, "pass" .. passId, 0) end
	end)
	Players.PlayerAdded:Connect(function(pl) task.spawn(checkPasses, pl) end)
	for _, pl in Players:GetPlayers() do task.spawn(checkPasses, pl) end
	Net.handle("GetDonate", require(game:GetService("ReplicatedStorage").Configs.Balance).RateLimits.GetDonate, DonateService.Info)   -- audit 4.4
end

return DonateService
