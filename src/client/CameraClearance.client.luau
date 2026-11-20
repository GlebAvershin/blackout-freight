-- Let the local orbit pass through decorative geometry without changing the
-- world used by movement, prompts, crew pings or drone sight lines.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local tag = "FreightCameraCutaway"
local tracked = {}

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

local function track(part)
	tracked[part] = {faces = {}, radius = part.Size.Magnitude * 0.5}
end
CollectionService:GetInstanceAddedSignal(tag):Connect(track)
CollectionService:GetInstanceRemovedSignal(tag):Connect(function(part)
	local record = tracked[part]
	if record then restore(part, record); tracked[part] = nil end
end)
for _, part in CollectionService:GetTagged(tag) do track(part) end

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

RunService:BindToRenderStep("FreightCameraClearance", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local eye = camera and camera.CFrame.Position
	local travel = if eye and head then head.Position - eye else Vector3.zero
	-- Only scenery close enough to fill the view needs a cutaway at long zoom.
	if travel.Magnitude > 8 then travel = travel.Unit * 8 end
	for part, record in tracked do
		local hidden = record.original ~= nil
		-- Reject distant pieces before transforming the segment into part space.
		local nearby = eye and (part.Position - eye).Magnitude <= record.radius + 10
		if head and nearby and crosses(part, eye, travel, if hidden then 1.1 else 0.8) then
			if not hidden then
				record.original = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 1
				for _, child in part:GetChildren() do suppressFace(record, child) end
				record.added = part.ChildAdded:Connect(function(child) suppressFace(record, child) end)
			end
		elseif hidden then
			restore(part, record)
		end
	end
end)
