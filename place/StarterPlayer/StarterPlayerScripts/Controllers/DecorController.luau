--!nonstrict
-- Decor window + placement: pick an item -> a ghost follows the mouse over your land -> click to buy & place (R rotates, X / Esc cancels).
-- "Remove" mode: click a decoration to take it away (50% refund). The server decides everything; the ghost is only a preview.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Net = require(ReplicatedStorage.Shared.Net)
local Util = require(ReplicatedStorage.Shared.Util)
local Decor = require(ReplicatedStorage.Configs.Decor)
local DecorModels = require(ReplicatedStorage.Shared.DecorModels)
local Icons = require(ReplicatedStorage.Configs.Icons)
local HUDController = require(script.Parent.HUDController)
local StateController = require(script.Parent.StateController)

local C = UIKit.C
local Ctl = {}
local win, infoLabel
local mode = nil           -- nil | { kind = "place", id, ghost, yaw } | { kind = "remove" }
local ERRORS = require(game:GetService("ReplicatedStorage").Configs.Strings).Decor   -- audit 2.4

local function myPlot()
	for _, m in workspace.PlayerPlots:GetChildren() do if m:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then return m end end
	return nil
end

-- plot-local (x, z) under the mouse (ray vs the ground plane of the plot)
local function mousePoint(plot)
	local cam = workspace.CurrentCamera
	local m = UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	local origin = plot.Origin.CFrame
	if math.abs(ray.Direction.Y) < 1e-4 then return nil end
	local t = (origin.Position.Y - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then return nil end
	local lp = origin:PointToObjectSpace(ray.Origin + ray.Direction * t)
	return lp.X, lp.Z, origin
end

local function stop()
	if mode and mode.ghost then mode.ghost:Destroy() end
	mode = nil
	pcall(function() RunService:UnbindFromRenderStep("TL_DecorGhost") end)
end

local function startPlace(id)
	stop()
	local plot = myPlot()
	if not plot then HUDController.Toast("Your plot isn't ready yet", "err"); return end
	local ghost = DecorModels.build(id)
	for _, d in ghost:GetDescendants() do if d:IsA("BasePart") then d.Transparency = math.max(d.Transparency, 0.45) end end
	ghost.Parent = workspace
	mode = { kind = "place", id = id, ghost = ghost, yaw = 0 }
	win.close()
	RunService:BindToRenderStep("TL_DecorGhost", Enum.RenderPriority.Camera.Value + 2, function()
		local x, z, origin = mousePoint(plot)
		if x then ghost:PivotTo(origin * CFrame.new(math.floor(x + 0.5), 0, math.floor(z + 0.5)) * CFrame.Angles(0, math.rad(mode.yaw), 0)) end
	end)
	HUDController.Toast("Click to place - R rotate - X cancel", "info")
end

local function startRemove()
	stop()
	mode = { kind = "remove" }
	win.close()
	HUDController.Toast("Click a decoration to remove it (50% back) - X to stop", "info")
end

local function onClick()
	if not mode then return end
	local plot = myPlot()
	local x, z = mousePoint(plot)
	if not x then return end
	if mode.kind == "place" then
		local r = Net.invoke("PlaceDecor", { id = mode.id, x = x, z = z, r = mode.yaw })
		if r.ok then HUDController.Toast("Placed!", "ok") else HUDController.Toast(ERRORS[r.err] or "Can't place here", "err") end
	else
		local best, bd = nil, math.huge
		for _, m in plot.Decor:GetChildren() do
			local def = Decor.ById[m:GetAttribute("DecorId")]
			local lp = plot.Origin.CFrame:PointToObjectSpace(m:GetPivot().Position)
			local d = math.sqrt((lp.X - x) ^ 2 + (lp.Z - z) ^ 2)
			if def and d <= def.r + 1 and d < bd then best, bd = m, d end
		end
		if best then
			local r = Net.invoke("RemoveDecor", { uid = best:GetAttribute("Uid") })
			if r.ok then HUDController.Toast(("Removed (+%d Coins)"):format(r.refund or 0), "ok") end
		end
	end
end

function Ctl.Start()
	win = UIKit.window(HUDController.Gui, "Decorations", UDim2.fromOffset(920, 620), C.green, Icons.decor)
	infoLabel = UIKit.label(win.body, { Text = "", TextSize = 24, Size = UDim2.new(1, -200, 0, 36), TextColor3 = C.yellow, TextXAlignment = Enum.TextXAlignment.Left, stroke = 3.5 })
	UIKit.button(win.body, { name = "RemoveMode", text = "Remove mode", color = C.red, size = UDim2.fromOffset(180, 38), pos = UDim2.new(1, -180, 0, -2), textSize = 20, onClick = startRemove })
	local scroll = UIKit.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 10, ScrollBarImageColor3 = C.muted, BorderSizePixel = 0 }, win.body)
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(204, 250), CellPadding = UDim2.fromOffset(12, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, scroll)
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, scroll)
	for i, def in Decor.List do
		local k = UIKit.itemCard(scroll, { w = 204, h = 250, rarity = C.green, name = def.name, pvH = 140, order = i })
		local ok, m = pcall(DecorModels.build, def.id)
		if ok and m then pcall(UIKit.preview, k.pv, m, { zoom = 0.95 }) end
		UIKit.priceButton(k.card, { text = Util.fmt(def.price), size = UDim2.new(1, -20, 0, 46), pos = UDim2.new(0, 10, 1, -56), textSize = 26, onClick = function() startPlace(def.id) end })
	end
	win.onOpen = function() stop(); local s = StateController.State; if s and s.decor then infoLabel.Text = ("Decorations %d/%d"):format(s.decor.count, s.decor.limit) end end
	StateController.Changed.Event:Connect(function(s) if s and s.decor then infoLabel.Text = ("Decorations %d/%d"):format(s.decor.count, s.decor.limit) end end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not mode then return end
		if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Escape then stop(); return end
		if processed then return end
		if input.KeyCode == Enum.KeyCode.R and mode.kind == "place" then mode.yaw = (mode.yaw + 45) % 360
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then onClick() end
	end)
end

return Ctl
