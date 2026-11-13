assert(game:GetService("RunService"):IsStudio())
local player = game:GetService("Players").LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("FreightHUD")
local storage = game:GetService("ReplicatedStorage")
local state = storage:WaitForChild("Freight"):WaitForChild("Shift")
local fixture = storage:WaitForChild("MobileHudResult")
local inputs = game:GetService("UserInputService")
local input = assert(inputs:CreateVirtualInput(), "Studio virtual input unavailable")
local card = gui:WaitForChild("ShiftCard")
local dock = gui:WaitForChild("EndingJournalButton")
local offer, preview = gui:WaitForChild("AuroraLens"), gui:WaitForChild("AuroraPreview")
local portrait = script:GetAttribute("Portrait")

local function waitFor(condition, label)
	local deadline = os.clock() + 15
	repeat
		if condition() then return end
		task.wait(0.05)
	until os.clock() >= deadline
	error("MOBILE HUD QA: " .. label .. " viewport=" .. tostring(gui.AbsoluteSize) .. " touch=" .. tostring(inputs.TouchEnabled) .. " phase=" .. tostring(state:GetAttribute("Phase")), 2)
end

local journal
waitFor(function()
	journal = gui:FindFirstChild("EndingJournal", true)
	return journal ~= nil
end, "journal created")

local pointerOffset
local function tap(button)
	local center = button.AbsolutePosition + button.AbsoluteSize / 2
	local service = game:GetService("GuiService")
	local inset = service:GetGuiInset()
	local fired = false
	local connection = button.Activated:Connect(function() fired = true end)
	-- Studio versions differ in whether virtual input includes the simulated device's inset.
	local offsets = {inset, -service:GetInsetArea(Enum.ScreenInsets.None).Min, Vector2.zero}
	if pointerOffset then
		table.insert(offsets, 1, pointerOffset)
	end
	for _, offset in offsets do
		local point = center + offset
		input:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
		task.wait()
		input:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
		task.wait(0.25)
		if fired then
			pointerOffset = offset
			break
		end
	end
	connection:Disconnect()
	if not fired then
		error(string.format("Studio did not activate %s (%s, %s, %s)", button.Name, button.Text,
			tostring(button.Interactable), tostring(center)), 2)
	end
end

local function inside(object)
	local p, s = object.AbsolutePosition, object.AbsoluteSize
	return p.X >= 0 and p.Y >= 0 and p.X + s.X <= gui.AbsoluteSize.X + 1 and p.Y + s.Y <= gui.AbsoluteSize.Y + 1
end

waitFor(function()
	return inputs.TouchEnabled and (gui.AbsoluteSize.Y > gui.AbsoluteSize.X) == portrait
		and gui.FirstDeliveryGuide.Enabled and card.Hint.Text ~= ""
end, "initial guide and objective in expected orientation")
assert(card.Hint.TextFits and card.Radio.TextFits, "first shift HUD text clipped")
assert(card.AbsolutePosition.Y >= (portrait and 0 or -36) and inside(dock), "first shift HUD outside viewport")
assert(card.AbsoluteSize.Y <= 32 and card.AbsoluteSize.X <= 188, "collapsed card takes too much screen space")
assert(not card.Hint.Visible and not card.Radio.Visible, "mobile details cover the scene at spawn")
tap(card.ShiftDetails)
waitFor(function() return card.Hint.Visible and card.Radio.Visible and card.AbsoluteSize.Y == 80 end, "expand shift details")
state:SetAttribute("SentinelVariant", "Tracker")
state:SetAttribute("SentinelMode", "search")
waitFor(function() return card.Radio.Text:find("Tracker",1,true) or card.Radio.Text:find("Следопыт",1,true) end, "tracker advice")
assert(card.Radio.TextFits, "tracker advice clipped")
player:SetAttribute("Tracked", true)
waitFor(function() return card.Objective.Text == "HIDE!" or card.Objective.Text == "ПРЯЧЬСЯ!" end, "tracker counterplay warning")
assert(card.Objective.TextFits and card.Hint.TextFits, "tracker warning clipped")
player:SetAttribute("Tracked", false)
state:SetAttribute("SentinelVariant", "Sentinel")
tap(card.ShiftDetails)
waitFor(function() return not card.Hint.Visible and card.AbsoluteSize.Y == 32 end, "collapse shift details")
assert(math.abs(card.AbsolutePosition.X + card.AbsoluteSize.X / 2 - gui.AbsoluteSize.X / 2) <= 1,
	"shift card must stay horizontally centered")
local ping = gui:WaitForChild("CrewPingButton")
waitFor(function() return ping.Visible end, "crew ping entry visible")
assert(inside(ping) and ping.AbsoluteSize.Y >= 44, "ping button outside safe area")
tap(ping)
local pingMenu = gui.CrewPingMenu
assert(pingMenu.Visible and gui.CrewPingAim.Visible and inside(pingMenu), "ping menu outside safe area")
assert(pingMenu.AbsolutePosition.Y >= card.AbsolutePosition.Y + card.AbsoluteSize.Y, "ping menu overlaps shift card")
for _, option in pingMenu:GetChildren() do
	assert(inside(option) and option.TextFits and option.AbsoluteSize.Y >= 44, "ping option clipped")
end
tap(ping)
assert(not pingMenu.Visible and not gui.CrewPingAim.Visible, "cancel leaves ping menu visible")
state:SetAttribute("BlackoutPhase", "warning")
waitFor(function() return card.Objective.Text == "Power fault" or card.Objective.Text == "Сбой света" end, "collapsed blackout warning")
assert(card.Objective.TextFits, "blackout warning clipped")
state:SetAttribute("BlackoutPhase", nil)
fixture:FireServer("seed")
waitFor(function() return player:GetAttribute("MobileFixtureReady") end, "load the server fixture")
state:SetAttribute("Phase", "won")
waitFor(function() return offer.Visible end, "preview entry after victory")
player:SetAttribute("LastRankUnlocked",2)
waitFor(function() return dock.Text == "Rank 2!" or dock.Text == "Ранг 2!" end, "rank milestone on collapsed HUD")
assert(dock.TextFits, "rank celebration clipped")
player:SetAttribute("LastRankUnlocked",0)
local invite = gui.InviteFriends
assert(inside(offer) and inside(invite), "mobile actions extend outside the safe area")
assert(dock.AbsolutePosition.Y == invite.AbsolutePosition.Y and invite.AbsolutePosition.Y == offer.AbsolutePosition.Y,
	"journal, invite and locker must share the bottom row")
assert(dock.AbsolutePosition.X + dock.AbsoluteSize.X < invite.AbsolutePosition.X
	and invite.AbsolutePosition.X + invite.AbsoluteSize.X < offer.AbsolutePosition.X, "mobile actions overlap")
assert(offer.AbsolutePosition.Y > gui.AbsoluteSize.Y / 2 and offer.AbsoluteSize.Y >= 44, "locker covers the play area")

tap(dock)
waitFor(function() return journal.Visible end, "open journal by pressing its button")
local shell = journal.Parent
local actions = shell.Actions
assert(inside(shell) and inside(journal) and inside(actions), "journal outside the safe area")
assert(journal.AbsolutePosition.Y + journal.AbsoluteSize.Y < actions.AbsolutePosition.Y, "scrollable content overlaps actions")
assert(not card.Visible and not dock.Visible and not invite.Visible and not offer.Visible, "journal overlaps other HUD elements")
assert(not ping.Visible, "ping button overlaps journal")
for _, button in {actions.MusicToggle, actions.EffectsToggle, actions.Close} do
	assert(inside(button) and button.AbsoluteSize.Y >= 44, "journal action clipped")
end
local sound = game:GetService("SoundService")
local muted = sound:GetAttribute("FreightMusicMuted") == true
tap(actions.MusicToggle)
waitFor(function() return (sound:GetAttribute("FreightMusicMuted") == true) ~= muted end, "toggle music from the fixed footer")
waitFor(function() return player:GetAttribute("SavedMusicMuted") == not muted end, "persist music preference")
tap(actions.MusicToggle)
waitFor(function() return player:GetAttribute("SavedMusicMuted") == muted end, "persist unmute")
storage.Freight.AudioSettings:FireServer("invalid",true)
task.wait(0.2)
assert(player:GetAttribute("SavedMusicMuted") == muted, "malformed audio request accepted")
assert(journal.ArchiveTitle.Text:find("2/2", 1, true), "archive is incomplete")
assert(journal.ClearRecord.Text:find("1:13", 1, true) and journal.ClearRecord.TextFits, "record is missing or clipped")
assert(journal.ClearRecord.Position.Y.Offset + journal.ClearRecord.Size.Y.Offset <= journal.CanvasSize.Y.Offset, "record cannot be scrolled into view")
assert(journal.BlackBoxRecord.Visible and journal.BlackBoxRecord.TextFits and journal.BlackBoxRecord.Text:find("0:41", 1, true),
	"Black Box recording or crew time is missing or clipped")
-- Scroll the workshop into view without changing the journal shell or footer.
local workshop = journal:WaitForChild("Workshop")
tap(actions.Close)
player:SetAttribute("LastSeasonUnlocked",1)
waitFor(function() return dock.Visible end,"season notification entry")
tap(dock)
waitFor(function() return journal.Visible end,"open new recording")
assert(math.abs(journal.CanvasPosition.Y-journal.Season.Position.Y.Offset)<2,"new recording did not open event section")
player:SetAttribute("LastSeasonUnlocked",0)
fixture:FireServer("briefing")
waitFor(function() return state:GetAttribute("Phase") == "briefing" and player:GetAttribute("Scrap") == 120 end, "workshop fixture")
player:SetAttribute("LastSeasonUnlocked",1)
tap(actions.Close)
tap(dock)
waitFor(function() return journal.Visible end,"new recording during briefing")
assert(math.abs(journal.CanvasPosition.Y-journal.Season.Position.Y.Offset)<2,"briefing hid new recording behind workshop")
player:SetAttribute("LastSeasonUnlocked",0)
tap(actions.Close)
waitFor(function() return dock.Visible end,"close for Prepare entry")
tap(dock)
waitFor(function() return journal.Visible end,"Prepare entry")
local challengesLink = journal.OpenCrewChallenges
assert(math.abs(journal.CanvasPosition.Y-challengesLink.Position.Y.Offset)<2,"Prepare did not show the daily shift link")
tap(challengesLink)
local challengesPanel = journal.CrewChallenges
waitFor(function() return math.abs(journal.CanvasPosition.Y-challengesPanel.Position.Y.Offset)<2 end,"open daily shift section")
assert(challengesPanel.DailyRules.TextFits and challengesPanel.DailyVote.TextFits, "daily shift controls clipped")
tap(challengesPanel.DailyVote)
waitFor(function() return player:GetAttribute("DailyVote") end,"submit daily shift vote")
task.wait(0.6)
tap(challengesPanel.DailyVote)
waitFor(function() return player:GetAttribute("DailyVote") == false end,"cancel daily shift vote")
journal.CanvasPosition = Vector2.new(0, workshop.Position.Y.Offset)
task.wait(0.3)
assert(workshop.Heat1.AbsoluteSize.Y >= 44 and workshop.Coil.AbsoluteSize.Y >= 44, "workshop touch targets too small")
assert(workshop.Status.TextFits and workshop.Balance.TextFits and workshop.Coil.TextFits and workshop.Lens.TextFits, "workshop text clipped")
assert(workshop.Heat5.AbsoluteSize.Y >= 44 and workshop.Heat5.TextFits, "Heat 5 touch target")
tap(workshop.Heat2)
waitFor(function() return player:GetAttribute("HeatVote") == 2 end, "server accepts heat vote")
task.wait(0.6)
journal.CanvasPosition = Vector2.new(0, workshop.Position.Y.Offset + workshop.Coil.Position.Y.Offset)
task.wait(0.2)
tap(workshop.Coil)
waitFor(function() return player:GetAttribute("UpgradeCoil") == true and player:GetAttribute("Scrap") == 80 end, "coil purchase")
task.wait(0.6)
local shared = storage.Freight
shared.Preparation:FireServer("upgrade", "Coil")
task.wait(0.7)
assert(player:GetAttribute("Scrap") == 80, "duplicate upgrade charged twice")
journal.CanvasPosition = Vector2.new(0, workshop.Position.Y.Offset + workshop.Lens.Position.Y.Offset)
task.wait(0.2)
tap(workshop.Lens)
waitFor(function() return player:GetAttribute("UpgradeLens") == true and player:GetAttribute("Scrap") == 0 end, "lens purchase")
assert(not workshop.Coil.Interactable, "owned upgrade still purchasable")
task.wait(0.6)
journal.CanvasPosition = Vector2.new(0, workshop.Position.Y.Offset + workshop.RoleCarrier.Position.Y.Offset)
task.wait(0.2)
assert(workshop.RoleCarrier.AbsoluteSize.Y >= 44 and workshop.RoleLure.TextFits and workshop.RoleDetail.TextFits, "role selection clipped")
tap(workshop.RoleLure)
waitFor(function() return player:GetAttribute("NextCrewRole") == "Lure" end, "select lure for next shift")
assert(player:GetAttribute("CrewRole") == "Carrier", "role changed during preparation before shift start")
task.wait(0.6)
for _, id in {"Scout", "Technician"} do
	journal.CanvasPosition = Vector2.new(0, workshop.Position.Y.Offset + workshop.RoleScout.Position.Y.Offset)
	task.wait(0.2)
	local button = workshop["Role" .. id]
	assert(button.AbsoluteSize.Y >= 44 and button.TextFits, "support role clipped")
	tap(button)
	waitFor(function() return player:GetAttribute("NextCrewRole") == id end, "select " .. id)
	assert(workshop.RoleDetail.TextFits, "support detail clipped")
	task.wait(0.6)
end
journal.CanvasPosition = Vector2.new(0, workshop.Position.Y.Offset + workshop.Mapyard.Position.Y.Offset)
task.wait(0.2)
assert(workshop.Mapyard.AbsoluteSize.Y >= 44 and workshop.Mapyard.TextFits and workshop.MapDetail.TextFits, "map selection clipped")
tap(workshop.Mapdepot)
waitFor(function() return player:GetAttribute("MapVote") == "depot" end, "map vote")
task.wait(0.6)
tap(workshop.Mapyard)
task.wait(0.6)
assert(player:GetAttribute("MapVote") == "depot", "client ending flags bypassed server map eligibility")
assert(journal.YardRecord.Visible and journal.YardRecord.TextFits, "yard recording clipped")
journal.CanvasPosition = Vector2.new(0, workshop.Position.Y.Offset + workshop.RankTitle.Position.Y.Offset)
task.wait(0.2)
for _, xp in {0,250,500,1000} do
	player:SetAttribute("RankXP", xp)
	task.wait(0.2)
	assert(workshop.RankTitle.TextFits and workshop.RankGoal.TextFits, "career text clipped")
	assert(workshop.RankProgress.Fill.Size.X.Scale >= 0 and workshop.RankProgress.Fill.Size.X.Scale <= 1, "career progress overflow")
end
local seasonPanel=journal:WaitForChild("Season")
for _,tier in {0,1,2,3} do
 player:SetAttribute("SeasonTier",tier)
 player:SetAttribute("SeasonDeliveries",tier==3 and 30 or tier*5)
 journal.CanvasPosition=Vector2.new(0,seasonPanel.Position.Y.Offset)
 task.wait(0.2)
 assert(seasonPanel.Heading.TextFits and seasonPanel.Dates.TextFits and seasonPanel.Progress.TextFits,"season heading clipped")
 for i=1,3 do
  local b=seasonPanel["Chapter"..i]
  local rowCenter=seasonPanel.Position.Y.Offset+b.Position.Y.Offset+b.Size.Y.Offset/2
  journal.CanvasPosition=Vector2.new(0,math.max(0,rowCenter-journal.AbsoluteSize.Y/2))
  task.wait(0.15)
  assert(b.AbsoluteSize.Y>=44 and b.TextFits,"season touch target")
  tap(b)
  task.wait(0.2)
  assert(seasonPanel.Detail.TextFits,"season recording clipped")
 end
end

player:SetAttribute("RankXP",0)
fixture:FireServer("resume")
waitFor(function() return state:GetAttribute("Phase") == "live" end, "resume gameplay")
tap(actions.Close)
waitFor(function() return not journal.Visible and card.Visible and offer.Visible end, "close journal and restore HUD")

tap(offer)
waitFor(function() return preview.Visible end, "open Aurora preview by pressing its button")
assert(inside(preview) and inside(preview.Close) and inside(preview.Buy), "Aurora preview clipped")
assert(inside(preview.Standard) and inside(preview.Signal) and inside(preview.Aurora), "locker swatches clipped")
assert(not card.Visible and not dock.Visible and not invite.Visible and not offer.Visible, "locker overlaps other HUD elements")
if not portrait and gui.AbsoluteSize.X >= 620 then
	assert(preview.AbsolutePosition.X >= gui.AbsoluteSize.X / 2, "locker covers the center of the landscape viewport")
end
local equip = storage.Freight:WaitForChild("EquipCellFinish")
equip:FireServer("Aurora")
equip:FireServer("Crew")
waitFor(function() return preview.Buy.Interactable end, "free finish action is ready")
task.wait(0.5)
assert(player:GetAttribute("CellFinish") == nil, "server accepted a finish without ownership")
tap(preview.Buy)
waitFor(function() return player:GetAttribute("CellFinish") == "Signal" end, "server equips the free ending reward")
tap(preview.Aurora)
waitFor(function() return preview.Description.Text:lower():find("violet") or preview.Description.Text:find("Фиолетовая", 1, true) end,
	"open Aurora swatch before purchase")
assert(player:GetAttribute("CellFinish") == "Signal" and player:GetAttribute("Aurora") == false, "preview cannot equip the paid finish")
tap(preview.Standard)
waitFor(function() return preview.Buy.Interactable end, "standard style can be equipped")
tap(preview.Buy)
waitFor(function() return player:GetAttribute("CellFinish") == "Standard" end, "server equips the standard style")
tap(preview.Crew)
waitFor(function() return preview.Description.Text:find("07", 1, true) end, "Depot 07 preview")
assert(inside(preview.Crew) and preview.Description.TextFits and player:GetAttribute("CellFinish") == "Standard",
	"previewing an unowned kit must not equip it")
local sample = preview.Crew.Battery
assert(sample["Power Cell"]:FindFirstChild("Crew stripe")
	and sample:FindFirstChild("Depot 07 patch")
	and sample:FindFirstChild("Depot 07 signal ring"), "the kit preview needs all three items")
fixture:FireServer("crew")
waitFor(function()
	return player:GetAttribute("Crew") == true
		and (preview.Buy.Text == "Equip" or preview.Buy.Text == "Выбрать")
end, "owning the crew pass enables equip")
tap(preview.Buy)
waitFor(function() return player:GetAttribute("CellFinish") == "Crew"
	and player.Character:FindFirstChild("Depot 07 patch") end, "the server equips the kit and puts the patch on the avatar")
tap(preview.Standard)
waitFor(function() return preview.Buy.Interactable end, "standard is available after equipping the kit")
tap(preview.Buy)
waitFor(function() return player:GetAttribute("CellFinish") == "Standard"
	and not player.Character:FindFirstChild("Depot 07 patch") end, "changing finish removes the patch")
tap(preview.Close)
waitFor(function() return not preview.Visible and card.Visible and dock.Visible end, "close preview and restore HUD")
waitFor(function() return offer.Visible end, "locker available after closing")
tap(offer)
waitFor(function()
	return preview.Visible and preview.Standard.UIStroke.Transparency < 1 and not preview.Buy.Interactable
end, "reopening the locker selects the equipped finish")
tap(preview.Close)
state:SetAttribute("Map", "yard")
state:SetAttribute("TrainStatus", "warning")
waitFor(function() return card.Objective.Text == "TRAIN SOON" or card.Objective.Text == "СКОРО ПОЕЗД" end, "collapsed train warning")
assert(card.AbsoluteSize.Y <= 32 and card.Objective.TextFits, "rail warning enlarged HUD")
state:SetAttribute("Map", "depot")
state:SetAttribute("TrainStatus", "clear")
fixture:FireServer("role-preview")
local ability = gui:WaitForChild("RoleAbility")
waitFor(function() return ability.Visible and not invite.Visible end, "contextual mobile ability")
assert(inside(ability) and ability.AbsoluteSize.Y >= 44 and ability.TextFits, "ability button clipped")
assert(ability.Position == invite.Position and ability.Size == invite.Size, "ability must reuse social slot")
assert(not preview.Visible and not journal.Visible, "ability overlays a modal")
tap(ability)
task.wait(0.6)
assert(player:GetAttribute("AbilityReadyAt") == 0, "client carrying flag granted a server ability")
fixture:FireServer("role-reset")
waitFor(function() return not ability.Visible and invite.Visible end, "social button restored")
print("MOBILE HUD QA PASS", portrait and "portrait" or "short landscape", gui.AbsoluteSize)
fixture:FireServer("done")
