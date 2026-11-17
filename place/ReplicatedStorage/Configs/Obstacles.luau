--!strict
-- Obstacle catalog (first vertical-slice set). Model-space: base centre at origin, forward (travel) = -Z.
-- entry = back edge (+Z), exit = front edge (-Z), both at standing height. 'weight' = stage weight for rewards/difficulty.
-- npc.supported=false => NPC-incompatible (shown in UI, never paid as an NPC stage).
local V = Vector3.new
local O = { Categories = { "Basic", "Moving", "Dangerous", "Traps", "Special", "Premium" }, List = {}, ById = {} }

local function add(d: any)
	d.top = d.top or d.size.Y
	d.entryY = d.entryY or d.top
	d.exitY = d.exitY or d.top
	d.entry = V(0, d.entryY, d.size.Z / 2)
	d.exit = V(0, d.exitY, -d.size.Z / 2)
	d.rebirth = d.rebirth or 0
	d.npc = d.npc or { supported = true }
	d.behavior = d.behavior or { kind = "static" }
	d.hazard = d.hazard or "none"        -- none | kill | knock
	d.stage = d.stage ~= false           -- counts as a paid stage
	-- symmetric front/back (session 6): turning it 180 degrees changes nothing, so r is stored modulo 180 (an owner course built at r=180
	-- had entry/exit swapped and never linked)
	d.symmetric = (d.behavior.kind == "static" or d.behavior.kind == "finish") and d.entryY == d.exitY and d.hazard == "none" and d.npc.hops == nil
	O.List[#O.List + 1] = d
	O.ById[d.id] = d
end

-- BASIC ------------------------------------------------------------------------------------------------
add{ id = "BasicPlatform", name = "Basic Platform", category = "Basic", rarity = "Common", price = 40,
	size = V(12, 2, 12), weight = 0.3, stage = true, staple = true,
	desc = "A sturdy 12x12 platform. The backbone of every course." }
add{ id = "SmallJumpPlatform", name = "Small Jump Platform", category = "Basic", rarity = "Common", price = 55,
	size = V(6, 2, 6), weight = 0.7,
	desc = "A tiny 6x6 landing pad. Precision jumps only." }
add{ id = "NarrowBridge", name = "Narrow Bridge", category = "Basic", rarity = "Common", price = 90,
	size = V(4, 2, 24), weight = 1.1, npc = { supported = true, unstable = true },
	desc = "Only 4 studs wide. Balance matters - one wobble and you're falling." }
add{ id = "RampUp", name = "Ramp Up", category = "Basic", rarity = "Uncommon", price = 110,
	size = V(8, 6, 12), top = 6, entryY = 2, exitY = 6, weight = 0.5,
	desc = "A 12-stud ramp that lifts the course 4 studs higher." }
add{ id = "MovingPlatform", name = "Moving Platform", category = "Basic", rarity = "Uncommon", price = 220,
	size = V(10, 3, 34), top = 2, weight = 1.7, npc = { supported = true, unstable = true },
	behavior = { kind = "ferry", travel = 16, move = 3.5, pause = 0.8, part = "Ferry" },
	desc = "A ferry that shuttles across a 20-stud void. Time your boarding." }

-- MOVING -----------------------------------------------------------------------------------------------
add{ id = "RotatingBar", name = "Rotating Bar", category = "Moving", rarity = "Uncommon", price = 260,
	size = V(16, 5, 16), top = 2, weight = 1.5, hazard = "knock",
	behavior = { kind = "spin", dps = 80, part = "Bar", reach = 7.2, low = 3.7 },
	desc = "A low spinner sweeps the whole deck. Jump it or get flung." }

-- DANGEROUS --------------------------------------------------------------------------------------------
add{ id = "LavaFloor", name = "Lava Floor", category = "Dangerous", rarity = "Common", price = 130,
	size = V(14, 3, 24), top = 2, weight = 1.2, hazard = "kill",
	behavior = { kind = "static", hazardPart = "Lava" },
	-- NPC adapter: takeoff/landing points (model space) for each hop across the lava
	npc = { supported = true, hops = {
		{ take = V(0, 2, 9.0), land = V(0, 2, 5.5) }, { take = V(0, 2, 4.4), land = V(0, 2, 0.5) },
		{ take = V(0, 2, -0.6), land = V(0, 2, -4.5) }, { take = V(0, 2, -5.6), land = V(0, 2, -9) } } },
	desc = "A glowing lava pit with three wide stepping stones. Don't touch the floor!" }
add{ id = "FallingPlatform", name = "Falling Platform", category = "Dangerous", rarity = "Uncommon", price = 160,
	size = V(8, 2, 8), weight = 0.9, npc = { supported = true, unstable = true },
	behavior = { kind = "falling", delay = 0.7, respawn = 3.5, part = "Tile" },
	desc = "Starts shaking when stepped on and drops after 0.7 seconds." }

-- SPECIAL ----------------------------------------------------------------------------------------------
add{ id = "SpeedPlatform", name = "Speed Platform", category = "Special", rarity = "Uncommon", price = 180,
	size = V(8, 2, 16), weight = 0.4, behavior = { kind = "speed", boost = 28, part = "Deck" },
	desc = "Doubles your sprint while you stand on it. Mind the next jump!" }
add{ id = "TeleportPlatform", name = "Teleport Platform", category = "Special", rarity = "Rare", price = 900, rebirth = 1,
	size = V(8, 2, 34), weight = 1.0,
	behavior = { kind = "teleport", pad = "Pad", dest = "Dest" },
	npc = { supported = false, reason = "Teleporting would skip the course. Players only." },
	desc = "Step on the glowing ring to jump across a 22-stud lava gap. NPCs can't use it." }
add{ id = "FinishPad", name = "Finish Pad", category = "Special", rarity = "Common", price = 0, free = true, unique = true,
	size = V(14, 14, 14), top = 2, weight = 0, stage = false, behavior = { kind = "finish", part = "Goal" },
	desc = "The finish line. Every course needs exactly one." }

-- ===== second wave ===============================================================================================
-- behavior kinds are implemented in ServerScriptService.Systems.Behaviors (deterministic functions of server time)
add{ id = "RotatingPlatform", name = "Rotating Platform", category = "Basic", rarity = "Uncommon", price = 200,
	size = V(14, 3, 24), top = 2, weight = 1.4, npc = { supported = true, unstable = true },
	behavior = { kind = "rotplat", dps = 36 },
	desc = "A slowly spinning disc between two docks. Hop on, ride, hop off." }
add{ id = "ConveyorBelt", name = "Conveyor Belt", category = "Special", rarity = "Uncommon", price = 220,
	size = V(8, 2, 18), weight = 0.6, behavior = { kind = "belt", part = "Belt", chevrons = "Chevrons", speed = 14 },
	npc = { supported = true, belt = 14 },
	desc = "A belt that carries you forward fast. Great for long jumps!" }
add{ id = "ReverseConveyor", name = "Reverse Conveyor", category = "Special", rarity = "Uncommon", price = 260,
	size = V(8, 2, 18), weight = 1.5, behavior = { kind = "belt", part = "Belt", chevrons = "Chevrons", speed = -9 },
	npc = { supported = true, belt = -9 },
	desc = "The belt runs against you. Slow runners will never make it up!" }
add{ id = "SlidingBlock", name = "Sliding Block", category = "Moving", rarity = "Uncommon", price = 240,
	size = V(17, 7, 16), top = 2, weight = 1.5, hazard = "knock",
	behavior = { kind = "slide", parts = { "Block0" }, axis = "x", amp = 5.5, period = 3.4, phases = { 0 }, size = V(5, 5, 5), y = 4.5, haz = "Knock", jumpable = false },
	desc = "A heavy block slides across the deck. Slip past when it's away." }
add{ id = "MovingWall", name = "Moving Wall", category = "Moving", rarity = "Rare", price = 650, rebirth = 1,
	size = V(16, 11, 26), top = 2, weight = 2.0, hazard = "knock",
	behavior = { kind = "slide", parts = { "Wall0", "Wall1" }, zs = { 5, -5 }, axis = "x", amp = 4.5, period = 4.6, phases = { 0, 0.5 }, size = V(9, 9, 1.6), y = 6.5, haz = "Knock", jumpable = false },
	desc = "Two tall walls sweep side to side, one after the other." }
add{ id = "SwingingHammer", name = "Swinging Hammer", category = "Moving", rarity = "Rare", price = 720, rebirth = 1,
	size = V(14, 16, 18), top = 2, weight = 2.1, hazard = "knock",
	behavior = { kind = "swing", parts = { "Hammer0" }, zs = { 0 }, amp = 62, period = 3.0, phases = { 0 }, arm = 10, pivotY = 13.5, head = V(4.2, 4.2, 4.2), haz = "Knock" },
	desc = "A giant hammer swings over the walkway. Time it right." }
add{ id = "MovingLaser", name = "Moving Laser", category = "Moving", rarity = "Epic", price = 3200, rebirth = 2,
	size = V(16, 6, 24), top = 2, weight = 2.7, hazard = "kill",
	behavior = { kind = "sweep", parts = { "Beam0" }, amps = { 9 }, periods = { 3.6 }, phases = { 0 }, y = 2.9, size = V(14.4, 0.5, 0.5), haz = "Kill", jumpable = true },
	desc = "A deadly beam sweeps the whole deck. Jump it!" }
add{ id = "SpikePlatform", name = "Spike Platform", category = "Traps", rarity = "Rare", price = 680, rebirth = 1,
	size = V(12, 4, 20), top = 2, weight = 2.2, hazard = "kill",
	behavior = { kind = "periodic", variant = "spikes", period = 3.4, activeDur = 1.3, warn = 0.4,
		zones = { { pos = V(0, 3, 0), size = V(11, 2.4, 15.6), phase = 0 } } },
	desc = "Spikes shoot up in a rhythm. Cross while they're down." }
add{ id = "ElectricFloor", name = "Electric Floor", category = "Traps", rarity = "Rare", price = 820, rebirth = 2,
	size = V(12, 2, 20), top = 2, weight = 2.3, hazard = "kill",
	behavior = { kind = "periodic", variant = "electric", period = 3.2, activeDur = 1.3, warn = 0.35,
		zones = { { pos = V(-3, 2.6, 0), size = V(5.6, 1.4, 19), phase = 0, tag = "TileL" }, { pos = V(3, 2.6, 0), size = V(5.6, 1.4, 19), phase = 0.5, tag = "TileR" } } },
	desc = "The left and right halves charge in turns. Pick the dark lane." }
add{ id = "FireTrap", name = "Fire Trap", category = "Traps", rarity = "Epic", price = 2800, rebirth = 2,
	size = V(10, 8, 34), top = 2, weight = 2.8, hazard = "kill",
	behavior = { kind = "periodic", variant = "fire", period = 2.8, activeDur = 0.9, warn = 0.4,
		zones = { { pos = V(0, 5.5, 12), size = V(7.6, 7, 1.8), phase = 0, tag = "Flame1" }, { pos = V(0, 5.5, 4), size = V(7.6, 7, 1.8), phase = 0.25, tag = "Flame2" },
			{ pos = V(0, 5.5, -4), size = V(7.6, 7, 1.8), phase = 0.5, tag = "Flame3" }, { pos = V(0, 5.5, -12), size = V(7.6, 7, 1.8), phase = 0.75, tag = "Flame4" } } },
	desc = "Flame walls burst in a wave. Dash through the gaps." }
add{ id = "DisappearingPlatform", name = "Disappearing Platform", category = "Special", rarity = "Rare", price = 560, rebirth = 1,
	size = V(6, 2, 22), top = 2, weight = 2.0,
	behavior = { kind = "vanish", tiles = { "T1", "T2", "T3" }, period = 3.0, hidden = 1.2, phases = { 0.4, 0.1667, 0.9333 } },   -- a wave: each tile appears 0.7 s after the previous one, so the hop chain is possible
	npc = { supported = true, vanish = true, unstable = true },
	desc = "Three glass tiles blink out one by one. Hop on the solid one!" }
add{ id = "BouncePad", name = "Bounce Pad", category = "Special", rarity = "Rare", price = 600, rebirth = 1,
	size = V(8, 10, 20), top = 10, entryY = 2, exitY = 10, weight = 1.8,
	behavior = { kind = "bounce", part = "Bounce", vy = 78, hv = 18 },
	npc = { supported = true, bounce = true },
	desc = "Springs you 8 studs up onto a high deck. Keep running forward!" }
add{ id = "InvisiblePlatform", name = "Invisible Platform", category = "Special", rarity = "Epic", price = 2600, rebirth = 3,
	size = V(10, 2, 10), top = 2, weight = 1.6,
	behavior = { kind = "reveal", part = "Slab" },
	npc = { supported = false, reason = "NPCs can't see invisible platforms. Players only." },
	desc = "It's there... you just can't see it. A step reveals it for a moment." }
add{ id = "HammerGauntlet", name = "Hammer Gauntlet", category = "Premium", rarity = "Legendary", price = 14000, rebirth = 4,
	size = V(14, 18, 38), top = 2, weight = 3.6, hazard = "knock",
	behavior = { kind = "swing", parts = { "Hammer0", "Hammer1" }, zs = { 9.5, -9.5 }, amp = 66, period = 2.6, phases = { 0, 0.5 }, arm = 10, pivotY = 13.5, head = V(4.6, 4.6, 4.6), haz = "Knock" },
	desc = "Two huge hammers swing against each other. Only the brave." }
add{ id = "LaserLabyrinth", name = "Laser Labyrinth", category = "Premium", rarity = "Mythic", price = 60000, rebirth = 6,
	size = V(18, 6, 30), top = 2, weight = 4.4, hazard = "kill",
	behavior = { kind = "sweep", parts = { "Beam0", "Beam1", "Beam2" }, amps = { 11, 11, 11 }, periods = { 3.0, 4.1, 5.3 }, phases = { 0, 0.33, 0.66 }, y = 2.9, size = V(16.4, 0.5, 0.5), haz = "Kill", jumpable = true },
	desc = "Three lasers on three different rhythms. A masterpiece of pain." }
add{ id = "PrismSpinner", name = "Prism Spinner", category = "Premium", rarity = "Secret", price = 200000, rebirth = 8,
	size = V(20, 10, 20), top = 2, weight = 5.2, hazard = "knock",
	behavior = { kind = "spin2", bars = { { part = "BarLow", dps = 70, y = 3.1, reach = 9.2, jumpable = true }, { part = "BarHigh", dps = -48, y = 8.0, reach = 9.2, jumpable = false } } },
	desc = "Two bars spin in opposite directions at two heights. Jump the low one, mind the high one." }

return O
