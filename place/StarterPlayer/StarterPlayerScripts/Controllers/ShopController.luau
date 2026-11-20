-- Obstacle Shop + NPC Shop windows (v2 "bright simulator" look). Pure display of SERVER data: shelf ids, prices from shared configs, lock state
-- from the server-synced rebirth. The server re-validates every purchase.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Configs = ReplicatedStorage.Configs
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)
local ObstacleModels = require(ReplicatedStorage.Shared.ObstacleModels)
local Obstacles = require(Configs.Obstacles)
local NPCs = require(Configs.NPCs)
local Icons = require(Configs.Icons)
local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)
local SfxController = require(script.Parent.SfxController)

local C = UIKit.C
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local SLATE = Color3.fromRGB(54, 58, 84)
local CARD_W = 204
local CARD_H = { obstacle = 266, npc = 322 }
local ShopController = {}
local shelf = { obstacle = {}, npc = {}, nextRefresh = 0, loaded = false }
local views = {}   -- kind -> { win, grid, timer, cards = { {update = fn} } }

local NPCRig = require(ReplicatedStorage.Shared.NPCRig)
local function npcModel(id)
	local okRig, rig = pcall(NPCRig.build, id)      -- same builder as the NPC collection window: the real 3D tester, not a letter
	if okRig and rig then return rig end
	local a = ReplicatedStorage:FindFirstChild("Assets")
	local t = a and a:FindFirstChild("NPCs") and a.NPCs:FindFirstChild(id)
	return t and t:Clone() or nil
end

local STAT_NAMES = { { "speed", "SPD", C.teal }, { "jump", "JMP", C.green }, { "balance", "BAL", C.yellow }, { "recovery", "REC", C.orange }, { "control", "CTL", C.purple } }

local function buildCard(kind, id, grid)
	local def = if kind == "obstacle" then Obstacles.ById[id] else NPCs.ById[id]
	local rc = UIKit.rarityColor(def.rarity)
	local H = CARD_H[kind]
	local card = UIKit.new("Frame", { Name = id, Size = UDim2.fromOffset(CARD_W, H), BackgroundColor3 = WHITE }, grid)
	UIKit.round(card, 18); UIKit.stroke(card, UIKit.INK, 4)
	UIKit.new("UIGradient", { Color = ColorSequence.new(SLATE:Lerp(rc, 0.5), SLATE:Lerp(rc, 0.12):Lerp(BLACK, 0.3)), Rotation = 90 }, card)
	local ring = UIKit.new("Frame", { Name = "Ring", BackgroundTransparency = 1, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5) }, card)
	UIKit.round(ring, 14); UIKit.new("UIStroke", { Color = rc, Thickness = 3, Transparency = 0.1 }, ring)

	-- preview well: rarity-tinted, a soft spotlight disc behind the 3D model
	local PV_H = 150
	local pv = UIKit.new("Frame", { Name = "Preview", Size = UDim2.new(1, -22, 0, PV_H), Position = UDim2.fromOffset(11, 12), BackgroundColor3 = WHITE }, card)
	UIKit.round(pv, 14); UIKit.stroke(pv, UIKit.INK, 3)
	UIKit.new("UIGradient", { Color = ColorSequence.new(SLATE:Lerp(rc, 0.55), SLATE:Lerp(rc, 0.2):Lerp(BLACK, 0.45)), Rotation = 90 }, pv)
	local spot = UIKit.new("Frame", { Size = UDim2.fromOffset(128, 128), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = WHITE, BackgroundTransparency = 0.86 }, pv)
	UIKit.round(spot, 64)
	local model = if kind == "obstacle" then ObstacleModels.build(id) else npcModel(id)
	if model then
		UIKit.preview(pv, model, if kind == "npc" then { zoom = 1.02, dir = Vector3.new(0.55, 0.3, -1) } else nil)
	else
		UIKit.label(pv, { Text = def.name:sub(1, 1), TextSize = 64, Size = UDim2.fromScale(1, 1), TextColor3 = rc })
	end
	UIKit.tag(card, string.upper(def.rarity), rc, UDim2.fromOffset(92, 24), UDim2.fromOffset(6, 6), 14)
	if kind == "obstacle" and def.npc and def.npc.supported == false then
		UIKit.tag(card, "NO NPC", C.orange, UDim2.fromOffset(66, 24), UDim2.fromOffset(CARD_W - 72, 6), 12)
	end
	local ownedTag = UIKit.tag(card, "x0", C.blue, UDim2.fromOffset(52, 24), UDim2.fromOffset(CARD_W - 64, 12 + PV_H - 32), 14)
	ownedTag.Visible = false

	-- "i" opens the description over the picture (no tiny paragraph on the card itself, like the references)
	local text = if kind == "obstacle" then def.desc else def.blurb
	if text then
		local info = UIKit.new("Frame", { Name = "Info", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.14, Visible = false, ZIndex = 8, Active = true }, pv)
		UIKit.round(info, 14)
		UIKit.label(info, { Text = text, Font = UIKit.BODY, TextSize = 17, TextWrapped = true, Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10), ZIndex = 9, stroke = 1.8 })
		local ib = UIKit.button(pv, { name = "InfoBtn", text = "i", color = C.blue, size = UDim2.fromOffset(30, 30), pos = UDim2.new(0, 6, 1, -36), textSize = 20, onClick = function() info.Visible = not info.Visible end })
		ib.ZIndex = 10
	end

	local nm = UIKit.label(card, { Text = def.name, TextSize = 22, TextScaled = true, Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 12 + PV_H + 6), stroke = 3 })
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 12 }, nm)
	if kind == "npc" then
		for i, s in STAT_NAMES do
			local y = 12 + PV_H + 40 + (i - 1) * 12
			UIKit.label(card, { Text = s[2], Font = UIKit.BODY, TextSize = 11, Size = UDim2.fromOffset(32, 11), Position = UDim2.fromOffset(14, y), TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.2 })
			local back = UIKit.new("Frame", { Size = UDim2.fromOffset(116, 9), Position = UDim2.fromOffset(48, y + 1), BackgroundColor3 = Color3.fromRGB(20, 18, 30) }, card)
			UIKit.round(back, 4); UIKit.stroke(back, UIKit.INK, 1.5)
			local fill = UIKit.new("Frame", { Size = UDim2.fromScale(def.stats[s[1]] / 10, 1), BackgroundColor3 = WHITE }, back)
			UIKit.round(fill, 4); UIKit.gloss(fill, s[3]:Lerp(WHITE, 0.35), s[3])
			UIKit.label(card, { Text = tostring(def.stats[s[1]]), Font = UIKit.BODY, TextSize = 11, Size = UDim2.fromOffset(22, 11), Position = UDim2.fromOffset(170, y), TextXAlignment = Enum.TextXAlignment.Left, stroke = 1.2 })
		end
	end
	local buy = UIKit.priceButton(card, { text = Util.fmt(def.price), size = UDim2.new(1, -20, 0, 46), pos = UDim2.fromOffset(10, H - 56), textSize = 26 })

	local lock = UIKit.new("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.04, ZIndex = 20, Visible = false, Active = true }, card)
	UIKit.round(lock, 18)
	local lk = UIKit.lock(lock, 80, UDim2.new(0.5, -40, 0, 40)); lk.ZIndex = 21
	UIKit.label(lock, { Text = "", Name = "Req", TextSize = 24, TextWrapped = true, Size = UDim2.new(1, -24, 0, 70), Position = UDim2.fromOffset(12, 134), ZIndex = 22, TextColor3 = C.yellow, stroke = 3 })

	local function setBuy(text: string, color: Color3, coin: boolean)
		buy.Text = text; buy.BackgroundColor3 = color
		local c = buy:FindFirstChild("Coin"); if c then c.Visible = coin end
		local pad = buy:FindFirstChildOfClass("UIPadding"); if pad then pad.PaddingLeft = UDim.new(0, if coin then 34 else 0) end
	end
	local function update()
		local s = StateController.State
		if not s then return end
		local locked = def.rebirth > s.rebirth
		lock.Visible = locked
		if locked then lock.Req.Text = UIKit.rebirthText(def.rebirth) end
		local owned = kind == "npc" and table.find(s.npcs, id) ~= nil
		local canPay = s.coins >= def.price
		if owned then setBuy("OWNED", C.panel2, false)
		elseif locked then setBuy("LOCKED", C.panel2, false)
		else setBuy(Util.fmt(def.price), if canPay then C.green else C.red, true) end
		if kind == "obstacle" then
			local n = s.inv[id] or 0
			card:SetAttribute("Owned", n)
			ownedTag.Visible = n > 0
			local lbl = ownedTag:FindFirstChildOfClass("TextLabel"); if lbl then lbl.Text = "x" .. n end
		end
	end
	buy.Activated:Connect(function()
		local s = StateController.State
		if not s then return end
		if def.rebirth > s.rebirth then HUDController.Toast(UIKit.rebirthText(def.rebirth), "err"); SfxController.Play("deny"); return end
		local r = Net.invoke("Buy", { shop = kind, id = id })
		if r.ok then
			SfxController.Play("buy")
			HUDController.Toast("Bought " .. def.name .. "!", "ok")
			local sc = card:FindFirstChildOfClass("UIScale") or UIKit.new("UIScale", {}, card)
			sc.Scale = 1.08
			TweenService:Create(sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			SfxController.Play("deny")
			HUDController.Toast(UIKit.err(r.err), "err")
		end
	end)
	update()
	return { card = card, update = update }
end

local function render(kind)
	local v = views[kind]
	for _, c in v.cards do c.card:Destroy() end
	v.cards = {}
	local ids = table.clone(shelf[kind])
	local function priceOf(id)
		local def = if kind == "obstacle" then Obstacles.ById[id] else NPCs.ById[id]
		return def and def.price or math.huge
	end
	table.sort(ids, function(a, b)
		local pa, pb = priceOf(a), priceOf(b)
		if pa ~= pb then return pa < pb end
		return a < b
	end)
	for _, id in ids do
		local ok, c = pcall(buildCard, kind, id, v.grid)
		if ok then v.cards[#v.cards + 1] = c else warn("[Shop] card " .. id .. ": " .. tostring(c)) end
	end
end

local function apply(p)
	if not p or p.ok == false then return end
	local changed = table.concat(p.obstacle or {}, ",") ~= table.concat(shelf.obstacle, ",") or table.concat(p.npc or {}, ",") ~= table.concat(shelf.npc, ",")
	shelf.obstacle, shelf.npc, shelf.nextRefresh, shelf.loaded = p.obstacle or {}, p.npc or {}, p.nextRefresh, true
	if changed or #views.obstacle.cards == 0 then
		for kind in views do render(kind) end
		if changed and p.slot then HUDController.Toast("Shops refreshed!", "info") end
	end
end

local function makeView(kind, title, accent, icon)
	local win = UIKit.window(HUDController.Gui, title, UDim2.fromOffset(920, 620), accent, icon)
	local timer = UIKit.label(win.body, { Text = "", TextSize = 24, Size = UDim2.new(0.68, 0, 0, 34), TextColor3 = C.yellow, TextXAlignment = Enum.TextXAlignment.Left, stroke = 3.5 })
	local goButton = UIKit.button(win.body, { name = "GoToShop", text = "Go to shop", color = C.yellow, size = UDim2.fromOffset(170, 38), pos = UDim2.new(1, -170, 0, -2), textSize = 20, onClick = function() ShopController.Teleport(kind) end })
	local scroll = UIKit.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 44), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 10, ScrollBarImageColor3 = C.muted, BorderSizePixel = 0 }, win.body)
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(CARD_W, CARD_H[kind]), CellPadding = UDim2.fromOffset(12, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, scroll)
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, scroll)
	views[kind] = { win = win, grid = scroll, timer = timer, cards = {} }
	-- audit 2.1: the "New items in m:ss" countdown ticks only while THIS window is open. Shelf changes arrive by the ShopSync event;
	-- if the refresh moment passed and no event came within 3 s, ask once (covers a dropped event).
	local ticking = false
	win.onOpen = function()
		local worldShops = workspace:FindFirstChild("WorldAssets") and workspace.WorldAssets:FindFirstChild("Shops")
		local shopModel = worldShops and worldShops:FindFirstChild("Shop_" .. kind)
		local char = game:GetService("Players").LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		goButton.Visible = not (shopModel and hrp and (hrp.Position - shopModel:GetPivot().Position).Magnitude < 45)
		local r = Net.invoke("GetShops")
		if r.ok then apply(r) end
		if ticking then return end
		ticking = true
		task.spawn(function()
			local asked = 0
			while win.isOpen() do
				local left = math.max(0, shelf.nextRefresh - workspace:GetServerTimeNow())
				timer.Text = ("New items in %d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
					local npcState = StateController.State and StateController.State.npc
					if kind == "npc" and npcState and npcState.limit then timer.Text ..= ("     Runners at once: %d%s"):format(npcState.limit, if npcState.limit < (npcState.padCount or 10) then " (Rebirth for more)" else "") end
				if left <= 0 and shelf.nextRefresh - workspace:GetServerTimeNow() < -3 and os.clock() - asked > 5 then
					asked = os.clock()
					local rr = Net.invoke("GetShops")
					if rr.ok then apply(rr) end
				end
				task.wait(0.5)
			end
			ticking = false
		end)
	end
end

function ShopController.Open(kind) views[kind].win.open() end

-- Every physical shop has a teleport button (the Robux/donation shop has none by design: it is only a window)
local TELEPORT_ERRORS = require(Configs.Strings).Teleport   -- audit 2.4
function ShopController.Teleport(kind)
	local r = Net.invoke("TeleportToShop", { shop = kind })
	if r.ok then
		SfxController.Play("teleport")
		if views[kind] and views[kind].win.isOpen() then views[kind].win.close() end
		-- frame the destination: camera behind the body, looking where the server turned it (the counter / down your course)
		task.delay(0.12, function()
			local char = game:GetService("Players").LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local cam = workspace.CurrentCamera
			if hrp and cam.CameraType == Enum.CameraType.Custom then
				local f = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
				if f.Magnitude > 0.1 then
					f = f.Unit
					if kind == "home" then
						cam.CFrame = CFrame.lookAt(hrp.Position - f * 24 + Vector3.new(0, 11, 0), hrp.Position + f * 12)
					else    -- shop: an almost level view at head height, so the seller under the awning is visible (a high view showed only the roof)
						cam.CFrame = CFrame.lookAt(hrp.Position - f * 20 + Vector3.new(0, 4, 0), hrp.Position + f * 20 + Vector3.new(0, 1, 0))
					end
				end
			end
		end)
		-- (session 8, skill review G09) no arrival toast: the camera already frames the kiosk, its sign and "E Open"
	else
		SfxController.Play("deny")
		HUDController.Toast(TELEPORT_ERRORS[r.err] or "Teleport failed", "err")
	end
end

function ShopController.Start()
	makeView("obstacle", "Obstacle Shop", C.teal, Icons.shop)
	makeView("npc", "NPC Shop", C.purple, Icons.npcshop)
	-- Owner rule (T37): the Shop / NPC Shop buttons sit at the TOP of the screen and ONLY teleport to the shop building; the window opens at the counter
	local compact = HUDController.Compact
	local height, width, gap = if compact then 74 else 54, if compact then 126 else 146, 10
	local npcExtra = if compact then 36 else 30
	local rowWidth = width * 3 + npcExtra + gap * 2
	local bar = UIKit.new("Frame", { Name = "ShopBar", BackgroundTransparency = 1, Size = UDim2.fromOffset(rowWidth, height),
		Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0) }, HUDController.Gui)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder }, bar)
	-- The reference uses horizontal plates, with the icon and label entirely inside each plate.
	local PLATES = {
		{ kind = "obstacle", id = "shop", text = "Shop", col = Color3.fromRGB(32, 150, 240), icon = Icons.shop },
		{ kind = "home", id = "home", text = "Home", col = Color3.fromRGB(46, 184, 62), icon = Icons.home or Icons.build },
		{ kind = "npc", id = "npcshop", text = "NPC Shop", col = Color3.fromRGB(150, 70, 235), icon = Icons.npcshop },
	}
	for i, p in PLATES do
		local w = width + (if p.kind == "npc" then npcExtra else 0)
		local b = UIKit.button(bar, { name = p.id, text = "", color = p.col, size = UDim2.fromOffset(w, height),
			order = i, onClick = function() ShopController.Teleport(p.kind) end })
		local icon = if compact then 47 else 42
		UIKit.new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = p.icon, Size = UDim2.fromOffset(icon, icon),
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), ZIndex = 4, ScaleType = Enum.ScaleType.Fit }, b)
		UIKit.label(b, { Name = "Caption", Text = p.text, TextSize = if compact then 22 else 24,
			Size = UDim2.new(1, -(icon + 17), 1, -10), Position = UDim2.fromOffset(icon + 10, 5), ZIndex = 5, stroke = 3.2 })
		HUDController.Menu[p.id] = b
	end
	-- Keep the navigation clear of currency and the vertical action buttons.
	local fit = Instance.new("UIScale"); fit.Name = "FitScale"; fit.Parent = bar
	local function keepClear()
		local gui = HUDController.Gui
		local us = gui:FindFirstChildOfClass("UIScale")
		local scale = if us then us.Scale else 1
		local rawW = rowWidth * scale
		fit.Scale = 1
		bar.AnchorPoint = Vector2.new(0.5, 0)
		local gw = gui.AbsoluteSize.X
		local reserve = 0
		for _, n in { "Coins", "Rebirth" } do
			local o = gui:FindFirstChild(n)
			if o and o.Visible then reserve = math.max(reserve, o.AbsolutePosition.X - gui.AbsolutePosition.X + o.AbsoluteSize.X + 12 * scale) end
		end
		local left = gw / 2 - rawW / 2
		local need = reserve - left
		if need <= 0 then
			bar.Position = UDim2.new(0.5, 0, 0, 8)
		elseif left + need + rawW <= gw - 8 * scale then
			bar.Position = UDim2.new(0.5, need / scale, 0, 8)
		else
			local progress = gui:FindFirstChild("Rebirth")
			local bottom = if progress then progress.AbsolutePosition.Y - gui.AbsolutePosition.Y + progress.AbsoluteSize.Y else 74 * scale
			local available = gw - 24 * scale
			fit.Scale = math.clamp(available / rawW, 0.1, 1)
			bar.Position = UDim2.new(0.5, 0, 0, bottom / scale + 8)
		end
	end
	task.defer(keepClear)
	task.delay(0.5, keepClear); task.delay(2, keepClear)
	HUDController.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(keepClear) end)
	Net.on("OpenShop", function(kind) if views[kind] then views[kind].win.open() end end)   -- the counter prompt in the world
	Net.on("ShopSync", apply)
	StateController.Changed.Event:Connect(function()
		for _, v in views do for _, c in v.cards do c.update() end end
	end)
	task.spawn(function()
		for _ = 1, 10 do
			local r = Net.invoke("GetShops")
			if r.ok then apply(r); break end
			task.wait(1)
		end
		-- audit 2 fix: no eternal background poll - the server pushes ShopSync on every rotation,
		-- and win.onOpen resyncs when the countdown shows stale data (covers a dropped event)
	end)
end

return ShopController
