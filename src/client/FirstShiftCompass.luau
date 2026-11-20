local RunService = game:GetService("RunService")

local showArrow = require(script.Parent.CompassVisibility)

local Compass = {}

function Compass.mount(card, colors, add, label, t)
	local chip = add("Frame", card, {
		Name = "FirstShiftCompass", AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(152, 28), Visible = false,
		BackgroundColor3 = colors.ink, BackgroundTransparency = 0.08, BorderSizePixel = 0,
	})
	add("UICorner", chip, {CornerRadius = UDim.new(0, 5)})
	local border = add("UIStroke", chip, {Color = colors.cyan, Transparency = 0.5})
	local arrow = label(chip, "Heading", 5, 3, 24, 22, 16, colors.cyan, true)
	arrow.Text = "▲"
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	local destination = label(chip, "Destination", 34, 3, 112, 22, 12, colors.paper, true)
	local target, root, carrying

	local render = RunService.PreRender:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera or not target or not root or not target:IsDescendantOf(workspace)
			or not root:IsDescendantOf(workspace) then
			chip.Visible = false
			return
		end

		local waypoint, onScreen = camera:WorldToViewportPoint(target.Position + Vector3.new(0, 3, 0))
		local size = camera.ViewportSize
		local offset = target.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local distance = flat.Magnitude
		if distance <= 8 or not showArrow(chip.Visible, onScreen, waypoint.X, waypoint.Y, size.X, size.Y) then
			chip.Visible = false
			return
		end

		-- The camera's right axis stays usable even when looking straight down.
		local right = camera.CFrame.RightVector
		local forward = Vector3.new(right.Z, 0, -right.X)
		arrow.Rotation = math.deg(math.atan2(flat:Dot(right), flat:Dot(forward)))
		local color = carrying and colors.amber or colors.cyan
		arrow.TextColor3 = color
		border.Color = color
		local name = if carrying then t("AIRLOCK", "ШЛЮЗ") else t("BATTERY", "БАТАРЕЯ")
		destination.Text = string.format("%s  ·  %d", name, math.round(distance))
		chip.Visible = true
	end)
	card.Destroying:Once(function() render:Disconnect() end)

	return function(nextTarget, nextRoot, hasCargo, compact)
		if target ~= nextTarget or root ~= nextRoot then chip.Visible = false end
		target, root, carrying = nextTarget, nextRoot, hasCargo
		chip.Position = UDim2.new(0.5, 0, 1, compact and 6 or 49)
	end
end

return Compass
