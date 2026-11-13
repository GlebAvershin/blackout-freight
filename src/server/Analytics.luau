local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Policy = require(game:GetService("ReplicatedStorage").Freight.AnalyticsPolicy)
local Analytics = {}
function Analytics.log(method, ...)
	local player = select(1, ...)
	if not player or not Policy.include(player.UserId, RunService:IsStudio(), game.CreatorType.Name, game.CreatorId) then return end
	local ok, err = pcall(method, AnalyticsService, ...)
	if not ok then warn("Freight analytics:", err) end
end
return Analytics
