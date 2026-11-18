--!strict
-- TRAP LAB server bootstrap. Order matters: remotes -> data -> world -> services.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = script.Parent.Services
local Systems = script.Parent.Systems

Players.CharacterAutoLoads = false   -- SessionService spawns characters after the plot is assigned
-- (audit 1.3 checked 2026-11-17: `CharacterAutoLoads` IS the current Players property and is not deprecated; `CharacterAutoLoad`
-- does not exist - "is not a valid member of Players" - so renaming it would break server start-up)
-- (audit 3.4) Folders that look empty in Edit but are filled at RUN time - keep them: workspace.Runtime (NPC despawn effects,
-- NPCRunService), and in every plot model Course (placed obstacles, BuildService), Npcs (placed testers, NPCPlacementService) and
-- Decor (decorations). The never-used empty folders workspace.Lobby / Leaderboards / DailyChallenges were deleted (session 8).

local Net = require(ReplicatedStorage.Shared.Net)
Net.init()
require(Systems.Collisions).Setup()

local PlotService = require(Services.PlotService)
PlotService.BuildWorld()

local PlayerDataService = require(Services.PlayerDataService)
require(Services.StateSync)
require(Services.RewardService)
local SessionService = require(Services.SessionService)

-- Net handlers shared by all clients
Net.handle("GetState", require(game:GetService("ReplicatedStorage").Configs.Balance).RateLimits.GetState, function(player: Player)
	local s = require(Services.StateSync).Snapshot(player)
	return { ok = s ~= nil, state = s }
end)

task.spawn(require(Services.WearService).Start)   -- NPC catalog wear, loaded in the background (NPCRig falls back until it is there)
SessionService.Start()
require(Services.BuildService).Start()
require(Services.ObstacleShopService).Start()
require(Services.NPCShopService).Start()
require(Services.ShopCore).Start()
require(Services.CourseValidationService).Start()
require(Services.ManualCourseRunService).Init()
require(Services.NPCPlacementService).Start()
require(Services.NPCRunService).Start()
require(Services.RebirthService).Start()
require(Services.ShopWorldService).Start()
require(Services.RatingService).Start()
require(Services.LeaderboardService).Start()
require(Services.HallService).Start()
require(Services.DecorService).Start()
require(Services.DonateService).Start()
require(Services.LoginRewardService).Start()
PlayerDataService.Start()

print("[TRAP LAB] server started. DataStore mock = " .. tostring(PlayerDataService.IsMock()))
