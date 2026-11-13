local Profile = require("../src/server/Profile")
local time = 1000
local database = {}
local failBefore, failAfter = false, false
local store = {}
function store:UpdateAsync(key, callback)
	if failBefore then error("network") end
	-- Roblox can invoke the callback repeatedly, discarding an earlier result.
	callback(database[key])
	local result = callback(database[key])
	if result then database[key] = result end
	if failAfter then error("response lost after commit") end
	return result
end
local a = Profile.new(store, "server-a-session", function() return time end)
local b = Profile.new(store, "server-b-session", function() return time end)
assert(a:acquire(7).scrap == 0)
assert(b:acquire(7) == nil)
local reward = {kind = "reward", amount = 50}
assert(a:transact(7, 1, reward).scrap == 50)
assert(a:transact(7, 1, reward).scrap == 50)
assert(a:transact(7, 3, reward) == nil)
failAfter = true
assert(a:transact(7, 2, reward) == nil)
failAfter = false
assert(a:transact(7, 2, reward).scrap == 100)
assert(a:transact(7, 3, {kind = "upgrade", id = "lamp", price = 40}).scrap == 60)
assert(a:transact(7, 4, {kind = "upgrade", id = "lamp", price = 40}).scrap == 60)
assert(a:transact(7, 5, {kind = "upgrade", id = "other", price = 99}).lastResult == "insufficient")
assert(a:transact(7, 6, {kind = "reward", amount = 0/0}) == nil)
assert(database.Player_7.sequence == 5)
assert(a:release(7))
assert(b:acquire(7).scrap == 60)
assert(a:transact(7, 6, reward) == nil)
assert(b:transact(7, 1, reward).scrap == 110)
time += 121
assert(b:refresh(7) == nil)
assert(a:acquire(7).scrap == 110)
assert(b:release(7) == nil)
failBefore = true
assert(b:acquire(8) == nil and database.Player_8 == nil)
failBefore = false
database.Player_9 = {version = 2, scrap = 1000}
assert(a:acquire(9) == nil and database.Player_9.scrap == 1000)
assert(database.Player_7.rankXP == 150 and database.Player_7.upgrades.lamp)
print("PASS: profile leases, duplicate callbacks, ambiguous commits, purchases, expiry, stale servers, corrupt/future saves")
-- Older profiles receive defaults; preference transactions never change earned XP.
local prefs = a:acquire(10)
assert(prefs.preferences.role=="Carrier" and prefs.preferences.musicMuted==false)
assert(a:transact(10,1,{kind="role",role="Scout"}).preferences.role=="Scout")
assert(a:transact(10,2,{kind="audio",musicMuted=true,effectsMuted=false}).preferences.musicMuted)
assert(a:transact(10,3,{kind="role",role="Admin"})==nil)
assert(a:transact(10,3,{kind="audio",musicMuted="yes",effectsMuted=false})==nil)
assert(a:release(10))
local restored=b:acquire(10)
assert(restored.preferences.role=="Scout" and restored.preferences.musicMuted and restored.rankXP==0 and restored.scrap==0)
print("PASS: preference defaults, validation, unchanged economy, second-server restore")
