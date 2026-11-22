-- Build mode: transparent ghost on a snapped grid, green/red validity, rotate, height levels, move, remove.
-- The ghost is only a PREVIEW: the server re-validates owner, item ownership, bounds, overlap and limits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local Configs = ReplicatedStorage.Configs
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Net = require(ReplicatedStorage.Shared.Net)
local PlotMath = require(ReplicatedStorage.Shared.PlotMath)
local ObstacleModels = require(ReplicatedStorage.Shared.ObstacleModels)
local Obstacles = require(Configs.Obstacles)
local Balance = require(Configs.Balance)
local Icons = require(Configs.Icons)
local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)

local C = UIKit.C
local player = Players.LocalPlayer
local BuildController = {}
local hasTouch = UserInputService.TouchEnabled

local function usingGamepad()
	return UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
end

local active, mode = false, "place"          -- mode: place | move | remove
local selectedId, rot, level, fine = nil, 0, 0, false
local ghostR = 0          -- the rotation the ghost actually has (magnet may straighten it); rot = what the player asked for with R
local ghost, ghostId, ghostHL, moveUid = nil, nil, nil, nil
local plot, originCF = nil, nil
local lastTouch = nil
local busy = false
local valid, reason = false, ""
local gx, gz = 0, -40
local hoverHL = nil
local bindBuildActions: (boolean) -> () = function(_) end   -- forward declaration (defined after the actions it binds)
local joined = false       -- the ghost sits flush on the course end (magnet) - declared early: doClick reads it
local ui = {}
-- session 8 (skill review G01/G02): ONE result per attempt, shown in the build bar line itself (no toast next to it)
local flashText, flashColor, flashUntil = "", Color3.new(1, 1, 1), 0
local function flash(text: string, color: Color3, secs: number?)
	-- audit 2 (A.5): 2 s default - 1.4 s was too short to read the result line comfortably
	flashText, flashColor, flashUntil = text, color, os.clock() + (secs or 2)
end

local function findPlot()
	for _, m in workspace.PlayerPlots:GetChildren() do
		if m:GetAttribute("OwnerId") == player.UserId then return m end
	end
	return nil
end

local function existingBoxes(ignoreUid)
	local list = {}
	for _, m in plot.Course:GetChildren() do
		local d = Obstacles.ById[m:GetAttribute("ObstacleId")]
		if d and m:GetAttribute("Uid") ~= ignoreUid then
			list[#list + 1] = PlotMath.box(d.size, m:GetAttribute("X"), m:GetAttribute("Y"), m:GetAttribute("Z"), m:GetAttribute("R"))
		end
	end
	return list
end

local function availableOf(def)
	local s = StateController.State
	if not s then return 0 end
	local placed = s.plot and s.plot.placed[def.id] or 0
	if def.free then return if def.unique then 1 - placed else 99 end
	return (s.inv[def.id] or 0) - placed
end

local function clearGhost()
	if ghost then ghost:Destroy() end
	ghost, ghostId, ghostHL = nil, nil, nil
end

local function makeGhost(id)
	clearGhost()
	local m = ObstacleModels.build(id)
	if not m then return end
	local parts = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false; d.CanQuery = false; d.CanTouch = false
			if d.Transparency < 1 then d.Transparency = math.max(d.Transparency, 0.35); table.insert(parts, d) end
			d.Material = Enum.Material.SmoothPlastic
		elseif d:IsA("SurfaceGui") or d:IsA("PointLight") then d:Destroy() end
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.38; hl.OutlineTransparency = 0; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = m
	m:SetAttribute("Tint", "")
	ui.ghostParts = parts      -- the ghost itself is painted green/red (a Highlight alone was not drawn in testing)
	m.Name = "BuildGhost"
	m.Parent = workspace       -- (session 6 bug: a Highlight under workspace.CurrentCamera is NOT drawn -> the ghost had no green/red tint). Client-only, never replicated.
	ghost, ghostId, ghostHL = m, id, hl
end

local function cursorRay()
	local camera = workspace.CurrentCamera
	if usingGamepad() then
		local center = camera.ViewportSize * 0.5
		return camera:ViewportPointToRay(center.X, center.Y)
	end
	local pos = if UserInputService.PreferredInput == Enum.PreferredInput.Touch then lastTouch else UserInputService:GetMouseLocation()
	if not pos then return nil end
	return camera:ViewportPointToRay(pos.X, pos.Y)
end

local function cursorOnPlane(planeY)
	local ray = cursorRay()
	if not ray then return nil end
	if math.abs(ray.Direction.Y) < 1e-4 then return nil end
	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 or t > 900 then return nil end
	return ray.Origin + ray.Direction * t
end

local function evaluate(def, x, z)
	local s = StateController.State
	if not s or not s.plot then return false, "NoProfile" end
	local box = PlotMath.box(def.size, x, level, z, ghostR)
	if not PlotMath.inZone(box, s.plot.width, s.plot.length) then return false, "OutOfBounds" end
	for _, b in existingBoxes(moveUid) do
		if PlotMath.overlap(box, b) then return false, "Overlap" end
	end
	if mode == "place" then
		if availableOf(def) <= 0 then return false, "NoItem" end
		if s.plot.count >= s.plot.limit then return false, "LimitReached" end
	end
	return true, nil
end

local function setHover(model)
	if hoverHL and hoverHL.Parent ~= model then hoverHL:Destroy(); hoverHL = nil end
	if model and not hoverHL then
		hoverHL = Instance.new("Highlight")
		hoverHL.FillColor = if mode == "remove" then C.red else C.yellow
		hoverHL.FillTransparency = 0.45; hoverHL.Parent = model
	end
end

local function hoveredObstacle()
	local ray = cursorRay()
	if not ray then return nil end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { plot.Course }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 900, rp)
	local inst = hit and hit.Instance
	while inst and inst.Parent ~= plot.Course do inst = inst.Parent end
	return inst
end

-- ===== hotbar (slots, as in every Roblox game): slot 1 = hammer; with the hammer in hand the slots hold the inventory; last slot = Delete =====
local BASE_SLOT = if hasTouch then 56 else 68
local MAX_PAGE, SLOT_GAP = 8, 6
local slotSize, pageSize = BASE_SLOT, MAX_PAGE
local toolWidth, toolHeight, tightTools = 540, 36, false
local page = 1
local KEYNUM = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9 }
local SLOT_BG = Color3.fromRGB(22, 24, 30)

local function newSlot(parent, order, keyText, selected)
	local b = UIKit.new("TextButton", { Size = UDim2.fromOffset(slotSize, slotSize), BackgroundColor3 = SLOT_BG, BackgroundTransparency = 0.2, Text = "", AutoButtonColor = false, LayoutOrder = order }, parent)
	UIKit.round(b, 10)
	UIKit.stroke(b, if selected then C.yellow else UIKit.INK, if selected then 5 else 3)
	if keyText then UIKit.label(b, { Text = keyText, TextSize = 15, Size = UDim2.fromOffset(24, 18), Position = UDim2.fromOffset(5, 2), TextXAlignment = Enum.TextXAlignment.Left, stroke = 2.5 }) end
	return b
end

-- Which bar buttons make sense right now (skill review G06: Move/Rotate/Up/Down all showed before any piece was picked)
local function refreshTools()
	if not ui.tools then return end
	local holding = ghost ~= nil and (mode == "place" or (mode == "move" and moveUid ~= nil))
	ui.tools.rotate.Visible = holding
	ui.tools.up.Visible = holding
	ui.tools.down.Visible = holding
	if ui.tools.place then ui.tools.place.Visible = holding end
	if ui.tools.cancel then ui.tools.cancel.Visible = holding end
	ui.tools.move.Visible = mode ~= "remove" and not (mode == "place" and holding)
	ui.tools.move.BackgroundColor3 = if mode == "move" then C.yellow else C.blue
	local visibleCount, naturalWidth = 0, 0
	for _, button in ui.toolButtons do
		if button.Visible then
			visibleCount += 1
			naturalWidth += if button == ui.tools.move and mode == "move" then 150 else button:GetAttribute("BaseWidth")
		end
	end
	local gaps = 8 * math.max(0, visibleCount - 1)
	local compactLabels = tightTools or naturalWidth + gaps > toolWidth
	local share = math.min(160, (toolWidth - gaps) / math.max(1, visibleCount))
	local gamepad = usingGamepad()
	local shortcuts = (gamepad or not hasTouch) and not compactLabels
	ui.tools.move.Text = if mode == "move" then (if compactLabels and holding then "Stop" else "Stop moving") elseif compactLabels then "Move" elseif gamepad then "Move (X)" else ui.tools.moveText
	ui.tools.rotate.Text = if not shortcuts then "Turn" elseif gamepad then "Turn (RB)" else "Turn (R)"
	ui.tools.up.Text = if not shortcuts then "Up" elseif gamepad then "Up (D-pad)" else "Up (E)"
	ui.tools.down.Text = if not shortcuts then "Down" elseif gamepad then "Down (D-pad)" else "Down (Q)"
	ui.tools.cancel.Text = if not shortcuts then "Cancel" elseif gamepad then "Cancel (B)" else "Cancel (Bksp)"
	for _, button in ui.toolButtons do
		local width = if button == ui.tools.move and mode == "move" then 150 else button:GetAttribute("BaseWidth")
		button.Size = UDim2.fromOffset(if compactLabels then share else width, toolHeight)
	end
end

local function refreshBar()
	if not ui.hot then return end
	for _, b in ui.hot:GetChildren() do if b:IsA("GuiObject") and b.Name ~= "Hammer" then b:Destroy() end end
	-- hammer in hand = green slot (build mode ON); the chosen trap = bigger slot with a yellow frame (two different signals)
	local hs = ui.hammer and ui.hammer:FindFirstChildOfClass("UIStroke")
	if hs then hs.Color = UIKit.INK; hs.Thickness = if active then 4 else 3 end
	if ui.hammer then
		ui.hammer.BackgroundColor3 = if active then Color3.fromRGB(40, 150, 60) else SLOT_BG
		ui.hammer.BackgroundTransparency = if active then 0 else 0.2
	end
	if ui.bar then ui.bar.Visible = active end
	-- the last copy was just placed (state arrives after the click): drop the empty hand so Turn/Up/Down do not linger
	if mode == "place" and selectedId then
		local d = Obstacles.ById[selectedId]
		if not d or availableOf(d) <= 0 then selectedId = nil; clearGhost() end
	end
	refreshTools()
	ui.slotIds = {}
	if not active then return end
	local list = {}
	for _, def in Obstacles.List do if availableOf(def) > 0 then list[#list + 1] = def end end
	local pages = math.max(1, math.ceil(#list / pageSize))
	page = math.clamp(page, 1, pages)
	for i = 1, pageSize do
		local def = list[(page - 1) * pageSize + i]
		if not def then break end
		local n = availableOf(def)
		local sel = selectedId == def.id and mode == "place"
		local b = newSlot(ui.hot, i, tostring(i + 1), sel)
		b.Name = "Slot_" .. def.id
		if sel then b.Size = UDim2.fromOffset(slotSize + 12, slotSize + 12); b.BackgroundTransparency = 0.05 end
		local pv = UIKit.new("Frame", { Size = UDim2.new(1, -8, 1, -14), Position = UDim2.fromOffset(4, 8), BackgroundTransparency = 1 }, b)
		local m = ObstacleModels.build(def.id)
		if m then UIKit.preview(pv, m) end
		UIKit.new("Frame", { Size = UDim2.new(1, -16, 0, 5), Position = UDim2.new(0, 8, 1, -9), BackgroundColor3 = UIKit.rarityColor(def.rarity), BorderSizePixel = 0 }, b)
		if not def.free then UIKit.tag(b, "x" .. n, C.blue, UDim2.fromOffset(34, 20), UDim2.new(1, -36, 0, 2), 14) end
		ui.slotIds[i + 1] = def.id
		b.Activated:Connect(function()
			if BuildController.Select(def.id) and usingGamepad() then GuiService.SelectedObject = nil end
		end)
	end
	if pages > 1 then
		local mb = newSlot(ui.hot, 50, nil, false)
		mb.Name = "More"
		UIKit.label(mb, { Text = page .. "/" .. pages, TextSize = 22, Size = UDim2.fromScale(1, 1), stroke = 3 })
		mb.Activated:Connect(function() page = page % pages + 1; refreshBar() end)
	end
	local del = newSlot(ui.hot, 100, "X", mode == "remove")
	del.Name = "Delete"; del.BackgroundColor3 = Color3.fromRGB(150, 28, 40)
	UIKit.label(del, { Text = "X", TextSize = 34, Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.fromScale(0, 0.1), TextColor3 = Color3.new(1, 1, 1), stroke = 3.5 })
	UIKit.label(del, { Text = "Delete", TextSize = 14, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -22), stroke = 2.5 })
	del.Activated:Connect(function() BuildController.SetMode(if mode == "remove" then "place" else "remove") end)
	if mode == "remove" then del.Size = UDim2.fromOffset(slotSize + 12, slotSize + 12); del.BackgroundTransparency = 0 end
end

local function setMode(m)
	mode = m; moveUid = nil
	if m ~= "place" then clearGhost(); selectedId = nil end
	refreshBar()
end

function BuildController.SetMode(m) setMode(m) end

local function doClick()
	if busy or not active or not plot then return end
	if mode == "place" then
		if not ghost then return end
		-- invalid spot: the build bar already says why - no stack of red toasts on every click (owner bug report)
		if not valid then
			flash("Can't place: " .. UIKit.err(reason), C.red, 1)
			return
		end
		busy = true
		local wasJoined = joined
		local r = Net.invoke("BuildPlace", { id = ghostId, x = gx, y = level, z = gz, r = ghostR })
		busy = false
		if r.ok then
			rot = ghostR       -- the next piece continues in the direction just placed (after a turn: straight on)
			flash(if wasJoined then "Placed - joined the course!" else "Placed (not joined to the course)", if wasJoined then C.green else C.teal)
			task.defer(function()
				local def = Obstacles.ById[selectedId]
				if not def or availableOf(def) <= 0 then selectedId = nil; clearGhost() end
				refreshBar()
			end)
		else flash("Can't place: " .. UIKit.err(r.err), C.red) end
	elseif mode == "remove" then
		local m = hoveredObstacle()
		if not m then return end
		busy = true
		local r = Net.invoke("BuildRemove", { uid = m:GetAttribute("Uid") })
		busy = false
		if r.ok then flash("Removed - back in your slots", C.teal) else flash(UIKit.err(r.err), C.red) end
	elseif mode == "move" then
		if moveUid and ghost then
			if not valid then flash("Can't put it here: " .. UIKit.err(reason), C.red, 1); return end
			busy = true
			local r = Net.invoke("BuildMove", { uid = moveUid, x = gx, y = level, z = gz, r = ghostR })
			busy = false
			if r.ok then flash("Moved", C.green); moveUid = nil; clearGhost(); refreshTools()
			else flash(UIKit.err(r.err), C.red) end
		else
			local m = hoveredObstacle()
			if not m then return end
			moveUid = m:GetAttribute("Uid")
			rot, level = m:GetAttribute("R"), m:GetAttribute("Y")
			makeGhost(m:GetAttribute("ObstacleId"))
			refreshTools()
		end
	end
end

-- ===== MAGNET (session 6, owner bug: "pieces can't be joined, a gap always stays") =====
-- The 4-stud grid snaps a piece's NEAR edge; many lengths are not multiples of 4 (18, 14, 6, 34...), so the far edge lands off-grid and the
-- next piece could only leave a gap or overlap (rejected). Now: if the ghost is near the EXIT of a placed piece (or the start edge), it
-- snaps flush to it - same direction, centred on it, and at the height where its entry meets that exit (a ramp lifts the next piece).
local MAGNET_RANGE = Balance.Build.MagnetRange     -- audit 2.3 (5); studs from the cursor to the FOOTPRINT the piece would take (cursor on/near that spot = join)
local turnJoin = false     -- the snapped spot is a 90-degree turn of the course
local function fwdOf(r: number): (number, number)
	local a = math.rad(r)
	return -math.sin(a), -math.cos(a)        -- plot-local forward (-Z rotated by r)
end
local function magnet(def, cx: number, cz: number): (number?, number?, number?, number?)
	-- returns centre x, z, level and the ROTATION that continues the course (the piece is turned to the neighbour's direction,
	-- so nothing can be joined back-to-front - an owner course had its conveyor reversed and never linked)
	local gHalf = def.size.Z / 2
	local best, bx, bz, by, br = MAGNET_RANGE, nil, nil, nil, nil
	turnJoin = false
	local function try(ex: number, ez: number, ey: number, r: number, ha: number?)   -- exit point of a neighbour (plot-local), its standing height, its direction, its half width
		-- session 8: a TURN. If the player turned the piece 90 deg (R) at the course end, keep that turn: the piece lies across the
		-- course end like an L, right in front of the exit, its entry edge starting at the exit centre (the walker steps straight onto
		-- it; NPC traversal walks along that entry edge - ObstacleTraversalService "turn"). Reversing (180) is never kept.
		local useR = r
		local dr = (rot - r) % 360
		if ha and (dr == 90 or dr == 270) then useR = rot end
		local fx, fz = fwdOf(useR)
		local nx, nz
		if useR == r then
			nx, nz = ex + fx * gHalf, ez + fz * gHalf            -- our centre so our entry sits exactly on that exit
		else
			local afx, afz = fwdOf(r)
			local off = gHalf
			nx, nz = ex + afx * def.size.X / 2 + fx * off, ez + afz * def.size.X / 2 + fz * off
		end
		local hw, hd = PlotMath.halfExtents(def.size, useR)
		local dx, dz = math.max(math.abs(cx - nx) - hw, 0), math.max(math.abs(cz - nz) - hd, 0)
		local d = math.sqrt(dx * dx + dz * dz) + 0.01 * math.sqrt((nx - cx) ^ 2 + (nz - cz) ^ 2)   -- footprint distance, centre breaks ties
		if d < best then
			local y = ey - (def.entryY or def.top)
			y = math.clamp(math.floor(y / Balance.LevelStep + 0.5) * Balance.LevelStep, 0, Balance.MaxBuildHeight)
			-- only FREE spots inside the zone (a join that overlaps another piece is no join)
			local s = StateController.State
			local box = PlotMath.box(def.size, nx, y, nz, useR)
			local free = s and s.plot and PlotMath.inZone(box, s.plot.width, s.plot.length)
			if free then for _, b in existingBoxes(moveUid) do if PlotMath.overlap(box, b) then free = false; break end end end
			if free then best, bx, bz, by, br = d, nx, nz, y, useR; turnJoin = useR ~= r end
		end
	end
	for _, m in plot.Course:GetChildren() do
		local od = Obstacles.ById[m:GetAttribute("ObstacleId")]
		if od and m:GetAttribute("Uid") ~= moveUid and od.id ~= "FinishPad" then
			local ox, oy, oz, orr = m:GetAttribute("X"), m:GetAttribute("Y"), m:GetAttribute("Z"), m:GetAttribute("R")
			if od.symmetric then orr = orr % 180 end
			local ofx, ofz = fwdOf(orr)
			try(ox + ofx * od.size.Z / 2, oz + ofz * od.size.Z / 2, oy + (od.exitY or od.top), orr, od.size.X / 2)
		end
	end
	try(cx, -Balance.StartAreaDepth, Balance.DeckTop, 0)          -- the start edge (course flows down the plot) at the cursor's x
	return bx, bz, by, br
end

local function onStep()
	ui.aim.Visible = ui.bar.Visible and usingGamepad() and (ghost ~= nil or mode ~= "place")
	if not active or not plot then return end
	if (mode == "place" or (mode == "move" and moveUid)) and ghost then
		local def = Obstacles.ById[ghostId]
		local p = cursorOnPlane(originCF.Position.Y + level)
		if p then
			local lp = originCF:PointToObjectSpace(p)
			gx, gz = PlotMath.snapCentre(def.size, lp.X, lp.Z, rot, if fine then 1 else Balance.GridSize)
			-- session 6 (owner: building was confusing): never let the ghost leave the build zone - it used to sink under the start
			-- area and vanish with only "Outside your build zone" on screen. Clamp it to the nearest spot INSIDE the zone instead.
			local s = StateController.State
			if s and s.plot then
				local hw, hd = PlotMath.halfExtents(def.size, rot)
				local G = Balance.GridSize
				local function snapIn(v, lo, hi) return math.clamp(v, lo, math.max(lo, hi)) end
				gx = snapIn(gx, -s.plot.width / 2 + hw, s.plot.width / 2 - hw)
				gz = snapIn(gz, -s.plot.length + hd, -Balance.StartAreaDepth - hd)
				gx, gz = PlotMath.snapCentre(def.size, gx, gz, rot, G)
				gx = snapIn(gx, -s.plot.width / 2 + hw, s.plot.width / 2 - hw)
				gz = snapIn(gz, -s.plot.length + hd, -Balance.StartAreaDepth - hd)
			end
			ghostR = rot
			local mx, mz, my, mr = magnet(def, lp.X, lp.Z)
			joined = mx ~= nil
			if mx then gx, gz, level, ghostR = mx, mz, my, mr end
		end
		if p then valid, reason = evaluate(def, gx, gz)
		else valid, joined, reason = false, false, "Aim" end
		ghost:PivotTo(PlotMath.cframe(originCF, gx, level, gz, ghostR))
		local tint = if valid then (if joined then "join" else "ok") else "bad"
		if ghost:GetAttribute("Tint") ~= tint then
			ghost:SetAttribute("Tint", tint)
			local col = if tint == "join" then Color3.fromRGB(70, 255, 100) elseif tint == "ok" then Color3.fromRGB(120, 210, 255) else Color3.fromRGB(255, 70, 70)
			for _, bp in ui.ghostParts or {} do bp.Color = col end
		end
		ghostHL.FillColor = if valid then (if joined then Color3.fromRGB(60, 255, 90) else C.green) else C.red
		ghostHL.FillTransparency = if valid and joined then 0.25 else 0.38
		ghostHL.OutlineColor = ghostHL.FillColor
		setHover(nil)
	elseif mode == "remove" or mode == "move" then
		setHover(hoveredObstacle())
	end
	if ui.status then
		local s = StateController.State
		-- plain words (session 6): what to do now + the one number that matters
		local info
		local gamepad = usingGamepad()
		if mode == "remove" then info = if gamepad then "Aim at a trap and press RT to remove it" elseif hasTouch then "Tap a trap to remove it" else "Click a trap to remove it"
		elseif mode == "move" then
			if moveUid then info = if gamepad then "Aim at a spot and press RT to move it" elseif hasTouch then "Tap a spot, then press PLACE" else "Click where it should go"
			else info = if gamepad then "Aim at a trap and press RT to pick it" elseif hasTouch then "Tap a trap to move it" else "Click a trap to move it" end
		elseif not ghost then
			local c = s and s.course
			info = if c and not c.playerPlayable and c.objectCount and c.objectCount > 0 then "The course is broken at the red GAP - pick a trap and join it there" else "Pick a trap in the slots below"
		elseif reason == "Aim" then info = if gamepad then "Aim at your build area" else "Tap where the trap should go"
		elseif gamepad and valid then info = if joined then "Joins the course. Press RT to place" else "RT: place    RB: turn"
		elseif valid and joined then info = if hasTouch then "Joins the course. Press PLACE" else (if turnJoin then "Turn - joins the course! Click to place" else "Joins the course! Click to place") .. "   -   R: turn"
		elseif valid then info = (if hasTouch then "Press PLACE" else "Click to place   -   R: turn") .. (if level > 0 then ("   -   height " .. level / Balance.LevelStep) else "")
		else info = UIKit.err(reason) end
		if s and s.plot then info = info .. ("      %d/%d"):format(s.plot.count, s.plot.limit) end
		if os.clock() < flashUntil then
			ui.status.Text = flashText; ui.status.TextColor3 = flashColor
		else
			ui.status.Text = info; ui.status.TextColor3 = C.yellow
		end
	end
end

-- ===== GAP MARKS (session 8, owner: "show where the course is broken right in the world") =====
-- The server's course check returns plot-local points where the reachable route stops (and the Finish entry if it is cut off).
-- While the hammer is in hand: a red pulsing pad + a bouncing "GAP" sign over each break, a yellow "join here" at a cut-off Finish.
local gapFolder = nil
local function clearGaps() if gapFolder then gapFolder:Destroy(); gapFolder = nil end end
local function gapSign(parent, text, col)
	local bb = UIKit.new("BillboardGui", { Size = UDim2.fromOffset(240, 70), StudsOffsetWorldSpace = Vector3.new(0, 5, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 400 }, parent)
	local holder = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, bb)
	UIKit.label(holder, { Text = text, TextSize = 30, Size = UDim2.new(1, 0, 0, 34), TextColor3 = col, stroke = 4 })
	UIKit.label(holder, { Text = "▼", TextSize = 30, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 32), TextColor3 = col, stroke = 4 })
	task.spawn(function()
		local t0 = os.clock()
		while holder.Parent and bb.Parent do
			holder.Position = UDim2.fromOffset(0, math.floor(math.abs(math.sin((os.clock() - t0) * 4)) * -10))
			task.wait(1 / 30)
		end
	end)
end
local function gapPad(p: Vector3, col: Color3, text: string)
	local part = UIKit.new("Part", { Name = "Gap", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7), Material = Enum.Material.Neon, Color = col, Transparency = 0.25,
		CFrame = originCF * CFrame.new(p.X, p.Y + 0.2, p.Z) * CFrame.Angles(0, 0, math.rad(90)) }, gapFolder)
	gapSign(part, text, col)
	task.spawn(function()
		while part.Parent do
			part.Transparency = 0.2 + 0.4 * (0.5 + 0.5 * math.sin(os.clock() * 5))
			task.wait(1 / 20)
		end
	end)
end
local function refreshGaps()
	clearGaps()
	local s = StateController.State
	local c = s and s.course
	if not active then return end
	-- audit 2 (A.4): a reburst swaps the plot (PlotService.Apply) - never trust the cached origin CFrame;
	-- re-find the plot and re-read its Origin on every refresh so the marks never linger on the old plot
	if not plot or not plot.Parent then plot = findPlot() end
	local origin = plot and plot:FindFirstChild("Origin")
	if origin and origin:IsA("BasePart") then originCF = origin.CFrame end
	if not plot or not originCF or not c or c.playerPlayable then return end
	gapFolder = Instance.new("Folder"); gapFolder.Name = "CourseGapMarks"; gapFolder.Parent = workspace   -- client-only
	for _, b in c.breaks or {} do
		gapPad(Vector3.new(b.x, b.y, b.z), C.red, if b.kind == "start" then "START HERE" else "GAP")
	end
	if c.finishEntry then
		local f = c.finishEntry
		gapPad(Vector3.new(f.x, f.y, f.z), C.yellow, "JOIN HERE")
	end
end

function BuildController.IsActive() return active end
function BuildController.Selected() return selectedId end   -- GuideController: is an item in hand?

-- Used by the hotbar slots, number keys and GuideController: switch build mode on and pick this item (false if it is not available)
function BuildController.Select(id)
	BuildController.SetActive(true)
	local def = Obstacles.ById[id]
	if not active or not def or availableOf(def) <= 0 then return false end
	mode = "place"; moveUid = nil; selectedId = id
	makeGhost(id); refreshBar()
	return true
end

function BuildController.SetActive(on)
	if on == active then return end
	if on and HUDController.RunMode then return end      -- no hammer while running a course
	if on then
		plot = findPlot()
		if not plot then HUDController.Toast("Your plot is not ready yet", "err"); return end
		originCF = plot.Origin.CFrame
	end
	active = on
	ui.bar.Visible = on
	if not on then clearGhost(); setHover(nil); selectedId = nil; moveUid = nil; lastTouch = nil; mode = "place" end
	if on then setMode("place") end
	bindBuildActions(on)
	refreshBar()
	refreshGaps()
end

local function rotate() rot = (rot + 90) % 360 end
local function lvl(d) level = math.clamp(level + d * Balance.LevelStep, 0, Balance.MaxBuildHeight) end
local function cancelHand() selectedId = nil; moveUid = nil; clearGhost(); refreshBar() end
local lastTrigger = -math.huge
local function applyWithTrigger()
	local now = os.clock()
	-- The controller emulator can send two Begin events for a single trigger press.
	if not ui.bar.Visible or now - lastTrigger < 0.12 then return end
	lastTrigger = now
	doClick()
end

-- audit 5.2: build actions go through ContextActionService while the hammer is in hand (keyboard + gamepad; bound on, unbound off).
-- Touch players use the on-screen bar (Turn / Up / Down / PLACE / Cancel) and the Delete slot - no duplicate CAS touch buttons.
local BUILD_ACTIONS = {
	{ "TL_BuildApply", applyWithTrigger, { Enum.KeyCode.ButtonR2 } },
	{ "TL_BuildTurn", function() rotate() end, { Enum.KeyCode.R, Enum.KeyCode.ButtonR1 } },
	{ "TL_BuildUp", function() lvl(1) end, { Enum.KeyCode.E, Enum.KeyCode.DPadUp } },
	{ "TL_BuildDown", function() lvl(-1) end, { Enum.KeyCode.Q, Enum.KeyCode.DPadDown } },
	{ "TL_BuildRemove", function() setMode(if mode == "remove" then "place" else "remove") end, { Enum.KeyCode.X, Enum.KeyCode.ButtonY } },
	{ "TL_BuildMove", function() setMode(if mode == "move" then "place" else "move") end, { Enum.KeyCode.M, Enum.KeyCode.ButtonX } },
	{ "TL_BuildCancel", function() cancelHand() end, { Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB } },
}
local casBound = false
bindBuildActions = function(on: boolean)
	if on == casBound then return end
	casBound = on
	for _, a in BUILD_ACTIONS do
		if on then
			local fn = a[2]
			ContextActionService:BindAction(a[1], function(_, state, input)
				local key = input.KeyCode
				if (key == Enum.KeyCode.DPadUp or key == Enum.KeyCode.DPadDown) and GuiService.SelectedObject then
					return Enum.ContextActionResult.Pass
				end
				if state == Enum.UserInputState.Begin then fn() end
				return Enum.ContextActionResult.Sink
			end, false, table.unpack(a[3]))
		else
			ContextActionService:UnbindAction(a[1])
		end
	end
end

function BuildController.Start()
	local gui = HUDController.Gui
	local aimGui = UIKit.new("ScreenGui", { Name = "TrapLabBuildAim", ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.None }, gui.Parent)
	ui.aim = UIKit.new("Frame", { Name = "Reticle", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, aimGui)
	UIKit.round(ui.aim, 5)
	UIKit.stroke(ui.aim, Color3.new(1, 1, 1), 2)
	local bar = UIKit.new("Frame", { Name = "BuildBar", AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, gui)
	UIKit.round(bar, 18); UIKit.stroke(bar, UIKit.INK, 4.5)
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(66, 70, 98), Color3.fromRGB(32, 34, 50)), Rotation = 90 }, bar)
	ui.bar = bar
	ui.status = UIKit.label(bar, { Name = "Status", Text = "", TextSize = 18, Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.yellow, stroke = 3 })
	ui.items = UIKit.new("ScrollingFrame", { BackgroundTransparency = 1, Visible = false, Size = UDim2.new(1, -20, 0, 108), Position = UDim2.fromOffset(10, 34), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 6, ScrollBarImageColor3 = C.muted, ScrollingDirection = Enum.ScrollingDirection.X, BorderSizePixel = 0 }, bar)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, ui.items)
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }, ui.items)
	local row = UIKit.new("Frame", { Name = "Actions", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6) }, bar)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	ui.toolButtons = {}
	local function btn(name, text, color, width, fn)
		local button = UIKit.button(row, { name = name, text = text, color = color, textSize = 18, onClick = fn })
		button:SetAttribute("BaseWidth", width)
		button.LayoutOrder = #ui.toolButtons + 1
		table.insert(ui.toolButtons, button)
		return button
	end
	-- session 8: one colour for the piece actions (blue), green = the commit (PLACE on touch); keys shown on PC; the actions appear only while
	-- a piece is in hand. Place = pick a slot, Remove = the Delete slot (no duplicate mode buttons).
	local keys = not hasTouch
	ui.tools = {}
	ui.tools.moveText = if keys then "Move a trap (M)" else "Move a trap"
	ui.tools.move = btn("Move", ui.tools.moveText, C.blue, if keys then 160 else 130, function() setMode(if mode == "move" then "place" else "move") end)
	ui.tools.rotate = btn("Turn", "Turn", C.blue, if keys then 104 else 80, rotate)
	ui.tools.up = btn("Up", "Up", C.blue, if keys then 86 else 60, function() lvl(1) end)
	ui.tools.down = btn("Down", "Down", C.blue, if keys then 104 else 76, function() lvl(-1) end)
	if hasTouch then ui.tools.place = btn("Place", "PLACE", C.green, 100, doClick) end
	-- audit 5.3: the way to put a piece away is on screen (PC shows the keys = the hint; touch gets the action itself)
	ui.tools.cancel = btn("Cancel", "Cancel", C.red, if keys then 136 else 90, cancelHand)

	-- hotbar: slot 1 = hammer (toggles build mode); the item slots and Delete appear while the hammer is in hand
	local hot = UIKit.new("Frame", { Name = "Hotbar", AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1 }, gui)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, SLOT_GAP), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom }, hot)
	ui.hot = hot
	local hb = newSlot(hot, 0, "1", false)
	hb.Name = "Hammer"; ui.hammer = hb
	UIKit.new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.hammer or Icons.build, Size = UDim2.new(1, -16, 1, -26), Position = UDim2.fromOffset(8, 6), ScaleType = Enum.ScaleType.Fit }, hb)
	UIKit.label(hb, { Text = "Hammer", TextSize = 13, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -18), stroke = 2.5 })
	hb.Activated:Connect(function() BuildController.SetActive(not active) end)
	local function layout()
		local viewport = workspace.CurrentCamera.ViewportSize
		local scale = UIKit.scaleFor()
		local touch = hasTouch and UserInputService.PreferredInput == Enum.PreferredInput.Touch
		local portrait = viewport.X <= viewport.Y
		local phone = math.min(viewport.X, viewport.Y) <= 500
		-- Keep the native jump button clear without shrinking the build actions.
		local sideRoom = if touch and not portrait then (if phone then 104 else 154) else 10
		local bottomRoom = if touch and portrait then math.ceil((if phone then 88 else 138) / scale) else 0
		local available = (viewport.X - 2 * sideRoom) / scale
		local width = math.min(560, available)
		tightTools = viewport.X < 520 or width < 560 or hasTouch
		toolWidth = width - 20
		toolHeight = if tightTools then math.max(36, math.ceil(46 / scale)) else 36
		slotSize = if tightTools then math.max(BASE_SLOT, math.ceil(46 / scale)) else BASE_SLOT
		pageSize = math.clamp(math.floor((available - 12 + SLOT_GAP) / (slotSize + SLOT_GAP)) - 3, 1, MAX_PAGE)
		local statusHeight = if tightTools then 42 else 26
		bar.Size = UDim2.fromOffset(width, math.max(92, statusHeight + toolHeight + 18))
		bar.Position = UDim2.new(0.5, 0, 1, -(slotSize + 30 + bottomRoom))
		row.Size = UDim2.new(1, -20, 0, toolHeight)
		ui.status.Size = UDim2.new(1, -24, 0, statusHeight)
		ui.status.TextWrapped = tightTools
		hot.Size = UDim2.fromOffset(0, slotSize + 12)
		hot.Position = UDim2.new(0.5, 0, 1, -(10 + bottomRoom))
		hb.Size = UDim2.fromOffset(slotSize, slotSize)
		refreshBar()
	end
	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		lastTouch = nil
		layout()
	end)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(layout)
	local lastGapKey = ""
	StateController.Changed.Event:Connect(function()
		if not active then return end
		refreshBar()
		local c = StateController.State and StateController.State.course
		local key = if c then (tostring(c.playerPlayable) .. "#" .. tostring(c.objectCount) .. "#" .. tostring(c.breaks and #c.breaks)
			.. (if c.breaks and c.breaks[1] then ("@" .. c.breaks[1].x .. "," .. c.breaks[1].z) else "")) else ""
		if key ~= lastGapKey or not gapFolder then lastGapKey = key; refreshGaps() end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if active then doClick() end
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			local k = input.KeyCode
			local num = KEYNUM[k]
			if num then
				if num == 1 then BuildController.SetActive(not active)
				elseif active and ui.slotIds and ui.slotIds[num] then if BuildController.Select(ui.slotIds[num]) then refreshBar() end end
			elseif k == Enum.KeyCode.B then BuildController.SetActive(not active)
			elseif not active then return
			elseif k == Enum.KeyCode.G then fine = not fine
			elseif k == Enum.KeyCode.Escape then cancelHand() end      -- R/E/Q/X/M/Backspace: ContextActionService (audit 5.2)
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(pos, processed)
		if not active or processed then return end
		lastTouch = pos
		if mode == "remove" or (mode == "move" and not moveUid) then doClick() end
	end)
	RunService.RenderStepped:Connect(onStep)
end

return BuildController
