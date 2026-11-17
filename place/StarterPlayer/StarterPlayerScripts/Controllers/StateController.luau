--!strict
-- Client mirror of the server's public state. Read-only for the rest of the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local StateController = {}
StateController.State = nil :: any
StateController.Changed = Instance.new("BindableEvent")
local started = false

function StateController.Start()
	if started then return end
	started = true
	Net.on("State", function(snap: any)
		StateController.State = snap
		StateController.Changed:Fire(snap)
	end)
	task.spawn(function()
		for _ = 1, 20 do
			local r = Net.invoke("GetState")
			if r.ok and r.state then
				if not StateController.State then
					StateController.State = r.state
					StateController.Changed:Fire(r.state)
				end
				return
			end
			task.wait(1)
		end
	end)
end

function StateController.Wait(): any
	while not StateController.State do StateController.Changed.Event:Wait() end
	return StateController.State
end

return StateController
