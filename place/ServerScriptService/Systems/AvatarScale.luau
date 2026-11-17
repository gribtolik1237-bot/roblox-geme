--!strict
-- Avatar size switching (see Balance.Avatar): giant in the lobby / on the plots, normal size while running a course by hand.
-- The scale is changed through the R15 Humanoid scale values (the engine rescales limbs, joints and hip height).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)

local AvatarScale = {}
local SCALE_VALUES = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }

function AvatarScale.Apply(char: Model, scale: number)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if char:GetAttribute("AvatarScale") == scale then return end
	for _, name in SCALE_VALUES do
		local v = hum:FindFirstChild(name)
		if v and v:IsA("NumberValue") then v.Value = scale end
	end
	local A = Balance.Avatar
	local k = math.sqrt(scale)                         -- Froude scaling: bigger body -> proportionally longer jump, faster pace
	hum.WalkSpeed = A.BaseWalkSpeed * k
	hum.UseJumpPower = false
	hum.JumpHeight = A.BaseJumpHeight * scale
	char:SetAttribute("AvatarScale", scale)           -- clients react to this (camera)
end

function AvatarScale.Lobby(char: Model) AvatarScale.Apply(char, Balance.Avatar.Lobby) end
function AvatarScale.Run(char: Model) AvatarScale.Apply(char, Balance.Avatar.Run) end

return AvatarScale
