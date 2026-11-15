local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Policy = require(game:GetService("ReplicatedStorage").Freight.AnalyticsPolicy)
local Analytics = {}
function Analytics.compassQAVariant(player)
	return Policy.compassQA(player.UserId, RunService:IsStudio(), game.GameId, player:GetJoinData().LaunchData)
end

function Analytics.logCompassQA(player, variant, stage, segment)
	if Analytics.compassQAVariant(player) ~= variant then return end
	local ok, err = pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, "FirstShiftCompassV1", 1, {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = variant,
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = stage,
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = "qa_" .. segment,
	})
	if not ok then warn("Freight compass QA analytics:", err) end
end

function Analytics.log(method, ...)
	local player = select(1, ...)
	if not player or not Policy.include(player.UserId, RunService:IsStudio(), game.CreatorType.Name, game.CreatorId) then return end
	local ok, err = pcall(method, AnalyticsService, ...)
	if not ok then warn("Freight analytics:", err) end
end
return Analytics
