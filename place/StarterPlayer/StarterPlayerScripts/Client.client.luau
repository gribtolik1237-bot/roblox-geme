--!strict
-- TRAP LAB client bootstrap. Controllers are required in dependency order; each may yield safely.
local Controllers = script.Parent:WaitForChild("Controllers")

local order = { "StateController", "HUDController", "CameraController", "FirstPersonController", "ShopController", "BuildController", "CourseSlotsController", "RunController", "NPCController", "RebirthController", "MetaController", "DonateController", "SfxController", "GuideController", "LoginRewardController", "PromenadeController" }
for _, name in order do
	local inst = Controllers:FindFirstChild(name)
	if inst then
		local ok, mod = pcall(require, inst)
		if ok and type(mod) == "table" and mod.Start then
			local ok2, err = pcall(mod.Start)
			if not ok2 then warn(("[Client] %s.Start failed: %s"):format(name, tostring(err))) end
		elseif not ok then
			warn(("[Client] require %s failed: %s"):format(name, tostring(mod)))
		end
	end
end
