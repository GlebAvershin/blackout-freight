local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("Freight"):WaitForChild("Shift")

local function bus(name, muteAttribute)
	local group = Instance.new("SoundGroup")
	group.Name = name
	local function update()
		group.Volume = SoundService:GetAttribute(muteAttribute) and 0 or 1
	end
	SoundService:GetAttributeChangedSignal(muteAttribute):Connect(update)
	update()
	group.Parent = SoundService
	return group
end

local music = bus("FreightMusic", "FreightMusicMuted")
local effects = bus("FreightEffects", "FreightEffectsMuted")

local function sound(name, asset, group, volume, parent)
	local item = Instance.new("Sound")
	item.Name = name
	item.SoundId = asset
	item.Volume = volume
	item.SoundGroup = group
	item.Parent = parent
	return item
end

-- APM Music and Pro Sound Effects audio from the Roblox Creator Store.
local ambience = sound("FreightAmbience", "rbxassetid://9040460717", music, 0, SoundService)
local tension = sound("FreightTension", "rbxassetid://9039978890", music, 0, SoundService)
ambience.Looped, tension.Looped = true, true
ambience:Play()
tension:Play()

local delivery = sound("FreightDeliveryCue", "rbxasset://sounds/volume_slider.ogg", effects, 0.28, SoundService)
local blackBoxRecovered = sound("FreightBlackBoxCue", "rbxasset://sounds/volume_slider.ogg", effects, 0.36, SoundService)
blackBoxRecovered.PlaybackSpeed = 0.68
local outcome = sound("FreightOutcomeCue", "rbxasset://sounds/volume_slider.ogg", effects, 0.23, SoundService)
local caught = sound("FreightCaughtCue", "rbxasset://sounds/action_jump_land.mp3", effects, 0.22, SoundService)
local sentinel = CollectionService:GetTagged("FreightSentinel")[1]
	or CollectionService:GetInstanceAddedSignal("FreightSentinel"):Wait()
local beacon = CollectionService:GetTagged("FreightDecoy")[1]
	or CollectionService:GetInstanceAddedSignal("FreightDecoy"):Wait()
local motor = sound("FreightMotorCue", "rbxassetid://9118332358", effects, 0.38, sentinel)
local decoy = sound("FreightDecoyCue", "rbxassetid://9118304350", effects, 0.42, beacon)
for _, cue in {motor, decoy} do
	cue.RollOffMode = Enum.RollOffMode.InverseTapered
	cue.RollOffMinDistance = 9
	cue.RollOffMaxDistance = 92
end

local function fadingTrack(track)
	local target, tween
	return function(volume, seconds)
		if target == volume then
			return
		end
		target = volume
		if tween then
			tween:Cancel()
		end
		tween = TweenService:Create(track, TweenInfo.new(seconds), {Volume = volume})
		tween:Play()
	end
end

local fadeAmbience, fadeTension = fadingTrack(ambience), fadingTrack(tension)
local duckUntil = 0
local function refreshMix()
	local phase = state:GetAttribute("Phase")
	local locked = phase == "live" and player:GetAttribute("Tracked") == true
	local decoyActive = phase == "live" and (state:GetAttribute("DecoyUntil") or 0) > workspace:GetServerTimeNow()
	local ducked = os.clock() < duckUntil
	local ambientVolume = phase == "live" and (locked and 0.06 or 0.23) or 0.13
	local tensionVolume = locked and not decoyActive and 0.32 or 0
	if ducked or decoyActive then
		ambientVolume *= 0.38
		tensionVolume *= 0.38
	end
	local seconds = ducked and 0.16 or 0.55
	fadeAmbience(ambientVolume, seconds)
	fadeTension(tensionVolume, seconds)
end

local function duck(seconds)
	duckUntil = math.max(duckUntil, os.clock() + seconds)
	refreshMix()
	task.delay(seconds, refreshMix)
end

local previousDecoy = state:GetAttribute("DecoyUntil") or 0
state:GetAttributeChangedSignal("DecoyUntil"):Connect(function()
	local untilTime = state:GetAttribute("DecoyUntil") or 0
	local remaining = untilTime - workspace:GetServerTimeNow()
	if untilTime ~= previousDecoy and remaining > 0 then
		decoy:Play()
		duck(1.1)
		task.delay(remaining, refreshMix)
	end
	previousDecoy = untilTime
	refreshMix()
end)

player:GetAttributeChangedSignal("Tracked"):Connect(function()
	if player:GetAttribute("Tracked") then
		motor:Play()
		duck(0.8)
	else
		motor:Stop()
	end
	refreshMix()
end)

local previousDeliveries = player:GetAttribute("ShiftDeliveries") or 0
player:GetAttributeChangedSignal("ShiftDeliveries"):Connect(function()
	local deliveries = player:GetAttribute("ShiftDeliveries") or 0
	if deliveries > previousDeliveries then
		delivery.PlaybackSpeed = player:GetAttribute("Aurora") and 1.16 or 0.92
		delivery:Play()
		duck(0.5)
	end
	previousDeliveries = deliveries
end)

local previousCatches = player:GetAttribute("Caught") or 0
state:GetAttributeChangedSignal("BlackBoxStatus"):Connect(function()
	if state:GetAttribute("BlackBoxStatus") == "secured" then
		blackBoxRecovered:Play()
		duck(0.8)
	end
end)

player:GetAttributeChangedSignal("Caught"):Connect(function()
	local catches = player:GetAttribute("Caught") or 0
	if catches > previousCatches then
		caught:Play()
		duck(0.6)
	end
	previousCatches = catches
end)

state:GetAttributeChangedSignal("Phase"):Connect(function()
	local phase = state:GetAttribute("Phase")
	if phase == "won" or phase == "lost" then
		outcome.PlaybackSpeed = phase == "won" and 1.36 or 0.62
		outcome:Play()
		duck(0.8)
	end
	refreshMix()
end)

refreshMix()

local crossingBell = sound("FreightCrossingBell", "rbxasset://sounds/volume_slider.ogg", effects, 0.4, SoundService)
crossingBell.PlaybackSpeed = 0.8
state:GetAttributeChangedSignal("TrainStatus"):Connect(function()
	if state:GetAttribute("Map") == "yard" and state:GetAttribute("TrainStatus") == "warning" then
		crossingBell:Play()
	end
end)
