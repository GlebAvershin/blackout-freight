local test = game:GetService("StudioTestService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Freight")
local state = shared:WaitForChild("Shift")
local result = Instance.new("RemoteEvent")
result.Name = "BlackoutResult"
local passed = {}
result.OnServerEvent:Connect(function(player, failure)
	if failure then test:EndTest("FAIL " .. tostring(failure)); return end
	passed[player] = true
	local count = 0
	for _ in passed do count += 1 end
	if count == 2 then test:EndTest("PASS") end
end)
result.Parent = shared
local phases = {}
state:GetAttributeChangedSignal("BlackoutPhase"):Connect(function()
	table.insert(phases, state:GetAttribute("BlackoutPhase") or "clear")
	if table.concat(phases, ",") ~= string.sub("warning,dark,clear", 1, #table.concat(phases, ",")) then
		test:EndTest("FAIL blackout phase order")
	end
end)
task.delay(55, function() test:EndTest("TIMEOUT " .. table.concat(phases, ",")) end)
