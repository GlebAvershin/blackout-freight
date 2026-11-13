assert(game:GetService("RunService"):IsStudio())
local studio = game:GetService("StudioTestService")
task.delay(55, function() studio:EndTest("TIMEOUT") end)
local function waitFor(predicate, message)
	local deadline = os.clock() + 12
	repeat if predicate() then return end; task.wait(0.05) until os.clock() >= deadline
	error(message)
end
local ok, reason = xpcall(function()
	local players = game:GetService("Players")
	local player = players:GetPlayers()[1] or players.PlayerAdded:Wait()
	local state = game:GetService("ReplicatedStorage"):WaitForChild("Freight"):WaitForChild("Shift")
	local world = workspace:WaitForChild("Blackout Freight • Depot 07")
	local press = game:GetService("ServerStorage"):WaitForChild("FreightTestAction")
	waitFor(function() return state:GetAttribute("Phase") == "live" and player.Character and player.Character.PrimaryPart end, "spawn")
	assert(state:GetAttribute("Heat") == 5 and world:FindFirstChild("Swarm 1") and world:FindFirstChild("Swarm 2"))
	assert(game:GetService("Lighting").ExposureCompensation < 0)
	waitFor(function() return player.Character.PrimaryPart:FindFirstChild("WorkshopLamp") end, "lamp spawn")
	assert(player.Character.PrimaryPart.WorkshopLamp.Enabled)
	local function interact(prompt, offset)
		player.Character:PivotTo(CFrame.new(prompt.Parent.WorldPosition + offset))
		press:Invoke(prompt, player)
	end
	local cells = game:GetService("CollectionService"):GetTagged("FreightPickup")
	local count = 0
	for _, cell in cells do
		if cell:IsDescendantOf(world) then
			interact(cell:FindFirstChildWhichIsA("ProximityPrompt", true), Vector3.new(0,0,1))
			count += 1
			if count == 2 then break end
		end
	end
	assert(player:GetAttribute("CargoCount") == 2, "Carrier rack didn't pick up two batteries")
	local delivery = world["Delivery console"]:FindFirstChildWhichIsA("ProximityPrompt", true)
	interact(delivery, Vector3.new(0,0,-3))
	assert(state:GetAttribute("Delivered") == 1 and player:GetAttribute("CargoCount") == 1)
	press:Invoke(delivery, player)
	assert(state:GetAttribute("Delivered") == 2 and player:GetAttribute("CargoCount") == 0)
	press:Invoke(delivery, player)
	assert(state:GetAttribute("Delivered") == 2)
	waitFor(function() return state:GetAttribute("GateShield") == true end, "shield on")
	waitFor(function() return state:GetAttribute("GateShield") == false end, "shield expires")
	print("YARD HIGH HEAT QA PASS: Swarm, darkness, rack, lamp, shield")
end, debug.traceback)
studio:EndTest(ok and "PASS" or "FAIL " .. tostring(reason))
