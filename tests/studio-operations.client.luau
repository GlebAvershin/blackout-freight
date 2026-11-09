local player = game:GetService("Players").LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Freight")
local invite = require(shared:WaitForChild("FriendInvite"))
local operations = require(shared:WaitForChild("Operations"))
local state = shared:WaitForChild("Shift")
local gui = player:WaitForChild("PlayerGui"):WaitForChild("FreightHUD")
assert(gui:WaitForChild("InviteFriends"):IsA("TextButton"))
assert(gui:WaitForChild("EndingJournal"):WaitForChild("ArchiveReward"):IsA("TextLabel"))

local prompted = 0
local platform = {
	CanSendGameInviteAsync = function() return true end,
	PromptGameInvite = function(_, sender) assert(sender == player) prompted += 1 end,
}
assert(invite.open(platform, player, false) == "local" and prompted == 0)
assert(invite.open(platform, player, true) == "opened" and prompted == 1)
print("LAST SIGNAL QA PASS: invite UI and platform adapter in Studio client")

local seen = {}
while not (seen.west and seen.east) do
	local key = state:GetAttribute("Operation")
	local route = operations.Routes[key]
	if route and not seen[key] and state:GetAttribute("Phase") == "live" then
		local radio = gui.ShiftCard.Radio.Text
		if radio == route.start[1] or radio == route.start[2] then
			seen[key] = true
			print("LAST SIGNAL QA PASS: Mira radio and operation HUD " .. key)
		end
	end
	task.wait(0.1)
end
