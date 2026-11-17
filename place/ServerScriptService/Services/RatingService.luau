--!nonstrict
-- Course rating (spec 16). 5 criteria (Balance.Rating.Criteria), whole stars 1..5. Anti-abuse: only AFTER clearing the owner's CURRENT course version,
-- never your own course, one vote per player per course; a changed vote is accepted only after Balance.RatingEditCooldown (replaces the old
-- vote, so repeats can never add weight). Shown rating = Bayesian mean, see Balance.Rating.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateSync = require(script.Parent.StateSync)

local Rating = {}
local CFG = Balance.Rating

-- (shown rating 1..5, votes)
function Rating.Average(ownerProfile)
	local rt = ownerProfile.plot.rating
	local n = rt.n
	local total = 0
	for i = 1, #CFG.Criteria do total += rt.sum[i] or 0 end
	local sumOfMeans = total / #CFG.Criteria          -- sum over voters of each voter's mean over the 5 criteria
	return (sumOfMeans + CFG.PriorMean * CFG.PriorWeight) / (n + CFG.PriorWeight), n
end

-- per-criterion means (nil entries when nobody voted yet)
function Rating.Criteria(ownerProfile)
	local rt, out = ownerProfile.plot.rating, {}
	for i = 1, #CFG.Criteria do out[i] = if rt.n > 0 then rt.sum[i] / rt.n else nil end
	return out
end

function Rating.Rate(player, req)
	if type(req) ~= "table" or not Net.isInt(req.owner) or type(req.scores) ~= "table" or #req.scores ~= #CFG.Criteria then return { ok = false, err = "Invalid" } end
	local scores = {}
	for i = 1, #CFG.Criteria do
		local s = req.scores[i]
		if not Net.isInt(s, CFG.Min, CFG.Max) then return { ok = false, err = "Invalid" } end
		scores[i] = s
	end
	if req.owner == player.UserId then return { ok = false, err = "OwnCourse" } end
	local owner = Players:GetPlayerByUserId(req.owner)
	local op, rp = owner and PlayerDataService.Get(owner), PlayerDataService.Get(player)
	if not owner or not op or not rp then return { ok = false, err = "NotAvailable" } end
	local res = Rating.Apply(rp, op, player.UserId, req.owner, scores, os.time())
	if res.ok then
		PlayerDataService.MarkDirty(owner); PlayerDataService.MarkDirty(player)
		StateSync.Push(owner)
		local okP, PS = pcall(require, script.Parent.PlotService)
		local pl = okP and PS.Get(owner)
		if pl then PS.SetSignRating(pl, res.average, res.votes) end
	end
	return res
end

-- Pure rule set (no Roblox objects): voter profile, owner profile, ids, validated scores, current time
function Rating.Apply(rp, op, raterId, ownerId, scores, now)
	if raterId == ownerId then return { ok = false, err = "OwnCourse" } end
	if not rp.clears[ownerId .. ":" .. op.plot.version] then return { ok = false, err = "NotCleared" } end   -- only after clearing THIS version
	local rec = rp.ratings[tostring(ownerId)]
	if rec and now - rec.t < Balance.RatingEditCooldown then return { ok = false, err = "Cooldown", wait = Balance.RatingEditCooldown - (now - rec.t) } end
	local plot, sid = op.plot, tostring(raterId)
	local old = plot.raters[sid]
	if old then                                   -- a changed vote REPLACES the old one: repeats never add weight
		for i = 1, #CFG.Criteria do plot.rating.sum[i] -= old[i] end
		plot.rating.n -= 1
	elseif plot.rating.n >= CFG.MaxVoters then
		return { ok = false, err = "Full" }
	end
	plot.raters[sid] = scores
	for i = 1, #CFG.Criteria do plot.rating.sum[i] += scores[i] end
	plot.rating.n += 1
	rp.ratings[tostring(ownerId)] = { t = now }
	local avg, n = Rating.Average(op)
	return { ok = true, average = avg, votes = n, replaced = old ~= nil }
end

function Rating.Start()
	Net.handle("Rate", Balance.RateLimits.Rate, Rating.Rate)
end

return Rating
