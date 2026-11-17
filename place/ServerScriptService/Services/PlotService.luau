--!strict
-- Owns the physical plots: ground, build zone, start area, NPC pads, PLAY sign. Assigns plots to players.
-- BuildWorld() is idempotent and can also be run in Edit mode to bake the world for inspection.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Balance = require(ReplicatedStorage.Configs.Balance)
local Progression = require(ReplicatedStorage.Configs.Progression)
local SignKit = require(ReplicatedStorage.Shared.SignKit)
local DecorModels = require(ReplicatedStorage.Shared.DecorModels)
local Icons = require(ReplicatedStorage.Configs.Icons)

local PlotService = {}

export type Plot = {
	index: number, model: Model, cf: CFrame, owner: Player?, ownerId: number,
	course: Folder, decor: Folder, npcs: Folder, spawn: SpawnLocation, sign: Model,
}
local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}
PlotService.Assigned = Instance.new("BindableEvent")   -- (player, plot)
PlotService.Released = Instance.new("BindableEvent")   -- (player, plot)

local PALETTE = {
	ground = Color3.fromRGB(100, 190, 78), land = Color3.fromRGB(100, 190, 78), pit = SignKit.WATER,
	edge = SignKit.SAND, deck = SignKit.SAND, steel = SignKit.WOOD,
	accent = Color3.fromRGB(255, 196, 61), play = Color3.fromRGB(64, 214, 110),
}

-- `studs = true` in props: studded plastic (the bright brick-toy surface from docs/ART_DIRECTION.md)
local function mk(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			if k == "studs" then
				if v then p.Material = Enum.Material.Plastic; p.TopSurface = Enum.SurfaceType.Studs end
			else
				(p :: any)[k] = v
			end
		end
	end
	p.Parent = parent
	return p
end

local function plotCFrame(i: number): CFrame
	local cols = #Balance.PlotColumns
	local col = (i - 1) % cols + 1
	local x = Balance.PlotColumns[col]
	if i <= cols then return CFrame.new(x, 0, -Balance.PlotRowOffset) end
	return CFrame.new(x, 0, Balance.PlotRowOffset) * CFrame.Angles(0, math.pi, 0)
end

local function padLocal(i: number): Vector3   -- NPC pad i (1..NpcPads), local to the plot
	return Vector3.new(-27 + (i - 1) * 6, 2, -15)
end
PlotService.PadLocal = padLocal

local SIGN_BOARD = {   -- the sign board carries the plot's flag colour (same order as PLOT_COLORS)
	Color3.fromRGB(34, 190, 222), Color3.fromRGB(150, 84, 235), Color3.fromRGB(70, 190, 48), Color3.fromRGB(240, 128, 28),
	Color3.fromRGB(236, 170, 20), Color3.fromRGB(235, 64, 64), Color3.fromRGB(240, 76, 148), Color3.fromRGB(52, 128, 240),
}
local function buildSign(model: Model, cf: CFrame, index: number): Model
	local sign = Instance.new("Model"); sign.Name = "PlaySign"; sign.Parent = model
	-- Stands just outside the start edge, facing the lobby aisle (+Z local). Built for the GIANT lobby avatar (Balance.Avatar.Lobby).
	-- Owner reference 2 (session 5, TRAP_LAB/references_s5): ONE huge green PLAY button with an icon + a dark rating strip under it.
	-- Coloured plastic only (no wood, D-030/D-034): red posts, navy feet/cap, yellow frame, board in the plot's flag colour.
	local K = Balance.Avatar.Lobby
	local S = Vector3.new
	local z = 5 * K
	local BOT, TOP = 4.7, 13.1                 -- board bottom / top in K units
	local H = TOP - BOT
	local CY = (TOP + BOT) / 2
	local function y(frac: number): number return (TOP - H * frac) * K end   -- board fraction (0 = top) -> local height
	for _, sx in { -1, 1 } do
		mk(sign, "Foot", S(3.4, 0.9, 3.4) * K, cf * CFrame.new(sx * 7.6 * K, 0.45 * K, z), SignKit.WOOD_DARK, nil, { studs = true })
		mk(sign, "Post", S(1.5, 14, 1.5) * K, cf * CFrame.new(sx * 7.6 * K, 7.9 * K, z), SignKit.WOOD, Enum.Material.Plastic)
		mk(sign, "FrameSide", S(1.2, H + 1.8, 1.4) * K, cf * CFrame.new(sx * 6.6 * K, CY * K, z), SignKit.WOOD_LIGHT, nil, { studs = true })
	end
	local board = mk(sign, "Board", S(12, H, 0.8) * K, cf * CFrame.new(0, CY * K, z), SIGN_BOARD[index] or Color3.fromRGB(52, 128, 240))
	mk(sign, "FrameTop", S(14.4, 0.9, 1.4) * K, cf * CFrame.new(0, (TOP + 0.45) * K, z), SignKit.WOOD_LIGHT, nil, { studs = true })
	mk(sign, "FrameBottom", S(14.4, 0.9, 1.4) * K, cf * CFrame.new(0, (BOT - 0.45) * K, z), SignKit.WOOD_LIGHT, nil, { studs = true })
	mk(sign, "Cap", S(18.2, 1.0, 2.2) * K, cf * CFrame.new(0, (TOP + 1.4) * K, z), SignKit.WOOD_DARK, nil, { studs = true })

	-- the big PLAY button (a real 3D slab with a dark rim) = the ONLY interactive element of the sign (spec 10.1)
	local bTop, bBot = 0.28, 0.64
	local bh = H * (bBot - bTop)
	local bcy = (y(bTop) + y(bBot)) / 2
	mk(sign, "ButtonRim", S(10.6 * K, (bh + 0.4) * K, 1.0 * K), cf * CFrame.new(0, bcy, z + 0.05 * K), Color3.fromRGB(26, 116, 50), Enum.Material.SmoothPlastic)
	local button = mk(sign, "PlayButton", S(10 * K, bh * K, 1.2 * K), cf * CFrame.new(0, bcy, z + 0.12 * K), PALETTE.play, Enum.Material.SmoothPlastic)
	local bg = Instance.new("SurfaceGui"); bg.Name = "PlayFace"; bg.Face = Enum.NormalId.Back; bg.LightInfluence = 0
	bg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; bg.PixelsPerStud = 40 / K; bg.Parent = button
	local gloss = Instance.new("Frame"); gloss.Name = "Gloss"; gloss.BorderSizePixel = 0; gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.78; gloss.Size = UDim2.fromScale(0.96, 0.22); gloss.Position = UDim2.fromScale(0.02, 0.06); gloss.Parent = bg
	local gc = Instance.new("UICorner"); gc.CornerRadius = UDim.new(0.5, 0); gc.Parent = gloss
	local ic = Instance.new("ImageLabel"); ic.Name = "Icon"; ic.BackgroundTransparency = 1; ic.ScaleType = Enum.ScaleType.Fit
	ic.Image = Icons.playflag or ""; ic.Size = UDim2.fromScale(0.33, 1.5); ic.Position = UDim2.fromScale(0.0, -0.25); ic.Parent = bg
	SignKit.text(bg, { Name = "Label", Size = UDim2.fromScale(0.64, 0.8), Position = UDim2.fromScale(0.32, 0.1), Text = "PLAY", Font = SignKit.TITLE, strokeThickness = 5 })

	-- dark rating strip under the button (reference: "0 LIKES"; our courses have 5-star ratings)
	local rTop, rBot = 0.78, 0.95
	local rh = H * (rBot - rTop)
	local strip = mk(sign, "RatingBar", S(10 * K, rh * K, 1.0 * K), cf * CFrame.new(0, (y(rTop) + y(rBot)) / 2, z + 0.1 * K), Color3.fromRGB(30, 32, 46), Enum.Material.SmoothPlastic)
	local rg = Instance.new("SurfaceGui"); rg.Name = "RatingFace"; rg.Face = Enum.NormalId.Back; rg.LightInfluence = 0
	rg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; rg.PixelsPerStud = 40 / K; rg.Parent = strip
	local st = Instance.new("ImageLabel"); st.Name = "Star"; st.BackgroundTransparency = 1; st.ScaleType = Enum.ScaleType.Fit
	st.Image = Icons.popular or ""; st.Size = UDim2.fromScale(0.16, 1.6); st.Position = UDim2.fromScale(0.02, -0.3); st.Parent = rg
	SignKit.text(rg, { Name = "Rating", Size = UDim2.fromScale(0.8, 0.74), Position = UDim2.fromScale(0.18, 0.13), Text = "No ratings yet", Font = SignKit.TITLE, TextXAlignment = Enum.TextXAlignment.Left, strokeThickness = 3 })

	-- text on the board: course name, owner | stats, status line between the button and the strip
	local info = Instance.new("SurfaceGui"); info.Name = "InfoFace"; info.Face = Enum.NormalId.Back; info.LightInfluence = 0
	info.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; info.PixelsPerStud = 40 / K; info.Parent = board
	local function label(name: string, x: number, yy: number, w: number, h: number, text: string, color: Color3, thick: number, align: Enum.TextXAlignment?)
		SignKit.text(info, { Name = name, Position = UDim2.fromScale(x, yy), Size = UDim2.fromScale(w, h), Text = text, Font = SignKit.TITLE, TextColor3 = color, strokeThickness = thick, TextXAlignment = align or Enum.TextXAlignment.Center })
	end
	label("Title", 0.04, 0.02, 0.92, 0.16, "Free plot", Color3.new(1, 1, 1), 4)
	label("Owner", 0.05, 0.185, 0.46, 0.085, "", SignKit.CREAM, 2.5, Enum.TextXAlignment.Left)
	label("Stats", 0.5, 0.185, 0.45, 0.085, "", Color3.fromRGB(255, 232, 110), 2.5, Enum.TextXAlignment.Right)
	label("Status", 0.05, 0.672, 0.9, 0.09, "", Color3.new(1, 1, 1), 2.5)

	local pp = Instance.new("ProximityPrompt"); pp.Name = "PlayPrompt"; pp.ActionText = "PLAY"; pp.ObjectText = "Run this course"
	pp.KeyboardKeyCode = Enum.KeyCode.E; pp.HoldDuration = 0
	pp.RequiresLineOfSight = false; pp.MaxActivationDistance = 14 * K; pp.UIOffset = Vector2.new(0, 60); pp.Parent = button
	CollectionService:AddTag(pp, "TL_PlayPrompt")
	-- owner request (session 5): the sign is smaller and stands BESIDE the path, not on it
	do
		local SIGN_SCALE, SIGN_DX = 0.65, -30
		local c0, s0 = sign:GetBoundingBox()
		local bottom = c0.Position.Y - s0.Y / 2
		sign:ScaleTo(SIGN_SCALE)
		local c1, s1 = sign:GetBoundingBox()
		local want = c0.Position + cf:VectorToWorldSpace(Vector3.new(SIGN_DX, 0, 0))
		sign:TranslateBy(Vector3.new(want.X, bottom + s1.Y / 2, want.Z) - c1.Position)
		sign:SetAttribute("Shifted", true)
	end
	return sign
end
PlotService.BuildSign = buildSign       -- used to re-bake the signs in Edit

-- Owner reference 1 (T41): "Course saves" board, mirror of the PLAY sign on the other side of the path, same plastic family.
-- The 3 slot rows and their buttons are drawn ONLY by the owner's client (CourseSlotsController adorns a SurfaceGui to "Board");
-- everybody sees the yellow header plate.
local function buildSaveBoard(model: Model, cf: CFrame, index: number): Model
	local b = Instance.new("Model"); b.Name = "SaveBoard"; b.Parent = model
	local K = Balance.Avatar.Lobby
	local S = Vector3.new
	local z = 5 * K
	local BOT, TOP = 4.7, 13.1
	local H = TOP - BOT
	local CY = (TOP + BOT) / 2
	for _, sx in { -1, 1 } do
		mk(b, "Foot", S(3.4, 0.9, 3.4) * K, cf * CFrame.new(sx * 7.6 * K, 0.45 * K, z), SignKit.WOOD_DARK, nil, { studs = true })
		mk(b, "Post", S(1.5, 14, 1.5) * K, cf * CFrame.new(sx * 7.6 * K, 7.9 * K, z), SignKit.WOOD, Enum.Material.Plastic)
		mk(b, "FrameSide", S(1.2, H + 1.8, 1.4) * K, cf * CFrame.new(sx * 6.6 * K, CY * K, z), SignKit.WOOD_LIGHT, nil, { studs = true })
	end
	mk(b, "Board", S(12, H, 0.8) * K, cf * CFrame.new(0, CY * K, z), SIGN_BOARD[index] or Color3.fromRGB(52, 128, 240))
	mk(b, "FrameTop", S(14.4, 0.9, 1.4) * K, cf * CFrame.new(0, (TOP + 0.45) * K, z), SignKit.WOOD_LIGHT, nil, { studs = true })
	mk(b, "FrameBottom", S(14.4, 0.9, 1.4) * K, cf * CFrame.new(0, (BOT - 0.45) * K, z), SignKit.WOOD_LIGHT, nil, { studs = true })
	mk(b, "Cap", S(18.2, 1.0, 2.2) * K, cf * CFrame.new(0, (TOP + 1.4) * K, z), SignKit.WOOD_DARK, nil, { studs = true })
	local header = mk(b, "Header", S(10.4, 1.5, 1.0) * K, cf * CFrame.new(0, (TOP - 1.0) * K, z + 0.1 * K), Color3.fromRGB(255, 200, 44), Enum.Material.SmoothPlastic)
	local hg = Instance.new("SurfaceGui"); hg.Name = "HeaderFace"; hg.Face = Enum.NormalId.Back; hg.LightInfluence = 0
	hg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; hg.PixelsPerStud = 40 / K; hg.Parent = header
	SignKit.text(hg, { Name = "Title", Size = UDim2.fromScale(0.92, 0.8), Position = UDim2.fromScale(0.04, 0.1), Text = "COURSE SAVES", Font = SignKit.TITLE, strokeThickness = 4 })
	do   -- same size and offset as the PLAY sign, on the other side of the path
		local c0, s0 = b:GetBoundingBox()
		local bottom = c0.Position.Y - s0.Y / 2
		b:ScaleTo(0.65)
		local c1, s1 = b:GetBoundingBox()
		local want = c0.Position + cf:VectorToWorldSpace(Vector3.new(30, 0, 0))
		b:TranslateBy(Vector3.new(want.X, bottom + s1.Y / 2, want.Z) - c1.Position)
	end
	return b
end
PlotService.BuildSaveBoard = buildSaveBoard

local function prop(model: Model, base: CFrame, id: string, x: number, z: number, yaw: number, scale: number)   -- cosmetic dressing, never collides
	local m = DecorModels.build(id)
	if m then m:ScaleTo(scale); m:PivotTo(base * CFrame.new(x, 0.4, z) * CFrame.Angles(0, math.rad(yaw), 0)); m.Name = "Prop_" .. id; m.Parent = model end
end

local POOL_TILE = "rbxassetid://126806655453119"   -- seamless tiled water texture (TRAP_LAB/assets/make_water_tile.py)
local PLOT_COLORS = {
	Color3.fromRGB(34, 200, 232), Color3.fromRGB(172, 92, 255), Color3.fromRGB(86, 214, 56), Color3.fromRGB(255, 142, 32),
	Color3.fromRGB(255, 190, 24), Color3.fromRGB(255, 72, 72), Color3.fromRGB(255, 84, 160), Color3.fromRGB(58, 142, 255),
}
local INERT = { CanCollide = false, CanQuery = false, CanTouch = false }

-- wooden fence run (decoration only): posts every ~16 studs + two studded rails. axis "z": along local z at x = fixed (a -> b); "x": along x at z = fixed
local function fence(model: Model, cf: CFrame, axis: string, fixed: number, a: number, b: number)
	local f = Instance.new("Folder"); f.Name = "Fence"; f.Parent = model
	local len = math.abs(b - a)
	local mid = (a + b) / 2
	for _, y in { 2.6, 5.4 } do
		local size = if axis == "z" then Vector3.new(0.9, 1.2, len) else Vector3.new(len, 1.2, 0.9)
		local pos = if axis == "z" then Vector3.new(fixed, y, mid) else Vector3.new(mid, y, fixed)
		mk(f, "Rail", size, cf * CFrame.new(pos), SignKit.WOOD_LIGHT, nil, { studs = true, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	local n = math.max(1, math.floor(len / 16))
	for i = 0, n do
		local t = a + (b - a) * i / n
		local pos = if axis == "z" then Vector3.new(fixed, 3.5, t) else Vector3.new(t, 3.5, fixed)
		mk(f, "Post", Vector3.new(2, 7, 2), cf * CFrame.new(pos), SignKit.WOOD_DARK, nil, { studs = true, CanCollide = false, CanQuery = false, CanTouch = false })
	end
end

-- tall flag with the plot number, visible from the aisle and from afar (the PLAY sign's text is small at a distance)
local function totem(model: Model, cf: CFrame, x: number, z: number, index: number)
	local col = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local f = Instance.new("Model"); f.Name = "Totem"; f.Parent = model
	local dir = if x < 0 then 1 else -1       -- the flag points toward the plot centre
	mk(f, "Foot", Vector3.new(7, 2, 7), cf * CFrame.new(x, 1, z), SignKit.WOOD_DARK, nil, { studs = true, CanCollide = false, CanQuery = false, CanTouch = false })
	mk(f, "Pole", Vector3.new(2.4, 46, 2.4), cf * CFrame.new(x, 24, z), SignKit.WOOD, Enum.Material.Plastic, INERT)
	mk(f, "Knob", Vector3.new(4, 4, 4), cf * CFrame.new(x, 48.5, z), Color3.fromRGB(255, 206, 60), nil, { studs = true, CanCollide = false, CanQuery = false, CanTouch = false })
	local flag = mk(f, "Flag", Vector3.new(20, 22, 1.6), cf * CFrame.new(x + dir * 11.2, 36, z), col, nil, { studs = true, CanCollide = false, CanQuery = false, CanTouch = false })
	mk(f, "FlagTrim", Vector3.new(20.8, 2, 2), cf * CFrame.new(x + dir * 11.2, 46.5, z), col:Lerp(Color3.new(0, 0, 0), 0.35), nil, { studs = true, CanCollide = false, CanQuery = false, CanTouch = false })
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local sg = Instance.new("SurfaceGui"); sg.Face = face; sg.LightInfluence = 0; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 4.6; sg.Parent = flag
		SignKit.text(sg, { Size = UDim2.fromScale(1, 1), Text = tostring(index), Font = SignKit.TITLE, strokeThickness = 3 })
	end
end

local function buildPlot(i: number): Plot
	local cf = plotCFrame(i)
	local model = Instance.new("Model"); model.Name = "Plot_" .. i
	model:SetAttribute("Index", i); model:SetAttribute("OwnerId", 0)
	local cell = Balance.PlotCell
	-- origin anchor (clients read the plot frame from it)
	mk(model, "Origin", Vector3.new(1, 1, 1), cf, Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	-- land: a lawn; cell is 260 wide, extends from +90 behind the start edge to -(cell.Y - 90) in front
	local back, frontLen = 90, cell.Y - 90
	local land = mk(model, "Land", Vector3.new(cell.X, 1, cell.Y), cf * CFrame.new(0, -0.5, (back - frontLen) / 2), PALETTE.land, Enum.Material.Grass)
	CollectionService:AddTag(land, "TL_Ground")
	do local lt = Instance.new("Texture"); lt.Name = "LawnTiles"; lt.Texture = "rbxassetid://108532129961873"; lt.Face = Enum.NormalId.Top; lt.StudsPerTileU = 64; lt.StudsPerTileV = 64; lt.Parent = land end
	-- the build zone is a test pool: falling off the course = into the water
	-- phase B.5: the pool floor reads as water - translucent blue glass with a soft underwater glow
	local zone = mk(model, "BuildZone", Vector3.new(10, 0.2, 10), cf * CFrame.new(0, 0.1, -60), Color3.fromRGB(90, 180, 255), Enum.Material.Glass, { Transparency = 0.5 })
	do local wl = Instance.new("PointLight"); wl.Name = "PoolGlow"; wl.Color = Color3.fromRGB(120, 200, 255); wl.Range = 40; wl.Brightness = 0.6; wl.Parent = zone end
	local tex = Instance.new("Texture"); tex.Name = "PoolTiles"; tex.Texture = POOL_TILE; tex.Face = Enum.NormalId.Top; tex.StudsPerTileU = 16; tex.StudsPerTileV = 16; tex.Parent = zone
	-- audit 3.6: faint build grid at the build step (Balance.GridSize) over the pool tiles: shows where pieces can go
	local grid = Instance.new("Texture"); grid.Name = "BuildGrid"; grid.Texture = POOL_TILE; grid.Face = Enum.NormalId.Top
	grid.StudsPerTileU = Balance.GridSize; grid.StudsPerTileV = Balance.GridSize; grid.Transparency = 0.7; grid.Parent = zone
	for _, n in { "PoolRim_L", "PoolRim_R", "PoolRim_B" } do mk(model, n, Vector3.new(1, 0.1, 1), cf, Color3.fromRGB(24, 116, 190), Enum.Material.Marble, { CanCollide = false, CanQuery = false, CanTouch = false }) end
	for _, side in { "L", "R" } do      -- pool ladders: two chrome rails over the coping + two steps into the water (placed by Apply)
		local lad = Instance.new("Model"); lad.Name = "PoolLadder_" .. side; lad.Parent = model
		for _, dz in { -1.8, 1.8 } do mk(lad, "Rail", Vector3.new(0.6, 8, 0.6), cf, Color3.fromRGB(214, 222, 236), Enum.Material.Metal, { CanCollide = false, CanQuery = false, CanTouch = false }):SetAttribute("Dz", dz) end
		mk(lad, "Top", Vector3.new(0.6, 0.6, 4.2), cf, Color3.fromRGB(214, 222, 236), Enum.Material.Metal, { CanCollide = false, CanQuery = false, CanTouch = false })
		for k = 1, 2 do mk(lad, "Step" .. k, Vector3.new(2.4, 0.5, 3.6), cf, Color3.fromRGB(246, 246, 250), nil, { studs = true, CanCollide = false, CanQuery = false, CanTouch = false }) end
	end
	mk(model, "StartPlatform", Vector3.new(64, 2, Balance.StartAreaDepth), cf * CFrame.new(0, 1, -Balance.StartAreaDepth / 2), PALETTE.deck, nil, { studs = true })
	mk(model, "StartStripe", Vector3.new(64, 0.15, 2), cf * CFrame.new(0, 2.075, -Balance.StartAreaDepth + 1), PALETTE.accent, nil, { studs = true })
	local spawn = Instance.new("SpawnLocation"); spawn.Name = "Spawn"; spawn.Size = Vector3.new(8, 0.3, 8)
	spawn.CFrame = cf * CFrame.new(0, 2.15, -5); spawn.Anchored = true; spawn.Neutral = true; spawn.Duration = 0
	spawn.CanCollide = false; spawn.Transparency = 0.5; spawn.Color = PALETTE.play; spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth; spawn.Parent = model
	for k = 1, Balance.NpcPads do
		local pad = mk(model, "Pad_" .. k, Vector3.new(0.4, 4.4, 4.4), cf * CFrame.new(padLocal(k) + Vector3.new(0, 0.2, 0)), Color3.fromRGB(120, 130, 150), Enum.Material.Slate, { Shape = Enum.PartType.Cylinder })
		pad.CFrame = pad.CFrame * CFrame.Angles(0, 0, math.rad(90))
		pad:SetAttribute("PadIndex", k)
		local pg = Instance.new("SurfaceGui"); pg.Face = Enum.NormalId.Right; pg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; pg.PixelsPerStud = 30; pg.LightInfluence = 0; pg.Parent = pad
		SignKit.text(pg, { Name = "Num", Size = UDim2.fromScale(1, 1), Text = tostring(k), Font = SignKit.TITLE, strokeThickness = 3 })
		do local lock = Instance.new("ImageLabel"); lock.Name = "Lock"; lock.BackgroundTransparency = 1; lock.Image = Icons.lock or ""; lock.Size = UDim2.fromScale(0.7, 0.7); lock.Position = UDim2.fromScale(0.15, 0.15); lock.ScaleType = Enum.ScaleType.Fit; lock.Visible = false; lock.Parent = pg end
		CollectionService:AddTag(pad, "TL_NpcPad")
	end
	-- pool coping: studded sand-coloured curb (resized by Apply)
	for _, n in { "Border_L", "Border_R", "Border_B" } do mk(model, n, Vector3.new(1, 1, 1), cf, PALETTE.edge, nil, { CanCollide = false, studs = true }) end
	local sign = buildSign(model, cf, i)
	buildSaveBoard(model, cf, i)
	-- entrance: studded paving from the lobby aisle to the PLAY sign, a two-ring green "stand here" disc in front of it, bushes/lamps along the way
	local inert = { CanCollide = false, CanQuery = false, CanTouch = false }
	mk(model, "Path", Vector3.new(14, 0.3, 62), cf * CFrame.new(0, 0.15, 58), SignKit.SAND, nil, { studs = true, CanCollide = false, CanQuery = false, CanTouch = false })
	local ring = mk(model, "PlayRing", Vector3.new(0.12, 18, 18), cf * CFrame.new(0, 0.1, 19) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 150, 72), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false, CanTouch = false })
	local disc = mk(model, "PlayDisc", Vector3.new(0.12, 14.5, 14.5), cf * CFrame.new(0, 0.16, 19) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(104, 226, 138), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 0.1 })
	for _, sx in { -1, 1 } do
		prop(model, cf, "Bush", sx * 13, 40, 0, 2.4); prop(model, cf, "Bush", sx * 13.5, 62, 40, 2.2)
		prop(model, cf, "FlowerPatch", sx * 14, 50, 0, 2.6); prop(model, cf, "Lantern", sx * 10, 30, 0, 2.2); prop(model, cf, "Lantern", sx * 10, 80, 0, 2.2)
	end
	prop(model, cf, "Tree", -58, 70, 0, 2.6); prop(model, cf, "Tree", 60, 76, 90, 2.6)
	-- plot dressing (decoration only, never collides): fences on the cell border, brick pines along the sides, number flags at the entrance
	fence(model, cf, "z", -129, 88, -330); fence(model, cf, "z", 129, 88, -330); fence(model, cf, "x", -329, -129, 129)
	for _, sx in { -1, 1 } do
		for zi = 0, 6 do prop(model, cf, "PineTree", sx * 124, 56 - zi * 62, (zi * 53 + sx * 20) % 360, 1.35) end
		prop(model, cf, "Tree", sx * 98, 80, 30 * sx, 1.9)
		totem(model, cf, sx * 34, 84, i)
	end
	local function folder(n: string): Folder local f = Instance.new("Folder"); f.Name = n; f.Parent = model; return f end
	local course, decor, npcs = folder("Course"), folder("Decor"), folder("Npcs")
	model.Parent = workspace.PlayerPlots
	return { index = i, model = model, cf = cf, owner = nil, ownerId = 0, course = course, decor = decor, npcs = npcs, spawn = spawn, sign = sign }
end

-- Resize zone/borders for the given rebirth count (never touches placed objects)
function PlotService.Apply(plot: Plot, rebirth: number)
	local size = Progression.plotSize(rebirth)
	local W, L, D = size.X, size.Y, Balance.StartAreaDepth
	local m, cf = plot.model, plot.cf
	local zone = m.BuildZone :: Part
	zone.Size = Vector3.new(W, 0.2, L - D)
	zone.CFrame = cf * CFrame.new(0, 0.1, -(D + L) / 2)
	local sp = m.StartPlatform :: Part
	local pw = math.max(W, 64)
	sp.Size = Vector3.new(pw, 2, D); sp.CFrame = cf * CFrame.new(0, 1, -D / 2)
	;(m.StartStripe :: Part).Size = Vector3.new(pw, 0.15, 2)
	local t = 2.4
	local bl, br, bb = m.Border_L :: Part, m.Border_R :: Part, m.Border_B :: Part
	bl.Size = Vector3.new(t, 1.2, L - D); bl.CFrame = cf * CFrame.new(-W / 2 - t / 2, 0.6, -(D + L) / 2)
	br.Size = Vector3.new(t, 1.2, L - D); br.CFrame = cf * CFrame.new(W / 2 + t / 2, 0.6, -(D + L) / 2)
	bb.Size = Vector3.new(W + 2 * t, 1.2, t); bb.CFrame = cf * CFrame.new(0, 0.6, -L - t / 2)
	local rt = 3
	local rl, rr, rb = m.PoolRim_L :: Part, m.PoolRim_R :: Part, m.PoolRim_B :: Part
	rl.Size = Vector3.new(rt, 0.1, L - D); rl.CFrame = cf * CFrame.new(-W / 2 + rt / 2, 0.25, -(D + L) / 2)
	rr.Size = Vector3.new(rt, 0.1, L - D); rr.CFrame = cf * CFrame.new(W / 2 - rt / 2, 0.25, -(D + L) / 2)
	rb.Size = Vector3.new(W - 2 * rt, 0.1, rt); rb.CFrame = cf * CFrame.new(0, 0.25, -L + rt / 2)
	for _, side in { "L", "R" } do
		local lad = m:FindFirstChild("PoolLadder_" .. side)
		if lad then
			local sgn = if side == "L" then -1 else 1
			local zc = -(D + 18)
			for _, r in lad:GetChildren() do
				if r.Name == "Rail" then (r :: Part).CFrame = cf * CFrame.new(sgn * (W / 2 + 1.4), 4, zc + (r :: Part):GetAttribute("Dz"))
				elseif r.Name == "Top" then (r :: Part).CFrame = cf * CFrame.new(sgn * (W / 2 + 1.4), 8, zc)
				elseif r.Name == "Step1" then (r :: Part).CFrame = cf * CFrame.new(sgn * (W / 2 - 2.2), 0.45, zc)
				elseif r.Name == "Step2" then (r :: Part).CFrame = cf * CFrame.new(sgn * (W / 2 - 5.2), 0.45, zc) end
			end
		end
	end
	m:SetAttribute("Width", W); m:SetAttribute("Length", L); m:SetAttribute("Rebirth", rebirth)
	local limit = Progression.npcLimit(rebirth)
	for k = 1, Balance.NpcPads do
		local pad = m:FindFirstChild("Pad_" .. k) :: Part
		local unlocked = k <= limit
		pad.Color = if unlocked then Color3.fromRGB(70, 230, 110) else Color3.fromRGB(130, 136, 150)   -- phase B.6: open pads = neon green, locked = grey
		pad.Material = if unlocked then Enum.Material.Neon else Enum.Material.Metal
		pad:SetAttribute("Unlocked", unlocked)
		local pg = pad:FindFirstChildOfClass("SurfaceGui")
		if pg then
			local num = pg:FindFirstChildWhichIsA("TextLabel")
			local lock = pg:FindFirstChildWhichIsA("ImageLabel")
			if num then num.Visible = unlocked end
			if lock then lock.Visible = not unlocked end
		end
	end
end

function PlotService.SetSignInfo(plot: Plot, title: string, owner: string, stats: string, status: string)
	local face = (plot.sign :: any).Board.InfoFace
	face.Title.Text = title; face.Owner.Text = owner; face.Stats.Text = stats; face.Status.Text = status
	if title == "Free plot" then PlotService.SetSignRating(plot, 0, 0) end
end

-- the dark strip under the PLAY button: shown course rating (Bayesian mean, RatingService) and number of votes
function PlotService.SetSignRating(plot: Plot, avg: number, n: number)
	local bar = (plot.sign :: any):FindFirstChild("RatingBar")
	local face = bar and bar:FindFirstChild("RatingFace")
	local t = face and face:FindFirstChild("Rating")
	if not t then return end
	(t :: any).Text = if n > 0 then string.format("%.1f  -  %d %s", avg, n, if n == 1 then "vote" else "votes") else "No ratings yet"
end

-- brick cliff ring at the edge of the world: a checker of two browns (2 rows), a studded grass cap and pines on top; solid, so nobody walks off the map
function PlotService.BuildCliffs(wa: Instance)
	local old = wa:FindFirstChild("Cliffs"); if old then old:Destroy() end
	local f = Instance.new("Folder"); f.Name = "Cliffs"; f.Parent = wa
	local browns = { Color3.fromRGB(160, 110, 76), Color3.fromRGB(134, 90, 62) }
	local ROW, THICK = 34, 30
	local WALL_TILE = "rbxassetid://93686982618788"   -- TRAP_LAB/assets/make_wall_tile.py
	local function wall(name: string, cx: number, cz: number, alongX: boolean, length: number, inner: Enum.NormalId)
		local segs = math.ceil(length / 100)
		local seg = length / segs
		for row = 1, 2 do
			for k = 1, segs do
				local t = -length / 2 + seg * (k - 0.5)
				local size = if alongX then Vector3.new(seg, ROW, THICK) else Vector3.new(THICK, ROW, seg)
				local pos = if alongX then Vector3.new(cx + t, ROW * (row - 0.5), cz) else Vector3.new(cx, ROW * (row - 0.5), cz + t)
				local seg_ = mk(f, name .. "_" .. row .. "_" .. k, size, CFrame.new(pos), browns[(k + row) % 2 + 1], Enum.Material.SmoothPlastic)
				local tx = Instance.new("Texture"); tx.Texture = WALL_TILE; tx.Face = inner; tx.StudsPerTileU = 8; tx.StudsPerTileV = 8; tx.Parent = seg_
			end
		end
		local capSize = if alongX then Vector3.new(length, 8, THICK + 8) else Vector3.new(THICK + 8, 8, length)
		mk(f, name .. "_Cap", capSize, CFrame.new(cx, ROW * 2 + 4, cz), Color3.fromRGB(92, 196, 76), nil, { studs = true })
		local rng = Random.new(#name * 7)
		local n = math.floor(length / 120)
		for k = 1, n do
			local t = -length / 2 + length * (k - 0.5) / n + rng:NextNumber(-25, 25)
			local m = DecorModels.build(if k % 3 == 0 then "Tree" else "PineTree")
			if m then
				m:ScaleTo(rng:NextNumber(2.4, 3.2))
				local p = if alongX then Vector3.new(cx + t, ROW * 2 + 8, cz) else Vector3.new(cx, ROW * 2 + 8, cz + t)
				m:PivotTo(CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)); m.Name = "CliffTree"; m.Parent = f
			end
		end
	end
	wall("N", 0, 735, true, 1700, Enum.NormalId.Front); wall("S", 0, -735, true, 1700, Enum.NormalId.Back)
	wall("E", 835, 0, false, 1470, Enum.NormalId.Left); wall("W", -835, 0, false, 1470, Enum.NormalId.Right)
end

function PlotService.BuildWorld(force: boolean?)
	local root = workspace.PlayerPlots
	if force then root:ClearAllChildren() end
	if #root:GetChildren() == 0 then
		local wa = workspace.WorldAssets
		for _, n in { "Ground", "LobbyFloor", "LobbyCurbN", "LobbyCurbS", "Cliffs" } do local o = wa:FindFirstChild(n); if o then o:Destroy() end end
		local g = mk(wa, "Ground", Vector3.new(1700, 2, 1500), CFrame.new(0, -1.5, 0), PALETTE.ground, Enum.Material.Grass)
		CollectionService:AddTag(g, "TL_Ground")
		do local gt = Instance.new("Texture"); gt.Name = "LawnTiles"; gt.Texture = "rbxassetid://108532129961873"; gt.Face = Enum.NormalId.Top; gt.StudsPerTileU = 64; gt.StudsPerTileV = 64; gt.Parent = g end
		mk(wa, "LobbyFloor", Vector3.new(1300, 1, 40), CFrame.new(0, -0.5, 0), SignKit.SAND_DARK, nil, { studs = true })
		mk(wa, "LobbyCurbN", Vector3.new(1300, 0.8, 2.4), CFrame.new(0, 0.4, 21.2), SignKit.WOOD_DARK, nil, { studs = true })
		mk(wa, "LobbyCurbS", Vector3.new(1300, 0.8, 2.4), CFrame.new(0, 0.4, -21.2), SignKit.WOOD_DARK, nil, { studs = true })
		for i = 1, Balance.PlotCount do buildPlot(i) end
		PlotService.BuildCliffs(wa)
	end
	plots = {}
	for i = 1, Balance.PlotCount do
		local m = root:FindFirstChild("Plot_" .. i) :: Model
		plots[i] = { index = i, model = m, cf = (m.Origin :: Part).CFrame, owner = nil, ownerId = 0, course = m.Course, decor = m.Decor, npcs = m.Npcs, spawn = m.Spawn, sign = m.PlaySign }
		PlotService.Apply(plots[i], 0)
		PlotService.SetSignInfo(plots[i], "Free plot", "", "", "")
	end
end

function PlotService.Assign(player: Player, rebirth: number): Plot?
	if byPlayer[player] then return byPlayer[player] end
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player; plot.ownerId = player.UserId
			plot.model:SetAttribute("OwnerId", player.UserId)
			plot.model:SetAttribute("OwnerName", player.DisplayName)
			byPlayer[player] = plot
			PlotService.Apply(plot, rebirth)
			player.RespawnLocation = plot.spawn
			PlotService.Assigned:Fire(player, plot)
			return plot
		end
	end
	return nil
end

function PlotService.Release(player: Player)
	local plot = byPlayer[player]
	if not plot then return end
	byPlayer[player] = nil
	PlotService.Released:Fire(player, plot)
	plot.owner = nil; plot.ownerId = 0
	plot.model:SetAttribute("OwnerId", 0)
	plot.model:SetAttribute("OwnerName", nil)
	PlotService.SetSignInfo(plot, "Free plot", "", "", "")
	plot.course:ClearAllChildren(); plot.decor:ClearAllChildren(); plot.npcs:ClearAllChildren()
end

function PlotService.Get(player: Player): Plot? return byPlayer[player] end
function PlotService.GetByOwnerId(id: number): Plot?
	for _, p in plots do if p.ownerId == id then return p end end
	return nil
end
function PlotService.GetByModel(m: Instance?): Plot?
	for _, p in plots do if p.model == m then return p end end
	return nil
end
function PlotService.All(): { Plot } return plots end

return PlotService
