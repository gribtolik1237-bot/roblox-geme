--!nonstrict
-- Dressing of the market plaza (ART-04/08): two-tone studded paving, navy curb, teal "stand here" discs in front of both kiosks and props.
-- Idempotent: everything lives in model.MarketDress; Build(model, true) rebuilds it. All parts are inert (never collide, never queryable).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignKit = require(ReplicatedStorage.Shared.SignKit)
local DecorModels = require(ReplicatedStorage.Shared.DecorModels)

local Dress = {}
local V, CF, ANG, rgb = Vector3.new, CFrame.new, CFrame.Angles, Color3.fromRGB
local FLOOR = 0.12                                  -- Promenade.FloorY (top of MarketPlaza)
local X0, X1, Z0, Z1 = -626.5, -548.5, -66.25, 66.25   -- inside the curb strips
local COLS, ROWS = 10, 16
local CREAM, PEACH = rgb(250, 232, 186), rgb(241, 196, 128)
local TEAL, MINT = rgb(24, 170, 176), rgb(124, 232, 226)
local NAVY = SignKit.WOOD_DARK
local INERT = { CanCollide = false, CanQuery = false, CanTouch = false }
Dress.KioskZ = 58                                   -- side stalls face the plaza centre: seen edge-on from the aisle they never hide the boards behind them
Dress.DiscX = -586
Dress.DiscDist = 17.5                               -- from the kiosk centre to the disc centre (Landing is 12.3 in front of the counter line)

local function mk(parent, name, size, cf, color, studs, extra)
	local props = { CanCollide = false, CanQuery = false, CanTouch = false, studs = studs }
	if extra then for k, v in extra do props[k] = v end end
	return SignKit.mk(parent, name, size, cf, color, nil, props)
end

local function lantern(folder, x, z)
	local m = Instance.new("Model"); m.Name = "Prop_Lantern"
	local YEL = rgb(255, 214, 80)
	local function cyl(name, h, d, y, color, mat)
		local p = mk(m, name, V(h, d, d), CF(x, FLOOR + 0.1 + y, z) * ANG(0, 0, math.rad(90)), color, false, { Shape = Enum.PartType.Cylinder })
		p.Material = mat or Enum.Material.SmoothPlastic
		return p
	end
	cyl("Foot", 1.0, 4.2, 0.5, NAVY, Enum.Material.Plastic)
	cyl("Post", 11.6, 1.1, 6.3, NAVY)
	cyl("Collar", 0.7, 3.4, 12.2, SignKit.INK)
	local globe = mk(m, "Globe", V(3.8, 3.8, 3.8), CF(x, FLOOR + 0.1 + 14.3, z), YEL, false, { Shape = Enum.PartType.Ball, CastShadow = false })
	globe.Material = Enum.Material.Neon
	mk(m, "Finial", V(1.2, 1.2, 1.2), CF(x, FLOOR + 0.1 + 16.6, z), SignKit.INK, false, { Shape = Enum.PartType.Ball })
	local l = Instance.new("PointLight"); l.Color = rgb(255, 214, 140); l.Range = 24; l.Brightness = 1.3; l.Parent = globe
	m.Parent = folder
end

local function prop(folder, id, x, z, yaw, scale)
	local m = DecorModels.build(id)
	if not m then return end
	m:ScaleTo(scale)
	m:PivotTo(CF(x, FLOOR + 0.1, z) * ANG(0, math.rad(yaw), 0))
	DecorModels.ground(m, FLOOR + 0.1)
	m.Name = "Prop_" .. id
	m.Parent = folder
end

function Dress.Build(model: Model, rebuild: boolean?, withBushes: boolean?)
	local old = model:FindFirstChild("MarketDress")
	if old then
		if not rebuild then return old end
		old:Destroy()
	end
	local folder = Instance.new("Folder"); folder.Name = "MarketDress"

	-- paving: 10 x 16 two-tone tiles over the sand deck
	local tiles = Instance.new("Folder"); tiles.Name = "Tiles"; tiles.Parent = folder
	local w, d = (X1 - X0) / COLS, (Z1 - Z0) / ROWS
	for c = 0, COLS - 1 do
		for r = 0, ROWS - 1 do
			mk(tiles, ("Tile_R%dC%d"):format(r + 1, c + 1), V(w, 0.1, d), CF(X0 + w * (c + 0.5), FLOOR + 0.05, Z0 + d * (r + 0.5)), if (c + r) % 2 == 0 then CREAM else PEACH, true, { CastShadow = false })
		end
	end

	-- navy curb on both long sides (replaces the thin brown strips)
	for _, p in model:GetChildren() do
		if p.Name == "PlazaBorder" and p:IsA("BasePart") then
			p.Color = NAVY; p.Size = V(p.Size.X, 0.5, 2.2)
			p.CFrame = CF(p.Position.X, FLOOR + 0.25, math.sign(p.Position.Z) * 66.9)
		end
	end

	-- teal "stand here" discs in front of the kiosk counters (owner reference: ring glows where you interact)
	for _, side in { -1, 1 } do
		local z = side * (Dress.KioskZ - Dress.DiscDist)
		local ring = mk(folder, "ShopRing", V(0.12, 15, 15), CF(Dress.DiscX, FLOOR + 0.17, z) * ANG(0, 0, math.rad(90)), TEAL, false, { Shape = Enum.PartType.Cylinder, CastShadow = false })
		ring.Material = Enum.Material.SmoothPlastic
		local disc = mk(folder, "ShopDisc", V(0.12, 12.4, 12.4), CF(Dress.DiscX, FLOOR + 0.23, z) * ANG(0, 0, math.rad(90)), MINT, false, { Shape = Enum.PartType.Cylinder, CastShadow = false })
		disc.Material = Enum.Material.SmoothPlastic
	end

	-- plaza medallion: concentric studless rings in the plaza centre (navy / amber / cream / teal), inert floor paint
	local MX, MZ = -590, 0
	for i, ring in { { 31, NAVY }, { 27, SignKit.YELLOW }, { 23.6, CREAM }, { 17, rgb(227, 114, 39) }, { 13.6, CREAM }, { 8, rgb(206, 58, 50) } } do
		local c = mk(folder, "Medallion" .. i, V(0.12, ring[1], ring[1]), CF(MX, FLOOR + 0.12 + i * 0.012, MZ) * ANG(0, 0, math.rad(90)), ring[2], false, { Shape = Enum.PartType.Cylinder, CastShadow = false })
		c.Material = Enum.Material.SmoothPlastic
	end

	-- props: lanterns frame the entrance, flower beds behind the kiosks
	for _, side in { -1, 1 } do
		lantern(folder, -558, side * 27)
		lantern(folder, -614, side * 27)
		prop(folder, "FlowerPatch", -556, side * 50, 0, 2.6)
		prop(folder, "FlowerPatch", -616, side * 50, 40, 2.6)
		if withBushes then
			prop(folder, "Bush", -553, side * 64, 0, Dress.BushScale or 1.4)
			prop(folder, "Bush", -622, side * 64, 90, Dress.BushScale or 1)
			prop(folder, "Bush", -553, side * 34, 40, Dress.BushScale or 1)
		end
	end
	folder.Parent = model
	return folder
end

return Dress
