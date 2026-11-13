local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local shared = ReplicatedStorage:WaitForChild("Freight")
local Round = require(shared.Round)
local MovementGuard = require(shared.MovementGuard)
local Progression = require(shared.Progression)
local Config = require(shared.Config)
local Operations = require(shared.Operations)
local Dispatch = require(shared.Dispatch)
local PowerCell = require(shared.PowerCell)
local FriendInvite = require(shared.FriendInvite)
local Depot = require(script.Parent.Depot)
local EndingJournal = require(script.Parent.EndingJournal)
local ProfileService = require(script.Parent.ProfileService)
local profiles = ProfileService.new()
local blackBoxId = "blackBox"
local CommerceService = require(script.Parent.CommerceService)
local log = require(script.Parent.Analytics).log
local journal = EndingJournal.new(not RunService:IsStudio() and DataStoreService:GetDataStore("FreightEndings_v1") or nil)
game:BindToClose(function() profiles:close() end)
game:BindToClose(function()
	journal:flush()
end)

local world, terminal, positions, drone, consoles, showPower, beacon, lightBeacon = Depot.build()
CollectionService:AddTag(drone.PrimaryPart, "FreightSentinel")
local scanner = drone.PrimaryPart.Scanner
local searchBeam = Instance.new("Beam")
searchBeam.Name = "TrackingBeam"
searchBeam.Attachment0 = Instance.new("Attachment", drone.PrimaryPart)
searchBeam.Color = ColorSequence.new(Depot.Red)
searchBeam.Transparency = NumberSequence.new(0.55, 0.82)
searchBeam.Width0 = 0.12
searchBeam.Width1 = 1.3
searchBeam.FaceCamera = true
searchBeam.LightEmission = 0.85
searchBeam.Parent = drone.PrimaryPart
local state = Instance.new("Folder")
state.Name = "Shift"
state:SetAttribute("Phase", "waiting")
state:SetAttribute("Delivered", 0)
state:SetAttribute("Ending", "")
state:SetAttribute("RouteSource", "")
state:SetAttribute("Operation", "")
state:SetAttribute("Target", Config.Target)
state:SetAttribute("EndsAt", 0)
state:SetAttribute("DecoyUntil", 0)
state:SetAttribute("DecoyReady", false)
state:SetAttribute("BlackBoxStatus", "")
state.Parent = shared

local random = Random.new()
local round
local cells = {}
local carried = {}
local trackedPlayer
local players = {}
local commerceService = CommerceService.new(Config, function(player) return players[player] ~= nil end)
local heatLevel = 1
local roundGuid
local roundStartedAt
local dispatchWeek
local decoyUntil, decoyReadyAt = 0, 0
local distracted = false
local operation, lastOperation, layout
local crewInviteToken, crewInviteExpires, crewReplay
local depotSpawn = CFrame.new(0, 4, 59)
local droneStart = Vector3.new(table.unpack(Config.Drone.Start))
local function now()
	return workspace:GetServerTimeNow()
end

local function onboard(player, n, label)
	local data = players[player]
	if data and data.onboard < n then
		data.onboard = n
		log(AnalyticsService.LogOnboardingFunnelStepEvent, player, n, label)
	end
end

local function funnel(player, n, label)
	log(AnalyticsService.LogFunnelStepEvent, player, "Shift", roundGuid, n, label)
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") or nil
end

-- Currency eligibility samples at interaction time as well as on Heartbeat.
local function verifyMovement(player, root)
	local data = players[player]
	if not data or not root then return false end
	local position, time = root.Position, now()
	if not data.movement then data.movement = MovementGuard.new(position.X, position.Z, time) end
	local valid = data.movement:sample(position.X, position.Z, time, 16)
	player:SetAttribute("MovementVerified", valid)
	if not valid then
		data.cargoVerified = false
		if time >= (data.nextMoveLog or 0) then
			data.nextMoveLog = time + 15
			log(AnalyticsService.LogCustomEvent, player, "MoveFlag")
		end
	end
	return valid
end
local movementElapsed = 0
RunService.Heartbeat:Connect(function(dt)
	movementElapsed += dt
	if movementElapsed < 0.25 then return end
	movementElapsed = 0
	for player, data in players do
		local root = rootOf(player)
		if root then verifyMovement(player, root) else data.movement = nil; data.cargoVerified = false end
	end
end)

local function movePlayer(player, destination)
	player.Character:PivotTo(destination)
	local data = players[player]
	if data then data.movement = nil; data.cargoVerified = false end
	player:SetAttribute("MovementVerified", false)
end

local function promptAt(part, action, name, offset)
	local anchor = Instance.new("Attachment")
	anchor.Position = offset
	anchor.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = name
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = true
	prompt.Enabled = false
	prompt.Parent = anchor
	return prompt, anchor
end

local function within(player, anchor)
	local root = rootOf(player)
	return root and (root.Position - anchor.WorldPosition).Magnitude <= 9 and root
end

local geometryRay = RaycastParams.new()
geometryRay.FilterType = Enum.RaycastFilterType.Include
geometryRay.FilterDescendantsInstances = {world}
geometryRay.RespectCanCollide = true

local function clearPath(origin, destination)
	return workspace:Raycast(origin, destination - origin, geometryRay) == nil
end

local function clearCargo(player)
	if players[player] then players[player].cargoVerified = false end
	if carried[player] then
		carried[player]:Destroy()
		carried[player] = nil
	end
	player:SetAttribute("Carrying", false)
	player:SetAttribute("BlackBoxCarrying", false)
	if trackedPlayer == player then
		trackedPlayer = nil
		searchBeam.Attachment1 = nil
		scanner.Color = Depot.Amber
		player:SetAttribute("Tracked", false)
	end
end

local function recover(player)
	local id = round and round:drop(player.UserId)
	clearCargo(player)
	if id and round.outcome == "live" and cells[id] then
		cells[id].Parent = world
		cells[id].PrimaryPart.Attachment.ProximityPrompt.Enabled = true
		if id == blackBoxId then
			state:SetAttribute("BlackBoxStatus", "available")
		end
	end
end

local function showCargo(player, root, isBlackBox)
	local finish = PowerCell.equipped(player)
	local color = PowerCell.Finishes[finish]
	local cf = root.CFrame * CFrame.new(0, 0, 1.1)
	local model = if isBlackBox then Depot.blackBox(world, cf) else PowerCell.build(world, cf, color, finish)
	if not isBlackBox then
		model:SetAttribute("CellFinish", finish)
	end
	if not isBlackBox and finish ~= "Crew" and player:GetAttribute("ArchiveGold") then
		model.PrimaryPart.Color = Color3.fromRGB(185, 130, 46)
		model.PrimaryPart.Material = Enum.Material.Metal
	end
	if not isBlackBox and (player:GetAttribute("DispatchWeeks") or 0) >= Dispatch.RewardWeeks then
		model.Terminal.Color = PowerCell.Dispatch
		model.Terminal.Material = Enum.Material.Neon
	end
	Instance.new("Attachment", model.PrimaryPart).Name = "TrackingTarget"
	for _, part in model:GetChildren() do
		part.Massless = true
		part.CanQuery = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Anchored = false
	end
	carried[player] = model
	player:SetAttribute("BlackBoxCarrying", isBlackBox)
	player:SetAttribute("Carrying", true)
end

local routePrompts = {}
for ending, console in consoles do
	local action = ending == "broadcast" and "Send recording" or "Power shelter"
	local prompt, anchor = promptAt(console, action, "Route power", Vector3.new(0, 1.7, -1.35))
	prompt.RequiresLineOfSight = false
	routePrompts[ending] = prompt
	prompt.Triggered:Connect(function(player)
		if round and players[player] and prompt.Enabled and within(player, anchor) and round:choose(ending, now()) then
			players[player].choseRoute = true
			log(AnalyticsService.LogCustomEvent, player, "Route_" .. ending)
		end
	end)
end

local decoy, decoyAnchor = promptAt(beacon, "Activate", "Decoy beacon", Vector3.new(0, 2, 0))
decoy.RequiresLineOfSight = false
CollectionService:AddTag(beacon, "FreightDecoy")

local function setDecoyReady(ready)
	decoy.Enabled = ready
	state:SetAttribute("DecoyReady", ready)
end

local function resetDecoy()
	decoyUntil, decoyReadyAt, distracted = 0, 0, false
	setDecoyReady(false)
	lightBeacon(false)
	scanner.Color = Depot.Amber
	searchBeam.Attachment1 = nil
	searchBeam.Color = ColorSequence.new(Depot.Red)
	state:SetAttribute("DecoyUntil", 0)
end

decoy.Triggered:Connect(function(player)
	local time = now()
	if not round or round.outcome ~= "live" or time >= round.deadline or time < decoyReadyAt
		or not trackedPlayer or carried[player] or not players[player] or not within(player, decoyAnchor) then
		return
	end
	decoyUntil = time + (player:GetAttribute("UpgradeLens") and 6 or Config.DecoySeconds)
	decoyReadyAt = time + (player:GetAttribute("UpgradeCoil") and 20 or Config.DecoyCooldown)
	round:assistBonus(trackedPlayer.UserId, player.UserId)
	setDecoyReady(false)
	state:SetAttribute("DecoyUntil", decoyUntil)
	log(AnalyticsService.LogCustomEvent, player, "DecoyActivated")
end)

local function showDeliveryEffect(player, isBlackBox)
	local cargo = carried[player]
	local finish = (cargo and cargo:GetAttribute("CellFinish")) or PowerCell.equipped(player)
	if not isBlackBox and finish == "Crew" then
		local ring = PowerCell.crewRing(world, CFrame.new(terminal.Position.X, 3.65, terminal.Position.Z), 1.35)
		local tween = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local center = ring:GetPivot().Position
		for _, segment in ring:GetChildren() do
			local offset = segment.Position - center
			TweenService:Create(segment, tween, {
				Position = segment.Position + offset * 2.5,
				Size = Vector3.new(segment.Size.X * 3.5, segment.Size.Y, segment.Size.Z),
				Transparency = 1,
			}):Play()
		end
		task.delay(0.6, function() ring:Destroy() end)
		return
	end
	local color = if isBlackBox then Depot.Red else PowerCell.Finishes[finish]
	local pulse = Depot.part(world, "Delivery pulse", Vector3.new(0.08, 2, 2),
		CFrame.new(terminal.Position.X, 3.65, terminal.Position.Z) * CFrame.Angles(0, 0, math.pi / 2),
		color, Enum.Material.Neon)
	pulse.Shape = Enum.PartType.Cylinder
	pulse.CanQuery = false
	pulse.Transparency = 0.35
	local fade = TweenService:Create(pulse, TweenInfo.new(0.48, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.08, 10, 10), Transparency = 1,
	})
	fade.Completed:Once(function()
		pulse:Destroy()
	end)
	fade:Play()
end

local deliver, deliveryAnchor = promptAt(terminal, "Deliver", "Airlock", Vector3.new(0, 2.4, -1.6))
CollectionService:AddTag(terminal, "FreightDelivery")
-- The camera may sit behind the console while the player stands in front of it.
deliver.RequiresLineOfSight = false
deliver.Triggered:Connect(function(player)
	if not round or not deliver.Enabled or not within(player, deliveryAnchor) then
		return
	end
	local time = now()
	local accepted, isBlackBox, helperId, boxSeconds = round:deposit(player.UserId, time)
	if accepted then
		if isBlackBox then
			showDeliveryEffect(player, true)
			clearCargo(player)
			state:SetAttribute("BlackBoxStatus", "secured")
			local helper = helperId and Players:GetPlayerByUserId(helperId)
			local assisted = helper ~= nil and players[helper] ~= nil
			journal:recoverBlackBox(player, if assisted then boxSeconds else nil)
			if assisted then
				journal:recoverBlackBox(helper, boxSeconds)
				log(AnalyticsService.LogCustomEvent, helper, "BlackBoxAssist", boxSeconds)
			end
			log(AnalyticsService.LogCustomEvent, player, "BlackBoxDelivered", boxSeconds, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = assisted and "crew" or "solo",
			})
			return
		end
		if time < decoyUntil then
			log(AnalyticsService.LogCustomEvent, player, "DeliveryDuringDecoy")
		end
		local deliveryData, deliveryRoot = players[player], rootOf(player)
		local verified = verifyMovement(player, deliveryRoot)
		if deliveryData and verified and deliveryData.cargoVerified and deliveryData.pickupAt and deliveryRoot then
			local distance = (deliveryRoot.Position - deliveryData.pickupPosition).Magnitude
			if time - deliveryData.pickupAt >= math.max(0.5, distance / 19 - 0.5) then
				deliveryData.verifiedDeliveries = (deliveryData.verifiedDeliveries or 0) + 1
			end
		end
		showDeliveryEffect(player)
		clearCargo(player)
		player:SetAttribute("ShiftDeliveries", (player:GetAttribute("ShiftDeliveries") or 0) + 1)
		state:SetAttribute("Delivered", round.delivered)
		local routing = round.outcome == "routing"
		showPower(round.delivered, routing)
		if routing then
			deliver.Enabled = false
			resetDecoy()
			if state:GetAttribute("BlackBoxStatus") ~= "secured" then
				state:SetAttribute("BlackBoxStatus", "")
			end
			for _, cell in cells do
				cell.PrimaryPart.Attachment.ProximityPrompt.Enabled = false
				cell.Parent = nil
			end
			for teammate in players do
				recover(teammate)
			end
			for _, prompt in routePrompts do
				prompt.Enabled = true
			end
			state:SetAttribute("EndsAt", round.deadline)
			state:SetAttribute("Phase", "routing")
		end
		local data = players[player]
		if data and not data.delivered then
			data.delivered = true
			funnel(player, 3, "Cell delivered")
		end
		if data and data.onboard < 3 then
			onboard(player, 3, "First cell delivered")
			player:SetAttribute("FirstDelivery", true)
			local seconds = math.max(0, now() - data.startedAt)
			log(AnalyticsService.LogCustomEvent, player, "SecondsToFirstDelivery", seconds, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = if seconds <= 90 then "Within 90s" else "Over 90s",
			})
		end
	end
end)

local function updateCrewPatch(player, character)
	local existing = character:FindFirstChild("Depot 07 patch")
	if PowerCell.equipped(player) ~= "Crew" then
		if existing then existing:Destroy() end
		return
	end
	local arm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
	if existing or not arm or not arm:IsA("BasePart") then
		return
	end
	local patch = PowerCell.crewPatch(character, arm.CFrame * CFrame.new(0, 0.15, -arm.Size.Z / 2 - 0.025))
	patch.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = arm, patch, patch
	patch.Anchored = false
end

local function restoreCellFinish(player)
	if not players[player] or carried[player] then
		return
	end
	local preferred = player:GetAttribute("PreferredCellFinish")
	local finish = if preferred then (if PowerCell.canEquip(player, preferred) then preferred else "Standard") else nil
	player:SetAttribute("CellFinish", finish)
	if player.Character then
		updateCrewPatch(player, player.Character)
	end
end

local function readyCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not root or not humanoid or player.Character ~= character then
		return
	end
	local offset = random:NextNumber(-6, 6)
	movePlayer(player, depotSpawn * CFrame.new(offset, 0, 0))
	updateCrewPatch(player, character)
	local data = players[player]
	if data and not data.spawned then
		data.spawned = true
		data.startedAt = now()
	end
	humanoid.Died:Connect(function()
		if player.Character == character then
			recover(player)
		end
	end)
end

local function join(player)
	if players[player] then
		return
	end
	players[player] = {onboard = 0, picked = false, delivered = false, activeShifts = 0, startedAt = now(), shiftCatches = 0}
	player:SetAttribute("Carrying", false)
	player:SetAttribute("BlackBoxCarrying", false)
	player:SetAttribute("Tracked", false)
	player:SetAttribute("Wins", 0)
	player:SetAttribute("ShiftDeliveries", 0)
	player:SetAttribute("Caught", 0)
	player:SetAttribute("FirstDelivery", false)
	for _, attribute in {"PreferredCellFinish", "EndingBroadcast", "EndingShelter", "Aurora", "Crew", "Carrying"} do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			restoreCellFinish(player)
		end)
	end
	journal:join(player)
	profiles:join(player)
	player.CharacterAdded:Connect(function(character)
		readyCharacter(player, character)
	end)
	if player.Character then
		task.spawn(readyCharacter, player, player.Character)
	end
	onboard(player, 1, "Player joined")
	if round and round.outcome == "live" then
		funnel(player, 1, "Shift started")
	end
	if not RunService:IsStudio() then
		task.spawn(function()
			for _ = 1, 8 do
				if not players[player] then
					return
				end
				local data = player:GetJoinData()
				local referrerId = data.ReferredByPlayerId
				if data.LaunchData and data.LaunchData ~= "" and type(referrerId) == "number" and referrerId > 0 then
					if not crewInviteExpires or now() >= crewInviteExpires or not FriendInvite.crewJoin(data, crewInviteToken) then
						return
					end
					local inviter = Players:GetPlayerByUserId(referrerId)
					if inviter and inviter ~= player and players[inviter] then
						local status = state:GetAttribute("BlackBoxStatus")
						local canStartNow = operation == "west" and round and round.outcome == "live"
							and round.deadline - now() >= 30 and (status == "available" or status == "carried")
						if not canStartNow then
							crewReplay = {inviter, player}
						end
					end
					return
				end
				task.wait(1)
			end
		end)
	end
	commerceService:join(player)
end

Players.PlayerAdded:Connect(join)
Players.PlayerRemoving:Connect(function(player)
	recover(player)
	journal:leave(player)
	task.spawn(function() profiles:leave(player) end)
	players[player] = nil
end)
local equipFinish = Instance.new("RemoteEvent")
equipFinish.Name = "EquipCellFinish"
equipFinish.OnServerEvent:Connect(function(player, finish)
	local data, root = players[player], rootOf(player)
	if not data or not root or carried[player] or not round or type(finish) ~= "string" then
		return
	end
	if round.outcome ~= "won" and round.outcome ~= "lost"
		and (round.outcome ~= "live" or root.Position.Z < Config.AirlockSafeZ) then
		return
	end
	if not PowerCell.canEquip(player, finish) or finish == PowerCell.equipped(player) then
		return
	end
	local time = now()
	if time < (data.nextFinishChange or 0) then
		return
	end
	data.nextFinishChange = time + 0.4
	if not journal:setFinish(player, finish, DateTime.now().UnixTimestampMillis) then
		return
	end
	restoreCellFinish(player)
	log(AnalyticsService.LogCustomEvent, player, "CellFinishEquipped", 1, {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = finish,
	})
end)
equipFinish.Parent = shared
if Config.CosmeticPassId > 0 then
	local steps = {"Locker shown", "Aurora selected", "Purchase prompt opened"}
	local commerce = Instance.new("RemoteEvent")
	commerce.Name = "Commerce"
	commerce.OnServerEvent:Connect(function(player, step)
		local data = players[player]
		if not data or step ~= (data.commerceStep or 0) + 1 or not steps[step] then
			return
		end
		if step == 1 then
			local wonBefore = player:GetAttribute("Wins") > 0
				or player:GetAttribute("EndingBroadcast") or player:GetAttribute("EndingShelter")
			if not wonBefore or player:GetAttribute("Aurora") ~= false then
				return
			end
			data.commerceSession = HttpService:GenerateGUID(false)
		end
		data.commerceStep = step
		log(AnalyticsService.LogFunnelStepEvent, player, "Aurora Lens Locker", data.commerceSession, step, steps[step])
	end)
	commerce.Parent = shared
end

local preparation = Instance.new("RemoteEvent")
preparation.Name = "Preparation"
preparation.OnServerEvent:Connect(function(player, action, value)
	local data = players[player]
	if not data or type(action) ~= "string" then return end
	local time = now()
	if time < (data.nextPreparation or 0) then return end
	data.nextPreparation = time + 0.5
	local phase, root = state:GetAttribute("Phase"), rootOf(player)
	local between = phase == "won" or phase == "lost" or phase == "briefing"
	if action == "heat" then
		if not between or type(value) ~= "number" or value % 1 ~= 0 or not Config.Heat[value] then return end
		player:SetAttribute("HeatVote", value)
		log(AnalyticsService.LogCustomEvent, player, "HeatVote", value)
	elseif action == "upgrade" then
		local item = type(value) == "string" and Progression.Catalog[value]
		if not item or not root or carried[player] or (not between and root.Position.Z < Config.AirlockSafeZ) then return end
		player:SetAttribute("WorkshopResult", "pending")
		if not profiles:enqueue(player, {kind = "upgrade", id = value, price = item.price}) then
			player:SetAttribute("WorkshopResult", "unavailable")
		end
	end
end)
preparation.Parent = shared

for _, player in Players:GetPlayers() do
	join(player)
end

local dronePoint = droneStart
local patrol = {}
for _, point in Config.Drone.Patrol do
	table.insert(patrol, Vector3.new(table.unpack(point)))
end
local heat = Config.Heat[1]
local patrolIndex = 1
local function moveDrone(dt)
	local time = now()
	local pulseActive = time < decoyUntil
	local target, targetRoot, nearest
	if not pulseActive then
		for player in carried do
			local root = rootOf(player)
			if root then
				local pos = root.Position
				local distance = (Vector3.new(pos.X, dronePoint.Y, pos.Z) - dronePoint).Magnitude
				local priority = if round.carrying[player.UserId] == blackBoxId then distance * Config.Drone.BlackBoxPriority else distance
				if pos.Z < Config.AirlockSafeZ and (not nearest or priority < nearest) then
					target, targetRoot, nearest = player, root, priority
				end
			end
		end
	end
	setDecoyReady(target ~= nil and time >= decoyReadyAt)
	local goal = patrol[patrolIndex]
	if target ~= trackedPlayer or pulseActive ~= distracted then
		if trackedPlayer then
			trackedPlayer:SetAttribute("Tracked", false)
		end
		trackedPlayer = target
		distracted = pulseActive
		lightBeacon(pulseActive)
		searchBeam.Attachment1 = pulseActive and decoyAnchor or (target and carried[target].PrimaryPart.TrackingTarget or nil)
		scanner.Color = pulseActive and Depot.Cyan or (target and Depot.Red or Depot.Amber)
		searchBeam.Color = ColorSequence.new(pulseActive and Depot.Cyan or Depot.Red)
		if target then
			target:SetAttribute("Tracked", true)
		end
	end
	if pulseActive then
		goal = Vector3.new(beacon.Position.X, dronePoint.Y, beacon.Position.Z)
	elseif targetRoot then
		local pos = targetRoot.Position
		goal = Vector3.new(math.clamp(pos.X, -65, 65), dronePoint.Y, math.clamp(pos.Z, -70, 52.5))
	elseif (goal - dronePoint).Magnitude < 2 then
		patrolIndex = patrolIndex % #patrol + 1
	end
	if operation then
		local x, z = Operations.waypoint(Operations.Routes[operation], dronePoint.X, dronePoint.Z, goal.X, goal.Z)
		goal = Vector3.new(x, dronePoint.Y, z)
	end
	local delta = goal - dronePoint
	if delta.Magnitude > 0.05 then
		local dir = delta.Unit
		local speed = if target and round.carrying[target.UserId] == blackBoxId then heat.BlackBoxSpeed elseif target or pulseActive then heat.ChaseSpeed else heat.PatrolSpeed
		dronePoint += dir * math.min(delta.Magnitude, dt * speed)
		drone:PivotTo(CFrame.lookAt(dronePoint, dronePoint + dir))
	end
	if targetRoot and (targetRoot.Position - dronePoint).Magnitude < Config.Drone.CatchRadius
		and clearPath(dronePoint, targetRoot.Position) then
		recover(target)
		target:SetAttribute("Caught", target:GetAttribute("Caught") + 1)
		players[target].shiftCatches += 1
		movePlayer(target, depotSpawn)
		log(AnalyticsService.LogCustomEvent, target, "Caught")
	end
end

local function startShift()
	local votes, novice = {}, false
	for player in players do
		table.insert(votes, player:GetAttribute("HeatVote") or 1)
		if not player:GetAttribute("FirstDelivery") and not player:GetAttribute("EndingBroadcast")
			and not player:GetAttribute("EndingShelter") then novice = true end
	end
	heatLevel = Progression.chooseHeat(votes, novice)
	heat = Config.Heat[heatLevel]
	state:SetAttribute("Heat", heatLevel)
	local eligible = false
	for player in players do
		if journal:eligible(player) then
			eligible = true
			break
		end
	end
	local previousOperation = operation
	local replayWest = crewReplay and players[crewReplay[1]] and players[crewReplay[2]]
	crewReplay = nil
	operation = Operations.next(eligible, operation, lastOperation, replayWest)
	if layout then
		layout:Destroy()
		layout = nil
	end
	if operation or previousOperation then
		for player in players do
			if rootOf(player) then
				movePlayer(player, depotSpawn * CFrame.new(random:NextNumber(-6, 6), 0, 0))
			end
		end
	end
	local ids
	if operation then
		lastOperation = operation
		local passage
		layout, passage = Depot.operation(world, Operations.Routes[operation], Operations.DividerZ, Operations.GapWidth)
		CollectionService:AddTag(passage, "FreightPassage")
		ids = Operations.Routes[operation].cells
	else
		local pool = {}
		for i = 3, #positions do
			table.insert(pool, i)
		end
		ids = {1, 2}
		while #ids < Config.CellCount do
			table.insert(ids, table.remove(pool, random:NextInteger(1, #pool)))
		end
	end
	roundStartedAt = now()
	dispatchWeek = Dispatch.week(os.time())
	state:SetAttribute("DispatchWeek", dispatchWeek)
	local hasBlackBox = operation == "west"
	round = Round.new(Config.Target, roundStartedAt + Config.ShiftSeconds, ids, Config.RoutingSeconds,
		if hasBlackBox then blackBoxId else nil)
	showPower(0, false)
	roundGuid = HttpService:GenerateGUID(false)
	if hasBlackBox then
		crewInviteToken = roundGuid
		crewInviteExpires = now() + 360
	end
	state:SetAttribute("CrewInviteToken", if hasBlackBox then crewInviteToken else nil)
	dronePoint = droneStart
	patrolIndex = 1
	drone:PivotTo(CFrame.new(dronePoint))
	local function spawnCargo(id, model, isBlackBox)
		cells[id] = model
		local prompt, anchor = promptAt(model.PrimaryPart, isBlackBox and "Recover" or "Take cell",
			isBlackBox and "Black box" or "Power cell", Vector3.new(0, 1, 0))
		CollectionService:AddTag(model.PrimaryPart, isBlackBox and "FreightBlackBox" or "FreightPickup")
		prompt.Enabled = true
		prompt.Triggered:Connect(function(player)
			if not round or cells[id] ~= model or not prompt.Enabled then
				return
			end
			local root = within(player, anchor)
			local data = players[player]
			if data and root and clearPath(root.Position, anchor.WorldPosition)
				and round:pickup(player.UserId, id, now()) then
				data.cargoVerified = verifyMovement(player, root)
				data.pickupAt, data.pickupPosition = now(), root.Position
				prompt.Enabled = false
				model.Parent = nil
				showCargo(player, root, isBlackBox)
				if isBlackBox then
					state:SetAttribute("BlackBoxStatus", "carried")
					if not data.tookBlackBox then
						data.tookBlackBox = true
						log(AnalyticsService.LogCustomEvent, player, "BlackBoxPickedUp")
					end
					return
				end
				if not data.picked then
					data.picked = true
					data.activeShifts += 1
					if data.activeShifts <= 2 then
						log(AnalyticsService.LogCustomEvent, player, "ActiveShift_" .. data.activeShifts)
					end
					funnel(player, 2, "Cell picked up")
				end
				if data.onboard < 2 then
					onboard(player, 2, "First cell picked up")
					local seconds = math.max(0, now() - data.startedAt)
					log(AnalyticsService.LogCustomEvent, player, "SecondsToFirstPickup", seconds, {
						[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = if seconds <= 45 then "Within 45s" else "Over 45s",
					})
				end
			end
		end)
	end
	for _, id in ids do
		local cf = CFrame.new(positions[id] + Vector3.new(0, 2.14, 0))
		spawnCargo(id, PowerCell.build(world, cf, Depot.Cyan), false)
	end
	if hasBlackBox then
		local model = Depot.blackBox(world, CFrame.new(-35, 0.72, -34))
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = Depot.Red, 9, 1.35
		light.Parent = model.PrimaryPart
		spawnCargo(blackBoxId, model, true)
	end
	for player, data in players do
		data.picked, data.delivered, data.choseRoute = false, false, false
		data.tookBlackBox = false
		data.shiftCatches = 0
		data.verifiedDeliveries = 0
		player:SetAttribute("LastScrapAward", 0)
		player:SetAttribute("DispatchCompletedThisShift", false)
		player:SetAttribute("NewBestThisShift", false)
		player:SetAttribute("SignalUnlockedThisShift", false)
		player:SetAttribute("ShiftDeliveries", 0)
		player:SetAttribute("ArchiveUnlockedThisShift", false)
		funnel(player, 1, "Shift started")
	end
	deliver.Enabled = true
	resetDecoy()
	state:SetAttribute("Ending", "")
	state:SetAttribute("RouteSource", "")
	state:SetAttribute("Operation", operation or "")
	state:SetAttribute("BlackBoxStatus", hasBlackBox and "available" or "")
	state:SetAttribute("Delivered", 0)
	state:SetAttribute("EndsAt", round.deadline)
	state:SetAttribute("Phase", "live")
end

local function finishShift()
	deliver.Enabled = false
	resetDecoy()
	for _, prompt in routePrompts do
		prompt.Enabled = false
	end
	showPower(round.delivered, false, round.ending)
	local elapsed = math.max(0, now() - roundStartedAt)
	for player, data in players do
		local reward = Progression.reward(data.verifiedDeliveries or 0, heat.ScrapMultiplier)
		if reward > 0 then
			profiles:enqueue(player, {kind = "reward", amount = reward}, roundGuid)
		end
		clearCargo(player)
		if round.outcome == "lost" and rootOf(player) then
			movePlayer(player, depotSpawn * CFrame.new(random:NextNumber(-6, 6), 0, 0))
		end
		if data.picked and round.outcome == "won" then
			player:SetAttribute("Wins", player:GetAttribute("Wins") + 1)
		end
		if round.outcome == "won" and (data.picked or data.choseRoute) then
			local hadSignal = PowerCell.canEquip(player, "Signal")
			local qualifies = Dispatch.qualifies(dispatchWeek, player:GetAttribute("ShiftDeliveries"), data.shiftCatches, elapsed)
			local clearSeconds = if data.delivered and round.routeSource == "chosen" then math.max(1, math.ceil(elapsed)) else nil
			local record, dispatch, newBest = journal:award(player, round.ending, data.delivered and operation or nil,
				qualifies and dispatchWeek or nil, clearSeconds)
			if newBest then
				player:SetAttribute("NewBestThisShift", true)
			end
			if not hadSignal then
				player:SetAttribute("SignalUnlockedThisShift", true)
			end
			if dispatch then
				player:SetAttribute("DispatchCompletedThisShift", true)
				log(AnalyticsService.LogCustomEvent, player, "DispatchCompleted", 1, {
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = tostring(Dispatch.objective(dispatchWeek)),
				})
			end
			if record then
				player:SetAttribute("ArchiveUnlockedThisShift", true)
				log(AnalyticsService.LogCustomEvent, player, "ArchiveRecovered", 1, {
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = operation,
				})
			end
			log(AnalyticsService.LogCustomEvent, player, "EndingReached", 1, {
				[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = round.ending,
				[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = round.routeSource,
				[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = operation or "standard",
			})
		end
		log(AnalyticsService.LogCustomEvent, player, "Shift_" .. round.outcome, elapsed)
	end
	for _, cell in cells do
		cell:Destroy()
	end
	table.clear(cells)
	state:SetAttribute("Ending", round.ending or "")
	state:SetAttribute("RouteSource", round.routeSource or "")
	state:SetAttribute("EndsAt", now() + 8)
	state:SetAttribute("Phase", round.outcome)
	round = nil
end

while true do
	if next(players) == nil then
		state:SetAttribute("Phase", "waiting")
		while next(players) == nil do
			task.wait(0.4)
		end
	end
	if next(players) ~= nil then
		startShift()
		while (round.outcome == "live" or round.outcome == "routing") and next(players) ~= nil do
			local dt = task.wait(0.05)
			round:expire(now())
			if round.outcome == "live" and next(players) ~= nil then
				moveDrone(math.min(dt, 0.15))
			end
		end
		if round.outcome == "live" or round.outcome == "routing" then
			round.outcome = "lost"
		end
		finishShift()
		task.wait(8)
		if next(players) then
			state:SetAttribute("EndsAt", now() + 10)
			state:SetAttribute("Phase", "briefing")
			task.wait(10)
		end
	end
end
