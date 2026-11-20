-- The server owns the original welded pursuit body. The shell, servo and light
-- pool are local visuals so the drone AI sends the same transforms at Heat 5.
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local rig = require(script.Parent.SentinelRig)
local state = game:GetService("ReplicatedStorage"):WaitForChild("Freight"):WaitForChild("Shift")
local player = Players.LocalPlayer
local units = {}
local tag = "FreightSentinelRig"

local function part(parent, name)
	local p = Instance.new("Part")
	p.Name = name
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.Anchored = false
	p.Parent = parent
	return p
end

local groupOffsets = {
	Hull = Vector3.zero,
	Port = Vector3.new(-2.52, 0.565, 0.1),
	Starboard = Vector3.new(2.52, 0.565, 0.1),
	Optic = Vector3.new(0, -0.03, -1.31),
}
local function joint(kind, base, piece, offset)
	local link = Instance.new(kind)
	link.Part0, link.Part1, link.C0 = base, piece, offset
	link.Parent = piece
	return link
end

-- A thin pool follows the actual floor or the top of a cargo stack. It is
-- purely visual, and none of its parts participate in gameplay raycasts.
local function projector(shell, body)
	local mount = Instance.new("Attachment")
	mount.Name = "Inspection lamp"
	mount.Position = Vector3.new(0, -0.45, -1.07)
	mount.Parent = body
	local pool = part(shell, "Inspection footprint")
	pool.Size = Vector3.new(.025, 2, 2)
	pool.Transparency = 1
	pool.CastShadow = false
	pool.Anchored = true
	local falloff = Instance.new("SurfaceGui")
	falloff.Face = Enum.NormalId.Right
	falloff.LightInfluence = 0
	falloff.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	falloff.CanvasSize = Vector2.new(96, 96)
	falloff.Enabled = false
	falloff.Parent = pool
	local rings = {}
	for _, width in {.99, .86, .71, .56, .40, .25} do
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(.5, .5)
		ring.Size, ring.Position = UDim2.fromScale(width, width), UDim2.fromScale(.5, .5)
		ring.BackgroundTransparency, ring.BorderSizePixel = .945, 0
		Instance.new("UICorner", ring).CornerRadius = UDim.new(.5, 0)
		ring.Parent = falloff
		table.insert(rings, ring)
	end
	local tip = Instance.new("Attachment", pool)
	local beam = Instance.new("Beam")
	beam.Name = "Inspection shaft"
	beam.Attachment0, beam.Attachment1 = mount, tip
	beam.FaceCamera = true
	beam.LightEmission = .65
	beam.Width0 = .13
	beam.Transparency = NumberSequence.new(.92, .965)
	beam.Enabled = false
	beam.Parent = mount
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	return {pool = pool, beam = beam, mount = mount, falloff = falloff, rings = rings, params = params, nextCast = 0}
end

local function mount(model)
	if units[model] or not model:IsDescendantOf(workspace) then return end
	local body = model:WaitForChild("Body", 6)
	if not body or not model:IsDescendantOf(workspace) or units[model] then return end
	local scale = model:GetScale()
	local shell = Instance.new("Model")
	shell.Name = "Inspection rig"
	local roots, motors, lamps = {}, {}, {}
	for name, offset in groupOffsets do
		local base = part(shell, name .. " mount")
		base.Size = Vector3.one * .1 * scale
		base.Transparency = 1
		base.CastShadow = false
		base.CFrame = body.CFrame * CFrame.new(offset * scale)
		roots[name] = base
		if name == "Hull" then
			joint("Weld", body, base, CFrame.identity)
		else
			motors[name] = joint("Motor6D", body, base, CFrame.new(offset * scale))
		end
	end
	for _, piece in rig.parts do
		local p = part(shell, piece.name)
		if piece.shape == "Ball" then
			-- SpecialMesh preserves the three authored ellipsoid radii.
			local sculpt = Instance.new("SpecialMesh")
			sculpt.MeshType = Enum.MeshType.Sphere
			sculpt.Parent = p
		else
			p.Shape = Enum.PartType[piece.shape]
		end
		p.Size = Vector3.new(table.unpack(piece.size)) * scale
		local pose = CFrame.new(table.unpack(piece.pose))
		local localPose = CFrame.new(pose.Position * scale) * pose.Rotation
		p.CFrame = body.CFrame * localPose
		local paint = rig.palette[piece.paint]
		p.Color, p.Material = Color3.fromHex(paint[1]), Enum.Material[paint[2]]
		p.CastShadow = piece.group == "Hull"
		joint("Weld", roots[piece.group], p, CFrame.new(-groupOffsets[piece.group] * scale) * localPose)
		if piece.paint == "Optical glass" then table.insert(lamps, p) end
	end
	shell.Parent = model
	local function hideProxy(p)
		if p:IsA("BasePart") then p.LocalTransparencyModifier = 1 end
	end
	for _, p in model:GetChildren() do hideProxy(p) end
	local added = model.ChildAdded:Connect(hideProxy)
	local headlamp = model.Name == "Sentinel" and projector(shell, body) or nil
	units[model] = {body = body, shell = shell, motors = motors, lamps = lamps, headlamp = headlamp,
		added = added, rotor = 0, pan = 0, elapsed = 0, mode = "", variant = ""}
end

local function unmount(model)
	local unit = units[model]
	if not unit then return end
	unit.added:Disconnect()
	if unit.headlamp then unit.headlamp.mount:Destroy() end
	unit.shell:Destroy()
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end
	end
	units[model] = nil
end
CollectionService:GetInstanceAddedSignal(tag):Connect(mount)
CollectionService:GetInstanceRemovedSignal(tag):Connect(unmount)
for _, model in CollectionService:GetTagged(tag) do task.spawn(mount, model) end

local palette = {
	patrol = Color3.fromRGB(238, 144, 59), search = Color3.fromRGB(193, 139, 255),
	hunt = Color3.fromRGB(255, 70, 59), distracted = Color3.fromRGB(75, 231, 223),
}
local function illuminate(head, unit, mode, angle, now)
	if now < head.nextCast then return end
	head.nextCast = now + .065
	local camera = workspace.CurrentCamera
	local close = camera and (unit.body.Position - camera.CFrame.Position).Magnitude < 110
	if not close or state:GetAttribute("Phase") ~= "live" then
		head.falloff.Enabled = false
		head.beam.Enabled = false
		return
	end
	local reach = mode == "hunt" and 1.05 or .46
	local direction = unit.body.CFrame:VectorToWorldSpace(Vector3.new(math.sin(angle) * .84, -1, -reach))
	local character = player.Character
	head.params.FilterDescendantsInstances = if character then {unit.body.Parent, character} else {unit.body.Parent}
	local hit = workspace:Raycast(head.mount.WorldPosition, direction.Unit * 14, head.params)
	head.beam.Enabled = hit ~= nil
	if not hit then
		head.falloff.Enabled = false
		return
	end
	local radius = math.clamp(hit.Distance * (mode == "hunt" and .16 or .29), .65, 2.6)
	head.beam.Width1 = radius * 1.75
	head.pool.Size = Vector3.new(.025, 2 * radius, 2 * radius)
	local along = math.abs(hit.Normal.Y) > .85 and Vector3.xAxis or Vector3.yAxis
	local tangent = (along - hit.Normal * hit.Normal:Dot(along)).Unit
	head.pool.CFrame = CFrame.fromMatrix(hit.Position + hit.Normal * .026, hit.Normal, tangent)
	head.falloff.Enabled = true
end

RunService.PreSimulation:Connect(function(dt)
	local mode = state:GetAttribute("SentinelMode") or "patrol"
	local variant = state:GetAttribute("SentinelVariant")
	local reduced = GuiService.ReducedMotionEnabled
	local now = os.clock()
	for _, unit in units do
		local color = palette[mode] or palette.patrol
		if mode == "patrol" and variant == "Tracker" then color = palette.search end
		if mode ~= unit.mode or variant ~= unit.variant then
			for _, lamp in unit.lamps do lamp.Color = color end
			if unit.headlamp then
				unit.headlamp.beam.Color = ColorSequence.new(color)
				for _, ring in unit.headlamp.rings do ring.BackgroundColor3 = color end
			end
			unit.mode, unit.variant = mode, variant
		end
		unit.elapsed += dt
		local sweep = if reduced or mode == "hunt" then 0
			else math.sin(unit.elapsed * (mode == "search" and 2.3 or 1.3)) * (mode == "search" and .68 or .36)
		unit.pan += (sweep - unit.pan) * (1 - math.exp(-dt * 9))
		unit.motors.Optic.Transform = CFrame.Angles(mode == "hunt" and -.14 or 0, unit.pan, 0)
		if not reduced then
			unit.rotor = (unit.rotor + dt * (mode == "hunt" and 9 or 5)) % (2 * math.pi)
			unit.motors.Port.Transform = CFrame.Angles(0, unit.rotor, 0)
			unit.motors.Starboard.Transform = CFrame.Angles(0, -unit.rotor, 0)
		end
		if unit.headlamp then illuminate(unit.headlamp, unit, mode, unit.pan, now) end
	end
end)
