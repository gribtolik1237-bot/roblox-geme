-- First-session guide (FTUE). OWNER RULE: just an ARROW that leads you and shows what to press - no cards, no text walls.
--  * world target  -> chevron beam on the ground from your feet + a bouncing arrow above the target with 1-2 words
--  * button target -> a bouncing arrow next to the button with 1 word ("NPCs", "Place", "Launch", "Hammer", "Shop")
-- Steps are DERIVED from state (stats / inventory / plot), so rejoining can't break them and veterans never see them.
-- Flow: starter course is pre-placed (Balance.StarterCourse) -> 1 send the NPC -> 2 PLAY it -> 3 buy a trap -> 4 place it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Icons = require(ReplicatedStorage.Configs.Icons)
local Balance = require(ReplicatedStorage.Configs.Balance)
local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)
local BuildController = require(script.Parent.BuildController)

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local GuideController = {}
local npcLaunched = false          -- the runner has left: point at it ("Watch!") until its run ends (stats.npcRuns grows at the end)
local playStarted = false          -- the PLAY step counts as done the moment a run starts (finishing it is not required)

local KIT_ITEMS, KIT_OBJECTS = 0, 0
for _, s in Balance.StarterCourse or {} do
	KIT_OBJECTS += 1
	if s.id ~= "FinishPad" then KIT_ITEMS += 1 end
end

local function myPlot(): Model?
	local pp = workspace:FindFirstChild("PlayerPlots")
	if not pp then return nil end
	for _, m in pp:GetChildren() do
		if m:GetAttribute("OwnerId") == player.UserId then return m end
	end
	return nil
end
local function invTotal(s: any): number
	local n = 0
	for _, v in s.inv or {} do n += v end
	return n
end
local function feet(): Vector3?
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return nil end
	return hrp.Position - Vector3.new(0, hrp.Size.Y / 2 + hum.HipHeight - 0.6, 0)
end
local function openWindow(name: string): GuiObject?
	local g = HUDController.Gui
	local w = g and g:FindFirstChild(name)
	return if w and (w :: GuiObject).Visible then w :: GuiObject else nil
end

-- Each step: done(state) and point() -> kind ("ui"|"world"|nil), target (GuiObject | Vector3), label
local STEPS = {
	{ id = "npc", done = function(s) return (s.stats and s.stats.npcRuns or 0) > 0 end,
		point = function()
			if npcLaunched then          -- the runner is out: point AT it - watching your NPC run your course is the 'aha' moment
				local p = myPlot()
				local folder = p and p:FindFirstChild("Npcs")
				for _, m in (folder and folder:GetChildren() or {}) do
					if m:IsA("Model") then return "world", m:GetPivot().Position - Vector3.new(0, 4, 0), "Watch!", true end
				end
				return nil
			end
			local win = openWindow("NPCTestersWindow")
			if win then
				local act = win:FindFirstChild("Pad1", true)
				act = act and act:FindFirstChild("Act")
				if act and (act :: GuiObject).Visible then return "ui", act, (act :: TextButton).Text end
				return nil
			end
			return "ui", HUDController.Menu.npcs, "NPCs"
		end },
	{ id = "play", done = function(s) return playStarted or (s.stats and s.stats.manualRuns or 0) > 0 end,
		point = function()
			local p = myPlot()
			local sign = p and p:FindFirstChild("PlaySign")
			local btn = sign and sign:FindFirstChild("PlayButton") :: BasePart?
			if not btn then return nil end
			local f = feet()
			if f and (btn.Position - f).Magnitude < 20 then return nil end   -- close enough: Roblox's own "E / tap - Run this course" prompt takes over
			return "world", btn.Position - Vector3.new(0, 6, 0), "PLAY"
		end },
	{ id = "shop", done = function(s) return invTotal(s) > KIT_ITEMS end,
		point = function()
			local win = openWindow("ObstacleShopWindow")
			if win then                   -- window open: point at the first trap the player can afford
				local s = StateController.State
				local best, bestOrder = nil, math.huge
				for _, d in win:GetDescendants() do
					if d:IsA("TextButton") and d.Name == "Buy" then
						local price = tonumber((d.Text:gsub("[^%d]", "")))
						local card = d.Parent :: GuiObject
						if price and s and price <= s.coins and card.LayoutOrder < bestOrder then best, bestOrder = d, card.LayoutOrder end
					end
				end
				return if best then "ui" else nil, best, "Buy"
			end
			local shops = workspace:FindFirstChild("WorldAssets") and workspace.WorldAssets:FindFirstChild("Shops")
			local m = shops and shops:FindFirstChild("Shop_obstacle") :: Model?
			local f = feet()
			local d = if m and f then (m:GetPivot().Position - f).Magnitude else math.huge
			if d < 32 then return nil end                      -- Roblox's own "E - Open" prompt takes over at the counter
			if d < 90 then return "world", (m :: Model):GetPivot().Position, "Shop" end
			return "ui", HUDController.Menu.shop, "Shop"
		end },
	{ id = "place", done = function(s) return (s.plot and s.plot.count or 0) > KIT_OBJECTS end,
		point = function()
			local g = HUDController.Gui
			local hot = g and g:FindFirstChild("Hotbar")
			if not hot then return nil end
			local p0 = myPlot()
			local o0 = p0 and p0:FindFirstChild("Origin") :: BasePart?
			local f = feet()
			if o0 and f and (o0.Position - f).Magnitude > 140 then return "ui", HUDController.Menu.home, "Home" end   -- build at home
			if not BuildController.IsActive() then return "ui", hot:FindFirstChild("Hammer"), "Hammer" end
			if not BuildController.Selected() then
				-- remove the step instead of pointing at it: the trap just bought goes straight into the hand (ghost appears)
				for _, c in hot:GetChildren() do
					if c.Name:sub(1, 5) == "Slot_" and c.Name ~= "Slot_FinishPad" then
						if os.clock() - (GuideController.lastAutoPick or 0) > 2 then
							GuideController.lastAutoPick = os.clock()
							task.defer(BuildController.Select, c.Name:sub(6))
						end
						return nil
					end
				end
				return nil
			end
			local p = myPlot()
			local o = p and p:FindFirstChild("Origin") :: BasePart?
			if not o then return nil end
			return "world", o.CFrame:PointToWorldSpace(Vector3.new(22, 2, -60)), "Click here"      -- a free spot beside the starter course
		end },
}

local ui: any = {}
local current: any = nil
local lastId: string? = "?"
local didStep = false

local function arrowImage(parent: Instance, name: string): ImageLabel
	return UIKit.new("ImageLabel", { Name = name, BackgroundTransparency = 1, Image = Icons.guideArrow or "", ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5) }, parent)
end

local function build(): boolean
	-- audit 2.5: bounded wait for PlayerGui; without it the guide simply does not start (graceful, warned)
	local pg = player:WaitForChild("PlayerGui", 15)
	if not pg then warn("[Guide] PlayerGui did not appear in 15 s - guide arrows disabled") return false end
	-- screen arrow (own ScreenGui above every window; same inset as the HUD so AbsolutePosition matches)
	local sg = UIKit.new("ScreenGui", { Name = "GuideArrows", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 30, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, pg)
	ui.sArrow = arrowImage(sg, "Arrow")
	ui.sLabel = UIKit.label(sg, { Name = "Label", Text = "", TextSize = 34, Size = UDim2.fromOffset(220, 44), AnchorPoint = Vector2.new(0.5, 0.5), stroke = 4.5 })
	ui.sg = sg
	-- world: beam + marker
	local holder = Instance.new("Part")
	holder.Name = "GuideHolder"; holder.Anchored = true; holder.CanCollide = false; holder.CanQuery = false; holder.CanTouch = false
	holder.Transparency = 1; holder.Size = Vector3.new(0.2, 0.2, 0.2)
	local a0 = Instance.new("Attachment"); a0.Parent = holder
	local a1 = Instance.new("Attachment"); a1.Parent = holder
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = Icons.guideArrows or Icons.guideChevron or ""
	beam.TextureMode = Enum.TextureMode.Static; beam.TextureLength = 5.5; beam.TextureSpeed = 1.2
	beam.Width0, beam.Width1 = 5.5, 5.5
	beam.FaceCamera = false           -- lies FLAT on the ground (attachment X = up, Y = side; see onStep): a path of arrows
	beam.Segments = 10                 -- (Segments = 1 does not render at all - found in testing)
	beam.LightEmission = 0; beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.05, 0), NumberSequenceKeypoint.new(1, 0) })
	beam.Parent = holder
	local bb = Instance.new("BillboardGui")
	bb.Name = "GuideMarker"; bb.Adornee = holder; bb.AlwaysOnTop = true; bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(200, 150); bb.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	local wl = UIKit.label(bb, { Name = "Label", Text = "", TextSize = 36, Size = UDim2.new(1, 0, 0, 44), stroke = 5 })
	local wa = arrowImage(bb, "Arrow")
	wa.Rotation = 90; wa.Size = UDim2.fromOffset(110, 55); wa.Position = UDim2.new(0.5, 0, 0, 96)
	bb.Parent = holder
	holder.Parent = workspace
	ui.holder, ui.a0, ui.a1, ui.beam, ui.marker, ui.wLabel = holder, a0, a1, beam, bb, wl
	return true
end

local function hideAll()
	ui.beam.Enabled = false; ui.marker.Enabled = false
	ui.sArrow.Visible = false; ui.sLabel.Visible = false
end

local function evaluate()
	local s = StateController.State
	if not s or not s.stats then return end
	local st
	for _, x in STEPS do if not x.done(s) then st = x break end end
	-- NEW players only (owner bug report: a Rebirth-10 player who cleared his course got "Hammer" / "Click here" arrows again)
	if (s.rebirth or 0) > 0 or (s.lifetime or 0) > 2500 then st = nil end
	local id = st and st.id or nil
	if id ~= lastId then
		if lastId ~= "?" and current then HUDController.Toast(if id then "Done!" else "Great start! Earn Coins, then Rebirth", "ok") end
		lastId = id
		current = st
		didStep = didStep or st ~= nil
	end
end

local function onStep()
	if not current or HUDController.RunMode == true then hideAll() return end
	local ok, kind, target, label, noBeam = pcall(current.point)
	if not ok or not kind or not target then hideAll() return end
	local t = os.clock()
	local bob = math.sin(t * 6) * 8
	if kind == "world" then
		ui.sArrow.Visible = false; ui.sLabel.Visible = false
		local pos = target :: Vector3
		ui.holder.Position = pos
		local f = feet()
		if f then
			local ground = Vector3.new(pos.X, f.Y, pos.Z)
			local d = ground - f
			if d.Magnitude > 0.5 then
				local side = d.Unit:Cross(Vector3.yAxis).Unit
				ui.a0.WorldCFrame = CFrame.fromMatrix(f, Vector3.yAxis, side)
				ui.a1.WorldCFrame = CFrame.fromMatrix(ground, Vector3.yAxis, side)
			end
			ui.beam.Enabled = not noBeam and d.Magnitude > 14
		else
			ui.beam.Enabled = false
		end
		ui.marker.Enabled = true
		ui.marker.StudsOffsetWorldSpace = Vector3.new(0, 8.5 + math.sin(t * 5) * 1.0, 0)   -- low enough that the word never hides under the top bar
		ui.wLabel.Text = label or ""
	else
		ui.beam.Enabled = false; ui.marker.Enabled = false
		local b = target :: GuiObject
		if not b:IsA("GuiObject") or not b.Visible or b.AbsoluteSize.X < 2 then hideAll() return end
		local vs = ui.sg.AbsoluteSize
		local ap, as = b.AbsolutePosition, b.AbsoluteSize
		local c = ap + as / 2
		local col = b.Parent
		local actionTile = col and col.Name == "MenuColumn"
		local us = HUDController.Gui and HUDController.Gui:FindFirstChildOfClass("UIScale")
		local k = math.clamp(us and us.Scale or 1, 0.6, 1.4)
		local aw, ah = 112 * k, 56 * k
		ui.sArrow.Size = UDim2.fromOffset(aw, ah)
		ui.sLabel.Size = UDim2.fromOffset(240 * k, 48 * k)
		ui.sLabel.TextSize = math.floor(38 * k)
		local gap = 8 * k
		local apos, lpos, rot, lanchor, lalign
		if actionTile then                 -- point alongside the vertical column, clear of the neighboring tiles
			rot = 180
			apos = Vector2.new(ap.X + as.X + gap + aw / 2 + math.abs(bob), c.Y)
			lpos = apos + Vector2.new(aw / 2 + 4 * k, 0); lanchor = Vector2.new(0, 0.5); lalign = Enum.TextXAlignment.Left
		elseif c.Y > vs.Y * 0.7 then          -- bottom (hotbar): arrow above, pointing down, word above it
			rot = 90
			apos = Vector2.new(c.X, ap.Y - gap - aw / 2 - math.abs(bob))
			lpos = apos - Vector2.new(0, aw / 2 + 2 * k); lanchor = Vector2.new(0.5, 1); lalign = Enum.TextXAlignment.Center
		elseif c.Y < vs.Y * 0.22 then     -- top bar: arrow below, pointing up, word under it
			rot = -90
			apos = Vector2.new(c.X, ap.Y + as.Y + gap + aw / 2 + math.abs(bob))
			lpos = apos + Vector2.new(0, aw / 2 + 2 * k); lanchor = Vector2.new(0.5, 0); lalign = Enum.TextXAlignment.Center
		elseif c.X < vs.X / 2 then        -- left side: arrow to the right pointing left, word after its tail
			rot = 180
			apos = Vector2.new(ap.X + as.X + gap + aw / 2 + math.abs(bob), c.Y)
			lpos = apos + Vector2.new(aw / 2 + 4 * k, 0); lanchor = Vector2.new(0, 0.5); lalign = Enum.TextXAlignment.Left
		else                              -- right side: arrow to the left pointing right, word before its tail
			rot = 0
			apos = Vector2.new(ap.X - gap - aw / 2 - math.abs(bob), c.Y)
			lpos = apos - Vector2.new(aw / 2 + 4 * k, 0); lanchor = Vector2.new(1, 0.5); lalign = Enum.TextXAlignment.Right
		end
		ui.sLabel.AnchorPoint = lanchor
		ui.sLabel.TextXAlignment = lalign
		ui.sArrow.Rotation = rot
		ui.sArrow.Position = UDim2.fromOffset(apos.X, apos.Y)
		ui.sLabel.Position = UDim2.fromOffset(lpos.X, lpos.Y)
		ui.sLabel.Text = label or ""
		ui.sArrow.Visible = true; ui.sLabel.Visible = label ~= nil and label ~= ""
	end
end

function GuideController.Start()
	if not HUDController.Gui then return end
	if not build() then return end
	hideAll()
	StateController.Changed.Event:Connect(evaluate)
	Net.on("NpcState", function(p)
		if type(p) == "table" and p.state == "start" and not npcLaunched then npcLaunched = true; evaluate() end
	end)
	Net.on("RunState", function(p)
		if type(p) == "table" and p.state == "start" and not playStarted then playStarted = true; evaluate() end
	end)
	evaluate()
	RunService.RenderStepped:Connect(onStep)
end

return GuideController
