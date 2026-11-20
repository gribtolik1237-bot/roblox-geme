--!strict
-- Rebirth (spec 13). Requirement = LIFETIME EARNED Coins reaching the next threshold. It NEVER deducts or resets Coins,
-- buildings, inventory, NPCs, slots or decorations: it only raises the counter, which grows the plot, the object limit,
-- the active-NPC limit and unlocks shop entries. The check and the increment happen without a yield, so a double
-- click / concurrent request can never apply the same rebirth twice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Progression = require(ReplicatedStorage.Configs.Progression)
local Net = require(ReplicatedStorage.Shared.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateSync = require(script.Parent.StateSync)

local Service = {}
Service.Rebirthed = Instance.new("BindableEvent")   -- (player, newRebirth)

function Service.Do(player: Player, req: any): any
	local profile: any, plot: any = PlayerDataService.Get(player), PlotService.Get(player)
	if not profile or not plot then return { ok = false, err = "NoProfile" } end
	if profile.rebirth >= Balance.MaxRebirth then return { ok = false, err = "MaxRebirth" } end
	local need = Progression.nextThreshold(profile.rebirth)
	if not need or profile.lifetime < need then return { ok = false, err = "NotEnough", need = need, have = profile.lifetime } end
	-- the client may state which rebirth it believes it is doing; a stale/duplicate request is rejected
	if type(req) == "table" and req.expect ~= nil and req.expect ~= profile.rebirth + 1 then return { ok = false, err = "Stale" } end
	profile.rebirth += 1                               -- THE ONLY STATE CHANGE (Coins untouched)
	profile.meta.lastRebirthAt = os.time()
	PlotService.Apply(plot, profile.rebirth)           -- bigger zone; existing objects are never moved or removed
	PlayerDataService.MarkDirty(player)
	StateSync.Push(player)
	Net.fire("Effect", player, "Rebirth", profile.rebirth)
	Net.fire("Notify", player, ("REBIRTH %d! Your plot grew and new items unlocked."):format(profile.rebirth), "ok")
	task.defer(function() if player.Parent then PlayerDataService.SaveNow(player) end end)
	Service.Rebirthed:Fire(player, profile.rebirth)
	return { ok = true, rebirth = profile.rebirth }
end

function Service.Start()
	Net.handle("Rebirth", Balance.RateLimits.Rebirth, Service.Do)
end

return Service
