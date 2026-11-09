local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local shared = ReplicatedStorage:WaitForChild("Freight")
local Round = require(shared.Round)
local Config = require(shared.Config)
local Operations = require(shared.Operations)
local Depot = require(script.Parent.Depot)
local EndingJournal = require(script.Parent.EndingJournal)
local journal = EndingJournal.new(not RunService:IsStudio() and DataStoreService:GetDataStore("FreightEndings_v1") or nil)
game:BindToClose(function()
	journal:flush()
end)

local world, terminal, positions, drone, consoles, showPower = Depot.build()
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
state.Parent = shared

local random = Random.new()
local round
local cells = {}
local carried = {}
local trackedPlayer
local players = {}
local roundGuid
local roundStartedAt
local operation, lastOperation, layout
local depotSpawn = CFrame.new(0, 4, 59)
local droneStart = Vector3.new(-19, 5.5, 12)
local function now()
	return workspace:GetServerTimeNow()
end

local function log(method, ...)
	if RunService:IsStudio() then
		return
	end
	local ok, err = pcall(method, AnalyticsService, ...)
	if not ok then
		warn("Freight analytics:", err)
	end
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
	if carried[player] then
		carried[player]:Destroy()
		carried[player] = nil
	end
	player:SetAttribute("Carrying", false)
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
	end
end

local function showCargo(player, root)
	local color = player:GetAttribute("Aurora") and Depot.Aurora or Depot.Cyan
	local model = Depot.battery(world, root.CFrame * CFrame.new(0, 0, 1.1), color)
	if player:GetAttribute("ArchiveGold") then
		model.PrimaryPart.Color = Color3.fromRGB(185, 130, 46)
		model.PrimaryPart.Material = Enum.Material.Metal
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

local deliver, deliveryAnchor = promptAt(terminal, "Deliver", "Airlock", Vector3.new(0, 2.4, -1.6))
CollectionService:AddTag(terminal, "FreightDelivery")
-- The camera may sit behind the console while the player stands in front of it.
deliver.RequiresLineOfSight = false
deliver.Triggered:Connect(function(player)
	if not round or not deliver.Enabled or not within(player, deliveryAnchor) then
		return
	end
	if round:deposit(player.UserId, now()) then
		clearCargo(player)
		player:SetAttribute("ShiftDeliveries", (player:GetAttribute("ShiftDeliveries") or 0) + 1)
		state:SetAttribute("Delivered", round.delivered)
		local routing = round.outcome == "routing"
		showPower(round.delivered, routing)
		if routing then
			deliver.Enabled = false
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
			log(AnalyticsService.LogCustomEvent, player, "SecondsToFirstDelivery", math.max(0, now() - data.startedAt))
		end
	end
end)

local function readyCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not root or not humanoid or player.Character ~= character then
		return
	end
	local offset = random:NextNumber(-6, 6)
	character:PivotTo(depotSpawn * CFrame.new(offset, 0, 0))
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
	players[player] = {onboard = 0, picked = false, delivered = false, activeShifts = 0, startedAt = now()}
	player:SetAttribute("Carrying", false)
	player:SetAttribute("Tracked", false)
	player:SetAttribute("Wins", 0)
	player:SetAttribute("ShiftDeliveries", 0)
	player:SetAttribute("Aurora", false)
	player:SetAttribute("Caught", 0)
	player:SetAttribute("FirstDelivery", false)
	journal:join(player)
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
	if Config.CosmeticPassId > 0 then
		task.spawn(function()
			for attempt = 1, 3 do
				local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, Config.CosmeticPassId)
				if ok then
					if owned and players[player] then
						player:SetAttribute("Aurora", true)
					end
					break
				end
				task.wait(attempt)
			end
		end)
	end
end

Players.PlayerAdded:Connect(join)
Players.PlayerRemoving:Connect(function(player)
	recover(player)
	journal:leave(player)
	players[player] = nil
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if bought and passId == Config.CosmeticPassId and passId > 0 and players[player] then
		player:SetAttribute("Aurora", true)
	end
end)
for _, player in Players:GetPlayers() do
	join(player)
end

local dronePoint = droneStart
local patrol = {Vector3.new(-31, 5.5, 10), Vector3.new(0, 5.5, -38), Vector3.new(31, 5.5, 17)}
local patrolIndex = 1
local function moveDrone(dt)
	local target, targetRoot, nearest
	for player in carried do
		local root = rootOf(player)
		if root then
			local pos = root.Position
			local distance = (Vector3.new(pos.X, dronePoint.Y, pos.Z) - dronePoint).Magnitude
			if pos.Z < 54 and (not nearest or distance < nearest) then
				target, targetRoot, nearest = player, root, distance
			end
		end
	end
	local goal = patrol[patrolIndex]
	if target ~= trackedPlayer then
		if trackedPlayer then
			trackedPlayer:SetAttribute("Tracked", false)
		end
		trackedPlayer = target
		searchBeam.Attachment1 = target and carried[target].PrimaryPart.TrackingTarget or nil
		scanner.Color = target and Depot.Red or Depot.Amber
		if target then
			target:SetAttribute("Tracked", true)
		end
	end
	if targetRoot then
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
		dronePoint += dir * math.min(delta.Magnitude, dt * (target and 13.7 or 8))
		drone:PivotTo(CFrame.lookAt(dronePoint, dronePoint + dir))
	end
	if targetRoot and (targetRoot.Position - dronePoint).Magnitude < 5.05
		and clearPath(dronePoint, targetRoot.Position) then
		recover(target)
		target:SetAttribute("Caught", target:GetAttribute("Caught") + 1)
		target.Character:PivotTo(depotSpawn)
		log(AnalyticsService.LogCustomEvent, target, "Caught")
	end
end

local function startShift()
	local eligible = false
	for player in players do
		if journal:eligible(player) then
			eligible = true
			break
		end
	end
	local previousOperation = operation
	operation = Operations.next(eligible, operation, lastOperation)
	if layout then
		layout:Destroy()
		layout = nil
	end
	if operation or previousOperation then
		for player in players do
			if rootOf(player) then
				player.Character:PivotTo(depotSpawn * CFrame.new(random:NextNumber(-6, 6), 0, 0))
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
	round = Round.new(Config.Target, roundStartedAt + Config.ShiftSeconds, ids, Config.RoutingSeconds)
	showPower(0, false)
	roundGuid = HttpService:GenerateGUID(false)
	dronePoint = droneStart
	patrolIndex = 1
	drone:PivotTo(CFrame.new(dronePoint))
	for _, id in ids do
		local pos = positions[id]
		local model = Depot.battery(world, CFrame.new(pos + Vector3.new(0, 2.14, 0)), Depot.Cyan)
		cells[id] = model
		local prompt, anchor = promptAt(model.PrimaryPart, "Take cell", "Power cell", Vector3.new(0, 1, 0))
		CollectionService:AddTag(model.PrimaryPart, "FreightPickup")
		prompt.Enabled = true
		prompt.Triggered:Connect(function(player)
			if not round or cells[id] ~= model or not prompt.Enabled then
				return
			end
			local root = within(player, anchor)
			local data = players[player]
			if data and root and clearPath(root.Position, anchor.WorldPosition)
				and round:pickup(player.UserId, id, now()) then
				prompt.Enabled = false
				model.Parent = nil
				showCargo(player, root)
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
					log(AnalyticsService.LogCustomEvent, player, "SecondsToFirstPickup", math.max(0, now() - data.startedAt))
				end
			end
		end)
	end
	for player, data in players do
		data.picked, data.delivered, data.choseRoute = false, false, false
		player:SetAttribute("ShiftDeliveries", 0)
		player:SetAttribute("ArchiveUnlockedThisShift", false)
		funnel(player, 1, "Shift started")
	end
	deliver.Enabled = true
	state:SetAttribute("Ending", "")
	state:SetAttribute("RouteSource", "")
	state:SetAttribute("Operation", operation or "")
	state:SetAttribute("Delivered", 0)
	state:SetAttribute("EndsAt", round.deadline)
	state:SetAttribute("Phase", "live")
end

local function finishShift()
	deliver.Enabled = false
	for _, prompt in routePrompts do
		prompt.Enabled = false
	end
	showPower(round.delivered, false, round.ending)
	for player, data in players do
		clearCargo(player)
		if round.outcome == "lost" and rootOf(player) then
			player.Character:PivotTo(depotSpawn * CFrame.new(random:NextNumber(-6, 6), 0, 0))
		end
		if data.picked and round.outcome == "won" then
			player:SetAttribute("Wins", player:GetAttribute("Wins") + 1)
		end
		if round.outcome == "won" and (data.picked or data.choseRoute) then
			if journal:award(player, round.ending, data.delivered and operation or nil) then
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
		log(AnalyticsService.LogCustomEvent, player, "Shift_" .. round.outcome, math.max(0, now() - roundStartedAt))
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
	end
end
