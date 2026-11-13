-- Atomic, write-through profile. No cached snapshot is ever written back.
-- A lease excludes another server; sequence numbers make ambiguous retries safe.
local Profile = {}
Profile.__index = Profile
local LeaseSeconds = 120

local function copy(old)
	if old == nil then
		return {version = 1, scrap = 0, rankXP = 0, upgrades = {}, sequence = 0}
	end
	assert(type(old) == "table" and old.version == 1, "Unsupported profile version")
	assert(type(old.scrap) == "number" and old.scrap >= 0 and old.scrap % 1 == 0, "Invalid balance")
	assert(type(old.rankXP) == "number" and old.rankXP >= 0 and old.rankXP % 1 == 0, "Invalid rank")
	assert(type(old.upgrades) == "table", "Invalid upgrades")
	local result = table.clone(old)
	result.upgrades = table.clone(old.upgrades)
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
			assert(type(amount) == "number" and amount >= 0 and amount <= 100 and amount % 1 == 0)
			-- Fixed UTC-hour cap persists across rejoining and server changes.
			local hour = math.floor(time / 3600)
			local earned = data.rewardHour == hour and (data.hourEarned or 0) or 0
			amount = math.min(amount, math.max(0, 600 - earned))
			data.rewardHour, data.hourEarned = hour, earned + amount
			data.lastAward = amount
			data.scrap += amount
			data.rankXP += amount
			data.lastResult = "rewarded"
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
