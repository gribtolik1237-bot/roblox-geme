-- !!! POST-EDITED BAKE (session 5, owner rules "kiosk size like the references" + "no wood"): the baked Shop_obstacle / Shop_npc in
-- WorldAssets.Shops were changed by hand AFTER Build(): whole model ScaleTo 0.6 (columns 18 studs) and plaza top re-aligned to y=1,
-- coloured plastic instead of WoodPlanks, wall "Seam" battens hidden, Display_* models x1.9, neon TradeRing at the landing, bigger
-- sign title (stroke 7), counter prompt MaxActivationDistance 24, NPC Shop mannequins + pedestals REMOVED and ONE Shopkeeper rig per shop (owner rule:
-- one NPC seller, not many; Obstacle Shop = Bacon, NPC Shop = Runner, anchored behind the counter, ~11.7 studs). Build(true) would UNDO all of that - re-apply (docs/TASKS.md) or port it here first.
--!nonstrict
-- Physical shops in the lobby (USER REQUEST): every shop except the Robux (donation) shop STANDS on the map, has an "Open" prompt on its
-- counter and a HUD button that teleports the player to it. The donation shop has no building and no teleport (window only).
-- Built for the giant lobby avatar (Balance.Avatar.Lobby = x2): counters, doors and awnings are twice normal size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Net = require(ReplicatedStorage.Shared.Net)
local ObstacleModels = require(ReplicatedStorage.Shared.ObstacleModels)
local NPCRig = require(ReplicatedStorage.Shared.NPCRig)
local NPCs = require(ReplicatedStorage.Configs.NPCs)
local Rarities = require(ReplicatedStorage.Configs.Rarities)
local SignKit = require(ReplicatedStorage.Shared.SignKit)
local DecorModels = require(ReplicatedStorage.Shared.DecorModels)

local Service = {}
local V, CF = Vector3.new, CFrame.new

-- Art direction (docs/ART_DIRECTION.md, "Etalony"): brick-toy pavilions - wooden frame, cream panels, striped fabric awning, studded sand plaza with a wooden curb, sign with fat outlined text.
local GRAPHITE, STEEL, CONCRETE, CURB, WOOD, CREAM = SignKit.WOOD_DARK, SignKit.WOOD, SignKit.SAND, SignKit.WOOD_DARK, SignKit.WOOD_LIGHT, SignKit.CREAM

-- x: the shop stands at the lobby end, facing the centre of the lobby. yaw maps the shop's local +Z (customer side) to the world.
local SHOPS = {
	obstacle = { title = "OBSTACLE SHOP", sub = "New items every 5 minutes", color = Color3.fromRGB(34, 190, 200), x = -585, yaw = 90, objectText = "Obstacle Shop" },
	npc = { title = "NPC SHOP", sub = "Hire a tester for your course", color = Color3.fromRGB(128, 96, 230), x = 585, yaw = -90, objectText = "NPC Shop" },
}

local function mk(model, base, name, size, offset, color, material, props)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = base * offset; p.Color = color; p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if p.Material == Enum.Material.Plastic then p.TopSurface = Enum.SurfaceType.Studs end
	if props then for k, v in props do p[k] = v end end
	p.Parent = model
	return p
end

-- Places a display model on a surface: bottom-centre of its bounding box at `worldPos`, facing the customers.
local function placeDisplay(m, worldPos, baseRot)
	local pivot = m:GetPivot()
	local bb, sz = m:GetBoundingBox()
	local rel = bb:ToObjectSpace(pivot)
	local target = CF(worldPos + V(0, sz.Y / 2, 0)) * baseRot * CFrame.Angles(0, math.pi, 0)
	m:PivotTo(target * rel)
end

local function freeze(m)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanTouch = false end
		if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
end

local function prop(model, base, id, x, z, yaw, scale)       -- cosmetic dressing from the decor catalog (never collides); scaled for the x2 lobby avatar
	local m = DecorModels.build(id)
	if m then m:ScaleTo(scale or 2.2); m:PivotTo(base * CF(x, 1, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)); m.Name = "Prop_" .. id; m.Parent = model end
end

local function buildShop(kind, def)
	local model = Instance.new("Model"); model.Name = "Shop_" .. kind
	model:SetAttribute("ShopKind", kind)
	local base = CF(def.x, 0, 0) * CFrame.Angles(0, math.rad(def.yaw), 0)
	local baseRot = CFrame.Angles(0, math.rad(def.yaw), 0)
	local acc = def.color
	local accDark = acc:Lerp(Color3.new(0, 0, 0), 0.38)

	-- concrete plaza with a raised curb all round and a darker slab path to the counter (no thin strips, no neon)
	mk(model, base, "Plaza", V(112, 1, 84), CF(0, 0.5, 0), CONCRETE, Enum.Material.Plastic)
	mk(model, base, "CurbFront", V(116, 1.6, 2.4), CF(0, 0.8, 43), CURB, Enum.Material.Plastic)
	mk(model, base, "CurbBack", V(116, 1.6, 2.4), CF(0, 0.8, -43), CURB, Enum.Material.Plastic)
	for _, s in { -1, 1 } do mk(model, base, "CurbSide", V(2.4, 1.6, 84), CF(s * 57, 0.8, 0), CURB, Enum.Material.Plastic) end
	mk(model, base, "Path", V(22, 0.2, 44), CF(0, 1.1, 20), CONCRETE:Lerp(Color3.new(0, 0, 0), 0.14), Enum.Material.Plastic, { CanCollide = false })

	-- steel frame + cladding: corner columns, ribbed back wall, side walls, accent-dark plinth
	for _, sx in { -1, 1 } do
		for _, z in { -26, 0 } do mk(model, base, "Column", V(3.4, 30, 3.4), CF(sx * 31, 16, z), STEEL, Enum.Material.Plastic) end
		mk(model, base, "SideWall", V(2, 30, 24), CF(sx * 30.5, 16, -13), CREAM)
		mk(model, base, "SidePlinth", V(2.4, 6, 24.4), CF(sx * 30.5, 4, -13), accDark)
	end
	mk(model, base, "BackWall", V(60, 30, 2), CF(0, 16, -25), CREAM)
	mk(model, base, "BackPlinth", V(60.4, 6, 2.4), CF(0, 4, -25), accDark)
	for i = -5, 5 do mk(model, base, "Seam", V(0.5, 24, 0.3), CF(i * 5, 18, -23.9), CREAM:Lerp(Color3.new(0, 0, 0), 0.2)) end     -- panel joints, tone-on-tone
	mk(model, base, "Floor", V(58, 0.3, 24), CF(0, 1.15, -13), GRAPHITE:Lerp(accDark, 0.3), Enum.Material.Plastic, { CanCollide = false })

	-- roof: graphite slab, accent fascia, rooftop units (breaks the silhouette)
	local roof = mk(model, base, "Roof", V(72, 3, 36), CF(0, 32.5, -9), GRAPHITE, Enum.Material.Plastic)
	local lamp = Instance.new("PointLight"); lamp.Color = Color3.fromRGB(255, 232, 190); lamp.Range = 70; lamp.Brightness = 2.4; lamp.Parent = roof
	mk(model, base, "Fascia", V(73, 2.6, 2), CF(0, 32.5, 9.6), acc)
	mk(model, base, "Vent", V(7, 3.4, 7), CF(-20, 35.7, -16), STEEL, Enum.Material.Plastic)
	mk(model, base, "Vent2", V(5, 2.4, 5), CF(-9, 35.2, -18), STEEL, Enum.Material.Plastic)
	mk(model, base, "RoofHouse", V(8, 5, 6), CF(22, 36.5, -14), CREAM)

	-- fabric awning (stripes in the shop colour and cream), valance on its front edge
	for i = 1, 8 do
		local c = if i % 2 == 1 then acc else CREAM
		mk(model, base, "Awning" .. i, V(9, 1.2, 14), CF(-31.5 + 9 * (i - 1), 29, 16) * CFrame.Angles(math.rad(20), 0, 0), c, Enum.Material.Fabric)
		mk(model, base, "Valance" .. i, V(9, 2.2, 0.5), CF(-31.5 + 9 * (i - 1), 24.6, 21.2), c, Enum.Material.Fabric)
	end
	for _, s in { -1, 1 } do
		mk(model, base, "AwningPost", V(2.6, 25, 2.6), CF(s * 34, 13.5, 21.5), STEEL, Enum.Material.Plastic)
		mk(model, base, "PostFoot", V(4.4, 1.4, 4.4), CF(s * 34, 1.7, 21.5), GRAPHITE, Enum.Material.Plastic)
	end

	-- counter: graphite body, accent front panel, wooden top, a card terminal (the only interactive spot)
	mk(model, base, "Counter", V(46, 7, 7), CF(0, 4.5, -3), GRAPHITE)
	mk(model, base, "CounterFront", V(44, 4.4, 0.7), CF(0, 4.2, 0.7), acc)
	mk(model, base, "CounterTop", V(48, 1, 8), CF(0, 8.5, -3), WOOD, Enum.Material.Plastic)
	mk(model, base, "Terminal", V(5, 2.6, 3.4), CF(21.5, 10.3, -3), GRAPHITE)
	mk(model, base, "TerminalScreen", V(3.8, 0.2, 2.2), CF(21.5, 11.7, -3), acc:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.SmoothPlastic, { CanCollide = false })
	local pp = mk(model, base, "PromptPart", V(6, 3, 6), CF(0, 11, -3), acc, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local prompt = Instance.new("ProximityPrompt"); prompt.Name = "ShopPrompt"; prompt.ActionText = "Open"; prompt.ObjectText = def.objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E; prompt.HoldDuration = 0; prompt.RequiresLineOfSight = false; prompt.MaxActivationDistance = 30
	prompt:SetAttribute("ShopKind", kind); prompt.Parent = pp
	CollectionService:AddTag(prompt, "TL_ShopPrompt")
	local shelfY = { 11, 17, 23 }
	for i, y in shelfY do
		mk(model, base, "Shelf" .. i, V(56, 1, 6), CF(0, y, -21.5), WOOD, Enum.Material.Plastic)
		for _, s in { -1, 1 } do mk(model, base, "Bracket", V(1, 3, 5), CF(s * 26, y - 1.6, -21.5), STEEL, Enum.Material.Plastic) end
	end

	-- displays
	if kind == "obstacle" then
		local ids = { "BasicPlatform", "SmallJumpPlatform", "RampUp", "LavaFloor", "SpikePlatform", "RotatingBar" }
		for i, id in ids do
			local ok, m = pcall(ObstacleModels.build, id)
			if ok and m then
				local ext = m:GetExtentsSize()
				m:ScaleTo(math.clamp(5.4 / math.max(ext.X, ext.Z), 0.2, 0.6))
				freeze(m)
				local x = if i % 2 == 1 then -14 else 14
				placeDisplay(m, base:PointToWorldSpace(V(x, shelfY[math.ceil(i / 2)] + 0.5, -21.5)), baseRot)
				m.Name = "Display_" .. id; m.Parent = model
			end
		end
	else
		local ids = { "Starter", "Runner", "Ninja", "Astronaut", "Knight", "Golden" }
		for i, id in ids do
			local def2 = NPCs.ById[id]
			local ok, m = pcall(NPCRig.build, id)
			if ok and m and def2 then
				local hum = m:FindFirstChildOfClass("Humanoid"); if hum then hum:Destroy() end
				m:ScaleTo(2.1)                      -- showcase mannequins stand on the counter, readable from the plaza
				freeze(m)
				local x = -19 + (i - 1) * 7
				mk(model, base, "Pedestal" .. i, V(5.4, 0.8, 5.4), CF(x, 9.4, -3), accDark, Enum.Material.Plastic)
				placeDisplay(m, base:PointToWorldSpace(V(x, 9.8, -3)), baseRot)
				m.Name = "Display_" .. id; m.Parent = model
				local head = m:FindFirstChild("Head")
				if head then
					local bg = Instance.new("BillboardGui"); bg.Size = UDim2.fromOffset(92, 20); bg.StudsOffset = V(0, 2.6, 0); bg.MaxDistance = 36; bg.AlwaysOnTop = false; bg.Adornee = head; bg.Parent = head
					local tl = SignKit.text(bg, { Size = UDim2.fromScale(1, 1), Text = def2.name, TextColor3 = Rarities.Info[def2.rarity].color, Font = SignKit.TITLE })
					local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(20, 22, 28); st.Thickness = 1.5; st.Parent = tl
				end
			end
		end
	end

	-- back-lit sign (lightbox) on two steel posts + a tall beacon to find the shop from across the lobby
	local board = mk(model, base, "SignBoard", V(56, 13, 2.4), CF(0, 46, -14), GRAPHITE)      -- raised above the rooftop units so nothing covers the text
	for _, s in { -1, 1 } do mk(model, base, "SignPost", V(2.6, 15, 2.6), CF(s * 25, 41.5, -14), STEEL, Enum.Material.Plastic) end
	mk(model, base, "SignCap", V(57, 1.2, 3), CF(0, 53.1, -14), acc)
	local _, panel, header = SignKit.panel(board, Enum.NormalId.Back, acc, 20, 0.62)
	SignKit.text(header, { Size = UDim2.fromScale(0.94, 0.84), Position = UDim2.fromScale(0.03, 0.08), Text = def.title, Font = SignKit.TITLE, TextColor3 = Color3.new(1, 1, 1), strokeThickness = 3 })
	SignKit.text(panel, { Size = UDim2.fromScale(0.9, 0.26), Position = UDim2.fromScale(0.05, 0.68), Text = def.sub, TextColor3 = SignKit.OFFWHITE })
	mk(model, base, "BeaconPole", V(3, 70, 3), CF(0, 36, -40), STEEL, Enum.Material.Plastic)
	mk(model, base, "BeaconBase", V(8, 3, 8), CF(0, 1.6, -40), GRAPHITE, Enum.Material.Plastic)
	local gem = mk(model, base, "BeaconGem", V(9, 9, 9), CF(0, 76, -40) * CFrame.Angles(math.rad(45), math.rad(45), 0), acc, Enum.Material.Neon, { CanCollide = false })
	local gl = Instance.new("PointLight"); gl.Color = acc; gl.Range = 70; gl.Brightness = 3; gl.Parent = gem
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(260, 44); bb.StudsOffset = V(0, 9, 0); bb.AlwaysOnTop = true; bb.MaxDistance = 1400; bb.Adornee = gem; bb.Parent = gem
	local bt = SignKit.text(bb, { Size = UDim2.fromScale(1, 1), Text = def.title, TextColor3 = acc, Font = SignKit.TITLE })
	local bst = Instance.new("UIStroke"); bst.Color = Color3.fromRGB(20, 22, 28); bst.Thickness = 2; bst.Parent = bt

	-- dressing: crates, bushes, lamp posts (cosmetic, never collide)
	local CRATE = WOOD:Lerp(CREAM, 0.25)
	for i, c in { { -50, -30, 8 }, { -46, -33, -14 } } do
		mk(model, base, "Crate" .. i, V(3.6, 3.6, 3.6), CF(c[1], 2.8, c[2]) * CFrame.Angles(0, math.rad(c[3]), 0), CRATE, Enum.Material.Plastic)
		mk(model, base, "CrateBand" .. i, V(3.9, 0.7, 3.9), CF(c[1], 2.8, c[2]) * CFrame.Angles(0, math.rad(c[3]), 0), STEEL, Enum.Material.Plastic)
	end
	mk(model, base, "Crate3", V(3.6, 3.6, 3.6), CF(-48.5, 6.2, -31) * CFrame.Angles(0, math.rad(30), 0), CRATE, Enum.Material.Plastic)
	prop(model, base, "Bush", 46, 34, 0, 2.6); prop(model, base, "Bush", 51, 29, 40, 2.2); prop(model, base, "FlowerPatch", -48, 36, 0, 2.8)
	prop(model, base, "Lantern", -48, 40, 0, 2.2); prop(model, base, "Lantern", 48, 40, 0, 2.2); prop(model, base, "Tree", 50, -34, 0, 2.4)

	-- where teleporting players land: in front of the counter, looking at it
	mk(model, base, "Landing", V(6, 0.2, 6), CF(0, 1.2, 26), acc, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	return model
end

function Service.Build(force)
	local wa = workspace:WaitForChild("WorldAssets")
	local folder = wa:FindFirstChild("Shops")
	-- D-038 (session 6): the baked kiosks are the SOURCE OF TRUTH (hand-edited, see the header). A rebuild would silently undo the owner's
	-- rules, so Build(true) refuses while the folder carries HandEdited = true. To really rebuild, pass "overwrite-hand-edits".
	if folder and force and folder:GetAttribute("HandEdited") and force ~= "overwrite-hand-edits" then
		warn("[ShopWorld] Build(true) refused: Shops are hand-edited (D-038). Pass 'overwrite-hand-edits' to rebuild from code.")
		return folder
	end
	if folder and force then folder:Destroy(); folder = nil end
	if not folder then
		folder = Instance.new("Folder"); folder.Name = "Shops"
		for kind, def in SHOPS do buildShop(kind, def).Parent = folder end
		folder.Parent = wa
	end
	return folder
end

-- TeleportToShop { shop = "obstacle" | "npc" }  (the donation shop has none, by design)
function Service.Teleport(player, req)
	if type(req) ~= "table" or (SHOPS[req.shop] == nil and req.shop ~= "home") then return { ok = false, err = "Invalid" } end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return { ok = false, err = "NoCharacter" } end
	local Manual = require(script.Parent.ManualCourseRunService)
	if Manual.Active(player) then return { ok = false, err = "InRun" } end       -- a run is in progress: the teleport would break it
	if req.shop == "home" then      -- top-bar "Home": the server puts the player on THEIR OWN plot (found by OwnerId; the client sends no position)
		local plot
		for _, m in workspace.PlayerPlots:GetChildren() do if m:GetAttribute("OwnerId") == player.UserId then plot = m break end end
		local sp, origin = plot and plot:FindFirstChild("Spawn"), plot and plot:FindFirstChild("Origin")
		if not (sp and origin) then return { ok = false, err = "NoPlot" } end
		local hpos = sp.Position + V(0, 8, 0)
		char:SetAttribute("ServerTeleportAt", os.clock())
		char:PivotTo(CFrame.lookAt(hpos, hpos + origin.CFrame.LookVector))
		hrp.AssemblyLinearVelocity = Vector3.zero
		return { ok = true }
	end
	local shops = workspace:FindFirstChild("WorldAssets") and workspace.WorldAssets:FindFirstChild("Shops")
	local model = shops and shops:FindFirstChild("Shop_" .. req.shop)
	local landing = model and model:FindFirstChild("Landing")
	if not landing then return { ok = false, err = "NoShop" } end
	-- arrive a step back and to the side of the trade ring, facing the counter: the giant (x2) lobby body no longer hides the seller and the
	-- counter from the camera behind it (session 6 player-eyes check). The counter prompt reaches this spot (MaxActivationDistance 32).
	local lcf = landing.CFrame
	local pos = landing.Position + lcf.RightVector * 7 - lcf.LookVector * 5 + V(0, 8, 0)     -- +8: high enough for the giant body
	local focus = landing.Position + lcf.LookVector * 14
	char:SetAttribute("ServerTeleportAt", os.clock())
	char:PivotTo(CFrame.lookAt(pos, Vector3.new(focus.X, pos.Y, focus.Z)))
	hrp.AssemblyLinearVelocity = Vector3.zero
	return { ok = true }
end

function Service.Start()
	Service.Build(false)
	Net.handle("TeleportToShop", require(game:GetService("ReplicatedStorage").Configs.Balance).RateLimits.Teleport, Service.Teleport)   -- audit 4.4
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if CollectionService:HasTag(prompt, "TL_ShopPrompt") then Net.fire("OpenShop", player, prompt:GetAttribute("ShopKind")) end
	end)
end

return Service
