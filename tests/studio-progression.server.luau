assert(game:GetService("RunService"):IsStudio())
local test = game:GetService("StudioTestService")
task.delay(65, function() test:EndTest("TIMEOUT") end)
local players = game:GetService("Players")
local player = players:GetPlayers()[1] or players.PlayerAdded:Wait()
local storage = game:GetService("ReplicatedStorage")
local state = storage:WaitForChild("Freight"):WaitForChild("Shift")
local action = game:GetService("ServerStorage"):WaitForChild("FreightTestAction")
local world = workspace:WaitForChild("Blackout Freight • Depot 07")
local function waitFor(f, label, seconds)
	local deadline = os.clock() + (seconds or 8)
	repeat if f() then return end; task.wait(0.05) until os.clock() > deadline
	error(label)
end
waitFor(function() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") and state:GetAttribute("Phase") == "live" end, "spawn")
local character = player.Character
local root, humanoid = character.HumanoidRootPart, character.Humanoid
root:SetNetworkOwner(nil)
local function nearestCell()
	local nearest, distance
	for _, model in world:GetChildren() do
		if model.Name == "Power Cell" and model.PrimaryPart then
			local p = model:FindFirstChildWhichIsA("ProximityPrompt", true)
			local d = (model.PrimaryPart.Position - root.Position).Magnitude
			if p and p.Enabled and (not distance or d < distance) then nearest, distance = p, d end
		end
	end
	return assert(nearest)
end
local function prompt(name) return assert(world:FindFirstChild(name)):FindFirstChildWhichIsA("ProximityPrompt", true) end
local function walk(p)
	local point = p.Parent.WorldPosition + Vector3.new(0,0,p.ObjectText == "Power cell" and 3 or -3)
	humanoid:MoveTo(Vector3.new(point.X, root.Position.Y, point.Z))
	waitFor(function() return (Vector3.new(root.Position.X,0,root.Position.Z) - Vector3.new(point.X,0,point.Z)).Magnitude < 2 end, "walk to " .. p.ObjectText)
	task.wait(0.15)
	action:Invoke(p, player)
end
walk(nearestCell())
assert(player:GetAttribute("Carrying"), "normal pickup")
walk(prompt("Delivery console"))
assert(state:GetAttribute("Phase") == "routing", "normal delivery")
walk(prompt("01   BROADCAST"))
waitFor(function() return state:GetAttribute("Phase") == "won" and player:GetAttribute("Scrap") == 10 end, "award after actual delivery")
assert(player:GetAttribute("LastScrapAward") == 10)
print("PROGRESSION GAMEPLAY PASS walked delivery earns 10 Scrap")
player:SetAttribute("HeatVote", 3)
waitFor(function() return state:GetAttribute("Phase") == "live" end, "second shift", 24)
assert(state:GetAttribute("Heat") == 3, "heat vote not applied to next shift")
local function teleport(p)
	local point = p.Parent.WorldPosition + Vector3.new(0,0,p.ObjectText == "Power cell" and 3 or -3)
	character:PivotTo(CFrame.new(point.X,3,point.Z))
	action:Invoke(p, player)
end
teleport(nearestCell())
assert(player:GetAttribute("Carrying"), "teleport fixture pickup")
teleport(prompt("Delivery console"))
teleport(prompt("01   BROADCAST"))
waitFor(function() return state:GetAttribute("Phase") == "won" end, "second finish")
task.wait(0.5)
assert(player:GetAttribute("Scrap") == 10, "teleported delivery earned currency")
print("PROGRESSION GAMEPLAY PASS teleported delivery earns no Scrap")
test:EndTest("PASS")
