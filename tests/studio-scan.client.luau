assert(game:GetService("RunService"):IsStudio())
local player = game:GetService("Players").LocalPlayer
local storage = game:GetService("ReplicatedStorage")
local result = storage:WaitForChild("ScanQAResult")
local gui = player:WaitForChild("PlayerGui")
local reported = false
while true do
	local scan = gui:FindFirstChild("Scout scan")
	if scan and not reported then
		assert(scan.Adornee and scan.DepthMode == Enum.HighlightDepthMode.AlwaysOnTop)
		result:FireServer("visible")
		reported = true
	elseif reported and not scan then
		result:FireServer("cleared")
		break
	end
	task.wait(0.05)
end
