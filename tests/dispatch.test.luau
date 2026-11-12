local Dispatch = require("../src/shared/Dispatch")
local Journal = require("../src/server/EndingJournal")

local monday = 4 * 86400
assert(Dispatch.week(monday - 1) == 0)
assert(Dispatch.week(monday) == 1)
assert(Dispatch.week(monday + 604799) == 1)
assert(Dispatch.week(monday + 604800) == 2)
assert(not Dispatch.qualifies(0, 1, 0, 30) and Dispatch.qualifies(0, 2, 1, 150))
assert(not Dispatch.qualifies(1, 1, 1, 40) and Dispatch.qualifies(1, 1, 0, 165))
assert(not Dispatch.qualifies(2, 0, 0, 30))
assert(Dispatch.qualifies(2, 1, 1, 120) and not Dispatch.qualifies(2, 1, 0, 120.1))

local merged = Journal.merge({broadcast = true, dispatchWeeks = {9, 11, "bad"}}, {
	shelter = true, dispatchWeeks = {10, 9, 11, 8, 10.5, -1},
})
assert(merged.broadcast and merged.shelter)
assert(#merged.dispatchWeeks == 3 and merged.dispatchWeeks[1] == 11 and merged.dispatchWeeks[3] == 9)
assert(#Journal.merge({dispatchWeeks = false}).dispatchWeeks == 0)

local player = {UserId = 18, SetAttribute = function(self, key, value) self[key] = value end}
local journal = Journal.new(nil)
journal:join(player)
local _, first = journal:award(player, "broadcast", nil, 9)
local _, duplicate = journal:award(player, "broadcast", nil, 9)
assert(first and not duplicate and player.DispatchWeeks == 1)
journal:award(player, "shelter", nil, 11)
journal:award(player, "shelter", nil, 13)
journal:leave(player)
journal:join(player)
assert(player.DispatchWeeks == Dispatch.RewardWeeks and player.DispatchLastWeek == 13)
print("PASS: UTC rotation, contract conditions, duplicate and stale progress, rejoin")
