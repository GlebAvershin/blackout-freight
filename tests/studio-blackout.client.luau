local Players = game:GetService("Players")
local collection = game:GetService("CollectionService")
local player = Players.LocalPlayer
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Freight")
local result = shared:WaitForChild("BlackoutResult")
local ok, failure = xpcall(function()
	local state = shared:WaitForChild("Shift")
	local ping = shared:WaitForChild("CrewPing")
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("FreightHUD")
	local sector = require(shared.SectorBlackout)
	local function waitFor(predicate, description, timeout)
		local deadline = os.clock() + (timeout or 10)
		repeat
			if predicate() then return end
			task.wait(0.05)
		until os.clock() >= deadline
		error(description)
	end
	local messages = {}
	ping.OnClientEvent:Connect(function(sender, kind, _, expiresAt)
		table.insert(messages, {sender, kind, expiresAt})
	end)
	waitFor(function() return state:GetAttribute("Phase") == "live" end, "first shift")
	assert(state:GetAttribute("BlackoutPhase") == nil, "first shift started with blackout")
	waitFor(function() return state:GetAttribute("Phase") == "lost" end, "introductory shift ended")
	waitFor(function() return #Players:GetPlayers() == 2 end, "crew of two")
	local crew = Players:GetPlayers()
	table.sort(crew, function(a, b) return a.UserId < b.UserId end)
	local sender = player == crew[1]
	if not sender then player:SetAttribute("FreightMuteCrewPings", true) end
	waitFor(function() return state:GetAttribute("Phase") == "live" end, "second shift", 24)
	local root = player.Character:WaitForChild("HumanoidRootPart")
	if sender then
		ping:FireServer("here", root.Position + Vector3.new(0, 0, 100))
		task.wait(0.4)
		ping:FireServer("unknown", root.Position)
		task.wait(0.4)
		ping:FireServer("here", root.Position)
		task.wait(0.4)
		ping:FireServer("here", root.Position)
	end
	waitFor(function() return #messages > 0 end, "ping was not replicated")
	assert(#messages == 1 and messages[1][1] == crew[1].UserId and messages[1][2] == "here", "invalid ping replicated")
	task.wait(0.5)
	assert(#messages == 1, "ping bypassed cooldown")
	assert((gui:FindFirstChild("CrewPingMarker") ~= nil) == sender, "local mute or own ping failed")
	waitFor(function() return state:GetAttribute("BlackoutPhase") == "warning" end, "second shift warning")
	local fixture
	for _, part in collection:GetTagged(sector.FixtureTag) do
		if part:FindFirstChildOfClass("PointLight") then fixture = part; break end
	end
	assert(fixture, "missing tagged sector fixture")
	local lamp = fixture:FindFirstChildOfClass("PointLight")
	local gate = workspace:FindFirstChild("Gate light", true)
	assert(gate and gate.Material == Enum.Material.Neon, "gate guidance missing")
	waitFor(function() return state:GetAttribute("BlackoutPhase") == "dark" end, "outage did not start")
	waitFor(function() return lamp.Brightness == 0 end, "sector light did not go dark")
	assert(gate.Material == Enum.Material.Neon, "outage hid gate guidance")
	waitFor(function() return not gui:FindFirstChild("CrewPingMarker") end, "expired ping remained")
	waitFor(function() return state:GetAttribute("BlackoutPhase") == nil end, "outage did not end")
	waitFor(function() return lamp.Brightness > 0 and fixture.Material == Enum.Material.Neon end, "sector light did not restore")
end, debug.traceback)
result:FireServer(if ok then nil else failure)
