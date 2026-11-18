-- The west plaza joins the shop fronts and the leaderboard courtyard to the plot aisle.
local Promenade = {}
local settings = require(game:GetService("ReplicatedStorage").Configs.Balance).Promenade

local V, CF, rgb = Vector3.new, CFrame.new, Color3.fromRGB
local ROAD_START, ROAD_END, ROAD_HALF_WIDTH = -548, 524, 20
Promenade.FloorY = 0.12
Promenade.ShopX = -586
Promenade.HallTransform = CF(-653, Promenade.FloorY, 0) * CFrame.Angles(0, -math.pi / 2, 0)

local SAND = rgb(238, 210, 153)
local CURB = rgb(84, 64, 55)
local AMBER = rgb(255, 200, 50)
local ORANGE = rgb(227, 114, 39)
local BLUE = rgb(23, 102, 181)
local INK = rgb(28, 37, 49)

local function part(parent, name, size, cf, color, solid)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanQuery = solid == true
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function buildRoad(parent)
	local length, center = ROAD_END - ROAD_START, (ROAD_START + ROAD_END) / 2
	local top = Promenade.FloorY
	part(parent, "AisleDeck", V(length, 0.7, 40), CF(center, top - 0.35, 0), SAND, true)
	local strips = {
		{ "InsideCurb", 2.5, 1, CURB },
		{ "InsideLine", 3.5, 0.5, AMBER },
		{ "InsideEdge", 4, 1, ORANGE },
		{ "OutsideEdge", 14, 1, ORANGE },
		{ "OutsideLine", 15, 0.5, AMBER },
		{ "OutsideCurb", 15.5, 1, CURB },
	}
	for _, side in { -1, 1 } do
		for _, strip in strips do
			local name, offset, width, color = table.unpack(strip)
			local p = part(parent, name, V(length, 0.08, width), CF(center, top, side * (offset + width / 2)), color)
			p.CastShadow = false
		end
		local laneZ = side * 9.5
		local lane = part(parent, if side < 0 then "WestLane" else "EastLane", V(length, 0.26, 9),
			CF(center, top - 0.01, laneZ), BLUE, true)
		lane.CastShadow = false
		lane.CustomPhysicalProperties = PhysicalProperties.new(1, 0.8, 0, 100, 1)

		local arrows = Instance.new("Folder")
		arrows.Name = lane.Name .. "Arrows"
		arrows:SetAttribute("Direction", side)
		local interval = settings.MarkerSpacing
		local count = math.floor((length - 12) / interval)
		local first = center - count * interval / 2
		arrows:SetAttribute("StartX", first)
		arrows:SetAttribute("Span", count * interval)
		for i = 0, count - 1 do
			local x = first + i * interval
			local tip = V(x + side * 2.5, top + 0.145, laneZ)
			for _, wing in { -1, 1 } do
				local tail = V(x - side * 2.5, tip.Y, laneZ + wing * 3.9)
				local delta = tip - tail
				local mid = (tip + tail) / 2 + V(0, wing * 0.003, 0)
				local p = part(arrows, "Chevron", V(1.35, 0.036, delta.Magnitude + 0.5), CFrame.lookAt(mid, mid + delta), INK)
				p:SetAttribute("TrackX", x)
				p.CastShadow = false
			end
		end
		arrows.Parent = parent
	end
end

local function buildApproach(parent, path)
	local pos = path.Position
	local top = pos.Y + path.Size.Y / 2
	local side = math.sign(pos.Z)
	local edge = math.abs(pos.Z) - path.Size.Z / 2
	local width = math.max(1, edge - ROAD_HALF_WIDTH + 1.2)
	part(parent, "PlotApproach", V(path.Size.X, 0.35, width),
		CF(pos.X, top - 0.175, side * (ROAD_HALF_WIDTH + width / 2 - 0.4)), SAND, true)
end

function Promenade.Build(world, plots)
	local existing = world:FindFirstChild("MarketPromenade")
	if existing then return existing end

	local model = Instance.new("Model")
	model.Name = "MarketPromenade"
	local plazaStart = -627
	part(model, "MarketPlaza", V(ROAD_START - plazaStart, 0.7, 136),
		CF((ROAD_START + plazaStart) / 2, Promenade.FloorY - 0.35, 0), SAND, true)
	for _, side in { -1, 1 } do
		part(model, "PlazaBorder", V(ROAD_START - plazaStart, 0.16, 1.5),
			CF((ROAD_START + plazaStart) / 2, Promenade.FloorY, side * 67), CURB)
		part(model, "HallWalk", V(26, 0.6, 36), CF(-627, Promenade.FloorY - 0.3, side * 86), SAND, true)
	end
	buildRoad(model)
	for _, plot in plots:GetChildren() do
		local path = plot:FindFirstChild("Path")
		if path and path:IsA("BasePart") then buildApproach(model, path) end
	end

	model.Parent = world
	return model
end

function Promenade.EnableBelts(model)
	for _, side in { -1, 1 } do
		local lane = model:FindFirstChild(if side < 0 then "WestLane" else "EastLane")
		if lane then lane.AssemblyLinearVelocity = Vector3.xAxis * settings.BeltSpeed * side end
	end
end

function Promenade.PlaceHall(hall)
	if hall:GetAttribute("MarketPlaced") then return end
	hall:PivotTo(Promenade.HallTransform * hall:GetPivot())
	hall:SetAttribute("MarketPlaced", true)
end

return Promenade
