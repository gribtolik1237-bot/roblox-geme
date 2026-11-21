--!nonstrict
-- Four two-sided leaderboard stands in the market courtyard.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Net = require(ReplicatedStorage.Shared.Net)
local SignKit = require(ReplicatedStorage.Shared.SignKit)
local Skin = require(ReplicatedStorage.Shared.BoardSkin)
local Leaderboard = require(script.Parent.LeaderboardService)

local Promenade = require(game:GetService("ServerStorage").WorldRecipes.LobbyPromenade)

local Hall = {}
local V, CF = Vector3.new, CFrame.new
local mk = SignKit.mk
local INNER = Color3.fromRGB(46, 36, 42)

local STANDS = {   -- title/sub/colour live in BoardSkin.INFO
	{ id = "money", x = -75 },
	{ id = "rebirths", x = -25 },
	{ id = "popular", x = 25 },   -- owner request: Popular lives in the Hall (no HUD tile)
	{ id = "obby", x = 75 },
}
for _, st in STANDS do for k, v in Skin.INFO[st.id] do st[k] = v end end

local buildFace = Skin.build

local stands = {}    -- id -> { faces = { refs, refs } }

local function short(n)
	if n >= 1e9 then return ("%.1fB"):format(n / 1e9) elseif n >= 1e6 then return ("%.1fM"):format(n / 1e6) elseif n >= 1e4 then return ("%.1fK"):format(n / 1e3) end
	return tostring(n)
end

-- D-039: the boards are TOP 100 and scroll, so clients draw them (BoardController, SurfaceGui in PlayerGui). The server only publishes the
-- rows on the board part: attribute "Rows" = JSON { {n = name, v = shown value, u = userId}, ... } in rank order, "Footer" = status line.
local function publish(id: string, rows: { any }, footer: string)
	local board = stands[id] and stands[id].board
	if not board then return end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, rows)
	if ok then board:SetAttribute("Rows", json) end
	board:SetAttribute("Footer", footer)
end

local function renderBoard(id)
	local res = Leaderboard.Fetch(id)
	local rows = {}
	for i, r in res.rows do rows[i] = { n = r.name, v = short(r.value), u = r.userId } end
	publish(id, rows, if res.source == "global" then "top 100 worldwide - scroll" else "this server only - scroll")
end

-- POPULAR: courses of the players online now (Leaderboard.Popular, same score as TOP OBBY): name, owner, shown rating
local function renderPopular()
	local list = Leaderboard.Popular()
	local rows = {}
	for i, c in list do rows[i] = { n = c.name .. "  -  " .. c.owner, v = if c.votes > 0 then ("%.1f (%d)"):format(c.rating, c.votes) else "new", u = c.ownerId } end
	publish("popular", rows, if #list > 0 then "online now - press E to visit" else "no courses online yet - build one!")
end

-- a two-tone studded paved plaza (8x8 tiles) under the whole hall, with a darker curb
local function plaza(model)
	local T = 8
	local HALF = 104          -- four stands at 50-stud spacing
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
	if st.id == "popular" then
		local pp = mk(model, "PromptPart", V(6, 3, 6), CF(x, 5.5, 0), c, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local prompt = Instance.new("ProximityPrompt"); prompt.ActionText = "Open"; prompt.ObjectText = "Popular Courses"; prompt.HoldDuration = 0
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
	Promenade.PlaceHall(model)
	return model
end

function Hall.Start()
	local model = Hall.Build(false)
	for _, st in STANDS do
		local board = model:FindFirstChild("Board_" .. st.id)
		stands[st.id] = { board = board }
		-- D-039: the baked 10-row faces are replaced at runtime by the clients' scrolling top-100 faces (BoardController)
		for _, face in { "Front", "Back" } do
			local g = board:FindFirstChild("Face_" .. face)
			if g then g:Destroy() end
		end
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if CollectionService:HasTag(prompt, "TL_BoardPrompt") then Net.fire("OpenBoard", player, prompt:GetAttribute("Board")) end
	end)
	task.spawn(function()
		while true do
			for _, id in Leaderboard.Kinds do pcall(renderBoard, id) end
			pcall(renderPopular)
			task.wait(30)
		end
	end)
end

return Hall
