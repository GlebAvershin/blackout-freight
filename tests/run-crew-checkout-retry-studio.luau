-- Run against a local copy of the release place via Studio RunScript.
-- Model a prompt request that returns without opening a Roblox dialog.
local hud = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Hud", true)
assert(hud and hud:IsA("LocalScript"))
local patched, count = hud.Source:gsub(
	"pcall%(MarketplaceService%.PromptGamePassPurchase, MarketplaceService, player, offer%.id%)",
	"true"
)
assert(count == 1, "checkout fixture must stub exactly one marketplace request")
hud.Source = patched
local test = game:GetService("StudioTestService")
local client = Instance.new("LocalScript")
client.Name = "CrewCheckoutQA"
client.Source = [=[
local player = game:GetService("Players").LocalPlayer
local storage = game:GetService("ReplicatedStorage")
local freight = storage:WaitForChild("Freight")
local state = freight:WaitForChild("Shift")
local gui = player:WaitForChild("PlayerGui"):WaitForChild("FreightHUD")
local offer, preview = gui:WaitForChild("AuroraLens"), gui:WaitForChild("AuroraPreview")
local event = storage:WaitForChild("CrewCheckoutQA")
local input = assert(game:GetService("UserInputService"):CreateVirtualInput())
local function waitFor(condition, label, seconds)
	local deadline = os.clock() + (seconds or 10)
	repeat
		if condition() then return end
		task.wait(0.1)
	until os.clock() > deadline
	error(label)
end
local function tap(button)
	local point = button.AbsolutePosition + button.AbsoluteSize / 2 + game:GetService("GuiService"):GetGuiInset()
	input:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
	task.wait()
	input:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
end
event:FireServer("prepare")
waitFor(function() return player:GetAttribute("CheckoutReady") end, "fixture not ready")
state:SetAttribute("Phase", "won")
waitFor(function() return offer.Visible end, "locker not visible")
tap(offer)
waitFor(function() return preview.Visible end, "locker did not open")
tap(preview.Crew)
local function canBuy()
	return preview.Buy.Interactable and preview.Buy.Text:find("R$", 1, true)
end
waitFor(canBuy, "buy button not ready")
tap(preview.Buy)
waitFor(function() return not preview.Buy.Interactable end, "buy button should wait for the prompt")
task.wait(0.5)
assert(not preview.Buy.Interactable, "buy button should block repeated clicks while opening")
waitFor(canBuy, "buy button did not recover without a callback", 18)
tap(preview.Buy)
waitFor(function() return not preview.Buy.Interactable end, "retry did not call the prompt")
assert(player:GetAttribute("Crew") == false and player:GetAttribute("CellFinish") ~= "Crew",
	"missing completion signal must not grant or equip the pass")
event:FireServer("done")
]=]
client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts
local server = Instance.new("Script")
server.Source = [=[
local storage = game:GetService("ReplicatedStorage")
local test = game:GetService("StudioTestService")
local event = Instance.new("RemoteEvent")
event.Name = "CrewCheckoutQA"
event.OnServerEvent:Connect(function(player, step)
	if step == "prepare" then
		player:SetAttribute("EndingShelter", true)
		player:SetAttribute("Crew", false)
		player:SetAttribute("CheckoutReady", true)
	elseif step == "done" then
		assert(player:GetAttribute("Crew") == false and player:GetAttribute("CellFinish") ~= "Crew")
		test:EndTest("Crew checkout retry PASS")
	end
end)
event.Parent = storage
task.delay(45, function() test:EndTest("Crew checkout TIMEOUT") end)
]=]
server.Parent = game:GetService("ServerScriptService")
local result = test:ExecuteMultiplayerTestAsync(1, "CrewCheckout")
print("FREIGHT CREW CHECKOUT", result)
assert(result == "Crew checkout retry PASS")
