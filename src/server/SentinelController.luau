local CollectionService = game:GetService("CollectionService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Freight")
local Config = require(shared.Config)
local Operations = require(shared.Operations)
local SentinelBrain = require(shared.SentinelBrain)
local Depot = require(script.Parent.Depot)

local SentinelController = {}

function SentinelController.new(drone, world, state, carried, shelters, callbacks)
	local rootOf = callbacks.rootOf
	local clearPath = callbacks.clearPath
	local catch = callbacks.catch
	local setDecoyReady = callbacks.setDecoyReady
	local lightBeacon = callbacks.lightBeacon
	local sentinelBrain = SentinelBrain.new()
	local sentinelVariant = "Sentinel"
	local trackedPlayer
	local distracted = false
	local swarm = {}
	local droneStart = Vector3.new(table.unpack(Config.Drone.Start))
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
	local dronePoint = droneStart
	local patrol = {}
	for _, point in Config.Drone.Patrol do
		table.insert(patrol, Vector3.new(table.unpack(point)))
	end
	local heat = Config.Heat[1]
	local patrolIndex = 1
	local function clearSwarm()
		for _, unit in swarm do unit.model:Destroy() end
		table.clear(swarm)
	end

	local heatLevel = 1
	local controller = {}

	function controller.configure(level, yardEligible)
		heatLevel = level
		heat = Config.Heat[level]
		sentinelVariant = SentinelBrain.variant(heatLevel, yardEligible)
		sentinelBrain.clear()
		state:SetAttribute("SentinelVariant", sentinelVariant)
		state:SetAttribute("SentinelMode", "patrol")
		for _, part in drone:GetChildren() do
			if part.Name == "Eye" or part.Name == "Thruster flare" then
				part.Color = sentinelVariant == "Tracker" and Color3.fromRGB(174,120,255) or Depot.Red
			end
		end
	end

	function controller.deploy()
		dronePoint = droneStart
		patrolIndex = heatLevel >= 3 and 3 or 1
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
	end

	function controller.finish()
		clearSwarm()
		sentinelBrain.clear()
		state:SetAttribute("SentinelMode", "patrol")
	end

	function controller.resetDecoy()
		distracted = false
		scanner.Color = Depot.Amber
		searchBeam.Attachment1 = nil
		searchBeam.Color = ColorSequence.new(Depot.Red)
	end

	function controller.trackedPlayer()
		return trackedPlayer
	end

	function controller.forget(player)
		if trackedPlayer == player then
			trackedPlayer = nil
			searchBeam.Attachment1 = nil
			scanner.Color = Depot.Amber
			player:SetAttribute("Tracked", false)
		end
	end

	function controller.step(dt, time, pulseActive, pilotRoot, gateShield, activeDecoyAnchor,
		decoyReadyAt, portableBeacon, route, carrying, blackBoxId)
		local candidates = {}
		if not pulseActive then
			for player in carried do
				local root = rootOf(player)
				if root and root.Position.Z < Config.AirlockSafeZ then
					local pos = root.Position
					local distance = (Vector3.new(pos.X, dronePoint.Y, pos.Z) - dronePoint).Magnitude
					table.insert(candidates, {id=player, x=pos.X, z=pos.Z,
						priority=carrying[player.UserId] == blackBoxId and distance * Config.Drone.BlackBoxPriority or distance,
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
		if route then
			local x, z = Operations.waypoint(route, dronePoint.X, dronePoint.Z, goal.X, goal.Z)
			goal = Vector3.new(x, dronePoint.Y, z)
		end
		local delta = goal - dronePoint
		if delta.Magnitude > 0.05 then
			local dir = delta.Unit
			local speed = if target and carrying[target.UserId] == blackBoxId then heat.BlackBoxSpeed elseif target or pulseActive then heat.ChaseSpeed else heat.PatrolSpeed
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
			if route then x, z = Operations.waypoint(route, point.X, point.Z, x, z) end
			local delta = Vector3.new(x, point.Y, z) - point
			if delta.Magnitude > 0.05 then
				local nextPoint = point + delta.Unit * math.min(delta.Magnitude, dt * 11)
				unit.model:PivotTo(CFrame.lookAt(nextPoint, nextPoint + delta.Unit))
				if not pulseActive and targetRoot and carried[target] and (targetRoot.Position - nextPoint).Magnitude < 3.5
					and clearPath(nextPoint, targetRoot.Position) then catch(target) end
			end
		end
	end

	return controller
end

return SentinelController
