--!nonstrict
-- Sound effects + background music (spec 24). M mutes everything.
-- SFX: ORIGINAL cues synthesised for TRAP LAB (TRAP_LAB/assets/make_sfx.py -> assets/audio/*.wav, uploaded via Open Cloud, ours);
-- Rebirth = Pro Sound Effects (Roblox-licensed library). Each cue keeps a built-in Roblox sound as a FALLBACK (4th field) used when the
-- uploaded asset fails to load (e.g. while Roblox audio moderation is still "Reviewing").
-- Music: APM Music (Roblox-licensed library): "Spring Weaver" (bright pizzicato, playful) + "Puzzle Waltz A", quiet looping playlist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local Net = require(ReplicatedStorage.Shared.Net)
local HUDController = require(script.Parent.HUDController)
local StateController = require(script.Parent.StateController)

local SFX = {}
local LIB = {      -- name = { id, volume, playbackSpeed?, fallback built-in file }
	open = { "rbxassetid://113860525578653", 0.3, nil, "switch.wav" },
	coin = { "rbxassetid://132271313002353", 0.35, nil, "electronicpingshort.wav" },
	spend = { "rbxassetid://92084588790572", 0.35, nil, "metal.mp3" },
	place = { "rbxassetid://117186539684798", 0.5, nil, "snap.mp3" },
	checkpoint = { "rbxassetid://83215067897615", 0.4, nil, "electronicpingshort.wav" },
	clear = { "rbxassetid://115227221666458", 0.5, nil, "victory.wav" },
	fall = { "rbxassetid://127176778891626", 0.4, nil, "uuhhh.mp3" },
	rebirth = { "rbxassetid://9116394545", 0.55, nil, "bass.wav" },   -- Pro Sound Effects: "Magic Glows Soft Clusters Of Chiming Hits 1"
	-- audit 3 (audio): licensed Pro Sound Effects cues for events that used to be silent
	buy = { "rbxassetid://9113867249", 0.4, nil, "snap.mp3" },                    -- "Computer Beeps And Tones Synth Hits Bright 2"
	deny = { "rbxassetid://9113867249", 0.4, 0.55, "uuhhh.mp3" },                -- the same beep pitched down = a dull "no"
	teleport = { "rbxassetid://9125647212", 0.45, nil, "switch.wav" },           -- "Magic Whooshes Pass Bys Metallic Shimmering"
	claim = { "rbxassetid://9126073001", 0.45, nil, "electronicpingshort.wav" }, -- "Synth Sparkle Tone High Pitch Bell Tone Ding"
	knock = { "rbxassetid://9113535048", 0.5, nil, "bass.wav" },                 -- "Body Slam 2" (Fight - Hits)
}
local MUSIC = { "rbxassetid://9042623779", "rbxassetid://1847525235" }   -- APM Music: Spring Weaver, Puzzle Waltz A
local MUSIC_VOLUME = 0.22
local group, musicGroup, muted = nil, nil, false
local failed = {}            -- ids that could not be fetched -> use the fallback
local last = {}

local function resolve(def)
	if failed[def[1]] and def[4] then return "rbxasset://sounds/" .. def[4] end
	return def[1]
end

function SFX.Play(name: string)
	local def = LIB[name]
	if not def or muted then return end
	local now = os.clock()
	if now - (last[name] or 0) < 0.12 then return end            -- never a machine gun
	last[name] = now
	local s = Instance.new("Sound")
	s.SoundId = resolve(def); s.Volume = def[2]; s.SoundGroup = group
	s.PlaybackSpeed = def[3] or (1 + (math.random() - 0.5) * 0.08)
	s.Parent = group
	s:Play()
	task.delay(6, function() s:Destroy() end)
end

-- audit 2.1: the playlist loop ends when sound is muted (M) and is started again on unmute (no idle loop while muted)
local musicTrack: Sound? = nil
local musicIndex = 1
local musicRunning = false
local function startMusic()
	if musicRunning then return end
	musicRunning = true
	if not musicTrack then
		local t = Instance.new("Sound"); t.Name = "Music"; t.Volume = MUSIC_VOLUME; t.SoundGroup = musicGroup; t.Parent = musicGroup
		musicTrack = t
	end
	local track = musicTrack :: Sound
	while not muted do
		track.SoundId = MUSIC[musicIndex]
		track.TimePosition = 0
		track:Play()
		local t0 = os.clock()
		while not track.IsLoaded and os.clock() - t0 < 10 and not muted do task.wait(0.25) end
		if track.IsLoaded and track.TimeLength > 1 then
			while track.IsPlaying and not muted do task.wait(0.5) end
		else task.wait(5) end
		if muted then break end
		musicIndex = musicIndex % #MUSIC + 1
	end
	track:Stop()
	musicRunning = false
end

function SFX.Start()
	group = Instance.new("SoundGroup"); group.Name = "TrapLabSFX"; group.Volume = 0.8; group.Parent = SoundService
	musicGroup = Instance.new("SoundGroup"); musicGroup.Name = "TrapLabMusic"; musicGroup.Volume = 1; musicGroup.Parent = SoundService
	task.spawn(function()      -- warm the cache so the first cue is not late; remember what failed (moderation pending etc.)
		local pre = {}
		for _, d in LIB do local s = Instance.new("Sound"); s.SoundId = d[1]; table.insert(pre, s) end
		pcall(function()
			ContentProvider:PreloadAsync(pre, function(id, status)
				if status ~= Enum.AssetFetchStatus.Success then failed[id] = true end
			end)
		end)
		for _, s in pre do s:Destroy() end
	end)
	task.spawn(startMusic)
	local prev = { coins = nil, rebirth = nil, count = nil }
	StateController.Changed.Event:Connect(function(s)
		if not s then return end
		if prev.coins ~= nil then
			if s.coins > prev.coins then SFX.Play("coin") elseif s.coins < prev.coins then SFX.Play("spend") end
			if s.rebirth > prev.rebirth then SFX.Play("rebirth") end
			if s.plot and prev.count and s.plot.count > prev.count then SFX.Play("place") end
		end
		prev.coins, prev.rebirth, prev.count = s.coins, s.rebirth, s.plot and s.plot.count or prev.count
	end)
	Net.on("RunState", function(p)
		if p.state == "progress" then SFX.Play("checkpoint")
		elseif p.state == "fall" then SFX.Play("fall")
		elseif p.state == "end" and p.outcome == "cleared" then SFX.Play("clear") end
	end)
	Net.on("NpcState", function(p)
		if p.state == "end" then SFX.Play(if p.outcome == "finished" then "clear" else "fall") end
	end)
	-- window open cue: every <Something>Window frame of the HUD
	local function hook(f)
		if f:IsA("Frame") and f.Name:match("Window$") then f:GetPropertyChangedSignal("Visible"):Connect(function() if f.Visible then SFX.Play("open") end end) end
	end
	local gui = HUDController.Gui
	for _, c in gui:GetChildren() do hook(c) end
	gui.ChildAdded:Connect(hook)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.M then return end
		muted = not muted
		musicGroup.Volume = if muted then 0 else 1
		if not muted then task.spawn(startMusic) end
		HUDController.Toast(if muted then "Sound off (M)" else "Sound on (M)", "info")
	end)
end

return SFX
