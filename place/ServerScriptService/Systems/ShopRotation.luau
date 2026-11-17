--!strict
-- Deterministic shop rotation (D-004): the assortment is a pure function of (time slot, salt, catalog), so every
-- player and every server sees the same list without any messaging. The SERVER computes it; clients only display it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Balance = require(ReplicatedStorage.Configs.Balance)

local Rotation = {}

export type Item = { id: string, weight: number, group: string? }

function Rotation.slotIndex(now: number?): number
	return math.floor((now or workspace:GetServerTimeNow()) / Balance.ShopIntervalSeconds)
end
function Rotation.nextRefresh(slot: number): number
	return (slot + 1) * Balance.ShopIntervalSeconds
end

-- Picks `count` ids: staples always included, then one per group (weighted), then weighted fill. No duplicates.
function Rotation.pick(slot: number, salt: number, items: { Item }, count: number, staples: { string }?): { string }
	local rng = Random.new(slot * 7919 + salt)
	local pool = table.clone(items)
	local chosen: { string } = {}
	local function take(i: number)
		chosen[#chosen + 1] = pool[i].id
		table.remove(pool, i)
	end
	local function weightedIndex(filter: ((Item) -> boolean)?): number?
		local total = 0
		for _, it in pool do if not filter or filter(it) then total += it.weight end end
		if total <= 0 then return nil end
		local r = rng:NextNumber() * total
		for i, it in pool do
			if not filter or filter(it) then
				r -= it.weight
				if r <= 0 then return i end
			end
		end
		for i, it in pool do if not filter or filter(it) then return i end end
		return nil
	end
	for _, sid in staples or {} do
		for i, it in pool do if it.id == sid then take(i); break end end
	end
	-- group coverage (e.g. at least one item per category) in a stable group order
	local groups: { string } = {}
	for _, it in items do
		if it.group and not table.find(groups, it.group) then groups[#groups + 1] = it.group end
	end
	table.sort(groups)
	for _, g in groups do
		if #chosen >= count then break end
		local has = false
		for _, id in chosen do
			for _, it in items do if it.id == id and it.group == g then has = true end end
		end
		if not has then
			local i = weightedIndex(function(it) return it.group == g end)
			if i then take(i) end
		end
	end
	while #chosen < count do
		local i = weightedIndex(nil)
		if not i then break end
		take(i)
	end
	return chosen
end

return Rotation
