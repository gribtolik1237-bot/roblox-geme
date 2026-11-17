--!nonstrict
-- The lobby "hall": three leaderboard stands (TOP MONEY / TOP REBIRTHS / TOP OBBY) and the Daily Challenges stand, in the middle of the lobby
-- aisle. Look (docs/ART_DIRECTION.md, "Etalony"): chunky wooden stands with a coloured studded frame, a dark list with medal ranks and fat outlined
-- text, standing on a two-tone studded paved plaza. Boards are two-sided SurfaceGuis (players arrive from both plot rows) re-rendered by the server.
-- Built for the giant lobby avatar (x2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local SignKit = require(ReplicatedStorage.Shared.SignKit)
local Leaderboard = require(script.Parent.LeaderboardService)
local Daily = require(script.Parent.DailyService)

local Hall = {}
local V, CF = Vector3.new, CFrame.new
local mk = SignKit.mk
local INNER, ROW_A, ROW_B = Color3.fromRGB(46, 36, 42), Color3.fromRGB(82, 66, 72), Color3.fromRGB(66, 52, 58)
local PLACE = { Color3.fromRGB(255, 196, 61), Color3.fromRGB(214, 222, 236), Color3.fromRGB(226, 140, 74) }   -- gold, silver, bronze

local STANDS = {
	{ id = "money", x = -100, title = "TOP MONEY", sub = "most Coins right now", color = Color3.fromRGB(255, 190, 48) },
	{ id = "rebirths", x = -50, title = "TOP REBIRTHS", sub = "most Rebirths", color = Color3.fromRGB(160, 120, 255) },
	{ id = "popular", x = 0, title = "POPULAR COURSES", sub = "online now - press E to visit", color = Color3.fromRGB(255, 120, 60) },   -- owner request: Popular lives in the Hall (no HUD tile)
	{ id = "obby", x = 50, title = "TOP OBBY", sub = "best course creators", color = Color3.fromRGB(40, 196, 214) },
	{ id = "daily", x = 100, title = "DAILY CHALLENGES", sub = "", color = Color3.fromRGB(80, 206, 96) },
}

local function text(parent, name, props)
	props.Name = name
	return SignKit.text(parent, props)
end

local function corner(inst, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = inst end

-- one face of a stand: title, subtitle, 10 rows (leaderboards) or 3 challenge rows (daily), footer
local function buildFace(board, face, stand)
	local g = Instance.new("SurfaceGui"); g.Name = "Face_" .. face.Name; g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30; g.LightInfluence = 0; g.Brightness = 1.1; g.Parent = board
	local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = INNER; bg.BorderSizePixel = 0; bg.Parent = g
	local bar = Instance.new("Frame"); bar.Name = "Bar"; bar.Size = UDim2.fromScale(1, 0.19); bar.BackgroundColor3 = stand.color; bar.BorderSizePixel = 0; bar.Parent = bg
	text(bar, "Title", { Size = UDim2.fromScale(0.94, 0.7), Position = UDim2.fromScale(0.03, 0.03), Text = stand.title, Font = SignKit.TITLE, TextColor3 = Color3.new(1, 1, 1), strokeThickness = 5 })
	local sub = text(bar, "Sub", { Size = UDim2.fromScale(0.94, 0.22), Position = UDim2.fromScale(0.03, 0.75), Text = stand.sub, TextColor3 = SignKit.INK, noStroke = true })
	local refs = { sub = sub, rows = {} }
	if stand.id == "daily" then
		for i, id in Balance.Daily.Order do
			local t = Balance.Daily[id]
			local y = 0.215 + (i - 1) * 0.225
			local row = Instance.new("Frame"); row.Size = UDim2.fromScale(0.94, 0.205); row.Position = UDim2.fromScale(0.03, y); row.BackgroundColor3 = ROW_A; row.BorderSizePixel = 0; row.Parent = bg
			corner(row, 12)
			text(row, "Name", { Size = UDim2.fromScale(0.52, 0.46), Position = UDim2.fromScale(0.03, 0.06), Text = (id == "SuperHard" and "SUPER HARD" or id:upper()) .. " - " .. t.title, Font = SignKit.TITLE, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = stand.color, strokeThickness = 3.5 })
			text(row, "Mult", { Size = UDim2.fromScale(0.4, 0.46), Position = UDim2.fromScale(0.57, 0.06), Text = ("x%d Coins - %d min"):format(t.mult, t.minutes), Font = SignKit.TITLE, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = PLACE[1], strokeThickness = 3.5 })
			local goal = ("Clear %d course%s%s%s"):format(t.goalRuns, t.goalRuns > 1 and "s" or "", t.minDifficulty > 1 and (" (" .. Balance.DifficultyOrder[t.minDifficulty] .. "+)") or "", t.othersOnly and " of other players" or "")
			text(row, "Goal", { Size = UDim2.fromScale(0.94, 0.34), Position = UDim2.fromScale(0.03, 0.58), Text = goal, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SignKit.CREAM, strokeThickness = 2.5 })
		end
		refs.footer = text(bg, "Footer", { Size = UDim2.fromScale(0.94, 0.06), Position = UDim2.fromScale(0.03, 0.91), Text = "", TextColor3 = SignKit.MUTED, noStroke = true })
	else
		for i = 1, Balance.Boards.Size do
			local row = Instance.new("Frame"); row.Size = UDim2.fromScale(0.94, 0.068); row.Position = UDim2.fromScale(0.03, 0.208 + (i - 1) * 0.0715)
			row.BackgroundColor3 = if PLACE[i] then PLACE[i]:Lerp(INNER, 0.6) else (if i % 2 == 0 then ROW_A else ROW_B); row.BorderSizePixel = 0; row.Parent = bg
			corner(row, 9)
			local rank = text(row, "Rank", { Size = UDim2.fromScale(0.3, 0.86), Position = UDim2.fromScale(0.012, 0.07), Text = tostring(i), Font = SignKit.TITLE,
				TextColor3 = if PLACE[i] then SignKit.INK else SignKit.MUTED, BackgroundTransparency = if PLACE[i] then 0 else 1, BackgroundColor3 = PLACE[i] or INNER, noStroke = PLACE[i] ~= nil, strokeThickness = 2.5 })
			local ar = Instance.new("UIAspectRatioConstraint"); ar.AspectRatio = 1; ar.DominantAxis = Enum.DominantAxis.Height; ar.Parent = rank
			corner(rank, 100)
			text(row, "Name", { Size = UDim2.fromScale(0.55, 0.76), Position = UDim2.fromScale(0.1, 0.12), Text = "-", Font = SignKit.TITLE, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if PLACE[i] then Color3.new(1, 1, 1) else SignKit.CREAM, strokeThickness = 3 })
			text(row, "Value", { Size = UDim2.fromScale(0.3, 0.76), Position = UDim2.fromScale(0.67, 0.12), Text = "", Font = SignKit.TITLE, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = PLACE[i] or stand.color, strokeThickness = 3 })
			refs.rows[i] = row
		end
		refs.footer = text(bg, "Footer", { Size = UDim2.fromScale(0.94, 0.04), Position = UDim2.fromScale(0.03, 0.955), Text = "", TextColor3 = SignKit.MUTED, noStroke = true })
	end
	return refs
end

local stands = {}    -- id -> { faces = { refs, refs } }

local function short(n)
	if n >= 1e9 then return ("%.1fB"):format(n / 1e9) elseif n >= 1e6 then return ("%.1fM"):format(n / 1e6) elseif n >= 1e4 then return ("%.1fK"):format(n / 1e3) end
	return tostring(n)
end

local function renderBoard(id)
	local res = Leaderboard.Fetch(id)
	for _, refs in stands[id].faces do
		for i, row in refs.rows do
			local r = res.rows[i]
			row:FindFirstChild("Name").Text = if r then r.name else "-"      -- (row.Name would be the Instance name, not the label)
			row:FindFirstChild("Value").Text = if r then short(r.value) else ""
		end
		refs.footer.Text = if res.source == "global" then "worldwide - updates every minute" else "this server only (global list unavailable)"
	end
end

-- POPULAR: courses of the players online now (Leaderboard.Popular, same score as TOP OBBY): name, owner, shown rating
local function renderPopular()
	local list = Leaderboard.Popular()
	for _, refs in stands.popular.faces do
		for i, row in refs.rows do
			local c = list[i]
			row:FindFirstChild("Name").Text = if c then (c.name .. "  -  " .. c.owner) else "-"
			row:FindFirstChild("Value").Text = if c then (if c.votes > 0 then ("%.1f (%d)"):format(c.rating, c.votes) else "new") else ""
		end
		refs.footer.Text = if #list > 0 then "online now - press E to visit a course" else "no finished courses online yet - build one!"
	end
end

local function renderDaily()
	local s = Daily.SecondsToReset()
	for _, refs in stands.daily.faces do
		refs.footer.Text = ("New challenges in %dh %02dm (UTC midnight) - press E to open"):format(math.floor(s / 3600), math.floor(s % 3600 / 60))
	end
end

-- a two-tone studded paved plaza (8x8 tiles) under the whole hall, with a darker curb
local function plaza(model)
	local T = 8
	local HALF = 128          -- five stands at 50-stud spacing
	local SAND_DEEPER = SignKit.SAND:Lerp(Color3.new(0, 0, 0), 0.2)   -- audit B: readable checkerboard (SAND_DARK was only ~9% off SAND)
	for cx = 0, HALF * 2 / T - 1 do
		for cz = 0, 5 do
			local c = if (cx + cz) % 2 == 0 then SignKit.SAND else SAND_DEEPER
			-- audit 3.3: grid names (row = cz, column = cx, 1-based) instead of 192 identical "Tile"
			mk(model, ("Tile_R%dC%d"):format(cz + 1, cx + 1), V(T, 0.6, T), CF(-HALF + T / 2 + cx * T, 0.3, -24 + T / 2 + cz * T), c, nil, { studs = true })
		end
	end
	mk(model, "CurbN", V(HALF * 2 + 4, 1.0, 2.4), CF(0, 0.5, 25.2), SignKit.WOOD_DARK, nil, { studs = true })
	mk(model, "CurbS", V(HALF * 2 + 4, 1.0, 2.4), CF(0, 0.5, -25.2), SignKit.WOOD_DARK, nil, { studs = true })
	for _, s in { -1, 1 } do mk(model, "CurbE", V(2.4, 1.0, 52.8), CF(s * (HALF + 1.2), 0.5, 0), SignKit.WOOD_DARK, nil, { studs = true }) end
end

local function buildStand(model, st)
	local x, c = st.x, st.color
	mk(model, "PlinthLow_" .. st.id, V(52, 1.6, 11), CF(x, 1.4, 0), SignKit.SAND_DARK, nil, { studs = true })
	mk(model, "Plinth_" .. st.id, V(46, 1.6, 9), CF(x, 3.0, 0), SignKit.SAND, nil, { studs = true })
	for _, s in { -1, 1 } do
		mk(model, "PostFoot", V(4.8, 1.2, 4.8), CF(x + s * 22.2, 4.4, 0), SignKit.WOOD_DARK, nil, { studs = true })
		mk(model, "Post", V(3, 31, 3), CF(x + s * 22.2, 20.5, 0), SignKit.WOOD, Enum.Material.Plastic)
	end
	local board = mk(model, "Board_" .. st.id, V(36, 22, 2), CF(x, 21.5, 0), INNER)
	board:SetAttribute("StandId", st.id)
	-- frame in the stand colour: top/bottom bars stand proud of the board (depth), side bars close to the posts
	mk(model, "FrameTop_" .. st.id, V(44, 2.6, 3.8), CF(x, 33.8, 0), c, nil, { studs = true })
	mk(model, "FrameBottom_" .. st.id, V(44, 2.6, 3.8), CF(x, 9.2, 0), c, nil, { studs = true })
	for _, s in { -1, 1 } do mk(model, "FrameSide", V(2.8, 27.2, 3.8), CF(x + s * 19.4, 21.5, 0), c, nil, { studs = true }) end
	-- cap beam over the posts with three lamps (small functional light accents)
	mk(model, "Cap_" .. st.id, V(50, 2.2, 4.4), CF(x, 36.9, 0), SignKit.WOOD_DARK, nil, { studs = true })
	for i = -1, 1 do mk(model, "Lamp", V(2, 1.4, 2), CF(x + i * 12, 38.6, 0), Color3.fromRGB(255, 236, 190), Enum.Material.Neon, { CanCollide = false }) end
	buildFace(board, Enum.NormalId.Front, st); buildFace(board, Enum.NormalId.Back, st)
	if st.id == "daily" or st.id == "popular" then
		local pp = mk(model, "PromptPart", V(6, 3, 6), CF(x, 5.5, 0), c, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local prompt = Instance.new("ProximityPrompt"); prompt.ActionText = "Open"; prompt.ObjectText = if st.id == "daily" then "Daily Challenges" else "Popular Courses"; prompt.HoldDuration = 0
		prompt.KeyboardKeyCode = Enum.KeyCode.E; prompt.RequiresLineOfSight = false; prompt.MaxActivationDistance = 30; prompt.Parent = pp
		prompt:SetAttribute("Board", st.id); CollectionService:AddTag(prompt, "TL_BoardPrompt")
	end
end

function Hall.Build(force)
	local wa = workspace:WaitForChild("WorldAssets")
	local model = wa:FindFirstChild("Hall")
	if model and force then model:Destroy(); model = nil end
	if not model then
		model = Instance.new("Model"); model.Name = "Hall"
		plaza(model)
		for _, st in STANDS do buildStand(model, st) end
		model.Parent = wa
	end
	return model
end

function Hall.Start()
	local model = Hall.Build(false)
	for _, st in STANDS do
		local board = model:FindFirstChild("Board_" .. st.id)
		stands[st.id] = { faces = {} }
		-- bound faces: the GUIs are already in the baked model; rebind their labels
		for _, face in { "Front", "Back" } do
			local g = board:FindFirstChild("Face_" .. face)
			local refs = { rows = {}, footer = g.Frame:FindFirstChild("Footer") }
			for _, c in g.Frame:GetChildren() do
				if c:IsA("Frame") and c:FindFirstChild("Rank") then refs.rows[#refs.rows + 1] = c end
			end
			table.sort(refs.rows, function(a, b) return a.Position.Y.Scale < b.Position.Y.Scale end)
			table.insert(stands[st.id].faces, refs)
		end
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if CollectionService:HasTag(prompt, "TL_BoardPrompt") then Net.fire("OpenBoard", player, prompt:GetAttribute("Board")) end
	end)
	task.spawn(function()
		local n = 0
		while true do
			for _, id in Leaderboard.Kinds do pcall(renderBoard, id) end
			pcall(renderDaily)
			pcall(renderPopular)
			n += 1
			task.wait(30)
		end
	end)
end

return Hall
