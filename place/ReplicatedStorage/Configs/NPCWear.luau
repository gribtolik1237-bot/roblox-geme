-- Real Roblox catalog wear for the NPC testers (session 7, owner: "NPC models look bad" - the glued-block hair/hats read as homemade next
-- to the references, where sellers are ordinary dressed Roblox avatars). All items are FREE, made by Roblox (catalog search
-- CreatorName = Roblox, MaxPrice = 0) and loaded by the server with InsertService (Services.WearService) into ReplicatedStorage.NPCWear.
-- hair: accessory ids (hair/hats), shirt/pants: classic clothing ids, keep: which original procedural pieces stay (iconic gear only).
-- If an item fails to load, NPCRig falls back to the old procedural look for that NPC. Body size/physics are untouched.
return {
	Bacon = { hair = { 63690008 }, shirt = 398635081, pants = 398634487, keep = {} },            -- Pal Hair, blue plaid shirt, nice jeans
	Noob = { hair = {}, keep = {} },                                                               -- classic: colours only
	Starter = { hair = { 607702162 }, shirt = 607785314, pants = 382537569, keep = {} },         -- Roblox cap, Roblox jacket, black jeans
	Guest = { hair = { 9243992729 }, shirt = 144076436, pants = 382538503, keep = {} },          -- short & sleek, striped shirt + denim jacket
	Builder = { hair = {}, pants = 144076760, keep = { "HardHat" } },                             -- keeps the hard hat
	Runner = { hair = { 7193442167 }, shirt = 382538059, pants = 382537950, keep = {} },         -- ponytail, green jersey, denim shorts
	Ninja = { hair = { 617605556 }, keep = { "Sash" } },                                           -- mystery hood + sash
	Astronaut = { hair = {}, keep = { "SpaceHelmet", "Backpack" } },
	Knight = { hair = {}, keep = { "KnightHelm", "Pauldrons" } },
	Cyber = { hair = { 3814474927 }, keep = { "VisorStrip", "NeonTrim" } },                        -- cool side shave
	Frost = { hair = { 451221329 }, keep = {} },                                                    -- true blue hair
	Blaze = { hair = { 9244038785 }, keep = { "NeonTrim" } },                                       -- surfer, red + glowing fire belt
	Golden = { hair = { 376524487 }, keep = { "Crown" } },                                         -- spiky blond + crown
	Titan = { hair = { 7193450455 }, keep = { "HeavyArmor" } },                                     -- curly afro + armour
	Angel = { hair = { 376526888 }, keep = { "Halo", "Wings" } },                                   -- straight blond
	Shadow = { hair = { 9174355709 }, keep = { "NeonTrim" } },                                      -- sideswept dreads + purple glow
	Galaxy = { hair = { 3814476174 }, keep = { "StarField" } },                                     -- colourful braids
	Crystal = { hair = { 451220849 }, keep = { "CrystalShards" } },                                 -- lavender updo
	Glitch = { hair = { 9174354743 }, keep = { "GlitchBlocks" } },                                  -- top knot
	Overlord = { hair = { 1772336109 }, keep = { "HornCrown", "Cape" } },                           -- ground-length hair
	Spectrum = { hair = { 7193448988 }, keep = { "RainbowHalo" } },                                 -- straight bangs
}
