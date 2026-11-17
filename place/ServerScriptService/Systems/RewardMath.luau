--!strict
-- Pure reward/difficulty formulas (no state, no Roblox services) so they can be unit-tested. Numbers: Configs.Balance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)

local RewardMath = {}

RewardMath.Difficulties = { "Easy", "Normal", "Hard", "VeryHard", "Extreme" }
local LABELS: { [string]: string } = { Easy = "Easy", Normal = "Normal", Hard = "Hard", VeryHard = "Very Hard", Extreme = "Extreme" }
function RewardMath.label(d: string): string return LABELS[d] or d end

-- score thresholds -> difficulty name
function RewardMath.difficulty(score: number): string
	if score < 3 then return "Easy" end
	if score < 6.5 then return "Normal" end
	if score < 11 then return "Hard" end
	if score < 17 then return "VeryHard" end
	return "Extreme"
end

-- Weight of the k-th copy (1-based) of the same obstacle type: repeated copies are worth less
function RewardMath.sameTypeWeight(weight: number, k: number): number
	return weight / (1 + Balance.Npc.SameTypeDecay * (k - 1))
end

-- Manual run payout for a first clear of a course version
function RewardMath.manual(stageCount: number, difficulty: string, lowQuality: boolean, isSelf: boolean): number
	local m = Balance.Manual
	local base = (m.Flat + m.BasePerStage * stageCount) * (m.DifficultyMult[difficulty] or 1)
	if lowQuality then base *= Balance.LowQualityMult end
	if isSelf then base *= m.SelfFraction end
	return math.floor(math.min(base, m.MaxReward))
end

-- Multiplier from how many NPC attempts already happened on this course version inside the window
function RewardMath.repeatMult(priorAttempts: number): number
	return math.max(Balance.Npc.RepeatFloor, 1 - Balance.Npc.RepeatDecay * priorAttempts)
end

-- Coins for ONE confirmed stage
function RewardMath.npcStage(weight: number, sameTypeIndex: number, priorAttempts: number, lowQuality: boolean): number
	local w = RewardMath.sameTypeWeight(weight, sameTypeIndex)
	local c = Balance.Npc.StageBase * w * RewardMath.repeatMult(priorAttempts)
	if lowQuality then c *= Balance.LowQualityMult end
	return math.floor(c)
end

-- Bonus for reaching the finish: flat + a share of what the attempt already earned
function RewardMath.npcFinish(earnedSoFar: number, priorAttempts: number, lowQuality: boolean): number
	local n = Balance.Npc
	local b = (n.FinishBonusFlat + n.FinishBonusFraction * earnedSoFar) * RewardMath.repeatMult(priorAttempts)
	if lowQuality then b *= Balance.LowQualityMult end
	return math.floor(b)
end

return RewardMath
