local PowerCell = {
	Cyan = Color3.fromRGB(46, 230, 233),
	Amber = Color3.fromRGB(255, 177, 71),
	Aurora = Color3.fromRGB(215, 127, 255),
	Dispatch = Color3.fromRGB(174, 238, 101),
	Crew = Color3.fromRGB(238, 245, 255),
}

PowerCell.Finishes = {Standard = PowerCell.Cyan, Signal = PowerCell.Amber, Aurora = PowerCell.Aurora, Crew = PowerCell.Crew}

function PowerCell.canEquip(player, finish)
	if finish == "Standard" then
		return true
	elseif finish == "Signal" then
		return player:GetAttribute("EndingBroadcast") == true or player:GetAttribute("EndingShelter") == true
	elseif finish == "Aurora" or finish == "Crew" then
		return player:GetAttribute(finish) == true
	end
	return false
end

function PowerCell.equipped(player)
	local finish = player:GetAttribute("CellFinish")
	if PowerCell.canEquip(player, finish) then
		return finish
	end
	return PowerCell.canEquip(player, "Aurora") and "Aurora" or "Standard"
end

local function piece(model, name, size, cf, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

function PowerCell.build(parent, cf, color, finish)
	local model = Instance.new("Model")
	model.Name = "Power Cell"
	model.PrimaryPart = piece(model, "Shell", Vector3.new(1.85, 1.55, 1.05), cf, Color3.fromRGB(16, 25, 38), Enum.Material.SmoothPlastic)
	for i = -1, 1 do
		piece(model, "Charge", Vector3.new(0.33, 0.91, 1.11), cf * CFrame.new(i * 0.48, 0, 0), color, Enum.Material.Neon)
	end
	if finish == "Crew" then
		model.PrimaryPart.Color = Color3.fromRGB(12, 17, 25)
		model.PrimaryPart.Material = Enum.Material.Metal
		for _, side in {-1, 1} do
			piece(model, "Crew stripe", Vector3.new(1.66, 0.14, 0.055),
				cf * CFrame.new(0, -0.58, side * 0.54), PowerCell.Crew, Enum.Material.SmoothPlastic)
		end
	end
	piece(model, "Terminal", Vector3.new(0.85, 0.19, 0.69), cf * CFrame.new(0, 0.85, 0), Color3.fromRGB(40, 57, 76), Enum.Material.SmoothPlastic)
	model.Parent = parent
	return model
end

function PowerCell.crewPatch(parent, cf)
	local patch = piece(parent, "Depot 07 patch", Vector3.new(0.54, 0.44, 0.045), cf,
		Color3.fromRGB(25, 32, 45), Enum.Material.Fabric)
	patch.CanQuery = false
	local face = Instance.new("SurfaceGui")
	face.CanvasSize = Vector2.new(108, 88)
	face.Parent = patch
	local number = Instance.new("TextLabel")
	number.Size = UDim2.fromScale(1, 1)
	number.BackgroundTransparency = 1
	number.TextColor3 = PowerCell.Crew
	number.Text = "07"
	number.TextScaled = true
	number.Font = Enum.Font.GothamBold
	number.Parent = face
	return patch
end

function PowerCell.crewRing(parent, cf, radius)
	local ring = Instance.new("Model")
	ring.Name = "Depot 07 signal ring"
	local segments = 16
	for i = 1, segments do
		local angle = 2 * math.pi * i / segments
		local segment = piece(ring, "Signal", Vector3.new(2 * radius * math.tan(math.pi / segments), 0.06, 0.09),
			cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, radius), PowerCell.Crew, Enum.Material.Neon)
		segment.CanQuery = false
		segment.Transparency = 0.15
	end
	ring.Parent = parent
	return ring
end

return PowerCell
