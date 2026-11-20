--!strict
-- TRAP LAB UI kit v2 - "bright simulator" look (docs/ART_DIRECTION.md, the owner's references): saturated two-tone glossy fills, THICK near-black
-- outlines, white text with a heavy dark stroke (Fredoka), big 3D icons that overhang their plates, a red square close button on the window corner.
-- One visual language for every window, button and toast.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Rarities = require(script.Parent.Parent.Configs.Rarities)
local Icons = require(script.Parent.Parent.Configs.Icons)

local UIKit = {}
UIKit.WindowChanged = Instance.new("BindableEvent")   -- (frame, isOpen) whenever a UIKit.window opens or closes
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

UIKit.INK = Color3.fromRGB(14, 10, 18)
UIKit.C = {
	bg = Color3.fromRGB(33, 35, 49), panel = Color3.fromRGB(47, 50, 70), panel2 = Color3.fromRGB(66, 70, 96),
	text = WHITE, muted = Color3.fromRGB(196, 202, 224), dark = UIKit.INK,
	teal = Color3.fromRGB(34, 200, 232), yellow = Color3.fromRGB(255, 204, 36), green = Color3.fromRGB(86, 214, 56),
	red = Color3.fromRGB(255, 72, 72), purple = Color3.fromRGB(172, 92, 255), orange = Color3.fromRGB(255, 142, 32),
	blue = Color3.fromRGB(58, 142, 255), pink = Color3.fromRGB(255, 84, 160),
}
UIKit.FONT = Enum.Font.FredokaOne        -- chunky rounded: titles, buttons, numbers
UIKit.BODY = Enum.Font.BuilderSansBold   -- small text, names (supports Cyrillic player names)

function UIKit.rarityColor(r: string): Color3
	local i = Rarities.Info[r]
	return if i then i.color else UIKit.C.muted
end

function UIKit.new(class: string, props: { [string]: any }?, parent: Instance?): any
	local inst = Instance.new(class)
	if props then for k, v in props do (inst :: any)[k] = v end end
	if parent then inst.Parent = parent end
	return inst
end

function UIKit.round(inst: Instance, radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, inst)
end
function UIKit.stroke(inst: Instance, color: Color3?, thick: number?): UIStroke
	return UIKit.new("UIStroke", { Color = color or UIKit.INK, Thickness = thick or 3.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }, inst)
end
-- glossy two-tone fill (lighter top half, a soft step in the middle, deeper bottom): the colour lives in the gradient, the instance itself turns white
function UIKit.gloss(inst: Instance, top: Color3, bottom: Color3): UIGradient
	if inst:IsA("GuiObject") then (inst :: any).BackgroundColor3 = WHITE end
	return UIKit.new("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(0.46, top:Lerp(bottom, 0.2)),
		ColorSequenceKeypoint.new(0.52, top:Lerp(bottom, 0.6)), ColorSequenceKeypoint.new(1, bottom),
	}), Rotation = 90 }, inst)
end
-- fat dark outline around the glyphs (Contextual mode: follows the text, not the box)
function UIKit.textStroke(inst: Instance, thick: number?, color: Color3?): UIStroke
	return UIKit.new("UIStroke", { Color = color or UIKit.INK, Thickness = thick or 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round }, inst)
end
-- thin bright rim light along the top inside edge of a plate
function UIKit.rim(inst: Instance, inset: number?, thick: number?): Frame
	local i = inset or 8
	local r = UIKit.new("Frame", { Name = "Rim", BackgroundColor3 = WHITE, BackgroundTransparency = 0.5, BorderSizePixel = 0, Size = UDim2.new(1, -i * 2, 0, thick or 3), Position = UDim2.fromOffset(i, 4) }, inst)
	UIKit.round(r, 2)
	return r
end

function UIKit.label(parent: Instance, props: { [string]: any }): TextLabel
	local p: { [string]: any } = { BackgroundTransparency = 1, Font = UIKit.FONT, TextColor3 = UIKit.C.text, TextScaled = false, TextSize = 18, Text = "" }
	for k, v in props do if k ~= "stroke" then p[k] = v end end
	local l = UIKit.new("TextLabel", p, parent)
	local st = props.stroke
	if st == nil then
		local ts = p.TextSize :: number
		st = if ts >= 18 then 2.5 elseif ts >= 14 then 1.6 else 1
	end
	if st and st ~= 0 then UIKit.textStroke(l, st) end
	return l
end

-- Chunky glossy button: saturated two-tone fill + thick ink outline + rim light, outlined text; hover (lighter + grows), press (darker + sinks).
-- props.icon: a 3D icon that overhangs the left edge (references 3/4).
function UIKit.button(parent: Instance, props: { name: string?, text: string, color: Color3?, size: UDim2?, pos: UDim2?, textSize: number?, onClick: (() -> ())?, anchor: Vector2?, order: number?, icon: string?, iconSize: number? }): TextButton
	local col = props.color or UIKit.C.green
	local ts = props.textSize or 22
	local b = UIKit.new("TextButton", {
		Name = props.name or "Button", Text = props.text, Font = UIKit.FONT, TextSize = ts, TextColor3 = WHITE,
		BackgroundColor3 = col, AutoButtonColor = false, Size = props.size or UDim2.fromOffset(120, 48),
		Position = props.pos or UDim2.new(), AnchorPoint = props.anchor or Vector2.zero, LayoutOrder = props.order or 0,
	}, parent)
	UIKit.round(b, 12); UIKit.stroke(b, UIKit.INK, 3.5)
	UIKit.textStroke(b, math.max(2, ts * 0.13))
	-- neutral shading gradient: the colour itself stays in BackgroundColor3 so controllers can recolour a button (BUY / LOCKED / selected)
	UIKit.new("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.45, Color3.fromRGB(238, 238, 238)),
		ColorSequenceKeypoint.new(0.51, Color3.fromRGB(206, 206, 206)), ColorSequenceKeypoint.new(1, Color3.fromRGB(184, 184, 184)),
	}), Rotation = 90 }, b)
	UIKit.rim(b, 8, 3)
	if props.icon then
		local isz = props.iconSize or 44
		local pad = math.floor(isz * 0.62)
		UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, pad) }, b)
		UIKit.new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = props.icon, Size = UDim2.fromOffset(isz, isz), AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -pad - math.floor(isz * 0.3), 0.5, -2), ZIndex = 4, ScaleType = Enum.ScaleType.Fit }, b)
	end
	local scale = UIKit.new("UIScale", { Scale = 1 }, b)
	local base = col
	local function tw(sc: number) TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Scale = sc }):Play() end
	b.MouseEnter:Connect(function() base = b.BackgroundColor3; tw(1.05); b.BackgroundColor3 = base:Lerp(WHITE, 0.16) end)
	b.MouseLeave:Connect(function() tw(1); b.BackgroundColor3 = base end)
	b.MouseButton1Down:Connect(function() tw(0.94); b.BackgroundColor3 = base:Lerp(BLACK, 0.14) end)
	b.MouseButton1Up:Connect(function() tw(1.05); b.BackgroundColor3 = base:Lerp(WHITE, 0.16) end)
	if props.onClick then b.Activated:Connect(props.onClick) end
	return b
end

-- Big price / action button with the coin icon overhanging on the left (shop cards, references 1)
function UIKit.priceButton(parent: Instance, props: { text: string, color: Color3?, size: UDim2?, pos: UDim2?, textSize: number?, onClick: (() -> ())?, anchor: Vector2?, order: number? }): TextButton
	local b = UIKit.button(parent, { name = "Buy", text = props.text, color = props.color or UIKit.C.green, size = props.size or UDim2.new(1, -16, 0, 46), pos = props.pos, textSize = props.textSize or 26, onClick = props.onClick, anchor = props.anchor, order = props.order })
	local pad = 34
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, pad) }, b)
	local c = UIKit.coin(b, 40, UDim2.new(0, 4 - pad, 0.5, -20))
	c.Name = "Coin"; c.ZIndex = 4
	return b
end

-- small coloured pill with outlined text (rarity ribbon, "NPC x" flags ...)
function UIKit.tag(parent: Instance, text: string, color: Color3, size: UDim2?, pos: UDim2?, textSize: number?): Frame
	local t = UIKit.new("Frame", { Name = "Tag", Size = size or UDim2.fromOffset(84, 22), Position = pos or UDim2.new(), BackgroundColor3 = WHITE, ZIndex = 5 }, parent)
	UIKit.round(t, 8); UIKit.stroke(t, UIKit.INK, 2.5)
	UIKit.gloss(t, color:Lerp(WHITE, 0.25), color:Lerp(BLACK, 0.12))
	UIKit.label(t, { Text = text, TextSize = textSize or 13, Size = UDim2.fromScale(1, 1), ZIndex = 6, stroke = 2 })
	return t
end

-- Window: dark slate body with a thick ink outline, a glossy accent header that overlaps the top edge (title in a heavy outline, optional 3D icon
-- overhanging on the left) and a red square close button on the corner. Returns { frame, body, open, close, toggle, isOpen, bar, scale }
function UIKit.window(gui: ScreenGui, title: string, size: UDim2, accent: Color3?, icon: string?)
	local acc = accent or UIKit.C.teal
	local frame = UIKit.new("Frame", { Name = title:gsub("%s", "") .. "Window", Size = size, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE, Visible = false }, gui)
	UIKit.round(frame, 20); UIKit.stroke(frame, UIKit.INK, 5)
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(72, 76, 106), Color3.fromRGB(33, 35, 51)), Rotation = 90 }, frame)
	local sizeC = UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(980, 640), MinSize = Vector2.new(300, 220) }, frame)
	-- never taller/wider than the visible (UI-scaled) screen: matters on phones in landscape
	local function fit()
		local v = workspace.CurrentCamera.ViewportSize / UIKit.scaleFor()
		sizeC.MaxSize = Vector2.new(math.max(300, math.min(980, v.X - 40)), math.max(220, math.min(640, v.Y - 70)))
		sizeC.MinSize = Vector2.new(math.min(300, sizeC.MaxSize.X), math.min(220, sizeC.MaxSize.Y))
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	local scale = UIKit.new("UIScale", { Scale = 0.85 }, frame)
	local key = UIKit.new("Frame", { Name = "Keyline", BackgroundTransparency = 1, Size = UDim2.new(1, -14, 1, -14), Position = UDim2.fromOffset(7, 7) }, frame)
	UIKit.round(key, 15); UIKit.new("UIStroke", { Color = WHITE, Transparency = 0.87, Thickness = 2 }, key)

	local bar = UIKit.new("Frame", { Name = "Bar", Size = UDim2.new(1, -36, 0, 60), Position = UDim2.fromOffset(18, -26), BackgroundColor3 = acc, ZIndex = 3 }, frame)
	UIKit.round(bar, 16); UIKit.stroke(bar, UIKit.INK, 4.5)
	UIKit.gloss(bar, acc:Lerp(WHITE, 0.42), acc:Lerp(BLACK, 0.24))
	UIKit.rim(bar, 12, 3)
	local lx = if icon then 92 else 22
	local t = UIKit.label(bar, { Text = title, TextSize = 34, TextScaled = true, Size = UDim2.new(1, -(lx + 78), 1, -10), Position = UDim2.fromOffset(lx, 3), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, stroke = 4 })
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 34, MinTextSize = 14 }, t)
	if icon then
		UIKit.new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = icon, Size = UDim2.fromOffset(92, 92), Position = UDim2.fromOffset(-10, -22), ZIndex = 7, ScaleType = Enum.ScaleType.Fit }, bar)
	end
	local body = UIKit.new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 54), Size = UDim2.new(1, -36, 1, -70) }, frame)
	local win = { frame = frame, body = body, scale = scale, bar = bar, onOpen = nil :: (() -> ())? }
	-- audit 2.1: any open/close (also a controller setting Visible directly) fires UIKit.WindowChanged - HUD modal logic listens instead of polling
	frame:GetPropertyChangedSignal("Visible"):Connect(function() UIKit.WindowChanged:Fire(frame, frame.Visible) end)
	function win.open()
		frame.Visible = true
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if win.onOpen then win.onOpen() end
	end
	function win.close()
		local tw = TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Scale = 0.85 })
		tw:Play(); tw.Completed:Once(function() frame.Visible = false end)
	end
	function win.isOpen(): boolean return frame.Visible end
	function win.toggle() if frame.Visible then win.close() else win.open() end end
	local x = UIKit.button(frame, { name = "Close", text = "X", color = UIKit.C.red, size = UDim2.fromOffset(52, 52), pos = UDim2.new(1, 14, 0, -30), anchor = Vector2.new(1, 0), textSize = 30, onClick = win.close })
	x.ZIndex = 9
	return win
end

-- Floating toast (top centre). kind: ok | err | info
local toastHolder: Frame? = nil
function UIKit.toast(gui: ScreenGui, text: string, kind: string?)
	if not toastHolder or toastHolder.Parent ~= gui then
		toastHolder = UIKit.new("Frame", { Name = "Toasts", BackgroundTransparency = 1, Size = UDim2.new(0, 520, 0, 220), Position = UDim2.new(0.5, 0, 0, (gui:GetAttribute("ToastY") :: number?) or 74), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 50 }, gui)
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, toastHolder)
	end
	-- session 8 (skill review G01/G02: stacked identical toasts): the same message never stacks - the visible one is refreshed;
	-- at most 3 toasts on screen (the oldest goes first)
	local holder = toastHolder :: Frame
	local live = {}
	for _, c in holder:GetChildren() do
		if c:IsA("TextLabel") and not c:GetAttribute("Dying") then
			-- session 8 (audit 2 fix): the same message never stacks - the visible one is refreshed;
			-- the colour must follow the NEW kind, not stay stale from the first showing
			if c.Text == text then
				c:SetAttribute("Until", os.clock() + 3)
				if c:GetAttribute("Kind") ~= (kind or "info") then
					c:SetAttribute("Kind", kind or "info")
				local col2 = if kind == "err" then UIKit.C.red elseif kind == "ok" then UIKit.C.green else UIKit.C.blue
				local g = c:FindFirstChildOfClass("UIGradient")
				if g then g.Color = ColorSequence.new(col2:Lerp(WHITE, 0.3), col2:Lerp(BLACK, 0.2)) end
			end
			return
			end
			live[#live + 1] = c
		end
	end
	table.sort(live, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #live >= 3 do local o = table.remove(live, 1) :: TextLabel; o:SetAttribute("Until", 0) end
	local col = if kind == "err" then UIKit.C.red elseif kind == "ok" then UIKit.C.green else UIKit.C.blue
	local t = UIKit.new("TextLabel", { Size = UDim2.fromOffset(0, 48), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = WHITE, Text = text, Font = UIKit.FONT, TextSize = 22, TextColor3 = WHITE, ZIndex = 51, LayoutOrder = math.floor(os.clock() * 1000) % 1e9 }, toastHolder)
	t:SetAttribute("Until", os.clock() + 3)
	t:SetAttribute("Kind", kind or "info")
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }, t)
	UIKit.round(t, 16); UIKit.stroke(t, UIKit.INK, 4); UIKit.textStroke(t, 2.5)
	UIKit.gloss(t, col:Lerp(WHITE, 0.3), col:Lerp(BLACK, 0.2))
	t.TextTransparency = 1; t.BackgroundTransparency = 1
	TweenService:Create(t, TweenInfo.new(0.2), { TextTransparency = 0, BackgroundTransparency = 0 }):Play()
	task.spawn(function()
		while t.Parent and os.clock() < ((t:GetAttribute("Until") :: number?) or 0) do task.wait(0.1) end
		if not t.Parent then return end
		t:SetAttribute("Dying", true)
		local o = TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 1, BackgroundTransparency = 1 })
		o:Play(); o.Completed:Once(function() t:Destroy() end)
	end)
end

-- Compact layout = phones / very small viewports: bigger relative UI (reference 1000x540) and a grid menu
function UIKit.isCompact(): boolean
	local v = workspace.CurrentCamera.ViewportSize
	return (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or v.Y < 420 or v.X < 480
end

function UIKit.scaleFor(): number
	local v = workspace.CurrentCamera.ViewportSize
	if UIKit.isCompact() then return math.clamp(math.min(v.X / 1000, v.Y / 540), 0.6, 1.1) end
	return math.clamp(math.min(v.X / 1280, v.Y / 720), 0.55, 1.25)
end

-- UI scale for phones/tablets/desktop
function UIKit.autoScale(gui: ScreenGui)
	local s = UIKit.new("UIScale", {}, gui)
	local function upd()
		s.Scale = UIKit.scaleFor()
	end
	upd()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(upd)
	return s
end

function UIKit.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

UIKit.errText = {
	Rate = "Slow down a little!", NoCoins = "Not enough Coins", Locked = "Locked - needs more Rebirths",
	NotInStock = "That item just left the shop", Owned = "You already own this", MaxOwned = "You own the maximum amount",
	Unknown = "Unknown item", Invalid = "Invalid request", NoPlot = "No plot assigned yet", NoItem = "You don't own this item",
	OutOfBounds = "Outside your build zone", Overlap = "Something is in the way", LimitReached = "Object limit reached - Rebirth to build more",
	AlreadyPlaced = "Already placed", NotFound = "Object not found", Net = "Connection problem, try again",
	Server = "Server error, try again", NoProfile = "Still loading your data...",
	PadLocked = "That pad unlocks with more Rebirths", EmptySlot = "Pick an NPC for that slot first", NotOwned = "You don't own that NPC",
	PadBusy = "That pad is already in use", AlreadyActive = "That NPC is already on a pad", NpcLimit = "Active NPC limit reached - Rebirth for more",
	ServerBusy = "Server is busy, try again soon", Busy = "Already running", CourseLoading = "Your course is still loading", CourseNotReady = "Finish your course first: it needs a Finish Pad and a route",
	NpcIncompatible = "Your route has obstacles NPCs can't use",
	NotEnough = "Not enough Lifetime Coins yet", MaxRebirth = "You reached the maximum Rebirth", Stale = "Already done - refreshing",
}
function UIKit.err(code: any): string
	return UIKit.errText[code] or ("Error: " .. tostring(code))
end
function UIKit.rebirthText(n: number): string
	return if n == 1 then "Requires 1 Rebirth" else ("Requires " .. n .. " Rebirths")
end

-- Coin icon (Blender 3D render, Configs/Icons.coin); falls back to a drawn badge if the id is missing
function UIKit.coin(parent: Instance, size: number, pos: UDim2?): GuiObject
	if Icons.coin then
		return UIKit.new("ImageLabel", { Name = "Coin", BackgroundTransparency = 1, Image = Icons.coin, Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(), ScaleType = Enum.ScaleType.Fit }, parent)
	end
	local c = UIKit.new("Frame", { Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(), BackgroundColor3 = UIKit.C.yellow }, parent)
	UIKit.round(c, size); UIKit.stroke(c, UIKit.INK, math.max(2, size / 10))
	UIKit.gloss(c, Color3.fromRGB(255, 226, 110), Color3.fromRGB(240, 156, 24))
	UIKit.label(c, { Text = "C", TextSize = math.floor(size * 0.62), Size = UDim2.fromScale(1, 1), TextColor3 = Color3.fromRGB(122, 70, 8) })
	return c
end

-- Padlock icon (Blender 3D render, Configs/Icons.lock)
function UIKit.lock(parent: Instance, size: number, pos: UDim2?): GuiObject
	if Icons.lock then
		return UIKit.new("ImageLabel", { Name = "Lock", BackgroundTransparency = 1, Image = Icons.lock, Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(), ScaleType = Enum.ScaleType.Fit }, parent)
	end
	local root = UIKit.new("Frame", { Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(), BackgroundTransparency = 1 }, parent)
	local body = UIKit.new("Frame", { Size = UDim2.fromScale(0.8, 0.5), Position = UDim2.fromScale(0.1, 0.46), BackgroundColor3 = UIKit.C.yellow }, root)
	UIKit.round(body, size / 6); UIKit.stroke(body, UIKit.INK, 2)
	return root
end

-- 3D preview of a model (cloned) framed by its bounding box
function UIKit.preview(parent: Instance, model: Model, props: { [string]: any }?): ViewportFrame
	-- props.zoom: distance factor (smaller = closer); props.dir: camera direction from the model (default: front-right-above for obstacles)
	local zoom, dir = 0.84, Vector3.new(0.75, 0.62, 1)
	local p2 = props
	if props then
		p2 = table.clone(props)
		if p2.zoom then zoom = p2.zoom; p2.zoom = nil end
		if p2.dir then dir = p2.dir; p2.dir = nil end
	end
	local vp = UIKit.new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(170, 175, 190), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-1, -1.6, -0.8) }, parent)
	if p2 then for k, v in p2 do (vp :: any)[k] = v end end
	local wm = Instance.new("WorldModel"); wm.Parent = vp
	model.Parent = wm
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera"); cam.FieldOfView = 35; cam.Parent = vp; vp.CurrentCamera = cam
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * zoom
	cam.CFrame = CFrame.lookAt(cf.Position + dir.Unit * dist, cf.Position)
	return vp
end

-- ---- shared item card (shops, inventory, NPC window): rarity-tinted body, preview well with a spotlight, rarity ribbon, outlined name ----
local SLATE = Color3.fromRGB(54, 58, 84)
function UIKit.itemCard(parent: Instance, props: { w: number, h: number, rarity: Color3, name: string, tag: string?, pvH: number?, order: number? }): { card: Frame, pv: Frame, y: number }
	local W, H, rc = props.w, props.h, props.rarity
	local card = UIKit.new("Frame", { Name = "Card", Size = UDim2.fromOffset(W, H), BackgroundColor3 = WHITE, LayoutOrder = props.order or 0 }, parent)
	UIKit.round(card, 18); UIKit.stroke(card, UIKit.INK, 4)
	UIKit.new("UIGradient", { Color = ColorSequence.new(SLATE:Lerp(rc, 0.5), SLATE:Lerp(rc, 0.12):Lerp(BLACK, 0.3)), Rotation = 90 }, card)
	local ring = UIKit.new("Frame", { Name = "Ring", BackgroundTransparency = 1, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5) }, card)
	UIKit.round(ring, 14); UIKit.new("UIStroke", { Color = rc, Thickness = 3, Transparency = 0.1 }, ring)
	local pvH = props.pvH or 140
	local pv = UIKit.new("Frame", { Name = "Preview", Size = UDim2.new(1, -22, 0, pvH), Position = UDim2.fromOffset(11, 12), BackgroundColor3 = WHITE }, card)
	UIKit.round(pv, 14); UIKit.stroke(pv, UIKit.INK, 3)
	UIKit.new("UIGradient", { Color = ColorSequence.new(SLATE:Lerp(rc, 0.55), SLATE:Lerp(rc, 0.2):Lerp(BLACK, 0.45)), Rotation = 90 }, pv)
	local spot = UIKit.new("Frame", { Size = UDim2.fromOffset(pvH - 22, pvH - 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = WHITE, BackgroundTransparency = 0.86 }, pv)
	UIKit.round(spot, pvH)
	if props.tag then UIKit.tag(card, string.upper(props.tag), rc, UDim2.fromOffset(92, 24), UDim2.fromOffset(6, 6), 14) end
	local nm = UIKit.label(card, { Name = "Name", Text = props.name, TextSize = 22, TextScaled = true, Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 12 + pvH + 6), stroke = 3 })
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 12 }, nm)
	return { card = card, pv = pv, y = 12 + pvH + 36 }
end

-- five NPC stat bars (SPD/JMP/BAL/REC/CTL) with numbers
local STATS = { { "speed", "SPD", UIKit.C.teal }, { "jump", "JMP", UIKit.C.green }, { "balance", "BAL", UIKit.C.yellow }, { "recovery", "REC", UIKit.C.orange }, { "control", "CTL", UIKit.C.purple } }
function UIKit.statBars(card: Frame, stats: { [string]: number }, y: number)
	for i, st in STATS do
		local yy = y + (i - 1) * 12
		UIKit.label(card, { Text = st[2], Font = UIKit.BODY, TextSize = 11, Size = UDim2.fromOffset(32, 11), Position = UDim2.fromOffset(14, yy), TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.2 })
		local back = UIKit.new("Frame", { Size = UDim2.fromOffset(116, 9), Position = UDim2.fromOffset(48, yy + 1), BackgroundColor3 = Color3.fromRGB(20, 18, 30) }, card)
		UIKit.round(back, 4); UIKit.stroke(back, UIKit.INK, 1.5)
		local f = UIKit.new("Frame", { Size = UDim2.fromScale(math.clamp((stats[st[1]] or 0) / 10, 0, 1), 1), BackgroundColor3 = WHITE }, back)
		UIKit.round(f, 4); UIKit.gloss(f, st[3]:Lerp(WHITE, 0.35), st[3])
		UIKit.label(card, { Text = tostring(stats[st[1]] or 0), Font = UIKit.BODY, TextSize = 11, Size = UDim2.fromOffset(22, 11), Position = UDim2.fromOffset(170, yy), TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.2 })
	end
end

-- a round "tab" pill (selected = bright, unselected = grey)
function UIKit.setTab(b: TextButton, selected: boolean)
	b.BackgroundColor3 = if selected then UIKit.C.yellow else UIKit.C.panel2
	b.TextTransparency = if selected then 0 else 0.15
end

return UIKit
