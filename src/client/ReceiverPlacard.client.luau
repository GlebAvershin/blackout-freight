--!strict
local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")
local world = workspace:WaitForChild("Blackout Freight • Depot 07")
local board = Instance.new("Part")
board.Name = "Depot 07 battery handling plate"
board.Anchored = true
board.CanCollide, board.CanQuery, board.CanTouch = false, false, false
board.CastShadow = false
board.Size = Vector3.new(12, 9.3, .18)
board.Position = Vector3.new(26, 6.7, 72.7)
board.Material = Enum.Material.Metal
board.Color = Color3.fromHex("283936")
board:AddTag("FreightCameraCutaway")
board.Parent = world

local gui = Instance.new("SurfaceGui")
gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
gui.CanvasSize = Vector2.new(600, 465)
gui.Face = Enum.NormalId.Front
gui.LightInfluence = .20
gui.MaxDistance = 115
gui.Parent = board

local function caption(name: string, top: number, height: number, text: string, size: number, color: Color3)
	local line = Instance.new("TextLabel")
	line.Name = name
	line.Position, line.Size = UDim2.fromOffset(15, top), UDim2.new(1, -30, 0, height)
	line.BackgroundTransparency = 1
	line.Text, line.Font, line.TextSize = text, Enum.Font.GothamBold, size
	line.TextColor3, line.TextXAlignment = color, Enum.TextXAlignment.Left
	line.Parent = gui
	return line
end

local paper = Color3.fromHex("EADCB8")
caption("Department", 0, 38, "DEPOT  07     /     AIRLOCK", 20, paper)
caption("Handling instruction", 404, 57, "INSERT POWER CELL", 37, paper)
local fallback = caption("Handling pictogram", 40, 360, "▰   →   ▣", 98, Color3.fromHex("79D8C4"))
fallback.TextXAlignment = Enum.TextXAlignment.Center
local ok, plate = pcall(function()
	local data = require(script.Parent.ReceiverPrintData)
	local image = AssetService:CreateEditableImage({Size = Vector2.new(data.width, data.height)})
	if not image then return nil end
	local packed = EncodingService:Base64Decode(buffer.fromstring(data.pixels))
	image:WritePixelsBuffer(Vector2.zero, image.Size, EncodingService:DecompressBuffer(packed, Enum.CompressionAlgorithm.Zstd))
	return image
end)
if ok and plate then
	local art = Instance.new("ImageLabel")
	art.Name = "Cell handling illustration"
	art.BackgroundTransparency = 1
	art.Position, art.Size = UDim2.fromOffset(12, 38), UDim2.new(1, -24, 0, 367)
	art.ScaleType, art.ImageContent = Enum.ScaleType.Crop, Content.fromObject(plate)
	art.Parent = gui
	fallback:Destroy()
end
