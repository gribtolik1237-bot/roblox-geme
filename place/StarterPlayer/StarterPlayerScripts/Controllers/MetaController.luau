--!nonstrict
-- Meta windows: Daily Challenges (+ active bonus pill), Popular courses, and the "Rate this course" popup shown after a clear. Display only: the server decides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Net = require(ReplicatedStorage.Shared.Net)
local Balance = require(ReplicatedStorage.Configs.Balance)
local HUDController = require(script.Parent.HUDController)
local Icons = require(ReplicatedStorage.Configs.Icons)
local StateController = require(script.Parent.StateController)

local C = UIKit.C
local Meta = {}
local daily, popular, rate = {}, {}, {}
local resetAt = 0
local bonus = { mult = 1, untilT = 0, serverTime = 0, at = 0 }

local function tierName(id) return if id == "SuperHard" then "Super Hard" else id end

-- DAILY ---------------------------------------------------------------------------------------
local TIER_COL = { Easy = C.green, Hard = C.orange, SuperHard = C.red }
-- session 8 (skill review G13): task, reward and status on separate lines; ONE challenge at a time is said on the button
-- ("Switch" + a second tap), because the server replaces the active challenge and its progress.
local anyActive, confirmTier, confirmUntil = false, nil, 0
local function refreshDaily()
	local r = Net.invoke("GetDaily")
	if not r.ok then return end
	resetAt = os.clock() + r.resetIn
	anyActive = false
	for _, t in r.tiers do if t.status == "active" then anyActive = true end end
	for _, t in r.tiers do
		local row = daily.rows[t.id]
		row.title.Text = t.title
		row.goal.Text = ("Task: clear %d course%s%s%s with PLAY"):format(t.goal, t.goal > 1 and "s" or "", t.minDifficulty ~= "Easy" and (" (" .. t.minDifficulty .. " or harder)") or "", t.othersOnly and " of other players" or "")
		local reward = ("Reward: x%d Coins for %d min"):format(t.mult, t.minutes)
		row.prog.Text = if t.status == "active" then ("Progress %d/%d   -   %s"):format(t.progress, t.goal, reward)
			elseif t.status == "done" then "Completed today!" else (reward .. " (starts when you finish)")
		local confirming = confirmTier == t.id and os.clock() < confirmUntil
		row.btn.Text = if t.status == "done" then "Done" elseif t.status == "active" then "In progress"
			elseif confirming then "Tap again" elseif anyActive then "Switch" else "Start"
		row.btn.Interactable = t.status == "available"
		row.btn.BackgroundColor3 = if t.status == "available" then (if anyActive then C.orange else C.green) elseif t.status == "active" then C.blue else C.panel2
	end
end

local function buildDaily()
	daily.win = UIKit.window(HUDController.Gui, "Daily Challenges", UDim2.fromOffset(760, 560), C.green, Icons.daily)
	local body = daily.win.body
	daily.info = UIKit.label(body, { Text = "", TextSize = 22, Size = UDim2.new(1, 0, 0, 32), TextColor3 = C.yellow, TextXAlignment = Enum.TextXAlignment.Left, stroke = 3.5 })
	daily.rows = {}
	for i, id in Balance.Daily.Order do
		local f = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 42 + (i - 1) * 132), BackgroundColor3 = Color3.new(1, 1, 1) }, body)
		UIKit.round(f, 16); UIKit.stroke(f, UIKit.INK, 4)
		UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(84, 88, 124), Color3.fromRGB(52, 55, 82)), Rotation = 90 }, f)
		UIKit.tag(f, string.upper(tierName(id)), TIER_COL[id] or C.teal, UDim2.fromOffset(130, 28), UDim2.fromOffset(14, 10), 16)
		local row = {}
		row.title = UIKit.label(f, { Size = UDim2.new(1, -200, 0, 32), Position = UDim2.fromOffset(14, 42), TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, stroke = 3.5 })
		row.goal = UIKit.label(f, { Font = UIKit.BODY, Size = UDim2.new(1, -200, 0, 22), Position = UDim2.fromOffset(14, 76), TextSize = 17, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2 })
		row.prog = UIKit.label(f, { Size = UDim2.new(1, -200, 0, 22), Position = UDim2.fromOffset(14, 96), TextSize = 18, TextColor3 = C.yellow, TextXAlignment = Enum.TextXAlignment.Left, stroke = 2.5 })
		row.btn = UIKit.button(f, { text = "Start", color = C.green, size = UDim2.fromOffset(160, 58), pos = UDim2.new(1, -176, 0.5, -29), textSize = 26, onClick = function()
			if anyActive and not (confirmTier == id and os.clock() < confirmUntil) then
				confirmTier, confirmUntil = id, os.clock() + 3
				HUDController.Toast("Your current challenge and its progress will be cancelled", "info")
				refreshDaily()
				return
			end
			confirmTier = nil
			local r = Net.invoke("StartDaily", { tier = id })
			if r.ok then HUDController.Toast("Challenge started: clear the course(s) with PLAY", "ok") else HUDController.Toast("Can't start now (" .. tostring(r.err) .. ")", "err") end
			refreshDaily()
		end })
		daily.rows[id] = row
	end
	daily.win.onOpen = refreshDaily
end

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

-- BONUS PILL ----------------------------------------------------------------------------------
local function remaining() return math.max(0, bonus.untilT - (bonus.serverTime + (os.clock() - bonus.at))) end

function Meta.Start()
	buildDaily(); buildPopular(); buildRate()
	HUDController.AddMenuButton("daily", "Daily", C.green, 6, function() daily.win.toggle() end)
	local col = HUDController.Gui:FindFirstChild("MenuColumn")
	local pill = UIKit.new("Frame", { Name = "BonusPill", Size = UDim2.fromOffset(240, 46), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.green, Visible = false }, HUDController.Gui)
	UIKit.round(pill, 16); UIKit.stroke(pill, UIKit.INK, 4); UIKit.gloss(pill, C.green:Lerp(Color3.new(1, 1, 1), 0.35), C.green:Lerp(Color3.new(0, 0, 0), 0.2))
	local pillText = UIKit.label(pill, { Text = "", TextSize = 24, Size = UDim2.fromScale(1, 1), TextColor3 = Color3.new(1, 1, 1), stroke = 3.5 })
	-- audit 2.1: event-driven. The pill is (re)evaluated on every state change and only counts down while a bonus is running;
	-- the Daily reset countdown only ticks while the Daily window is open.
	local pillLoop = false
	local function runPill()
		if pillLoop then return end
		pillLoop = true
		task.spawn(function()
			while bonus.mult > 1 and remaining() > 0 do
				local left = remaining()
				pill.Visible = true
				pillText.Text = ("x%d  %d:%02d"):format(bonus.mult, math.floor(left / 60), math.floor(left % 60))
				task.wait(1)
			end
			pill.Visible = false
			pillLoop = false
		end)
	end
	local function setBonus(s)
		if s and s.daily then bonus = { mult = s.daily.mult, untilT = s.daily.untilT, serverTime = s.serverTime or os.time(), at = os.clock() } end
		if bonus.mult > 1 and remaining() > 0 then runPill() else pill.Visible = false end
	end
	StateController.Changed.Event:Connect(setBonus)
	if StateController.State then setBonus(StateController.State) end
	local dailyLoop = false
	local baseOpen = daily.win.onOpen
	daily.win.onOpen = function()
		if baseOpen then baseOpen() end
		if dailyLoop then return end
		dailyLoop = true
		task.spawn(function()
			while daily.win.isOpen() do
				local left = math.max(0, resetAt - os.clock())
				daily.info.Text = ("New challenges in %dh %02dm (UTC midnight)"):format(math.floor(left / 3600), math.floor(left % 3600 / 60))
				task.wait(1)
			end
			dailyLoop = false
		end)
	end
	Net.on("OpenBoard", function(kind) if kind == "daily" then daily.win.open() elseif kind == "popular" then popular.win.open() end end)
	Net.on("RunState", function(p)       -- after clearing someone ELSE's course: offer to rate it
		if p.state == "end" and p.outcome == "cleared" and p.isSelf == false and p.ownerId then
			rate.owner = p.ownerId; rate.scores = { 3, 3, 3, 3, 3 }
			for i = 1, 5 do for s, b in rate.buttons[i] do b.BackgroundColor3 = if s <= 3 then C.yellow else C.panel2; b.TextColor3 = if s <= 3 then Color3.new(1, 1, 1) else C.muted end end
			task.delay(1.2, function() rate.win.open() end)
		end
	end)
end

return Meta
