--!nonstrict
-- Procedural, original cosmetic models (spec 17). Origin = ground centre. EVERY part is non-colliding and not queryable: decorations must never
-- block building, walking, NPC ground checks or raycasts.
local Decor = require(script.Parent.Parent.Configs.Decor)
local M = {}
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local VERT = ANG(0, 0, math.rad(90))     -- a Cylinder's axis is X: turn it upright

local function part(m, name, size, cf, color, mat, shape, props)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	if props then for k, v in props do p[k] = v end end
	p.Parent = m
	return p
end
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local function post(m, name, h, r, x, z, color, mat) return part(m, name, V(h, r * 2, r * 2), CF(x, h / 2, z) * VERT, color, mat, CYL) end

local B = {}
-- brick-toy blocks: studded Plastic cubes/slabs (the owner's references: trees, bushes and rocks are stacked blocks, not smooth blobs)
local STUD = Enum.SurfaceType.Studs
local function blk(m, name, size, cf, color, mat)
	return part(m, name, size, cf, color, mat or Enum.Material.Plastic, nil, { TopSurface = STUD })
end
-- audit 2 / phase B: nature props keep the stacked-block silhouette but read as REAL materials - LeafyGrass canopy,
-- Wood trunks, Slate rocks - instead of flat Plastic
B.Rock = function(m)
	blk(m, "Rock", V(3.2, 1.8, 2.6), CF(0, 0.9, 0) * ANG(0, 0.4, 0), rgb(150, 156, 170), Enum.Material.Slate)
	blk(m, "RockTop", V(1.8, 0.9, 1.5), CF(-0.2, 2.2, 0.1) * ANG(0, 0.9, 0), rgb(168, 174, 188), Enum.Material.Slate)
	blk(m, "RockB", V(1.9, 1.2, 1.7), CF(1.9, 0.6, 0.8) * ANG(0, 0.8, 0), rgb(124, 130, 146), Enum.Material.Slate)
end
B.BigRock = function(m)
	blk(m, "R1", V(6, 3.4, 5), CF(0, 1.7, 0) * ANG(0, 0.4, 0), rgb(140, 146, 162), Enum.Material.Slate)
	blk(m, "R1Top", V(3.6, 2, 3), CF(-0.4, 4.3, 0.2) * ANG(0, 0.9, 0), rgb(166, 172, 186), Enum.Material.Slate)
	blk(m, "R2", V(3.6, 2.6, 3.2), CF(-3.4, 1.3, 1.6) * ANG(0, 1, 0), rgb(158, 164, 178), Enum.Material.Slate)
	blk(m, "R3", V(2.8, 2, 2.4), CF(3.4, 1, -1.4) * ANG(0, 0.3, 0), rgb(124, 130, 146), Enum.Material.Slate)
end
B.Bush = function(m)
	blk(m, "B1", V(4.8, 2.6, 4.4), CF(0, 1.3, 0), rgb(76, 200, 110), Enum.Material.LeafyGrass)
	blk(m, "B2", V(3.2, 2, 3), CF(0.3, 3.5, 0.1), rgb(92, 214, 124), Enum.Material.LeafyGrass)
	blk(m, "B3", V(2.2, 1.6, 2.2), CF(-1.9, 0.8, 2.2), rgb(64, 184, 98), Enum.Material.LeafyGrass)
	blk(m, "B4", V(1.6, 1.4, 1.6), CF(2.1, 2.9, -1.2), rgb(64, 184, 98), Enum.Material.LeafyGrass)
end
B.FlowerPatch = function(m)
	blk(m, "Bed", V(5.6, 0.5, 5.6), CF(0, 0.25, 0), rgb(86, 190, 104), Enum.Material.LeafyGrass)
	local cols = { rgb(255, 120, 170), rgb(255, 214, 70), rgb(255, 255, 255), rgb(190, 130, 255) }
	for i = 1, 9 do
		local a = i * 2.4
		local x, z = math.cos(a) * (0.6 + i * 0.22), math.sin(a) * (0.6 + i * 0.22)
		part(m, "Stem" .. i, V(0.2, 1.2, 0.2), CF(x, 1.1, z), rgb(60, 150, 80))
		part(m, "Bloom" .. i, V(1, 1, 1), CF(x, 1.9, z) * ANG(0, a, 0), cols[i % #cols + 1], Enum.Material.Plastic)
	end
end
B.Mushrooms = function(m)
	for i, d in { { 0, 0, 1.4 }, { 1.3, 0.7, 0.9 }, { -1, 0.9, 1.1 } } do
		part(m, "Stalk" .. i, V(d[3] * 0.7, d[3], d[3] * 0.7), CF(d[1], d[3] / 2, d[2]), rgb(246, 240, 224), Enum.Material.Plastic)
		blk(m, "Cap" .. i, V(d[3] * 1.9, d[3] * 0.8, d[3] * 1.9), CF(d[1], d[3] + d[3] * 0.4, d[2]), rgb(230, 70, 70))
		part(m, "Dot" .. i, V(0.4, 0.2, 0.4), CF(d[1] + d[3] * 0.4, d[3] + d[3] * 0.85, d[2] + 0.2), Color3.new(1, 1, 1), Enum.Material.Plastic)
	end
end
B.Tree = function(m)
	part(m, "Trunk", V(1.8, 5.6, 1.8), CF(0, 2.8, 0), rgb(130, 90, 56), Enum.Material.Wood)
	blk(m, "C1", V(8.4, 3.2, 8.4), CF(0, 6.6, 0), rgb(76, 188, 96), Enum.Material.LeafyGrass)
	blk(m, "C1a", V(3.4, 3, 3.4), CF(4.6, 6.2, 2.6), rgb(64, 172, 84), Enum.Material.LeafyGrass)
	blk(m, "C1b", V(3, 2.8, 3), CF(-4.4, 7, -2.8), rgb(92, 204, 112), Enum.Material.LeafyGrass)
	blk(m, "C2", V(6, 3.2, 6), CF(0, 9.8, 0), rgb(92, 204, 112), Enum.Material.LeafyGrass)
	blk(m, "C3", V(3.6, 2.8, 3.6), CF(0, 12.4, 0), rgb(110, 222, 130), Enum.Material.LeafyGrass)
end
B.PineTree = function(m)
	part(m, "Trunk", V(1.6, 3.4, 1.6), CF(0, 1.7, 0), rgb(120, 84, 52), Enum.Material.Wood)
	for i, d in { { 7.4, 3.6 }, { 5.6, 6.2 }, { 3.8, 8.8 }, { 2, 11.2 } } do
		blk(m, "Tier" .. i, V(d[1], 2.6, d[1]), CF(0, d[2], 0), rgb(40 + i * 10, 140 + i * 14, 92), Enum.Material.LeafyGrass)
	end
	part(m, "Tip", V(1.4, 1.4, 1.4), CF(0, 13.2, 0) * ANG(0.5, 0.5, 0), rgb(255, 214, 70), Enum.Material.Neon)
end
B.Lantern = function(m)
	post(m, "Pole", 6, 0.3, 0, 0, rgb(104, 56, 44), Enum.Material.Plastic)
	part(m, "Base", V(1.8, 0.5, 1.8), CF(0, 0.25, 0), rgb(104, 56, 44), Enum.Material.Plastic)
	local glass = part(m, "Lamp", V(1.5, 1.8, 1.5), CF(0, 6.9, 0), rgb(255, 224, 140), Enum.Material.Neon, BALL)
	local l = Instance.new("PointLight"); l.Color = rgb(255, 214, 140); l.Range = 22; l.Brightness = 1.6; l.Parent = glass
	part(m, "Cap", V(2.1, 0.5, 2.1), CF(0, 7.9, 0), rgb(104, 56, 44), Enum.Material.Plastic)
end
B.Banner = function(m)
	post(m, "Pole", 9, 0.25, 0, 0, rgb(180, 190, 210), Enum.Material.Metal)
	part(m, "Flag", V(3.4, 5, 0.2), CF(1.8, 6, 0), rgb(255, 196, 61))
	part(m, "Stripe", V(3.4, 1.2, 0.24), CF(1.8, 6.4, 0), rgb(46, 214, 224))
	part(m, "Knob", V(0.8, 0.8, 0.8), CF(0, 9.2, 0), rgb(255, 196, 61), Enum.Material.Neon, BALL)
end
B.CrystalCluster = function(m)
	local c = rgb(70, 224, 232)
	for i, d in { { 0, 0, 5, 1.4 }, { 1.4, 0.6, 3.4, 1 }, { -1.3, -0.5, 3, 1 }, { 0.4, -1.5, 2.2, 0.8 } } do
		local p = part(m, "Crystal" .. i, V(d[4], d[3], d[4]), CF(d[1], d[3] / 2, d[2]) * ANG(0.12 * i, i, 0.1 * i), c, Enum.Material.Neon)
		p.Transparency = 0.15
	end
	local l = Instance.new("PointLight"); l.Color = c; l.Range = 16; l.Brightness = 1.2; l.Parent = m:FindFirstChild("Crystal1")
end
B.Fountain = function(m)
	part(m, "Basin", V(13, 2, 13), CF(0, 1, 0) * VERT, rgb(190, 198, 214), Enum.Material.Marble, CYL).CFrame = CF(0, 1, 0) * VERT
	part(m, "Water", V(11, 0.3, 11), CF(0, 1.9, 0) * VERT, rgb(70, 190, 255), Enum.Material.SmoothPlastic, CYL, { Transparency = 0.3 }).CFrame = CF(0, 1.9, 0) * VERT
	post(m, "Column", 5, 0.9, 0, 0, rgb(206, 212, 226), Enum.Material.Marble)
	part(m, "Bowl", V(6, 1, 6), CF(0, 5, 0) * VERT, rgb(190, 198, 214), Enum.Material.Marble, CYL).CFrame = CF(0, 5, 0) * VERT
	part(m, "Spout", V(1.4, 1.4, 1.4), CF(0, 6.4, 0), rgb(120, 220, 255), Enum.Material.Neon, BALL)
	local l = Instance.new("PointLight"); l.Color = rgb(120, 220, 255); l.Range = 24; l.Brightness = 1.4; l.Parent = m.Spout
end
B.Archway = function(m)
	for _, s in { -1, 1 } do
		part(m, "Pillar", V(2.6, 12, 2.6), CF(s * 6.5, 6, 0), rgb(208, 214, 230), Enum.Material.Marble)
		part(m, "PillarCap", V(3.4, 1, 3.4), CF(s * 6.5, 12.5, 0), rgb(160, 170, 192), Enum.Material.Marble)
		part(m, "Gem", V(1.2, 1.2, 1.2), CF(s * 6.5, 13.6, 0), rgb(255, 196, 61), Enum.Material.Neon, BALL)
	end
	part(m, "Beam", V(17, 2, 2.6), CF(0, 13, 0), rgb(208, 214, 230), Enum.Material.Marble)
	part(m, "BeamTrim", V(17.2, 0.4, 2.8), CF(0, 14.1, 0), rgb(255, 196, 61), Enum.Material.SmoothPlastic)
end

function M.build(id)
	local f = B[id]
	if not f or not Decor.ById[id] then return nil end
	local m = Instance.new("Model"); m.Name = id
	f(m)
	m:SetAttribute("DecorId", id)
	return m
end

return M
