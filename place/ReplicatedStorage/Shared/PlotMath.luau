--!strict
-- Plot-local geometry shared by server validation and the client build ghost.
-- Plot frame: origin = start-edge centre on the ground, forward (build direction) = -Z, X = right.
-- An object is {id, x, y, z, r}: centre x/z (studs), base altitude y, yaw r in {0,90,180,270}.
local Balance = require(script.Parent.Parent.Configs.Balance)

local PlotMath = {}

export type Box = { minX: number, maxX: number, minY: number, maxY: number, minZ: number, maxZ: number }

function PlotMath.halfExtents(size: Vector3, r: number): (number, number)
	local w, d = size.X, size.Z
	if r % 180 == 90 then w, d = d, w end
	return w / 2, d / 2
end

function PlotMath.box(size: Vector3, x: number, y: number, z: number, r: number): Box
	local hw, hd = PlotMath.halfExtents(size, r)
	return { minX = x - hw, maxX = x + hw, minY = y, maxY = y + size.Y, minZ = z - hd, maxZ = z + hd }
end

function PlotMath.overlap(a: Box, b: Box, eps: number?): boolean
	local e = eps or 0.05
	return a.minX < b.maxX - e and a.maxX > b.minX + e
		and a.minY < b.maxY - e and a.maxY > b.minY + e
		and a.minZ < b.maxZ - e and a.maxZ > b.minZ + e
end

-- Buildable zone in plot-local space: |x| <= width/2, z in [-length, -StartAreaDepth]
function PlotMath.inZone(b: Box, width: number, length: number): boolean
	local hx = width / 2
	return b.minX >= -hx - 1e-3 and b.maxX <= hx + 1e-3
		and b.maxZ <= -Balance.StartAreaDepth + 1e-3 and b.minZ >= -length - 1e-3
		and b.minY >= 0 and b.minY <= Balance.MaxBuildHeight
end

function PlotMath.cframe(plotCF: CFrame, x: number, y: number, z: number, r: number): CFrame
	return plotCF * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(r), 0)
end

-- World position of a model-local point for a placed object
function PlotMath.worldPoint(plotCF: CFrame, x: number, y: number, z: number, r: number, localPoint: Vector3): Vector3
	return PlotMath.cframe(plotCF, x, y, z, r):PointToWorldSpace(localPoint)
end

-- Snap a desired CENTRE so that the box MIN corner (x,z) lands on the grid (edges of pieces butt together)
function PlotMath.snapCentre(size: Vector3, cx: number, cz: number, r: number, step: number): (number, number)
	local hw, hd = PlotMath.halfExtents(size, r)
	local minX = math.floor((cx - hw) / step + 0.5) * step
	local minZ = math.floor((cz - hd) / step + 0.5) * step
	return minX + hw, minZ + hd
end

function PlotMath.snapY(y: number): number
	local s = Balance.LevelStep
	return math.clamp(math.floor(y / s + 0.5) * s, 0, Balance.MaxBuildHeight)
end

return PlotMath
