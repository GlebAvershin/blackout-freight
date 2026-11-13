-- Run only in the temporary Studio QA place. Shares an in-memory store across service instances.
local Service = require(game:GetService("ServerScriptService").Freight.ProfileService)
local records, failOnce = {}, false
local store = {UpdateAsync = function(_, key, callback)
	callback(records[key]) -- discarded callback, as on a concurrent write
	local value = callback(records[key])
	if value then records[key] = value end
	if failOnce then failOnce = false; error("Simulated response loss") end
	return value
end}
local function actor()
	return {UserId = 40001, SetAttribute = function(self, key, value) self[key] = value end}
end
local function waitFor(f)
	local deadline = os.clock() + 10
	repeat if f() then return end; task.wait(0.05) until os.clock() >= deadline
	error("Profile worker timed out")
end
local first, person = Service.new(store), actor()
first:join(person)
waitFor(function() return person.ProfileStatus == "local" end)
failOnce = true
assert(first:enqueue(person, {kind = "reward", amount = 75}, "shift-1"))
assert(not first:enqueue(person, {kind = "reward", amount = 75}, "shift-1"))
assert(first:enqueue(person, {kind = "upgrade", id = "Coil", price = 40}))
assert(first:enqueue(person, {kind = "upgrade", id = "Coil", price = 40}))
waitFor(function() return person.UpgradeCoil and person.Scrap == 35 and records.Player_40001.sequence == 3 end)
-- Drain a pending write on leave, then acquire from another server session.
assert(first:enqueue(person, {kind = "reward", amount = 50}, "shift-2"))
first:leave(person)
waitFor(function() return first.sessions[person] == nil end)
local second, returning = Service.new(store), actor()
second:join(returning)
waitFor(function() return returning.ProfileStatus == "local" end)
assert(returning.Scrap == 85 and returning.UpgradeCoil and returning.RankXP == 125)
second:close()
assert(next(second.sessions) == nil)
print("EXPANSION PROFILE PASS serialized queue, ambiguous write, duplicate upgrade, drain, second-session restore")
-- Rank rewards derive only from confirmed lifetime XP, including after a lost reply.
records.Player_40002={version=1,scrap=240,rankXP=240,upgrades={},sequence=0}
local rankService,rankPlayer=Service.new(store),actor()
rankPlayer.UserId=40002
rankService:join(rankPlayer)
waitFor(function() return rankPlayer.ProfileStatus=="local" end)
assert(rankPlayer.CrewTitle=="Rookie")
failOnce=true
assert(rankService:enqueue(rankPlayer,{kind="reward",amount=10},"rank-shift"))
waitFor(function() return rankPlayer.LastRankUnlocked==2 and rankPlayer.ProfileStatus=="local" end)
assert(rankPlayer.RankXP==250 and rankPlayer.CrewTitle=="Runner")
rankPlayer.LastRankUnlocked=0
assert(rankService:enqueue(rankPlayer,{kind="upgrade",id="Coil",price=40}))
waitFor(function() return rankPlayer.UpgradeCoil and rankPlayer.ProfileStatus=="local" end)
assert(rankPlayer.RankXP==250 and rankPlayer.LastRankUnlocked==0,"spending changed rank or repeated unlock")
rankService:close()
local restoredService,restored=Service.new(store),actor()
restored.UserId=40002
restoredService:join(restored)
waitFor(function() return restored.ProfileStatus=="local" end)
assert(restored.RankXP==250 and restored.CrewTitle=="Runner" and restored.LastRankUnlocked==nil,"rank restore or duplicate celebration")
restoredService:close()
print("EXPANSION RANK PASS confirmed milestone, response loss, spending, second-session restore")
local preferencesService, preferencesPlayer=Service.new(store),actor()
preferencesPlayer.UserId=40003
preferencesService:join(preferencesPlayer)
waitFor(function() return preferencesPlayer.ProfileStatus=="local" end)
assert(preferencesPlayer.NextCrewRole=="Carrier" and preferencesPlayer.SavedMusicMuted==false)
assert(preferencesService:enqueue(preferencesPlayer,{kind="role",role="Technician"}))
assert(preferencesService:enqueue(preferencesPlayer,{kind="audio",musicMuted=true,effectsMuted=true}))
waitFor(function() return preferencesPlayer.NextCrewRole=="Technician" and preferencesPlayer.SavedEffectsMuted==true end)
preferencesService:close()
local againService,againPlayer=Service.new(store),actor()
againPlayer.UserId=40003
againService:join(againPlayer)
waitFor(function() return againPlayer.ProfileStatus=="local" end)
assert(againPlayer.NextCrewRole=="Technician" and againPlayer.SavedMusicMuted and againPlayer.SavedEffectsMuted)
againService:close()
print("EXPANSION PREFERENCES PASS role, audio and second-session restore")
