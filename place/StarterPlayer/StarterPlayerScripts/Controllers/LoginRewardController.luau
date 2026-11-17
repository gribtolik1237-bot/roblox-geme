-- Daily login gift window (LoginRewardService). Opens by itself once per session, a few seconds after joining, only when the server
-- says a claim is possible (after the tutorial's first NPC run). 7 day tiles, today's tile highlighted, one big green Claim button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)
local Icons = require(ReplicatedStorage.Configs.Icons)
local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)
local SfxController = require(script.Parent.SfxController)

local C = UIKit.C
local WHITE = Color3.new(1, 1, 1)
local Controller = {}
local win, tiles, claimBtn = nil, {}, nil
local shownThisSession = false
local busy = false

local function render(info: any)
	if not win or not info then return end
	for i, t in tiles do
		local amount = info.rewards[i] or 0
		t.amount.Text = Util.fmt(amount)
		local done = i < info.day or (info.claimedToday and i == info.day)
		local today = i == info.day and not info.claimedToday
		local base = if i == 7 then C.purple elseif done then C.green elseif today then C.yellow else Color3.fromRGB(78, 82, 116)
		t.grad.Color = ColorSequence.new(base:Lerp(WHITE, 0.3), base:Lerp(Color3.new(0, 0, 0), 0.2))
		t.stroke.Color = UIKit.INK                       -- thick ink outline always (owner references); today = fatter + bigger
		t.stroke.Thickness = if today then 6 else 3.5
		t.scale.Scale = if today then 1.08 else 1
		t.check.Visible = done
	end
	claimBtn.Text = if info.claimedToday then "Come back tomorrow!" else ("Claim  +" .. Util.fmt(info.rewards[info.day] or 0))
	claimBtn.BackgroundColor3 = if info.canClaim then C.green else C.panel2
	local coin = claimBtn:FindFirstChild("Coin")
	if coin then (coin :: GuiObject).Visible = info.canClaim end
end

local function build()
	local compact = HUDController.Compact
	local TW, TH = if compact then 74 else 96, if compact then 100 else 128
	win = UIKit.window(HUDController.Gui, "Daily Gift", UDim2.fromOffset(7 * (TW + 10) + 60, TH + 190), C.orange, Icons.daily)
	local sub = UIKit.label(win.body, { Text = "Come back every day - day 7 is the big one!", Font = UIKit.BODY, TextSize = 18, Size = UDim2.new(1, 0, 0, 24), TextColor3 = Color3.fromRGB(255, 232, 140), stroke = 2.5 })
	sub.Name = "Sub"
	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TH + 10), Position = UDim2.fromOffset(0, 32) }, win.body)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, row)
	for i = 1, 7 do
		local f = UIKit.new("Frame", { Name = "Day" .. i, Size = UDim2.fromOffset(TW, TH), BackgroundColor3 = WHITE, LayoutOrder = i }, row)
		UIKit.round(f, 14)
		local stroke = UIKit.stroke(f, UIKit.INK, 3.5)
		local grad = UIKit.new("UIGradient", { Rotation = 90 }, f)
		UIKit.rim(f, 8, 3)
		local scale = UIKit.new("UIScale", { Scale = 1 }, f)
		UIKit.label(f, { Text = if i == 7 then "DAY 7!" else ("Day " .. i), TextSize = if compact then 15 else 19, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 6), stroke = 3 })
		local cs = if compact then 40 else 54
		UIKit.coin(f, cs, UDim2.new(0.5, -cs / 2, 0.5, -cs / 2 + 2))
		local amount = UIKit.label(f, { Text = "", TextSize = if compact then 17 else 22, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -30), TextColor3 = Color3.fromRGB(255, 226, 90), stroke = 3.5 })
		-- claimed badge: green round seal on the corner (outside the title line)
		local bs = if compact then 28 else 36
		local check = UIKit.new("Frame", { Name = "Claimed", Size = UDim2.fromOffset(bs, bs), Position = UDim2.new(1, -bs * 0.6, 0, -bs * 0.4), BackgroundColor3 = WHITE, ZIndex = 6, Visible = false }, f)
		UIKit.round(check, bs / 2); UIKit.stroke(check, UIKit.INK, 3)
		UIKit.gloss(check, C.green:Lerp(WHITE, 0.3), C.green:Lerp(Color3.new(0, 0, 0), 0.2))
		UIKit.label(check, { Text = "OK", TextSize = if compact then 11 else 14, Size = UDim2.fromScale(1, 1), ZIndex = 7, stroke = 2 })
		tiles[i] = { frame = f, stroke = stroke, grad = grad, scale = scale, amount = amount, check = check }
	end
	claimBtn = UIKit.priceButton(win.body, { text = "Claim", color = C.green, size = UDim2.fromOffset(if compact then 260 else 330, if compact then 46 else 58), pos = UDim2.new(0.5, 0, 1, -6), anchor = Vector2.new(0.5, 1), textSize = if compact then 24 else 30, onClick = function()
		if busy then return end
		busy = true
		local r = Net.invoke("ClaimLogin")
		busy = false
		if r.ok then
			SfxController.Play("claim")
			HUDController.Toast(("Daily gift: +%s Coins!"):format(Util.fmt(r.amount or 0)), "ok")
			local t = tiles[r.day]
			if t then
				t.scale.Scale = 1.3
				TweenService:Create(t.scale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
			task.delay(1.1, function() if win.isOpen() then win.close() end end)
		elseif r.err == "AlreadyClaimed" then
			HUDController.Toast("Already claimed today - come back tomorrow!", "info")
		else
			SfxController.Play("deny")
			HUDController.Toast(UIKit.err(r.err), "err")
		end
	end })
	claimBtn.Name = "Claim"
	win.onOpen = function() render(StateController.State and StateController.State.login) end
end

function Controller.Open()
	if win then win.open() end
end

function Controller.Start()
	if not HUDController.Gui then return end
	build()
	StateController.Changed.Event:Connect(function(s)
		if win.isOpen() then render(s and s.login) end
		if not shownThisSession and s and s.login and s.login.canClaim and not HUDController.RunMode then
			shownThisSession = true
			task.delay(3, function()
				if not HUDController.RunMode then win.open() end
			end)
		end
	end)
	local s = StateController.State
	if s and s.login and s.login.canClaim then
		shownThisSession = true
		task.delay(3, function() if not HUDController.RunMode then win.open() end end)
	end
end

return Controller
