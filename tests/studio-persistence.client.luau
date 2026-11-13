assert(game:GetService("RunService"):IsStudio())
local storage = game:GetService("ReplicatedStorage")
local player = game:GetService("Players").LocalPlayer
local control = storage:WaitForChild("PersistenceTestControl")
local preparation = storage:WaitForChild("Freight"):WaitForChild("Preparation")
control.OnClientEvent:Connect(function(command)
	if command == "select" then
		preparation:FireServer("role", "Technician")
	elseif command == "dash" then
		preparation:FireServer("ability")
	else
		control:FireServer("observed", player:GetAttribute("EndingBroadcast"),
			player:GetAttribute("Scrap"), player:GetAttribute("NextCrewRole"), player:GetAttribute("CrewRole"),
			player:GetAttribute("SeasonDeliveries"),player:GetAttribute("SeasonTier"))
	end
end)
control:FireServer("ready")
