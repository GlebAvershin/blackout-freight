local Round = {}
Round.__index = Round

function Round.new(target, deadline, ids, routingSeconds)
	assert(target > 0 and target <= #ids and routingSeconds > 0)
	local cells = {}
	for _, id in ids do
		assert(cells[id] == nil, "Duplicate cell id")
		cells[id] = "available"
	end
	return setmetatable({
		target = target,
		deadline = deadline,
		routingSeconds = routingSeconds,
		delivered = 0,
		outcome = "live",
		cells = cells,
		carrying = {},
	}, Round)
end

function Round:pickup(user, id, now)
	if self.outcome ~= "live" or now >= self.deadline or self.carrying[user] or self.cells[id] ~= "available" then
		return false
	end
	self.carrying[user] = id
	self.cells[id] = "carried"
	return true
end

function Round:drop(user)
	local id = self.carrying[user]
	if id then
		self.carrying[user] = nil
		self.cells[id] = "available"
	end
	return id
end

function Round:deposit(user, now)
	local id = self.carrying[user]
	if self.outcome ~= "live" or now >= self.deadline or not id then
		return false
	end
	self.carrying[user] = nil
	self.cells[id] = "delivered"
	self.delivered += 1
	if self.delivered == self.target then
		self.outcome = "routing"
		self.deadline = now + self.routingSeconds
	end
	return true
end

function Round:choose(ending, now)
	if self.outcome ~= "routing" or now >= self.deadline or (ending ~= "broadcast" and ending ~= "shelter") then
		return false
	end
	self.ending = ending
	self.routeSource = "chosen"
	self.outcome = "won"
	return true
end

function Round:expire(now)
	if now < self.deadline then
		return false
	end
	if self.outcome == "live" then
		self.outcome = "lost"
	elseif self.outcome == "routing" then
		self.ending = "shelter"
		self.routeSource = "automatic"
		self.outcome = "won"
	else
		return false
	end
	return true
end

return Round
