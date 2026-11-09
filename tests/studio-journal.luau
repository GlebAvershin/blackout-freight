return function(Journal)
	local stored = {broadcast = true, west = true}
	local readFinished = false
	local updateAttempts = 0
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
		stored = update(stored)
		return stored
	end
	local function player()
		return {UserId = 42, SetAttribute = function(self, key, value) self[key] = value end}
	end
	local journal = Journal.new(store)
	local first = player()
	journal:join(first)
	journal:award(first, "shelter")
	assert(first.EndingShelter and first.JournalStatus == "saving")
	journal:flush()
	assert(updateAttempts == 2 and stored.broadcast and stored.shelter)
	while not readFinished do task.wait() end
	assert(first.EndingBroadcast and first.EndingShelter and first.JournalStatus == "ready")
	assert(journal:award(first, "shelter", "east"))
	journal:flush()
	assert(first.ArchiveGold and stored.west and stored.east)
	journal:leave(first)
	local second = player()
	Journal.new(store):join(second)
	local deadline = os.clock() + 4
	while second.JournalStatus == "loading" and os.clock() < deadline do task.wait() end
	assert(second.EndingBroadcast and second.EndingShelter and second.ArchiveGold and second.JournalStatus == "ready")
	print("LAST SIGNAL QA PASS: journal retry, old read, shutdown flush and rejoin")
end
