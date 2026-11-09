local Lighting = game:GetService("Lighting")

local Depot = {}
Depot.Cyan = Color3.fromRGB(46, 230, 233)
Depot.Aurora = Color3.fromRGB(215, 127, 255)
Depot.Amber = Color3.fromRGB(255, 191, 74)
Depot.Red = Color3.fromRGB(255, 76, 72)
Depot.Shelter = Color3.fromRGB(255, 176, 111)
local ink = Color3.fromRGB(16, 25, 38)
local steel = Color3.fromRGB(40, 57, 76)
local neon = Enum.Material.Neon

function Depot.part(parent, name, size, cf, color, material, solid)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanTouch = false
	p.CastShadow = solid == true
	p.Parent = parent
	return p
end

function Depot.battery(parent, cf, color)
	local model = Instance.new("Model")
	model.Name = "Power Cell"
	local body = Depot.part(model, "Shell", Vector3.new(1.85, 1.55, 1.05), cf, ink)
	for i = -1, 1 do
		Depot.part(model, "Charge", Vector3.new(0.33, 0.91, 1.11), cf * CFrame.new(i * 0.48, 0, 0), color, neon)
	end
	Depot.part(model, "Terminal", Vector3.new(0.85, 0.19, 0.69), cf * CFrame.new(0, 0.85, 0), steel)
	model.PrimaryPart = body
	model.Parent = parent
	return model
end

local function sign(part, title, color, face)
	local board = Instance.new("SurfaceGui")
	board.Face = face or Enum.NormalId.Front
	board.LightInfluence = 0
	board.CanvasSize = Vector2.new(840, 130)
	board.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = title
	label.TextColor3 = color
	label.Parent = board
end

function Depot.operation(world, route, divider, gapWidth)
	local layout = Instance.new("Model")
	layout.Name = "Service diversion"
	local color = route.gap < 0 and Color3.fromRGB(102, 255, 191) or Color3.fromRGB(121, 168, 255)
	for _, span in {{-67, route.gap - gapWidth / 2}, {route.gap + gapWidth / 2, 67}} do
		local left, right = table.unpack(span)
		local gate = Depot.part(layout, "Closed freight shutters", Vector3.new(right - left, 11, 1.6),
			CFrame.new((left + right) / 2, 5.5, divider), steel, Enum.Material.Metal, true)
		for x = left + 3, right - 2, 7 do
			Depot.part(layout, "Shutter rib", Vector3.new(0.32, 10.8, 1.68), CFrame.new(x, 5.5, divider), ink)
		end
		for _, z in {divider - 0.85, divider + 0.85} do
			Depot.part(layout, "Closure stripe", Vector3.new(gate.Size.X, 0.18, 0.11), CFrame.new(gate.Position.X, 2, z), Depot.Amber, Enum.Material.Neon)
		end
	end
	local header = Depot.part(layout, "Service passage", Vector3.new(gapWidth - 0.4, 1.3, 1.7),
		CFrame.new(route.gap, 9.5, divider), ink, Enum.Material.Metal)
	local title = route.gap < 0 and "W   /   BYPASS" or "E   /   SERVICE"
	sign(header, title, color)
	sign(header, title, color, Enum.NormalId.Back)
	for _, x in {route.gap - gapWidth / 2 + 0.4, route.gap + gapWidth / 2 - 0.4} do
		Depot.part(layout, "Passage light", Vector3.new(0.24, 9, 0.6), CFrame.new(x, 4.5, divider), color, Enum.Material.Neon)
	end
	for z = divider - 11, divider + 21, 2.2 do
		Depot.part(layout, "Service lane light", Vector3.new(3.2, 0.05, 0.35), CFrame.new(route.gap, 0.065, z), color, Enum.Material.Neon)
	end
	local direction = math.sign(route.gap)
	for x = 4, math.abs(route.gap) - 2, 2.6 do
		Depot.part(layout, "Approach light", Vector3.new(0.35, 0.05, 2.2), CFrame.new(x * direction, 0.065, divider + 22.6), color, Enum.Material.Neon)
	end
	layout.Parent = world
	return layout, header
end

local function light(part, color, range, brightness)
	local lamp = Instance.new("PointLight")
	lamp.Color = color
	lamp.Range = range
	lamp.Brightness = brightness
	lamp.Parent = part
	return lamp
end

function Depot.build()
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = 0.22
	Lighting.Ambient = Color3.fromRGB(100, 112, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(122, 137, 155)
	Lighting.FogColor = ink
	Lighting.FogStart = 90
	Lighting.FogEnd = 300
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Contrast = 0.02
	grade.Saturation = -0.06
	grade.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.16, 18, 0.94
	bloom.Parent = Lighting

	local world = Instance.new("Model")
	world.Name = "Blackout Freight • Depot 07"
	local function box(name, x, y, z, w, h, d, color, material, solid)
		return Depot.part(world, name, Vector3.new(w, h, d), CFrame.new(x, y, z), color, material, solid)
	end
	box("Warehouse foundation", 0, -1, 0, 140, 2, 152, Color3.fromRGB(37, 47, 61), Enum.Material.Concrete, true)
	for _, x in {-1.6, 1.6} do
		box("Guide rail", x, 0.04, -7, 0.13, 0.08, 119, Color3.fromRGB(108, 130, 147), Enum.Material.Metal)
	end
	for z = -66, 50, 4 do
		box("Rail tie", 0, 0.035, z, 4.1, 0.07, 0.18, steel, Enum.Material.Metal)
	end
	for z = -66, 66, 12 do
		box("Floor joint", 0, 0.025, z, 136, 0.05, 0.08, steel)
	end
	for x = -68, 68, 136 do
		box("Side wall", x, 7, 0, 2, 14, 152, steel, nil, true)
		for _, y in {4, 6, 8} do
			local pipe = Depot.part(world, "Service pipe", Vector3.new(131, 0.45, 0.45),
				CFrame.new(x * 0.97, y, -4) * CFrame.Angles(0, math.pi / 2, 0), steel, Enum.Material.Metal)
			pipe.Shape = Enum.PartType.Cylinder
		end
		for z = -60, 60, 20 do
			box("Column", x * 0.98, 6, z, 3, 12, 2.5, ink, nil, true)
			box("Wall marker", x * 0.95, 5, z, 0.18, 2.3, 0.15, Depot.Cyan, neon)
		end
	end
	for z = -74, 74, 148 do
		box("Bulkhead", 0, 7, z, 140, 14, 2, steel, nil, true)
	end
	local paints = {Color3.fromRGB(44, 70, 81), Color3.fromRGB(50, 67, 90), Color3.fromRGB(64, 72, 85)}
	for row, x in {-47, -17, 17, 47} do
		for sector, z in {-48, -15, 19, 47} do
			box("Cargo container", x, 2, z, 12, 4, 8, paints[(row + sector) % #paints + 1], Enum.Material.Metal, true)
			box("Container lid", x, 4.06, z, 12.2, 0.15, 8.2, ink)
			for n = -4, 4, 2 do
				box("Cargo rib", x + n, 2, z + 4.05, 0.14, 3.5, 0.15, ink)
			end
			box("Cargo reflector", x, 1.23, z + 4.16, 4, 0.15, 0.09, Depot.Amber)
			local plate = Depot.part(world, "Freight ID", Vector3.new(4.8, 0.95, 0.12),
				CFrame.new(x, 2.4, z + 4.21) * CFrame.Angles(0, math.pi, 0), ink)
			sign(plate, string.format("%s–%02d", string.char(64 + row), sector), Color3.fromRGB(152, 190, 201))
		end
	end
	for _, x in {-32, 0, 32} do
		for z = -64, 38, 6 do
			box("Lane dash", x, 0.05, z, 0.16, 0.05, 2.7, Color3.fromRGB(113, 133, 148))
		end
	end
	local sectors = {
		{z = 36, title = "01 / RECEIVING", color = Color3.fromRGB(116, 199, 214)},
		{z = 5, title = "02 / SWITCHYARD", color = Color3.fromRGB(234, 163, 102)},
		{z = -27, title = "03 / COLD STORAGE", color = Color3.fromRGB(147, 173, 237)},
		{z = -55, title = "04 / RELAY CORE", color = Color3.fromRGB(168, 207, 182)},
	}
	for _, sector in sectors do
		local z, accent = sector.z, sector.color
		box("Service gantry", 0, 12, z, 136, 0.9, 1.4, steel, Enum.Material.Metal)
		for _, x in {-53, 53} do
			box("Overhead service duct", x, 12.2, z + 11, 4.1, 1.2, 19, ink, Enum.Material.Metal)
			box("Gantry edge", x, 11.5, z, 16, 0.1, 0.24, accent, neon)
		end
		local board = box("Sector wayfinding", 0, 10.6, z, 17, 1.8, 0.36, ink, Enum.Material.Metal)
		sign(board, sector.title, accent, Enum.NormalId.Back)
		sign(board, sector.title, accent)
		for _, x in {-42, 0, 42} do
			local fixture = box("Aisle light", x, 11.45, z, 4.5, 0.18, 0.5, accent, neon)
			light(fixture, accent, 24, 0.85)
		end
	end

	for i = -14, 14, 2 do
		box("Safe zone stripe", i, 0.055, 54, 1.07, 0.09, 2.4, Depot.Amber, neon)
	end
	for _, x in {-15, 15} do
		box("Gate pier", x, 4, 54, 1.5, 8, 1.5, steel, Enum.Material.Metal, true)
		local strip = box("Gate light", x * 0.944, 4, 54, 0.2, 7.6, 1.3, Depot.Amber, neon)
		light(strip, Depot.Amber, 23, 0.95)
	end
	box("Airlock header", 0, 8.3, 54, 31.5, 0.78, 1.5, steel, Enum.Material.Metal)
	local archSign = box("Airlock direction sign", 0, 8.3, 53.2, 13, 0.72, 0.1, ink)
	sign(archSign, "07  /  SAFE ZONE", Depot.Amber)
	for _, x in {-5.4, 5.4} do
		for z = 55, 63, 2 do
			box("Return lane light", x, 0.061, z, 0.26, 0.09, 0.84, Depot.Amber, neon)
		end
	end
	sign(box("Airlock sign", 0, 5.3, 72.8, 13, 1.4, 0.6, ink), "07  /  AIRLOCK", Depot.Amber)
	sign(box("Back wall sign", 0, 8.4, 72.8, 37, 4, 0.6, ink), "BLACKOUT FREIGHT", Depot.Cyan)
	local terminal = box("Delivery console", 0, 1.65, 65, 8.4, 3.3, 2.6, steel, Enum.Material.Metal, true)
	box("Console rim", 0, 3.38, 65, 8.5, 0.24, 2.8, ink, Enum.Material.Metal)
	local chargeLights = {}
	for i = -2, 2 do
		table.insert(chargeLights, box("Charge status", i * 1.27, 3.53, 64.7, 1.08, 0.13, 1.5, steel))
	end
	sign(terminal, "DELIVER CELLS", Depot.Amber)
	local outputs, consoles = {}, {}
	for _, route in {
		{key = "broadcast", x = -13, color = Depot.Cyan, title = "01   BROADCAST"},
		{key = "shelter", x = 13, color = Depot.Shelter, title = "02   SHELTER"},
	} do
		local console = box(route.title, route.x, 1.35, 67, 5.5, 2.7, 2.4, steel, Enum.Material.Metal, true)
		consoles[route.key] = console
		sign(console, route.title, route.color)
		local strip = box("Route status", route.x, 2.76, 67, 4.5, 0.12, 1.4, route.color)
		outputs[route.key] = {strip = strip, lamp = light(strip, route.color, 19, 0)}
		sign(box("Power routing board", route.x, 5.4, 72.7, 8.5, 0.9, 0.48, ink), route.title, route.color)
	end
	local mast = box("Relay mast", 0, 14, -66, 2.5, 28, 2.5, steel, Enum.Material.Metal, true)
	for _, x in {-4.2, 4.2} do
		box("Relay cooling tower", x, 7.5, -67, 3, 15, 3, steel, Enum.Material.Metal)
		for y = 2.8, 12, 2.3 do
			box("Cooling fins", x, y, -65.44, 2.7, 0.16, 0.18, Depot.Cyan)
		end
	end
	for _, y in {15, 20, 25} do
		box("Antenna crossbar", 0, y, -66, 14 - (y - 15) * 0.45, 0.42, 1.2, steel, Enum.Material.Metal)
	end
	local beacon = box("Relay beacon", 0, 28.6, -66, 1.2, 1.25, 1.2, Depot.Cyan)
	outputs.broadcast.beacon = beacon
	outputs.broadcast.relay = light(beacon, Depot.Cyan, 36, 0)
	sign(box("Relay plate", 0, 6, mast.Position.Z + 1.4, 8, 1.1, 0.16, ink), "RELAY 07", Depot.Cyan)
	local shelter = box("Shelter light", 13, 7, 70.5, 7.5, 0.22, 0.7, Depot.Shelter)
	outputs.shelter.beacon = shelter
	outputs.shelter.relay = light(shelter, Depot.Shelter, 31, 0)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Airlock Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.Size = Vector3.new(18, 0.5, 5)
	spawn.Position = Vector3.new(0, 0.25, 59)
	spawn.Parent = world

	local positions = {
		Vector3.new(-9, 0, 42), Vector3.new(9, 0, 34),
		Vector3.new(-32, 0, 22), Vector3.new(32, 0, 19), Vector3.new(-57, 0, 35),
		Vector3.new(57, 0, 42), Vector3.new(0, 0, 5), Vector3.new(-33, 0, -7),
		Vector3.new(34, 0, -20), Vector3.new(-55, 0, -30),
		Vector3.new(56, 0, -53), Vector3.new(4, 0, -56),
	}
	for _, pos in positions do
		box("Cell socket", pos.X, 0.65, pos.Z, 3.1, 1.3, 2.8, steel, Enum.Material.Metal, true)
		box("Socket ring", pos.X, 1.33, pos.Z, 2.9, 0.1, 2.5, Color3.fromRGB(59, 120, 138))
	end

	local drone = Instance.new("Model")
	drone.Name = "Sentinel"
	local core = Depot.part(drone, "Body", Vector3.new(4.3, 2, 3.2), CFrame.new(), ink, Enum.Material.Metal)
	Depot.part(drone, "Eye", Vector3.new(2.75, 0.38, 0.23), CFrame.new(0, 0.2, -1.67), Depot.Red, neon)
	for _, x in {-2.75, 2.75} do
		Depot.part(drone, "Thruster", Vector3.new(1.1, 0.8, 2.6), CFrame.new(x, -0.45, 0), steel)
		Depot.part(drone, "Thruster flare", Vector3.new(0.78, 0.16, 1.75), CFrame.new(x, -0.91, 0), Depot.Red, neon)
		Depot.part(drone, "Armored wing", Vector3.new(1.6, 0.34, 2.4), CFrame.new(x * 1.1, 0.42, 0.22), steel, Enum.Material.Metal)
	end
	light(core, Depot.Red, 19, 1.25)
	local scan = Instance.new("SpotLight")
	scan.Name = "Scanner"
	scan.Color = Depot.Amber
	scan.Face = Enum.NormalId.Bottom
	scan.Angle = 72
	scan.Range = 15
	scan.Brightness = 1.5
	scan.Parent = core
	drone.PrimaryPart = core
	drone:PivotTo(CFrame.new(0, 5, -42))
	drone.Parent = world
	world.Parent = workspace
	return world, terminal, positions, drone, consoles, function(count, routing, ending)
		for i, lamp in chargeLights do
			lamp.Color = i <= count and Depot.Cyan or steel
			lamp.Material = i <= count and neon or Enum.Material.Metal
		end
		for route, output in outputs do
			local selected = route == ending
			output.strip.Material = (routing or selected) and neon or Enum.Material.SmoothPlastic
			output.lamp.Brightness = selected and 1.45 or (routing and 0.45 or 0)
			output.beacon.Material = selected and neon or Enum.Material.SmoothPlastic
			output.relay.Brightness = selected and 2.1 or 0
		end
	end
end

return Depot
