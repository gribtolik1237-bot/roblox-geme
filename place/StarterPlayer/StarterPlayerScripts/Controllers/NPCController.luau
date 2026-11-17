-- NPC window (v2 look): collection (permanent), 5 quick slots, 10 start pads (place / launch / recall) + live run progress.
-- NPCs are launched ONLY from here (never from the PLAY sign). All rules are enforced by the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Configs = ReplicatedStorage.Configs
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)
local NPCRig = require(ReplicatedStorage.Shared.NPCRig)
local NPCs = require(Configs.NPCs)
local Balance = require(Configs.Balance)
local Icons = require(Configs.Icons)
local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)

local C = UIKit.C
local WHITE = Color3.new(1, 1, 1)
local NPCController = {}
local win, infoLabel, slotButtons, collection, padList, progress
local selectedSlot = 1
local padRows = {}
local runLines = {}
local LEFT_W = 556
local STAT_HEX = { "#22C8E8", "#56D638", "#FFCC24", "#FF8E20", "#AC5CFF" }   -- SPD JMP BAL REC CTL (same colours as the shop bars)

local function npcPreview(parent, id, zoom)
	local ok, m = pcall(NPCRig.build, id)
	if ok and m then UIKit.preview(parent, m, { zoom = zoom or 1.1, dir = Vector3.new(0.55, 0.3, -1) }) end
end

local function refreshSlots()
	local s = StateController.State
	if not s then return end
	for i, b in slotButtons do
		for _, c in b:GetChildren() do if c.Name == "Preview" or c.Name == "SlotName" or c.Name == "Empty" then c:Destroy() end end
		local id = s.slots[i]
		local st = b:FindFirstChildOfClass("UIStroke")
		local sel = i == selectedSlot
		st.Color = if sel then C.yellow else UIKit.INK
		st.Thickness = if sel then 5 else 3.5
		if id then
			local holder = UIKit.new("Frame", { Name = "Preview", Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 2), BackgroundTransparency = 1 }, b)
			npcPreview(holder, id)
			UIKit.label(b, { Name = "SlotName", Text = id, TextSize = 15, Size = UDim2.new(1, -4, 0, 18), Position = UDim2.new(0, 2, 1, -20), ZIndex = 3, stroke = 3 })
		else
			UIKit.label(b, { Name = "Empty", Text = "+", TextSize = 46, Size = UDim2.fromScale(1, 1), TextColor3 = C.muted, TextTransparency = 0.35, stroke = 3 })
		end
	end
end

local function refreshCollection()
	local s = StateController.State
	if not s then return end
	for _, c in collection:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	for n, id in s.npcs do
		local def = NPCs.ById[id]
		if def then
			local rc = UIKit.rarityColor(def.rarity)
			local k = UIKit.itemCard(collection, { w = 168, h = 190, rarity = rc, name = def.name, tag = def.rarity, pvH = 112, order = n })
			k.card.Name = id
			npcPreview(k.pv, id)
			local st = def.stats
			UIKit.label(k.card, { Text = ('<font color="%s">%d</font>  <font color="%s">%d</font>  <font color="%s">%d</font>  <font color="%s">%d</font>  <font color="%s">%d</font>'):format(
				STAT_HEX[1], st.speed, STAT_HEX[2], st.jump, STAT_HEX[3], st.balance, STAT_HEX[4], st.recovery, STAT_HEX[5], st.control),
				RichText = true, TextSize = 19, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, k.y + 2), stroke = 2.5 })
			local reach = s.npc and s.npc.reach and s.npc.reach[id]
			if reach and (s.npc.maxGap or 0) > reach then      -- this NPC cannot cross the widest gap of the player's course
				UIKit.label(k.card, { Text = ("can't cross %.1f gap"):format(s.npc.maxGap), Font = UIKit.BODY, TextSize = 12, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, k.y + 26), TextColor3 = C.red, stroke = 1.5 })
			end
			local inSlot = table.find(s.slots, id)
			if inSlot then UIKit.tag(k.card, "SLOT " .. inSlot, C.teal, UDim2.fromOffset(66, 24), UDim2.fromOffset(168 - 72, 6), 13) end
			local hit = UIKit.new("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 12 }, k.card)
			hit.Activated:Connect(function()
				local r = Net.invoke("SetSlot", { slot = selectedSlot, id = id })
				if not r.ok then HUDController.Toast(UIKit.err(r.err), "err") end
			end)
		end
	end
end

local function refreshPads()
	local s = StateController.State
	if not s or not s.npc then return end
	local n = s.npc
	local course = s.course
	local warn = ""
	if course then
		if not course.playerPlayable then warn = "  -  your course isn't finished yet"
		elseif not course.npcPlayable then warn = "  -  NPC-incompatible obstacles on the route" end
	end
	infoLabel.Text = ("Active NPCs %d/%d%s"):format(n.active, n.limit, warn)
	infoLabel.TextColor3 = if warn ~= "" then C.orange else C.yellow
	-- (skill roblox-game-design, TRAP LAB case G12) placing an NPC is preparation and stays allowed; LAUNCHING needs a finished course -
	-- so the reason sits next to the button and the button says what to do, instead of an always-green "Place"/"Launch"
	local blocked = course ~= nil and not course.npcPlayable
	local why = if course and not course.playerPlayable then "Course not ready" elseif blocked then "Trap not for NPCs" else nil
	for i = 1, n.padCount do
		local row = padRows[i]
		local e = n.pads[tostring(i)]
		local locked = i > n.limit
		row.name.Text = ("Pad %d"):format(i)
		row.frame.BackgroundTransparency = if locked then 0.45 else 0
		row.badge.BackgroundColor3 = if locked then C.panel2 else C.teal
		if locked then
			row.status.Text = "Locked - more Rebirths"; row.status.TextColor3 = C.muted
			row.act.Visible = false; row.recall.Visible = false
		elseif not e then
			row.status.Text = why or "Free"; row.status.TextColor3 = if why then C.orange else C.green
			row.act.Visible = true; row.act.Text = "Place"; row.act.BackgroundColor3 = C.teal; row.recall.Visible = false
			row.mode = "place"
		elseif e.status == "placed" then
			row.status.Text = e.npc .. " ready"; row.status.TextColor3 = C.yellow
			row.act.Visible = true; row.recall.Visible = true
			if blocked then
				row.status.Text = why or ""; row.status.TextColor3 = C.orange
				row.act.Text = "Fix course"; row.act.BackgroundColor3 = C.panel2; row.mode = "blocked"
			else
				row.act.Text = "Launch"; row.act.BackgroundColor3 = C.green; row.mode = "launch"
			end
		else
			row.status.Text = ("%s running %d/%d"):format(e.npc, e.stage, e.total); row.status.TextColor3 = C.orange
			row.act.Visible = false; row.recall.Visible = true; row.mode = "running"
		end
	end
end

local function setProgress(pad, text)
	local l = runLines[pad]
	if not text then if l then l:Destroy(); runLines[pad] = nil end return end
	if not l then
		l = UIKit.label(progress, { Text = "", TextSize = 24, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Right, LayoutOrder = pad, TextColor3 = C.yellow, stroke = 4 })
		runLines[pad] = l
	end
	l.Text = text
end

function NPCController.Start()
	win = UIKit.window(HUDController.Gui, "NPC Testers", UDim2.fromOffset(960, 620), C.blue, Icons.npcs)
	local body = win.body
	infoLabel = UIKit.label(body, { Text = "", TextSize = 26, Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.yellow, stroke = 3.5 })
	-- quick slots
	UIKit.label(body, { Text = "QUICK SLOTS: pick a slot, then tap an NPC", Font = UIKit.BODY, TextSize = 14, Size = UDim2.new(0, LEFT_W, 0, 18), Position = UDim2.fromOffset(0, 38), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.muted, stroke = 1.5 })
	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(LEFT_W, 104), Position = UDim2.fromOffset(0, 60) }, body)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12) }, row)
	slotButtons = {}
	for i = 1, Balance.NpcSlots do
		local b = UIKit.new("TextButton", { Name = "Slot" .. i, Size = UDim2.fromOffset(100, 100), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, LayoutOrder = i }, row)
		UIKit.round(b, 16); UIKit.stroke(b, UIKit.INK, 3.5)
		UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(86, 92, 128), Color3.fromRGB(46, 50, 76)), Rotation = 90 }, b)
		UIKit.label(b, { Name = "Num", Text = tostring(i), TextSize = 20, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(5, 3), TextColor3 = C.yellow, ZIndex = 4, stroke = 3 })
		b.Activated:Connect(function()
			if selectedSlot == i and StateController.State and StateController.State.slots[i] then
				Net.invoke("SetSlot", { slot = i, id = false })       -- tap the selected slot again to empty it
			end
			selectedSlot = i; refreshSlots()
		end)
		slotButtons[i] = b
	end
	-- collection
	UIKit.label(body, { Text = ('COLLECTION (yours forever)     <font color="%s">SPD</font> <font color="%s">JMP</font> <font color="%s">BAL</font> <font color="%s">REC</font> <font color="%s">CTL</font>'):format(STAT_HEX[1], STAT_HEX[2], STAT_HEX[3], STAT_HEX[4], STAT_HEX[5]),
		RichText = true, TextSize = 14, Font = UIKit.BODY, Size = UDim2.new(0, LEFT_W, 0, 18), Position = UDim2.fromOffset(0, 172), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.muted, stroke = 1.5 })
	collection = UIKit.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(0, LEFT_W, 1, -196), Position = UDim2.fromOffset(0, 194), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = C.muted, BorderSizePixel = 0 }, body)
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(168, 190), CellPadding = UDim2.fromOffset(10, 12), SortOrder = Enum.SortOrder.LayoutOrder }, collection)
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) }, collection)

	-- start pads
	local PX = LEFT_W + 18
	UIKit.label(body, { Text = "START PADS", TextSize = 24, Size = UDim2.new(1, -PX, 0, 30), Position = UDim2.fromOffset(PX, 4), TextXAlignment = Enum.TextXAlignment.Left, stroke = 3.5 })
	padList = UIKit.new("ScrollingFrame", { Name = "PadList", BackgroundTransparency = 1, Size = UDim2.new(1, -PX, 1, -40), Position = UDim2.fromOffset(PX, 40), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = C.muted, BorderSizePixel = 0 }, body)
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, padList)
	for i = 1, Balance.NpcPads do
		local f = UIKit.new("Frame", { Name = "Pad" .. i, Size = UDim2.new(1, -14, 0, 62), BackgroundColor3 = WHITE, LayoutOrder = i }, padList)
		UIKit.round(f, 14); UIKit.stroke(f, UIKit.INK, 3.5)
		UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(78, 82, 116), Color3.fromRGB(50, 53, 80)), Rotation = 90 }, f)
		local r = { frame = f, mode = "place" }
		r.badge = UIKit.new("Frame", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(10, 11), BackgroundColor3 = C.teal }, f)
		UIKit.round(r.badge, 20); UIKit.stroke(r.badge, UIKit.INK, 3)
		UIKit.label(r.badge, { Text = tostring(i), TextSize = 22, Size = UDim2.fromScale(1, 1), stroke = 3 })
		r.name = UIKit.label(f, { Text = "", TextSize = 20, Size = UDim2.fromOffset(120, 24), Position = UDim2.fromOffset(60, 7), TextXAlignment = Enum.TextXAlignment.Left, stroke = 3 })
		r.status = UIKit.label(f, { Text = "", Font = UIKit.BODY, TextSize = 14, TextScaled = true, Size = UDim2.fromOffset(110, 20), Position = UDim2.fromOffset(60, 33), TextXAlignment = Enum.TextXAlignment.Left, stroke = 2 })
		UIKit.new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 10 }, r.status)
		r.act = UIKit.button(f, { name = "Act", text = "Place", color = C.teal, size = UDim2.fromOffset(84, 42), pos = UDim2.new(1, -164, 0.5, -21), textSize = 20, onClick = function()
			local res
			if r.mode == "place" then res = Net.invoke("PlaceNpc", { slot = selectedSlot, pad = i })
			elseif r.mode == "blocked" then
				local c = StateController.State and StateController.State.course
				HUDController.Toast(if c and not c.playerPlayable then "Join your traps from the Start to the Finish (green ghost = joins)" else "Some traps on the route can't be used by NPCs", "err")
			elseif r.mode == "launch" then
				res = Net.invoke("LaunchNpc", { pad = i })
				if res and res.ok and win.isOpen() then win.close() end      -- get out of the way: watching the runner IS the reward
			end
			if res and not res.ok then
				HUDController.Toast(UIKit.err(res.err) .. (if res.detail then (" (" .. res.detail .. ")") else ""), "err")
			end
		end })
		r.recall = UIKit.button(f, { text = "Recall", color = C.red, size = UDim2.fromOffset(72, 42), pos = UDim2.new(1, -78, 0.5, -21), textSize = 18, onClick = function()
			local res = Net.invoke("RecallNpc", { pad = i })
			if not res.ok then HUDController.Toast(UIKit.err(res.err), "err") end
		end })
		padRows[i] = r
	end

	progress = UIKit.new("Frame", { Name = "NpcProgress", BackgroundTransparency = 1, Size = UDim2.fromOffset(340, 170), Position = UDim2.new(1, -14, 1, -86), AnchorPoint = Vector2.new(1, 1) }, HUDController.Gui)
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right }, progress)

	-- catalog hair on every NPC in the world, added LOCALLY (cosmetic only; the server-simulated body stays the tested one)
	local function dressIfNpc(m)
		if m:IsA("Model") and m:GetAttribute("Npc") == true then
			task.defer(function()
				m:WaitForChild("Head", 5)
				pcall(NPCRig.DressLocal, m)
			end)
		end
	end
	local plots = workspace:WaitForChild("PlayerPlots", 10)
	if plots then
		for _, d in plots:GetDescendants() do dressIfNpc(d) end
		plots.DescendantAdded:Connect(dressIfNpc)
	end

	HUDController.AddMenuButton("npcs", "NPCs", C.blue, 4, function() win.toggle() end)
	win.onOpen = function() refreshSlots(); refreshCollection(); refreshPads() end
	StateController.Changed.Event:Connect(function() refreshSlots(); refreshCollection(); refreshPads() end)

	-- juice for the money moment: a coin + "+N" pops above the runner on every paid stage (rises, grows, fades)
	local lastEarned = {}
	local function coinPop(padIndex, amount)
		if amount <= 0 then return end
		local npc
		for _, plot in workspace.PlayerPlots:GetChildren() do
			if plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId and plot:FindFirstChild("Npcs") then
				for _, m in plot.Npcs:GetChildren() do
					if m:IsA("Model") and (m:GetAttribute("Pad") == padIndex or npc == nil) then npc = m end
				end
			end
		end
		if not npc then return end
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(150, 56); bb.AlwaysOnTop = true; bb.LightInfluence = 0
		bb.StudsOffsetWorldSpace = Vector3.new(0, 5, 0); bb.Adornee = npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
		local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, bb)
		UIKit.coin(row, 44, UDim2.fromOffset(6, 6))
		local t = UIKit.label(row, { Text = "+" .. Util.fmt(amount), TextSize = 40, Size = UDim2.new(1, -54, 1, 0), Position = UDim2.fromOffset(54, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 214, 64), stroke = 4 })
		local sc = UIKit.new("UIScale", { Scale = 0.4 }, row)
		bb.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(bb, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, 11, 0) }):Play()
		task.delay(0.75, function()
			TweenService:Create(t, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
			for _, d in row:GetDescendants() do
				if d:IsA("ImageLabel") then TweenService:Create(d, TweenInfo.new(0.45), { ImageTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then TweenService:Create(d, TweenInfo.new(0.45), { Transparency = 1 }):Play() end
			end
		end)
		task.delay(1.3, function() bb:Destroy() end)
	end

	Net.on("NpcState", function(p)
		if p.state == "stage" then
			local prev = lastEarned[p.pad] or 0
			lastEarned[p.pad] = p.earned or prev
			coinPop(p.pad, (p.earned or prev) - prev)
		elseif p.state == "start" then lastEarned[p.pad] = 0 end
		if p.state == "start" then
			HUDController.Toast(p.npc .. " is off!", "info")
			setProgress(p.pad, ("%s  0/%d"):format(p.npc, p.total))
		elseif p.state == "stage" then
			setProgress(p.pad, ("%s  %d/%d   +%d"):format(p.npc, p.stage, p.total, p.earned))
		elseif p.state == "stumble" then
			HUDController.Toast(p.npc .. (if p.recovered then " stumbled but recovered!" else " lost its balance!"), if p.recovered then "info" else "err")
		elseif p.state == "end" then
			setProgress(p.pad, nil)
			local total = (p.earned or 0) + (p.bonus or 0)
			if p.outcome == "finished" then
				HUDController.Toast(("%s finished the course! +%s Coins"):format(p.npc, Util.fmt(total)), "ok")
			elseif p.outcome == "failed" then
				local why = tostring(p.reason or "")
				local txt = if why:find("cannot_cross") then (why:match("cannot_cross: ([^%[]+)") or "too far to jump") elseif why:find("fell") then "fell" elseif why:find("hazard") then "hit a hazard" elseif why:find("stuck") then "got stuck" else "stopped"
				HUDController.Toast(("%s %s - %d stage(s), +%s Coins"):format(p.npc, txt, p.stage or 0, Util.fmt(total)), "err")
			else
				HUDController.Toast(("%s run ended - +%s Coins"):format(p.npc, Util.fmt(total)), "info")
			end
		end
	end)
end

return NPCController
