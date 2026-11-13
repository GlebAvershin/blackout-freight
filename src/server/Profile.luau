-- Atomic, write-through profile. No cached snapshot is ever written back.
-- A lease excludes another server; sequence numbers make ambiguous retries safe.
local Progression = if script then require(game:GetService("ReplicatedStorage").Freight.Progression) else require("../shared/Progression")
local Season = if script then require(game:GetService("ReplicatedStorage").Freight.Season) else require("../shared/Season")
local Challenges = if script then require(game:GetService("ReplicatedStorage").Freight.CrewChallenges) else require("../shared/CrewChallenges")
local Roles = if script then require(game:GetService("ReplicatedStorage").Freight.Roles) else require("../shared/Roles")
local Profile = {}
Profile.__index = Profile
local LeaseSeconds = 120

local function copy(old)
	if old == nil then
		return {version = 1, scrap = 0, rankXP = 0, upgrades = {}, seasons = {}, preferences = {role="Carrier",musicMuted=false,effectsMuted=false}, sequence = 0}
	end
	assert(type(old) == "table" and old.version == 1, "Unsupported profile version")
	assert(type(old.scrap) == "number" and old.scrap >= 0 and old.scrap % 1 == 0, "Invalid balance")
	assert(type(old.rankXP) == "number" and old.rankXP >= 0 and old.rankXP % 1 == 0, "Invalid rank")
	assert(type(old.upgrades) == "table", "Invalid upgrades")
	local result = table.clone(old)
	result.upgrades = table.clone(old.upgrades)
	assert(old.seasons == nil or type(old.seasons)=="table", "Invalid seasons")
	result.seasons = table.clone(old.seasons or {})
	if result.seasons[Season.Id] ~= nil then result.seasons[Season.Id] = Season.copy(result.seasons[Season.Id]) end
	assert(old.preferences == nil or type(old.preferences) == "table", "Invalid preferences")
	result.preferences = old.preferences and table.clone(old.preferences) or {role="Carrier",musicMuted=false,effectsMuted=false}
	return result
end

function Profile.new(store, owner, clock)
	assert(type(owner) == "string" and #owner > 0)
	return setmetatable({store = store, owner = owner, clock = clock or os.time}, Profile)
end

function Profile:_update(userId, transform)
	local ok, result = pcall(function()
		return self.store:UpdateAsync("Player_" .. userId, function(old, info)
			local nextValue = transform(copy(old))
			if nextValue == nil then return nil end
			return nextValue, {userId}, info and info:GetMetadata() or {}
		end)
	end)
	if not ok then return nil, "unavailable" end
	if result then return result end
	return nil, "locked"
end

function Profile:acquire(userId)
	local time = self.clock()
	return self:_update(userId, function(data)
		if data.owner and data.owner ~= self.owner and (data.expires or 0) > time then return nil end
		if data.owner ~= self.owner then data.sequence = 0 end
		data.owner, data.expires = self.owner, time + LeaseSeconds
		return data
	end)
end

function Profile:refresh(userId)
	local time = self.clock()
	return self:_update(userId, function(data)
		if data.owner ~= self.owner or (data.expires or 0) <= time then return nil end
		data.expires = time + LeaseSeconds
		return data
	end)
end

-- Caller serializes operations and retains the same sequence after a failed write.
-- Catalog and amounts are server-owned, never accepted from RemoteEvent payloads.
function Profile:transact(userId, sequence, operation)
	assert(type(sequence) == "number" and sequence >= 1 and sequence % 1 == 0)
	assert(type(operation) == "table")
	local time = self.clock()
	return self:_update(userId, function(data)
		if data.owner ~= self.owner or (data.expires or 0) <= time then return nil end
		if sequence == data.sequence then return data end
		if sequence ~= data.sequence + 1 then return nil end
		if operation.kind == "reward" then
			local amount = operation.amount
			assert(type(amount) == "number" and amount >= 0 and amount <= 110 and amount % 1 == 0)
			-- Keep the free XP pace independent of paid wallet bonuses.
			local hour = math.floor(time / 3600)
			local sameHour = data.rewardHour == hour
			local earned = sameHour and (data.hourEarned or 0) or 0
			local xpEarned = sameHour and (data.hourXP or earned) or 0
			local wallet = Progression.walletReward(amount, operation.doubleScrap == true, operation.club == true)
			local earnedAt = operation.earnedAt or time -- legacy/internal callers
			assert(type(earnedAt)=="number" and earnedAt>=0 and earnedAt<=time and earnedAt%1==0, "Invalid award timestamp")
			local week = Challenges.week(earnedAt)
			if operation.role == Challenges.roleOfWeek(week) and (operation.deliveries or 0) >= 2
				and operation.ending and (data.roleBonusWeek or -1) < week
				and earned + wallet + Challenges.WeeklyBonus <= 600 then
				wallet += Challenges.WeeklyBonus
				data.roleBonusWeek = week
			end
			amount = math.min(amount, math.max(0, 600 - xpEarned))
			wallet = math.min(wallet, math.max(0, 600 - earned))
			data.rewardHour, data.hourEarned, data.hourXP = hour, earned + wallet, xpEarned + amount
			data.lastAward = wallet
			data.scrap += wallet
			data.rankXP += amount
			if operation.role and Roles.Catalog[operation.role] then
				data.roleDeliveries = table.clone(data.roleDeliveries or {})
				local deliveries = math.clamp(operation.deliveries or 0, 0, 5)
				data.roleDeliveries[operation.role] = math.min(Challenges.Milestones[#Challenges.Milestones],
					(data.roleDeliveries[operation.role] or 0) + deliveries)
			end
			if operation.daily then
				data.daily = Challenges.dailyRecord(data.daily, operation.daily)
				data.dailyTitle = true
			end
			data.seasons[Season.Id] = Season.advance(data.seasons[Season.Id], operation.deliveries or 0, operation.ending, earnedAt)
			data.lastResult = "rewarded"
		elseif operation.kind == "adReward" then
			local id = operation.purchaseId
			assert(type(id) == "string" and #id > 0 and #id <= 128, "Invalid receipt ID")
			data.adReceipts = table.clone(data.adReceipts or {})
			if not data.adReceipts[id] then
				data.scrap += Progression.AdScrap
				data.adReceipts[id] = true
			end
			data.lastResult = "adRewarded"
		elseif operation.kind == "role" then
			assert(({Carrier=true,Lure=true,Scout=true,Technician=true})[operation.role], "Invalid role")
			data.preferences.role = operation.role
			data.lastResult = "preferences"
		elseif operation.kind == "audio" then
			assert(type(operation.musicMuted)=="boolean" and type(operation.effectsMuted)=="boolean", "Invalid audio settings")
			data.preferences.musicMuted, data.preferences.effectsMuted = operation.musicMuted, operation.effectsMuted
			data.lastResult = "preferences"
		elseif operation.kind == "upgrade" then
			local id, price = operation.id, operation.price
			assert(type(id) == "string" and #id > 0 and #id <= 64)
			assert(type(price) == "number" and price >= 0 and price % 1 == 0)
			if data.upgrades[id] then
				data.lastResult = "owned"
			elseif data.scrap < price then
				data.lastResult = "insufficient"
			else
				data.scrap -= price
				data.upgrades[id] = true
				data.lastResult = "purchased"
			end
		else
			error("Unknown profile operation")
		end
		data.sequence, data.expires = sequence, time + LeaseSeconds
		return data
	end)
end

function Profile:release(userId)
	return self:_update(userId, function(data)
		if data.owner ~= self.owner then return nil end
		data.owner, data.expires = nil, nil
		return data
	end)
end

return Profile
