local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Profile = require(script.Parent.Profile)
local RankTrack = require(game:GetService("ReplicatedStorage").Freight.RankTrack)
local Season = require(game:GetService("ReplicatedStorage").Freight.Season)
local Analytics = require(script.Parent.Analytics)
local AnalyticsService = game:GetService("AnalyticsService")
local Service = {}
Service.__index = Service

function Service.new(store, clock)
	if not store and RunService:IsStudio() then
		local records = {}
		store = {UpdateAsync = function(_, key, callback)
			local value = callback(records[key])
			if value then records[key] = value end
			return value
		end}
	end
	return setmetatable({store = store or DataStoreService:GetDataStore("FreightProfile_v1"), clock = clock, sessions = {}, closing = false}, Service)
end

local function publish(player, data, preferenceKind)
	player:SetAttribute("Scrap", data.scrap)
	player:SetAttribute("RankXP", data.rankXP)
	local season = data.seasons[Season.Id] or Season.copy(nil)
	player:SetAttribute("SeasonDeliveries", season.deliveries)
	player:SetAttribute("SeasonBroadcast", season.broadcast)
	player:SetAttribute("SeasonShelter", season.shelter)
	player:SetAttribute("SeasonTier", Season.tier(season))
	local title = RankTrack.progress(data.rankXP)
	player:SetAttribute("CrewTitle", title and title.id or "Rookie")
	player:SetAttribute("CrewRank", 1 + math.floor(data.rankXP / 250))
	if preferenceKind == "initial" or preferenceKind == "role" then
		player:SetAttribute("NextCrewRole", data.preferences.role or "Carrier")
	end
	if preferenceKind == "initial" or preferenceKind == "audio" then
		player:SetAttribute("SavedMusicMuted", data.preferences.musicMuted == true)
		player:SetAttribute("SavedEffectsMuted", data.preferences.effectsMuted == true)
	end
	for _, id in {"Coil", "Lens"} do player:SetAttribute("Upgrade" .. id, data.upgrades[id] == true) end
end

local function retry(callback)
	for attempt = 1, 3 do
		local result, reason = callback()
		if result then return result end
		if reason == "locked" then return nil end
		if attempt < 3 then task.wait(attempt * 2) end
	end
	return nil
end

function Service:join(player)
	if self.closing or self.sessions[player] then return end
	local session = {profile = Profile.new(self.store, HttpService:GenerateGUID(false), self.clock), queue = {}, seen = {}}
	self.sessions[player] = session
	player:SetAttribute("ProfileStatus", "loading")
	task.spawn(function()
		local data = retry(function() return session.profile:acquire(player.UserId) end)
		if data then
			session.ready = true
			publish(player, data, "initial")
			player:SetAttribute("ProfileStatus", RunService:IsStudio() and "local" or "ready")
			local sequence, refreshedAt = data.sequence, os.clock()
			local previousXP = data.rankXP
			local previousTier = Season.tier(data.seasons[Season.Id])
			while true do
				local item = session.queue[1]
				if item then
					player:SetAttribute("ProfileStatus", "saving")
					-- No later operation may pass an unconfirmed write.
					local result = retry(function() return session.profile:transact(player.UserId, sequence + 1, item.operation) end)
					if not result then session.ready = false; break end
					sequence += 1
					refreshedAt = os.clock()
					table.remove(session.queue, 1)
					publish(player, result, item.operation.kind)
					local tier = Season.tier(result.seasons[Season.Id])
					if tier > previousTier then
						player:SetAttribute("LastSeasonUnlocked", tier)
						Analytics.log(AnalyticsService.LogCustomEvent, player, "SeasonMilestone", tier)
					end
					previousTier = tier
					local unlocked = RankTrack.unlocked(previousXP, result.rankXP)
					previousXP = result.rankXP
					if unlocked then
						player:SetAttribute("LastRankUnlocked", unlocked.rank)
						Analytics.log(AnalyticsService.LogCustomEvent, player, "RankMilestone", unlocked.rank)
					end
					if item.operation.kind == "reward" then
						player:SetAttribute("LastScrapAward", result.lastAward or 0)
						Analytics.log(AnalyticsService.LogCustomEvent, player, "ScrapAwarded", result.lastAward or 0)
					elseif item.operation.kind == "upgrade" then
						player:SetAttribute("WorkshopResult", result.lastResult)
						if result.lastResult == "purchased" then
							Analytics.log(AnalyticsService.LogCustomEvent, player, "WorkshopPurchased", item.operation.price, {
								[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = item.operation.id,
							})
						end
					end
					player:SetAttribute("ProfileStatus", RunService:IsStudio() and "local" or "ready")
				elseif session.leaving or self.closing then
					break
				elseif os.clock() - refreshedAt >= 30 then
					if not retry(function() return session.profile:refresh(player.UserId) end) then
						session.ready = false; break
					end
					refreshedAt = os.clock()
				else
					task.wait(0.1)
				end
			end
		end
		session.ready = false
		if not session.leaving and not self.closing then player:SetAttribute("ProfileStatus", "unavailable") end
		retry(function() return session.profile:release(player.UserId) end)
		self.sessions[player] = nil
	end)
end

function Service:enqueue(player, operation, key)
	local session = self.sessions[player]
	if not session or not session.ready or session.leaving or self.closing or #session.queue >= 16 then return false end
	if key and session.seen[key] then return false end
	if key then session.seen[key] = true end
	local accepted = table.clone(operation)
	-- Freeze server-owned event eligibility before a queue/network delay can
	-- cross the season boundary. Never read a timestamp from a RemoteEvent.
	if accepted.kind == "reward" then accepted.earnedAt = self.clock and self.clock() or os.time() end
	table.insert(session.queue, {operation = accepted})
	return true
end

function Service:leave(player)
	local session = self.sessions[player]
	if session then session.leaving = true end -- Worker drains accepted writes before releasing.
end

function Service:close()
	self.closing = true
	for player in self.sessions do self:leave(player) end
	local deadline = os.clock() + 25
	while next(self.sessions) and os.clock() < deadline do task.wait(0.1) end
end
return Service
