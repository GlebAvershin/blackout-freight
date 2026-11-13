local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Freight")
local state = shared:WaitForChild("Shift")
local player = Players.LocalPlayer
local highlight, expires
local function clear()
	if highlight then highlight:Destroy(); highlight = nil end
end
shared:WaitForChild("SentinelScan").OnClientEvent:Connect(function(drone, untilTime)
	clear()
	if state:GetAttribute("Phase") ~= "live" then return end
	expires = untilTime
	highlight = Instance.new("Highlight")
	highlight.Name = "Scout scan"
	highlight.Adornee = drone
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(70,230,255)
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0
	highlight.Parent = player.PlayerGui
	local thisScan = highlight
	task.delay(math.max(0, expires-workspace:GetServerTimeNow()), function()
		if highlight == thisScan then clear() end
	end)
end)
state:GetAttributeChangedSignal("Phase"):Connect(function()
	if state:GetAttribute("Phase") ~= "live" then clear() end
end)
player.CharacterRemoving:Connect(clear)
