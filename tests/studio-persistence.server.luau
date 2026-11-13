assert(game:GetService("RunService"):IsStudio())
local test = game:GetService("StudioTestService")
local ok, failure = xpcall(function()
	task.delay(210, function() test:EndTest("PERSISTENCE TIMEOUT") end)
	local fixture = require(script.Parent.PersistenceFixture)
	local players = game:GetService("Players")
	local storage = game:GetService("ReplicatedStorage")
	local control = Instance.new("RemoteEvent")
	control.Name = "PersistenceTestControl"
	local ready, observed = {}, {}
	control.OnServerEvent:Connect(function(player, kind, ...)
		if kind == "ready" then ready[player] = true else observed[player] = {...} end
	end)
	control.Parent = storage
	local function waitFor(f, label, seconds)
		local deadline = os.clock() + (seconds or 10)
		repeat if f() then return end; task.wait(0.05) until os.clock() > deadline
		error("PERSISTENCE: " .. label)
	end
	local player = players:GetPlayers()[1] or players.PlayerAdded:Wait()
	local state = storage:WaitForChild("Freight"):WaitForChild("Shift")
	waitFor(function() return ready[player] and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		and state:GetAttribute("Phase") == "live" and player:GetAttribute("ProfileStatus") == "local" end, "ready", 70)
	local function clientCheck(activeRole)
		waitFor(function()
			control:FireClient(player, "observe")
			local values = observed[player]
			return values and values[1] == true and values[2] == 50 and values[3] == "Technician" and values[4] == activeRole
		end, "replicated journal / balance / selected and active roles")
	end
	if fixture.restoring then
		assert(player:GetAttribute("EndingBroadcast") == true and player:GetAttribute("EndingShelter") == false)
		assert(player:GetAttribute("Scrap") == 50 and player:GetAttribute("RankXP") == 50)
		assert(player:GetAttribute("NextCrewRole") == "Technician" and player:GetAttribute("CrewRole") == "Technician")
		clientCheck("Technician")
		print("PERSISTENCE PASS second process restored Broadcast, 50 Scrap, 50 XP, selected and active Technician on server and client")
		test:EndTest("PERSISTENCE RESTORE PASS")
		return
	end
	assert(player:GetAttribute("EndingBroadcast") == false and player:GetAttribute("EndingShelter") == false, "journal not empty")
	assert(player:GetAttribute("Scrap") == 0 and player:GetAttribute("RankXP") == 0, "profile not empty")
	assert(player:GetAttribute("CrewRole") == "Carrier" and state:GetAttribute("Target") == 5)
	local world = workspace:WaitForChild("Blackout Freight • Depot 07")
	local press = game:GetService("ServerStorage"):WaitForChild("FreightTestAction")
	local root, humanoid = player.Character.HumanoidRootPart, player.Character.Humanoid
	root:SetNetworkOwner(nil)
	local function flat(point) return Vector3.new(point.X, 0, point.Z) end
	local function walk(point)
		local carrying = player:GetAttribute("Carrying")
		for attempt = 1, 3 do
			local path = game:GetService("PathfindingService"):CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 5})
			path:ComputeAsync(root.Position, Vector3.new(point.X, root.Position.Y, point.Z))
			assert(path.Status == Enum.PathStatus.Success, "no walkable path")
			for _, waypoint in path:GetWaypoints() do
				if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
				humanoid:MoveTo(waypoint.Position)
				local deadline = os.clock() + 5
				repeat task.wait(0.05) until (flat(root.Position) - flat(waypoint.Position)).Magnitude < 2 or os.clock() > deadline
					or (carrying and not player:GetAttribute("Carrying"))
				if carrying and not player:GetAttribute("Carrying") then return false end
				if os.clock() > deadline then
					print("PERSISTENCE REPATH", attempt, root.Position, waypoint.Position, "caught", player:GetAttribute("Caught"))
					break
				end
			end
			if (flat(root.Position) - flat(point)).Magnitude < 3 then break end
			if attempt == 3 then error("walk could not reach prompt") end
		end
		task.wait(0.15)
		return true
	end
	local function interact(prompt)
		if not walk(prompt.Parent.WorldPosition + Vector3.new(0,0,prompt.ObjectText == "Power cell" and 3 or -3)) then return false end
		press:Invoke(prompt, player)
		return true
	end
	local function prompt(name) return assert(world:FindFirstChild(name)):FindFirstChildWhichIsA("ProximityPrompt", true) end
	local attempts = 0
	while state:GetAttribute("Delivered") < 5 do
		attempts += 1
		assert(attempts <= 12 and state:GetAttribute("Phase") == "live", "shift not completed within normal rules")
		local delivered = state:GetAttribute("Delivered") + 1
		local nearest, distance
		for _, model in world:GetChildren() do
			local candidate = model.Name == "Power Cell" and model:FindFirstChildWhichIsA("ProximityPrompt", true)
			if candidate and candidate.Enabled then
				local d = (candidate.Parent.WorldPosition - root.Position).Magnitude
				if not distance or d < distance then nearest, distance = candidate, d end
			end
		end
		interact(assert(nearest, "cell missing"))
		assert(player:GetAttribute("Carrying"), "pickup rejected")
		control:FireClient(player, "dash")
		if not interact(prompt("Delivery console")) then
			print("PERSISTENCE RETRY caught by Sentinel", player:GetAttribute("Caught"))
			continue
		end
		assert(state:GetAttribute("Delivered") == delivered, "delivery failed or Sentinel caught carrier")
		print("PERSISTENCE DELIVERY", delivered, player:GetAttribute("MovementVerified"))
	end
	assert(state:GetAttribute("Phase") == "routing")
	interact(prompt("01   BROADCAST"))
	waitFor(function() return state:GetAttribute("Phase") == "won" and player:GetAttribute("Scrap") == 50
		and player:GetAttribute("EndingBroadcast") == true and player:GetAttribute("JournalStatus") == "ready" end, "new ending and earned Scrap")
	assert(player:GetAttribute("EndingShelter") == false and player:GetAttribute("LastScrapAward") == 50)
	control:FireClient(player, "select")
	waitFor(function() return player:GetAttribute("NextCrewRole") == "Technician" and player:GetAttribute("ProfileStatus") == "local" end, "role remote accepted")
	clientCheck("Carrier")
	print("PERSISTENCE PASS empty journal, five walked deliveries, first Broadcast, 50 Scrap, client role selection")
	test:EndTest(fixture.snapshot())
end, debug.traceback)
if not ok then
	warn("PERSISTENCE FAILURE", failure)
	test:EndTest("PERSISTENCE FAIL: " .. tostring(failure))
end
