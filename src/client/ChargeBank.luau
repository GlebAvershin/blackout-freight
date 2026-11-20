-- Same five physical sockets are repeated on the receiver wall and in the HUD.
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local ChargeBank = {}
function ChargeBank.mount(rail, total, gap, wellColor, litColor)
	local contacts = {}
	for index = 1, total do
		local well = Instance.new("Frame")
		well.Name = "Bank" .. index
		well.Position = UDim2.new((index - 1) / total, gap / 2, 0, 0)
		well.Size = UDim2.new(1 / total, -gap, 1, 0)
		well.BackgroundColor3 = wellColor
		well.BorderSizePixel = 0
		well.Parent = rail

		local fill = Instance.new("Frame")
		fill.Name = "Charge"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = litColor
		fill.Parent = well
		contacts[index] = {fill = fill}
	end

	local previous, reduced
	return function(count)
		local steady = GuiService.ReducedMotionEnabled
		if count == previous and steady == reduced then return end
		for index, contact in contacts do
			local active = index <= count
			if previous ~= nil and active == (index <= previous) and steady == reduced then continue end
			if contact.tween then contact.tween:Cancel(); contact.tween = nil end
			local size = UDim2.fromScale(active and 1 or 0, 1)
			if active and previous ~= nil and index > previous and not steady then
				local timing = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out,
					0, false, math.min(index - previous - 1, 4) * 0.045)
				contact.tween = TweenService:Create(contact.fill, timing, {Size = size})
				contact.tween:Play()
			else
				contact.fill.Size = size
			end
		end
		previous, reduced = count, steady
	end
end

return ChargeBank
