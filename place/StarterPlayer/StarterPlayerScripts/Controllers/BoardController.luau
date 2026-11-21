--!nonstrict
-- D-039 (owner, 2026-11-20): Hall leaderboards show the TOP 100 and scroll up/down (mouse wheel, finger drag).
-- HallService publishes rows on each Board_<id> part (attribute "Rows" = JSON {n, v, u}, "Footer"). This controller draws every board
-- face as a SurfaceGui in PlayerGui with Adornee = board (a SurfaceGui left in Workspace receives no input, so it could not scroll).
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Skin = require(ReplicatedStorage.Shared.BoardSkin)

local BoardController = {}
local player = Players.LocalPlayer

local function fill(refs, board, id)
	local ok, rows = pcall(HttpService.JSONDecode, HttpService, board:GetAttribute("Rows") or "[]")
	if not ok or type(rows) ~= "table" then rows = {} end
	refs.ensure(math.max(#rows, 10))
	local mine
	for i, row in refs.rows do
		local r = rows[i]
		row.Visible = r ~= nil or (i == 1 and #rows == 0)      -- D039-5: no "-" filler rows, one invitation row when the board is empty
		row:FindFirstChild("Name").Text = if r then tostring(r.n) else (if id == "popular" then "No courses yet" else "Be the first!")
		row:FindFirstChild("Value").Text = if r then tostring(r.v) else ""
		if r and r.u == player.UserId then mine = i end
	end
	if id == "popular" then
		refs.you.Text = if mine then ("Your course: #%d"):format(mine) else ""
	else
		refs.you.Text = if mine then ("You: #%d  -  %s"):format(mine, tostring(rows[mine].v)) else "You: not in the top 100 yet"
	end
	refs.footer.Text = board:GetAttribute("Footer") or ""
end

local function bindBoard(board: BasePart, pg: Instance)
	local id = board:GetAttribute("StandId")
	local info = id and Skin.INFO[id]
	if not info then return end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local refs = Skin.buildScroll(board, face, info, pg)
		fill(refs, board, id)
		board:GetAttributeChangedSignal("Rows"):Connect(function() fill(refs, board, id) end)
		board:GetAttributeChangedSignal("Footer"):Connect(function() refs.footer.Text = board:GetAttribute("Footer") or "" end)
	end
end

function BoardController.Start()
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui", 15)
		local wa = workspace:WaitForChild("WorldAssets", 60)
		local hall = wa and wa:WaitForChild("Hall", 60)
		if not (pg and hall) then warn("[Boards] Hall or PlayerGui not found - scrolling boards disabled"); return end
		for _, c in hall:GetChildren() do
			if c:IsA("BasePart") and c.Name:sub(1, 6) == "Board_" then bindBoard(c, pg) end
		end
	end)
end

return BoardController
