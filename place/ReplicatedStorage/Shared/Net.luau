--!strict
-- Central remote registry. Client->server = RemoteFunction (reply {ok=bool, err=string?, ...}),
-- server->client = RemoteEvent. The server NEVER invokes a client function.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.Functions = {
	"GetState", "Buy", "GetShops", "BuildPlace", "BuildMove", "BuildRemove", "ValidateCourse", "SetCourseName",
	"SetSlot", "PlaceNpc", "LaunchNpc", "RecallNpc", "StartManual", "CancelManual", "GetPlaySign",
	"Rebirth", "Rate", "GetBoards", "PlaceDecor", "RemoveDecor", "TeleportToShop", "GetDonate",
	"CourseSlots", "ClaimLogin",
}
Net.Events = { "State", "ShopSync", "Notify", "RunState", "Effect", "Knock", "NpcState", "OpenShop", "OpenBoard" }

local function folder(): Folder
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if f then return f :: Folder end
	local nf = Instance.new("Folder")
	nf.Name = "Remotes"
	nf.Parent = ReplicatedStorage
	return nf
end

-- SERVER -------------------------------------------------------------------------------
function Net.init()
	assert(RunService:IsServer(), "Net.init is server-only")
	local f = folder()
	for _, n in Net.Functions do
		if not f:FindFirstChild(n) then
			local r = Instance.new("RemoteFunction"); r.Name = n; r.Parent = f
		end
	end
	for _, n in Net.Events do
		if not f:FindFirstChild(n) then
			local r = Instance.new("RemoteEvent"); r.Name = n; r.Parent = f
		end
	end
end

-- Registers a rate-limited, pcall-protected handler. fn(player, ...) -> table
function Net.handle(name: string, minInterval: number?, fn: (Player, ...any) -> any)
	-- audit 4.4: intervals come from Configs.Balance.RateLimits; a missing one is a config bug - warn and use the generic limit
	if type(minInterval) ~= "number" then
		warn(("[Net] no rate limit for %s - using 0.2 s"):format(name))
		minInterval = 0.2
	end
	local interval = minInterval :: number
	local rf = folder():WaitForChild(name, 5) :: RemoteFunction
	local last: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
	rf.OnServerInvoke = function(player: Player, ...)
		local now = os.clock()
		local prev = last[player]
		if prev and now - prev < interval then return { ok = false, err = "Rate" } end
		last[player] = now
		local ok, res = pcall(fn, player, ...)
		if not ok then
			warn(("[Net] handler %s failed: %s"):format(name, tostring(res)))
			return { ok = false, err = "Server" }
		end
		return res
	end
end

function Net.fire(name: string, player: Player, ...: any)
	local ev = folder():FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then ev:FireClient(player, ...) end
end
function Net.fireAll(name: string, ...: any)
	local ev = folder():FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then ev:FireAllClients(...) end
end

-- CLIENT -------------------------------------------------------------------------------
function Net.invoke(name: string, ...: any): any
	local rf = folder():WaitForChild(name, 10)
	if not rf then return { ok = false, err = "NoRemote" } end
	local ok, res = pcall(function(...) return (rf :: RemoteFunction):InvokeServer(...) end, ...)
	if not ok or type(res) ~= "table" then return { ok = false, err = "Net" } end
	return res
end
function Net.on(name: string, fn: (...any) -> ())
	local ev = folder():WaitForChild(name, 10)
	if ev and ev:IsA("RemoteEvent") then return ev.OnClientEvent:Connect(fn) end
	return nil
end

-- VALIDATION (server) -------------------------------------------------------------------
function Net.isNum(x: any, lo: number?, hi: number?): boolean
	if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then return false end
	if lo and x < lo then return false end
	if hi and x > hi then return false end
	return true
end
function Net.isInt(x: any, lo: number?, hi: number?): boolean
	return Net.isNum(x, lo, hi) and math.floor(x :: number) == x
end
function Net.isId(x: any): boolean
	return type(x) == "string" and #x >= 1 and #x <= 40 and x:match("^[%w_]+$") ~= nil
end
function Net.isStr(x: any, maxLen: number): boolean
	return type(x) == "string" and #x <= maxLen
end

return Net
