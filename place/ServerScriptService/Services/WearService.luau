--!strict
-- Loads the NPC catalog wear (Configs.NPCWear) once per server with InsertService into ReplicatedStorage.NPCWear, so the server-spawned
-- NPCs AND the client 3D previews (NPCRig) can clone real accessories/clothes. Failures are logged and simply skipped (NPCRig falls back).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Service = {}

function Service.Start()
	local folder = ReplicatedStorage:FindFirstChild("NPCWear") or Instance.new("Folder")
	folder.Name = "NPCWear"
	local Wear = require(ReplicatedStorage.Configs.NPCWear)
	local ids: { [number]: boolean } = {}
	for _, w in Wear do
		for _, h in w.hair or {} do ids[h] = true end
		if w.shirt then ids[w.shirt] = true end
		if w.pants then ids[w.pants] = true end
	end
	local ok, bad = 0, 0
	for id in ids do
		if not folder:FindFirstChild(tostring(id)) then
			local s, model = pcall(function() return InsertService:LoadAsset(id) end)
			local item = s and model and model:GetChildren()[1]
			if item and (item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants")) then
				item.Name = tostring(id)
				for _, d in item:GetDescendants() do      -- strip anything that could run code or play sounds
					if d:IsA("LuaSourceContainer") or d:IsA("Sound") then d:Destroy() end
				end
				item.Parent = folder
				ok += 1
			else
				bad += 1
				warn(("[Wear] could not load %d: %s"):format(id, tostring(model)))
			end
			if model then (model :: Instance):Destroy() end
		end
	end
	folder.Parent = ReplicatedStorage
	print(("[Wear] NPC wear: %d items in store (%d newly loaded, %d failed)"):format(#folder:GetChildren(), ok, bad))   -- S13: "0 ok" only meant "nothing new to load"
end

return Service
