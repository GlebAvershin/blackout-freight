local Operations = require("../src/shared/Operations")
local Invite = require("../src/shared/FriendInvite")

assert(Operations.next(false, nil, nil) == nil)
assert(Operations.next(true, nil, nil) == "west")
assert(Operations.next(true, "west", "west") == nil)
assert(Operations.next(true, nil, "west") == "east")
assert(Operations.next(true, nil, "east") == "west")
assert(Operations.next(false, "west", "west", true) == "west", "accepted crew invite can replay West")
assert(Invite.crewJoin({LaunchData = "freight-west:shift-token", ReferredByPlayerId = 42}, "shift-token"))
assert(not Invite.crewJoin({LaunchData = "freight-west:shift-token"}, "shift-token"))
assert(not Invite.crewJoin({LaunchData = "freight-west:old", ReferredByPlayerId = 42}, "shift-token"))
assert(not Invite.crewJoin({LaunchData = "freight-west:", ReferredByPlayerId = 42}, ""))
assert(Operations.nextObjective(false, false, false, false) == "bothEndings")
assert(Operations.nextObjective(true, false, false, false) == "shelter")
assert(Operations.nextObjective(false, true, false, false) == "broadcast")
assert(Operations.nextObjective(true, true, false, false) == "bothRecords")
assert(Operations.nextObjective(true, true, true, false) == "east")
assert(Operations.nextObjective(true, true, false, true) == "west")
assert(Operations.nextObjective(true, true, true, true) == "complete")
for key, route in Operations.Routes do
	local seen = {}
	for _, id in route.cells do
		assert(id >= 1 and id <= 12 and not seen[id], key)
		seen[id] = true
	end
	assert(#route.cells == 8 and seen[1] and seen[2], key)
	local x, z = Operations.waypoint(route, 0, 48, 2, 15)
	assert(x == route.gap and z == Operations.DividerZ + 4)
	x, z = Operations.waypoint(route, route.gap, 35, 2, 15)
	assert(x == route.gap and z == Operations.DividerZ - 4)
	x, z = Operations.waypoint(route, route.gap, 25, 2, 15)
	assert(x == 2 and z == 15)
end

local player = {}
local called = 0
local sentOptions
local service = {
	CanSendGameInviteAsync = function(_, sender) assert(sender == player) return true end,
	PromptGameInvite = function(_, sender, options)
		assert(sender == player)
		called += 1
		sentOptions = options
	end,
}
assert(Invite.open(service, player, false) == "local" and called == 0)
assert(Invite.open(service, player, true) == "opened" and called == 1 and sentOptions == nil)
local crewInvite = {PromptMessage = "Recover the Black Box"}
assert(Invite.open(service, player, true, crewInvite) == "opened" and called == 2 and sentOptions == crewInvite)
service.CanSendGameInviteAsync = function() return false end
assert(Invite.open(service, player, true) == "unavailable" and called == 2)
service.CanSendGameInviteAsync = function() return true end
service.PromptGameInvite = function() error("platform unavailable") end
assert(Invite.open(service, player, true) == "unavailable")
print("PASS: route rotation, route inventory, drone path, native invite and unavailable states")
