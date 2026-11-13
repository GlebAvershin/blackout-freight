local P = require("../src/shared/Progression")
assert(P.reward(0, 1.5) == 0 and P.reward(2, 1.25) == 25 and P.reward(8, 1.5) == 75)
assert(P.chooseHeat({}, false) == 1)
assert(P.chooseHeat({3,3,1}, true) == 1)
assert(P.chooseHeat({2,3}, false) == 2)
assert(P.chooseHeat({3,3,2}, false) == 3)
assert(P.chooseHeat({0,4,0/0,"3"}, false) == 1)
local Profile = require("../src/server/Profile")
local saved
local store = {UpdateAsync = function(_, _, f) saved = f(saved); return saved end}
local profile = Profile.new(store, "cap", function() return 1000 end)
profile:acquire(1)
for i=1,8 do profile:transact(1,i,{kind="reward",amount=100}) end
assert(saved.scrap == 600 and saved.rankXP == 600)
profile:release(1)
local nextServer = Profile.new(store,"next",function() return 1100 end)
nextServer:acquire(1)
assert(nextServer:transact(1,1,{kind="reward",amount=100}).lastAward == 0)
print("PASS: rewards, persistent hourly cap, heat votes, novice protection, ties")
