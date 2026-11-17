--!strict
-- NPC slots (quick-select) + placement on the owner's NPC start pads + the active-NPC limit (spec 9.2, 10.7).
-- A placed NPC counts as ACTIVE from placement until its attempt ends and the model is cleaned up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Configs.Balance)
local Progression = require(ReplicatedStorage.Configs.Progression)
local NPCs = require(ReplicatedStorage.Configs.NPCs)
local Rarities = require(ReplicatedStorage.Configs.Rarities)
local Net = require(ReplicatedStorage.Shared.Net)
local NPCRig = require(ReplicatedStorage.Shared.NPCRig)

local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateSync = require(script.Parent.StateSync)
local SessionService = require(script.Parent.SessionService)
local CourseValidationService = require(script.Parent.CourseValidationService)
local Brain = require(script.Parent.NPCBrainService)
local Traversal = require(script.Parent.ObstacleTraversalService)
local Collisions = require(script.Parent.Parent.Systems.Collisions)
local NPCAnimator = require(script.Parent.Parent.Systems.NPCAnimator)

local Service = {}
Service.RecallRequested = Instance.new("BindableEvent")   -- (player, pad) a running NPC was recalled

local NpcTypes = require(script.Parent.Parent.Systems.NpcTypes)
type PadEntry = NpcTypes.PadEntry

local pads: { [Player]: { [number]: PadEntry } } = {}   -- [player] = { [padIndex] = { npcId, status = "placed"|"running", model, stage, total } }

local function active(player: Player): number local n = 0 for _ in pads[player] or {} do n += 1 end return n end
local function serverTotal(): number local n = 0 for _, t in pads do for _ in t do n += 1 end end return n end
function Service.Active(player: Player): number return active(player) end
function Service.Entry(player: Player, pad: number): PadEntry? return pads[player] and pads[player][pad] end
function Service.All(player: Player): { [number]: PadEntry } return pads[player] or {} end
function Service.ServerTotal(): number return serverTotal() end

local function nameTag(model: Model, def: any)
	local head = model:FindFirstChild("Head")
	if not head then return end
	local g = Instance.new("BillboardGui"); g.Name = "NameTag"; g.Size = UDim2.fromOffset(160, 44); g.StudsOffset = Vector3.new(0, 2.8, 0)
	g.MaxDistance = 70; g.AlwaysOnTop = false; g.Adornee = head; g.Parent = head
	local function lbl(text: string, y: number, h: number, color: Color3, size: number)
		local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Size = UDim2.new(1, 0, 0, h); l.Position = UDim2.fromOffset(0, y)
		l.Font = Enum.Font.FredokaOne; l.Text = text; l.TextSize = size; l.TextColor3 = color; l.TextStrokeTransparency = 0.3; l.Parent = g
	end
	lbl(def.name, 0, 24, Color3.new(1, 1, 1), 22)
	lbl(def.rarity, 24, 16, Rarities.Info[def.rarity].color, 14)
end

local function spawnModel(player: Player, plot: any, pad: number, def: any): Model
	local model = NPCRig.build(def.id) :: Model
	local m = Brain.Mapped(def.stats)
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.WalkSpeed = m.walkSpeed; hum.UseJumpPower = true; hum.JumpPower = m.jumpPower; hum.AutoRotate = true
	local pos = plot.cf:PointToWorldSpace(PlotService.PadLocal(pad) + Vector3.new(0, 3.9, 0))
	model:PivotTo(CFrame.lookAt(pos, pos + plot.cf.LookVector))
	model:SetAttribute("OwnerId", player.UserId); model:SetAttribute("Pad", pad); model:SetAttribute("Npc", true)
	Collisions.Apply(model, "NPC")
	model.Parent = plot.npcs
	pcall(function() (model:FindFirstChild("HumanoidRootPart") :: BasePart):SetNetworkOwner(nil) end)   -- the SERVER simulates NPC physics
	NPCAnimator.Attach(model)
	nameTag(model, def)
	return model
end

function Service.Place(player: Player, req: any): any
	local profile: any, plot: any = PlayerDataService.Get(player), PlotService.Get(player)
	if not profile or not plot then return { ok = false, err = "NoPlot" } end
	if type(req) ~= "table" or not Net.isInt(req.slot, 1, Balance.NpcSlots) or not Net.isInt(req.pad, 1, Balance.NpcPads) then return { ok = false, err = "Invalid" } end
	local limit = Progression.npcLimit(profile.rebirth)
	if req.pad > limit then return { ok = false, err = "PadLocked" } end
	local npcId = profile.slots[req.slot]
	if not npcId then return { ok = false, err = "EmptySlot" } end
	if not profile.npcs[npcId] then return { ok = false, err = "NotOwned" } end
	local def = NPCs.ById[npcId]
	if not def then return { ok = false, err = "Unknown" } end
	pads[player] = pads[player] or {}
	if pads[player][req.pad] then return { ok = false, err = "PadBusy" } end
	for _, e in pads[player] do if e.npcId == npcId then return { ok = false, err = "AlreadyActive" } end end
	if active(player) >= limit then return { ok = false, err = "NpcLimit" } end
	if serverTotal() >= Balance.ServerNpcCap then return { ok = false, err = "ServerBusy" } end
	local entry = { npcId = npcId, status = "placed", pad = req.pad, stage = 0, total = 0 }
	pads[player][req.pad] = entry            -- reserved before building: concurrent calls cannot exceed the limit
	local ok, model = pcall(spawnModel, player, plot, req.pad, def)
	if not ok then pads[player][req.pad] = nil; warn("[NPC] spawn failed: " .. tostring(model)); return { ok = false, err = "Server" } end
	entry.model = model
	StateSync.Push(player)
	return { ok = true, pad = req.pad, npc = npcId }
end

-- Frees a pad/active slot after cleanup (called by NPCRunService too)
function Service.Free(player: Player, pad: number)
	local mine = pads[player]
	local e = mine and mine[pad]
	if not mine or not e then return end
	if e.model then e.model:Destroy() end
	mine[pad] = nil
	if next(mine) == nil and not player.Parent then pads[player] = nil end
	if player.Parent then StateSync.Push(player) end
end

function Service.Recall(player: Player, req: any): any
	if type(req) ~= "table" or not Net.isInt(req.pad, 1, Balance.NpcPads) then return { ok = false, err = "Invalid" } end
	local e = pads[player] and pads[player][req.pad]
	if not e then return { ok = false, err = "NotFound" } end
	if e.status == "running" then Service.RecallRequested:Fire(player, req.pad) return { ok = true } end
	Service.Free(player, req.pad)
	return { ok = true }
end

function Service.SetSlot(player: Player, req: any): any
	local profile: any = PlayerDataService.Get(player)
	if not profile then return { ok = false, err = "NoProfile" } end
	if type(req) ~= "table" or not Net.isInt(req.slot, 1, Balance.NpcSlots) then return { ok = false, err = "Invalid" } end
	local id = req.id
	if id == nil or id == false then
		profile.slots[req.slot] = false
	else
		if not Net.isId(id) then return { ok = false, err = "Invalid" } end
		if not NPCs.ById[id] then return { ok = false, err = "Unknown" } end
		if not profile.npcs[id] then return { ok = false, err = "NotOwned" } end
		for i = 1, Balance.NpcSlots do if profile.slots[i] == id then profile.slots[i] = false end end   -- one slot per NPC
		profile.slots[req.slot] = id
	end
	PlayerDataService.MarkDirty(player)
	StateSync.Push(player)
	return { ok = true }
end

function Service.Start()
	StateSync.Provider("npc", function(player: Player): any
		local p: any = PlayerDataService.Get(player)
		if not p then return nil end           -- (strict pass: profile can be missing while a player is leaving)
		local list: { [string]: any } = {}
		for i, e in pads[player] or {} do list[tostring(i)] = { npc = e.npcId, status = e.status, stage = e.stage or 0, total = e.total or 0 } end
		local course = CourseValidationService.Analyze(player)
		local reach: { [string]: number } = {}     -- NOTE-003: how wide a gap each owned NPC can really cross (its own speed/jump), shown as a warning in the NPC window
		for id in p.npcs do
			local d = NPCs.ById[id]
			if d then local m = Brain.Mapped(d.stats); reach[id] = (Traversal.Capability(m.walkSpeed, m.jumpPower)) end
		end
		return { active = active(player), limit = Progression.npcLimit(p.rebirth), pads = list, padCount = Balance.NpcPads, serverCap = Balance.ServerNpcCap, reach = reach, maxGap = course and course.maxGap or 0,
			npcPlayable = course and course.npcPlayable or false, playerPlayable = course and course.playerPlayable or false }
	end)
	Net.handle("SetSlot", Balance.RateLimits.NpcSlot, Service.SetSlot)
	Net.handle("PlaceNpc", Balance.RateLimits.Npc, Service.Place)
	Net.handle("RecallNpc", Balance.RateLimits.Npc, Service.Recall)
	SessionService.Leaving.Event:Connect(function(player: Player)
		for pad, e in pairs(pads[player] or {}) do if e.status ~= "running" then Service.Free(player, pad) end end
	end)
end

return Service
