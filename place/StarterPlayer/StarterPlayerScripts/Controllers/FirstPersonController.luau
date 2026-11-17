--!nonstrict
-- First-person view while the player runs a course by hand (USER REQUEST: "view from the first person, a really cool feeling").
-- The default first-person camera does the looking; on top of it, every frame (after the camera script):
--   head bob (distance driven)  |  landing dip (spring) + pitch kick  |  FOV grows with speed, kicks on jump/checkpoint
--   roll when strafing           |  trauma-based shake on hits/falls   |  edge vignette that grows with speed, red flash on hits
-- Effects are deliberately small: they must support control, not fight it. V toggles first/third person during a run.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HUDController = require(script.Parent.HUDController)
local CameraController = require(script.Parent.CameraController)

local FP = {}
local player = Players.LocalPlayer
local Balance = require(game:GetService("ReplicatedStorage").Configs.Balance)
local BASE_FOV, DEFAULT_FOV = Balance.Client.BaseFov, Balance.Client.DefaultFov   -- audit 2.3 (80 / 70)
local active, wantFirstPerson = false, true

local S = { bob = 0, bobAmp = 0, dip = 0, dipV = 0, fov = DEFAULT_FOV, kick = 0, roll = 0, trauma = 0, vig = 0, flash = 0, maxFall = 0, airborne = false }
local overlay, edges, flashFrame
local hookedHum = nil
local stateConn = nil

local function buildOverlay()
	if overlay and overlay.Parent then return end
	local gui = HUDController.Gui
	overlay = Instance.new("Frame"); overlay.Name = "FPOverlay"; overlay.Size = UDim2.fromScale(1, 1); overlay.BackgroundTransparency = 1
	overlay.Active = false; overlay.ZIndex = 0; overlay.Visible = false; overlay.Parent = gui
	edges = {}
	-- each edge is a black frame whose gradient is opaque at the screen border and clear towards the middle
	local defs = {
		{ pos = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.2, 1), rot = 0 },      -- left
		{ pos = UDim2.fromScale(0.8, 0), size = UDim2.fromScale(0.2, 1), rot = 180 },  -- right
		{ pos = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.26), rot = 90 },    -- top
		{ pos = UDim2.fromScale(0, 0.74), size = UDim2.fromScale(1, 0.26), rot = 270 },-- bottom
	}
	for _, d in defs do
		local f = Instance.new("Frame"); f.BackgroundColor3 = Color3.new(0, 0, 0); f.BackgroundTransparency = 1; f.BorderSizePixel = 0
		f.Position = d.pos; f.Size = d.size; f.Active = false; f.Parent = overlay
		local g = Instance.new("UIGradient"); g.Rotation = d.rot
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }); g.Parent = f
		table.insert(edges, f)
	end
	flashFrame = Instance.new("Frame"); flashFrame.Name = "Flash"; flashFrame.Size = UDim2.fromScale(1, 1); flashFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	flashFrame.BackgroundTransparency = 1; flashFrame.BorderSizePixel = 0; flashFrame.Active = false; flashFrame.Parent = overlay
end

local function hook(hum)
	if hookedHum == hum then return end
	if stateConn then stateConn:Disconnect() end
	hookedHum = hum
	stateConn = hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			S.kick += 3
		elseif new == Enum.HumanoidStateType.Landed then
			local fall = S.maxFall
			S.maxFall = 0
			if fall > 14 then
				S.dip = math.min(fall * 0.011, 0.85); S.dipV = 0                -- the camera drops, then springs back
				S.trauma = math.min(1, S.trauma + math.clamp((fall - 25) / 90, 0, 0.45))
			end
		end
	end)
end

local function step(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not hum or not hrp or not cam then return end
	hook(hum)
	local v = hrp.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	S.airborne = not grounded
	if not grounded then S.maxFall = math.max(S.maxFall, -v.Y) end
	local a = math.min(dt * 8, 1)

	-- head bob: phase advances with the distance travelled, amplitude fades in/out
	local targetAmp = if grounded and speed > 1.5 then math.clamp(speed / 16, 0.4, 1.4) else 0
	S.bobAmp += (targetAmp - S.bobAmp) * a
	S.bob += dt * speed * 0.55
	S.dipV += (-S.dip * 140 - S.dipV * 14) * dt
	S.dip += S.dipV * dt
	hum.CameraOffset = Vector3.new(math.cos(S.bob) * 0.06 * S.bobAmp, (math.abs(math.sin(S.bob)) * 0.14 - 0.07) * S.bobAmp - S.dip, 0)

	-- field of view: wider when fast / in the air; kicks decay
	local fovTarget = BASE_FOV + math.clamp(speed - 16, 0, 24) * 0.55 + (if grounded then 0 else 3) + S.kick
	S.fov += (fovTarget - S.fov) * math.min(dt * 6, 1)
	S.kick -= S.kick * math.min(dt * 5, 1)
	cam.FieldOfView = S.fov

	-- roll into a strafe, tiny roll with the bob
	local side = flat:Dot(cam.CFrame.RightVector)
	local rollTarget = -math.clamp(side / 16, -1, 1) * math.rad(2.2) + math.sin(S.bob) * math.rad(0.35) * S.bobAmp
	S.roll += (rollTarget - S.roll) * math.min(dt * 7, 1)

	-- trauma shake (quadratic, noise based)
	S.trauma = math.max(0, S.trauma - dt * 1.6)
	local amt = S.trauma * S.trauma
	local c = os.clock() * 24
	local sx, sy, sz = math.noise(c, 0, 1) * amt * 0.05, math.noise(0, c, 2) * amt * 0.05, math.noise(c, c, 3) * amt * 0.07
	cam.CFrame = cam.CFrame * CFrame.Angles(sx - S.dip * 0.06, sy, S.roll + sz)

	-- screen edges: always a little, more with speed and in the air; red flash decays
	local vigTarget = 0.12 + math.clamp((speed - 14) / 16, 0, 0.45) + (if grounded then 0 else 0.1)
	S.vig += (vigTarget - S.vig) * a
	for _, f in edges do f.BackgroundTransparency = 1 - S.vig end
	S.flash = math.max(0, S.flash - dt * 2.4)
	flashFrame.BackgroundTransparency = 1 - S.flash * 0.45
end

local function applyMode()
	if wantFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		CameraController.SetZoom(14)
	end
end

function FP.Enter()
	if active then return end
	active = true
	buildOverlay()
	overlay.Visible = true
	-- audit 5.4: start the FOV easing from what the camera shows NOW (no jump if a tween from a previous exit is still running)
	local cam0 = workspace.CurrentCamera
	S.fov = if cam0 then cam0.FieldOfView else DEFAULT_FOV
	S.kick = 10; S.dip = 0; S.dipV = 0; S.trauma = 0; S.maxFall = 0
	applyMode()
	RunService:BindToRenderStep("TL_FirstPerson", Enum.RenderPriority.Camera.Value + 1, step)   -- right AFTER the default camera script
end

function FP.Exit()
	if not active then return end
	active = false
	pcall(function() RunService:UnbindFromRenderStep("TL_FirstPerson") end)
	if overlay then overlay.Visible = false end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.CameraOffset = Vector3.zero end
	-- audit 5.4: the run FOV (80..95) eases back to the normal 70 instead of snapping (the snap read as a camera jerk)
	local cam = workspace.CurrentCamera
	if cam then
		game:GetService("TweenService"):Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = DEFAULT_FOV }):Play()
	end
	player.CameraMode = Enum.CameraMode.Classic
end

-- Turn the view down the course. In first person the body follows the CAMERA, and the camera keeps its old yaw - without this the
-- player who pressed E facing the PLAY sign started the run looking backwards (found in the S6 FTUE test).
function FP.Face(look)
	if typeof(look) ~= "Vector3" then return end
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then return end
	local dir = flat.Unit
	for _, delay in { 0, 0.15 } do        -- once now, once after the server teleport has replicated
		task.delay(delay, function()
			local cam = workspace.CurrentCamera
			local c = cam.CFrame
			cam.CFrame = CFrame.lookAt(c.Position, c.Position + dir - Vector3.new(0, 0.12, 0))
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + dir) end
		end)
	end
end

-- kind: "start" | "checkpoint" | "fall" | "knock"
function FP.Impact(kind)
	if not active then return end
	if kind == "checkpoint" then S.kick += 7; S.trauma = math.min(1, S.trauma + 0.12)
	elseif kind == "fall" then S.trauma = math.min(1, S.trauma + 0.7); S.flash = 1
	elseif kind == "knock" then S.trauma = math.min(1, S.trauma + 0.8); S.flash = 0.7
	elseif kind == "start" then S.kick += 10 end
end

function FP.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not active then return end
		if input.KeyCode == Enum.KeyCode.V then wantFirstPerson = not wantFirstPerson; applyMode() end
	end)
end

return FP
