local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local PowerCell = require(game:GetService("ReplicatedStorage"):WaitForChild("Freight"):WaitForChild("PowerCell"))
local terminal = CollectionService:GetTagged("FreightDelivery")[1]
	or CollectionService:GetInstanceAddedSignal("FreightDelivery"):Wait()
local rack = terminal:WaitForChild("Charge receiver")
local slots = {}
for index = 1, 5 do
	local part = rack:WaitForChild("Slot" .. index)
	slots[index] = {part = part, rest = part.Position, idle = part.Color}
end

local updateDisplay = require(script.Parent.ReceiverDisplay).mount(rack:WaitForChild("Bank display"), #slots, PowerCell.Cyan)

local function update(animate)
	local count = rack:GetAttribute("Charge") or 0
	updateDisplay(count)
	for index, slot in slots do
		local charged = index <= count
		if animate and slot.charged == charged then continue end
		slot.charged = charged
		if slot.tween then slot.tween:Cancel(); slot.tween = nil end
		local position = slot.rest + Vector3.yAxis * (charged and rack:GetAttribute("Travel") or 0)
		slot.part.Color = if charged then PowerCell.Cyan else slot.idle
		slot.part.Material = if charged then Enum.Material.Neon else Enum.Material.Metal
		if animate and charged and not GuiService.ReducedMotionEnabled then
			slot.tween = TweenService:Create(slot.part, TweenInfo.new(0.24, Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out), {Position = position})
			slot.tween:Play()
		else
			slot.part.Position = position
		end
	end
end

rack:GetAttributeChangedSignal("Charge"):Connect(function() update(true) end)
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function() update(false) end)
update(false)
