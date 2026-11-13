-- Verified through Roblox's public username lookup, 2026-11-13.
local excluded = {[11969424328]=true, [11984313673]=true} -- vicusiuss, TestVicu
local Policy = {}
function Policy.include(userId, studio, creatorType, creatorId)
	return not studio and type(userId)=="number" and userId>0 and not excluded[userId]
		and not (creatorType=="User" and userId==creatorId)
end
return Policy
