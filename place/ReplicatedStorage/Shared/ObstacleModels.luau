--!strict
-- Procedural, original obstacle models (DECISIONS D-002). Origin = base centre, forward = -Z, base at y=0.
-- Builders are shared: the server builds real obstacles, the client builds ghosts from the same code.
local Obstacles = require(script.Parent.Parent.Configs.Obstacles)
local Rarities = require(script.Parent.Parent.Configs.Rarities)

local V, CF = Vector3.new, CFrame.new
local function rgb(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

local C = {
	deck = rgb(240, 226, 190), steel = rgb(176, 184, 204), dark = rgb(40, 44, 64), teal = rgb(40, 196, 214), wood2 = rgb(46, 58, 110),   -- steel: cool light grey (was brownish 112,98,98 = read as old wood)
	yellow = rgb(255, 190, 48), orange = rgb(255, 128, 48), red = rgb(240, 84, 76), green = rgb(80, 206, 96),
	purple = rgb(160, 120, 255), wood = rgb(176, 124, 78), lava = rgb(255, 96, 24),
}

-- Neon is reserved for hazards and goals (lava, flames, lasers, spike tips, void, goal, bounce, teleport pads); decorative trims are flat paint.
local GLOW = { Lava = true, Glow = true, Beam = true, Tip = true, Void = true, Goal = true, Bounce = true, Pad = true, Dest = true, Pilot = true, StoneGlow = true, Cap = true }
local function isGlow(name: string): boolean
	return GLOW[name] == true or name:sub(1, 5) == "Flame"
end
local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): Part
	if mat == Enum.Material.Neon and not isGlow(name) then mat = Enum.Material.SmoothPlastic end
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if props then for k, v in props do (p :: any)[k] = v end end
	p.Parent = model
	return p
end

local function deckSlab(m: Model, name: string, w: number, d: number, cx: number, cz: number, accent: Color3)
	part(m, name .. "Base", V(w, 1.2, d), CF(cx, 0.6, cz), C.wood2, Enum.Material.Plastic)
	part(m, name, V(w, 0.8, d), CF(cx, 1.6, cz), C.deck, Enum.Material.Plastic, { TopSurface = Enum.SurfaceType.Studs, CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.2, 0.5, 1, 1) })
	local t = 0.8
	part(m, name .. "TrimL", V(t, 0.3, d), CF(cx - w / 2 + t / 2, 2.15, cz), accent, Enum.Material.SmoothPlastic, { CanCollide = false })
	part(m, name .. "TrimR", V(t, 0.3, d), CF(cx + w / 2 - t / 2, 2.15, cz), accent, Enum.Material.SmoothPlastic, { CanCollide = false })
end

local B: { [string]: (Model, any) -> () } = {}

local CATEGORY_DECK: { [string]: Color3 } = {
	Basic = rgb(255, 206, 60), Moving = rgb(255, 146, 52), Special = rgb(255, 104, 176), Premium = rgb(156, 98, 255),
	Traps = rgb(70, 74, 98), Dangerous = rgb(70, 74, 98),
}

B.BasicPlatform = function(m)
	deckSlab(m, "Deck", 12, 12, 0, 0, C.teal)
	for _, s in { -1, 1 } do part(m, "Foot", V(1.6, 0.4, 1.6), CF(s * 4.6, 0.2, 4.6), C.dark) end
end

B.SmallJumpPlatform = function(m)
	part(m, "PadBase", V(1.2, 6, 6), CF(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), C.steel, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	part(m, "Pad", V(0.8, 5.6, 5.6), CF(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), C.yellow, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	part(m, "Ring", V(0.1, 3.6, 3.6), CF(0, 2.02, 0) * CFrame.Angles(0, 0, math.rad(90)), C.orange, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
end

B.NarrowBridge = function(m)
	for i = 0, 11 do
		local z = -11 + i * 2
		-- owner rule: NO WOOD -> coloured studded plastic slats (yellow / orange, the Basic family colours); sizes unchanged
		part(m, "Plank", V(4, 0.5, 1.8), CF(0, 1.75, z), if i % 2 == 0 then rgb(255, 206, 60) else rgb(255, 150, 50), Enum.Material.Plastic, { TopSurface = Enum.SurfaceType.Studs })
	end
	for _, s in { -1, 1 } do
		part(m, "Rope", V(0.25, 0.25, 24), CF(s * 1.9, 1.45, 0), rgb(46, 58, 110), Enum.Material.Plastic, { CanCollide = false })   -- navy rail (was brown rope)
	end
	for _, z in { -11.8, 0, 11.8 } do
		for _, s in { -1, 1 } do part(m, "Post", V(0.5, 1.6, 0.5), CF(s * 1.9, 1.0, z), rgb(206, 58, 50), Enum.Material.Plastic, { CanCollide = false }) end
	end
end

B.RampUp = function(m)
	deckSlab(m, "Base", 8, 12, 0, 0, C.teal)
	local w = Instance.new("WedgePart"); w.Name = "Slope"; w.Size = V(8, 4, 12)
	-- default wedge: slope rises toward -Z? orient so the high edge is at -Z (exit)
	w.CFrame = CF(0, 4, 0) * CFrame.Angles(0, math.rad(180), 0)
	w.Color = C.deck; w.Material = Enum.Material.SmoothPlastic; w.Anchored = true; w.TopSurface = Enum.SurfaceType.Smooth; w.Parent = m
	-- S12 art pass (chief recipe): a studded deck plate laid ON the slope + rarity trims, all decorative (no collision/query/touch);
	-- the wedge underneath keeps the physics untouched. Slope = atan(4/12) ~ 18.4 deg, its plane passes through the wedge centre.
	local slopeCF = CF(0, 4, 0) * CFrame.Angles(math.atan2(4, 12), 0, 0)
	local len = math.sqrt(12 * 12 + 4 * 4)
	part(m, "SlopeDeck", V(8, 0.2, len), slopeCF * CF(0, 0.13, 0), C.deck, Enum.Material.Plastic, { CanCollide = false, CanQuery = false, CanTouch = false, TopSurface = Enum.SurfaceType.Studs })
	for _, s in { -1, 1 } do part(m, "SlopeTrim", V(0.8, 0.3, len), slopeCF * CF(s * 3.6, 0.38, 0), C.teal, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false, CanTouch = false }) end
end

B.MovingPlatform = function(m)
	for _, z in { 14.5, -14.5 } do
		part(m, "EndPadBase", V(10, 1.2, 5), CF(0, 0.6, z), C.wood2, Enum.Material.Plastic)
		-- S12 art pass: same studded plastic + rarity side trims as every other deck (was flat SmoothPlastic); friction kept at SmoothPlastic 0.2
		part(m, "EndPad", V(10, 0.8, 5), CF(0, 1.6, z), C.deck, Enum.Material.Plastic, { TopSurface = Enum.SurfaceType.Studs, CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.2, 0.5, 1, 1) })
		for _, s in { -1, 1 } do part(m, "EndPadTrim", V(0.8, 0.3, 5), CF(s * 4.6, 2.15, z), C.teal, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false, CanTouch = false }) end
		part(m, "EndStripe", V(10, 0.1, 0.6), CF(0, 2.02, if z > 0 then 12.6 else -12.6), C.yellow, Enum.Material.Neon, { CanCollide = false })
	end
	for _, s in { -1, 1 } do
		part(m, "Rail", V(0.7, 0.7, 24), CF(s * 4.4, 0.35, 0), C.dark, Enum.Material.Metal, { CanCollide = false })
		part(m, "RailLight", V(0.2, 0.2, 24), CF(s * 4.4, 0.75, 0), C.orange, Enum.Material.Neon, { CanCollide = false })
	end
	local fm = Instance.new("Model"); fm.Name = "FerryModel"; fm.Parent = m
	local ferry = part(fm, "Ferry", V(8, 1.9, 8), CF(0, 1.05, 8), C.orange, Enum.Material.SmoothPlastic)
	part(fm, "FerryTop", V(7.2, 0.15, 7.2), CF(0, 2.0, 8), C.deck, Enum.Material.Plastic, { CanCollide = false, TopSurface = Enum.SurfaceType.Studs })   -- S12: studded like the decks
	fm.PrimaryPart = ferry
end

B.RotatingBar = function(m)
	deckSlab(m, "Deck", 16, 16, 0, 0, C.yellow)
	part(m, "Hub", V(2.6, 2.8, 2.8), CF(0, 3.3, 0) * CFrame.Angles(0, 0, math.rad(90)), C.dark, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	local bar = Instance.new("Model"); bar.Name = "BarModel"; bar.Parent = m
	local b = part(bar, "Bar", V(14.4, 1.0, 1.2), CF(0, 3.1, 0), C.yellow)
	for _, x in { -5.4, -1.8, 1.8, 5.4 } do
		part(bar, "Stripe", V(1.6, 1.02, 1.22), CF(x, 3.1, 0), C.dark, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	for _, s in { -1, 1 } do part(bar, "Cap", V(1.2, 1.4, 1.4), CF(s * 7.2, 3.1, 0), C.red, Enum.Material.Neon, { CanCollide = false }) end
	bar.PrimaryPart = b
	b:SetAttribute("Knock", true)
end

B.LavaFloor = function(m)
	deckSlab(m, "RimBack", 14, 4, 0, 10, C.red)
	deckSlab(m, "RimFront", 14, 4, 0, -10, C.red)
	part(m, "Basin", V(14.6, 1, 16.6), CF(0, 0.5, 0), C.dark, Enum.Material.Metal)
	local lava = part(m, "Lava", V(14, 0.6, 16), CF(0, 0.9, 0), C.lava, Enum.Material.Neon, { CanCollide = false })
	lava:SetAttribute("Kill", true)
	local l = Instance.new("PointLight"); l.Color = C.lava; l.Range = 16; l.Brightness = 1.5; l.Parent = lava
	for i, z in { 5.5, 0.5, -4.5 } do
		part(m, "Stone" .. i, V(2, 4.2, 4.2), CF(0, 1, z) * CFrame.Angles(0, 0, math.rad(90)), C.deck, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
		part(m, "StoneGlow" .. i, V(0.1, 4.4, 4.4), CF(0, 0.5, z) * CFrame.Angles(0, 0, math.rad(90)), C.orange, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	end
end

B.FallingPlatform = function(root)
	local m = Instance.new("Model"); m.Name = "TileModel"; m.Parent = root
	local t = part(m, "Tile", V(8, 2, 8), CF(0, 1, 0), rgb(186, 214, 240), Enum.Material.Plastic, { TopSurface = Enum.SurfaceType.Studs })   -- pale 'fragile' tile with dark cracks (was brown slate)
	m.PrimaryPart = t
	t:SetAttribute("Falling", true)
	for i, off in { -2.4, 0, 2.4 } do
		part(m, "Crack" .. i, V(0.25, 0.06, 5.5), CF(off, 2.02, 0) * CFrame.Angles(0, math.rad(20 * (i - 2)), 0), C.dark, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
		part(m, "Bolt", V(0.7, 0.2, 0.7), CF(sx * 3.2, 2.05, sz * 3.2), C.steel, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	end end
end

B.SpeedPlatform = function(m)
	part(m, "DeckBase", V(8, 1.2, 16), CF(0, 0.6, 0), C.wood2, Enum.Material.Plastic)
	-- S12 art series: studded track + role trims like every other deck (was flat SmoothPlastic); friction kept at SmoothPlastic 0.2
	local d = part(m, "Deck", V(8, 0.8, 16), CF(0, 1.6, 0), rgb(66, 48, 44), Enum.Material.Plastic, { TopSurface = Enum.SurfaceType.Studs, CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.2, 0.5, 1, 1) })
	for _, s in { -1, 1 } do part(m, "DeckTrim", V(0.8, 0.3, 16), CF(s * 3.6, 2.15, 0), C.teal, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false, CanTouch = false }) end
	d:SetAttribute("Speed", true)
	for i = 0, 3 do
		local z = 5.4 - i * 3.4
		for _, s in { -1, 1 } do
			part(m, "Chevron", V(0.55, 0.06, 3.4), CF(s * 1.15, 2.03, z) * CFrame.Angles(0, math.rad(-s * 40), 0), C.teal, Enum.Material.Neon, { CanCollide = false })
		end
	end
end

B.TeleportPlatform = function(m)
	deckSlab(m, "PadBack", 8, 6, 0, 14, C.purple)
	deckSlab(m, "PadFront", 8, 6, 0, -14, C.purple)
	local void = part(m, "Void", V(8, 0.4, 22), CF(0, 0.3, 0), rgb(120, 40, 200), Enum.Material.Neon, { CanCollide = false })
	void:SetAttribute("Kill", true)
	local pad = part(m, "Pad", V(0.2, 5, 5), CF(0, 2.1, 14) * CFrame.Angles(0, 0, math.rad(90)), C.purple, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	pad:SetAttribute("Teleport", true)
	part(m, "Dest", V(0.2, 5, 5), CF(0, 2.1, -14) * CFrame.Angles(0, 0, math.rad(90)), C.green, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanTouch = false })
end

B.FinishPad = function(m)
	part(m, "Base", V(14, 1.2, 14), CF(0, 0.6, 0), C.wood2, Enum.Material.Plastic)
	for ix = 0, 3 do for iz = 0, 3 do
		part(m, "Tile", V(3.5, 0.8, 3.5), CF(-5.25 + ix * 3.5, 1.6, -5.25 + iz * 3.5), if (ix + iz) % 2 == 0 then rgb(250, 250, 250) else rgb(26, 28, 38), Enum.Material.Plastic, { TopSurface = Enum.SurfaceType.Studs })
	end end
	local goal = part(m, "Goal", V(10, 0.3, 10), CF(0, 2.15, 0), C.green, Enum.Material.Neon, { CanCollide = false, Transparency = 0.55 })
	goal:SetAttribute("Goal", true)
	-- a real landmark (session 6): fat red posts with yellow caps, a big banner - the finish must read from the start of the course
	for _, s in { -1, 1 } do
		part(m, "Post", V(1.6, 11, 1.6), CF(s * 6.4, 7.5, 0), rgb(206, 58, 50), Enum.Material.Plastic, { CanCollide = false })
		part(m, "PostFoot", V(2.6, 1, 2.6), CF(s * 6.4, 2.5, 0), C.wood2, Enum.Material.Plastic, { CanCollide = false })
		part(m, "PostCap", V(2.2, 1, 2.2), CF(s * 6.4, 13.3, 0), C.yellow, Enum.Material.Plastic, { CanCollide = false })
	end
	local banner = part(m, "Banner", V(14.6, 3.4, 1.2), CF(0, 11.4, 0), C.wood2, Enum.Material.SmoothPlastic, { CanCollide = false })
	for i = 0, 13 do      -- checkered strip under the banner
		part(m, "Check", V(1.04, 0.6, 1.25), CF(-6.76 + i * 1.04, 9.4, 0), if i % 2 == 0 then rgb(250, 250, 250) else rgb(26, 28, 38), Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = Instance.new("SurfaceGui"); g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 40; g.Parent = banner
		local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = "FINISH"
		t.Font = Enum.Font.FredokaOne; t.TextScaled = true; t.TextColor3 = Color3.new(1, 1, 1); t.Parent = g
		local st = Instance.new("UIStroke"); st.Color = rgb(14, 10, 18); st.Thickness = 6; st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; st.Parent = t
	end
end

-- ===== second wave: the rest of the starter list + premium variants ============================================
local function sub(m: Model, name: string): Model
	local s = Instance.new("Model"); s.Name = name; s.Parent = m
	return s
end
local STUDS = { TopSurface = Enum.SurfaceType.Studs, BottomSurface = Enum.SurfaceType.Studs, FrontSurface = Enum.SurfaceType.Studs, BackSurface = Enum.SurfaceType.Studs, LeftSurface = Enum.SurfaceType.Studs, RightSurface = Enum.SurfaceType.Studs }
local POST_RED, BEAM_NAVY = rgb(206, 58, 50), rgb(46, 58, 110)   -- world palette (no wood): red posts, navy beams, studded plastic
local function postPair(m: Model, x: number, z: number, h: number, color: Color3)
	for _, s in { -1, 1 } do part(m, "Post", V(1.2, h, 1.2), CF(s * x, 2 + h / 2, z), color, Enum.Material.Plastic, STUDS) end   -- size kept (solid: NPC-tested)
end
local function hammer(m: Model, name: string, z: number, armLen: number, headSize: number, color: Color3)
	local hm = sub(m, name)
	local pv = part(hm, "Pivot", V(0.6, 0.6, 0.6), CF(0, 13.5, z), C.dark, Enum.Material.Metal, { CanCollide = false })
	part(hm, "Arm", V(0.9, armLen, 0.9), CF(0, 13.5 - armLen / 2, z), C.steel, Enum.Material.Metal, { CanCollide = false })
	local head = part(hm, "Head", V(headSize, headSize, headSize), CF(0, 13.5 - armLen - headSize / 2 + 0.4, z), color, Enum.Material.Metal)
	part(hm, "HeadBand", V(headSize + 0.2, 0.5, headSize + 0.2), CF(0, 13.5 - armLen - headSize / 2 + 0.4, z), C.yellow, Enum.Material.Neon, { CanCollide = false })
	hm.PrimaryPart = pv
	head:SetAttribute("Knock", true)
end
local function beam(m: Model, name: string, y: number, width: number, z: number, color: Color3)
	local bm = sub(m, name)
	local b = part(bm, "Beam", V(width, 0.3, 0.3), CF(0, y, z), color, Enum.Material.Neon, { CanCollide = false })
	part(bm, "Glow", V(width, 0.7, 0.7), CF(0, y, z), color, Enum.Material.Neon, { CanCollide = false, Transparency = 0.7 })
	bm.PrimaryPart = b
	b:SetAttribute("Kill", true)
end

B.RotatingPlatform = function(m)
	deckSlab(m, "PadA", 10, 5, 0, 9.5, C.teal)
	deckSlab(m, "PadB", 10, 5, 0, -9.5, C.teal)
	part(m, "Post", V(2.4, 0.8, 2.4), CF(0, 0.4, 0), C.steel, Enum.Material.Metal)
	local dm = sub(m, "DiscModel")
	local disc = part(dm, "Disc", V(1.2, 14, 14), CF(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), C.deck, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	for i = 0, 2 do
		part(dm, "Spoke" .. i, V(13, 0.08, 1.0), CF(0, 2.03, 0) * CFrame.Angles(0, i * math.rad(60), 0), if i == 0 then C.orange else C.teal, Enum.Material.Neon, { CanCollide = false })
	end
	part(dm, "Rim", V(0.3, 14.3, 14.3), CF(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), C.teal, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.5 })
	dm.PrimaryPart = disc
end

B.SlidingBlock = function(m)
	deckSlab(m, "Deck", 16, 16, 0, 0, C.yellow)
	for _, s in { -1, 1 } do part(m, "Rail", V(0.6, 0.6, 16), CF(s * 8.3, 2.3, 0), C.dark, Enum.Material.Metal, { CanCollide = false }) end
	local bm = sub(m, "Block0")
	local b = part(bm, "Block", V(5, 5, 5), CF(0, 4.5, 0), rgb(58, 86, 168), Enum.Material.Plastic, STUDS)   -- blue crusher on the orange deck (was orange on orange)
	part(bm, "Stripe", V(5.1, 0.8, 5.1), CF(0, 4.5, 0), C.yellow, Enum.Material.SmoothPlastic, { CanCollide = false })
	bm.PrimaryPart = b
	b:SetAttribute("Knock", true)
end

B.MovingWall = function(m)
	deckSlab(m, "Deck", 16, 26, 0, 0, C.red)
	for i, z in { 5, -5 } do
		local wm = sub(m, "Wall" .. (i - 1))
		local w = part(wm, "Wall", V(9, 9, 1.6), CF(0, 6.5, z), rgb(244, 244, 248), Enum.Material.Plastic, STUDS)
		part(wm, "Warn", V(9.1, 1.2, 1.7), CF(0, 9.5, z), C.yellow, Enum.Material.Neon, { CanCollide = false })
		part(wm, "Warn2", V(9.1, 1.2, 1.7), CF(0, 4.0, z), C.yellow, Enum.Material.Neon, { CanCollide = false })
		wm.PrimaryPart = w
		w:SetAttribute("Knock", true)
	end
end

B.SwingingHammer = function(m)
	deckSlab(m, "Deck", 14, 18, 0, 0, C.red)
	postPair(m, 6.6, 0, 11.5, POST_RED)
	part(m, "Beam", V(14.6, 1.4, 1.6), CF(0, 14.1, 0), BEAM_NAVY, Enum.Material.Plastic, STUDS)
	hammer(m, "Hammer0", 0, 10, 4.2, C.red)
end

B.MovingLaser = function(m)
	deckSlab(m, "Deck", 14, 24, 0, 0, C.red)
	for _, z in { -12.2, 12.2 } do
		for _, s in { -1, 1 } do part(m, "Emitter", V(1.4, 3, 1.4), CF(s * 7.6, 3.5, z), POST_RED, Enum.Material.Plastic, STUDS) end
	end
	for _, s in { -1, 1 } do part(m, "Track", V(0.5, 0.3, 24), CF(s * 7.6, 2.2, 0), C.red, Enum.Material.Neon, { CanCollide = false }) end
	beam(m, "Beam0", 2.9, 14.4, 0, C.red)
end

B.SpikePlatform = function(m)
	deckSlab(m, "Deck", 12, 20, 0, 0, C.orange)
	part(m, "Plate", V(11, 0.15, 16), CF(0, 2.04, 0), C.dark, Enum.Material.Metal, { CanCollide = false })
	local sm = sub(m, "Spikes")
	local root = part(sm, "Root", V(0.5, 0.5, 0.5), CF(0, 2, 0), C.dark, nil, { Transparency = 1, CanCollide = false })
	for ix = 0, 4 do for iz = 0, 6 do
		-- chunky steel spike (wide foot, narrower body, red hot tip): reads as DANGER, not as matchsticks (session 6 review)
		part(sm, "SpikeFoot", V(1.4, 0.6, 1.4), CF(-4 + ix * 2, 2 + 0.3, -6 + iz * 2) * CFrame.Angles(0, math.rad(45), 0), rgb(150, 156, 172), Enum.Material.Metal, { CanCollide = false })
		part(sm, "Spike", V(1.0, 2.4, 1.0), CF(-4 + ix * 2, 2 + 1.5, -6 + iz * 2) * CFrame.Angles(0, math.rad(45), 0), rgb(196, 202, 216), Enum.Material.Metal, { CanCollide = false })
		part(sm, "Tip", V(0.6, 0.8, 0.6), CF(-4 + ix * 2, 2 + 3.0, -6 + iz * 2) * CFrame.Angles(0, math.rad(45), 0), C.red, Enum.Material.Neon, { CanCollide = false })
	end end
	sm.PrimaryPart = root
	root:SetAttribute("Kill", true)
end

B.ElectricFloor = function(m)
	deckSlab(m, "Frame", 12, 20, 0, 0, C.teal)
	for _, side in { { "TileL", -3 }, { "TileR", 3 } } do
		for i = 0, 4 do
			local t = part(m, side[1], V(5.4, 0.2, 3.6), CF(side[2], 2.05, -8 + i * 4), C.dark, Enum.Material.Metal)
			t:SetAttribute("Tile", side[1])
		end
	end
	for i = 0, 5 do part(m, "Coil", V(11.4, 0.1, 0.4), CF(0, 2.06, -10 + i * 4), C.teal, Enum.Material.Neon, { CanCollide = false, Transparency = 0.4 }) end
end

B.FireTrap = function(m)
	deckSlab(m, "Deck", 8, 34, 0, 0, C.orange)
	for i, z in { 12, 4, -4, -12 } do
		for _, s in { -1, 1 } do part(m, "Nozzle", V(1.4, 1.6, 1.4), CF(s * 4.4, 2.8, z), POST_RED, Enum.Material.Plastic, STUDS) end
		local f = part(m, "Flame" .. i, V(8, 7, 1.8), CF(0, 5.5, z), C.orange, Enum.Material.Neon, { CanCollide = false, Transparency = 1, CanTouch = false })
		local l = Instance.new("PointLight"); l.Color = C.orange; l.Range = 14; l.Brightness = 0; l.Parent = f
		part(m, "Pilot" .. i, V(7.6, 0.12, 0.5), CF(0, 2.07, z), C.red, Enum.Material.Neon, { CanCollide = false, Transparency = 0.6 })
	end
end

B.DisappearingPlatform = function(m)
	for i, z in { 8, 0, -8 } do
		part(m, "T" .. i, V(6, 2, 6), CF(0, 1, z), C.deck, Enum.Material.Glass, { Color = rgb(150, 224, 240) })
		part(m, "T" .. i .. "Rim", V(6.2, 0.15, 6.2), CF(0, 2.0, z), C.teal, Enum.Material.Neon, { CanCollide = false, Transparency = 0.35 })
	end
end

B.BouncePad = function(m)
	deckSlab(m, "Back", 8, 6, 0, 7, C.green)
	part(m, "Bounce", V(5, 0.7, 5), CF(0, 2.35, 7), C.green, Enum.Material.Neon)
	part(m, "Spring", V(1.2, 1.2, 1.2), CF(0, 1.4, 7), C.steel, Enum.Material.Metal, { CanCollide = false })
	part(m, "HighBase", V(8, 8, 6), CF(0, 4, -7), C.wood2, Enum.Material.Plastic, STUDS)
	for i, y in { 2.2, 4.2, 6.2 } do      -- yellow 'spring' bands on the face the runner sees: reads as a launcher, not a crate (visual only)
		part(m, "SpringBand" .. i, V(8.1, 0.7, 0.2), CF(0, y, -3.95), C.yellow, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
	end
	part(m, "HighDeck", V(8, 0.8, 6), CF(0, 9.6, -7), C.deck, Enum.Material.Plastic, { TopSurface = Enum.SurfaceType.Studs, CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.2, 0.5, 1, 1) })   -- S12: studded landing deck
	part(m, "HighTrimL", V(0.35, 0.1, 6), CF(-3.8, 10.02, -7), C.green, Enum.Material.Neon, { CanCollide = false })
	part(m, "HighTrimR", V(0.35, 0.1, 6), CF(3.8, 10.02, -7), C.green, Enum.Material.Neon, { CanCollide = false })
end

local function belt(m: Model, color: Color3, reverse: boolean)
	part(m, "BeltBase", V(8, 1.2, 18), CF(0, 0.6, 0), C.wood2, Enum.Material.Plastic)
	local b = part(m, "Belt", V(7, 0.8, 18), CF(0, 1.6, 0), C.dark, Enum.Material.SmoothPlastic)
	b:SetAttribute("Belt", true)
	local cm = sub(m, "Chevrons")
	local root = part(cm, "Root", V(0.2, 0.2, 0.2), CF(0, 2.0, 0), C.dark, nil, { Transparency = 1, CanCollide = false })
	for i = 0, 5 do
		for _, s in { -1, 1 } do part(cm, "Chev", V(0.5, 0.06, 2.6), CF(s * 1.2, 2.03, -7.5 + i * 3) * CFrame.Angles(0, math.rad((if reverse then 1 else -1) * s * 40), 0), color, Enum.Material.Neon, { CanCollide = false }) end
	end
	cm.PrimaryPart = root
	for _, s in { -1, 1 } do part(m, "Guard", V(0.4, 0.5, 18), CF(s * 3.8, 2.2, 0), color, Enum.Material.Neon, { CanCollide = false }) end
end
B.ConveyorBelt = function(m) belt(m, C.teal, false) end
B.ReverseConveyor = function(m) belt(m, C.orange, true) end

B.InvisiblePlatform = function(m)
	local s = part(m, "Slab", V(10, 2, 10), CF(0, 1, 0), C.deck, Enum.Material.Glass, { Transparency = 0.93 })
	s:SetAttribute("Reveal", true)
	for _, p in { { 4.9, 0 }, { -4.9, 0 } } do part(m, "Edge", V(0.2, 0.1, 10), CF(p[1], 2.02, p[2]), C.purple, Enum.Material.Neon, { CanCollide = false, Transparency = 0.85 }) end
end

B.HammerGauntlet = function(m)
	deckSlab(m, "Deck", 14, 38, 0, 0, C.yellow)
	for _, z in { 9.5, -9.5 } do
		postPair(m, 6.6, z, 11.5, POST_RED)
		part(m, "Beam", V(14.4, 1.2, 1.4), CF(0, 14.1, z), BEAM_NAVY, Enum.Material.Plastic, STUDS)
	end
	hammer(m, "Hammer0", 9.5, 10, 4.6, rgb(220, 50, 45))
	hammer(m, "Hammer1", -9.5, 10, 4.6, rgb(220, 50, 45))
end

B.LaserLabyrinth = function(m)
	deckSlab(m, "Deck", 16, 30, 0, 0, C.purple)
	for _, z in { -15.2, 15.2 } do for _, s in { -1, 1 } do part(m, "Emitter", V(1.2, 3, 1.2), CF(s * 8.6, 3.5, z), POST_RED, Enum.Material.Plastic, STUDS) end end
	for _, s in { -1, 1 } do part(m, "Track", V(0.5, 0.3, 30), CF(s * 8.6, 2.2, 0), C.purple, Enum.Material.Neon, { CanCollide = false }) end
	beam(m, "Beam0", 2.9, 16.4, 0, C.red)
	beam(m, "Beam1", 2.9, 16.4, 0, Color3.fromRGB(255, 90, 200))
	beam(m, "Beam2", 2.9, 16.4, 0, C.purple)
end

B.PrismSpinner = function(m)
	deckSlab(m, "Deck", 20, 20, 0, 0, C.teal)
	part(m, "Hub", V(7, 2.4, 2.4), CF(0, 5.4, 0) * CFrame.Angles(0, 0, math.rad(90)), BEAM_NAVY, Enum.Material.Plastic, { Shape = Enum.PartType.Cylinder })
	local low = sub(m, "BarLow")
	local b1 = part(low, "Bar", V(18.4, 1.0, 1.3), CF(0, 3.1, 0), C.teal, Enum.Material.Neon)
	part(low, "Cap", V(1.4, 1.5, 1.5), CF(9.2, 3.1, 0), C.red, Enum.Material.Neon, { CanCollide = false })
	low.PrimaryPart = b1; b1:SetAttribute("Knock", true)
	local high = sub(m, "BarHigh")
	local b2 = part(high, "Bar", V(18.4, 1.0, 1.3), CF(0, 8.0, 0), C.purple, Enum.Material.Neon)
	part(high, "Cap", V(1.4, 1.5, 1.5), CF(-9.2, 8.0, 0), C.yellow, Enum.Material.Neon, { CanCollide = false })
	high.PrimaryPart = b2; b2:SetAttribute("Knock", true)
end

-- ===== Audit 3.2 (session 8): ROLE = colour of the side trims, plus a few per-type readability cues. Decoration only: every added
-- part is CanCollide/CanQuery/CanTouch = false and massless, sizes of walkable/hazard parts are untouched (NPC physics tests stay valid).
local ROLE_COL = {
	kill = Color3.fromRGB(255, 84, 40),      -- kills / sends back: red-orange neon
	knock = Color3.fromRGB(255, 204, 36),    -- knocks you off: yellow neon
	safe = Color3.fromRGB(70, 205, 95),      -- plain walkable: green
	move = Color3.fromRGB(58, 142, 255),     -- safe but moving / special surface: blue
}
local MOVING_SAFE = { ferry = true, rotplat = true, belt = true, speed = true, bounce = true, falling = true, vanish = true, reveal = true }
local DECO = { CanCollide = false, CanQuery = false, CanTouch = false, Massless = true, CastShadow = false }

local function roleOf(m: Model, def: any): string
	local knock = false
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			if p:GetAttribute("Kill") then return "kill" end
			if p:GetAttribute("Knock") then knock = true end
		end
	end
	if def.behavior.kind == "periodic" then return "kill" end
	if knock then return "knock" end
	if MOVING_SAFE[def.behavior.kind] then return "move" end
	return "safe"
end

local function spinGlyph(host: BasePart, dps: number?, col: Color3)
	local sg = Instance.new("SurfaceGui"); sg.Name = "SpinDir"; sg.Face = Enum.NormalId.Top; sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 60
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.TextScaled = true
	t.Font = Enum.Font.GothamBlack; t.Text = if (dps or 1) >= 0 then "↺" else "↻"; t.TextColor3 = col
	local st = Instance.new("UIStroke"); st.Thickness = 4; st.Color = Color3.fromRGB(14, 10, 18); st.Parent = t
	t.Parent = sg; sg.Parent = host
end

local function roleAccents(m: Model, def: any)
	local role = roleOf(m, def)
	local col = ROLE_COL[role]
	local neon = role == "kill" or role == "knock"
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Name:find("Trim") then
			p.Color = col; p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	local id = def.id
	if id == "RotatingBar" or id == "PrismSpinner" then
		for _, p in m:GetDescendants() do if p:IsA("BasePart") and p.Name == "Bar" then p.Material = Enum.Material.Metal end end   -- steel bar, colour kept
		local hub = m:FindFirstChild("Hub") :: BasePart?
		local dps = def.behavior.dps or (def.behavior.bars and def.behavior.bars[1] and def.behavior.bars[1].dps)
		if hub then spinGlyph(hub, dps, col) end
	elseif id == "RotatingPlatform" then
		local post = m:FindFirstChild("Post") :: BasePart?
		if post then
			local sign = part(m, "SpinSign", V(3, 0.2, 3), post.CFrame * CF(0, post.Size.Y / 2 + 0.15, 0), Color3.fromRGB(46, 58, 110), Enum.Material.SmoothPlastic, DECO)
			spinGlyph(sign, def.behavior.dps, col)
		end
	elseif id == "LavaFloor" then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				if p.Name == "Basin" then p.Material = Enum.Material.CrackedLava; p.Color = Color3.fromRGB(110, 36, 22)
				elseif p.Name:match("^StoneGlow") then p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(255, 128, 48) end
			end
		end
	elseif id == "MovingPlatform" then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Name == "RailLight" then p.Material = Enum.Material.Neon; p.Color = col end   -- the travel line
		end
		local ferry = m:FindFirstChild("FerryModel")
		local top = ferry and ferry:FindFirstChild("FerryTop") :: BasePart?
		if ferry and top then   -- neon edge frame on the moving deck (moves with it: same sub-model)
			local s = top.Size
			for i, e in { { V(s.X, 0.25, 0.3), CF(0, s.Y / 2 + 0.1, s.Z / 2 - 0.15) }, { V(s.X, 0.25, 0.3), CF(0, s.Y / 2 + 0.1, -s.Z / 2 + 0.15) },
				{ V(0.3, 0.25, s.Z), CF(s.X / 2 - 0.15, s.Y / 2 + 0.1, 0) }, { V(0.3, 0.25, s.Z), CF(-s.X / 2 + 0.15, s.Y / 2 + 0.1, 0) } } do
				part(ferry, "EdgeGlow" .. i, e[1], top.CFrame * e[2], col, Enum.Material.Neon, DECO)
			end
		end
	end
end

local Models = { C = C, part = part }

function Models.has(id: string): boolean return B[id] ~= nil end

-- Builds an obstacle model at the origin. Pivot = base centre. Attributes: ObstacleId.
function Models.build(id: string): Model?
	local def, f = Obstacles.ById[id], B[id]
	if not def or not f then return nil end
	local m = Instance.new("Model"); m.Name = id
	local root = part(m, "Root", V(1, 1, 1), CF(0, 0, 0), C.dark, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	f(m, def)
	-- Session 6 art pass (owner: obstacles looked pale/weak next to the references). COLOUR = ROLE, saturated, warm on the cyan pool:
	-- walkable deck colour by CATEGORY (Basic yellow, Moving orange, Special pink, Premium purple, Traps/Dangerous dark graphite so the
	-- hazard parts pop), the RARITY colour goes on the side trims. Colour only - sizes, materials and physics are untouched (NPC tests stay valid).
	local deckCol = CATEGORY_DECK[def.category] or C.deck
	local info = Rarities.Info[def.rarity]
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Color == C.deck then p.Color = deckCol
			elseif info and info.color and (p.Name:find("Trim") ~= nil) then p.Color = info.color end
		end
	end
	local okAcc, errAcc = pcall(roleAccents, m, def)     -- decoration must never break a build
	if not okAcc then warn("[ObstacleModels] accents " .. id .. ": " .. tostring(errAcc)) end
	m.PrimaryPart = root
	m:SetAttribute("ObstacleId", id)
	return m
end

return Models
