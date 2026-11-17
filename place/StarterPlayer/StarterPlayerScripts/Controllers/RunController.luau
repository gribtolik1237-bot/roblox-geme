-- Manual-run HUD: banner (course, stage x/N, server-synced timer, Cancel) + result popup. Display only; the server decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIKit = require(ReplicatedStorage.Shared.UIKit)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)
local HUDController = require(script.Parent.HUDController)
local FirstPerson = require(script.Parent.FirstPersonController)
local SfxController = require(script.Parent.SfxController)

local C = UIKit.C
local RunController = {}
local banner, info, title, result
local run = nil

local REASONS = require(ReplicatedStorage.Configs.Strings).RunReasons   -- audit 2.4

local function fmtTime(t) return ("%d:%04.1f"):format(math.floor(t / 60), t % 60) end

-- audit 2.1: the banner timer ticks ONLY while a run is active (spawned at run start, ends with the run) - no eternal poll loop
local timerOn = false
local function startTimer()
	if timerOn then return end
	timerOn = true
	task.spawn(function()
		while run do
			local t = math.max(0, workspace:GetServerTimeNow() - (run.startedAt or workspace:GetServerTimeNow()))
			info.Text = ("Stage %d/%d    %s    Falls %d"):format(run.stage or 0, run.total or 0, fmtTime(t), run.falls or 0)
			task.wait(0.1)
		end
		timerOn = false
	end)
end

local function showResult(p)
	result.Visible = true
	local cleared = p.outcome == "cleared"
	result.Title.Text = if cleared then "COURSE CLEARED!" else "RUN ENDED"
	result.Title.TextColor3 = if cleared then C.green else C.orange
	local lines = { ("Time %s    Stages %d/%d"):format(fmtTime(p.time or 0), p.stage or 0, p.total or 0) }
	if cleared then
		if (p.reward or 0) > 0 then lines[#lines + 1] = ("+%s Coins"):format(Util.fmt(p.reward)) else lines[#lines + 1] = REASONS[(p.reason == "repeat") and "repeat_" or p.reason or ""] or "No reward this time" end
	elseif p.outcome == "cancel" then lines[#lines + 1] = "You left the course"
	else lines[#lines + 1] = REASONS[p.outcome] or REASONS[p.reason or ""] or "" end
	result.Info.Text = table.concat(lines, "\n")
	result.Position = UDim2.new(0.5, 0, 0.6, 0)
	TweenService:Create(result, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.45, 0) }):Play()
	task.delay(7, function() if result.Visible and run == nil then result.Visible = false end end)
end

function RunController.Start()
	local gui = HUDController.Gui
	banner = UIKit.new("Frame", { Name = "RunBanner", Size = UDim2.fromOffset(560, 92), Position = UDim2.new(0.5, 0, 0, 64), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, gui)
	UIKit.round(banner, 20); UIKit.stroke(banner, UIKit.INK, 4.5)
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(66, 74, 110), Color3.fromRGB(30, 34, 54)), Rotation = 90 }, banner)
	local bk = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6) }, banner)
	UIKit.round(bk, 15); UIKit.new("UIStroke", { Color = C.teal, Thickness = 3 }, bk)
	title = UIKit.label(banner, { Text = "", TextSize = 24, Size = UDim2.new(1, -140, 0, 32), Position = UDim2.fromOffset(18, 8), TextXAlignment = Enum.TextXAlignment.Left, stroke = 3.5 })
	info = UIKit.label(banner, { Text = "", TextSize = 28, Size = UDim2.new(1, -140, 0, 38), Position = UDim2.fromOffset(18, 44), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.yellow, stroke = 4 })
	-- the ONLY button during a run (owner rule T38): Exit at the right edge; hotbar, hammer and menu tiles are hidden meanwhile
	local exitBtn = UIKit.button(gui, { text = "Exit", color = C.red, size = UDim2.fromOffset(120, 60), pos = UDim2.new(1, -136, 0.4, 0), textSize = 28, onClick = function() Net.invoke("CancelManual") end })
	exitBtn.Visible = false
	result = UIKit.new("Frame", { Name = "RunResult", Size = UDim2.fromOffset(480, 300), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 20 }, gui)
	UIKit.round(result, 24); UIKit.stroke(result, UIKit.INK, 5)
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(74, 80, 116), Color3.fromRGB(34, 36, 54)), Rotation = 90 }, result)
	local rk = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -14, 1, -14), Position = UDim2.fromOffset(7, 7), ZIndex = 20 }, result)
	UIKit.round(rk, 18); UIKit.new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.86, Thickness = 2 }, rk)
	UIKit.label(result, { Name = "Title", Text = "", TextSize = 46, Size = UDim2.new(1, -20, 0, 64), Position = UDim2.fromOffset(10, 16), ZIndex = 21, stroke = 5 })
	UIKit.label(result, { Name = "Info", Text = "", TextSize = 26, TextWrapped = true, Size = UDim2.new(1, -40, 0, 110), Position = UDim2.fromOffset(20, 88), ZIndex = 21, TextColor3 = C.yellow, stroke = 3.5 })
	local ok = UIKit.button(result, { text = "OK", color = C.green, size = UDim2.fromOffset(170, 58), pos = UDim2.new(0.5, -85, 1, -74), textSize = 30, onClick = function() result.Visible = false end })
	ok.ZIndex = 22

	Net.on("RunState", function(p)
		if p.state == "start" then
			run = p; result.Visible = false; banner.Visible = true
			local okB, BC = pcall(require, script.Parent.BuildController)
			if okB and BC.SetActive then BC.SetActive(false) end       -- leave build mode first (hammer is not available during a run)
			HUDController.SetRunMode(true); exitBtn.Visible = true
			FirstPerson.Enter()                  -- first-person view for the run (V = toggle third person)
			FirstPerson.Face(p.look)             -- start looking DOWN the course, not back at the sign
			title.Text = ("%s  -  %s  [%s]"):format(p.name or "Course", p.owner or "", p.difficulty or "")
			HUDController.Toast(if p.isSelf then "Test run: your own course (reduced reward, once per version)" else "Go go go!", "info")
			startTimer()
		elseif p.state == "progress" then
			if run then run.stage = p.stage; run.total = p.total end
			HUDController.Toast(("Checkpoint %d/%d"):format(p.stage, p.total), "ok")
			FirstPerson.Impact("checkpoint")
		elseif p.state == "fall" then
			if run then run.falls = p.falls end
			HUDController.Toast("Oops! Back to your last checkpoint", "err")
			FirstPerson.Impact("fall")
			FirstPerson.Face(p.look)
		elseif p.state == "end" then
			run = nil; banner.Visible = false
			exitBtn.Visible = false; HUDController.SetRunMode(false)
			FirstPerson.Exit()
			showResult(p)
		end
	end)
	Net.on("Knock", function(dir, power)
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum then
			hrp.AssemblyLinearVelocity = dir * power + Vector3.new(0, 38, 0)
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
			SfxController.Play("knock")
			FirstPerson.Impact("knock")
		end
	end)
	Net.on("Effect", function(kind, v)
		if kind == "Launch" then      -- bounce pad: keep the horizontal speed for 0.55 s (the Humanoid damps it)
			local char = Players.LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			hrp.AssemblyLinearVelocity = v
			local t1 = os.clock()
			while os.clock() - t1 < 0.55 and hrp.Parent do
				local cur = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(v.X, cur.Y, v.Z)
				task.wait()
			end
		end
	end)
end

return RunController
