--!strict
-- Rarity table shared by both shops. 'weight' drives shop appearance chance, 'priceMult' drives cost.
local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarities.Info = {
	Common    = { index = 1, color = Color3.fromRGB(176, 190, 204), weight = 100, priceMult = 1 },
	Uncommon  = { index = 2, color = Color3.fromRGB(96, 214, 120),  weight = 55,  priceMult = 2.5 },
	Rare      = { index = 3, color = Color3.fromRGB(70, 160, 255),  weight = 28,  priceMult = 7 },
	Epic      = { index = 4, color = Color3.fromRGB(184, 104, 255), weight = 12,  priceMult = 22 },
	Legendary = { index = 5, color = Color3.fromRGB(255, 184, 48),  weight = 5,   priceMult = 70 },
	Mythic    = { index = 6, color = Color3.fromRGB(255, 82, 120),   weight = 1.8, priceMult = 220 },
	Secret    = { index = 7, color = Color3.fromRGB(40, 255, 224),   weight = 0.6, priceMult = 700 },
}

function Rarities.index(name: string): number
	local info = Rarities.Info[name]
	return info and info.index or 1
end

return Rarities
