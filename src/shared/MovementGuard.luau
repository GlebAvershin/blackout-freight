-- Horizontal token budget tolerates bursty replication without allowing sustained speedups.
local Guard = {}
Guard.__index = Guard
function Guard.new(x, z, time)
	return setmetatable({x = x, z = z, time = time, budget = 14, blockedUntil = 0}, Guard)
end
function Guard:reset(x, z, time)
	self.x, self.z, self.time, self.budget = x, z, time, 14
	self.blockedUntil = time + 0.5
end
function Guard:sample(x, z, time, speed)
	if x ~= x or z ~= z or math.abs(x) == math.huge or math.abs(z) == math.huge then
		self.blockedUntil = time + 3
		return false
	end
	local dt = math.max(0, time - self.time)
	local distance = math.sqrt((x - self.x)^2 + (z - self.z)^2)
	self.budget = math.min(14, self.budget + dt * (speed + 3)) - distance
	self.x, self.z, self.time = x, z, time
	if self.budget < 0 then
		self.blockedUntil = time + 3
		self.budget = 0
		return false
	end
	return time >= self.blockedUntil
end
return Guard
