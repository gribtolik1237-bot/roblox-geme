--!nonstrict
-- Physical kiosks and their HUD teleport. The counter prompt opens the shop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local ShopRestyle = require(ServerStorage.WorldRecipes.ShopRestyle)
local SHOPS = ShopRestyle.Definitions

local Service = {}
local V = Vector3.new

function Service.Build(force)
	local world = workspace:WaitForChild("WorldAssets")
	local folder = world:FindFirstChild("Shops")
	if folder then
		if not force then return folder end
		if folder:GetAttribute("HandEdited") and force ~= "overwrite-hand-edits" then
			warn("[ShopWorld] Shops are hand-edited. Pass 'overwrite-hand-edits' to rebuild.")
			return folder
		end
	end
	return ShopRestyle.Run()
end

-- TeleportToShop { shop = "obstacle" | "npc" }  (the donation shop has none, by design)
function Service.Teleport(player, req)
	if type(req) ~= "table" or (SHOPS[req.shop] == nil and req.shop ~= "home") then return { ok = false, err = "Invalid" } end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return { ok = false, err = "NoCharacter" } end
	local Manual = require(script.Parent.ManualCourseRunService)
	if Manual.Active(player) then return { ok = false, err = "InRun" } end       -- a run is in progress: the teleport would break it
	if req.shop == "home" then      -- top-bar "Home": the server puts the player on THEIR OWN plot (found by OwnerId; the client sends no position)
		local plot
		for _, m in workspace.PlayerPlots:GetChildren() do if m:GetAttribute("OwnerId") == player.UserId then plot = m break end end
		local sp, origin = plot and plot:FindFirstChild("Spawn"), plot and plot:FindFirstChild("Origin")
		if not (sp and origin) then return { ok = false, err = "NoPlot" } end
		local hpos = sp.Position + V(0, 8, 0)
		char:SetAttribute("ServerTeleportAt", os.clock())
		char:PivotTo(CFrame.lookAt(hpos, hpos + origin.CFrame.LookVector))
		hrp.AssemblyLinearVelocity = Vector3.zero
		return { ok = true }
	end
	local shops = workspace:FindFirstChild("WorldAssets") and workspace.WorldAssets:FindFirstChild("Shops")
	local model = shops and shops:FindFirstChild("Shop_" .. req.shop)
	local landing = model and model:FindFirstChild("Landing")
	if not landing then return { ok = false, err = "NoShop" } end
	-- Arrive a step back and to the side, facing the counter with the seller visible past the lobby avatar.
	local lcf = landing.CFrame
	local pos = landing.Position + lcf.RightVector * 7 - lcf.LookVector * 5 + V(0, 8, 0)     -- +8: high enough for the giant body
	local focus = landing.Position + lcf.LookVector * 14
	char:SetAttribute("ServerTeleportAt", os.clock())
	char:PivotTo(CFrame.lookAt(pos, Vector3.new(focus.X, pos.Y, focus.Z)))
	hrp.AssemblyLinearVelocity = Vector3.zero
	return { ok = true }
end

function Service.Start()
	Service.Build(false)
	Net.handle("TeleportToShop", require(game:GetService("ReplicatedStorage").Configs.Balance).RateLimits.Teleport, Service.Teleport)   -- audit 4.4
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if CollectionService:HasTag(prompt, "TL_ShopPrompt") then Net.fire("OpenShop", player, prompt:GetAttribute("ShopKind")) end
	end)
end

return Service
