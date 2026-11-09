local Journal = {}
Journal.__index = Journal

function Journal.merge(left, right)
	left = type(left) == "table" and left or {}
	right = type(right) == "table" and right or {}
	return {
		broadcast = left.broadcast == true or right.broadcast == true,
		shelter = left.shelter == true or right.shelter == true,
		west = left.west == true or right.west == true,
		east = left.east == true or right.east == true,
	}
end

function Journal.new(store)
	return setmetatable({store = store, entries = {}}, Journal)
end

local function retry(operation)
	for attempt = 1, 3 do
		local ok, result = pcall(operation)
		if ok then
			return true, result
		end
		warn("Freight journal:", result)
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	return false
end

local function publish(entry)
	if entry.player then
		entry.player:SetAttribute("EndingBroadcast", entry.endings.broadcast)
		entry.player:SetAttribute("EndingShelter", entry.endings.shelter)
		entry.player:SetAttribute("ArchiveWest", entry.endings.west)
		entry.player:SetAttribute("ArchiveEast", entry.endings.east)
		entry.player:SetAttribute("ArchiveGold", entry.endings.west and entry.endings.east)
		entry.player:SetAttribute("JournalStatus", entry.status)
	end
end

function Journal:join(player)
	local key = tostring(player.UserId)
	local entry = self.entries[key] or {endings = Journal.merge(), pending = {}}
	self.entries[key] = entry
	entry.player = player
	entry.status = self.store and "loading" or "local"
	publish(entry)
	if self.store then
		self:save(key, entry)
		task.spawn(function()
			local ok, saved = retry(function()
				return self.store:GetAsync(key)
			end)
			if self.entries[key] ~= entry or entry.player ~= player then
				return
			end
			entry.endings = Journal.merge(entry.endings, saved)
			if entry.status == "loading" then
				entry.status = ok and "ready" or "unavailable"
			end
			publish(entry)
		end)
	end
end

function Journal:save(key, entry)
	if not self.store or entry.writing or not next(entry.pending) then
		return
	end
	entry.writing = true
	entry.status = "saving"
	publish(entry)
	task.spawn(function()
		while next(entry.pending) do
			local snapshot = table.clone(entry.pending)
			local ok, saved = retry(function()
				return self.store:UpdateAsync(key, function(old)
					return Journal.merge(old, snapshot)
				end)
			end)
			if not ok then
				break
			end
			for ending in snapshot do
				entry.pending[ending] = nil
			end
			entry.endings = Journal.merge(entry.endings, saved)
		end
		entry.writing = false
		entry.status = next(entry.pending) and "unavailable" or "ready"
		publish(entry)
		if not entry.player and not next(entry.pending) then
			self.entries[key] = nil
		end
	end)
end

function Journal:eligible(player)
	local endings = self.entries[tostring(player.UserId)].endings
	return endings.broadcast and endings.shelter
end

function Journal:award(player, ending, operation)
	local key = tostring(player.UserId)
	local entry = self.entries[key]
	local record = (operation == "west" or operation == "east") and self:eligible(player) and not entry.endings[operation]
	if record then
		entry.endings[operation] = true
		if self.store then
			entry.pending[operation] = true
		end
	end
	if not entry.endings[ending] then
		entry.endings[ending] = true
		if self.store then
			entry.pending[ending] = true
		end
	end
	publish(entry)
	self:save(key, entry)
	return record == true
end

function Journal:leave(player)
	local key = tostring(player.UserId)
	local entry = self.entries[key]
	if entry and entry.player == player then
		entry.player = nil
		if self.store and not next(entry.pending) then
			self.entries[key] = nil
		else
			self:save(key, entry)
		end
	end
end

function Journal:flush()
	for key, entry in self.entries do
		self:save(key, entry)
	end
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		local writing = false
		for _, entry in self.entries do
			writing = writing or entry.writing
		end
		if not writing then
			return
		end
		task.wait(0.2)
	end
end

return Journal
