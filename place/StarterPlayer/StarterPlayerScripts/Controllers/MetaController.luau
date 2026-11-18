--!nonstrict
-- Meta windows: Popular Courses and the "Rate this course" popup shown after a clear. Display only: the server decides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Net = require(ReplicatedStorage.Shared.Net)
local Balance = require(ReplicatedStorage.Configs.Balance)
local HUDController = require(script.Parent.HUDController)
local Icons = require(ReplicatedStorage.Configs.Icons)

local C = UIKit.C
local Meta = {}
local popular, rate = {}, {}

-- POPULAR -------------------------------------------------------------------------------------
local function refreshPopular()
	local r = Net.invoke("GetBoards")
	if not r.ok then return end
	for _, c in popular.list:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	local MEDAL = { Color3.fromRGB(255, 200, 40), Color3.fromRGB(205, 212, 228), Color3.fromRGB(218, 142, 72) }
	for i, c in r.popular do
		local f = UIKit.new("Frame", { Size = UDim2.new(1, -12, 0, 72), LayoutOrder = i, BackgroundColor3 = Color3.new(1, 1, 1) }, popular.list)
		UIKit.round(f, 16); UIKit.stroke(f, UIKit.INK, 3.5)
		UIKit.new("UIGradient", { Color = if i == 1 then ColorSequence.new(Color3.fromRGB(150, 118, 44), Color3.fromRGB(96, 76, 38)) else ColorSequence.new(Color3.fromRGB(84, 88, 124), Color3.fromRGB(52, 55, 82)), Rotation = 90 }, f)
		local medal = UIKit.new("Frame", { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(10, 12), BackgroundColor3 = MEDAL[i] or C.panel2 }, f)
		UIKit.round(medal, 24); UIKit.stroke(medal, UIKit.INK, 3.5)
		UIKit.label(medal, { Text = tostring(i), TextSize = 26, Size = UDim2.fromScale(1, 1), stroke = 3 })
		UIKit.label(f, { Text = c.name, TextSize = 24, Size = UDim2.new(0.45, -60, 0, 32), Position = UDim2.fromOffset(68, 6), TextXAlignment = Enum.TextXAlignment.Left, stroke = 3 })
		UIKit.label(f, { Text = ("by %s  -  %s, %d stages"):format(c.owner, c.difficulty, c.stages), Font = UIKit.BODY, TextSize = 15, TextColor3 = C.muted, Size = UDim2.new(0.45, -60, 0, 22), Position = UDim2.fromOffset(68, 40), TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.8 })
		UIKit.label(f, { Text = ("%.1f stars  (%d votes)"):format(c.rating, c.votes), TextSize = 21, TextColor3 = C.yellow, Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.new(0.45, 0, 0, 0), stroke = 3 })
		UIKit.label(f, { Text = ("%d plays - %d clears"):format(c.plays, c.clears), Font = UIKit.BODY, TextSize = 16, TextColor3 = C.muted, Size = UDim2.new(0.25, -10, 1, 0), Position = UDim2.new(0.75, 0, 0, 0), stroke = 1.8 })
	end
	popular.empty.Visible = #r.popular == 0
end

local function buildPopular()
	popular.win = UIKit.window(HUDController.Gui, "Popular Courses", UDim2.fromOffset(800, 540), C.orange, Icons.popular)
	popular.list = UIKit.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, BorderSizePixel = 0 }, popular.win.body)
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, popular.list)
	popular.empty = UIKit.label(popular.win.body, { Text = "No finished courses online right now.", TextSize = 22, TextColor3 = C.muted, Size = UDim2.fromScale(1, 0.2), Position = UDim2.fromScale(0, 0.4), Visible = false })
	popular.win.onOpen = refreshPopular
end

-- RATE ----------------------------------------------------------------------------------------
local function buildRate()
	rate.win = UIKit.window(HUDController.Gui, "Rate this course", UDim2.fromOffset(560, 470), C.yellow)
	rate.scores = { 3, 3, 3, 3, 3 }
	rate.buttons = {}
	local function paint(i)
		for s, b in rate.buttons[i] do b.BackgroundColor3 = if s <= rate.scores[i] then C.yellow else C.panel2; b.TextColor3 = if s <= rate.scores[i] then Color3.new(1, 1, 1) else C.muted end
	end
	for i, name in Balance.Rating.Criteria do
		UIKit.label(rate.win.body, { Text = name, TextSize = 20, Size = UDim2.fromOffset(190, 40), Position = UDim2.fromOffset(0, (i - 1) * 56), TextXAlignment = Enum.TextXAlignment.Left })
		rate.buttons[i] = {}
		for s = 1, 5 do
			local b = UIKit.button(rate.win.body, { text = tostring(s), color = C.panel2, size = UDim2.fromOffset(52, 40), pos = UDim2.fromOffset(200 + (s - 1) * 60, (i - 1) * 56), textSize = 22, onClick = function() rate.scores[i] = s; paint(i) end })
			rate.buttons[i][s] = b
		end
		paint(i)
	end
	rate.info = UIKit.label(rate.win.body, { Text = "1 = poor ... 5 = great. You can change your vote once an hour.", TextSize = 15, TextColor3 = C.muted, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 288) })
	UIKit.button(rate.win.body, { text = "Send rating", color = C.green, size = UDim2.fromOffset(200, 52), pos = UDim2.new(0.5, -100, 0, 322), textSize = 24, onClick = function()
		local r = Net.invoke("Rate", { owner = rate.owner, scores = rate.scores })
		if r.ok then HUDController.Toast(("Thanks! Course rating: %.1f stars (%d votes)"):format(r.average, r.votes), "ok"); rate.win.close()
		else HUDController.Toast(({ Cooldown = "You already rated this course recently", NotCleared = "Clear the course first", OwnCourse = "You can't rate your own course", NotAvailable = "The owner left" })[r.err] or "Rating failed", "err") end
	end })
end

function Meta.Start()
	buildPopular()
	buildRate()
	Net.on("OpenBoard", function(kind)
		if kind == "popular" then popular.win.open() end
	end)
	Net.on("RunState", function(p)       -- after clearing someone ELSE's course: offer to rate it
		if p.state == "end" and p.outcome == "cleared" and p.isSelf == false and p.ownerId then
			rate.owner = p.ownerId; rate.scores = { 3, 3, 3, 3, 3 }
			for i = 1, 5 do for s, b in rate.buttons[i] do b.BackgroundColor3 = if s <= 3 then C.yellow else C.panel2; b.TextColor3 = if s <= 3 then Color3.new(1, 1, 1) else C.muted end end
			task.delay(1.2, function() rate.win.open() end)
		end
	end)
end

return Meta
