-- Pure target selection; geometry and movement remain server-owned.
local Brain = {MemorySeconds = 3}
function Brain.variant(heat, crewUnlocked)
	return heat >= 2 and crewUnlocked and "Tracker" or "Sentinel"
end
function Brain.new()
	local last
	local api = {}
	function api.clear() last = nil end
	function api.choose(variant, time, candidates)
		local best, remembered
		for _, item in candidates do
			if not item.protected then
				if last and last.id == item.id then remembered = item end
				if (variant ~= "Tracker" or item.visible) and (not best or item.priority < best.priority) then best = item end
			end
		end
		if best then
			last = {id=best.id, x=best.x, z=best.z, time=time}
			return best.id, best.x, best.z, "hunt"
		end
		if variant == "Tracker" and last and remembered and time-last.time < Brain.MemorySeconds then
			return nil, last.x, last.z, "search"
		end
		last = nil
		return nil, nil, nil, "patrol"
	end
	return api
end
return Brain
