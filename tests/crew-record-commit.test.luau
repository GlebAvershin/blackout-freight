local CrewRecordCommit = require("../src/server/CrewRecordCommit")

local writes = {{committed = true}, {committed = true}, {committed = true}, {}}
local elapsed = 0
assert(CrewRecordCommit.await(writes, function()
	elapsed += 0.2
	if elapsed >= 31 then writes[4].committed = true end
end), "a slow profile must not discard a valid crew record")
assert(elapsed >= 31)

writes[4] = {}
writes[3] = {}
local waits = 0
assert(not CrewRecordCommit.await(writes, function()
	waits += 1
	writes[4].failed = true
end), "a failed profile must prevent a crew record")
assert(waits == 1, "failure should end the wait even if another profile is pending")

assert(not CrewRecordCommit.await({}, function()
	error("an empty crew must not wait")
end))
