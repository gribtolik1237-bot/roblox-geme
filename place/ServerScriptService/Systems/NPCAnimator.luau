--!nonstrict
-- Drives an NPC rig's animations from Humanoid events (server-side Animator => replicates to every client).
-- Uses Roblox's own default R15 animation assets. stumble/fall/despawn are physical + procedural (see NPCRunService).
local NPCAnimator = {}

local IDS = {
	idle = "rbxassetid://507766666", walk = "rbxassetid://507777826", jump = "rbxassetid://507765000", fall = "rbxassetid://507767968",
}

function NPCAnimator.Attach(model: Model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local tracks = {}
	local function load(name, priority, looped)
		local a = Instance.new("Animation"); a.AnimationId = IDS[name]
		local ok, t = pcall(function() return animator:LoadAnimation(a) end)
		if ok and t then t.Priority = priority; t.Looped = looped; tracks[name] = t end
	end
	load("idle", Enum.AnimationPriority.Idle, true)
	load("walk", Enum.AnimationPriority.Movement, true)
	load("jump", Enum.AnimationPriority.Action, false)
	load("fall", Enum.AnimationPriority.Action, true)
	local current = nil
	local function play(name)
		if current == name or not tracks[name] then return end
		if current and tracks[current] then tracks[current]:Stop(0.15) end
		current = name
		tracks[name]:Play(0.15)
	end
	hum.Running:Connect(function(speed)
		if speed > 0.8 then
			play("walk")
			if tracks.walk then tracks.walk:AdjustSpeed(math.clamp(speed / 14, 0.5, 2.4)) end
		else play("idle") end
	end)
	hum.Jumping:Connect(function() play("jump") end)
	hum.FreeFalling:Connect(function(active) if active then play("fall") end end)
	play("idle")
	return { tracks = tracks, play = play }
end

return NPCAnimator
