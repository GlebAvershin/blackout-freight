local Lighting = game:GetService("Lighting")
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
local Roles = require(shared.Roles)
local SentinelBrain = require(shared.SentinelBrain)
local sentinelBrain = SentinelBrain.new()
local sentinelVariant = "Sentinel"
local RailCycle = require(shared.RailCycle)
local FreightYard = require(script.Parent.FreightYard)
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
local shelters = require(script.Parent.LightShelters).new(world, Depot, Roles)
local depotPositions = positions
local yard
local currentMap = "depot"
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
local pilot
local swarm = {}
local gateShieldUntil = 0
local gateLights = {}
local function setGateShield(active)
	if state:GetAttribute("GateShield") == active then return end
	state:SetAttribute("GateShield", active)
	for _, strip in gateLights do strip.PointLight.Brightness = active and 1.65 or 0.95 end
end
for _, part in world:GetChildren() do
	if part.Name == "Gate light" then table.insert(gateLights, part) end
end
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

commerceService:enableRewardedAds(Config, shared, profiles, function(player)
	local root = rootOf(player)
	return root and root.Position.Z >= Config.AirlockSafeZ and not carried[player]
		and (player:GetAttribute("ProfileStatus") == "ready" or player:GetAttribute("ProfileStatus") == "local")
end)

-- Currency eligibility samples at interaction time as well as on Heartbeat.
local function verifyMovement(player, root)
	local data = players[player]
	if not data or not root then return false end
	local position, time = root.Position, now()
	if not data.movement then data.movement = MovementGuard.new(position.X, position.Z, time) end
	local speed = Roles.speed(data.sprintUntil or 0, time, carried[player] ~= nil)
	local valid = data.movement:sample(position.X, position.Z, time, speed)
	player:SetAttribute("MovementVerified", valid)
	if not valid then
		data.cargoVerified = false
		if data.reserveProof then data.reserveProof.verified = false end
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
		if root then
			local speed = Roles.speed(data.sprintUntil or 0, now(), carried[player] ~= nil)
			root.Parent.Humanoid.WalkSpeed = speed
			verifyMovement(player, root)
		else data.movement = nil; data.cargoVerified = false end
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
	return root and now() >= (player:GetAttribute("RecoveryUntil") or 0) and (root.Position - anchor.WorldPosition).Magnitude <= 9 and root
end

local geometryRay = RaycastParams.new()
geometryRay.FilterType = Enum.RaycastFilterType.Include
geometryRay.FilterDescendantsInstances = {world}
geometryRay.RespectCanCollide = true

local function clearPath(origin, destination)
	return workspace:Raycast(origin, destination - origin, geometryRay) == nil
end

local function clearCargo(player)
	if players[player] then
		players[player].cargoVerified = false
		players[player].reserveProof = nil
		players[player].sprintUntil = 0
		player:SetAttribute("SprintUntil", 0)
		local root = rootOf(player)
		if root then root.Parent.Humanoid.WalkSpeed = 16 end
	end
	if carried[player] then
		carried[player]:Destroy()
		carried[player] = nil
	end
	player:SetAttribute("Carrying", false)
	player:SetAttribute("CargoCount", 0)
	player:SetAttribute("BlackBoxCarrying", false)
	if trackedPlayer == player then
		trackedPlayer = nil
		searchBeam.Attachment1 = nil
		scanner.Color = Depot.Amber
		player:SetAttribute("Tracked", false)
	end
end

local function recover(player, caught)
	while round and round.carrying[player.UserId] do
		local hard = caught and heatLevel >= 3
		local id = round:drop(player.UserId, hard)
		local cell = cells[id]
		if not cell or round.outcome ~= "live" then continue end
		if id == blackBoxId then
			state:SetAttribute("BlackBoxStatus", hard and "lost" or "available")
			if hard then continue end
		elseif hard then
			local available = {}
			for other, model in cells do
				if other ~= id and other ~= blackBoxId and model.Parent == world and round.cells[other] == "available" then
					table.insert(available, model)
				end
			end
			if #available > 0 then
				local other = available[random:NextInteger(1, #available)]
				local original = cell:GetPivot()
				cell:PivotTo(other:GetPivot())
				other:PivotTo(original)
			end
		end
		cell.Parent = world
		cell.PrimaryPart.Attachment.ProximityPrompt.Enabled = true
	end
	clearCargo(player)
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
	player:SetAttribute("CargoCount", 1)
end

local routePrompts = {}
for ending, console in consoles do
	local action = ending == "broadcast" and "Send recording" or "Power shelter"
	local prompt, anchor = promptAt(console, action, "Route power", Vector3.new(0, 1.7, -1.35))
	prompt.RequiresLineOfSight = false
	routePrompts[ending] = prompt
	prompt.Triggered:Connect(function(player)
		if round and player ~= pilot and players[player] and prompt.Enabled and within(player, anchor) and round:choose(ending, now()) then
			players[player].choseRoute = true
			log(AnalyticsService.LogCustomEvent, player, "Route_" .. ending)
		end
	end)
end

local decoy, decoyAnchor = promptAt(beacon, "Activate", "Decoy beacon", Vector3.new(0, 2, 0))
decoy.RequiresLineOfSight = false
CollectionService:AddTag(beacon, "FreightDecoy")
local portableBeacon
local activeDecoyAnchor = decoyAnchor

local function clearPortableBeacon()
	if portableBeacon then portableBeacon:Destroy(); portableBeacon = nil end
	activeDecoyAnchor = decoyAnchor
end

local function setDecoyReady(ready)
	decoy.Enabled = ready
	state:SetAttribute("DecoyReady", ready)
end

local function resetDecoy()
	clearPortableBeacon()
	state:SetAttribute("DecoyReadyAt", 0)
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
	state:SetAttribute("DecoyReadyAt", decoyReadyAt)
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
			if time - deliveryData.pickupAt >= math.max(0.5, distance / (deliveryData.usedSprint and 25 or 19) - 0.5) then
				deliveryData.verifiedDeliveries = (deliveryData.verifiedDeliveries or 0) + 1
			end
		end
		showDeliveryEffect(player)
		if round.carrying[player.UserId] then
			player:SetAttribute("CargoCount", 1)
			local proof = deliveryData.reserveProof
			deliveryData.cargoVerified, deliveryData.pickupAt, deliveryData.pickupPosition = proof.verified, proof.time, proof.position
			deliveryData.usedSprint, deliveryData.reserveProof = proof.usedSprint, nil
		else
			clearCargo(player)
		end
		player:SetAttribute("ShiftDeliveries", (player:GetAttribute("ShiftDeliveries") or 0) + 1)
		state:SetAttribute("Delivered", round.delivered)
		gateShieldUntil = time + (if heatLevel >= 4 then 2 else 5)
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
			setGateShield(false)
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
	local lamp = Instance.new("PointLight")
	lamp.Name, lamp.Range, lamp.Brightness = "WorkshopLamp", 16, 0.8
	lamp.Enabled = player:GetAttribute("UpgradeLamp") == true
	lamp.Parent = root
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
	player:SetAttribute("CrewRole", "Carrier")
	player:SetAttribute("NextCrewRole", "Carrier")
	player:SetAttribute("AbilityReadyAt", 0)
	player:SetAttribute("SprintUntil", 0)
	for _, attribute in {"PreferredCellFinish", "EndingBroadcast", "EndingShelter", "Aurora", "Crew", "Carrying"} do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			restoreCellFinish(player)
		end)
	end
	player:GetAttributeChangedSignal("UpgradeLamp"):Connect(function()
		local root = rootOf(player)
		local lamp = root and root:FindFirstChild("WorkshopLamp")
		if lamp then lamp.Enabled = player:GetAttribute("UpgradeLamp") == true end
	end)
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
	shelters.remove(player)
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

local audioSettings = Instance.new("RemoteEvent")
audioSettings.Name = "AudioSettings"
audioSettings.OnServerEvent:Connect(function(player, musicMuted, effectsMuted, extra)
	local data = players[player]
	if not data or extra ~= nil or type(musicMuted) ~= "boolean" or type(effectsMuted) ~= "boolean" then return end
	local time = now()
	if time < (data.nextAudioSetting or 0) then return end
	data.nextAudioSetting = time + 1
	profiles:enqueue(player, {kind="audio",musicMuted=musicMuted,effectsMuted=effectsMuted})
end)
audioSettings.Parent = shared
local scan = Instance.new("RemoteEvent")
scan.Name = "SentinelScan"
scan.Parent = shared
local preparation = Instance.new("RemoteEvent")
preparation.Name = "Preparation"
preparation.OnServerEvent:Connect(function(player, action, value)
	local data = players[player]
	if not data or type(action) ~= "string" then return end
	local time = now()
	if time < (data.nextPreparation or 0) then return end
	data.nextPreparation = time + 0.5
	local phase, root = state:GetAttribute("Phase"), rootOf(player)
	if player == pilot and phase == "live" then return end
	local between = phase == "won" or phase == "lost" or phase == "briefing"
	if action == "ability" then
		local role = player:GetAttribute("CrewRole")
		if value ~= nil or not root or not round or time < (player:GetAttribute("RecoveryUntil") or 0) or time >= round.deadline
			or not Roles.canUse(role, round.outcome, time, data.abilityReadyAt or 0, carried[player] ~= nil,
				root.Position.Z < Config.AirlockSafeZ, trackedPlayer ~= nil and time >= decoyReadyAt and time >= decoyUntil)
			or not verifyMovement(player, root) then return end
		if math.abs(root.Position.X) > 70 or root.Position.Z < -75 then return end
		local definition = Roles.Catalog[role]
		data.abilityReadyAt = time + definition.cooldown
		player:SetAttribute("AbilityReadyAt", data.abilityReadyAt)
		if role == "Carrier" then
			data.usedSprint = true
			if data.reserveProof then data.reserveProof.usedSprint = true end
			data.sprintUntil = time + definition.duration
			player:SetAttribute("SprintUntil", data.sprintUntil)
			root.Parent.Humanoid.WalkSpeed = 22
		elseif role == "Scout" then
			scan:FireClient(player, drone, time + definition.duration)
		elseif role == "Technician" then
			shelters.deploy(player, root, time)
		else
			clearPortableBeacon()
			portableBeacon = Depot.part(world, "Portable crew beacon", Vector3.new(1.2, 0.5, 1.2),
				CFrame.new(root.Position.X, 0.5, root.Position.Z), Depot.Cyan, Enum.Material.Neon, false)
			portableBeacon.CanQuery = false
			activeDecoyAnchor = Instance.new("Attachment", portableBeacon)
			activeDecoyAnchor.Position = Vector3.new(0, 1.5, 0)
			local light = Instance.new("PointLight", portableBeacon)
			light.Color, light.Range, light.Brightness = Depot.Cyan, 10, 1.5
			decoyUntil = time + definition.duration + (player:GetAttribute("UpgradeLens") and 1 or 0)
			decoyReadyAt = time + (player:GetAttribute("UpgradeCoil") and 20 or Config.DecoyCooldown)
			state:SetAttribute("DecoyReadyAt", decoyReadyAt)
			round:assistBonus(trackedPlayer.UserId, player.UserId)
			state:SetAttribute("DecoyUntil", decoyUntil)
			setDecoyReady(false)
		end
		log(AnalyticsService.LogCustomEvent, player, "RoleAbility", 1, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = role,
		})
	elseif action == "pilot" then
		if not Config.SentinelPilotEnabled or not between or type(value) ~= "boolean" or not journal:eligible(player) then return end
		player:SetAttribute("PilotVolunteer", value)
	elseif action == "map" then
		if not between or (value ~= "depot" and value ~= "yard") then return end
		if value == "yard" and not journal:eligible(player) then return end
		player:SetAttribute("MapVote", value)
	elseif action == "role" then
		if not between or type(value) ~= "string" or not Roles.Catalog[value] then return end
		if not profiles:enqueue(player, {kind="role",role=value}) then return end
		player:SetAttribute("NextCrewRole", value)
		log(AnalyticsService.LogCustomEvent, player, "RoleSelected", 1, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = value,
		})
	elseif action == "heat" then
		if not between or type(value) ~= "number" or value % 1 ~= 0 or not Config.Heat[value] or (value > 3 and not journal:eligible(player)) then return end
		player:SetAttribute("HeatVote", value)
		log(AnalyticsService.LogCustomEvent, player, "HeatVote", value)
	elseif action == "upgrade" then
		local item = type(value) == "string" and Progression.Catalog[value]
		if not item or not root or carried[player] or (not between and (phase ~= "live" or root.Position.Z < Config.AirlockSafeZ)) then return end
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
local function catch(player)
	recover(player, true)
	player:SetAttribute("Caught", (player:GetAttribute("Caught") or 0) + 1)
	players[player].shiftCatches += 1
	if heatLevel >= 3 then player:SetAttribute("RecoveryUntil", now() + 10) end
	movePlayer(player, depotSpawn)
	log(AnalyticsService.LogCustomEvent, player, "Caught")
end

local function clearSwarm()
	for _, unit in swarm do unit.model:Destroy() end
	table.clear(swarm)
end

local function moveDrone(dt)
	local time = now()
	shelters.step(time, rootOf)
	local pulseActive = time < decoyUntil
	local pilotRoot = pilot and rootOf(pilot)
	if pilot and (not pilotRoot or not players[pilot]) then
		pilot:SetAttribute("PilotingSentinel", false)
		pilot = nil -- Normal AI immediately resumes.
	end
	local gateShield = time < gateShieldUntil
	setGateShield(gateShield)
	if not pulseActive and portableBeacon then clearPortableBeacon() end
	local candidates = {}
	if not pulseActive then
		for player in carried do
			local root = rootOf(player)
			if root and root.Position.Z < Config.AirlockSafeZ then
				local pos = root.Position
				local distance = (Vector3.new(pos.X, dronePoint.Y, pos.Z) - dronePoint).Magnitude
				table.insert(candidates, {id=player, x=pos.X, z=pos.Z,
					priority=round.carrying[player.UserId] == blackBoxId and distance * Config.Drone.BlackBoxPriority or distance,
					visible=sentinelVariant ~= "Tracker" or clearPath(dronePoint, pos), protected=shelters.protects(pos) or (gateShield and pos.Z >= 48 and math.abs(pos.X) <= 13)})
			end
		end
	else sentinelBrain.clear() end
	local target, rememberedX, rememberedZ, mode = sentinelBrain.choose(sentinelVariant, time, candidates)
	local targetRoot = target and rootOf(target)
	state:SetAttribute("SentinelMode", pulseActive and "distracted" or mode)
	setDecoyReady(target ~= nil and time >= decoyReadyAt)
	local goal = patrol[patrolIndex]
	if target ~= trackedPlayer or pulseActive ~= distracted then
		if trackedPlayer then
			trackedPlayer:SetAttribute("Tracked", false)
		end
		trackedPlayer = target
		distracted = pulseActive
		lightBeacon(pulseActive and not portableBeacon)
		searchBeam.Attachment1 = pulseActive and activeDecoyAnchor or (target and carried[target].PrimaryPart.TrackingTarget or nil)
		searchBeam.Color = ColorSequence.new(pulseActive and Depot.Cyan or Depot.Red)
		if target then
			target:SetAttribute("Tracked", true)
		end
	end
	scanner.Color = pulseActive and Depot.Cyan or (target and Depot.Red or (mode == "search" and Color3.fromRGB(174,120,255) or Depot.Amber))
	if pulseActive then
		goal = Vector3.new(activeDecoyAnchor.WorldPosition.X, dronePoint.Y, activeDecoyAnchor.WorldPosition.Z)
	elseif pilotRoot then
		local pos = pilotRoot.Position
		goal = Vector3.new(math.clamp(pos.X, -65, 65), dronePoint.Y, math.clamp(pos.Z, -70, 52.5))
	elseif targetRoot then
		local pos = targetRoot.Position
		goal = Vector3.new(math.clamp(pos.X, -65, 65), dronePoint.Y, math.clamp(pos.Z, -70, 52.5))
	elseif mode == "search" then
		goal = Vector3.new(math.clamp(rememberedX, -65, 65), dronePoint.Y, math.clamp(rememberedZ, -70, 52.5))
	elseif (goal - dronePoint).Magnitude < 2 then
		patrolIndex = (patrolIndex - 1 + (if heatLevel >= 3 then -1 else 1)) % #patrol + 1
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
	if pilotRoot and not pulseActive then
		for _, candidate in candidates do
			local root = rootOf(candidate.id)
			if not candidate.protected and root and (root.Position-dronePoint).Magnitude < Config.Drone.CatchRadius
				and clearPath(dronePoint,root.Position) then
				catch(candidate.id)
				break
			end
		end
	elseif targetRoot and (targetRoot.Position - dronePoint).Magnitude < Config.Drone.CatchRadius
		and clearPath(dronePoint, targetRoot.Position) then
		catch(target)
	end
	for _, unit in swarm do
		local point = unit.model:GetPivot().Position
		local nextGoal = patrol[unit.index]
		if pulseActive then
			nextGoal = activeDecoyAnchor.WorldPosition
		elseif targetRoot and carried[target] and clearPath(point, targetRoot.Position) then
			nextGoal = targetRoot.Position
		elseif (nextGoal - point).Magnitude < 2 then
			unit.index = unit.index % #patrol + 1
		end
		local x, z = nextGoal.X, math.min(nextGoal.Z, 52.5)
		if operation then x, z = Operations.waypoint(Operations.Routes[operation], point.X, point.Z, x, z) end
		local delta = Vector3.new(x, point.Y, z) - point
		if delta.Magnitude > 0.05 then
			local nextPoint = point + delta.Unit * math.min(delta.Magnitude, dt * 11)
			unit.model:PivotTo(CFrame.lookAt(nextPoint, nextPoint + delta.Unit))
			if not pulseActive and targetRoot and carried[target] and (targetRoot.Position - nextPoint).Magnitude < 3.5
				and clearPath(nextPoint, targetRoot.Position) then catch(target) end
		end
	end
end

local function startShift()
	-- Let a new player's saved role load before choosing the first shift's roles.
	local loadDeadline = now() + 8
	repeat
		local loading = false
		for player in players do if player:GetAttribute("ProfileStatus") == "loading" then loading = true end end
		if not loading then break end
		task.wait(0.1)
	until now() >= loadDeadline
	shelters.clear()
	local votes, novice = {}, false
	local mapVotes, yardEligible = {}, true
	local volunteers = {}
	for player in players do
		table.insert(votes, player:GetAttribute("HeatVote") or 1)
		table.insert(mapVotes, player:GetAttribute("MapVote") or "depot")
		if player:GetAttribute("PilotVolunteer") and rootOf(player) then table.insert(volunteers, player) end
		if not journal:eligible(player) then yardEligible = false end
		if not player:GetAttribute("FirstDelivery") and not player:GetAttribute("EndingBroadcast")
			and not player:GetAttribute("EndingShelter") then novice = true end
	end
	pilot = nil
	if Config.SentinelPilotEnabled and yardEligible and #votes >= 3 and #volunteers > 0 then
		pilot = volunteers[random:NextInteger(1,#volunteers)]
	end
	heatLevel = Progression.chooseHeat(votes, novice, yardEligible)
	heat = Config.Heat[heatLevel]
	state:SetAttribute("Heat", heatLevel)
	Lighting.ExposureCompensation = if heatLevel == 5 then -0.27 else 0.22
	sentinelVariant = SentinelBrain.variant(heatLevel, yardEligible)
	sentinelBrain.clear()
	state:SetAttribute("SentinelVariant", sentinelVariant)
	state:SetAttribute("SentinelMode", "patrol")
	for _, part in drone:GetChildren() do
		if part.Name == "Eye" or part.Name == "Thruster flare" then
			part.Color = sentinelVariant == "Tracker" and Color3.fromRGB(174,120,255) or Depot.Red
		end
	end
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
	local previousMap = currentMap
	currentMap = replayWest and "depot" or RailCycle.choose(mapVotes, yardEligible)
	if yard then yard.destroy(); yard = nil end
	positions = depotPositions
	if currentMap == "yard" then yard = FreightYard.build(world, Depot); positions = yard.positions end
	state:SetAttribute("Map", currentMap)
	state:SetAttribute("TrainStatus", "clear")
	operation = currentMap == "depot" and Operations.next(eligible, operation, lastOperation, replayWest) or nil
	if layout then
		layout:Destroy()
		layout = nil
	end
	if operation or previousOperation or currentMap ~= previousMap then
		for player in players do
			if rootOf(player) then
				movePlayer(player, depotSpawn * CFrame.new(random:NextNumber(-6, 6), 0, 0))
			end
		end
	end
	local ids
	if yard then
		ids = {1,2,3,4,5,6,7,8}
	elseif operation then
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
	patrolIndex = heatLevel >= 3 and 3 or 1
	gateShieldUntil = now() + (if heatLevel >= 4 then 2 else 5)
	clearSwarm()
	if heatLevel == 5 then
		for index, x in {-28, 28} do
			local model = drone:Clone()
			model.Name = "Swarm " .. index
			CollectionService:RemoveTag(model.PrimaryPart, "FreightSentinel")
			model.PrimaryPart.TrackingBeam:Destroy()
			model.PrimaryPart.Scanner:Destroy()
			model:ScaleTo(0.45)
			model:PivotTo(CFrame.new(x, droneStart.Y, -22))
			model.Parent = world
			table.insert(swarm, {model = model, index = index})
		end
	end
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
			if data and player ~= pilot and root and clearPath(root.Position, anchor.WorldPosition)
				and round:pickup(player.UserId, id, now(), player:GetAttribute("CrewRole") == "Carrier"
					and player:GetAttribute("UpgradeRack") == true) then
				local second = carried[player] ~= nil
				local verified = verifyMovement(player, root)
				if second then
					data.reserveProof = {verified=verified, time=now(), position=root.Position,
						usedSprint=now() < (data.sprintUntil or 0)}
				else
					data.cargoVerified = verified
					data.pickupAt, data.pickupPosition = now(), root.Position
					data.usedSprint = false
				end
				prompt.Enabled = false
				model.Parent = nil
				if second then player:SetAttribute("CargoCount", 2) else showCargo(player, root, isBlackBox) end
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
		player:SetAttribute("PilotingSentinel", player == pilot)
		player:SetAttribute("RecoveryUntil", 0)
		data.picked, data.delivered, data.choseRoute = false, false, false
		data.tookBlackBox = false
		data.shiftCatches = 0
		data.verifiedDeliveries = 0
		data.abilityReadyAt, data.sprintUntil = 0, 0
		player:SetAttribute("CrewRole", player:GetAttribute("NextCrewRole") or "Carrier")
		player:SetAttribute("AbilityReadyAt", 0)
		player:SetAttribute("SprintUntil", 0)
		player:SetAttribute("LastScrapAward", 0)
		player:SetAttribute("LastRankUnlocked", 0)
		player:SetAttribute("LastSeasonUnlocked", 0)
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
	if pilot then
		pilot:SetAttribute("PilotingSentinel", false)
		pilot = nil
	end
	clearSwarm()
	Lighting.ExposureCompensation = 0.22
	setGateShield(false)
	sentinelBrain.clear()
	state:SetAttribute("SentinelMode", "patrol")
	shelters.clear()
	if yard then yard.step(0); state:SetAttribute("TrainStatus", "clear") end
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
			profiles:enqueue(player, {kind = "reward", amount = reward,
				doubleScrap = player:GetAttribute("DoubleScrap") == true, club = player:GetAttribute("DepotClub") == true,
				deliveries = math.clamp(data.verifiedDeliveries or 0, 0, 5),
				ending = if round.outcome == "won" then round.ending else nil}, roundGuid)
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
			local record, dispatch, newBest = journal:award(player, round.ending, data.delivered and (yard and "yard" or operation) or nil,
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
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = yard and "yard" or operation,
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
				if yard then
					local phase, before, after = yard.step(now() - roundStartedAt)
					state:SetAttribute("TrainStatus", phase)
					for player, data in players do
						local root = rootOf(player)
						if root and RailCycle.hit(root.Position.X,root.Position.Y,root.Position.Z,before,after) then
							recover(player)
							data.shiftCatches += 1
							player:SetAttribute("Caught", (player:GetAttribute("Caught") or 0) + 1)
							movePlayer(player, depotSpawn)
							log(AnalyticsService.LogCustomEvent, player, "TrainCaught")
						end
					end
				end
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
