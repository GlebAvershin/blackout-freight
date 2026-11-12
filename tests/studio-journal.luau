return function(Journal)
	local stored = {
		broadcast = true, west = true, bestClearSeconds = 100,
		finishPreference = {finish = "Aurora", changedAt = 100},
	}
	local readFinished = false
	local updateAttempts = 0
	local duringWrite
	local store = {}
	function store:GetAsync(key)
		assert(key == "42")
		local before = table.clone(stored)
		task.wait(1.6)
		readFinished = true
		return before
	end
	function store:UpdateAsync(key, update)
		assert(key == "42")
		updateAttempts += 1
		if updateAttempts == 1 then
			error("QA simulated transient storage failure")
		end
		if duringWrite then
			local callback = duringWrite
			duringWrite = nil
			callback()
		end
		stored = update(stored)
		return stored
	end
	local function player()
		return {UserId = 42, SetAttribute = function(self, key, value) self[key] = value end}
	end
	local journal = Journal.new(store)
	local first = player()
	journal:join(first)
	local _, _, provisional = journal:award(first, "shelter", nil, nil, 112)
	assert(not provisional, "do not announce a record before the save is loaded")
	assert(journal:setFinish(first, "Signal", 200))
	assert(first.EndingShelter and first.JournalStatus == "saving")
	journal:flush()
	assert(updateAttempts == 3 and stored.broadcast and stored.shelter)
	assert(stored.finishPreference.finish == "Signal")
	while not readFinished do task.wait() end
	assert(first.EndingBroadcast and first.EndingShelter and first.JournalStatus == "ready")
	assert(first.BestClearSeconds == 100, "a slower run cannot replace the cloud record")
	assert(first.PreferredCellFinish == "Signal", "a delayed read cannot undo a local equip")
	duringWrite = function()
		journal:award(first, "shelter", nil, 21, 80)
		journal:award(first, "shelter", nil, 22, 85)
		assert(journal:setFinish(first, "Standard", 300))
	end
	assert(journal:award(first, "shelter", "east", 20, 90))
	journal:flush()
	assert(first.ArchiveGold and stored.west and stored.east)
	assert(#stored.dispatchWeeks == 3 and stored.dispatchWeeks[1] == 22)
	assert(journal:recoverBlackBox(first))
	journal:recoverBlackBox(first, 44)
	journal:recoverBlackBox(first, 31)
	journal:recoverBlackBox(first, 54)
	journal:flush()
	journal:leave(first)
	local second = player()
	Journal.new(store):join(second)
	local deadline = os.clock() + 4
	while second.JournalStatus == "loading" and os.clock() < deadline do task.wait() end
	assert(second.EndingBroadcast and second.EndingShelter and second.ArchiveGold and second.JournalStatus == "ready")
	assert(second.DispatchWeeks == 3 and second.DispatchLastWeek == 22)
	assert(second.BestClearSeconds == 80, "a faster result during a save survives a rejoin")
	assert(second.PreferredCellFinish == "Standard", "latest selection during a save survives a rejoin")
	assert(second.ArchiveBlackBox and second.BestBlackBoxCrewSeconds == 31,
		"the optional recording and fastest crew extraction survive rejoin")
	print("LAST SIGNAL QA PASS: journal retry, old read, concurrent records and contract awards, and rejoin")
end
