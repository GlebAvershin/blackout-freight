local Experiment = {}
Experiment.__index = Experiment
Experiment.WindowSeconds = 90

function Experiment.variant(userId)
	-- Jenkins one-at-a-time hash, salted with the experiment version.
	local key = "first_shift_compass_v1:" .. tostring(userId)
	local hash = 0
	for index = 1, #key do
		hash = bit32.band(hash + string.byte(key, index), 0xffffffff)
		hash = bit32.band(hash + bit32.lshift(hash, 10), 0xffffffff)
		hash = bit32.bxor(hash, bit32.rshift(hash, 6))
	end
	hash = bit32.band(hash + bit32.lshift(hash, 3), 0xffffffff)
	hash = bit32.bxor(hash, bit32.rshift(hash, 11))
	hash = bit32.band(hash + bit32.lshift(hash, 15), 0xffffffff)
	return if hash % 2 == 0 then "control" else "compass"
end

function Experiment.start(variant, time, crewSize)
	return setmetatable({
		variant = variant,
		segment = if crewSize == 1 then "solo" else "crew",
		startedAt = time,
		seen = {},
	}, Experiment)
end

function Experiment:record(event, time)
	if time < self.startedAt or time > self.startedAt + Experiment.WindowSeconds or self.seen[event] then
		return false
	end
	if event == "delivered_90" and not self.seen.pickup_90 then return false end
	self.seen[event] = true
	return true
end

return Experiment
