-- Run only in the temporary Studio QA place. Shares an in-memory store across service instances.
local Service = require(game:GetService("ServerScriptService").Freight.ProfileService)
local records, failOnce = {}, false
local store = {UpdateAsync = function(_, key, callback)
	callback(records[key]) -- discarded callback, as on a concurrent write
	local value = callback(records[key])
	if value then records[key] = value end
	if failOnce then failOnce = false; error("Simulated response loss") end
	return value
end}
local function actor()
	return {UserId = 40001, SetAttribute = function(self, key, value) self[key] = value end}
end
local function waitFor(f)
	local deadline = os.clock() + 10
	repeat if f() then return end; task.wait(0.05) until os.clock() >= deadline
	error("Profile worker timed out")
end
local first, person = Service.new(store), actor()
first:join(person)
waitFor(function() return person.ProfileStatus == "local" end)
failOnce = true
assert(first:enqueue(person, {kind = "reward", amount = 75}, "shift-1"))
assert(not first:enqueue(person, {kind = "reward", amount = 75}, "shift-1"))
assert(first:enqueue(person, {kind = "upgrade", id = "Coil", price = 40}))
assert(first:enqueue(person, {kind = "upgrade", id = "Coil", price = 40}))
waitFor(function() return person.UpgradeCoil and person.Scrap == 35 and records.Player_40001.sequence == 3 end)
-- Drain a pending write on leave, then acquire from another server session.
assert(first:enqueue(person, {kind = "reward", amount = 50}, "shift-2"))
first:leave(person)
waitFor(function() return first.sessions[person] == nil end)
local second, returning = Service.new(store), actor()
second:join(returning)
waitFor(function() return returning.ProfileStatus == "local" end)
assert(returning.Scrap == 85 and returning.UpgradeCoil and returning.RankXP == 125)
second:close()
assert(next(second.sessions) == nil)
print("EXPANSION PROFILE PASS serialized queue, ambiguous write, duplicate upgrade, drain, second-session restore")
