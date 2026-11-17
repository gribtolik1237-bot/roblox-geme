--!strict
-- Collision groups: NPCs collide with the course but never with each other or with players.
local PhysicsService = game:GetService("PhysicsService")

local Collisions = {}

function Collisions.Setup()
	for _, g in { "Players", "NPC" } do
		pcall(function() PhysicsService:RegisterCollisionGroup(g) end)
	end
	PhysicsService:CollisionGroupSetCollidable("NPC", "NPC", false)
	PhysicsService:CollisionGroupSetCollidable("NPC", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", true)
end

function Collisions.Apply(model: Instance, group: string)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end)
end

return Collisions
