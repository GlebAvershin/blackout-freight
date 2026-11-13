-- Permanent free career rewards, derived from confirmed lifetime XP.
local Track = {}
Track.Milestones = table.freeze({
	table.freeze({xp=250, rank=2, id="Runner", en="Runner", ru="Курьер", color={205,145,85}}),
	table.freeze({xp=500, rank=3, id="Keeper", en="Signal keeper", ru="Связист", color={65,220,225}}),
	table.freeze({xp=1000, rank=5, id="Dispatcher", en="Dispatcher", ru="Диспетчер", color={255,195,65}}),
})
function Track.progress(xp)
	xp = type(xp)=="number" and xp==xp and math.clamp(math.floor(xp),0,1e12) or 0
	local current, nextReward
	for _, reward in Track.Milestones do
		if xp >= reward.xp then current=reward else nextReward=reward; break end
	end
	local start = current and current.xp or 0
	local fraction = nextReward and (xp-start)/(nextReward.xp-start) or 1
	return current, nextReward, fraction
end
function Track.unlocked(before, after)
	local old = Track.progress(before)
	local new = Track.progress(after)
	return new and (not old or new.xp > old.xp) and new or nil
end
return Track
