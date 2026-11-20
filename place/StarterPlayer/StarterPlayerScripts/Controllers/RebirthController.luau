-- Rebirth window (v2 look): progress bar, "now > next" rows, what is new in the shops, what you keep, one big button. The server decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Configs = ReplicatedStorage.Configs
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)
local Icons = require(Configs.Icons)
local Progression = require(Configs.Progression)
local Obstacles = require(Configs.Obstacles)
local NPCs = require(Configs.NPCs)
local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)

local C = UIKit.C
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local RebirthController = {}
local win, rows, shopsText, fill, fillText, button, confirmUntil = nil, {}, nil, nil, nil, nil, 0
local shopsHead = nil
local GREEN = "#6BE04A"

local function unlocks(r)
	local list = {}
	for _, d in Obstacles.List do if d.rebirth == r and not d.free then list[#list + 1] = d.name end end
	for _, d in NPCs.List do if d.rebirth == r then list[#list + 1] = d.name .. " (NPC)" end end
	return list
end

local function setRow(i: number, cur: string, nxt: string?)
	local r = rows[i]
	r.Text = if nxt then ('%s  <font color="#FFCC24">></font>  <font color="%s">%s</font>'):format(cur, GREEN, nxt) else cur
end

local function refresh()
	local s = StateController.State
	if not s or not win then return end
	local r = s.rebirth
	local nextT = Progression.nextThreshold(r)
	if not nextT then
		-- session 8 (skill review G11: "MAX" repeated in every row and on the button): show the FINAL values once, say it once
		local cur = Progression.plotSize(r)
		setRow(1, ("%dx%d"):format(cur.X, cur.Y))
		setRow(2, tostring(Progression.objectLimit(r)))
		setRow(3, tostring(Progression.cosmeticLimit(r)))
		setRow(4, tostring(Progression.npcLimit(r)))
		shopsHead.Text = "ALL UNLOCKED"
		shopsText.Text = "Every trap and NPC is in the shops for you. Keep building and earning!"
		fill.Size = UDim2.fromScale(1, 1); fillText.Text = ("Rebirth %d - the highest"):format(r)
		button.Text = "HIGHEST REBIRTH REACHED"; button.BackgroundColor3 = C.panel2
		return
	end
	shopsHead.Text = ("NEW IN THE SHOPS AT REBIRTH %d"):format(r + 1)
	local cur, nxt = Progression.plotSize(r), Progression.plotSize(r + 1)
	setRow(1, ("%dx%d"):format(cur.X, cur.Y), ("%dx%d"):format(nxt.X, nxt.Y))
	setRow(2, tostring(Progression.objectLimit(r)), tostring(Progression.objectLimit(r + 1)))
	setRow(3, tostring(Progression.cosmeticLimit(r)), tostring(Progression.cosmeticLimit(r + 1)))
	setRow(4, tostring(Progression.npcLimit(r)), tostring(Progression.npcLimit(r + 1)))
	local un = unlocks(r + 1)
	shopsText.Text = if #un > 0 then table.concat(un, "  -  ") else "More rare items"
	local frac = math.clamp(s.lifetime / nextT, 0, 1)
	fill.Size = UDim2.fromScale(math.max(frac, 0.03), 1)
	fillText.Text = ("Lifetime Coins  %s / %s"):format(Util.fmt(s.lifetime), Util.fmt(nextT))
	local can = s.lifetime >= nextT
	if can then
		button.Text = if os.clock() < confirmUntil then "TAP AGAIN TO CONFIRM" else ("REBIRTH %d"):format(r + 1)
		button.BackgroundColor3 = C.green
	else
		button.Text = ("%s MORE COINS NEEDED"):format(Util.fmt(nextT - s.lifetime)); button.BackgroundColor3 = C.panel2
	end
end

local function celebrate(n)
	local gui = HUDController.Gui
	local flash = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.purple, BackgroundTransparency = 0.6, ZIndex = 40 }, gui)
	local t = UIKit.label(gui, { Text = ("REBIRTH %d!"):format(n), TextSize = 96, Size = UDim2.fromScale(1, 0.25), Position = UDim2.fromScale(0, 0.3), TextColor3 = C.yellow, ZIndex = 41, stroke = 8 })
	local sc = UIKit.new("UIScale", { Scale = 0.2 }, t)
	TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(flash, TweenInfo.new(1.4), { BackgroundTransparency = 1 }):Play()
	task.delay(2.2, function()
		TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.delay(0.6, function() flash:Destroy(); t:Destroy() end)
	end)
end

function RebirthController.Start()
	win = UIKit.window(HUDController.Gui, "Rebirth", UDim2.fromOffset(660, 540), C.purple, Icons.rebirth)
	local body = win.body
	-- progress bar
	local bar = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(26, 24, 40) }, body)
	UIKit.round(bar, 20); UIKit.stroke(bar, UIKit.INK, 4)
	fill = UIKit.new("Frame", { Size = UDim2.fromScale(0.03, 1), BackgroundColor3 = WHITE }, bar)
	UIKit.round(fill, 20); UIKit.gloss(fill, C.pink:Lerp(WHITE, 0.3), C.purple:Lerp(BLACK, 0.1))
	fillText = UIKit.label(bar, { Text = "", TextSize = 21, Size = UDim2.fromScale(1, 1), ZIndex = 3, stroke = 3 })
	-- "now > next" rows
	local names = { "Plot size", "Obstacle limit", "Decoration limit", "Active NPCs at once" }
	for i, nm in names do
		local row = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 52 + (i - 1) * 54), BackgroundColor3 = WHITE }, body)
		UIKit.round(row, 14); UIKit.stroke(row, UIKit.INK, 3)
		UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(76, 80, 112), Color3.fromRGB(50, 53, 78)), Rotation = 90 }, row)
		UIKit.label(row, { Text = nm, TextSize = 22, Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromOffset(16, 0), TextXAlignment = Enum.TextXAlignment.Left, stroke = 3 })
		rows[i] = UIKit.label(row, { Text = "", RichText = true, TextSize = 24, Size = UDim2.new(0.5, -16, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, stroke = 3 })
	end
	-- new in the shops
	local sb = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 72), Position = UDim2.fromOffset(0, 272), BackgroundColor3 = WHITE }, body)
	UIKit.round(sb, 14); UIKit.stroke(sb, UIKit.INK, 3)
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(88, 62, 128), Color3.fromRGB(56, 40, 90)), Rotation = 90 }, sb)
	shopsHead = UIKit.label(sb, { Text = "NEW IN THE SHOPS", TextSize = 16, Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(14, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.yellow, stroke = 2.5 })
	shopsText = UIKit.label(sb, { Text = "", Font = UIKit.BODY, TextSize = 19, TextWrapped = true, Size = UDim2.new(1, -28, 0, 40), Position = UDim2.fromOffset(14, 28), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, stroke = 2 })
	-- what is kept
	local kb = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 352), BackgroundColor3 = WHITE }, body)
	UIKit.round(kb, 14); UIKit.stroke(kb, UIKit.INK, 3)
	UIKit.gloss(kb, C.green:Lerp(WHITE, 0.15), C.green:Lerp(BLACK, 0.3))
	UIKit.label(kb, { Text = "You KEEP all Coins, buildings, items, NPCs and decorations", Font = UIKit.BODY, TextSize = 18, TextScaled = true, Size = UDim2.new(1, -20, 1, -6), Position = UDim2.fromOffset(10, 3), stroke = 2.5 })
	button = UIKit.button(body, { name = "Go", text = "REBIRTH", color = C.panel2, size = UDim2.new(1, 0, 0, 62), pos = UDim2.new(0, 0, 1, -62), textSize = 32, icon = Icons.rebirth, iconSize = 70, onClick = function()
		local s = StateController.State
		if not s then return end
		local nextT = Progression.nextThreshold(s.rebirth)
		if not nextT or s.lifetime < nextT then HUDController.Toast(UIKit.err(if nextT then "NotEnough" else "MaxRebirth"), "err"); return end
		if os.clock() > confirmUntil then confirmUntil = os.clock() + 3; refresh(); return end
		confirmUntil = 0
		local r = Net.invoke("Rebirth", { expect = s.rebirth + 1 })
		if not r.ok then HUDController.Toast(UIKit.err(r.err), "err") end
		refresh()
	end })
	HUDController.AddMenuButton("rebirth", "Rebirth", C.purple, 5, function() win.toggle() end)
	win.onOpen = refresh
	local lastRebirth = nil
	StateController.Changed.Event:Connect(function(s)
		if lastRebirth ~= nil and s.rebirth > lastRebirth then celebrate(s.rebirth) end
		lastRebirth = s.rebirth
		refresh()
	end)
end

return RebirthController
