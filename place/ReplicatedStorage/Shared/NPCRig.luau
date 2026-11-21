--!strict
-- Builds the 21 original Roblox-style NPC testers from one clean R15 template + procedural accessories.
-- Shared: the server spawns real NPCs from it, shop/inventory UIs use it for 3D previews.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCs = require(script.Parent.Parent.Configs.NPCs)

local NPCWear = require(script.Parent.Parent.Configs.NPCWear)

local NPCRig = {}

-- welds a catalog Accessory onto the rig by its attachment (works without a Humanoid parent, so ViewportFrame previews dress too)
local function wearAccessory(m: Model, acc: Accessory, scale: number?)
	local handle = acc:FindFirstChild("Handle") :: BasePart?
	if not handle then return end
	local att = handle:FindFirstChildOfClass("Attachment")
	local target: Attachment? = nil
	if att then
		for _, d in m:GetDescendants() do
			if d:IsA("Attachment") and d.Name == att.Name and d.Parent ~= handle then target = d; break end
		end
	end
	if not target then
		local head = m:FindFirstChild("Head") :: BasePart?
		target = head and head:FindFirstChild("HatAttachment") :: Attachment?
	end
	if not target then return end
	if scale and scale ~= 1 then
		handle.Size *= scale
		if att then att.Position *= scale end
		local mesh = handle:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			mesh.Scale *= scale
			mesh.Offset *= scale
		end
	end
	handle.Anchored = false; handle.CanCollide = false; handle.CanQuery = false; handle.CanTouch = false; handle.Massless = true
	-- The attachment is scaled to the rig before the one local weld is created.
	if att then handle.CFrame = target.WorldCFrame * att.CFrame:Inverse() else handle.CFrame = target.WorldCFrame end
	local w = Instance.new("WeldConstraint"); w.Part0 = target.Parent :: BasePart; w.Part1 = handle; w.Parent = handle
	acc.Parent = m
end
local V, CF = Vector3.new, CFrame.new
local function c(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end
local ANG = CFrame.Angles
local VERT = ANG(0, 0, math.rad(90))   -- turns a Cylinder (axis = X) so that its axis is vertical

local function attach(m: Model, host: string, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?, wedge: boolean?): BasePart?
	local h = m:FindFirstChild(host) :: BasePart?
	if not h then return nil end
	local p = Instance.new(if wedge then "WedgePart" else "Part")
	p.Name = "Acc_" .. name; p.Size = size; p.Color = color; p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true; p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if props then for k, v in props do (p :: any)[k] = v end end
	p.CFrame = h.CFrame * offset
	p.Parent = m
	local w = Instance.new("WeldConstraint"); w.Part0 = h; w.Part1 = p; w.Parent = p
	return p
end
local function ball(m: Model, host: string, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): BasePart?
	local pr: { [string]: any } = props or {}; pr.Shape = Enum.PartType.Ball
	return attach(m, host, name, size, offset, color, material, pr)
end
local function cyl(m: Model, host: string, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): BasePart?
	local pr: { [string]: any } = props or {}; pr.Shape = Enum.PartType.Cylinder
	return attach(m, host, name, size, offset * VERT, color, material, pr)
end
local function ring(m: Model, host: string, name: string, radius: number, y: number, n: number, color: Color3, material: Enum.Material?, size: Vector3?)
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local col = if typeof(color) == "function" then color(i, n) else color
		attach(m, host, name .. i, size or V(0.42, 0.12, 0.2), CF(math.cos(a) * radius, y, math.sin(a) * radius) * ANG(0, -a + math.pi / 2, 0), col, material or Enum.Material.Neon)
	end
end

local A = {}
A.BaconHair = function(m)
	attach(m, "Head", "Base", V(1.28, 0.3, 1.28), CF(0, 0.6, 0.02), c(130, 62, 30))
	for i = 0, 4 do attach(m, "Head", "Strip" .. i, V(1.3, 0.1, 0.2), CF(0, 0.78, -0.5 + i * 0.25), if i % 2 == 0 then c(235, 160, 120) else c(215, 70, 50)) end
	attach(m, "Head", "Back", V(1.28, 0.7, 0.25), CF(0, 0.3, 0.6), c(130, 62, 30))
end
A.SimpleCap = function(m)
	cyl(m, "Head", "Cap", V(0.4, 1.34, 1.34), CF(0, 0.58, 0), c(40, 100, 210))
	attach(m, "Head", "Brim", V(1.0, 0.1, 0.6), CF(0, 0.52, -0.78), c(30, 80, 180))
end
A.SideHair = function(m)
	attach(m, "Head", "Top", V(1.3, 0.45, 1.3), CF(0, 0.56, 0.03), c(25, 22, 28))
	attach(m, "Head", "SideL", V(0.25, 0.8, 0.9), CF(-0.64, 0.12, 0.12), c(25, 22, 28))
	attach(m, "Head", "SideR", V(0.25, 0.8, 0.9), CF(0.64, 0.12, 0.12), c(25, 22, 28))
end
A.HardHat = function(m)
	ball(m, "Head", "Dome", V(1.5, 1.2, 1.5), CF(0, 0.5, 0), c(255, 170, 30))
	cyl(m, "Head", "Brim", V(0.1, 1.9, 1.9), CF(0, 0.42, 0), c(235, 150, 20))
	attach(m, "Head", "Ridge", V(0.2, 0.12, 1.4), CF(0, 1.08, 0), c(255, 200, 80))
end
A.Headband = function(m)
	attach(m, "Head", "Band", V(1.24, 0.2, 1.24), CF(0, 0.3, 0), c(255, 60, 60), Enum.Material.Neon)
	attach(m, "Head", "Tail", V(0.18, 0.12, 0.7), CF(0.2, 0.3, 0.9), c(255, 60, 60), Enum.Material.Neon)
end
A.NinjaMask = function(m)
	attach(m, "Head", "Wrap", V(1.24, 0.34, 1.24), CF(0, 0.34, 0), c(24, 24, 30))
	attach(m, "Head", "Mask", V(1.22, 0.5, 0.12), CF(0, -0.22, -0.58), c(24, 24, 30))
	attach(m, "Head", "Tail", V(0.16, 0.14, 0.9), CF(0.2, 0.34, 0.95), c(180, 30, 40))
end
A.Sash = function(m)
	attach(m, "LowerTorso", "Sash", V(2.05, 0.3, 1.1), CF(0, 0, 0), c(190, 30, 40))
	attach(m, "LowerTorso", "Knot", V(0.4, 0.4, 0.2), CF(0.5, 0, -0.6), c(150, 20, 30))
end
A.SpaceHelmet = function(m)
	ball(m, "Head", "Glass", V(1.95, 1.95, 1.95), CF(0, 0.05, 0), c(190, 225, 255), Enum.Material.Glass, { Transparency = 0.6 })
	attach(m, "Head", "Collar", V(1.5, 0.3, 1.5), CF(0, -0.62, 0), c(235, 235, 240))
end
A.Backpack = function(m)
	attach(m, "UpperTorso", "Pack", V(1.5, 1.7, 0.75), CF(0, 0, 0.9), c(225, 228, 235))
	attach(m, "UpperTorso", "PackStrip", V(0.3, 1.4, 0.1), CF(0, 0, 1.3), c(70, 200, 255), Enum.Material.Neon)
end
A.KnightHelm = function(m)
	attach(m, "Head", "Helm", V(1.38, 1.15, 1.38), CF(0, 0.2, 0), c(160, 165, 175), Enum.Material.Metal)
	attach(m, "Head", "Visor", V(1.0, 0.14, 0.1), CF(0, 0.15, -0.7), c(20, 22, 28))
	attach(m, "Head", "Plume", V(0.2, 0.8, 1.0), CF(0, 1.0, 0.1), c(210, 40, 40), nil, nil, true)
end
A.Pauldrons = function(m)
	for _, s in { -1, 1 } do ball(m, s == -1 and "LeftUpperArm" or "RightUpperArm", "Paul" .. s, V(1.25, 0.8, 1.3), CF(0, 0.4, 0), c(150, 155, 165), Enum.Material.Metal) end
end
A.VisorStrip = function(m)
	attach(m, "Head", "Visor", V(1.12, 0.26, 0.1), CF(0, 0.1, -0.6), c(0, 230, 255), Enum.Material.Neon)
end
A.NeonTrim = function(m, def)
	local col = def.look.neon or c(0, 230, 255)
	attach(m, "LowerTorso", "Belt", V(2.05, 0.16, 1.08), CF(0, 0.02, 0), col, Enum.Material.Neon)
	attach(m, "UpperTorso", "Chest", V(0.2, 1.2, 0.06), CF(0, 0, -0.52), col, Enum.Material.Neon)
end
A.IceCrown = function(m)
	for i, x in { -0.45, -0.22, 0, 0.22, 0.45 } do
		attach(m, "Head", "Ice" .. i, V(0.22, 0.5 + (3 - math.abs(i - 3)) * 0.25, 0.22), CF(x, 0.85 + (3 - math.abs(i - 3)) * 0.08, 0), c(190, 240, 255), Enum.Material.Ice, nil, true)
	end
end
A.FlameHair = function(m)
	for i, x in { -0.5, -0.25, 0, 0.25, 0.5 } do
		attach(m, "Head", "Flame" .. i, V(0.3, 0.7 + (i % 2) * 0.35, 0.4), CF(x, 0.85, (i - 3) * 0.1), if i % 2 == 0 then c(255, 200, 40) else c(255, 90, 20), Enum.Material.Neon, nil, true)
	end
end
A.Crown = function(m)
	cyl(m, "Head", "Ring", V(0.35, 1.3, 1.3), CF(0, 0.7, 0), c(255, 205, 50), Enum.Material.Metal)
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2
		attach(m, "Head", "Spike" .. i, V(0.2, 0.5, 0.2), CF(math.cos(a) * 0.55, 1.1, math.sin(a) * 0.55) * ANG(0, -a, 0), c(255, 205, 50), Enum.Material.Metal, nil, true)
	end
	ball(m, "Head", "Gem", V(0.22, 0.22, 0.22), CF(0, 0.75, -0.68), c(255, 60, 90), Enum.Material.Neon)
end
A.HeavyArmor = function(m)
	attach(m, "UpperTorso", "Plate", V(2.35, 1.75, 1.3), CF(0, 0, 0), c(95, 100, 118), Enum.Material.Metal)
	for _, s in { -1, 1 } do ball(m, s == -1 and "LeftUpperArm" or "RightUpperArm", "BigPaul" .. s, V(1.7, 1.1, 1.8), CF(0, 0.5, 0), c(80, 85, 102), Enum.Material.Metal) end
	attach(m, "UpperTorso", "Core", V(0.5, 0.5, 0.1), CF(0, 0.2, -0.68), c(255, 150, 40), Enum.Material.Neon)
end
A.Halo = function(m)
	ring(m, "Head", "Halo", 0.78, 1.3, 14, c(255, 230, 120), Enum.Material.Neon, V(0.42, 0.1, 0.22))
end
A.Wings = function(m)
	for _, s in { -1, 1 } do
		for k = 0, 2 do
			attach(m, "UpperTorso", "Wing" .. s .. k, V(0.12, 1.7 - k * 0.35, 1.5), CF(s * (0.9 + k * 0.28), 0.4 - k * 0.38, 0.75) * ANG(0, 0, s * math.rad(18 + k * 6)) * ANG(0, s * math.rad(18), 0), c(255, 255, 255), Enum.Material.SmoothPlastic, { Transparency = 0.1 }, true)
		end
	end
end
A.Hood = function(m)
	local col = c(26, 22, 40)
	attach(m, "Head", "Back", V(1.4, 1.4, 0.45), CF(0, 0.05, 0.62), col)
	attach(m, "Head", "Top", V(1.4, 0.4, 1.45), CF(0, 0.7, 0.02), col)
	attach(m, "Head", "SideL", V(0.22, 1.35, 1.2), CF(-0.68, 0.05, 0.08), col)
	attach(m, "Head", "SideR", V(0.22, 1.35, 1.2), CF(0.68, 0.05, 0.08), col)
	attach(m, "Head", "Point", V(0.5, 0.6, 0.5), CF(0, 0.7, 0.7), col, nil, nil, true)
end
A.StarField = function(m)
	for i = 1, 9 do
		local a, y = i * 2.4, (i % 3 - 1) * 0.7
		ball(m, "UpperTorso", "Star" .. i, V(0.3, 0.3, 0.3), CF(math.cos(a) * 1.7, y + 0.2, math.sin(a) * 1.7), if i % 2 == 0 then c(220, 190, 255) else c(255, 255, 255), Enum.Material.Neon)
	end
end
A.CrystalShards = function(m)
	local col = c(120, 235, 245)
	for i, o in { { -0.5, 0.9, 0.2, 0.35 }, { 0.1, 1.1, -0.1, 0.45 }, { 0.5, 0.85, 0.3, 0.3 } } do
		attach(m, "Head", "Shard" .. i, V(0.3, o[4] * 2.2, 0.3), CF(o[1], o[2], o[3]) * ANG(0, i, math.rad((i - 2) * 14)), col, Enum.Material.Glass, { Transparency = 0.15 }, true)
	end
	for _, s in { -1, 1 } do attach(m, s == -1 and "LeftUpperArm" or "RightUpperArm", "ShoulderShard" .. s, V(0.35, 1.1, 0.35), CF(s * 0.3, 0.8, 0) * ANG(0, 0, s * math.rad(-20)), col, Enum.Material.Glass, { Transparency = 0.15 }, true) end
end
A.GlitchBlocks = function(m)
	local cols = { c(40, 255, 160), c(255, 30, 120), c(255, 255, 255) }
	local offs = { { -1.2, 0.8, 0.3, 0.5 }, { 1.1, -0.2, -0.4, 0.4 }, { -0.8, -0.9, 0.6, 0.35 }, { 0.9, 0.9, 0.5, 0.6 }, { 0, 1.6, -0.3, 0.3 }, { -1.3, -0.1, -0.5, 0.3 }, { 1.4, 0.5, 0.1, 0.3 } }
	for i, o in offs do attach(m, "UpperTorso", "Glitch" .. i, V(o[4], o[4], o[4]), CF(o[1], o[2], o[3]) * ANG(0.4 * i, 0.7 * i, 0), cols[i % 3 + 1], Enum.Material.Neon, { Transparency = 0.1 * (i % 3) }) end
end
A.HornCrown = function(m)
	local col = c(140, 20, 40)
	for _, s in { -1, 1 } do
		attach(m, "Head", "Horn" .. s, V(0.35, 1.2, 0.35), CF(s * 0.5, 0.95, 0) * ANG(0, 0, s * math.rad(-22)), c(30, 10, 20), Enum.Material.Metal, nil, true)
		attach(m, "Head", "HornTip" .. s, V(0.2, 0.5, 0.2), CF(s * 0.78, 1.5, 0) * ANG(0, 0, s * math.rad(-30)), c(255, 60, 60), Enum.Material.Neon, nil, true)
	end
	cyl(m, "Head", "Band", V(0.3, 1.3, 1.3), CF(0, 0.55, 0), col, Enum.Material.Metal)
end
A.Cape = function(m)
	attach(m, "UpperTorso", "Cape", V(2.0, 2.6, 0.14), CF(0, -0.6, 0.62) * ANG(math.rad(-8), 0, 0), c(120, 14, 36))
	attach(m, "UpperTorso", "CapeTrim", V(2.05, 0.15, 0.16), CF(0, 0.65, 0.6), c(255, 190, 60), Enum.Material.Metal)
end
A.RainbowHalo = function(m)
	ring(m, "Head", "Rainbow", 0.82, 1.3, 16, function(i, n) return Color3.fromHSV(i / n, 0.85, 1) end, Enum.Material.Neon, V(0.46, 0.12, 0.24))
end

local SKIN = { "Head", "LeftHand", "RightHand" }
local SHIRT = { "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }
local PANTS = { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" }
local FEET = { "LeftFoot", "RightFoot" }

local function paint(m: Model, names: { string }, color: Color3, material: Enum.Material?)
	for _, n in names do
		local p = m:FindFirstChild(n) :: BasePart?
		if p then p.Color = color; if material then p.Material = material end end
	end
end

local function baseModel(): Model
	local a = ReplicatedStorage:FindFirstChild("Assets") or ReplicatedStorage:WaitForChild("Assets", 10)
	local base = a and a:WaitForChild("R15Base", 10)
	assert(base, "[NPCRig] ReplicatedStorage.Assets.R15Base missing")   -- (strict pass: explicit error instead of 'index nil')
	return base :: Model
end

-- Returns an unparented Model (Humanoid rig) dressed as NPC `id`.
function NPCRig.build(id: string): Model
	local def = NPCs.ById[id]
	local m = baseModel():Clone()
	m.Name = id
	local L = def.look
	paint(m, SKIN, L.skin, L.material)
	paint(m, SHIRT, L.shirt, L.material)
	paint(m, PANTS, L.pants, L.material)
	paint(m, FEET, L.pants:Lerp(Color3.new(0, 0, 0), 0.4), L.material)
	if L.neon then for _, n in { "LeftHand", "RightHand" } do local p = m:FindFirstChild(n); if p then p.Material = Enum.Material.Neon; p.Color = L.neon end end end
	-- session 7: real catalog wear (Configs.NPCWear, loaded by the server into ReplicatedStorage.NPCWear) instead of glued-block hair/hats;
	-- the original procedural pieces are kept only for iconic gear (`keep`), or entirely when the wear is not loaded (fallback)
	local wear = NPCWear[id]
	local store = ReplicatedStorage:FindFirstChild("NPCWear")
	local dressed = false
	if wear and store then
		dressed = true
		-- PHYSICS (session 7 A/B: Runner on Moving Wall 4/4 undressed vs 6/12 with catalog hair): the SERVER-simulated NPC gets no catalog
		-- accessories; every client adds them locally for looks (NPCRig.DressLocal, NPCController). Clothes (textures) are fine everywhere.
		if not game:GetService("RunService"):IsServer() then
			for _, hid in wear.hair or {} do
				local src = store:FindFirstChild(tostring(hid))
				if src then wearAccessory(m, src:Clone()) else dressed = false end
			end
		end
		for _, cid in { wear.shirt, wear.pants } do
			local src = cid and store:FindFirstChild(tostring(cid))
			if src then src:Clone().Parent = m end
		end
	end
	for _, name in (if dressed then wear.keep else L.acc) do
		local f = A[name]
		if f then f(m, def) end
	end
	if L.scale then m:ScaleTo(L.scale) end
	m:SetAttribute("NpcId", id)
	if L.rainbow then m:SetAttribute("Rainbow", true) end
	return m
end

-- Client only: put the catalog hair on a server-spawned NPC (cosmetic, local, massless, no collisions - never touches the simulation)
function NPCRig.DressLocal(m: Model)
	if m:GetAttribute("DressedLocal") then return end
	local id = m:GetAttribute("NpcId")
	local wear = id and NPCWear[id]
	local store = ReplicatedStorage:FindFirstChild("NPCWear")
	if not wear or not store or not m:FindFirstChild("Head") then return end
	m:SetAttribute("DressedLocal", true)
	local scale = m:GetScale()
	for _, hid in wear.hair or {} do
		local src = store:FindFirstChild(tostring(hid))
		if src then wearAccessory(m, src:Clone(), scale) end
	end
end

-- S13 ART-04 (chief P3): shop cards and the NPC window show the rare NPCs in their in-game look. A STATIC snapshot of the client
-- FX colours (NPCController fx registry) for ViewportFrame previews - Highlight and particles do not render in a ViewportFrame.
-- Colour/material of a preview copy only; never called on the server-simulated NPCs.
local PREVIEW_SEG = { Head = 0, UpperTorso = 0.08, LowerTorso = 0.16, LeftUpperArm = 0.1, RightUpperArm = 0.1, LeftLowerArm = 0.18, RightLowerArm = 0.18,
	LeftHand = 0.26, RightHand = 0.26, LeftUpperLeg = 0.26, RightUpperLeg = 0.26, LeftLowerLeg = 0.34, RightLowerLeg = 0.34, LeftFoot = 0.42, RightFoot = 0.42 }
function NPCRig.PreviewLook(m: Model)
	local id = m:GetAttribute("NpcId")
	local function each(f: (BasePart, number) -> ())
		for name, off in PREVIEW_SEG do
			local p = m:FindFirstChild(name)
			if p and p:IsA("BasePart") then f(p, off) end
		end
	end
	local function named(pattern: string, f: (BasePart) -> ())
		for _, d in m:GetDescendants() do if d:IsA("BasePart") and d.Name:match(pattern) then f(d) end end
	end
	if id == "Spectrum" then
		each(function(p, off) p.Color = Color3.fromHSV((off * 1.6) % 1, 0.7, 1) end)          -- a full rainbow from head to feet
	elseif id == "Shadow" then
		each(function(p) p.Color = Color3.fromRGB(46, 40, 70) end)
		named(".", function(p) if p.Material == Enum.Material.Neon then p.Color = Color3.fromRGB(170, 100, 255) end end)
	elseif id == "Overlord" then
		each(function(p) p.Color = Color3.fromRGB(88, 28, 40) end)
		named("HornTip", function(p) p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(255, 90, 40) end)
		named("CapeTrim", function(p) p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(255, 90, 40) end)
	elseif id == "Galaxy" then
		each(function(p, off) p.Color = Color3.fromHSV(0.55 + 0.27 * (off / 0.42), 0.8, 0.58) end)
		named("Star%d+$", function(p) p.Color = Color3.fromRGB(255, 255, 255) end)
	elseif id == "Crystal" then
		each(function(p, off) local w = off / 0.42; p.Color = Color3.fromHSV(0.46 + 0.06 * w, 0.55 - 0.4 * w, 0.85 + 0.15 * w) end)
		named("Shard", function(p) p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(200, 250, 255) end)
	end
end

return NPCRig
