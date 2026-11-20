local LocalizationService = game:GetService("LocalizationService")
local ChargeBank = require(script.Parent.ChargeBank)
local Display = {}

function Display.mount(panel, total, cyan)
	local russian = LocalizationService.RobloxLocaleId:lower():sub(1, 2) == "ru"
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Receiver readout"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1160, 220)
	gui.LightInfluence = 0.08
	gui.MaxDistance = 150
	gui.Parent = panel
	local ivory = Color3.fromRGB(243, 240, 215)
	local amber = Color3.fromRGB(255, 194, 87)
	local well = Color3.fromRGB(60, 80, 79)

	local function rect(x, y, w, h, color)
		local frame = Instance.new("Frame")
		frame.Position = UDim2.fromOffset(x, y)
		frame.Size = UDim2.fromOffset(w, h)
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.Parent = gui
		return frame
	end
	local function text(x, y, w, h, size, font, color, value)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(x, y)
		label.Size = UDim2.fromOffset(w, h)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Font = font
		label.TextSize = size
		label.TextColor3 = color
		label.Text = value
		label.AutoLocalize = false
		label.Parent = gui
		return label
	end

	rect(0, 0, 1160, 220, Color3.fromRGB(18, 32, 35))
	rect(0, 0, 171, 220, amber)
	local ink = Color3.fromRGB(28, 41, 41)
	text(19, 14, 145, 40, 28, Enum.Font.GothamBold, ink, russian and "ДЕПО" or "DEPOT")
	text(12, 48, 150, 120, 105, Enum.Font.RobotoMono, ink, "07")
	for _, x in {29, 55} do rect(x, 179, 10, 26, ink).Rotation = 19 end
	text(201, 12, 700, 38, 30, Enum.Font.RobotoMono, cyan,
		russian and "ПРИЁМНИК  /  ЗАРЯД" or "RECEIVER  /  CHARGE")
	local caption = text(198, 54, 700, 92, 73, Enum.Font.GothamBold, ivory, "")
	local counter = text(885, 54, 264, 92, 70, Enum.Font.RobotoMono, ivory, "")
	counter.Name = "Total"
	counter.TextXAlignment = Enum.TextXAlignment.Right
	local bank = rect(197, 166, 938, 26, well)
	bank.Name = "ChargeRail"
	bank.BackgroundTransparency = 1
	local updateBank = ChargeBank.mount(bank, total, 9, well, cyan)
	return function(count)
		caption.Text = if count >= total then (russian and "ЛИНИЯ ГОТОВА" or "LINE READY")
			else (russian and "БАТАРЕИ" or "POWER CELLS")
		counter.Text = string.format("%02d/%02d", count, total)
		updateBank(count)
	end
end

return Display
