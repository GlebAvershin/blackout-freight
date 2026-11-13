local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}
function Analytics.log(method, ...)
	if RunService:IsStudio() then return end
	local ok, err = pcall(method, AnalyticsService, ...)
	if not ok then warn("Freight analytics:", err) end
end
return Analytics
