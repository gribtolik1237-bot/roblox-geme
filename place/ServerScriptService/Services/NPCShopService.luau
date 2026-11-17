--!strict
-- NPC shop catalog: NPCs are PERMANENT collection entries (never consumed). A bought NPC goes into the first free quick slot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local NPCs = require(ReplicatedStorage.Configs.NPCs)
local ShopCore = require(script.Parent.ShopCore)

local Service = {}

function Service.Start()
	ShopCore.register({
		kind = "npc", salt = Balance.ShopAssortmentSalt.Npc, catalog = NPCs.List, count = Balance.ShopNpcSlots,
		staples = nil,
		groupOf = nil,
		canBuy = function(profile: any, d: any): string?
			if profile.npcs[d.id] then return "Owned" end
			return nil
		end,
		grant = function(_: Player, profile: any, d: any)
			profile.npcs[d.id] = true
			for i = 1, Balance.NpcSlots do
				if not profile.slots[i] then profile.slots[i] = d.id; break end
			end
		end,
	})
end

return Service
