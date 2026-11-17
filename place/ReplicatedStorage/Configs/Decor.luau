--!strict
-- Cosmetic catalog (spec 17): a second Coins goal. Prices are provisional (see BALANCE.md). `r` = footprint radius used by the placement rules.
local D = { List = {}, ById = {} }
local function add(id: string, name: string, price: number, r: number, desc: string)
	local d = { id = id, name = name, price = price, r = r, desc = desc }
	D.List[#D.List + 1] = d; D.ById[id] = d
end
add("Rock", "Pebble Rock", 50, 2.5, "A smooth little boulder.")
add("Bush", "Round Bush", 60, 3, "Fluffy and green.")
add("FlowerPatch", "Flower Patch", 80, 3, "Pink, yellow and white blooms.")
add("Mushrooms", "Mushroom Trio", 90, 2, "Red caps with white dots.")
add("BigRock", "Big Rock", 120, 4, "A chunky stack of stones.")
add("Tree", "Round Tree", 150, 4, "Shade for your champions.")
add("PineTree", "Pine Tree", 180, 4, "Three tiers of evergreen.")
add("Lantern", "Garden Lantern", 200, 1.5, "Warm light after dark.")
add("Banner", "Victory Banner", 240, 2, "Show your colours.")
add("CrystalCluster", "Crystal Cluster", 400, 3, "Glowing teal crystals.")
add("Fountain", "Fountain", 900, 7, "Three-tier stone fountain with a glowing pool.")
add("Archway", "Grand Archway", 1500, 8, "A gate fit for a champion's plot.")
return D
