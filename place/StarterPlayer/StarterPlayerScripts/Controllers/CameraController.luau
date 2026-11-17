-- Camera: follows the avatar scale (giant in the lobby -> farther default zoom). The manual-run first-person view is added in RunController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)

local CameraController = {}
local player = Players.LocalPlayer

-- The default camera script has no 'initial zoom' API: pin min = max for a moment, then give the player back the zoom range.
function CameraController.SetZoom(distance: number)
	player.CameraMinZoomDistance = distance
	player.CameraMaxZoomDistance = distance
	task.delay(0.4, function()
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 128
	end)
end

local function watch(char: Model)
	local function apply()
		local s = char:GetAttribute("AvatarScale")
		if s == Balance.Avatar.Lobby then CameraController.SetZoom(Balance.Avatar.LobbyZoom) end
	end
	char:GetAttributeChangedSignal("AvatarScale"):Connect(apply)
	apply()
end

function CameraController.Start()
	player.CharacterAdded:Connect(watch)
	if player.Character then watch(player.Character) end
end

return CameraController
