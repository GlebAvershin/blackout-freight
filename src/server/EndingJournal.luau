local Dispatch = if script
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Freight").Dispatch)
	else require("../shared/Dispatch")

local Journal = {}
Journal.__index = Journal

local function mergeWeeks(left, right)
	local seen, weeks = {}, {}
	for _, source in {left or false, right or false} do
		if type(source) == "table" then
			for _, week in source do
				if type(week) == "number" and week >= 0 and week <= 100000 and week % 1 == 0 and not seen[week] then
					seen[week] = true
					table.insert(weeks, week)
				end
			end
		end
	end
	table.sort(weeks, function(a, b)
		return a > b
	end)
	while #weeks > Dispatch.RewardWeeks do
		table.remove(weeks)
	end
	return weeks
end

local function validClearTime(seconds)
	return type(seconds) == "number" and seconds >= 1 and seconds <= 3600 and seconds % 1 == 0
end

local function mergeClearTime(left, right)
	if not validClearTime(left) then
		return if validClearTime(right) then right else nil
	end
	return if validClearTime(right) then math.min(left, right) else left
end

local validFinishes = {Standard = true, Signal = true, Aurora = true, Crew = true}

local function validPreference(value)
	return type(value) == "table" and type(value.finish) == "string" and validFinishes[value.finish]
		and type(value.changedAt) == "number" and value.changedAt >= 1
		and value.changedAt <= 4102444800000 and value.changedAt % 1 == 0
end

local function mergePreference(left, right)
	local choice = if validPreference(left) then left else nil
	if validPreference(right) and (not choice or right.changedAt > choice.changedAt) then
		choice = right
	end
	return if choice then {finish = choice.finish, changedAt = choice.changedAt} else nil
end

function Journal.merge(left, right)
	left = type(left) == "table" and left or {}
	right = type(right) == "table" and right or {}
	return {
		broadcast = left.broadcast == true or right.broadcast == true,
		shelter = left.shelter == true or right.shelter == true,
		west = left.west == true or right.west == true,
		east = left.east == true or right.east == true,
		blackBox = left.blackBox == true or right.blackBox == true,
		dispatchWeeks = mergeWeeks(left.dispatchWeeks, right.dispatchWeeks),
		bestClearSeconds = mergeClearTime(left.bestClearSeconds, right.bestClearSeconds),
		bestBlackBoxCrewSeconds = mergeClearTime(left.bestBlackBoxCrewSeconds, right.bestBlackBoxCrewSeconds),
		finishPreference = mergePreference(left.finishPreference, right.finishPreference),
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
		entry.player:SetAttribute("ArchiveBlackBox", entry.endings.blackBox)
		entry.player:SetAttribute("BestBlackBoxCrewSeconds", entry.endings.bestBlackBoxCrewSeconds)
		local weeks = entry.endings.dispatchWeeks
		entry.player:SetAttribute("DispatchWeeks", #weeks)
		entry.player:SetAttribute("DispatchLastWeek", weeks[1])
		entry.player:SetAttribute("BestClearSeconds", entry.endings.bestClearSeconds)
		local preference = entry.endings.finishPreference
		entry.player:SetAttribute("PreferredCellFinish", preference and preference.finish)
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
				if entry.pending[ending] == snapshot[ending] then
					entry.pending[ending] = nil
				end
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

function Journal:setFinish(player, finish, changedAt)
	local key = tostring(player.UserId)
	local entry = self.entries[key]
	local choice = {finish = finish, changedAt = changedAt}
	if not entry or entry.player ~= player or not validPreference(choice) then
		return false
	end
	local previous = entry.endings.finishPreference
	if previous then
		if previous.finish == finish then
			return false
		end
		choice.changedAt = math.max(changedAt, previous.changedAt + 1)
	end
	entry.endings.finishPreference = choice
	if self.store then
		entry.pending.finishPreference = choice
	end
	player:SetAttribute("PreferredCellFinish", finish)
	self:save(key, entry)
	return true
end

function Journal:recoverBlackBox(player, crewSeconds)
	local key = tostring(player.UserId)
	local entry = self.entries[key]
	local unlocked = not entry.endings.blackBox
	local previousBest = entry.endings.bestBlackBoxCrewSeconds
	local best = mergeClearTime(previousBest, crewSeconds)
	if not unlocked and best == previousBest then
		return false
	end
	entry.endings.blackBox = true
	entry.endings.bestBlackBoxCrewSeconds = best
	if self.store then
		if unlocked then
			entry.pending.blackBox = true
		end
		if best ~= previousBest then
			entry.pending.bestBlackBoxCrewSeconds = best
		end
	end
	publish(entry)
	self:save(key, entry)
	return unlocked
end

function Journal:award(player, ending, operation, week, clearSeconds)
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
	local dispatch = week ~= nil and not table.find(entry.endings.dispatchWeeks, week)
	if dispatch then
		entry.endings.dispatchWeeks = mergeWeeks(entry.endings.dispatchWeeks, {week})
		if self.store then
			entry.pending.dispatchWeeks = mergeWeeks(entry.pending.dispatchWeeks, {week})
		end
	end
	local previousBest = entry.endings.bestClearSeconds
	local best = mergeClearTime(previousBest, clearSeconds)
	local improved = best ~= previousBest
	local knownBest = entry.status == "ready" or entry.status == "local"
	if improved then
		entry.endings.bestClearSeconds = best
		if self.store then
			entry.pending.bestClearSeconds = best
		end
	end
	publish(entry)
	self:save(key, entry)
	return record == true, dispatch, improved and knownBest
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
