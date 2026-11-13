local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local AnalyticsService = game:GetService("AnalyticsService")
local Analytics = require(script.Parent.Analytics)

local CommerceService = {}
CommerceService.__index = CommerceService

function CommerceService.new(config, isPresent)
	local self = setmetatable({passes = {Aurora = config.CosmeticPassId, Crew = config.CrewPassId,
		ShiftPass = config.ShiftPassId, DoubleScrap = config.DoubleScrapPassId},
		club = config.DepotClubSubscriptionId, clubRequests = {}, isPresent = isPresent}, CommerceService)
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
	if self.club ~= "" then
		Players.UserSubscriptionStatusChanged:Connect(function(player, id)
			if id == self.club then self:refreshClub(player) end
		end)
		Players.PlayerRemoving:Connect(function(player) self.clubRequests[player] = nil end)
	end
	return self
end

-- The platform retries unresolved receipts. Acknowledge only after UpdateAsync.
function CommerceService:enableRewardedAds(config, shared, profiles, inLobby)
	local productId = config.RewardedScrapProductId
	if productId <= 0 then return end
	local ok, reward = pcall(AdService.CreateAdRewardFromDevProductId, AdService, productId)
	if not ok then warn("Rewarded Scrap product is unavailable"); return end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "RewardedScrap"
	local nextAttempt = {}
	Players.PlayerRemoving:Connect(function(player) nextAttempt[player] = nil end)
	MarketplaceService.ProcessReceipt = function(receipt)
		local pending = Enum.ProductPurchaseDecision.NotProcessedYet
		if receipt.ProductId ~= productId or receipt.ProductPurchaseChannel ~= Enum.ProductPurchaseChannel.AdReward then
			return pending
		end
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then return pending end
		local accepted, item = profiles:enqueue(player, {kind="adReward",purchaseId=receipt.PurchaseId})
		if not accepted then return pending end
		local deadline = os.clock()+15
		repeat
			if item.committed then return Enum.ProductPurchaseDecision.PurchaseGranted end
			task.wait(0.1)
		until os.clock() >= deadline or not self.isPresent(player)
		return if item.committed then Enum.ProductPurchaseDecision.PurchaseGranted else pending
	end
	remote.OnServerEvent:Connect(function(player)
		local time = os.clock()
		if not self.isPresent(player) or not inLobby(player) or time < (nextAttempt[player] or 0) then return end
		nextAttempt[player] = time + 120
		pcall(AdService.ShowRewardedVideoAdAsync, AdService, player, reward)
	end)
	remote.Parent = shared
end

function CommerceService:refreshClub(player)
	if self.club == "" or not self.isPresent(player) then return end
	local request = {}
	self.clubRequests[player] = request
	for attempt = 1, 3 do
		local ok, status = pcall(MarketplaceService.GetUserSubscriptionStatusAsync, MarketplaceService, player, self.club)
		if self.clubRequests[player] ~= request or not self.isPresent(player) then return end
		if ok then
			player:SetAttribute("DepotClub", status.IsSubscribed == true)
			return
		end
		task.wait(attempt)
	end
	if self.clubRequests[player] == request and self.isPresent(player) then player:SetAttribute("DepotClub", nil) end
end

function CommerceService:join(player)
	if self.club ~= "" then task.spawn(function() self:refreshClub(player) end) end
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
