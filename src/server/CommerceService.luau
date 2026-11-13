local MarketplaceService = game:GetService("MarketplaceService")
local AnalyticsService = game:GetService("AnalyticsService")
local Analytics = require(script.Parent.Analytics)

local CommerceService = {}
CommerceService.__index = CommerceService

function CommerceService.new(config, isPresent)
	local self = setmetatable({passes = {Aurora = config.CosmeticPassId, Crew = config.CrewPassId}, isPresent = isPresent}, CommerceService)
	self.connection = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if not bought or passId <= 0 or not isPresent(player) then return end
		for finish, configuredId in self.passes do
			if passId == configuredId then
				player:SetAttribute(finish, true)
				Analytics.log(AnalyticsService.LogCustomEvent, player, finish .. "PassPurchased")
				return
			end
		end
	end)
	return self
end

function CommerceService:join(player)
	for finish, passId in self.passes do
		if passId <= 0 then continue end
		task.spawn(function()
			for attempt = 1, 3 do
				if not self.isPresent(player) then return end
				local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
				if ok then
					-- A completed purchase must win over an older ownership request.
					if self.isPresent(player) and player:GetAttribute(finish) == nil then
						player:SetAttribute(finish, owned)
					end
					return
				end
				task.wait(attempt)
			end
		end)
	end
end

return CommerceService
