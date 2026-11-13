local Brain = require("../src/shared/SentinelBrain")
assert(Brain.variant(1,true)=="Sentinel" and Brain.variant(3,false)=="Sentinel" and Brain.variant(2,true)=="Tracker")
local brain=Brain.new()
local a={id=1,x=4,z=10,priority=10,visible=true}
local b={id=2,x=8,z=20,priority=5,visible=false}
local id,x,z,mode=brain.choose("Tracker",0,{a,b})
assert(id==1 and mode=="hunt")
a.visible=false; a.x=90
id,x,z,mode=brain.choose("Tracker",1,{a,b})
assert(id==nil and x==4 and z==10 and mode=="search", "memory must not follow unseen movement")
id,x,z,mode=brain.choose("Tracker",3,{a,b})
assert(id==nil and x==nil and mode=="patrol", "memory must expire")
a.visible=true
assert(brain.choose("Tracker",4,{a,b})==1)
a.protected=true
id,x,z,mode=brain.choose("Tracker",4.1,{a,b})
assert(id==nil and mode=="patrol", "shelter must remove remembered target")
a.protected=false
assert(brain.choose("Tracker",5,{a,b})==1)
brain.clear(); a.visible=false
id,x,z,mode=brain.choose("Tracker",5.1,{a,b})
assert(id==nil and mode=="patrol", "decoy/round reset clears memory")
assert(brain.choose("Sentinel",6,{a,b})==2, "classic priority changed")
b.visible=true
assert(brain.choose("Tracker",7,{a,b})==2)
id,x,z,mode=brain.choose("Tracker",7.1,{})
assert(id==nil and mode=="patrol", "delivered/disconnected cargo remains target")
print("PASS: tracker visibility, stale position, expiry, shelter, decoy, classic priority, beginner gate")
