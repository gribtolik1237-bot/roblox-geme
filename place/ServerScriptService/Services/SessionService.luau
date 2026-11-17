--!strict
-- Player lifecycle: profile loaded -> plot assigned -> character spawned at the plot; respawn; release on leave.
local Players = game:GetService("Players")
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateSync = require(script.Parent.StateSync)
local Collisions = require(script.Parent.Parent.Systems.Collisions)
local AvatarScale = require(script.Parent.Parent.Systems.AvatarScale)

local SessionService = {}
SessionService.Ready = Instance.new("BindableEvent")      -- (player, profile, plot) after plot assignment
SessionService.Leaving = Instance.new("BindableEvent")    -- (player) before plot release
SessionService.CharacterSpawned = Instance.new("BindableEvent") -- (player, character)

local function spawnCharacter(player: Player)
	if player.Parent then player:LoadCharacter() end
end

local function onCharacter(player: Player, char: Model)
	Collisions.Apply(char, "Players")
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		hum:WaitForChild("BodyHeightScale", 5)        -- R15 scale values arrive with the avatar
		AvatarScale.Lobby(char)                        -- the player is a giant in the lobby (a manual run shrinks it back)
		hum.Died:Connect(function()
			task.wait(Players.RespawnTime)
			spawnCharacter(player)
		end)
	end
	SessionService.CharacterSpawned:Fire(player, char)
end

function SessionService.Start()
	PlayerDataService.Loaded.Event:Connect(function(player: Player, profile: any)
		local plot = PlotService.Assign(player, profile.rebirth)
		if not plot then
			player:Kick("TRAP LAB server is full (8 plots). Please join another server.")
			return
		end
		PlotService.SetSignInfo(plot, profile.plot.name, player.DisplayName, "", "Build a course!")
		do local okR, R = pcall(require, script.Parent.RatingService); if okR then local avg, n = R.Average(profile); PlotService.SetSignRating(plot, avg, n) end end
		player.CharacterAdded:Connect(function(c) onCharacter(player, c) end)
		SessionService.Ready:Fire(player, profile, plot)
		StateSync.Push(player)
		spawnCharacter(player)
	end)
	PlayerDataService.Removing.Event:Connect(function(player: Player)
		SessionService.Leaving:Fire(player)
		PlotService.Release(player)
	end)
end

return SessionService
