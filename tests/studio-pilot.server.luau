assert(game:GetService("RunService"):IsStudio())
local studio = game:GetService("StudioTestService")
local players = game:GetService("Players")
task.delay(85, function() studio:EndTest("TIMEOUT") end)

local function waitFor(predicate, message, seconds)
	local deadline = os.clock() + (seconds or 8)
	repeat
		if predicate() then return end
		task.wait(0.05)
	until os.clock() >= deadline
	error(message)
end

local ok, reason = xpcall(function()
	local state = game:GetService("ReplicatedStorage"):WaitForChild("Freight"):WaitForChild("Shift")
	local world = workspace:WaitForChild("Blackout Freight • Depot 07")
	local storage = game:GetService("ServerStorage")
	local prepare = storage:WaitForChild("FreightTestPreparation")
	local interact = storage:WaitForChild("FreightTestAction")
	waitFor(function()
		if #players:GetPlayers() ~= 3 or state:GetAttribute("Phase") ~= "briefing" then return false end
		for _, player in players:GetPlayers() do
			if not player.Character or not player.Character.PrimaryPart or not player:GetAttribute("EndingShelter") then return false end
		end
		return true
	end, "Three eligible crew members did not spawn", 55)

	local operator, carrier, observer = table.unpack(players:GetPlayers())
	prepare:Invoke(operator, "pilot", true)
	assert(operator:GetAttribute("PilotVolunteer") == true, "Volunteer not accepted")
	state:SetAttribute("PilotTestReady", true)
	waitFor(function() return state:GetAttribute("Phase") == "live" end, "Shift did not start")
	assert(operator:GetAttribute("PilotingSentinel") == true, "Volunteer not selected")
	assert(not carrier:GetAttribute("PilotingSentinel") and not observer:GetAttribute("PilotingSentinel"))

	local cell
	for _, item in game:GetService("CollectionService"):GetTagged("FreightPickup") do
		if item:IsDescendantOf(world) and (not cell or item.Position.Z > cell.Position.Z) then cell = item end
	end
	local prompt = assert(cell):FindFirstChildWhichIsA("ProximityPrompt", true)
	local pickup = prompt.Parent.WorldPosition + Vector3.new(0, 0, 2)
	operator.Character:PivotTo(CFrame.new(pickup))
	interact:Invoke(prompt, operator)
	assert(not operator:GetAttribute("Carrying"), "Operator took crew cargo")

	local drone = world.Sentinel
	local start = drone:GetPivot().Position
	operator.Character:PivotTo(CFrame.new(start + Vector3.new(0, 0, 12)))
	waitFor(function() return drone:GetPivot().Position.Z > start.Z + 4 end, "Drone did not follow the operator")

	operator.Character.Humanoid.Health = 0
	waitFor(function() return operator:GetAttribute("PilotingSentinel") == false end, "Operator was not released")
	carrier.Character:PivotTo(CFrame.new(pickup))
	interact:Invoke(prompt, carrier)
	assert(carrier:GetAttribute("Carrying"), "Crew could not pick up cargo")
	waitFor(function()
		return state:GetAttribute("SentinelMode") == "hunt" and carrier:GetAttribute("Tracked")
	end, "AI did not reacquire crew cargo")
end, debug.traceback)
studio:EndTest(ok and "PASS" or "FAIL " .. tostring(reason))
