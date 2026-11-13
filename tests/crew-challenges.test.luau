local Challenges = require("../src/shared/CrewChallenges")
local Profile = require("../src/server/Profile")
local cells = Challenges.cells(20770, 8, 12)
assert(#cells == 8 and cells[1] == 1 and cells[2] == 2)
assert(table.concat(cells, ",") == table.concat(Challenges.cells(20770, 8, 12), ","))
assert(table.concat(cells, ",") ~= table.concat(Challenges.cells(20771, 8, 12), ","))
local seen = {}
for _, id in cells do assert(id <= 12 and not seen[id]); seen[id] = true end
local record = Challenges.dailyRecord(nil, {day = 20770, crew = 1, seconds = 80})
record = Challenges.dailyRecord(record, {day = 20770, crew = 2, seconds = 64})
record = Challenges.dailyRecord(record, {day = 20770, crew = 1, seconds = 90})
assert(record.times["1"] == 80 and record.times["2"] == 64)
assert(Challenges.dailyRecord(record, {day = 20769, crew = 1, seconds = 40}) == record)
assert(Challenges.dailyRecord(record, {day = 20771, crew = 1, seconds = 70}).times["2"] == nil)
local now = 20770 * 86400
local data
local store = {UpdateAsync = function(_, _, callback)
	local nextData = callback(data)
	if nextData then data = nextData end
	return nextData
end}
local profile = Profile.new(store, "first", function() return now end)
assert(profile:acquire(5))
local reward = {kind = "reward", amount = 30, deliveries = 3, role = "Scout",
	daily = {day = 20770, crew = 2, seconds = 75}}
assert(profile:transact(5, 1, reward).roleDeliveries.Scout == 3)
assert(profile:transact(5, 1, reward).roleDeliveries.Scout == 3)
assert(profile:release(5))
local second = Profile.new(store, "second", function() return now end)
local restored = second:acquire(5)
assert(restored.dailyTitle and restored.daily.times["2"] == 75 and restored.roleDeliveries.Scout == 3)
assert(Challenges.tier(4) == 0 and Challenges.tier(5) == 1 and Challenges.tier(30) == 3)
assert(Challenges.minimumTime({900, 360, 360, 360, 360, 360}, 5, 1, 22, 9, 9) == 153)
assert(Challenges.minimumTime({900, 360, 360, 360, 360, 360}, 5, 4, 22, 9, 9) == 38)
assert(Challenges.day(86400 - 1) == 0 and Challenges.day(86400) == 1)
assert(Challenges.unlocked(false, false, 0) == false)
assert(Challenges.unlocked(true, false, 0) and Challenges.unlocked(false, false, 1))
for sequence = 1, 6 do
	local progress = second:transact(5, sequence, {kind = "reward", amount = 50, deliveries = 5, role = "Scout"})
	assert(progress.roleDeliveries.Scout == 3 + sequence * 5)
end
local weekly = {kind = "reward", amount = 20, deliveries = 2, role = Challenges.roleOfWeek(Challenges.week(now)), ending = "broadcast"}
assert(second:transact(5, 7, weekly).lastAward == 40)
assert(second:transact(5, 8, weekly).lastAward == 20)
now += 7 * 86400
assert(second:acquire(5))
weekly.role = Challenges.roleOfWeek(Challenges.week(now))
assert(second:transact(5, 9, weekly).lastAward == 40)
local crewRecords = {}
local crewStore = {UpdateAsync = function(_, key, callback)
	local updated = callback(crewRecords[key])
	if updated then crewRecords[key] = updated end
	return updated
end}
local firstServer = Profile.new(crewStore, "crew-first", function() return now end)
local nextServer = Profile.new(crewStore, "crew-next", function() return now end)
for userId, role in {"Carrier", "Lure", "Scout", "Technician"} do
	assert(firstServer:acquire(userId))
	assert(firstServer:transact(userId, 1, {
		kind = "reward", amount = 20, deliveries = if userId == 1 then 2 else 1, role = role,
		daily = {day = Challenges.day(now), crew = 4, seconds = 102},
	}))
	assert(firstServer:release(userId))
	local loaded = nextServer:acquire(userId)
	assert(loaded.daily.times["4"] == 102 and loaded.daily.times["1"] == nil and loaded.dailyTitle)
	assert(loaded.roleDeliveries[role] == (if userId == 1 then 2 else 1))
end
print("PASS: daily layout, crew brackets, date rollover, role progress and profile restore")
