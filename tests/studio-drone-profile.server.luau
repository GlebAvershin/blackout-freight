assert(game:GetService("RunService"):IsStudio())
local studio = game:GetService("StudioTestService")
local players = game:GetService("Players")
local state = game.ReplicatedStorage:WaitForChild("Freight"):WaitForChild("Shift")
local world = workspace:WaitForChild("Blackout Freight • Depot 07")
local probe = require(script.Parent.DroneProbe)
local heartbeat = game:GetService("RunService").Heartbeat
task.delay(probe.timeout, function()
	studio:EndTest("PROFILE TIMEOUT clients=" .. #players:GetPlayers())
end)

local function summary(samples, index, scale)
	local ordered, sum = {}, 0
	for _, sample in samples do
		local value = sample[index] * scale
		table.insert(ordered, value)
		sum += value
	end
	table.sort(ordered)
	return string.format("%.4f/%.4f/%.4f", sum / #samples,
		ordered[math.ceil(#samples * 0.5)], ordered[math.ceil(#samples * 0.95)])
end

local ok, result = xpcall(function()
	repeat task.wait() until state:GetAttribute("Phase") == "live" and #players:GetPlayers() == 4
	assert(state:GetAttribute("Heat") == 5 and state:GetAttribute("Map") == "depot")
	assert(world:FindFirstChild("Swarm 1") and world:FindFirstChild("Swarm 2"))
	local drones = {world.Sentinel, world["Swarm 1"], world["Swarm 2"]}
	local function checkModels()
		for i, model in drones do
			local body = model.PrimaryPart
			local eye = body.CFrame:PointToObjectSpace(model.Eye.Position)
			local scale = if i == 1 then 1 else 0.45
			assert((eye - Vector3.new(0, 0.2, -1.67) * scale).Magnitude < 0.03, model.Name .. " eye detached")
			assert((model:GetPivot().Position - body.Position).Magnitude < 0.03, model.Name .. " pivot detached")
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") then
					assert(not part.CanCollide and not part.CanTouch)
				end
			end
		end
	end
	local roster = players:GetPlayers()
	table.sort(roster, function(a, b) return a.UserId < b.UserId end)
	local dropped = false
	players.PlayerRemoving:Connect(function() dropped = true end)
	for i, player in roster do
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart").Anchored = true
		character:PivotTo(CFrame.new((i - 2.5) * 4, 4, 59))
	end
	task.wait(5)
	checkModels()

	local cadenceFailures = {}
	local function measure(label)
		table.clear(probe.samples)
		local frames = {}
		local monitor = heartbeat:Connect(function(dt) table.insert(frames, {dt}) end)
		local started = os.clock()
		probe.record = true
		task.wait(probe.window)
		probe.record = false
		monitor:Disconnect()
		local elapsed = os.clock() - started
		local samples, hunt = probe.samples, 0
		local covered, bucketStart, bucketCount = 0, 0, 0
		local completeBuckets = 0
		local minRate, maxRate = math.huge, 0
		for _, sample in samples do
			if sample[5] == "hunt" then hunt += 1 end
			covered += sample[6]
			bucketCount += 1
			if covered - bucketStart >= 5 then
				local rate = bucketCount / (covered - bucketStart)
				minRate, maxRate = math.min(minRate, rate), math.max(maxRate, rate)
				completeBuckets += 1
				bucketStart, bucketCount = covered, 0
			end
		end
		assert(not dropped and #players:GetPlayers() == 4 and #samples >= 30, "incomplete sample")
		assert((not label:find("chase") and hunt == 0) or (label:find("chase") and hunt == #samples),
			"mixed drone modes: " .. hunt .. "/" .. #samples)
		local stats = string.format("%s n=%d hunt=%d hz=%.2f heartbeat_hz=%.2f frame_ms=%s total_ms=%s transforms_ms=%s rays=%s parts=%s tick_gap_ms=%s 5s_hz=%.2f..%.2f",
			label, #samples, hunt, #samples / elapsed, #frames / elapsed, summary(frames, 1, 1000), summary(samples, 1, 1000),
			summary(samples, 2, 1000), summary(samples, 3, 1), summary(samples, 4, 1),
			summary(samples, 6, 1000), minRate, maxRate)
		print("PROFILE WINDOW", stats)
		if probe.checkCadence then
			local heartbeatRate = #frames / elapsed
			if label:find("load") then
				assert(heartbeatRate >= 22 and heartbeatRate <= 24,
					"stress window did not sustain 22–24 server frames/s: " .. stats)
			else
				assert(heartbeatRate >= 45, "ordinary window has insufficient server frames: " .. stats)
			end
			if completeBuckets < math.floor(probe.window / 5) - 1 or minRate < 19 or maxRate > 21 then
				table.insert(cadenceFailures, stats)
			end
		end
		return stats
	end

	-- Drive each server frame to at least 43 ms in the controlled load windows.
	-- This is fixture-only load; clients and game logic still run in Studio.
	local function stress()
		local previous = os.clock()
		return heartbeat:Connect(function()
			local deadline = previous + 0.043
			while os.clock() < deadline do end
			previous = os.clock()
		end)
	end
	local patrol = measure("patrol")
	local loadedPatrol
	if probe.stress then
		local load = stress()
		task.wait(0.5)
		loadedPatrol = measure("load-patrol")
		load:Disconnect()
	end
	checkModels()
	local carrier = roster[1]
	local best, distance = nil, math.huge
	for _, part in game:GetService("CollectionService"):GetTagged("FreightPickup") do
		local gap = (part.Position - Vector3.new(-18, 0, 39)).Magnitude
		if gap < distance then best, distance = part, gap end
	end
	local prompt = assert(best):FindFirstChildWhichIsA("ProximityPrompt", true)
	carrier.Character:PivotTo(CFrame.new(prompt.Parent.WorldPosition + Vector3.new(0, 0, 1)))
	game.ServerStorage.FreightTestAction:Invoke(prompt, carrier)
	assert(carrier:GetAttribute("Carrying"), "pickup failed")
	-- Keep the carrier in the open central lane, above catch range and on the patrol side of the shutter.
	-- A moving target keeps the drone transforms active through the whole sample.
	carrier.Character:PivotTo(CFrame.new(0, 12, 15))
	local started = os.clock()
	local motion = heartbeat:Connect(function()
		carrier.Character:PivotTo(CFrame.new(0, 12, 4 + 11 * math.cos((os.clock() - started) * 0.9)))
	end)
	task.wait(0.5)
	local chase = measure("chase")
	local loadedChase
	if probe.stress then
		local load = stress()
		task.wait(0.5)
		loadedChase = measure("load-chase")
		load:Disconnect()
	end
	motion:Disconnect()
	checkModels()
	assert(world.Sentinel.PrimaryPart.TrackingBeam.Attachment1 ~= nil, "tracking beam lost")
	assert(#cadenceFailures == 0, "drone cadence regression: " .. table.concat(cadenceFailures, " | "))
	return table.concat({"clients=4 route=" .. tostring(state:GetAttribute("Operation")), patrol, chase,
		loadedPatrol, loadedChase}, " | ")
end, debug.traceback)
studio:EndTest(ok and "PROFILE PASS " .. result or "PROFILE FAIL " .. result)
