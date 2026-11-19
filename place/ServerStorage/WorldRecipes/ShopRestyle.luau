-- Shared builder for the baked kiosks and a world regenerated without them.
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").Shared
local NPCRig = require(Shared.NPCRig)
local ObstacleModels = require(Shared.ObstacleModels)
local SignKit = require(Shared.SignKit)
local Promenade = require(script.Parent.LobbyPromenade)

local ShopRestyle = {}
local V, CF, rgb = Vector3.new, CFrame.new, Color3.fromRGB
local RED = rgb(207, 45, 49)
local TRIM = rgb(127, 28, 43)
local TOP = rgb(232, 76, 67)
local PALE = rgb(220, 198, 246)

ShopRestyle.Definitions = {
	obstacle = { label = "Obstacle Shop", heading = "OBSTACLES", seller = "Bacon", color = rgb(37, 120, 236), z = -58, yaw = 0 },
	npc = { label = "NPC Shop", heading = "NPC SHOP", seller = "Runner", color = rgb(255, 199, 42), z = 58, yaw = math.pi },
}

local function piece(model, base, name, size, offset, color, solid)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = base * offset
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = solid == true
	part.CanQuery = solid == true
	part.CanTouch = false
	part.Parent = model
	return part
end

local function placeModel(model, target)
	local bounds, size = model:GetBoundingBox()
	local offset = bounds:ToObjectSpace(model:GetPivot())
	model:PivotTo(target * CF(0, size.Y / 2, 0) * offset)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
		end
	end
end

local function makeSign(model, base, definition)
	local frame = piece(model, base, "SignFrame", V(21.6, 4.8, 1.3), CF(0, 21.1, -5.2), TRIM)
	frame.BackSurface = Enum.SurfaceType.Studs
	local board = piece(model, base, "SignBoard", V(19.4, 3.5, 0.38), CF(0, 21.1, -4.5), RED)
	local face = Instance.new("SurfaceGui")
	face.Name = "ShopName"
	face.Face = Enum.NormalId.Back
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = 28
	face.MaxDistance = 110
	face.LightInfluence = 0
	face.Parent = board
	SignKit.text(face, {
		Size = UDim2.fromScale(0.94, 0.82),
		Position = UDim2.fromScale(0.03, 0.09),
		Text = definition.heading,
		Font = SignKit.TITLE,
		TextColor3 = SignKit.OFFWHITE,
		strokeThickness = 3,
	})
end

local function makeCanopy(model, base, color)
	local tilt = CFrame.Angles(math.rad(16), 0, 0)
	for i = -4, 4 do
		local x = i * 4.05
		local stripe = if i % 2 == 0 then color else PALE
		local roof = CF(x, 17.45, 0.1) * tilt
		piece(model, base, "CanopyStripe", V(4.05, 0.9, 16.4), roof, stripe, true)
		local length = if i % 2 == 0 then 1.25 else 1.65
		local front = roof * V(0, -0.19, 8)
		local tab = piece(model, base, "CanopyValance", V(4.02, length, 0.8),
			CF(front.X, front.Y - length / 2 + 0.28, front.Z), stripe)
		tab.BackSurface = Enum.SurfaceType.Studs
	end
	piece(model, base, "TopRail", V(36, 1.05, 1.45), CF(0, 19.4, -6.95), TRIM)
end

local function addCounterPrompt(model, base, kind, definition)
	local promptPart = piece(model, base, "PromptPart", V(2, 1, 1), CF(0, 6, 6.2), definition.color)
	promptPart.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = definition.label
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 20
	prompt:SetAttribute("ShopKind", kind)
	CollectionService:AddTag(prompt, "TL_ShopPrompt")
	prompt.Parent = promptPart

	-- The existing HUD teleport spawns ahead of the landing and faces the counter.
	local landing = piece(model, base, "Landing", V(2, 0.1, 2), CF(0, 0, 12.3), definition.color)
	landing.Transparency = 1
end

function ShopRestyle.BuildKiosk(kind, previous)
	local definition = assert(ShopRestyle.Definitions[kind], "Unknown shop kind")
	local base = CF(Promenade.ShopX, Promenade.FloorY, definition.z) * CFrame.Angles(0, definition.yaw, 0)
	local model = Instance.new("Model")
	model.Name = "Shop_" .. kind
	model:SetAttribute("ShopKind", kind)
	model.WorldPivot = base

	piece(model, base, "BaseTrim", V(34, 0.42, 13.2), CF(0, 0.22, 0), TRIM, true)
	piece(model, base, "Floor", V(32.8, 0.47, 12.5), CF(0, 0.58, 0), RED, true)
	for _, side in { -1, 1 } do
		local x = side * 15.1
		for _, post in { { -5.1, 18.1 }, { 4.8, 15.75 } } do
			local z, top = post[1], post[2]
			piece(model, base, "PostFoot", V(3.25, 3.2, 3.25), CF(x, 1.6, z), TRIM, true)
			local pillar = piece(model, base, "Post", V(2.25, top - 3, 2.25), CF(x, (top + 3) / 2, z), RED, true)
			pillar.BackSurface = Enum.SurfaceType.Studs
		end
		piece(model, base, "SideRail", V(1.2, 2, 8.8), CF(x, 2.15, -0.1), RED, true)
	end
	piece(model, base, "BackRail", V(28.6, 2.1, 0.9), CF(0, 2.1, -5.05), RED, true)
	local counter = piece(model, base, "Counter", V(28.4, 3.9, 2.8), CF(0, 2.2, 4.6), RED, true)
	counter.BackSurface = Enum.SurfaceType.Studs
	piece(model, base, "CounterSkirt", V(28.6, 0.42, 2.95), CF(0, 0.65, 4.65), TRIM)
	piece(model, base, "CounterTop", V(29.2, 0.6, 3.2), CF(0, 4.22, 4.6), TOP, true)

	makeCanopy(model, base, definition.color)
	makeSign(model, base, definition)
	addCounterPrompt(model, base, kind, definition)

	-- Reuse the hand-dressed seller, including its catalog clothes and accessories.
	local oldSeller = previous and previous:FindFirstChild("Shopkeeper")
	local seller = if oldSeller then oldSeller:Clone() else NPCRig.build(definition.seller)
	if not oldSeller then seller:ScaleTo(1.85) end
	seller.Name = "Shopkeeper"
	seller:SetAttribute("NpcId", definition.seller)
	placeModel(seller, base * CF(0, 0.82, -0.6) * CFrame.Angles(0, math.pi, 0))
	local humanoid = seller:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	seller.Parent = model

	if kind == "obstacle" then
		for _, entry in { { "SpikePlatform", -9 }, { "RotatingBar", 9 } } do
			local id, x = entry[1], entry[2]
			local display = ObstacleModels.build(id)
			local size = display:GetExtentsSize()
			display:ScaleTo(math.min(4.5 / math.max(size.X, size.Z), 2.3 / size.Y))
			piece(model, base, "DisplayTile", V(5.4, 0.3, 2.9), CF(x, 4.66, 4.6), TRIM)
			display.Name = "Display_" .. id
			placeModel(display, base * CF(x, 4.81, 4.6))
			display.Parent = model
		end
	end
	return model
end

function ShopRestyle.Build(previous)
	local folder = Instance.new("Folder")
	folder.Name = "Shops"
	folder:SetAttribute("HandEdited", true)
	for kind in ShopRestyle.Definitions do
		local old = previous and previous:FindFirstChild("Shop_" .. kind)
		ShopRestyle.BuildKiosk(kind, old).Parent = folder
	end
	return folder
end

function ShopRestyle.Run()
	local world = workspace.WorldAssets
	local previous = world:FindFirstChild("Shops")
	local replacement = ShopRestyle.Build(previous)
	if previous then previous:Destroy() end
	replacement.Parent = world
	return replacement
end

return ShopRestyle
