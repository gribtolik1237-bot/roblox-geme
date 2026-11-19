--!nonstrict
-- Leaderboard face skin: navy plastic panel, fat header in the stand colour, rounded rows with medal badges.
-- HallService builds new faces with it; the same call restyles baked boards (destroy Face_*, Skin.build again).
-- Row contract for HallService.Start: bg Frame ("Frame") holds Bar, the rows (Frames that contain "Rank"/"Name"/"Value") and Footer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local SignKit = require(script.Parent.SignKit)

local Skin = {}
local rgb = Color3.fromRGB
local NAVY, NAVY_TOP = rgb(30, 36, 84), rgb(54, 64, 128)
local ROW_A, ROW_B = rgb(64, 76, 148), rgb(50, 60, 122)
local PLACE = { rgb(255, 196, 61), rgb(214, 222, 236), rgb(226, 140, 74) }   -- gold, silver, bronze
local CREAM, INK, WHITE = SignKit.CREAM, SignKit.INK, Color3.new(1, 1, 1)

Skin.INFO = {
	money = { title = "TOP MONEY", sub = "most Coins right now", color = rgb(255, 190, 48) },
	rebirths = { title = "TOP REBIRTHS", sub = "most Rebirths", color = rgb(160, 120, 255) },
	popular = { title = "POPULAR COURSES", sub = "online now - press E to visit", color = rgb(255, 120, 60) },
	obby = { title = "TOP OBBY", sub = "best course creators", color = rgb(40, 196, 214) },
}

local function corner(inst, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = inst end
local function stroke(inst, color, thick) local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thick; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.LineJoinMode = Enum.LineJoinMode.Round; s.Parent = inst end
local function gradient(inst, a, b, rot) local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(a, b); g.Rotation = rot; g.Parent = inst end
local function text(parent, name, props) props.Name = name; return SignKit.text(parent, props) end

-- One face of a stand: heading, ranked rows and a footer. Returns { sub, rows, footer }.
function Skin.build(board: BasePart, face: Enum.NormalId, stand)
	local g = Instance.new("SurfaceGui"); g.Name = "Face_" .. face.Name; g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30; g.LightInfluence = 0; g.Brightness = 1.1; g.Parent = board
	local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = NAVY; bg.BorderSizePixel = 0; bg.Parent = g
	gradient(bg, NAVY_TOP, NAVY, 90)

	local bar = Instance.new("Frame"); bar.Name = "Bar"; bar.Size = UDim2.fromScale(0.96, 0.2); bar.Position = UDim2.fromScale(0.02, 0.016)
	bar.BackgroundColor3 = stand.color; bar.BorderSizePixel = 0; bar.Parent = bg
	corner(bar, 26); stroke(bar, INK, 5); gradient(bar, stand.color:Lerp(WHITE, 0.3), stand.color, 90)
	text(bar, "Title", { Size = UDim2.fromScale(0.94, 0.66), Position = UDim2.fromScale(0.03, 0.04), Text = stand.title, Font = SignKit.TITLE, TextColor3 = WHITE, strokeThickness = 6 })
	local sub = text(bar, "Sub", { Size = UDim2.fromScale(0.94, 0.24), Position = UDim2.fromScale(0.03, 0.72), Text = stand.sub, Font = SignKit.TITLE, TextColor3 = INK, noStroke = true })

	local refs = { sub = sub, rows = {} }
	local top, h, gap = 0.235, 0.0655, 0.0045
	for i = 1, Balance.Boards.Size do
		local medal = PLACE[i]
		local row = Instance.new("Frame"); row.Size = UDim2.fromScale(0.96, h); row.Position = UDim2.fromScale(0.02, top + (i - 1) * (h + gap))
		row.BackgroundColor3 = if medal then medal:Lerp(NAVY, 0.5) else (if i % 2 == 0 then ROW_A else ROW_B); row.BorderSizePixel = 0; row.Parent = bg
		corner(row, 14)
		if medal then stroke(row, medal, 3) end
		local rank = text(row, "Rank", { Size = UDim2.fromScale(0.3, 0.84), Position = UDim2.fromScale(0.012, 0.08), Text = tostring(i), Font = SignKit.TITLE,
			TextColor3 = if medal then INK else CREAM, BackgroundTransparency = 0, BackgroundColor3 = medal or NAVY_TOP, noStroke = medal ~= nil, strokeThickness = 2.5 })
		local ar = Instance.new("UIAspectRatioConstraint"); ar.AspectRatio = 1; ar.DominantAxis = Enum.DominantAxis.Height; ar.Parent = rank
		corner(rank, 100)
		text(row, "Name", { Size = UDim2.fromScale(0.55, 0.84), Position = UDim2.fromScale(0.1, 0.08), Text = "-", Font = SignKit.TITLE, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if medal then WHITE else CREAM, strokeThickness = 3 })
		text(row, "Value", { Size = UDim2.fromScale(0.3, 0.84), Position = UDim2.fromScale(0.67, 0.08), Text = "", Font = SignKit.TITLE, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = medal or stand.color:Lerp(WHITE, 0.3), strokeThickness = 3 })
		refs.rows[i] = row
	end
	refs.footer = text(bg, "Footer", { Size = UDim2.fromScale(0.94, 0.04), Position = UDim2.fromScale(0.03, 0.948), Text = "", Font = SignKit.BODY, TextColor3 = SignKit.MUTED, noStroke = true })
	return refs
end

-- Restyle the baked boards of a Hall model in place (labels are rebound by HallService.Start).
function Skin.restyle(hall: Model)
	for id, info in Skin.INFO do
		local board = hall:FindFirstChild("Board_" .. id)
		if board then
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local old = board:FindFirstChild("Face_" .. face.Name)
				if old then old:Destroy() end
				Skin.build(board, face, info)
			end
		end
	end
end

return Skin
