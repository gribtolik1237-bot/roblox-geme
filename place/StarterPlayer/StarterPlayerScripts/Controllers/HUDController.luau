--!strict
-- Main HUD: Coins, Rebirth progress, notification toasts, and the menu tile grid (big 3D icon tiles, like the owner's references).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Icons = require(ReplicatedStorage.Configs.Icons)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)
local StateController = require(script.Parent.StateController)

local HUDController = {}
HUDController.Gui = nil :: ScreenGui?
HUDController.Menu = {} :: { [string]: TextButton }
HUDController.Compact = false
local C = UIKit.C
local WHITE = Color3.new(1, 1, 1)
local MENU_GAP = 8

local function tileSize(): number
	return if HUDController.Compact then 74 else 66
end

function HUDController.Gui_(): ScreenGui
	return HUDController.Gui :: ScreenGui
end

function HUDController.Toast(text: string, kind: string?)
	if HUDController.Gui then UIKit.toast(HUDController.Gui, text, kind) end
end

local TILE = {
	npcs = Color3.fromRGB(55, 143, 232),
	rebirth = Color3.fromRGB(164, 82, 227),
	donate = Color3.fromRGB(229, 78, 103),
}

-- Small action tiles under the currency bar. The whole tile is the button.
function HUDController.AddMenuButton(id: string, text: string, color: Color3, order: number, onClick: () -> ())
	local col = (HUDController.Gui :: ScreenGui):FindFirstChild("MenuColumn") :: Frame
	local S = tileSize()
	local b = UIKit.button(col, { text = "", color = TILE[id] or color, size = UDim2.fromOffset(S, S), textSize = 14, order = order, onClick = onClick })
	b.Name = id
	local img = Icons[id]
	if img then
		local isz = S - 25
		UIKit.new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = img, Size = UDim2.fromOffset(isz, isz), AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 1), ZIndex = 4, ScaleType = Enum.ScaleType.Fit }, b)
	end
	UIKit.label(b, { Name = "Caption", Text = text, TextSize = 17, Size = UDim2.new(1, -8, 0, 22),
		Position = UDim2.new(0, 4, 1, -24), ZIndex = 5, stroke = 2.4 })
	HUDController.Menu[id] = b
	return b
end

-- Owner rule (T38): during a manual run only first person + one Exit button. Hides the menu grid, rebirth bar, hotbar and build strip; restores their previous state after.
function HUDController.SetRunMode(on: boolean)
	HUDController.RunMode = on
	local g = HUDController.Gui
	if not g then return end
	-- toasts sit lower during a run so they never cover the run banner (stage / time) at the top
	g:SetAttribute("ToastY", if on then 150 else 74)
	local toasts = g:FindFirstChild("Toasts")
	if toasts then (toasts :: Frame).Position = UDim2.new(0.5, 0, 0, if on then 150 else 74) end
	for _, n in { "MenuColumn", "Rebirth", "Hotbar", "BuildBar", "ShopBar" } do
		local o = g:FindFirstChild(n)
		if o then
			if on then
				if o:GetAttribute("HiddenByRun") == nil then o:SetAttribute("HiddenByRun", o.Visible) end
				o.Visible = false
			elseif o:GetAttribute("HiddenByRun") ~= nil then
				o.Visible = o:GetAttribute("HiddenByRun"); o:SetAttribute("HiddenByRun", nil)
			end
		end
	end
end

function HUDController.Start()
	-- audit 2.5: bounded wait; PlayerGui practically always exists, but never hang the whole client start-up on it
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui", 15)
	if not pg then warn("[HUD] PlayerGui did not appear in 15 s - HUD not built") return end
	local gui = UIKit.new("ScreenGui", { Name = "TrapLabHUD", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, pg)
	HUDController.Gui = gui
	UIKit.autoScale(gui)
	-- the camera viewport can still be (1,1) for a moment after join: wait for a real size before choosing the layout
	local t0 = os.clock()
	while workspace.CurrentCamera.ViewportSize.Y < 100 and os.clock() - t0 < 3 do task.wait() end
	local compact = UIKit.isCompact()
	HUDController.Compact = compact

	-- Coins: big 3D coin + a heavily outlined number, no plate (like the currency counters in the references)
	local cs = if compact then 44 else 64
	local pill = UIKit.new("Frame", { Name = "Coins", Size = UDim2.fromOffset(if compact then 230 else 300, cs), Position = UDim2.fromOffset(16, 10), BackgroundTransparency = 1 }, gui)
	UIKit.coin(pill, cs, UDim2.fromOffset(0, 0))
	local coinsText = UIKit.label(pill, { Name = "Value", Text = "0", TextSize = if compact then 32 else 46, Size = UDim2.new(1, -(cs + 8), 1, 0), Position = UDim2.fromOffset(cs + 6, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 214, 64), stroke = if compact then 4 else 5 })

	-- Rebirth progress bar (Lifetime Earned Coins toward the next threshold)
	local barH = if compact then 22 else 30
	local bar = UIKit.new("Frame", { Name = "Rebirth", Size = UDim2.fromOffset(if compact then 210 else 270, barH), Position = UDim2.fromOffset(16, cs + 16), BackgroundColor3 = Color3.fromRGB(30, 28, 44) }, gui)
	UIKit.round(bar, barH / 2); UIKit.stroke(bar, UIKit.INK, 3.5)
	local fill = UIKit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.purple }, bar)
	UIKit.round(fill, barH / 2); UIKit.gloss(fill, C.purple:Lerp(WHITE, 0.4), C.purple:Lerp(Color3.new(0, 0, 0), 0.15))
	local barText = UIKit.label(bar, { Text = "Rebirth 0", TextSize = if compact then 13 else 17, Size = UDim2.fromScale(1, 1), ZIndex = 3, stroke = 3 })

	-- Left menu grid
	local S = tileSize()
	local top = cs + barH + 28
	local col = UIKit.new("Frame", { Name = "MenuColumn", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, S),
		AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(16, top) }, gui)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, MENU_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder }, col)

	-- Storage-mode banner (honest indicator when progress cannot be saved)
	local banner = UIKit.label(gui, { Name = "MockBanner", Text = "Studio test: data is NOT saved", TextSize = 16, Size = UDim2.fromOffset(300, 24), Position = UDim2.new(1, -10, 1, -6), AnchorPoint = Vector2.new(1, 1), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.orange, Visible = false })   -- corner: never behind the hotbar

	local lastCoins = 0
	local function refresh(s: any)
		if not s then return end
		coinsText.Text = Util.fmt(s.coins)
		if s.coins > lastCoins and lastCoins > 0 then
			local sc = coinsText:FindFirstChildOfClass("UIScale") or UIKit.new("UIScale", {}, coinsText)
			sc.Scale = 1.25
			TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		lastCoins = s.coins
		if s.nextThreshold then
			fill.Size = UDim2.fromScale(math.clamp(s.lifetime / s.nextThreshold, 0, 1), 1)
			barText.Text = ("R%d  %s / %s"):format(s.rebirth, Util.fmt(s.lifetime), Util.fmt(s.nextThreshold))
		else
			fill.Size = UDim2.fromScale(1, 1); barText.Text = ("Rebirth %d (MAX)"):format(s.rebirth)
		end
		banner.Visible = s.mock == true
	end
	StateController.Changed.Event:Connect(refresh)
	if StateController.State then refresh(StateController.State) end

	Net.on("Notify", function(text: string, kind: string?) HUDController.Toast(text, kind) end)

	-- A window is modal (skill roblox-game-design, TRAP LAB case G15/G16: the top Shop/Home/NPC Shop row and the hammer were drawn OVER
	-- the shop windows' header and last card row). While any "...Window" is open the top row, hotbar, build bar and menu grid step aside.
	-- audit 2.1: event-driven (was a 0.15 s poll). Re-evaluated when a UIKit.window opens/closes (UIKit.WindowChanged) and when one of
	-- the yielding bars becomes visible while a window is open (e.g. a controller took the hammer) - that one is hidden again.
	local YIELD = { "ShopBar", "Hotbar", "BuildBar", "MenuColumn" }
	local YSET: { [string]: boolean } = {}
	for _, n in YIELD do YSET[n] = true end
	local modal = false
	local function anyWindowOpen(): boolean
		for _, c in gui:GetChildren() do
			if c:IsA("GuiObject") and c.Visible and c.Name:sub(-6) == "Window" then return true end
		end
		return false
	end
	local function evaluate()
		local any = anyWindowOpen()
		if any == modal then return end
		modal = any
		for _, n in YIELD do
			local o = gui:FindFirstChild(n) :: GuiObject?
			if o then
				if any then
					if o:GetAttribute("HiddenByModal") == nil then o:SetAttribute("HiddenByModal", o.Visible) end
					o.Visible = false
				elseif o:GetAttribute("HiddenByModal") ~= nil then
					-- (race fix: something shown in the same instant the window closed stays shown)
					if not HUDController.RunMode then o.Visible = o:GetAttribute("HiddenByModal") or o.Visible end
					o:SetAttribute("HiddenByModal", nil)
				end
			end
		end
	end
	local function watchBar(o: Instance)
		if not (o:IsA("GuiObject") and YSET[o.Name]) then return end
		local g = o :: GuiObject
		g:GetPropertyChangedSignal("Visible"):Connect(function()
			if modal and g.Visible then g:SetAttribute("HiddenByModal", true); g.Visible = false end
		end)
	end
	for _, c in gui:GetChildren() do watchBar(c) end
	gui.ChildAdded:Connect(watchBar)
	UIKit.WindowChanged.Event:Connect(function() task.defer(evaluate) end)
end

return HUDController
