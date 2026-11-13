local Roles = if script then require(script.Parent.Roles) else require("./Roles")
local Dispatch = if script then require(script.Parent.Dispatch) else require("./Dispatch")
local Challenges = {}
Challenges.Heat = 1
Challenges.Milestones = table.freeze({5, 15, 30})
Challenges.MinimumSeconds = 30
Challenges.WeeklyBonus = 20
Challenges.BlackoutAt = 35

function Challenges.unlocked(broadcast, shelter, wins)
	return broadcast == true or shelter == true or (wins or 0) > 0
end

-- Every delivery consumes crew time. Assume the shortest possible selection,
-- straight lines, maximum sprint speed and the full interaction radius.
function Challenges.minimumTime(distances, target, crewSize, maxSpeed, interactionRadius, spawnOffset)
	local sorted = table.clone(distances)
	table.sort(sorted)
	local total, longest = 0, 0
	for index = 1, target do
		local distance = math.max(0, sorted[index] - 2 * interactionRadius)
		-- A recovery can reset a player to the safe spawn before any pickup.
		total += distance + math.max(0, distance - spawnOffset)
		longest = distance
	end
	return math.max(Challenges.MinimumSeconds, math.floor(math.max(total / crewSize, longest) / maxSpeed))
end

function Challenges.day(timestamp)
	return math.floor(timestamp / 86400)
end

function Challenges.roleOfWeek(week)
	return Roles.Order[week % #Roles.Order + 1]
end

function Challenges.cells(day, count, available)
	local result = {1, 2}
	local pool = {}
	for id = 3, available do table.insert(pool, id) end
	-- Small deterministic generator shared by every server and CLI tests.
	local seed = day % 2147483646 + 1
	while #result < count and #pool > 0 do
		seed = (seed * 48271) % 2147483647
		table.insert(result, table.remove(pool, seed % #pool + 1))
	end
	return result
end

function Challenges.dailyRecord(previous, run)
	if previous and previous.day > run.day then return previous end
	local times = if previous and previous.day == run.day then table.clone(previous.times) else {}
	local key = tostring(run.crew)
	times[key] = math.min(times[key] or run.seconds, run.seconds)
	return {day = run.day, times = times}
end

function Challenges.week(timestamp)
	return Dispatch.week(timestamp)
end

function Challenges.tier(deliveries)
	for index = #Challenges.Milestones, 1, -1 do
		if deliveries >= Challenges.Milestones[index] then return index end
	end
	return 0
end

return table.freeze(Challenges)
