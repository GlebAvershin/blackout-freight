-- Appended to expansion QA only; no live account or cloud DataStore.
local Season = require(game:GetService("ReplicatedStorage").Freight.Season)
local Service = require(game:GetService("ServerScriptService").Freight.ProfileService)
local function untilReady(fn,label)
 local deadline=os.clock()+12
 repeat if fn() then return end; task.wait(0.05) until os.clock()>deadline
 error("SEASON "..label)
end
local records={Player_40004={version=1,scrap=0,rankXP=0,upgrades={},sequence=0,
 seasons={[Season.Id]={deliveries=25,broadcast=true,shelter=false}}}}
local failOnce=true
local time=Season.EndsAt-1
local store={UpdateAsync=function(_,key,fn)
 fn(records[key]); local data=fn(records[key])
 if failOnce and data and data.sequence==1 then
  failOnce=false; time=Season.EndsAt+1; error("Offline across season expiry before commit")
 end
 if data then records[key]=data end
 return data
end}
local actor={UserId=40004,SetAttribute=function(self,k,v) self[k]=v end}
local clock=function() return time end
local service=Service.new(store,clock)
service:join(actor)
untilReady(function() return actor.ProfileStatus=="local" end,"load")
assert(actor.SeasonTier==2)
assert(service:enqueue(actor,{kind="reward",amount=50,deliveries=5,ending="shelter"},"final"))
untilReady(function() return actor.LastSeasonUnlocked==3 and actor.ProfileStatus=="local" end,"unlock")
assert(actor.Scrap==50 and actor.SeasonDeliveries==30)
service:close()
local restored={UserId=40004,SetAttribute=actor.SetAttribute}
local second=Service.new(store,clock); second:join(restored)
untilReady(function() return restored.ProfileStatus=="local" end,"restore")
assert(restored.SeasonTier==3 and restored.SeasonBroadcast and restored.SeasonShelter and not restored.LastSeasonUnlocked)
second:close()
player:SetAttribute("SeasonTier",3)
untilReady(function() return player.Character:FindFirstChild("Echo event badge") end,"badge missing")
local badge=player.Character["Echo event badge"]
assert(not badge.CanCollide and not badge.CanQuery and badge.Massless and badge.WeldConstraint.Part0.Parent==player.Character)
player:LoadCharacterAsync()
untilReady(function() return player.Character and player.Character:FindFirstChild("Echo event badge") end,"respawn")
player:SetAttribute("SeasonTier",0)
untilReady(function() return not player.Character:FindFirstChild("Echo event badge") end,"cleanup")
print("EXPANSION SEASON PASS retry across expiry, final milestone, second service, badge, respawn")
