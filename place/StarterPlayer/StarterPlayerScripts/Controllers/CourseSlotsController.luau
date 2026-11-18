-- Course save slots (T41, owner reference 1 in TRAP_LAB/references_s5): the OWNER's interactive SurfaceGui on their plot's "SaveBoard":
-- 3 rows (Slot N, objects + age, Save / Load) and a red "Clear course". Load over a non-empty course and Clear need a second press
-- within 3 s. Display + requests only: the server re-validates everything (BuildService.CourseSlots).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Net = require(ReplicatedStorage.Shared.Net)
local StateController = require(script.Parent.StateController)
local HUDController = require(script.Parent.HUDController)

local C = UIKit.C
local player = Players.LocalPlayer
local CourseSlots = {}

local SLOT_COUNT, PPU = 3, 60
local GREY = Color3.fromRGB(120, 124, 140)
local ERR = require(ReplicatedStorage.Configs.Strings).CourseSlots   -- audit 2.4

local views = {}
local armed: { [string]: number } = {}
local busy = false

local function findBoard(): BasePart?
	for _, m in workspace.PlayerPlots:GetChildren() do
		if m:GetAttribute("OwnerId") == player.UserId then
			local sb = m:FindFirstChild("SaveBoard")
			return sb and sb:FindFirstChild("Board") :: BasePart?
		end
	end
	return nil
end

local function ago(t: number): string
	local d = math.max(0, os.time() - t)
	if d < 60 then return "just now" elseif d < 3600 then return math.floor(d / 60) .. " min ago" elseif d < 86400 then return math.floor(d / 3600) .. " h ago" end
	return math.floor(d / 86400) .. " d ago"
end

local function courseCount(): number
	local s = StateController.State
	return if s and s.plot then s.plot.count else 0
end

local refresh

local function request(action: string, slot: number?)
	if busy then return end
	busy = true
	local r = Net.invoke("CourseSlots", { action = action, slot = slot })
	busy = false
	if r.ok then
		if action == "save" then HUDController.Toast(("Saved to slot %d (%d objects)"):format(slot :: number, r.n), "ok")
		elseif action == "load" then
			HUDController.Toast(("Slot %d loaded: %d objects%s"):format(slot :: number, r.loaded, if (r.skipped or 0) > 0 then ("  (%d skipped: not owned or no room)"):format(r.skipped) else ""), "ok")
		else HUDController.Toast("Course cleared - everything is back in your slots", "ok") end
	else
		HUDController.Toast(ERR[r.err] or UIKit.err(r.err), "err")
	end
	refresh()
end

-- two-step confirm for destructive actions: first press arms the button for 3 s
local function confirm(key: string, fn: () -> ())
	local t = armed[key]
	if t and os.clock() - t < 3 then armed[key] = nil; fn(); return end
	armed[key] = os.clock()
	refresh()
	task.delay(3, function()
		if armed[key] and os.clock() - armed[key] >= 2.9 then armed[key] = nil; refresh() end
	end)
end

refresh = function()
	local s = StateController.State
	local saves = s and s.plot and s.plot.saves
	for _, view in views do
		for i, row in view.rows do
			local sv = saves and saves[i]
			row.info.Text = if sv then ("%d objects  -  %s"):format(sv.n, ago(sv.t)) else "Empty"
			row.info.TextColor3 = if sv then Color3.fromRGB(255, 222, 90) else Color3.fromRGB(190, 194, 210)
			row.load.Text = if armed["load" .. i] then "Replace?" else "Load"
			row.save.Text = if armed["save" .. i] then "Overwrite?" else "Save"
			row.load.BackgroundColor3 = if sv then C.purple else GREY
		end
		view.clear.Text = if armed.clear then "Tap again to clear" else "Clear course"
	end
end

local function buildFace(board: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = if face == Enum.NormalId.Back then "CourseSlotsGui" else "CourseSlotsGuiReverse"
	gui.Adornee = board; gui.Face = face; gui.ResetOnSpawn = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; gui.PixelsPerStud = PPU; gui.LightInfluence = 0; gui.MaxDistance = 160; gui.ZOffset = 1
	gui.Parent = player:WaitForChild("PlayerGui", 15)
	local W = board.Size.X * PPU
	local H = board.Size.Y * PPU
	local root = UIKit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	local top = math.floor(H * 0.22)          -- below the yellow header plate
	local clearH = math.floor(H * 0.14)
	local gap = 10
	local rowH = math.floor((H - top - clearH - 4 * gap - 6) / SLOT_COUNT)
	local bw = math.floor((W - 48) * 0.24)
	local rows = {}
	for i = 1, SLOT_COUNT do
		local y = top + (i - 1) * (rowH + gap)
		local row = UIKit.new("Frame", { Name = "Slot" .. i, BackgroundColor3 = Color3.fromRGB(24, 26, 42), Size = UDim2.fromOffset(W - 48, rowH), Position = UDim2.fromOffset(24, y) }, root)
		UIKit.round(row, 16); UIKit.stroke(row, UIKit.INK, 4)
		UIKit.label(row, { Name = "Title", Text = "Slot " .. i, TextSize = math.floor(rowH * 0.5), Size = UDim2.new(0.42, 0, 0.55, 0), Position = UDim2.fromScale(0.03, 0.04), TextXAlignment = Enum.TextXAlignment.Left, stroke = 4 })
		local info = UIKit.label(row, { Name = "Info", Text = "Empty", TextSize = math.floor(rowH * 0.31), Size = UDim2.new(0.46, 0, 0.36, 0), Position = UDim2.fromScale(0.03, 0.58), TextXAlignment = Enum.TextXAlignment.Left, stroke = 3 })
		local save, load
		save = UIKit.button(row, { name = "Save", text = "Save", color = C.green, size = UDim2.fromOffset(bw, rowH - 22), pos = UDim2.new(1, -2 * bw - 26, 0.5, -(rowH - 22) / 2), textSize = math.floor(rowH * 0.42),
			onClick = function()
				local s = StateController.State
				local filled = s and s.plot and s.plot.saves and s.plot.saves[i]
				if filled then confirm("save" .. i, function() request("save", i) end) else request("save", i) end
			end })
		load = UIKit.button(row, { name = "Load", text = "Load", color = C.purple, size = UDim2.fromOffset(bw, rowH - 22), pos = UDim2.new(1, -bw - 12, 0.5, -(rowH - 22) / 2), textSize = math.floor(rowH * 0.42),
			onClick = function()
				if courseCount() > 0 then confirm("load" .. i, function() request("load", i) end) else request("load", i) end
			end })
		rows[i] = { info = info, save = save, load = load }
	end
	local clear = UIKit.button(root, { name = "Clear", text = "Clear course", color = C.red, size = UDim2.fromOffset(W - 48, clearH), pos = UDim2.fromOffset(24, H - clearH - gap - 4), textSize = math.floor(clearH * 0.6),
		onClick = function() confirm("clear", function() request("clear") end) end })
	table.insert(views, { gui = gui, rows = rows, clear = clear })
end

function CourseSlots.Start()
	task.spawn(function()
		-- audit 2.5: bounded search for the plot's SaveBoard (the plot is assigned a few seconds after join)
		local board = findBoard()
		local t0 = os.clock()
		while not board and os.clock() - t0 < 120 do task.wait(1); board = findBoard() end
		if not board then warn("[CourseSlots] SaveBoard not found in 120 s - save slots board not built") return end
		buildFace(board, Enum.NormalId.Back)
		buildFace(board, Enum.NormalId.Front)
		refresh()
		-- audit 2.1: the "x min ago" ticker lives only while the board GUI exists and refreshes only while the board can be seen
		-- (player within its MaxDistance); out of range it just sleeps, StateController.Changed covers real changes.
		local myGui = views[1].gui
		while myGui and myGui.Parent do
			task.wait(30)
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and (hrp.Position - board.Position).Magnitude <= myGui.MaxDistance then refresh() end
		end
	end)
	StateController.Changed.Event:Connect(function() refresh() end)
end

return CourseSlots
