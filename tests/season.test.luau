local Season = require("../src/shared/Season")
local Profile = require("../src/server/Profile")
assert(not Season.active(Season.StartsAt-1) and Season.active(Season.StartsAt))
assert(Season.active(Season.EndsAt-1) and not Season.active(Season.EndsAt))
local progress=Season.advance(nil,5,"broadcast",Season.StartsAt)
assert(progress.deliveries==5 and progress.broadcast and not progress.shelter)
assert(Season.tier(progress)==1)
local original=progress
progress=Season.advance(progress,5,nil,Season.StartsAt)
assert(original.deliveries==5, "mutated saved table in discarded UpdateAsync callback")
assert(Season.tier(progress)==1)
progress=Season.advance(progress,5,nil,Season.StartsAt)
assert(Season.tier(progress)==2)
progress=Season.advance(progress,0,"shelter",Season.StartsAt)
assert(not progress.shelter,"AFK ending counted")
for _=1,3 do progress=Season.advance(progress,5,"shelter",Season.StartsAt) end
assert(progress.deliveries==30 and Season.tier(progress)==3)
assert(Season.tier(Season.advance(progress,5,"broadcast",Season.EndsAt))==3,"expired reward disappeared")
assert(Season.advance(nil,5,"broadcast",Season.EndsAt).deliveries==0)
assert(Season.advance(nil,5,"broadcast",Season.StartsAt-1).deliveries==0)
assert(not pcall(Season.advance,nil,6,nil,Season.StartsAt))
assert(not pcall(Season.advance,nil,0/0,nil,Season.StartsAt))
assert(not pcall(Season.advance,nil,1,"invalid",Season.StartsAt))
local time=Season.StartsAt+100
local db,failAfter={},false
local store={UpdateAsync=function(_,key,fn)
 fn(db[key]); local data=fn(db[key]); if data then db[key]=data end
 if failAfter then error("lost response") end; return data
end}
local a=Profile.new(store,"one",function() return time end)
assert(a:acquire(1))
local op={kind="reward",amount=50,deliveries=5,ending="broadcast"}
local data=a:transact(1,1,op)
assert(data and data.seasons and data.seasons[Season.Id],"profile does not persist event progress")
assert(data.seasons[Season.Id].deliveries==5 and data.scrap==50)
failAfter=true; assert(a:transact(1,2,op)==nil); failAfter=false
assert(a:transact(1,2,op).seasons[Season.Id].deliveries==10)
assert(db.Player_1.scrap==100)
assert(a:transact(1,3,{kind="reward",amount=50}).seasons[Season.Id].deliveries==10,"legacy caller invented progress")
assert(a:release(1))
local b=Profile.new(store,"two",function() return time end)
assert(b:acquire(1).seasons[Season.Id].deliveries==10)
assert(b:transact(1,1,{kind="reward",amount=0,deliveries=5,ending="shelter"}).seasons[Season.Id].shelter,"Scrap cap blocked cosmetic progress")
time=Season.EndsAt
assert(b:acquire(1))
assert(b:transact(1,2,op).seasons[Season.Id].deliveries==15,"expired season gained progress")
assert(Season.tier(db.Player_1.seasons[Season.Id])==2)
db.Player_2={version=1,scrap=0,rankXP=0,upgrades={},seasons="bad"}
assert(b:acquire(2)==nil and db.Player_2.seasons=="bad","corrupt profile overwritten")
print("PASS: season window, participation, milestones, immutable callbacks, duplicate/lost replies, legacy profile and second-session restore")
-- Award eligibility is the enqueue time, not the later retry/commit time.
time=Season.EndsAt-1
local c=Profile.new(store,"boundary",function() return time end)
assert(c:acquire(3))
local late={kind="reward",amount=50,deliveries=5,ending="broadcast",earnedAt=time}
local normalUpdate=store.UpdateAsync
store.UpdateAsync=function() error("offline before commit") end
assert(c:transact(3,1,late)==nil)
store.UpdateAsync=normalUpdate
time=Season.EndsAt+1
local credited=c:transact(3,1,late)
assert(credited.seasons[Season.Id].deliveries==5 and credited.seasons[Season.Id].broadcast,"pre-expiry reward lost during retry")
assert(c:transact(3,2,{kind="reward",amount=50,deliveries=5,earnedAt=time+10})==nil,"future timestamp accepted")
print("PASS: retry across expiry preserves earned season award; future timestamps rejected")
db.Player_4={version=1,scrap=123,rankXP=123,upgrades={},seasons={[Season.Id]=false}}
assert(b:acquire(4)==nil and db.Player_4.scrap==123,"invalid false season silently loaded as empty")
print("PASS: malformed season cannot silently load as an empty record")
