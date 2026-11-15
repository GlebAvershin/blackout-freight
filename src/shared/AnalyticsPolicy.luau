-- Verified through Roblox's public username lookup, 2026-11-13.
local excluded = {[11969424328]=true, [11984313673]=true} -- vicusiuss, TestVicu
local Policy = {}
function Policy.compassQA(userId, studio, universeId, launchData)
	if studio or universeId ~= 10775560304 or not excluded[userId] then return nil end
	if launchData == "freight-qa-compass-v1" then return "compass" end
	if launchData == "freight-qa-control-v1" then return "control" end
	return nil
end

function Policy.include(userId, studio, creatorType, creatorId)
	return not studio and type(userId)=="number" and userId>0 and not excluded[userId]
		and not (creatorType=="User" and userId==creatorId)
end
return Policy
