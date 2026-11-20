local Architecture = {}

local enamel = Color3.fromRGB(26, 42, 45)
local ivory = Color3.fromRGB(240, 239, 215)
local ochre = Color3.fromRGB(191, 129, 56)
local steel = Color3.fromRGB(59, 77, 80)

function Architecture.sectorSign(board, number, title, accent)
	for _, face in {Enum.NormalId.Front, Enum.NormalId.Back} do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SectorPlate"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(940, 125)
		gui.LightInfluence = 0.15
		gui.MaxDistance = 160
		gui.Parent = board

		local function band(x, y, width, height, color)
			local frame = Instance.new("Frame")
			frame.BackgroundColor3 = color
			frame.BorderSizePixel = 0
			frame.Position = UDim2.fromOffset(x, y)
			frame.Size = UDim2.fromOffset(width, height)
			frame.Parent = gui
			return frame
		end
		local function text(x, width, value, font, color, alignment)
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromOffset(x, 0)
			label.Size = UDim2.fromOffset(width, 125)
			label.Text = value
			label.Font = font
			label.TextSize = 73
			label.TextColor3 = color
			label.TextXAlignment = alignment
			label.Parent = gui
		end
		band(0, 0, 940, 125, enamel)
		band(4, 4, 162, 117, accent)
		text(4, 162, number, Enum.Font.RobotoMono, enamel, Enum.TextXAlignment.Center)
		text(194, 664, title, Enum.Font.GothamBold, ivory, Enum.TextXAlignment.Left)
		for _, x in {863, 888} do
			band(x, 35, 13, 55, accent).Rotation = 19
		end
	end
end

-- The hoist spans the outer stacks. All of its geometry is outside the interaction
-- and visibility queries used by carry prompts, pings and Sentinel.
function Architecture.transferCrane(world, makePart)
	local model = Instance.new("Model")
	model.Name = "Transfer crane"
	local function member(name, x, y, z, w, h, d, color, rotation)
		local part = makePart(model, name, Vector3.new(w, h, d),
			CFrame.new(x, y, z) * CFrame.Angles(0, 0, rotation or 0), color, Enum.Material.Metal)
		part.CanQuery = false
		return part
	end
	local z = -41
	for _, x in {-61, 61} do
		member("Runway post", x, 11, z, 1.8, 22, 2.1, steel)
		member("Gusset", x * 0.958, 18.2, z, 0.72, 8, 1.2, ochre, x < 0 and -0.7 or 0.7)
	end
	member("Bottom flange", 0, 20, z, 124, 0.65, 2.6, ochre)
	member("Upper flange", 0, 24.6, z, 124, 0.55, 2.4, ochre)
	local span = 10
	for index = 0, 11 do
		local angle = math.atan(4.6 / span) * (index % 2 == 0 and 1 or -1)
		member("Lattice diagonal", -55 + span * index, 22.3, z, math.sqrt(span^2 + 4.6^2), 0.55, 0.82, steel, angle)
	end
	member("Trolley", -23, 21.3, z, 9.8, 3.1, 4.1, ochre)
	member("Cable drum", -23, 19.3, z, 6, 1.2, 2.3, enamel)
	for _, x in {-25, -21} do
		member("Fall rope", x, 15.2, z, 0.17, 7.4, 0.17, steel)
	end
	member("Spreader", -23, 11.4, z, 7, 0.64, 1.7, ochre)
	model.Parent = world
end

-- Sawtooth clerestories leave the central rail open to the night sky. Their
-- repeating profile gives each bay a readable rhythm when looking downrange.
function Architecture.clerestories(world, makePart)
	local roof = Instance.new("Model")
	roof.Name = "Depot clerestories"
	local zinc = Color3.fromRGB(43, 58, 63)
	local glazing = Color3.fromRGB(95, 133, 139)
	local function piece(name, size, pose, color, material)
		local p = makePart(roof, name, size, pose, color, material or Enum.Material.Metal)
		p.CanQuery = false
		return p
	end
	for _, side in {-1, 1} do
		for _, z in {-54, -24, 6, 36} do
			piece("Sawtooth roof", Vector3.new(21.4, .46, 30), CFrame.new(side * 56.6, 16.1, z)
				* CFrame.Angles(0, 0, -side * .17), zinc)
			piece("Clerestory sill", Vector3.new(.48, .4, 29.9), CFrame.new(side * 46.2, 14.8, z), steel)
			local pane = piece("Wired glass", Vector3.new(.18, 3.12, 29.7),
				CFrame.new(side * 46.2, 16.5, z), glazing, Enum.Material.Glass)
			pane.Transparency = .26
			for _, offset in {-14.8, -5, 5} do
				piece("Window mullion", Vector3.new(.38, 3.4, .26),
					CFrame.new(side * 46.2, 16.45, z + offset), enamel)
			end
			piece("Rafter", Vector3.new(21.4, .34, .48), CFrame.new(side * 56.6, 15.65, z-14.6)
				* CFrame.Angles(0, 0, -side * .17), steel)
		end
	end
	roof.Parent = world
end

function Architecture.airlockCanopy(world, makePart)
	local function part(name, size, cf, color, material)
		local p = makePart(world, name, size, cf, color, material or Enum.Material.Metal)
		p.CanQuery = false
		return p
	end
	part("Transfer station soffit", Vector3.new(74, .65, 12), CFrame.new(2, 15.6, 68.2), enamel)
	part("Canopy fascia", Vector3.new(74.4, .82, .52), CFrame.new(2, 15.3, 62.15), steel)
	for _, x in {-27, -9, 9, 27} do
		part("Canopy rib", Vector3.new(.35, .72, 12), CFrame.new(x, 15.03, 68.2), steel)
		local lamp = part("Amber downlight", Vector3.new(6.1, .15, .61),
			CFrame.new(x+3.8, 15.17, 66.7), Color3.fromRGB(255, 220, 166), Enum.Material.Neon)
		local light = Instance.new("SurfaceLight")
		light.Face, light.Angle, light.Range = Enum.NormalId.Bottom, 102, 20
		light.Brightness, light.Color = .72, Color3.fromRGB(255, 225, 186)
		light.Parent = lamp
	end
end

return Architecture
