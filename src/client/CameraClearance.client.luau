-- Let the local orbit pass through decorative geometry without changing the
-- world used by movement, prompts, crew pings or drone sight lines.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local tracked = {}
local receiver = {}

local function suppressFace(record, child)
	if child:IsA("SurfaceGui") and child.Enabled then
		record.faces[child] = true
		child.Enabled = false
	end
end

local function restore(part, record)
	if record.original == nil then return end
	part.LocalTransparencyModifier = record.original
	record.original = nil
	record.added:Disconnect()
	for face in record.faces do
		if face.Parent == part then face.Enabled = true end
	end
	table.clear(record.faces)
end

local function setHidden(part, record, hidden)
	if not hidden then
		restore(part, record)
	elseif record.original == nil then
		record.original = part.LocalTransparencyModifier
		part.LocalTransparencyModifier = 1
		for _, child in part:GetChildren() do suppressFace(record, child) end
		record.added = part.ChildAdded:Connect(function(child) suppressFace(record, child) end)
	end
end

local function watch(tag, parts)
	local function track(part)
		parts[part] = {faces = {}, radius = part.Size.Magnitude * 0.5}
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(part)
		local record = parts[part]
		if record then restore(part, record); parts[part] = nil end
	end)
	for _, part in CollectionService:GetTagged(tag) do track(part) end
end

watch("FreightCameraCutaway", tracked)
watch("FreightReceiverBody", receiver)

-- Clip the eye-to-avatar segment to the three slabs of an oriented part.
local function clip(origin, delta, extent, entry, exit)
	if math.abs(delta) < 0.0001 then
		if math.abs(origin) > extent then return 1, 0 end
		return entry, exit
	end
	local a, b = (-extent - origin) / delta, (extent - origin) / delta
	return math.max(entry, math.min(a, b)), math.min(exit, math.max(a, b))
end

local function crosses(part, eye, travel, padding)
	local pose = part.CFrame
	local origin = pose:PointToObjectSpace(eye)
	local delta = pose:VectorToObjectSpace(travel)
	local extent = part.Size * 0.5 + Vector3.one * padding
	local entry, exit = clip(origin.X, delta.X, extent.X, 0, 1)
	if entry > exit then return false end
	entry, exit = clip(origin.Z, delta.Z, extent.Z, entry, exit)
	if entry > exit then return false end
	entry, exit = clip(origin.Y, delta.Y, extent.Y, entry, exit)
	return entry <= exit
end

-- The floor console can cover the torso while leaving the head visible.
-- Treat its housing and moving cassettes as a unit, even at long orbit distances.
local receiverHidden = false
local function receiverObstructs(eye, head, root)
	if not eye or not root or not head then return false end
	local toHead = head.Position - eye
	local toBody = root.Position - eye
	-- A player can press against the front edge while looking at the
	-- receiver. Padding must not pull a hit from behind the avatar forward.
	local inset = 1
	toHead *= 1 - math.min(1, inset / math.max(toHead.Magnitude, inset))
	toBody *= 1 - math.min(1, inset / math.max(toBody.Magnitude, inset))
	local padding = if receiverHidden then 0.9 else 0.55
	local reach = math.max(toHead.Magnitude, toBody.Magnitude)
	for part, record in receiver do
		if (part.Position - eye).Magnitude > reach + record.radius + 2 then continue end
		if crosses(part, eye, toBody, padding) or crosses(part, eye, toHead, padding) then return true end
	end
	return false
end

RunService:BindToRenderStep("FreightCameraClearance", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local eye = camera and camera.CFrame.Position
	local root = character and character:FindFirstChild("HumanoidRootPart")
	receiverHidden = receiverObstructs(eye, head, root)
	for part, record in receiver do setHidden(part, record, receiverHidden) end
	local travel = if eye and head then head.Position - eye else Vector3.zero
	-- Only scenery close enough to fill the view needs a cutaway at long zoom.
	if travel.Magnitude > 8 then travel = travel.Unit * 8 end
	for part, record in tracked do
		local hidden = record.original ~= nil
		-- Reject distant pieces before transforming the segment into part space.
		local nearby = eye and (part.Position - eye).Magnitude <= record.radius + 10
		setHidden(part, record, head and nearby and crosses(part, eye, travel, if hidden then 1.1 else 0.8))
	end
end)
