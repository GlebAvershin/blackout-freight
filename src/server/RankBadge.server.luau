local Players = game:GetService("Players")
local Track = require(game:GetService("ReplicatedStorage"):WaitForChild("Freight"):WaitForChild("RankTrack"))
local Challenges = require(game:GetService("ReplicatedStorage").Freight.CrewChallenges)
local masteryColors = {Color3.fromRGB(210, 149, 101), Color3.fromRGB(90, 221, 233), Color3.fromRGB(255, 205, 88)}
local roleGlyphs = {Carrier = "C", Lure = "L", Scout = "S", Technician = "T"}
local connections = {}
local function draw(player)
	local character = player.Character
	if not character then return end
	local old = character:FindFirstChild("Crew rank badge")
	if old then old:Destroy() end
	local oldChallenge = character:FindFirstChild("Crew challenge badge")
	if oldChallenge then oldChallenge:Destroy() end
	local reward = Track.progress(player:GetAttribute("RankXP"))
	local role = player:GetAttribute("CrewRole")
	local glyph = role and roleGlyphs[role]
	local mastery = glyph and Challenges.tier(player:GetAttribute("Mastery" .. role) or 0) or 0
	local daily = player:GetAttribute("DailyTitle")
	local arm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
	if not arm then return end
	local function attach(name, offset, text, color)
		local badge = Instance.new("Part")
		badge.Name, badge.Size = name, Vector3.new(0.06,0.56,0.56)
		badge.CanCollide, badge.CanTouch, badge.CanQuery, badge.Massless = false, false, false, true
		badge.Material, badge.Color = Enum.Material.Fabric, Color3.fromRGB(22,30,42)
		badge.CFrame = arm.CFrame * CFrame.new(-arm.Size.X/2-0.035,offset,0)
		local face = Instance.new("SurfaceGui")
		face.Face, face.CanvasSize = Enum.NormalId.Left, Vector2.new(96,96)
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1,1), 1
		label.Text, label.TextColor3 = text, color
		label.Font, label.TextScaled = Enum.Font.GothamBold, true
		label.Parent = face; face.Parent = badge
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = arm, badge
		weld.Parent = badge
		badge.Parent = character
	end
	if reward then attach("Crew rank badge", 0, tostring(reward.rank), Color3.fromRGB(table.unpack(reward.color))) end
	if mastery > 0 then
		attach("Crew challenge badge", reward and -0.57 or 0, glyph .. mastery, masteryColors[mastery])
	elseif daily then
		attach("Crew challenge badge", reward and -0.57 or 0, "D", masteryColors[3])
	end
end
local function join(player)
	if connections[player] then return end
	local function characterAdded(character)
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid",10)
			if not humanoid then return end
			character:WaitForChild(humanoid.RigType == Enum.HumanoidRigType.R15 and "LeftUpperArm" or "Left Arm",10)
			if player.Character == character and connections[player] then draw(player) end
		end)
	end
	connections[player] = {
		player:GetAttributeChangedSignal("RankXP"):Connect(function() draw(player) end),
		player.CharacterAdded:Connect(characterAdded),
	}
	for _, attribute in {"CrewRole", "DailyTitle", "MasteryCarrier", "MasteryLure", "MasteryScout", "MasteryTechnician"} do
		table.insert(connections[player], player:GetAttributeChangedSignal(attribute):Connect(function() draw(player) end))
	end
	if player.Character then characterAdded(player.Character) end
end
Players.PlayerAdded:Connect(join)
Players.PlayerRemoving:Connect(function(player)
	for _, connection in connections[player] or {} do connection:Disconnect() end
	connections[player] = nil
end)
for _, player in Players:GetPlayers() do join(player) end
