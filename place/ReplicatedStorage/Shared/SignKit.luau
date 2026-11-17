--!nonstrict
-- Shared look for every world sign / board AND the world palette (see docs/ART_DIRECTION.md, section "Etalony"): a bright brick-toy test range.
-- Chunky wooden frames, studded plastic, fat Builder Sans text with a dark outline (readable on any background), small hazard edges only.
-- Light on signs is functional (LightInfluence = 0 keeps them readable in shade). No neon trims, no glossy gradients.
local SignKit = {}
SignKit.GRAPHITE = Color3.fromRGB(44, 40, 46)
SignKit.PANEL = Color3.fromRGB(62, 52, 58)
SignKit.OFFWHITE = Color3.fromRGB(252, 248, 238)
SignKit.YELLOW = Color3.fromRGB(255, 196, 40)
SignKit.MUTED = Color3.fromRGB(214, 200, 188)
SignKit.INK = Color3.fromRGB(34, 26, 28)           -- text outline / dark lines
SignKit.CREAM = Color3.fromRGB(248, 238, 212)
SignKit.WOOD = Color3.fromRGB(206, 58, 50)         -- NO WOOD (owner rule D-030/D-034): WOOD* names are historical; they are coloured plastic: red posts, navy beams/bases, yellow frames/rails
SignKit.WOOD_DARK = Color3.fromRGB(46, 58, 110)
SignKit.WOOD_LIGHT = Color3.fromRGB(255, 200, 44)
SignKit.SAND = Color3.fromRGB(236, 212, 158)       -- paving
SignKit.SAND_DARK = Color3.fromRGB(214, 186, 128)
SignKit.GRASS = Color3.fromRGB(100, 190, 78)
SignKit.WATER = Color3.fromRGB(58, 172, 198)
SignKit.TITLE = Enum.Font.BuilderSansExtraBold
SignKit.BODY = Enum.Font.BuilderSansBold

function SignKit.stroke(label, color, thick)
	local s = Instance.new("UIStroke"); s.Color = color or SignKit.INK; s.Thickness = thick or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; s.LineJoinMode = Enum.LineJoinMode.Round; s.Parent = label
	return s
end

-- text label; props may carry `noStroke = true` or `strokeThickness`
function SignKit.text(parent, props)
	local noStroke, thick = props.noStroke, props.strokeThickness
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1; t.Font = SignKit.BODY; t.TextScaled = true; t.TextColor3 = SignKit.OFFWHITE
	for k, v in props do
		if k ~= "noStroke" and k ~= "strokeThickness" then t[k] = v end
	end
	t.Parent = parent
	if not noStroke then SignKit.stroke(t, SignKit.INK, thick or 2) end
	return t
end

-- generic part: studded plastic when `studs`; always anchored
function SignKit.mk(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			if k == "studs" then
				if v then p.Material = Enum.Material.Plastic; p.TopSurface = Enum.SurfaceType.Studs end
			else p[k] = v end
		end
	end
	p.Parent = parent
	return p
end

-- diagonal yellow/black hazard stripes in a strip frame (a standard safety-edge convention)
function SignKit.hazard(parent, size, pos, stripes, a, b)
	local f = Instance.new("Frame"); f.Size = size; f.Position = pos; f.BorderSizePixel = 0; f.BackgroundColor3 = a or SignKit.YELLOW; f.Parent = parent
	local pts = {}
	for i = 0, stripes - 1 do
		local t0, t1 = i / stripes, (i + 1) / stripes
		local c = if i % 2 == 0 then (a or SignKit.YELLOW) else (b or SignKit.GRAPHITE)
		table.insert(pts, ColorSequenceKeypoint.new(math.max(t0, if i == 0 then 0 else t0 + 0.0005), c))
		table.insert(pts, ColorSequenceKeypoint.new(math.min(t1 - 0.0005, 1), c))
	end
	pts[1] = ColorSequenceKeypoint.new(0, pts[1].Value); pts[#pts] = ColorSequenceKeypoint.new(1, pts[#pts].Value)
	local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(pts); g.Rotation = 35; g.Parent = f
	return f
end

-- SurfaceGui + graphite panel + coloured header band (height fraction `band`) with hazard edge. Returns gui, panel, header
function SignKit.panel(part, face, accent, ppu, band)
	local g = Instance.new("SurfaceGui")
	g.Face = face; g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = ppu or 24
	g.LightInfluence = 0; g.Brightness = 1.3; g.Parent = part
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1); panel.BackgroundColor3 = accent:Lerp(SignKit.INK, 0.5); panel.BorderSizePixel = 0; panel.Parent = g
	local header = Instance.new("Frame")
	header.Size = UDim2.fromScale(1, band or 0.2); header.BackgroundColor3 = accent; header.BorderSizePixel = 0; header.Parent = panel
	SignKit.hazard(panel, UDim2.fromScale(1, 0.028), UDim2.fromScale(0, band or 0.2), 9)      -- ColorSequence allows at most 20 keypoints = 9 hard-edged stripes
	return g, panel, header
end

function SignKit.lighten(c, a) return c:Lerp(Color3.new(1, 1, 1), a) end
function SignKit.darken(c, a) return c:Lerp(Color3.new(0, 0, 0), a) end

return SignKit
