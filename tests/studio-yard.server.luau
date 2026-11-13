assert(game:GetService("RunService"):IsStudio())
local test = game:GetService("StudioTestService")
task.delay(100,function() test:EndTest("TIMEOUT") end)
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local state = game:GetService("ReplicatedStorage"):WaitForChild("Freight"):WaitForChild("Shift")
local world = workspace:WaitForChild("Blackout Freight • Depot 07")
local server = game:GetService("ServerStorage")
local press, prepare = server:WaitForChild("FreightTestAction"), server:WaitForChild("FreightTestPreparation")
local function waitFor(f,label,seconds)
	local deadline=os.clock()+(seconds or 8)
	repeat if f() then return end; task.wait(0.05) until os.clock()>deadline
	error("YARD QA "..label)
end
waitFor(function() return state:GetAttribute("Phase")=="live" and player.Character and player.Character:FindFirstChild("HumanoidRootPart") end,"spawn")
assert(state:GetAttribute("Map")=="yard")
local layout=assert(world:FindFirstChild("Freight Yard"))
assert(not world:FindFirstChild("Cargo container"),"depot clutter remained")
assert(#layout:GetChildren()>40)
local root=player.Character.HumanoidRootPart
root:SetNetworkOwner(nil)
local function go(position)
	player.Character.Humanoid:MoveTo(Vector3.new(position.X,root.Position.Y,position.Z))
	waitFor(function() return (Vector3.new(root.Position.X,0,root.Position.Z)-Vector3.new(position.X,0,position.Z)).Magnitude<2 end,"walk",12)
end
-- Walk through the unblocked crossing to the far side, before the first train.
go(Vector3.new(-26,3,10))
go(Vector3.new(-26,3,-18))
assert(root.Position.Z < -14,"crossing not reachable")
waitFor(function() return state:GetAttribute("TrainStatus")=="warning" end,"warning",15)
local warned=os.clock()
waitFor(function() return state:GetAttribute("TrainStatus")=="passing" end,"train",6)
assert(os.clock()-warned>=3.5,"warning too short")
local catches=player:GetAttribute("Caught")
player.Character:PivotTo(CFrame.new(0,3,-5))
waitFor(function() return player:GetAttribute("Caught")>catches end,"train collision",6)
assert(root.Position.Z>=54 and not player:GetAttribute("Carrying"),"train recovery failed")
local cell
for _, model in world:GetChildren() do
	if model.Name=="Power Cell" and model.PrimaryPart.Position.Z==35 then
		cell=model:FindFirstChildWhichIsA("ProximityPrompt",true); break
	end
end
assert(cell)
local function walkPrompt(prompt)
	local p=prompt.Parent.WorldPosition+Vector3.new(0,0,prompt.ObjectText=="Power cell" and 3 or -3)
	go(p); task.wait(0.2); press:Invoke(prompt,player)
end
walkPrompt(cell)
assert(player:GetAttribute("Carrying"))
walkPrompt(world["Delivery console"]:FindFirstChildWhichIsA("ProximityPrompt",true))
walkPrompt(world["01   BROADCAST"]:FindFirstChildWhichIsA("ProximityPrompt",true))
waitFor(function() return state:GetAttribute("Phase")=="won" end,"finish")
assert(player:GetAttribute("ArchiveYard"),"Mira yard recording missing")
prepare:Invoke(player,"map","depot")
waitFor(function() return state:GetAttribute("Phase")=="live" end,"depot return",24)
assert(state:GetAttribute("Map")=="depot" and not world:FindFirstChild("Freight Yard"))
assert(world:FindFirstChild("Cargo container") and world:FindFirstChild("Cell socket"),"depot not restored")
print("YARD QA PASS crossing walk, four-second warning, train recovery, delivery, Mira record, depot restore")
test:EndTest("PASS")
