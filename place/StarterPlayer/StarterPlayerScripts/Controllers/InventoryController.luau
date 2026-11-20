--!nonstrict
-- Inventory (spec 9, v2 look): tab 1 = obstacles you own (preview, name, rarity, free copies, search, "Use in building"), tab 2 = your NPC collection
-- (preview, rarity, stats, equip into a quick slot). Display only; purchases/slots are enforced by the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Net = require(ReplicatedStorage.Shared.Net)
local NPCRig = require(ReplicatedStorage.Shared.NPCRig)
local ObstacleModels = require(ReplicatedStorage.Shared.ObstacleModels)
local Obstacles = require(ReplicatedStorage.Configs.Obstacles)
local NPCs = require(ReplicatedStorage.Configs.NPCs)
local Icons = require(ReplicatedStorage.Configs.Icons)
local HUDController = require(script.Parent.HUDController)
local StateController = require(script.Parent.StateController)

local C = UIKit.C
local Inv = {}
local win, tabBtns, scroll, grid, search, count
local tab = "obstacles"
local CARD_W = 204
local CARD_H = { obstacles = 266, npcs = 306 }

local function render()
	local s = StateController.State
	if not s or not scroll then return end
	for _, c in scroll:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	grid.CellSize = UDim2.fromOffset(CARD_W, CARD_H[tab])
	local q = string.lower(search.Text or "")
	local shown = 0
	if tab == "obstacles" then
		for _, def in Obstacles.List do
			local owned = if def.free then math.huge else (s.inv[def.id] or 0)
			local placed = (s.plot and s.plot.placed and s.plot.placed[def.id]) or 0
			local left = if def.free then math.huge else owned - placed
			local match = q == "" or string.find(string.lower(def.name), q, 1, true) or string.find(string.lower(def.rarity), q, 1, true) or string.find(string.lower(def.category), q, 1, true)
			if owned > 0 and match then
				shown += 1
				local rc = UIKit.rarityColor(def.rarity)
				local k = UIKit.itemCard(scroll, { w = CARD_W, h = CARD_H.obstacles, rarity = rc, name = def.name, tag = def.rarity, order = shown })
				local m = ObstacleModels.build(def.id)
				if m then pcall(UIKit.preview, k.pv, m) end
				UIKit.label(k.card, { Text = if def.free then "always available" else (if left > 0 then ("Free x%d   (placed %d / %d)"):format(left, placed, owned) else ("All %d placed"):format(owned)), Font = UIKit.BODY, TextSize = 15, Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, k.y), TextColor3 = if left > 0 then C.yellow else C.red, stroke = 2 })
				UIKit.button(k.card, { text = "Use in building", color = if left > 0 then C.green else C.panel2, size = UDim2.new(1, -20, 0, 44), pos = UDim2.new(0, 10, 1, -54), textSize = 20, onClick = function()
					if left <= 0 then HUDController.Toast("All copies are already placed - buy more or remove one", "err"); return end
					win.close()
					local ok, BuildController = pcall(require, script.Parent.BuildController)
					if ok and BuildController.Select(def.id) then HUDController.Toast("Selected: " .. def.name .. " - click on your plot to place it", "ok") end
				end })
			end
		end
	else
		for _, id in s.npcs do
			local def = NPCs.ById[id]
			local match = q == "" or (def and (string.find(string.lower(def.name), q, 1, true) or string.find(string.lower(def.rarity), q, 1, true)))
			if def and match then
				shown += 1
				local rc = UIKit.rarityColor(def.rarity)
				local k = UIKit.itemCard(scroll, { w = CARD_W, h = CARD_H.npcs, rarity = rc, name = def.name, tag = def.rarity, order = shown })
				local ok, m = pcall(NPCRig.build, id)
				if ok and m then pcall(UIKit.preview, k.pv, m, { zoom = 1.1, dir = Vector3.new(0.55, 0.3, -1) }) end
				UIKit.statBars(k.card, def.stats, k.y)
				local slot = table.find(s.slots, id)
				UIKit.button(k.card, { text = if slot then ("In slot " .. slot) else "Equip in a slot", color = if slot then C.panel2 else C.purple, size = UDim2.new(1, -20, 0, 44), pos = UDim2.new(0, 10, 1, -54), textSize = 20, onClick = function()
					if slot then HUDController.Toast(id .. " is already in slot " .. slot, "info"); return end
					local target
					for i = 1, 5 do if not s.slots[i] then target = i; break end end      -- the first free quick slot, else slot 1
					local r = Net.invoke("SetSlot", { slot = target or 1, id = id })
					if r.ok then HUDController.Toast(("%s equipped in slot %d - open NPCs to place it"):format(id, target or 1), "ok") else HUDController.Toast("Couldn't equip (" .. tostring(r.err) .. ")", "err") end
				end })
			end
		end
	end
	count.Text = ("%d shown"):format(shown)
end

local function setTab(name)
	tab = name
	for n, b in tabBtns do UIKit.setTab(b, n == name) end
	render()
end

function Inv.Start()
	win = UIKit.window(HUDController.Gui, "Inventory", UDim2.fromOffset(920, 620), C.orange, Icons.inventory)
	tabBtns = {}
	for i, d in { { "obstacles", "Obstacles" }, { "npcs", "NPCs" } } do
		tabBtns[d[1]] = UIKit.button(win.body, { text = d[2], color = C.panel2, size = UDim2.fromOffset(150, 40), pos = UDim2.fromOffset((i - 1) * 160, 0), textSize = 22, onClick = function() setTab(d[1]) end })
	end
	search = UIKit.new("TextBox", { Size = UDim2.fromOffset(260, 40), Position = UDim2.new(1, -350, 0, 0), BackgroundColor3 = Color3.fromRGB(24, 24, 38), TextColor3 = C.text, PlaceholderText = "Search name / rarity", PlaceholderColor3 = C.muted, Text = "", Font = UIKit.BODY, TextSize = 19, ClearTextOnFocus = false }, win.body)
	UIKit.round(search, 12); UIKit.stroke(search, UIKit.INK, 3.5)
	count = UIKit.label(win.body, { Text = "", TextSize = 18, TextColor3 = C.muted, Size = UDim2.fromOffset(80, 40), Position = UDim2.new(1, -80, 0, 0) })
	scroll = UIKit.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 10, ScrollBarImageColor3 = C.muted, BorderSizePixel = 0 }, win.body)
	grid = UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(CARD_W, CARD_H.obstacles), CellPadding = UDim2.fromOffset(12, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, scroll)
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, scroll)
	search:GetPropertyChangedSignal("Text"):Connect(render)
	win.onOpen = function() setTab(tab) end
	StateController.Changed.Event:Connect(function() if win.isOpen() then render() end end)
end

return Inv
