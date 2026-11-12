-- Run against a disposable copy of the release place via Studio RunScript.
-- Simulate MarketplaceService's event without touching player entitlements or Roblox funds.
local test = game:GetService("StudioTestService")
local shift = game:GetService("ServerScriptService"):FindFirstChild("Shift", true)
assert(shift and shift:IsA("Script"))
local signal = Instance.new("BindableEvent")
signal.Name = "CrewMarketplaceFixture"
signal.Parent = game:GetService("ServerStorage")
local hook = "MarketplaceService.PromptGamePassPurchaseFinished"
assert(shift.Source:find(hook, 1, true))
shift.Source = shift.Source:gsub("MarketplaceService%.PromptGamePassPurchaseFinished", 'game:GetService("ServerStorage"):WaitForChild("CrewMarketplaceFixture").Event', 1)
local shiftSource = shift.Source
for _, variable in {"decoy", "deliver", "prompt"} do
	shiftSource = shiftSource:gsub(variable .. "%.Triggered:Connect%(function%(player%)", "connectPrompt(" .. variable .. ", function(player)")
end
local promptHook = [==[
assert(RunService:IsStudio(), "QA build is for Studio only")
local handlers = setmetatable({}, {__mode = "k"})
local function connectPrompt(prompt, callback)
	prompt.Triggered:Connect(callback)
	handlers[prompt] = callback
end
local test = Instance.new("BindableFunction")
test.Name = "FreightTestAction"
test.OnInvoke = function(prompt, player)
	assert(handlers[prompt], "unknown prompt")(player)
end
test.Parent = game:GetService("ServerStorage")

]==]
local n
shiftSource, n = shiftSource:gsub("local routePrompts = {}", promptHook .. "local routePrompts = {}", 1)
assert(n == 1)
shift.Source = shiftSource
local server = Instance.new("Script")
server.Source = [=[
local storage = game:GetService("ReplicatedStorage")
local test = game:GetService("StudioTestService")
local event = Instance.new("RemoteEvent")
event.Name = "CrewKitStudio"
event.OnServerEvent:Connect(function(player, action)
	if action == "grant" then
		assert(player:GetAttribute("CellFinish") == nil, "unowned equip request changed the finish")
		local purchase = game:GetService("ServerStorage"):WaitForChild("CrewMarketplaceFixture")
		local config = require(storage.Freight.Config)
		player:SetAttribute("Crew", false)
		purchase:Fire(player, config.CrewPassId, false)
		purchase:Fire(player, config.CrewPassId + 1, true)
		task.wait(0.3)
		assert(player:GetAttribute("Crew") == false, "a cancel or wrong pass must never grant Crew")
		purchase:Fire(player, config.CrewPassId, true)
	elseif action == "deliver" then
		local collection = game:GetService("CollectionService")
		local activate = game:GetService("ServerStorage"):WaitForChild("FreightTestAction")
		local world = workspace:FindFirstChild("Blackout Freight • Depot 07")
		local function trigger(part)
			local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
			local point = prompt.Parent.WorldPosition
			player.Character:PivotTo(CFrame.new(point.X, 3, point.Z + 3))
			activate:Invoke(prompt, player)
		end
		assert(player:GetAttribute("CellFinish") == "Crew")
		trigger(collection:GetTagged("FreightPickup")[1])
		assert(player:GetAttribute("Carrying"), "could not pick up the battery")
		local carried = false
		for _, cargo in world:GetChildren() do
			if cargo:FindFirstChild("Crew stripe") then carried = true break end
		end
		assert(carried, "carried battery needs the striped shell")
		trigger(collection:GetTagged("FreightDelivery")[1])
		local ring = world:FindFirstChild("Depot 07 signal ring")
		assert(ring and #ring:GetChildren() == 16, "delivery should emit the crew ring")
		task.wait(0.7)
		assert(not ring.Parent, "spent delivery ring should be removed")
		player:SetAttribute("CrewDeliveryChecked", true)
	elseif action == "done" then
		assert(player:GetAttribute("CellFinish") == "Standard")
		assert(not player.Character:FindFirstChild("Depot 07 patch"))
		test:EndTest("Crew checkout callback PASS")
	end
end)
event.Parent = storage
task.delay(35, function() test:EndTest("Crew kit timed out") end)
]=]
server.Parent = game:GetService("ServerScriptService")
local client = Instance.new("LocalScript")
client.Source = [=[
local player = game:GetService("Players").LocalPlayer
local storage = game:GetService("ReplicatedStorage")
local fixture = storage:WaitForChild("CrewKitStudio")
local freight = storage:WaitForChild("Freight")
local state = freight:WaitForChild("Shift")
local equip = freight:WaitForChild("EquipCellFinish")
local gui = player:WaitForChild("PlayerGui"):WaitForChild("FreightHUD")
local function untilReady(check)
	local deadline = os.clock() + 5
	repeat
		if check() then return end
		task.wait()
	until os.clock() >= deadline
	error("Crew kit test timed out")
end
local preview = gui:WaitForChild("AuroraPreview"):WaitForChild("Crew"):WaitForChild("Battery")
assert(preview["Power Cell"]:FindFirstChild("Crew stripe"))
assert(preview:FindFirstChild("Depot 07 patch"))
assert(#preview["Depot 07 signal ring"]:GetChildren() == 16)
untilReady(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return state:GetAttribute("Phase") == "live" and root and root.Position.Z >= 54
end)
equip:FireServer("Crew")
task.wait(0.6)
assert(player:GetAttribute("CellFinish") == nil)
fixture:FireServer("grant")
untilReady(function() return player:GetAttribute("Crew") end)
equip:FireServer("Crew")
untilReady(function()
	return player:GetAttribute("CellFinish") == "Crew" and player.Character:FindFirstChild("Depot 07 patch")
end)
fixture:FireServer("deliver")
untilReady(function() return player:GetAttribute("CrewDeliveryChecked") end)
equip:FireServer("Standard")
untilReady(function()
	return player:GetAttribute("CellFinish") == "Standard" and not player.Character:FindFirstChild("Depot 07 patch")
end)
fixture:FireServer("done")
]=]
client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
local result = test:ExecuteMultiplayerTestAsync(1, "CrewKitStudio")
print("FREIGHT CREW KIT", result)
assert(result == "Crew checkout callback PASS", tostring(result))
