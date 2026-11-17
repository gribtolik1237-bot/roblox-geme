--!nonstrict
-- Support shop window (spec 23): window + HUD button ONLY - no building and no teleport by design. Shows the items from Configs/Donate; an item whose
-- assetId is still 0 is disabled ("Not set up yet"), so nothing can be bought that does not exist. Real purchases go through MarketplaceService prompts
-- and are granted by the SERVER (DonateService) - this client never grants anything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Net = require(ReplicatedStorage.Shared.Net)
local Donate = require(ReplicatedStorage.Configs.Donate)
local HUDController = require(script.Parent.HUDController)
local Icons = require(ReplicatedStorage.Configs.Icons)

local C = UIKit.C
local PINK = Color3.fromRGB(255, 112, 160)
local COLORS = { teal = C.teal, green = C.green, orange = C.orange, purple = C.purple }
local DonateController = {}
local win, header, grid
local cards = {}      -- id -> { btn, price }
local priceCache = {} -- assetId -> "R$ 25" | false

local function fetchPrice(item, label)
	if item.assetId <= 0 then return end
	if priceCache[item.assetId] ~= nil then label.Text = priceCache[item.assetId] or "price unavailable" return end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(item.assetId, if item.kind == "GamePass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
		end)
		local txt = if ok and info and info.PriceInRobux then ("R$ " .. info.PriceInRobux) else false
		priceCache[item.assetId] = txt
		if label.Parent then label.Text = txt or "price unavailable" end
	end)
end

local function buy(item)
	if item.assetId <= 0 then HUDController.Toast("This item is not available yet", "info") return end
	local ok = pcall(function()
		if item.kind == "GamePass" then MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, item.assetId)
		else MarketplaceService:PromptProductPurchase(Players.LocalPlayer, item.assetId) end
	end)
	if not ok then HUDController.Toast("Couldn't open the purchase window", "err") end
end

local function refresh()
	local r = Net.invoke("GetDonate")
	local owned = {}
	if r.ok then
		for _, it in r.items do owned[it.id] = it.owned end
		-- session 8 (skill review G14): the Supporter threshold is a TOTAL of all tips - say "in total" and show the running sum
		local need = r.supporterMin or 50
		header.Text = if r.supporter then "Supporter mark: ON - thank you!" .. (if r.donated > 0 then ("  (your tips: R$ %d)"):format(r.donated) else "")
			elseif r.donated > 0 then ("Your tips so far: R$ %d of R$ %d in total for the Supporter mark"):format(r.donated, need)
			else ("Optional tips. R$ %d in total (or the pass) unlocks the Supporter mark."):format(need)
	end
	for _, item in Donate.Items do
		local c = cards[item.id]
		if c then
			if item.assetId <= 0 then
				c.btn.Text = "Not set up yet"; c.btn.BackgroundColor3 = C.muted; c.price.Text = "coming soon"
			elseif owned[item.id] then
				c.btn.Text = "OWNED"; c.btn.BackgroundColor3 = C.panel
			else
				c.btn.Text = "SUPPORT"; c.btn.BackgroundColor3 = C.green
				fetchPrice(item, c.price)
			end
		end
	end
end

function DonateController.Start()
	win = UIKit.window(HUDController.Gui, "Support the game", UDim2.fromOffset(920, 540), PINK, Icons.donate)
	task.spawn(function() -- warm the icons so no card ever shows an empty tile when the window opens
		local list = {}
		for _, it in Donate.Items do
			if it.icon and it.icon ~= "" then local im = Instance.new("ImageLabel"); im.Image = it.icon; table.insert(list, im) end
		end
		pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
		for _, im in list do im:Destroy() end
	end)
	header = UIKit.label(win.body, { Text = "", TextSize = 22, TextColor3 = C.yellow, Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, stroke = 3.5 })
	grid = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -82), Position = UDim2.fromOffset(0, 40) }, win.body)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	for i, item in Donate.Items do
		local col = COLORS[item.color] or C.teal
		local k = UIKit.itemCard(grid, { w = 204, h = 360, rarity = col, name = item.name, tag = item.tag, pvH = 168, order = i })
		k.card.Name = item.id
		if item.icon and item.icon ~= "" then
			local pic = UIKit.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = item.icon, ScaleType = Enum.ScaleType.Crop }, k.pv)
			UIKit.round(pic, 12)
		end
		UIKit.label(k.card, { Text = item.desc, Font = UIKit.BODY, TextSize = 13, TextWrapped = true, TextColor3 = Color3.fromRGB(232, 236, 252), TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -20, 0, 54), Position = UDim2.fromOffset(10, k.y + 4), stroke = 1.4 })
		local price = UIKit.label(k.card, { Text = "", TextSize = 22, TextColor3 = C.yellow, Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0, 4, 1, -92), stroke = 3 })
		local btn = UIKit.button(k.card, { text = "SUPPORT", color = C.green, size = UDim2.new(1, -20, 0, 46), pos = UDim2.new(0, 10, 1, -56), textSize = 24, onClick = function() buy(item) end })
		cards[item.id] = { btn = btn, price = price }
	end
	UIKit.label(win.body, { Text = Donate.Note, Font = UIKit.BODY, TextSize = 16, TextWrapped = true, TextColor3 = C.muted, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -34), TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.6 })
	win.onOpen = refresh
	HUDController.AddMenuButton("donate", "Donate", PINK, 10, function() win.toggle() end)
end

return DonateController
