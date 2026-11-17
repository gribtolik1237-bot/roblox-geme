--!strict
-- 21 starter NPC testers (3 per rarity). Original Roblox-style looks; Bacon/Noob/Guest are archetype nods only.
-- stats are 1..10 (see Balance.NpcStatMap). Trade-offs are deliberate: rarity is potential, not a guarantee.
local function C(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

local NPCs = { List = {}, ById = {} }

local function add(d: any)
	d.stats = d.stats
	NPCs.List[#NPCs.List + 1] = d
	NPCs.ById[d.id] = d
end
local function S(speed: number, jump: number, balance: number, recovery: number, control: number)
	return { speed = speed, jump = jump, balance = balance, recovery = recovery, control = control }
end

-- look: skin/shirt/pants colours, accessories (built by Shared/NPCRig), scale, material
-- Common
add{ id = "Bacon", name = "Bacon", rarity = "Common", price = 400 --[[audit 4.1: was 150]], rebirth = 0, stats = S(5,5,5,4,5),
	blurb = "Reliable all-rounder with a sizzling hairdo.", look = { skin = C(255,204,153), shirt = C(70,110,200), pants = C(60,60,70), acc = {"BaconHair"} } }
add{ id = "Noob", name = "Noob", rarity = "Common", price = 350 --[[audit 4.1: was 120]], rebirth = 0, stats = S(4,4,3,6,3),
	blurb = "Clumsy but stubborn. Gets up again and again.", look = { skin = C(245,205,48), shirt = C(13,105,172), pants = C(75,151,75), acc = {} } }
add{ id = "Starter", name = "Starter", rarity = "Common", price = 0, rebirth = 0, free = true, stats = S(5,5,4,3,4),
	blurb = "Your first tester. Free for everyone.", look = { skin = C(234,184,146), shirt = C(240,240,240), pants = C(90,90,100), acc = {"SimpleCap"} } }
-- Uncommon
add{ id = "Guest", name = "Guest", rarity = "Uncommon", price = 380, rebirth = 0, stats = S(6,5,5,4,5),
	blurb = "A calm visitor with a steady stride.", look = { skin = C(255,204,153), shirt = C(128,128,128), pants = C(40,40,40), acc = {"SideHair"} } }
add{ id = "Builder", name = "Builder", rarity = "Uncommon", price = 420, rebirth = 0, stats = S(4,6,7,5,5),
	blurb = "Hard hat, steady feet. Loves narrow bridges.", look = { skin = C(234,184,146), shirt = C(255,150,40), pants = C(60,80,120), acc = {"HardHat"} } }
add{ id = "Runner", name = "Runner", rarity = "Uncommon", price = 460, rebirth = 0, stats = S(8,5,3,3,5),
	blurb = "Fast, but wobbly on thin surfaces.", look = { skin = C(198,134,66), shirt = C(255,70,70), pants = C(30,30,30), acc = {"Headband"} } }
-- Rare
add{ id = "Ninja", name = "Ninja", rarity = "Rare", price = 1100, rebirth = 1, stats = S(7,8,6,4,7),
	blurb = "Silent, agile and precise.", look = { skin = C(234,184,146), shirt = C(30,30,38), pants = C(30,30,38), acc = {"NinjaMask", "Sash"} } }
add{ id = "Astronaut", name = "Astronaut", rarity = "Rare", price = 1250, rebirth = 1, stats = S(5,9,4,5,6),
	blurb = "Low-gravity legs: huge jumps, shaky landings.", look = { skin = C(234,184,146), shirt = C(235,235,240), pants = C(235,235,240), acc = {"SpaceHelmet", "Backpack"} } }
add{ id = "Knight", name = "Knight", rarity = "Rare", price = 1400, rebirth = 2, stats = S(4,4,9,8,6),
	blurb = "Heavy armour: slow, hard to knock over.", look = { skin = C(234,184,146), shirt = C(150,155,165), pants = C(110,115,125), acc = {"KnightHelm", "Pauldrons"}, material = Enum.Material.Metal } }
-- Epic
add{ id = "Cyber", name = "Cyber", rarity = "Epic", price = 4200, rebirth = 2, stats = S(8,7,6,5,9),
	blurb = "Targeting visor and pixel-perfect control.", look = { skin = C(70,80,100), shirt = C(20,24,40), pants = C(20,24,40), acc = {"VisorStrip", "NeonTrim"}, neon = C(0,230,255) } }
add{ id = "Frost", name = "Frost", rarity = "Epic", price = 4600, rebirth = 3, stats = S(6,6,8,6,7),
	blurb = "Ice-cool balance on any surface.", look = { skin = C(190,230,255), shirt = C(120,190,240), pants = C(90,150,210), acc = {"IceCrown"}, material = Enum.Material.Ice } }
add{ id = "Blaze", name = "Blaze", rarity = "Epic", price = 5000, rebirth = 3, stats = S(9,7,4,5,6),
	blurb = "Blazing speed. Don't expect a gentle landing.", look = { skin = C(255,150,70), shirt = C(200,40,20), pants = C(60,20,20), acc = {"FlameHair"}, neon = C(255,120,20) } }
-- Legendary
add{ id = "Golden", name = "Golden", rarity = "Legendary", price = 14000, rebirth = 4, stats = S(7,7,7,7,7),
	blurb = "Perfectly balanced in every way.", look = { skin = C(255,200,60), shirt = C(255,190,40), pants = C(220,160,30), acc = {"Crown"}, material = Enum.Material.Metal } }
add{ id = "Titan", name = "Titan", rarity = "Legendary", price = 15500, rebirth = 5, stats = S(5,5,10,9,6),
	blurb = "Colossal armour. Almost impossible to topple.", look = { skin = C(150,150,160), shirt = C(90,95,110), pants = C(70,75,90), acc = {"HeavyArmor"}, scale = 1.2, material = Enum.Material.Metal } }
add{ id = "Angel", name = "Angel", rarity = "Legendary", price = 17000, rebirth = 5, stats = S(7,9,6,6,8),
	blurb = "Floaty jumps and graceful control. Wings are cosmetic.", look = { skin = C(255,235,215), shirt = C(255,255,255), pants = C(245,245,250), acc = {"Halo", "Wings"} } }
-- Mythic
add{ id = "Shadow", name = "Shadow", rarity = "Mythic", price = 52000, rebirth = 6, stats = S(9,8,6,5,9),
	blurb = "A flicker in the dark. Blindingly quick.", look = { skin = C(30,26,44), shirt = C(20,18,30), pants = C(20,18,30), acc = {"Hood"}, neon = C(150,60,255) } }
add{ id = "Galaxy", name = "Galaxy", rarity = "Mythic", price = 58000, rebirth = 7, stats = S(7,10,5,8,7),
	blurb = "Stardust legs: the highest jumps of all.", look = { skin = C(60,40,120), shirt = C(40,24,90), pants = C(30,20,70), acc = {"StarField"}, neon = C(200,160,255) } }
add{ id = "Crystal", name = "Crystal", rarity = "Mythic", price = 64000, rebirth = 7, stats = S(6,6,10,10,5),
	blurb = "Unshakable, but not very precise.", look = { skin = C(160,240,235), shirt = C(110,220,230), pants = C(80,190,215), acc = {"CrystalShards"}, material = Enum.Material.Glass } }
-- Secret
add{ id = "Glitch", name = "Glitch", rarity = "Secret", price = 160000, rebirth = 8, stats = S(10,8,3,10,6),
	blurb = "Unstable code in a body. Fast and it never stays down.", look = { skin = C(40,255,160), shirt = C(20,20,20), pants = C(255,30,120), acc = {"GlitchBlocks"}, neon = C(40,255,160) } }
add{ id = "Overlord", name = "Overlord", rarity = "Secret", price = 190000, rebirth = 9, stats = S(9,9,9,6,8),
	blurb = "Rules the lab. Strong everywhere, a touch reckless.", look = { skin = C(70,20,30), shirt = C(30,10,20), pants = C(30,10,20), acc = {"HornCrown", "Cape"} } }
add{ id = "Spectrum", name = "Spectrum", rarity = "Secret", price = 230000, rebirth = 9, stats = S(8,8,8,8,10),
	blurb = "Every colour, every skill. Flawless control.", look = { skin = C(255,255,255), shirt = C(255,255,255), pants = C(255,255,255), acc = {"RainbowHalo"}, rainbow = true } }

return NPCs
