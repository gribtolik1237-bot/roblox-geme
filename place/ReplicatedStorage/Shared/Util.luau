--!strict
local Util = {}

function Util.snap(v: number, step: number): number
	return math.floor(v / step + 0.5) * step
end

function Util.deepCopy(t: any): any
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in t do c[k] = Util.deepCopy(v) end
	return c
end

-- Fill missing keys of `data` from `template` (recursively). Never overwrites existing values.
function Util.reconcile(data: any, template: any)
	for k, v in template do
		if data[k] == nil then
			data[k] = Util.deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			Util.reconcile(data[k], v)
		end
	end
end

function Util.count(t: { [any]: any }): number
	local n = 0
	for _ in t do n += 1 end
	return n
end

function Util.fmt(n: number): string
	n = math.floor(n)
	if n >= 1e9 then return ("%.2fB"):format(n / 1e9) end
	if n >= 1e6 then return ("%.2fM"):format(n / 1e6) end
	if n >= 1e4 then return ("%.1fK"):format(n / 1e3) end
	local s = tostring(n)
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function Util.clampRot(r: number): number
	return ((math.floor(r / 90 + 0.5) % 4) * 90)
end

-- "Is this the pit/ground (not an obstacle)?" - the ONE definition (audit 2.4; used by Systems.GroundCheck for NPC and manual runs)
function Util.isGround(inst: Instance): boolean
	return inst.Name == "BuildZone" or inst.Name == "Land" or inst.Name == "Ground" or inst.Name == "LobbyFloor"
		or game:GetService("CollectionService"):HasTag(inst, "TL_Ground")
end

-- Server-synchronised clock (os.time() granularity is 1 s, GetServerTimeNow() is sub-second).
function Util.now(): number
	return workspace:GetServerTimeNow()
end

return Util
