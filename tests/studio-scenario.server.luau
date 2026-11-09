local Players = game:GetService("Players")
local storage = game:GetService("ReplicatedStorage")
local state = storage:WaitForChild("Freight"):WaitForChild("Shift")
local world = workspace:WaitForChild("Blackout Freight • Depot 07")
local test = game:GetService("ServerStorage"):WaitForChild("FreightTestAction")
local operations = require(storage.Freight.Operations)
local expectedPlayers = 2

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
	waitFor(function() return state:GetAttribute("Phase") == expected end, "expected phase " .. expected, 12)
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
end, "expected test clients", 35)
local a, b = table.unpack(Players:GetPlayers())
waitFor(function()
	return a.Character and a.Character:FindFirstChild("HumanoidRootPart")
		and (not b or b.Character and b.Character:FindFirstChild("HumanoidRootPart"))
end, "test clients ready", 20)
phase("live")
local deliver = promptOn("Delivery console")
local broadcast = promptOn("01   BROADCAST")
local shelter = promptOn("02   SHELTER")

local function carry(p)
	press(p, cell())
	waitFor(function() return p:GetAttribute("Carrying") end, "pickup " .. p.Name, 3)
end

local function deposit(p, expected)
	press(p, deliver)
	waitFor(function() return state:GetAttribute("Delivered") == expected end, "delivery " .. expected, 3)
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
deposit(winner, 1)
assert(winner:GetAttribute("FirstDelivery") == true)
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
assert(winner:GetAttribute("EndingBroadcast") and (not other or other:GetAttribute("EndingBroadcast")))
assert(world:FindFirstChild("Relay beacon").Material == Enum.Material.Neon)
assert(world:FindFirstChild("Shelter light").Material ~= Enum.Material.Neon)
print("LAST SIGNAL QA PASS: five deliveries and broadcast")
phase("live")
assert(state:GetAttribute("Delivered") == 0 and state:GetAttribute("Ending") == "")
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
print("LAST SIGNAL QA PASS: next shift reset, shelter, distinct lighting")
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
	win(broadcast)
	assert(winner:GetAttribute("ArchiveUnlockedThisShift"))
	print("LAST SIGNAL QA PASS: physical passage, deliveries and archive " .. key)
end

special("west", 35)
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
