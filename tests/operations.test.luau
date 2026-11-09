local Operations = require("../src/shared/Operations")
local Invite = require("../src/shared/FriendInvite")

assert(Operations.next(false, nil, nil) == nil)
assert(Operations.next(true, nil, nil) == "west")
assert(Operations.next(true, "west", "west") == nil)
assert(Operations.next(true, nil, "west") == "east")
assert(Operations.next(true, nil, "east") == "west")
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
local service = {
	CanSendGameInviteAsync = function(_, sender) assert(sender == player) return true end,
	PromptGameInvite = function(_, sender) assert(sender == player) called += 1 end,
}
assert(Invite.open(service, player, false) == "local" and called == 0)
assert(Invite.open(service, player, true) == "opened" and called == 1)
service.CanSendGameInviteAsync = function() return false end
assert(Invite.open(service, player, true) == "unavailable" and called == 1)
service.CanSendGameInviteAsync = function() return true end
service.PromptGameInvite = function() error("platform unavailable") end
assert(Invite.open(service, player, true) == "unavailable")
print("PASS: route rotation, route inventory, drone path, native invite and unavailable states")
