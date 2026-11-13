local Players = game:GetService("Players")
local storage = game:GetService("ReplicatedStorage")
local state = storage:WaitForChild("Freight"):WaitForChild("Shift")
local world = workspace:WaitForChild("Blackout Freight • Depot 07")
local test = game:GetService("ServerStorage"):WaitForChild("FreightTestAction")
local operations = require(storage.Freight.Operations)
local studioTest = game:GetService("StudioTestService")
local expectedPlayers = 2
local argsAvailable, testArgs = pcall(studioTest.GetTestArgs, studioTest)
local restore = argsAvailable and type(testArgs) == "string" and testArgs:match("^FourPlayerRestore:")
local restoreCrew = argsAvailable and type(testArgs) == "string" and testArgs:match("^BlackBoxCrewRestore:(.+)$")
local writeCrew = argsAvailable and testArgs == "BlackBoxCrewWrite"
if argsAvailable and (testArgs == "FourPlayerShift" or restore) then
	expectedPlayers = 4
	task.delay(85, function()
		studioTest:EndTest("Four-player shift timed out")
	end)
end

local function waitFor(test, label, seconds)
	local deadline = os.clock() + (seconds or 5)
	repeat
		local value = test()
		if value then return value end
		task.wait(0.05)
	until os.clock() >= deadline
	error("LAST SIGNAL QA: " .. label, 2)
end

local function phase(expected)
	waitFor(function() return state:GetAttribute("Phase") == expected end, "expected phase " .. expected, 24)
end

local function promptOn(name)
	return world:FindFirstChild(name):FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function placeAt(player, prompt, xOffset)
	local point = prompt.Parent.WorldPosition + Vector3.new(xOffset or 0, 0, 3)
	local pos = Vector3.new(point.X, 3, point.Z)
	player.Character:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
	return pos + Vector3.new(0, 2, 3)
end

local function press(player, prompt)
	placeAt(player, prompt)
	test:Invoke(prompt, player)
end

local function cell()
	local nearest
	local drone = world:FindFirstChild("Sentinel"):GetPivot().Position
	for _, model in world:GetChildren() do
		local prompt = model.Name == "Power Cell" and model:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt and prompt.Enabled then
			local pos = prompt.Parent.WorldPosition
			if (pos - drone).Magnitude > 20 and (not nearest or pos.Z > nearest.Parent.WorldPosition.Z) then
				nearest = prompt
			end
		end
	end
	return assert(nearest, "LAST SIGNAL QA: no active cell")
end

waitFor(function()
	return #Players:GetPlayers() >= expectedPlayers
end, "expected test clients", expectedPlayers == 4 and 65 or 35)
local crew = Players:GetPlayers()
if restoreCrew then
	assert(#crew == 2, "expected two returning crew members")
	local records = game:GetService("HttpService"):JSONDecode(restoreCrew)
	local sharedTime
	for _, player in crew do
		local saved = assert(records[tostring(player.UserId)], "missing saved crew member")
		waitFor(function() return player:GetAttribute("JournalStatus") == "ready" end, "crew journal ready")
		local time = player:GetAttribute("BestBlackBoxCrewSeconds")
		assert(player:GetAttribute("ArchiveBlackBox") and type(time) == "number" and time > 0)
		assert(time == saved.bestBlackBoxCrewSeconds and (not sharedTime or time == sharedTime))
		sharedTime = time
	end
	studioTest:EndTest("Black Box restored for both crew members: " .. sharedTime .. "s")
	return
end
if restore then
	assert(#crew == 4, "expected four returning players")
	for _, player in crew do
		waitFor(function() return player:GetAttribute("JournalStatus") == "ready" end, "journal ready for " .. player.Name)
		assert(player:GetAttribute("EndingBroadcast") == true, "new server did not restore Broadcast for " .. player.Name)
		assert(player:GetAttribute("EndingShelter") == false, "new server restored an unearned ending")
	end
	print("LAST SIGNAL QA PASS: second Studio server restored Broadcast for all four returning clients")
	studioTest:EndTest("Four-player journal restore passed")
	return
end
local a, b = table.unpack(crew)
waitFor(function()
	for _, player in crew do
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
			return false
		end
	end
	return true
end, "test clients ready", 20)
phase("live")
local deliver = promptOn("Delivery console")
local broadcast = promptOn("01   BROADCAST")
local shelter = promptOn("02   SHELTER")
local decoy = assert(promptOn("Decoy beacon"), "QA beacon has no prompt")

local function carry(p)
	press(p, cell())
	waitFor(function() return p:GetAttribute("Carrying") end, "pickup " .. p.Name, 3)
end

local function deposit(p, expected)
	press(p, deliver)
	waitFor(function() return state:GetAttribute("Delivered") == expected end, "delivery " .. expected, 3)
end

if expectedPlayers == 4 then
	assert(#crew == 4, "expected four player profiles")
	for _, player in crew do
		assert(player:GetAttribute("EndingBroadcast") == false, "expected a clean journal")
	end
	local sharedCell = cell()
	local carrier
	for i, player in crew do
		placeAt(player, sharedCell, (i - 2.5) * 1.2)
		test:Invoke(sharedCell, player)
		if player:GetAttribute("Carrying") then
			assert(not carrier, "one battery was picked up by more than one player")
			carrier = player
		end
	end
	assert(carrier, "no player picked up the contested battery")
	deposit(carrier, 1)
	local delivered = 1
	for _, player in crew do
		if player ~= carrier then
			carry(player)
			delivered += 1
			deposit(player, delivered)
		end
	end
	carry(carrier)
	deposit(carrier, 5)
	phase("routing")
	press(crew[4], broadcast)
	phase("won")
	assert(state:GetAttribute("Ending") == "broadcast" and state:GetAttribute("Delivered") == 5)
	for _, player in crew do
		assert(player:GetAttribute("ShiftDeliveries") == (player == carrier and 2 or 1), "incorrect personal score")
		assert(player:GetAttribute("EndingBroadcast") and not player:GetAttribute("Carrying"), "ending or cargo was not updated")
	end
	local snapshot = assert(game:GetService("ServerStorage"):FindFirstChild("FreightTestSnapshotJournal"), "QA journal snapshot is missing")
	print("LAST SIGNAL QA PASS: four clients, five deliveries and Broadcast in all four journals")
	studioTest:EndTest("FourPlayerRestore:" .. snapshot:Invoke())
	return
end

local same = cell()
test:Invoke(same, a)
assert(not a:GetAttribute("Carrying"), "LAST SIGNAL QA: remote pickup succeeded")
local winner, other = a, nil
if b then
	placeAt(a, same, -1.4)
	placeAt(b, same, 1.4)
	test:Invoke(same, a)
	test:Invoke(same, b)
	waitFor(function() return a:GetAttribute("Carrying") or b:GetAttribute("Carrying") end, "contested cell", 3)
	assert(a:GetAttribute("Carrying") ~= b:GetAttribute("Carrying"), "LAST SIGNAL QA: duplicate cargo")
	winner = a:GetAttribute("Carrying") and a or b
	other = winner == a and b or a
else
	press(winner, same)
end
if other then
	waitFor(function() return winner:GetAttribute("Tracked") and decoy.Enabled end, "beacon ready during pursuit")
	task.wait(0.6) -- Let both HUDs render readiness before attempting activation.
	test:Invoke(decoy, winner)
	assert(state:GetAttribute("DecoyUntil") == 0, "carrier must not activate the beacon")
	other.Character:PivotTo(CFrame.new(0, 3, 65))
	test:Invoke(decoy, other)
	assert(state:GetAttribute("DecoyUntil") == 0, "remote activation must fail")
	press(other, decoy)
	local deadline = state:GetAttribute("DecoyUntil")
	assert(deadline > workspace:GetServerTimeNow())
	waitFor(function() return not winner:GetAttribute("Tracked") end, "beacon interrupts pursuit")
	assert(winner:GetAttribute("Carrying") and not decoy.Enabled)
	test:Invoke(decoy, other)
	assert(state:GetAttribute("DecoyUntil") == deadline, "shared cooldown must reject repeat activation")
	print("LAST SIGNAL QA PASS: decoy interruption, proximity and cooldown")
end
winner:SetAttribute("Aurora", true)
deposit(winner, 1)
local pulse = assert(world:FindFirstChild("Delivery pulse"), "missing delivery effect")
assert(pulse.Color == Color3.fromRGB(215, 127, 255), "Aurora delivery effect must be violet")
winner:SetAttribute("Aurora", false)
print("LAST SIGNAL QA PASS: Aurora delivery effect")
assert(winner:GetAttribute("FirstDelivery") == true)
assert(winner:GetAttribute("ShiftDeliveries") == 1 and (not other or other:GetAttribute("ShiftDeliveries") == 0))
press(winner, deliver)
assert(winner:GetAttribute("ShiftDeliveries") == 1, "empty delivery changed the personal total")
if other then
	carry(other)
	local corpse = other.Character
	corpse:FindFirstChildOfClass("Humanoid").Health = 0
	corpse:PivotTo(CFrame.new(25, 3, 60))
	waitFor(function() return not other:GetAttribute("Carrying") end, "reset releases cargo")
	print("LAST SIGNAL QA PASS: contested cell and death recovery")
end
assert(state:GetAttribute("Delivered") == 1)
for i = 2, 5 do
	carry(winner)
	deposit(winner, i)
end
phase("routing")
assert(not deliver.Enabled and broadcast.Enabled and shelter.Enabled)
press(winner, broadcast)
phase("won")
assert(state:GetAttribute("Ending") == "broadcast")
assert(state:GetAttribute("RouteSource") == "chosen")
assert(winner:GetAttribute("ShiftDeliveries") == 5 and not winner:GetAttribute("Tracked"))
assert(winner:GetAttribute("EndingBroadcast") and (not other or other:GetAttribute("EndingBroadcast")))
assert(winner:GetAttribute("SignalUnlockedThisShift") == true, "the first ending must announce Signal Amber")
assert(world:FindFirstChild("Relay beacon").Material == Enum.Material.Neon)
assert(world:FindFirstChild("Shelter light").Material ~= Enum.Material.Neon)
assert(winner:GetAttribute("DispatchCompletedThisShift") and winner:GetAttribute("DispatchWeeks") == 1)
assert(not other or other:GetAttribute("DispatchWeeks") == 0)
assert((winner:GetAttribute("BestClearSeconds") or 0) > 0 and winner:GetAttribute("NewBestThisShift"))
assert(not other or not other:GetAttribute("BestClearSeconds"), "a non-delivering player cannot set a record")
print("LAST SIGNAL QA PASS: five deliveries, broadcast and weekly contract")
phase("live")
assert(state:GetAttribute("Delivered") == 0 and state:GetAttribute("Ending") == "")
assert(winner:GetAttribute("SignalUnlockedThisShift") == false, "the unlock announcement must clear for the next shift")
assert(winner:GetAttribute("BestClearSeconds") and not winner:GetAttribute("NewBestThisShift"))
assert(winner:GetAttribute("ShiftDeliveries") == 0, "next shift retained the personal total")
for i = 1, 5 do
	carry(winner)
	deposit(winner, i)
end
phase("routing")
press(winner, shelter)
phase("won")
assert(state:GetAttribute("Ending") == "shelter")
assert(winner:GetAttribute("EndingBroadcast") and winner:GetAttribute("EndingShelter"))
assert(not other or (other:GetAttribute("EndingBroadcast") and not other:GetAttribute("EndingShelter")))
assert(world:FindFirstChild("Shelter light").Material == Enum.Material.Neon)
assert(world:FindFirstChild("Relay beacon").Material ~= Enum.Material.Neon)
assert(winner:GetAttribute("DispatchWeeks") == 1 and not winner:GetAttribute("DispatchCompletedThisShift"))
print("LAST SIGNAL QA PASS: next shift reset, shelter, distinct lighting and no duplicate weekly credit")
assert(not winner:GetAttribute("ArchiveWest") and not winner:GetAttribute("ArchiveEast"))

local function win(console)
	for i = 1, 5 do
		carry(winner)
		deposit(winner, i)
	end
	phase("routing")
	press(winner, console)
	phase("won")
end

local function special(key, blockedGap)
	phase("live")
	assert(state:GetAttribute("Operation") == key)
	local route = operations.Routes[key]
	local layout = assert(world:FindFirstChild("Service diversion"))
	assert(layout["Service passage"].Position.X == route.gap)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {layout}
	params.RespectCanCollide = true
	local function blocked(x)
		return workspace:Raycast(Vector3.new(x, 3, operations.DividerZ + 6), Vector3.new(0, 0, -12), params)
	end
	assert(blocked(0) and blocked(blockedGap) and not blocked(route.gap))
	task.wait(0.8)
	if key == "west" then
		local box = assert(promptOn("Black Box"), "the West Bypass should contain optional cargo")
		assert(not winner:GetAttribute("ArchiveBlackBox") and state:GetAttribute("BlackBoxStatus") == "available")
		test:Invoke(box, winner)
		assert(not winner:GetAttribute("Carrying"), "remote Black Box pickup succeeded")
		press(winner, box)
		assert(winner:GetAttribute("BlackBoxCarrying") and state:GetAttribute("BlackBoxStatus") == "carried")
		if other then
			waitFor(function() return winner:GetAttribute("Tracked") and decoy.Enabled end, "Sentinel pursues the Black Box")
			press(other, decoy)
			assert(state:GetAttribute("DecoyUntil") > workspace:GetServerTimeNow(), "teammate did not divert Sentinel")
		end
		press(winner, deliver)
		assert(state:GetAttribute("BlackBoxStatus") == "secured" and not winner:GetAttribute("Carrying"))
		assert(winner:GetAttribute("ArchiveBlackBox"), "delivery must unlock Mira's recording")
		local crewTime = winner:GetAttribute("BestBlackBoxCrewSeconds")
		if other then
			assert(other:GetAttribute("ArchiveBlackBox") and crewTime and crewTime > 0
				and crewTime == other:GetAttribute("BestBlackBoxCrewSeconds"))
		else
			assert(crewTime == nil, "solo extraction cannot set a crew record")
		end
		assert(state:GetAttribute("Delivered") == 0 and winner:GetAttribute("ShiftDeliveries") == 0, "optional cargo changed the main score")
		print("LAST SIGNAL QA PASS: optional Black Box extraction", other and "with crew assist" or "solo")
	else
		assert(not world:FindFirstChild("Black Box") and state:GetAttribute("BlackBoxStatus") == "")
	end
	win(broadcast)
	assert(winner:GetAttribute("ArchiveUnlockedThisShift"))
	print("LAST SIGNAL QA PASS: physical passage, deliveries and archive " .. key)
end

special("west", 35)
if writeCrew then
	assert(#crew == 2, "expected two crew members")
	local snapshot = assert(game:GetService("ServerStorage"):FindFirstChild("FreightTestSnapshotJournal")):Invoke()
	local records = game:GetService("HttpService"):JSONDecode(snapshot)
	for _, player in crew do
		local saved = assert(records[tostring(player.UserId)], "missing saved crew member")
		assert(saved.blackBox and saved.bestBlackBoxCrewSeconds == player:GetAttribute("BestBlackBoxCrewSeconds"))
	end
	studioTest:EndTest("BlackBoxCrewRestore:" .. snapshot)
	return
end
assert(winner:GetAttribute("ArchiveWest") and not winner:GetAttribute("ArchiveGold"))
phase("live")
assert(state:GetAttribute("Operation") == "" and not world:FindFirstChild("Service diversion"))
win(shelter)
special("east", -35)
assert(winner:GetAttribute("ArchiveEast") and winner:GetAttribute("ArchiveGold"))
assert(not other or not other:GetAttribute("ArchiveWest"))
phase("live")
carry(winner)
local shell
for _, model in world:GetChildren() do
	if model.Name == "Power Cell" and model.PrimaryPart:FindFirstChild("TrackingTarget") then
		shell = model.PrimaryPart
	end
end
assert(shell and shell.Color == Color3.fromRGB(185, 130, 46))
print("LAST SIGNAL QA PASS: post-story gold casing applied to carried battery")
require(script.Parent.JournalScenario)(require(script.Parent.EndingJournal))
pcall(function()
	game:GetService("StudioTestService"):EndTest("Last Signal QA passed")
end)
