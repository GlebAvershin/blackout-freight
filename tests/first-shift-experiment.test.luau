local Experiment = require("../src/server/FirstShiftExperiment")

local counts = {control = 0, compass = 0}
for userId = 100000, 109999 do
	local variant = Experiment.variant(userId)
	counts[variant] += 1
	assert(variant == Experiment.variant(userId))
end
assert(counts.control > 4800 and counts.control < 5200)
local differentHighIds = 0
for userId = 100001, 100100 do
	if Experiment.variant(userId) ~= Experiment.variant(userId + 2^32) then differentHighIds += 1 end
end
assert(differentHighIds > 25)

local run = Experiment.start("compass", 100, 1)
assert(run.segment == "solo")
assert(run:record("delivered_90", 110) == false)
assert(run:record("pickup_90", 99) == false)
assert(run:record("pickup_90", 105) == true)
assert(run:record("pickup_90", 106) == false)
assert(run:record("caught_90", 106) == true)
assert(run:record("caught_90", 107) == false)
assert(run:record("delivered_90", 190) == true)
assert(run:record("delivered_90", 190) == false)

local crew = Experiment.start("control", 100, 2)
assert(crew.segment == "crew")
assert(crew:record("pickup_90", 190.01) == false)
print("PASS: stable assignment, crew segment, event ordering, deduplication and 90-second window")
