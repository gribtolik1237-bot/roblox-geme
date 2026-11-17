--!nonstrict
-- Behaviour kinds of the obstacle catalog. Each kind's setup(e, ctx) fills:
--   e.update(e, t, dt)  -> moves/animates the obstacle (pure function of server time t)
--   e.hazards           -> descriptors {kind="Kill"|"Knock", size, pose(t)->CFrame, active(t)?->bool, jumpable, ref=BasePart}
--                          used for contact polling AND by the NPC brain to PREDICT where hazards will be
--   e.vanish            -> {visibleAt(i, t)}  (disappearing tiles)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Behaviors = {}
local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local TAU = math.pi * 2
local function osc(t, period, phase) return math.sin((t / period + phase) * TAU) end
local function frac(x) return x - math.floor(x) end

local function charOf(hit)
	local m = hit:FindFirstAncestorOfClass("Model")
	local h = m and m:FindFirstChildOfClass("Humanoid")
	return m, h
end

Behaviors.rotplat = function(e, ctx)
	local b = e.def.behavior
	local dm = e.model:FindFirstChild("DiscModel")
	local disc = dm.PrimaryPart
	local w = math.rad(b.dps)
	e.update = function(_, t)
		local th = w * (t + e.phase * 10)
		dm:PivotTo(e.base * CF(0, 1.4, 0) * ANG(0, th, 0) * ANG(0, 0, math.rad(90)))
		disc.AssemblyAngularVelocity = V3(0, w, 0)
	end
	e.hazards = {}
end

Behaviors.slide = function(e, ctx)
	local b = e.def.behavior
	e.hazards = {}
	local items = {}
	for i, name in b.parts do
		local sm = e.model:FindFirstChild(name)
		local z = if b.zs then b.zs[i] else 0
		local ph = b.phases[i]
		local function pose(t) return e.base * CF(b.amp * osc(t, b.period, ph + e.phase), b.y, z) end
		items[#items + 1] = { model = sm, pose = pose }
		e.hazards[#e.hazards + 1] = { kind = b.haz, size = b.size, pose = pose, jumpable = b.jumpable, ref = sm.PrimaryPart }
	end
	e.update = function(_, t) for _, it in items do it.model:PivotTo(it.pose(t)) end end
end

Behaviors.swing = function(e, ctx)
	local b = e.def.behavior
	e.hazards = {}
	local items = {}
	for i, name in b.parts do
		local hm = e.model:FindFirstChild(name)
		local z = b.zs[i]
		local ph = b.phases[i]
		local function pivot(t) return e.base * CF(0, b.pivotY, z) * ANG(0, 0, math.rad(b.amp) * osc(t, b.period, ph + e.phase)) end
		local function head(t) return pivot(t) * CF(0, -b.arm - b.head.Y / 2 + 0.4, 0) end
		items[#items + 1] = { model = hm, pivot = pivot }
		e.hazards[#e.hazards + 1] = { kind = b.haz, size = b.head, pose = head, jumpable = false, ref = hm:FindFirstChild("Head") }
	end
	e.update = function(_, t) for _, it in items do it.model:PivotTo(it.pivot(t)) end end
end

Behaviors.sweep = function(e, ctx)
	local b = e.def.behavior
	e.hazards = {}
	local items = {}
	for i, name in b.parts do
		local bm = e.model:FindFirstChild(name)
		local function pose(t) return e.base * CF(0, b.y, b.amps[i] * osc(t, b.periods[i], b.phases[i] + e.phase)) end
		items[#items + 1] = { model = bm, pose = pose }
		e.hazards[#e.hazards + 1] = { kind = b.haz, size = b.size, pose = pose, jumpable = b.jumpable, ref = bm.PrimaryPart }
	end
	e.update = function(_, t) for _, it in items do it.model:PivotTo(it.pose(t)) end end
end

Behaviors.spin2 = function(e, ctx)
	local b = e.def.behavior
	e.hazards = {}
	local items = {}
	for _, bar in b.bars do
		local bm = e.model:FindFirstChild(bar.part)
		local w = math.rad(bar.dps)
		local function pose(t) return e.base * ANG(0, w * (t + e.phase * 10), 0) * CF(0, bar.y, 0) end
		items[#items + 1] = { model = bm, pose = pose }
		e.hazards[#e.hazards + 1] = { kind = "Knock", size = V3(bar.reach * 2, 1.0, 1.3), pose = pose, jumpable = bar.jumpable, ref = bm.PrimaryPart,
			overhead = (not bar.jumpable) and bar.y > 6 }     -- above a walking NPC's head: harmless on foot, deadly in a jump (T33)
	end
	e.update = function(_, t) for _, it in items do it.model:PivotTo(it.pose(t)) end end
end

-- spikes / electric tiles / fire walls: zones that are DEADLY only inside their active window of a repeating cycle
Behaviors.periodic = function(e, ctx)
	local b = e.def.behavior
	e.hazards = {}
	local zones = {}
	for i, z in b.zones do
		local function phaseX(t) return frac(t / b.period + z.phase + e.phase * 0) * b.period end
		local function active(t) return phaseX(t) < b.activeDur end
		local function warning(t) local x = phaseX(t); return x >= b.period - b.warn end
		local zcf = e.base * CF(z.pos)
		zones[i] = { z = z, active = active, warning = warning, last = nil }
		e.hazards[#e.hazards + 1] = { kind = "Kill", size = z.size, pose = function() return zcf end, active = active, jumpable = false, periodic = true, reach = (if b.variant == "fire" then 2.0 else 0.5), slow = (if b.variant == "fire" then 8 else nil), ref = e.model.PrimaryPart, lanes = (b.variant == "electric"), next = function(t) return (b.period - phaseX(t)) % b.period end }
	end
	local variant = b.variant
	local spikes = e.model:FindFirstChild("Spikes")
	local h = -3.4
	local tiles = {}
	for _, d in e.model:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("Tile") then tiles[d:GetAttribute("Tile")] = tiles[d:GetAttribute("Tile")] or {}; table.insert(tiles[d:GetAttribute("Tile")], d) end
	end
	e.update = function(_, t, dt)
		for i, zn in zones do
			local act, warn = zn.active(t), zn.warning(t)
			local state = if act then 2 elseif warn then 1 else 0
			if variant == "spikes" and spikes then
				local target = if act then 0 elseif warn then -2.2 else -3.4
				h += (target - h) * math.min(1, (dt or 0.016) * 16)
				spikes:PivotTo(e.base * CF(0, 2 + h, 0))
			elseif zn.last ~= state then
				zn.last = state
				if variant == "electric" then
					for _, p in tiles[zn.z.tag] or {} do
						p.Color = if state == 2 then Color3.fromRGB(120, 245, 255) elseif state == 1 then Color3.fromRGB(255, 220, 90) else Color3.fromRGB(34, 40, 58)
						p.Material = if state == 0 then Enum.Material.Metal else Enum.Material.Neon
					end
				elseif variant == "fire" then
					local f = e.model:FindFirstChild(zn.z.tag)
					if f then
						f.Transparency = if state == 2 then 0.15 elseif state == 1 then 0.88 else 1
						local l = f:FindFirstChildOfClass("PointLight"); if l then l.Brightness = if state == 2 then 4 else 0 end
					end
				end
			end
		end
	end
end

Behaviors.vanish = function(e, ctx)
	local b = e.def.behavior
	e.hazards = {}
	local tiles = {}
	for i, name in b.tiles do tiles[i] = { part = e.model:FindFirstChild(name), rim = e.model:FindFirstChild(name .. "Rim"), last = nil } end
	local function x(i, t) return frac(t / b.period + b.phases[i]) * b.period end
	e.vanish = { period = b.period, hidden = b.hidden, visibleAt = function(i, t) return x(i, t) >= b.hidden end }
	e.update = function(_, t)
		for i, tl in tiles do
			local xi = x(i, t)
			local state = if xi < b.hidden then 2 elseif xi >= b.period - 0.45 then 1 else 0
			if tl.last ~= state then
				tl.last = state
				tl.part.CanCollide = state ~= 2
				tl.part.CanQuery = state ~= 2
				tl.part.Transparency = if state == 2 then 1 elseif state == 1 then 0.55 else 0
				tl.rim.Transparency = if state == 2 then 1 elseif state == 1 then 0.8 else 0.35
			end
		end
	end
end

Behaviors.bounce = function(e, ctx)
	local b = e.def.behavior
	e.hazards = {}
	local pad = e.model:FindFirstChild(b.part)
	local last = {}
	table.insert(e.conns, pad.Touched:Connect(function(hit)
		local char, hum = charOf(hit)
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health <= 0 or not hrp then return end
		if last[char] and os.clock() - last[char] < 1.2 then return end
		last[char] = os.clock()
		local pl = Players:GetPlayerFromCharacter(char)
		task.spawn(function()
			-- launch when the body is over the pad centre, so the arc (and the landing) is predictable
			local t0 = os.clock()
			while os.clock() - t0 < 0.45 and hrp.Parent do
				local d = Vector3.new(hrp.Position.X - pad.Position.X, 0, hrp.Position.Z - pad.Position.Z).Magnitude
				if d <= 1.2 then break end
				task.wait()
			end
			if not hrp.Parent then return end
			local v = e.base.LookVector * b.hv + V3(0, b.vy, 0)
			if pl then ctx.fire("Effect", pl, "Launch", v)
			else
				-- the Humanoid damps horizontal speed right after take-off: keep it for 0.55 s so the arc lands on the high deck
				hrp.AssemblyLinearVelocity = v
				local fwd = e.base.LookVector
				local t1 = os.clock()
				while os.clock() - t1 < 0.55 and hrp.Parent do
					local cur = hrp.AssemblyLinearVelocity
					hrp.AssemblyLinearVelocity = V3(fwd.X * b.hv, cur.Y, fwd.Z * b.hv)
					RunService.Heartbeat:Wait()
				end
			end
		end)
	end))
end

Behaviors.belt = function(e, ctx)
	local b = e.def.behavior
	e.hazards = {}
	local belt = e.model:FindFirstChild(b.part)
	local chev = e.model:FindFirstChild(b.chevrons)
	belt.AssemblyLinearVelocity = e.base.LookVector * b.speed       -- anchored conveyor trick: carries characters
	local dir = if b.speed > 0 then -1 else 1
	e.update = function(_, t)
		belt.AssemblyLinearVelocity = e.base.LookVector * b.speed
		chev:PivotTo(e.base * CF(0, 2, dir * ((t * math.abs(b.speed)) % 3)))
	end
end

Behaviors.reveal = function(e, ctx)
	local b = e.def.behavior
	e.hazards = {}
	local slab = e.model:FindFirstChild(b.part)
	local token = 0
	table.insert(e.conns, slab.Touched:Connect(function(hit)
		local _, hum = charOf(hit)
		if not hum then return end
		token += 1
		local my = token
		slab.Transparency = 0.3
		task.delay(2.5, function() if my == token and slab.Parent then slab.Transparency = 0.93 end end)
	end))
end

return Behaviors
