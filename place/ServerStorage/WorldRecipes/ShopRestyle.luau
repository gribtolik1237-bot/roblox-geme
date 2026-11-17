-- Audit 3.1 (session 8): reproducible restyle of the two kiosks in Workspace.WorldAssets.Shops. Idempotent: run again any time
-- (Edit, command bar: require(game.ServerStorage.WorldRecipes.ShopRestyle).Run()). Owner rules kept: NO wood, palette red posts /
-- navy beams / yellow rails, neon only on the sign, screen, beacon gem, trade ring and the awning bulbs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Obstacles = require(ReplicatedStorage.Configs.Obstacles)

local R = {}
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local STYLE = {
	obstacle = { title = "OBSTACLE SHOP", accent = rgb(34, 190, 200), roof = rgb(64, 156, 255), floor = rgb(255, 222, 120), stripe2 = rgb(255, 255, 255) },
	npc = { title = "NPC SHOP", accent = rgb(150, 100, 240), roof = rgb(255, 89, 89), floor = rgb(255, 222, 120), stripe2 = rgb(255, 255, 255) },
}
local BULBS = { rgb(255, 214, 90), rgb(255, 120, 90), rgb(120, 230, 255), rgb(140, 255, 140) }

local function each(model, pattern, fn)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match(pattern) then fn(d) end
	end
end

local function restyle(shop)
	local kind = shop:GetAttribute("ShopKind")
	local S = STYLE[kind]
	if not S then return "skip " .. shop.Name end
	for _, n in { "Garland", "PriceTags", "KioskLight" } do local o = shop:FindFirstChild(n) if o then o:Destroy() end end
	local own = {}  -- only the kiosk's OWN parts (not the shopkeeper rig / props / product displays)
	for _, d in shop:GetChildren() do if d:IsA("BasePart") then own[#own + 1] = d end end
	local function ownEach(pattern, fn) for _, p in own do if p.Name:match(pattern) then fn(p) end end end
	-- a) materials by meaning
	ownEach("^Floor$", function(p) p.Material = Enum.Material.SmoothPlastic; p.Color = S.floor end)
	ownEach("^Roof$", function(p) p.Material = Enum.Material.Fabric; p.Color = S.roof end)
	ownEach("^Fascia$", function(p) p.Material = Enum.Material.Fabric; p.Color = S.roof:Lerp(rgb(0, 0, 0), 0.15) end)
	ownEach("^Awning%d+$", function(p)
		local i = tonumber(p.Name:match("%d+$")) or 1
		p.Material = Enum.Material.Fabric; p.Color = if i % 2 == 1 then S.accent else S.stripe2
	end)
	ownEach("^Valance%d+$", function(p)
		local i = tonumber(p.Name:match("%d+$")) or 1
		p.Material = Enum.Material.Fabric; p.Color = if i % 2 == 1 then S.accent else S.stripe2
	end)
	for _, pat in { "^Column$", "^AwningPost$", "^SignPost$", "^BeaconPole$", "^Bracket" } do
		ownEach(pat, function(p) p.Material = Enum.Material.Metal; p.Color = rgb(206, 58, 50) end)      -- painted metal, owner red
	end
	ownEach("^Shelf%d*$", function(p) p.Material = Enum.Material.Glass; p.Color = rgb(200, 240, 255); p.Transparency = 0.25 end)   -- glass shelves
	ownEach("Plinth$", function(p) p.Material = Enum.Material.Marble; p.Color = rgb(244, 244, 250) end)                        -- marble podiums
	-- b) neon accents (interaction / identity only) + a warm light inside
	ownEach("^SignBoard$", function(p) p.Material = Enum.Material.Neon; p.Color = rgb(40, 50, 100) end)
	ownEach("^SignCap$", function(p) p.Material = Enum.Material.Neon; p.Color = S.accent end)
	ownEach("^TerminalScreen$", function(p) p.Material = Enum.Material.Neon; p.Color = S.accent end)
	ownEach("^BeaconGem$", function(p) p.Material = Enum.Material.Neon; p.Color = S.accent end)
	ownEach("^TradeRing$", function(p) p.Material = Enum.Material.Neon; p.Color = S.accent end)
	local roof = shop:FindFirstChild("Roof")
	local floor = shop:FindFirstChild("Floor")
	if roof and floor then
		local holder = Instance.new("Part")
		holder.Name = "KioskLight"; holder.Anchored = true; holder.CanCollide = false; holder.CanQuery = false; holder.CanTouch = false
		holder.Transparency = 1; holder.Size = Vector3.new(1, 1, 1)
		holder.CFrame = CFrame.new((roof.Position + floor.Position) / 2)
		local l = Instance.new("PointLight"); l.Color = rgb(255, 205, 150); l.Range = 26; l.Brightness = 1.6; l.Shadows = false; l.Parent = holder
		holder.Parent = shop
	end
	-- d) garland: one neon bulb under each valance strip
	local gar = Instance.new("Folder"); gar.Name = "Garland"
	local vals = {}
	ownEach("^Valance%d+$", function(p) vals[#vals + 1] = p end)
	table.sort(vals, function(a, b) return (tonumber(a.Name:match("%d+$")) or 0) < (tonumber(b.Name:match("%d+$")) or 0) end)
	for i, v in vals do
		local b = Instance.new("Part")
		b.Name = "Bulb" .. i; b.Shape = Enum.PartType.Ball; b.Size = Vector3.new(0.9, 0.9, 0.9)
		b.Material = Enum.Material.Neon; b.Color = BULBS[(i - 1) % #BULBS + 1]
		b.Anchored = true; b.CanCollide = false; b.CanQuery = false; b.CanTouch = false; b.CastShadow = false
		b.CFrame = v.CFrame * CFrame.new(0, -v.Size.Y / 2 - 0.5, 0)
		b.Parent = gar
	end
	gar.Parent = shop
	-- front direction of the kiosk (counter -> customer landing)
	local counter, landing = shop:FindFirstChild("Counter"), shop:FindFirstChild("Landing")
	local front = Vector3.new(0, 0, -1)
	if counter and landing then
		local d = landing.Position - counter.Position
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 0.1 then front = d.Unit end
	end
	-- d) sign title on the SignBoard face that looks at the customers
	local board = shop:FindFirstChild("SignBoard")
	local old = board and board:FindFirstChild("TitleGui")
	if old then old:Destroy() end
	local hasTitle = false     -- the baked sign usually already carries its own title SurfaceGui: never draw a second one
	if board then for _, g in board:GetChildren() do if g:IsA("SurfaceGui") then hasTitle = true end end end
	if board and not hasTitle then
		local face = if board.CFrame.LookVector:Dot(front) >= 0 then Enum.NormalId.Front else Enum.NormalId.Back
		local sg = board:FindFirstChild("TitleGui") or Instance.new("SurfaceGui")
		sg.Name = "TitleGui"; sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40
		sg.LightInfluence = 0; sg.MaxDistance = 600
		sg:ClearAllChildren()
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(0.94, 0.86); t.Position = UDim2.fromScale(0.03, 0.07)
		t.Font = Enum.Font.FredokaOne; t.TextScaled = true; t.Text = S.title; t.TextColor3 = rgb(255, 255, 255)
		local st = Instance.new("UIStroke"); st.Thickness = 10; st.Color = rgb(14, 10, 18); st.Parent = t
		t.Parent = sg
		sg.Parent = board
	end
	-- d) price tags over each product display (obstacle kiosk only: the NPC kiosk shows its goods in the window)
	local tags = Instance.new("Folder"); tags.Name = "PriceTags"
	for _, m in shop:GetChildren() do
		local id = m:IsA("Model") and m.Name:match("^Display_(.+)$")
		local def = id and Obstacles.ById[id]
		if def then
			local cf, size = m:GetBoundingBox()
			local top = cf.Position + Vector3.new(0, size.Y / 2 + 1.3, 0)
			local tag = Instance.new("Part")
			tag.Name = "Tag_" .. id; tag.Size = Vector3.new(4.6, 1.7, 0.2); tag.Anchored = true; tag.CanCollide = false; tag.CanQuery = false; tag.CanTouch = false
			tag.Material = Enum.Material.SmoothPlastic; tag.Color = rgb(255, 255, 255)
			tag.CFrame = CFrame.lookAt(top, top + front)
			local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 60
			sg.LightInfluence = 0; sg.MaxDistance = 120
			local bar = Instance.new("Frame"); bar.Size = UDim2.fromScale(1, 0.42); bar.BackgroundColor3 = rgb(46, 58, 110); bar.BorderSizePixel = 0; bar.Parent = sg
			local n = Instance.new("TextLabel"); n.BackgroundTransparency = 1; n.Size = UDim2.fromScale(0.94, 1); n.Position = UDim2.fromScale(0.03, 0)
			n.Font = Enum.Font.FredokaOne; n.TextScaled = true; n.Text = def.name; n.TextColor3 = rgb(255, 255, 255); n.Parent = bar
			local p = Instance.new("TextLabel"); p.BackgroundTransparency = 1; p.Size = UDim2.fromScale(0.94, 0.52); p.Position = UDim2.fromScale(0.03, 0.45)
			p.Font = Enum.Font.FredokaOne; p.TextScaled = true; p.TextColor3 = rgb(40, 150, 40)
			p.Text = if def.free then "FREE" else (tostring(def.price) .. " Coins")
			p.Parent = sg
			sg.Parent = tag
			local fr = Instance.new("SelectionBox")    -- thin dark frame around the tag (ink outline like the UI)
			fr.Adornee = tag; fr.LineThickness = 0.06; fr.Color3 = rgb(14, 10, 18); fr.SurfaceTransparency = 1; fr.Parent = tag
			tag.Parent = tags
		end
	end
	tags.Parent = shop
	-- c) display identities: lava basin cracked lava, spikes metal (already metal); stone glow neon (already)
	local lava = shop:FindFirstChild("Display_LavaFloor")
	if lava then each(lava, "^Basin$", function(p) p.Material = Enum.Material.CrackedLava; p.Color = rgb(120, 40, 20) end) end
	local spk = shop:FindFirstChild("Display_SpikePlatform")
	if spk then each(spk, "^Spike%d*$", function(p) p.Material = Enum.Material.Metal end) end
	-- no wood anywhere (owner rule): the decorative tree trunk becomes plastic
	each(shop, "^Trunk$", function(p) if p.Material == Enum.Material.Wood or p.Material == Enum.Material.WoodPlanks then p.Material = Enum.Material.Plastic end end)
	-- e) PrimaryPart
	local plaza = shop:FindFirstChild("Plaza") or floor
	if plaza then shop.PrimaryPart = plaza end
	return shop.Name .. " ok"
end

function R.Run()
	local out = {}
	for _, shop in workspace.WorldAssets.Shops:GetChildren() do
		if shop:IsA("Model") then out[#out + 1] = restyle(shop) end
	end
	return table.concat(out, "; ")
end

return R
