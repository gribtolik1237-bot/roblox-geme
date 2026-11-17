-- BUG-021: a SurfaceGui with the default MaxDistance (0) is culled at moderate range, so world signs went blank from across the lobby.
-- World signage gets a long range: plot PLAY signs, course-save boards and the 5 Hall boards. (An earlier note blamed a "render budget"
-- for black Hall boards; re-tested 2026-11-16: that was lazy first-frame rendering of SurfaceGuis in Studio screen captures, not a budget.)
local RANGE = 600
local function fix(d: Instance)
	if d:IsA("SurfaceGui") and (d:FindFirstAncestor("PlaySign") or d:FindFirstAncestor("SaveBoard") or d:FindFirstAncestor("Hall")) then d.MaxDistance = RANGE end
end
for _, root in { workspace:WaitForChild("PlayerPlots"), workspace:WaitForChild("WorldAssets"):WaitForChild("Hall") } do
	for _, d in root:GetDescendants() do fix(d) end
	root.DescendantAdded:Connect(fix)
end
