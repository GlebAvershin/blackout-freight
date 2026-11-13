local player = game:GetService("Players").LocalPlayer
local sound = game:GetService("SoundService")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Freight"):WaitForChild("AudioSettings")
local applying, dirty, generation = false, false, 0
local pendingMusic, pendingEffects
local function ready()
	local status = player:GetAttribute("ProfileStatus")
	return status == "ready" or status == "local" or status == "saving"
end
local function sendLater()
	generation += 1
	local this = generation
	task.delay(1.1, function()
		if this ~= generation or not dirty or not ready() then return end
		dirty = false
		pendingMusic, pendingEffects = sound:GetAttribute("FreightMusicMuted") == true, sound:GetAttribute("FreightEffectsMuted") == true
		remote:FireServer(pendingMusic, pendingEffects)
	end)
end
local function restore()
	if not ready() then return end
	if dirty then sendLater(); return end
	if pendingMusic ~= nil then
		if player:GetAttribute("SavedMusicMuted") ~= pendingMusic or player:GetAttribute("SavedEffectsMuted") ~= pendingEffects then return end
		pendingMusic, pendingEffects = nil, nil
	end
	applying = true
	sound:SetAttribute("FreightMusicMuted", player:GetAttribute("SavedMusicMuted") == true)
	sound:SetAttribute("FreightEffectsMuted", player:GetAttribute("SavedEffectsMuted") == true)
	applying = false
end
for _, attribute in {"FreightMusicMuted", "FreightEffectsMuted"} do
	sound:GetAttributeChangedSignal(attribute):Connect(function()
		if not applying then dirty = true; sendLater() end
	end)
end
for _, attribute in {"SavedMusicMuted", "SavedEffectsMuted", "ProfileStatus"} do
	player:GetAttributeChangedSignal(attribute):Connect(restore)
end
restore()
