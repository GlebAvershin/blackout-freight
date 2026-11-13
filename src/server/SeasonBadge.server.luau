local Players = game:GetService("Players")
local connections = {}
local function draw(player)
	local character=player.Character
	if not character then return end
	local old=character:FindFirstChild("Echo event badge")
	if old then old:Destroy() end
	local premium=character:FindFirstChild("Echo premium badge")
	if premium then premium:Destroy() end
	local arm=character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
	local tier=player:GetAttribute("SeasonTier") or 0
	local club=player:GetAttribute("DepotClub") == true
	local premiumTier=if player:GetAttribute("ShiftPass") == true then tier else 0
	if not arm or (tier<3 and premiumTier==0 and not club) then return end
	local badge=Instance.new("Part")
	badge.Name,badge.Size="Echo event badge",Vector3.new(0.06,0.56,0.56)
	badge.CanCollide,badge.CanTouch,badge.CanQuery,badge.Massless=false,false,false,true
	badge.Material,badge.Color=Enum.Material.Fabric,Color3.fromRGB(16,31,42)
	badge.CFrame=arm.CFrame*CFrame.new(arm.Size.X/2+0.035,0,0)
	local face=Instance.new("SurfaceGui")
	face.Face,face.CanvasSize=Enum.NormalId.Right,Vector2.new(96,96)
	local text=Instance.new("TextLabel")
	text.Size,text.BackgroundTransparency=UDim2.fromScale(1,1),1
	text.Text,text.TextColor3="ECHO",Color3.fromRGB(72,235,211)
	text.Font,text.TextScaled=Enum.Font.GothamBold,true
	text.Parent=face; face.Parent=badge
	local weld=Instance.new("WeldConstraint")
	weld.Part0,weld.Part1=arm,badge
	weld.Parent=badge
	if tier>=3 then badge.Parent=character end
	if premiumTier>0 or club then
		local accent=badge:Clone()
		accent.Name="Echo premium badge"
		accent.Size=Vector3.new(0.06,0.24,0.56)
		accent.WeldConstraint.Enabled=false
		accent.CFrame=badge.CFrame*CFrame.new(0,-0.43,0)
		accent.WeldConstraint.Part1=accent
		local month=tonumber(os.date("!%m")) or 1
		accent.SurfaceGui.TextLabel.Text=if club then "CLUB" else "SHIFT " .. premiumTier
		accent.SurfaceGui.TextLabel.TextColor3=if club and month%2==0 then Color3.fromRGB(186,133,255) elseif not club and premiumTier==1 then Color3.fromRGB(205,216,228)
			elseif not club and premiumTier==3 then Color3.fromRGB(129,240,220) else Color3.fromRGB(255,197,87)
		accent.Parent=character
		accent.WeldConstraint.Enabled=true
	end
	if tier<3 then badge:Destroy() end
end
local function join(player)
	if connections[player] then return end
	local function characterAdded(character)
		task.spawn(function()
			local humanoid=character:WaitForChild("Humanoid",10)
			if not humanoid then return end
			character:WaitForChild(humanoid.RigType==Enum.HumanoidRigType.R15 and "RightUpperArm" or "Right Arm",10)
			if player.Character==character and connections[player] then draw(player) end
		end)
	end
	connections[player]={player:GetAttributeChangedSignal("SeasonTier"):Connect(function() draw(player) end),player.CharacterAdded:Connect(characterAdded),
		player:GetAttributeChangedSignal("ShiftPass"):Connect(function() draw(player) end),
		player:GetAttributeChangedSignal("DepotClub"):Connect(function() draw(player) end)}
	if player.Character then characterAdded(player.Character) end
end
Players.PlayerAdded:Connect(join)
Players.PlayerRemoving:Connect(function(player)
	for _,connection in connections[player] or {} do connection:Disconnect() end
	connections[player]=nil
end)
for _,player in Players:GetPlayers() do join(player) end
