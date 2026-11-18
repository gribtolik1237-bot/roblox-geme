--!nonstrict
-- The server drives the two solid belts. Nearby chevrons scroll locally.
local RunService = game:GetService("RunService")
local Balance = require(game:GetService("ReplicatedStorage").Configs.Balance)
local PromenadeController = {}

local UPDATE_INTERVAL = 1 / 30
local DRAW_RADIUS = 260

function PromenadeController.Start()
	local market = workspace:WaitForChild("WorldAssets"):WaitForChild("MarketPromenade")
	local tracks = {}
	for _, name in { "WestLaneArrows", "EastLaneArrows" } do
		local folder = market:FindFirstChild(name)
		if folder then
			local parts = {}
			for _, part in folder:GetChildren() do
				table.insert(parts, { model = part, base = part.CFrame, anchor = part:GetAttribute("TrackX") })
			end
			table.insert(tracks, {
				parts = parts,
				start = folder:GetAttribute("StartX"),
				length = folder:GetAttribute("Span"),
				speed = Balance.Promenade.BeltSpeed * folder:GetAttribute("Direction"),
			})
		end
	end
	if #tracks == 0 then return end

	local update = 0
	local parts, frames = {}, {}
	RunService.PreRender:Connect(function(dt)
		update += dt
		if update < UPDATE_INTERVAL then return end
		update %= UPDATE_INTERVAL
		local camera = workspace.CurrentCamera
		if not camera or math.abs(camera.CFrame.Z) > DRAW_RADIUS then return end
		local now = workspace:GetServerTimeNow()
		table.clear(parts)
		table.clear(frames)
		for _, track in tracks do
			local shift = (now * track.speed) % track.length
			for _, marker in track.parts do
				local x = track.start + (marker.anchor - track.start + shift) % track.length
				if math.abs(x - camera.CFrame.X) < DRAW_RADIUS or math.abs(marker.model.Position.X - camera.CFrame.X) < DRAW_RADIUS then
					table.insert(parts, marker.model)
					table.insert(frames, marker.base + Vector3.new(x - marker.anchor, 0, 0))
				end
			end
		end
		if #parts > 0 then workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged) end
	end)
end

return PromenadeController
