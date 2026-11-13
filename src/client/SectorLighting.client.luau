local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Freight")
if not require(shared:WaitForChild("Config")).SectorBlackoutEnabled then return end

local sector = require(shared.SectorBlackout)
local state = shared:WaitForChild("Shift")
local player = Players.LocalPlayer
local fixtures = {}
local function update(fixture, original)
	local phase = state:GetAttribute("BlackoutPhase")
	local transition = phase == "warning" and not GuiService.ReducedMotionEnabled
		and not player:GetAttribute("FreightSteadyLights")
	local factor = if phase == "dark" then 0 elseif transition then 0.78 else 1
	local color = original.color:Lerp(Color3.fromRGB(35, 40, 46), 1 - factor)
	if original.colorTween then original.colorTween:Cancel(); original.colorTween = nil end
	if original.lightTween then original.lightTween:Cancel(); original.lightTween = nil end
	fixture.Material = if phase == "dark" then Enum.Material.SmoothPlastic else original.material
	if transition then
		local info = TweenInfo.new(sector.WarningSeconds, Enum.EasingStyle.Linear)
		original.colorTween = TweenService:Create(fixture, info, {Color = color})
		original.colorTween:Play()
		if original.light then
			original.lightTween = TweenService:Create(original.light, info, {Brightness = original.brightness * factor})
			original.lightTween:Play()
		end
	else
		fixture.Color = color
		if original.light then original.light.Brightness = original.brightness * factor end
	end
end

local function track(fixture)
	local light = fixture:FindFirstChildOfClass("PointLight")
	local original = {color = fixture.Color, material = fixture.Material, light = light, brightness = light and light.Brightness}
	fixtures[fixture] = original
	update(fixture, original)
end

for _, fixture in CollectionService:GetTagged(sector.FixtureTag) do track(fixture) end
CollectionService:GetInstanceAddedSignal(sector.FixtureTag):Connect(track)
CollectionService:GetInstanceRemovedSignal(sector.FixtureTag):Connect(function(fixture) fixtures[fixture] = nil end)
local function refresh()
	for fixture, original in fixtures do update(fixture, original) end
end
state:GetAttributeChangedSignal("BlackoutPhase"):Connect(refresh)
player:GetAttributeChangedSignal("FreightSteadyLights"):Connect(refresh)
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(refresh)
