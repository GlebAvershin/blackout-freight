assert(game:GetService("RunService"):IsStudio())
local player = game:GetService("Players").LocalPlayer
local state = game:GetService("ReplicatedStorage"):WaitForChild("Freight"):WaitForChild("Shift")
local gui = player:WaitForChild("PlayerGui"):WaitForChild("FreightHUD")
local card = gui:WaitForChild("ShiftCard")
local guide = gui:WaitForChild("FirstDeliveryGuide")
local compass = card:WaitForChild("FirstShiftCompass", 5)
assert(compass, "GUIDANCE QA: compass missing")
local function waitFor(condition, description, seconds)
	local deadline = os.clock() + (seconds or 3)
	repeat
		if condition() then return end
		task.wait(0.05)
	until os.clock() >= deadline
	error("GUIDANCE QA: " .. description, 2)
end

waitFor(function() return guide.Enabled end, "first pickup marker", 12)
waitFor(function() return player:GetAttribute("FirstShiftCompassUntil") end, "live server enrolls the Studio preview")
local camera = workspace.CurrentCamera
local root = player.Character.HumanoidRootPart
local eye = root.Position + Vector3.new(0, 4, 0)
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(eye, guide.Adornee.Position)
waitFor(function() return not compass.Visible end, "in-frame marker hides compass")
camera.CFrame = CFrame.lookAt(eye, eye * 2 - guide.Adornee.Position)
waitFor(function() return compass.Visible end, "offscreen battery shows compass")
assert(math.abs(compass.Heading.Rotation) > 135, "heading should point behind camera")
local exposure = player:GetAttribute("FirstShiftCompassUntil")
player:SetAttribute("FirstShiftCompassUntil", nil)
waitFor(function() return not compass.Visible and guide.Enabled end, "control retains original world marker")
player:SetAttribute("FirstShiftCompassUntil", exposure)
root.CFrame = CFrame.new(0, 4, 45)
eye = root.Position + Vector3.new(0, 4, 0)
player:SetAttribute("Carrying", true)
waitFor(function()
	return guide.Enabled and guide.Adornee and guide.Adornee:HasTag("FreightDelivery")
end, "cargo switches guide to airlock")
camera.CFrame = CFrame.lookAt(eye, eye * 2 - guide.Adornee.Position)
waitFor(function()
	local text = compass.Destination.Text
	return compass.Visible and (text:find("AIRLOCK", 1, true) or text:find("ШЛЮЗ", 1, true))
end, "airlock compass after pickup")
player:SetAttribute("Carrying", false)
camera.CameraType = Enum.CameraType.Custom
state:SetAttribute("Delivered", 1)
player:SetAttribute("FirstDelivery", true)
player:SetAttribute("ShiftDeliveries", 1)
waitFor(function()
	return guide.Enabled and (card.Hint.Text:find("Battery delivered", 1, true) or card.Hint.Text:find("Батарея принята", 1, true))
end, "first delivery confirmation and next marker")
waitFor(function()
	return card.ChargeRail.Bank1.Charge.Size.X.Scale == 1 and card.ChargeRail.Bank2.Charge.Size.X.Scale == 0
end, "HUD acknowledges first cell")
waitFor(function() return not compass.Visible end, "compass retires after first delivery")
waitFor(function() return not guide.Enabled end, "handoff expires", 6)
player:SetAttribute("Caught", 1)
waitFor(function() return guide.Enabled end, "marker returns after a catch")
state:SetAttribute("Phase", "lost")
waitFor(function()
	return not guide.Enabled and (card.Radio.Text:find("automatically", 1, true) or card.Radio.Text:find("начнётся сама", 1, true))
end, "loss explains auto restart and clears the marker")
state:SetAttribute("Delivered", 0)
player:SetAttribute("ShiftDeliveries", 0)
state:SetAttribute("Phase", "live")
waitFor(function() return guide.Enabled end, "next shift shows marker despite lifetime first delivery")
assert(player:GetAttribute("FirstDelivery") == true)
local terminal = assert(game:GetService("CollectionService"):GetTagged("FreightDelivery")[1])
local rack = terminal:WaitForChild("Charge receiver", 5)
local display = rack["Bank display"]:WaitForChild("Receiver readout", 5)
assert(display and display:IsA("SurfaceGui"), "receiver wall readout missing")
local base = rack.Slot1.Position
for _, count in {1, 4, 5, 0} do
	rack:SetAttribute("Charge", count)
	waitFor(function()
		for index = 1, 5 do
			local slot = rack["Slot" .. index]
			local charged = index <= count
			local expectedY = base.Y + (charged and rack:GetAttribute("Travel") or 0)
			if display.ChargeRail["Bank" .. index].Charge.Size.X.Scale ~= (charged and 1 or 0) then return false end
			if (slot.Material == Enum.Material.Neon) ~= charged or math.abs(slot.Position.Y - expectedY) > 0.01 then return false end
			assert(not slot.CanCollide and not slot.CanQuery and not slot.CanTouch)
		end
		return display.Total.Text == string.format("%02d/05", count) and display.Total.TextFits
	end, "receiver count " .. count)
end
print("RECEIVER QA PASS: first delivery, batched updates, full rack and reset")
local sentinel = workspace["Blackout Freight • Depot 07"].Sentinel
local art = sentinel:WaitForChild("Inspection rig", 5)
assert(art and art.Iris and art["Port impeller 0"] and art["Starboard impeller 0"])
assert(art.Iris.CanQuery == false and sentinel.Eye.LocalTransparencyModifier == 1)
assert(art.Crown:FindFirstChildOfClass("SpecialMesh"), "painted hull must retain its ellipsoid proportions")
waitFor(function()
	local expected = sentinel.Body.CFrame * CFrame.new(0, .38, .21)
	return (expected.Position - art.Crown.Position).Magnitude < .15
end, "housing follows authoritative drone")
local head = sentinel.Body["Inspection lamp"]
local shaft = head["Inspection shaft"]
waitFor(function() return shaft.Enabled and shaft.Attachment1 and shaft.Width1 > 0 end, "inspection lamp lands on floor")
local firstPose = art["Port mount"].Motor6D.Transform
if not game:GetService("GuiService").ReducedMotionEnabled then
	waitFor(function() return art["Port mount"].Motor6D.Transform ~= firstPose end, "inspection fans turn")
end
for _, step in {{"hunt", Color3.fromRGB(255, 70, 59)}, {"distracted", Color3.fromRGB(75, 231, 223)}} do
	state:SetAttribute("SentinelMode", step[1])
	waitFor(function() return art.Iris.Color == step[2] and shaft.Color.Keypoints[1].Value == step[2] end, step[1] .. " cue")
end
state:SetAttribute("SentinelMode", "patrol")
print("SENTINEL ART PASS: coupled housing, animated fan, floor hit and mode colors")
local cue = game:GetService("SoundService"):WaitForChild("FreightDeliveryCue", 5)
player:SetAttribute("Aurora", true)
for index, finish in {"Standard", "Aurora", "Standard"} do
	player:SetAttribute("CellFinish", finish)
	player:SetAttribute("ShiftDeliveries", index)
	local expectedSpeed = if finish == "Aurora" then 1.16 else 0.92
	waitFor(function() return math.abs(cue.PlaybackSpeed - expectedSpeed) < 0.001 end, "cue for " .. finish)
end
print("AUDIO QA PASS: owned Aurora follows equipped finish")
print("GUIDANCE QA PASS: compass/control, pickup, airlock, handoff, recovery, loss and next shift")
game:GetService("ReplicatedStorage"):WaitForChild("GuidanceResult"):FireServer()
