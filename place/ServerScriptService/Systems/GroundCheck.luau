--!nonstrict
-- "Did the character fall off the course?" = is the safe floor beneath it the pit/ground instead of an obstacle.
-- A SPHERE cast is used (not a single ray): rays slip through the 0.2-stud gaps between bridge planks and gave false falls.
local Util = require(game:GetService("ReplicatedStorage").Shared.Util)

local GroundCheck = {}

GroundCheck.isGround = Util.isGround   -- audit 2.4: single definition in Shared.Util

-- true when the nearest thing below the character (within 6.5 studs) is ground
function GroundCheck.overGround(hrp: BasePart, ignore: { Instance }): boolean
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = ignore
	rp.RespectCanCollide = true       -- hidden tiles / decoration trims (CanCollide=false) are not "floor"
	local hit = workspace:Spherecast(hrp.Position, 0.9, Vector3.new(0, -6.5, 0), rp)
	return hit ~= nil and GroundCheck.isGround(hit.Instance)
end

return GroundCheck
