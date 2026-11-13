local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Freight")
local Config = require(shared:WaitForChild("Config"))
local Operations = require(shared:WaitForChild("Operations"))
local Dispatch = require(shared:WaitForChild("Dispatch"))
local PowerCell = require(shared:WaitForChild("PowerCell"))
local FriendInvite = require(shared:WaitForChild("FriendInvite"))
local state = shared:WaitForChild("Shift")
local russian = string.sub(string.lower(LocalizationService.RobloxLocaleId), 1, 2) == "ru"

local function t(en, ru)
	return russian and ru or en
end

local function localized(lines)
	return t(lines[1], lines[2])
end

local colors = {
	ink = Color3.fromRGB(13, 21, 32),
	slate = Color3.fromRGB(39, 53, 68),
	paper = Color3.fromRGB(239, 249, 255),
	muted = Color3.fromRGB(170, 192, 208),
	cyan = Color3.fromRGB(64, 232, 234),
	amber = Color3.fromRGB(255, 195, 80),
	red = Color3.fromRGB(255, 121, 117),
	aurora = Color3.fromRGB(215, 127, 255),
}

local function add(class, parent, props)
	local item = Instance.new(class)
	for name, value in props do
		item[name] = value
	end
	item.Parent = parent
	return item
end

local gui = add("ScreenGui", player:WaitForChild("PlayerGui"), {
	Name = "FreightHUD", ResetOnSpawn = false, DisplayOrder = 3, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
})
-- Start with the objective unobstructed and keep Roblox's chat toggle available.
task.spawn(function()
	for _ = 1, 10 do
		if pcall(StarterGui.SetCore, StarterGui, "ChatActive", false) then
			break
		end
		task.wait(0.25)
	end
end)
local card = add("Frame", gui, {
	Name = "ShiftCard", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.new(1, -16, 0, 108), BackgroundColor3 = colors.ink, BackgroundTransparency = 0.16, BorderSizePixel = 0,
})
local cardLimit = add("UISizeConstraint", card, {MaxSize = Vector2.new(320, 108)})
add("UICorner", card, {CornerRadius = UDim.new(0, 5)})
local cardStroke = add("UIStroke", card, {Color = colors.slate, Thickness = 1})
local pulse = add("Frame", card, {
	Name = "DeliveryPulse", Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -10, 0, 2),
	BackgroundColor3 = colors.cyan, BackgroundTransparency = 1, BorderSizePixel = 0,
})
local fade = TweenService:Create(pulse, TweenInfo.new(0.65, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
local previousDeliveries = player:GetAttribute("ShiftDeliveries") or 0
local handoffUntil = 0
local needsRecoveryGuide = false
player:GetAttributeChangedSignal("ShiftDeliveries"):Connect(function()
	local deliveries = player:GetAttribute("ShiftDeliveries") or 0
	if deliveries > previousDeliveries then
		if deliveries == 1 or needsRecoveryGuide then
			handoffUntil = os.clock() + 4
		end
		needsRecoveryGuide = false
		fade:Cancel()
		pulse.BackgroundTransparency = 0
		fade:Play()
	end
	previousDeliveries = deliveries
end)

local function label(parent, name, x, y, width, height, px, color, heavy)
	return add("TextLabel", parent, {
		Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = width and UDim2.fromOffset(width, height) or UDim2.new(1, -2 * x, 0, height),
		Font = heavy and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = px, TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "", AutoLocalize = false, TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local brand = label(card, "Brand", 10, 3, nil, 14, 10, colors.muted, true)
local objective = label(card, "Objective", 10, 20, nil, 22, 16, colors.paper, true)
objective.Size = UDim2.new(1, -79, 0, 22)
local timer = label(card, "Timer", 0, 20, 59, 22, 18, colors.cyan, true)
timer.AnchorPoint = Vector2.new(1, 0)
timer.TextXAlignment = Enum.TextXAlignment.Right
timer.Font = Enum.Font.RobotoMono

local rail = add("Frame", card, {
	Size = UDim2.new(1, -20, 0, 3), BackgroundTransparency = 1,
})
local segments = {}
for i = 1, Config.Target do
	segments[i] = add("Frame", rail, {
		Position = UDim2.fromScale((i - 1) / Config.Target, 0),
		Size = UDim2.new(1 / Config.Target, -4, 1, 0), BorderSizePixel = 0, BackgroundColor3 = colors.slate,
	})
end
local hint = label(card, "Hint", 10, 50, nil, 28, 12, colors.paper, true)
hint.TextWrapped = true
hint.TextTruncate = Enum.TextTruncate.None
local radio = label(card, "Radio", 10, 78, nil, 28, 12, colors.muted, false)
radio.TextWrapped = true
radio.TextTruncate = Enum.TextTruncate.None

local marker = add("BillboardGui", gui, {
	Name = "FirstDeliveryGuide", Size = UDim2.fromOffset(138, 30), StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
	AlwaysOnTop = true, MaxDistance = 90, Enabled = false,
})
local markerText = label(marker, "Waypoint", 0, 0, 138, 30, 14, colors.cyan, true)
markerText.TextXAlignment = Enum.TextXAlignment.Center
markerText.BackgroundColor3 = colors.ink
markerText.BackgroundTransparency = 0.14
add("UICorner", markerText, {CornerRadius = UDim.new(0, 5)})

local function dockButton(name, color)
	local button = add("TextButton", gui, {
		Name = name, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(130, 36),
		BackgroundColor3 = colors.ink, TextColor3 = color, TextSize = 13, Font = Enum.Font.GothamBold, AutoLocalize = false,
	})
	add("UICorner", button, {CornerRadius = UDim.new(0, 5)})
	add("UIStroke", button, {Color = colors.slate})
	return button
end

local journalButton = dockButton("EndingJournalButton", colors.cyan)
local invite = dockButton("InviteFriends", colors.amber)
local function crewChallengeOpen()
	local status = state:GetAttribute("BlackBoxStatus")
	return state:GetAttribute("Phase") == "live" and (status == "available" or status == "carried")
end
local function inviteLabel()
	return crewChallengeOpen() and t("Invite crew", "Позвать экипаж") or t("Invite friends", "Позвать друзей")
end
invite.Text = inviteLabel()
local openingInvite = false
invite.Activated:Connect(function()
	if openingInvite then
		return
	end
	openingInvite = true
	invite.Text = t("Checking…", "Проверяем…")
	local published = game.GameId > 0 and not RunService:IsStudio()
	local options
	if published and crewChallengeOpen() then
		options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = t("Bring a friend to recover the Black Box!", "Позови друга за чёрным ящиком!")
		local token = state:GetAttribute("CrewInviteToken")
		if token then
			options.LaunchData = FriendInvite.crewLaunch(token)
		end
	end
	local result = FriendInvite.open(SocialService, player, published, options)
	if result == "local" then
		invite.Text = t("Published game only", "После публикации")
	elseif result == "unavailable" then
		invite.Text = t("Unavailable", "Недоступно")
	else
		invite.Text = inviteLabel()
	end
	task.wait(3)
	invite.Text = inviteLabel()
	openingInvite = false
end)

local journalPanel = add("ScrollingFrame", gui, {
	Name = "EndingJournal", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0.92, 0, 0, 104),
	BackgroundColor3 = colors.ink, BorderSizePixel = 0, Visible = false, ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.fromOffset(0, 224),
})
local journalLimit = add("UISizeConstraint", journalPanel, {MaxSize = Vector2.new(346, 224)})
add("UICorner", journalPanel, {CornerRadius = UDim.new(0, 5)})
add("UIStroke", journalPanel, {Color = colors.slate})
local broadcastLine = label(journalPanel, "Broadcast", 12, 6, nil, 25, 14, colors.cyan, true)
local shelterLine = label(journalPanel, "Shelter", 12, 32, nil, 25, 14, colors.amber, true)
local journalStatus = label(journalPanel, "Status", 12, 58, nil, 38, 12, colors.muted, false)
journalStatus.TextWrapped = true
journalStatus.TextTruncate = Enum.TextTruncate.None
local archiveTitle = label(journalPanel, "ArchiveTitle", 12, 97, nil, 20, 13, colors.paper, true)
local westRecord = label(journalPanel, "WestRecord", 12, 117, nil, 39, 12, colors.cyan, false)
local eastRecord = label(journalPanel, "EastRecord", 12, 157, nil, 39, 12, colors.cyan, false)
local archiveReward = label(journalPanel, "ArchiveReward", 12, 198, nil, 22, 12, colors.amber, true)
local dispatchTitle = label(journalPanel, "DispatchTitle", 12, 0, nil, 20, 13, PowerCell.Dispatch, true)
local dispatchDetail = label(journalPanel, "DispatchDetail", 12, 0, nil, 42, 12, colors.paper, false)
dispatchDetail.TextWrapped = true
dispatchDetail.TextTruncate = Enum.TextTruncate.None
local clearRecord = label(journalPanel, "ClearRecord", 12, 0, nil, 34, 12, colors.cyan, true)
clearRecord.TextWrapped = true
clearRecord.TextTruncate = Enum.TextTruncate.None
local blackBoxRecord = label(journalPanel, "BlackBoxRecord", 12, 0, nil, 54, 12, colors.amber, true)
blackBoxRecord.TextWrapped = true
blackBoxRecord.TextTruncate = Enum.TextTruncate.None
local yardRecord = label(journalPanel, "YardRecord", 12, 0, nil, 54, 12, colors.amber, true)
yardRecord.TextWrapped = true
yardRecord.TextTruncate = Enum.TextTruncate.None
local function soundToggle(name, attribute, enabledText, disabledText)
	local button = add("TextButton", journalPanel, {
		Name = name, Size = UDim2.new(0.5, -18, 0, 44),
		BackgroundColor3 = colors.slate, TextColor3 = colors.paper,
		Font = Enum.Font.GothamBold, TextSize = 13, AutoLocalize = false,
	})
	add("UICorner", button, {CornerRadius = UDim.new(0, 5)})
	local function update()
		button.Text = SoundService:GetAttribute(attribute) and disabledText or enabledText
	end
	button.Activated:Connect(function()
		SoundService:SetAttribute(attribute, not SoundService:GetAttribute(attribute))
	end)
	SoundService:GetAttributeChangedSignal(attribute):Connect(update)
	update()
	return button
end

local musicToggle = soundToggle("MusicToggle", "FreightMusicMuted", t("Music: on", "Музыка: вкл"), t("Music: off", "Музыка: выкл"))
local effectsToggle = soundToggle("EffectsToggle", "FreightEffectsMuted", t("Effects: on", "Эффекты: вкл"), t("Effects: off", "Эффекты: выкл"))
local journalShell = add("Frame", gui, {
	Name = "MobileJournal", BackgroundColor3 = colors.ink, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0), Visible = false,
})
add("UICorner", journalShell, {CornerRadius = UDim.new(0, 5)})
add("UIStroke", journalShell, {Color = colors.slate})
local journalFooter = add("Frame", journalShell, {
	Name = "Actions", BackgroundTransparency = 1,
	Position = UDim2.new(0, 8, 1, -52), Size = UDim2.new(1, -16, 0, 44),
})
local closeJournal = add("TextButton", journalFooter, {
	Name = "Close", Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -44, 0, 0),
	BackgroundColor3 = colors.slate, TextColor3 = colors.paper,
	Text = "×", TextSize = 24, Font = Enum.Font.GothamBold, AutoLocalize = false,
})
add("UICorner", closeJournal, {CornerRadius = UDim.new(0, 5)})
local compact = false
local dockBottom = 40
for _, line in {westRecord, eastRecord} do
	line.TextWrapped = true
	line.TextTruncate = Enum.TextTruncate.None
end
local function toggleJournal()
	journalPanel.Visible = not journalPanel.Visible
	if journalPanel.Visible then
		journalPanel.CanvasPosition = state:GetAttribute("Phase") == "briefing" and Vector2.new(0, 10000) or Vector2.zero
	end
end
journalButton.Activated:Connect(toggleJournal)
closeJournal.Activated:Connect(toggleJournal)
UserInputService.InputBegan:Connect(function(input, handled)
	if not handled and input.KeyCode == Enum.KeyCode.J then
		toggleJournal()
	end
end)

local function drawGuide(phase, carrying, route, findNext)
	if phase ~= "live" or (not carrying and not findNext) then
		marker.Enabled = false
		marker.Adornee = nil
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local target, nearest
	if root then
		for _, part in CollectionService:GetTagged(carrying and "FreightDelivery" or "FreightPickup") do
			if part:IsDescendantOf(workspace) then
				local distance = (part.Position - root.Position).Magnitude
				if not nearest or distance < nearest then
					target, nearest = part, distance
				end
			end
		end
	end
	local passage
	if route and target and (root.Position.Z - Operations.DividerZ) * (target.Position.Z - Operations.DividerZ) < 0 then
		passage = CollectionService:GetTagged("FreightPassage")[1]
	end
	marker.Adornee = passage or target
	-- Let the native interaction prompt take over once the player reaches the marker.
	marker.Enabled = passage ~= nil or (nearest ~= nil and nearest > 8)
	markerText.TextColor3 = carrying and colors.amber or colors.cyan
	markerText.Text = passage and t("▼  PASSAGE", "▼  ПРОХОД")
		or carrying and t("▼  AIRLOCK", "▼  ШЛЮЗ") or t("▼  BATTERY", "▼  БАТАРЕЯ")
end

local nextObjectives = {
	bothEndings = {"Find both endings to unlock Mira's archive.", "Открой обе концовки, чтобы найти архив Миры."},
	broadcast = {"Next: send the recording from BROADCAST.", "Дальше: передай запись с консоли «Эфир»."},
	shelter = {"Next: power the SHELTER console.", "Дальше: запитай консоль «Укрытие»."},
	bothRecords = {"Next: win each special route to recover a recording.", "Дальше: найди записи в обеих особых сменах."},
	west = {"Next: recover Mira's West Bypass recording.", "Дальше: найди запись на западном обходе."},
	east = {"Next: recover Mira's East Service recording.", "Дальше: найди запись на восточной ветке."},
	complete = {"Archive complete. Gold battery casing unlocked.", "Архив собран. Золотой корпус батареи открыт."},
}

local function formatClearTime(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local progressionPanel = require(script.Parent.ProgressionPanel).mount(journalPanel, player, state, shared, colors, add, t)

local function drawJournal()
	local broadcast = player:GetAttribute("EndingBroadcast") == true
	local shelter = player:GetAttribute("EndingShelter") == true
	local count = (broadcast and 1 or 0) + (shelter and 1 or 0)
	local west = player:GetAttribute("ArchiveWest") == true
	local east = player:GetAttribute("ArchiveEast") == true
	local records = (west and 1 or 0) + (east and 1 or 0)
	local progress = count == 2 and (t("Archive", "Архив") .. "  " .. records .. "/2") or (t("Log", "Журнал") .. "  " .. count .. "/2")
	local phase = state:GetAttribute("Phase")
	local earned = player:GetAttribute("LastScrapAward") or 0
	if phase == "briefing" then progress = t("Prepare", "Сборы")
	elseif (phase == "won" or phase == "lost") and earned > 0 then progress = "+" .. earned .. " Scrap" end
	journalButton.Text = journalPanel.Visible and t("Close log", "Закрыть журнал") or progress
	broadcastLine.Text = (broadcast and "✓  " or "○  ") .. t("01   Evidence on air", "01   Запись в эфире")
	shelterLine.Text = (shelter and "✓  " or "○  ") .. t("02   Shelter powered", "02   Укрытие под светом")
	local status = player:GetAttribute("JournalStatus")
	if not status or status == "loading" then
		journalStatus.Text = t("Receiving your log…", "Загружаем журнал…")
	elseif status == "saving" then
		journalStatus.Text = t("Saving your log…", "Сохраняем журнал…")
	elseif status == "unavailable" then
		journalStatus.Text = t("Cloud unavailable. This log may be incomplete.", "Облако недоступно. Журнал может быть неполным.")
	elseif status == "local" then
		journalStatus.Text = t("Studio test · saved until server stops.", "Тест в Studio · до остановки сервера.")
	else
		journalStatus.Text = t("Pick up a battery or route power in a winning shift.", "Возьми батарею или направь энергию в победной смене.")
	end
	archiveTitle.Text = count == 2 and (t("MIRA'S ARCHIVE", "АРХИВ МИРЫ") .. "  " .. records .. "/2")
		or t("Archive opens after both endings.", "Архив откроется после двух концовок.")
	westRecord.Text = west and ("✓  " .. localized(Operations.Routes.west.record)) or t("○  Win West Bypass after delivering a cell.", "○  Сдай батарею и выиграй «Западный обход».")
	eastRecord.Text = east and ("✓  " .. localized(Operations.Routes.east.record)) or t("○  Win East Service after delivering a cell.", "○  Сдай батарею и выиграй «Восточную ветку».")
	archiveReward.Text = west and east and t("✓  Gold battery casing unlocked", "✓  Золотой корпус батареи открыт")
		or t("Both recordings unlock a gold casing.", "За две записи откроется золотой корпус.")
	westRecord.Visible, eastRecord.Visible, archiveReward.Visible = count == 2, count == 2, count == 2
	local contentEnd = count == 2 and (compact and 174 or 224) or (compact and 96 or 122)
	local week = state:GetAttribute("DispatchWeek")
	dispatchTitle.Position = UDim2.fromOffset(12, contentEnd)
	dispatchDetail.Position = UDim2.fromOffset(12, contentEnd + 19)
	local completed = player:GetAttribute("DispatchWeeks") or 0
	dispatchTitle.Text = completed >= Dispatch.RewardWeeks and t("WEEKLY CONTRACT · LIME TERMINAL", "КОНТРАКТ НЕДЕЛИ · ЛАЙМОВЫЙ КОНТАКТ")
		or string.format(t("WEEKLY CONTRACT · %d/%d", "КОНТРАКТ НЕДЕЛИ · %d/%d"), completed, Dispatch.RewardWeeks)
	if week ~= nil and player:GetAttribute("DispatchLastWeek") == week then
		dispatchDetail.Text = t("Completed. Next contract on Monday (UTC).", "Выполнено. Следующий контракт в понедельник по UTC.")
	elseif week ~= nil then
		dispatchDetail.Text = localized(Dispatch.Objectives[Dispatch.objective(week)])
	else
		dispatchDetail.Text = ""
	end
	clearRecord.Position = UDim2.fromOffset(12, contentEnd + 62)
	local best = player:GetAttribute("BestClearSeconds")
	clearRecord.Text = if best then t("Fastest shift  /  ", "Лучшая смена  /  ") .. formatClearTime(best)
		else t("Set a record: deliver a cell and finish with a chosen ending.", "Рекорд: сдай батарею и заверши смену с выбранной концовкой.")
	blackBoxRecord.Visible = count == 2 or player:GetAttribute("ArchiveBlackBox") == true
	blackBoxRecord.Position = UDim2.fromOffset(12, contentEnd + 101)
	if player:GetAttribute("ArchiveBlackBox") then
		local crewBest = player:GetAttribute("BestBlackBoxCrewSeconds")
		local crew = if crewBest then t("  /  CREW ", "  /  ЭКИПАЖ ") .. formatClearTime(crewBest)
			else ""
		blackBoxRecord.Text = t("BLACK BOX", "ЧЁРНЫЙ ЯЩИК") .. crew .. "\n"
			.. t("Mira: The shutdown order came from inside Depot 07.", "Мира: Приказ об отключении пришёл из самого Депо 07.")
	else
		blackBoxRecord.Text = t("BLACK BOX\nFind the red case in West Bypass.", "ЧЁРНЫЙ ЯЩИК\nНайди красный кейс на Западном обходе.")
	end
	local contentHeight = contentEnd + (blackBoxRecord.Visible and 160 or 102)
	yardRecord.Visible = player:GetAttribute("ArchiveYard") == true
	if yardRecord.Visible then
		yardRecord.Position = UDim2.fromOffset(12, contentHeight)
		yardRecord.Text = t("FREIGHT YARD\nMira: The relay key is on train 07. Its destination was erased.", "ГРУЗОВОЙ ДВОР\nМира: Ключ на составе 07. Его пункт назначения стёрли.")
		contentHeight += 60
	end
	contentHeight = progressionPanel.draw(contentHeight + 8)
	if compact then
		journalPanel.CanvasSize = UDim2.fromOffset(0, contentHeight)
	else
		musicToggle.Position = UDim2.new(0, 12, 0, contentHeight)
		effectsToggle.Position = UDim2.new(0.5, 6, 0, contentHeight)
		local height = contentHeight + 52
		journalPanel.CanvasSize = UDim2.fromOffset(0, height)
		journalPanel.Size = UDim2.new(0.92, 0, 0, math.clamp(gui.AbsoluteSize.Y - journalPanel.Position.Y.Offset - 8, 42, height))
	end
end

if russian then
	local labels = {
		["Take cell"] = "Взять", ["Power cell"] = "Батарея",
		["Deliver"] = "Сдать", ["Airlock"] = "Шлюз",
		["Activate"] = "Включить", ["Decoy beacon"] = "Маяк-приманка",
		["Send recording"] = "Передать запись", ["Power shelter"] = "Запитать укрытие", ["Route power"] = "Направить энергию",
	}
	ProximityPromptService.PromptShown:Connect(function(prompt)
		prompt.ActionText = labels[prompt.ActionText] or prompt.ActionText
		prompt.ObjectText = labels[prompt.ObjectText] or prompt.ObjectText
	end)
end

local shop = add("TextButton", gui, {
	Name = "AuroraLens", AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(240, 44), BackgroundColor3 = colors.ink, TextColor3 = colors.aurora,
	TextSize = 14, Font = Enum.Font.GothamBold, Text = t("BATTERY LOCKER", "ОФОРМЛЕНИЕ БАТАРЕИ"),
	AutoLocalize = false, Visible = false,
})
add("UICorner", shop, {CornerRadius = UDim.new(0, 8)})
add("UIStroke", shop, {Color = colors.aurora, Transparency = 0.45})
local preview = add("Frame", gui, {
	Name = "AuroraPreview", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0.92, 0, 0, 164),
	BackgroundColor3 = colors.ink, Visible = false,
})
add("UISizeConstraint", preview, {MaxSize = Vector2.new(326, 164)})
add("UICorner", preview, {CornerRadius = UDim.new(0, 8)})
add("UIStroke", preview, {Color = colors.aurora, Transparency = 0.45})
label(preview, "Title", 12, 7, nil, 19, 15, colors.aurora, true).Text = t("BATTERY LOCKER", "ОФОРМЛЕНИЕ БАТАРЕИ")
local finishDetail = label(preview, "Description", 12, 28, nil, 18, 12, colors.paper, false)
local equipFinish = shared:WaitForChild("EquipCellFinish")
local selectedFinish = "Signal"
local finishTiles = {}
local finishes = {"Standard", "Signal", "Aurora", "Crew"}
for index, finish in finishes do
	local color = PowerCell.Finishes[finish]
	local column = (index - 1) / #finishes
	local sample = add("TextButton", preview, {
		Name = finish, Position = UDim2.new(column, 12 - 18 * column, 0, 49),
		Size = UDim2.new(1 / #finishes, -10.5, 0, 56), BackgroundColor3 = colors.slate, BorderSizePixel = 0,
		Text = "", AutoLocalize = false,
	})
	add("UICorner", sample, {CornerRadius = UDim.new(0, 5)})
	finishTiles[finish] = add("UIStroke", sample, {Color = color, Transparency = 1})
	local viewport = add("ViewportFrame", sample, {
		Name = "Battery", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 1),
		Size = UDim2.fromOffset(56, 38), BackgroundTransparency = 1, Ambient = Color3.fromRGB(180, 180, 180),
	})
	PowerCell.build(viewport, CFrame.new(), color, finish)
	if finish == "Crew" then
		PowerCell.crewPatch(viewport, CFrame.new(1.05, 0.4, 0.85) * CFrame.Angles(0, math.pi, 0))
		PowerCell.crewRing(viewport, CFrame.new(0, -0.82, 0), 1.18)
	end
	viewport.CurrentCamera = add("Camera", viewport, {
		CFrame = CFrame.lookAt(Vector3.new(2.8, 1.9, 5), Vector3.new(0, 0.15, 0)),
		FieldOfView = finish == "Crew" and 36 or 26,
	})
	local style = label(sample, "Style", 0, 39, nil, 16, 11, color, true)
	style.Size = UDim2.new(1, 0, 0, 16)
	style.TextXAlignment = Enum.TextXAlignment.Center
	style.Text = ({Standard = t("Standard", "Стандарт"), Signal = t("Signal Amber", "Янтарный"),
		Aurora = "Aurora Lens", Crew = t("Depot 07", "Депо 07")})[finish]
	sample.Activated:Connect(function()
		selectedFinish = finish
	end)
end
local function previewButton(name, position, size, color)
	local button = add("TextButton", preview, {
		Name = name, Position = position, Size = size, BackgroundColor3 = colors.slate,
		Text = "", TextColor3 = color, TextSize = 14, Font = Enum.Font.GothamBold, AutoLocalize = false,
	})
	add("UICorner", button, {CornerRadius = UDim.new(0, 5)})
	return button
end
local closePreview = previewButton("Close", UDim2.fromOffset(12, 112), UDim2.new(0.4, -16, 0, 44), colors.paper)
closePreview.Text = t("Close", "Закрыть")
local buy = previewButton("Buy", UDim2.new(0.4, 4, 0, 112), UDim2.new(0.6, -16, 0, 44), colors.aurora)
closePreview.Activated:Connect(function()
	preview.Visible = false
end)

local detailsExpanded = false
local detailsToggle = add("TextButton", card, {
	Name = "ShiftDetails", Size = UDim2.new(1, 0, 0, 44), ZIndex = 2,
	BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false,
})
local detailsArrow = label(detailsToggle, "Chevron", 0, 1, 22, 22, 14, colors.muted, true)
detailsArrow.AnchorPoint = Vector2.new(1, 0)
detailsArrow.Position = UDim2.new(1, -4, 0, 1)
detailsArrow.TextXAlignment = Enum.TextXAlignment.Center
detailsArrow.ZIndex = 2
local previewLimit = preview:FindFirstChildOfClass("UISizeConstraint")

local function updatePanelVisibility()
	if journalPanel.Visible and preview.Visible then
		preview.Visible = false
	end
	card.Visible = not compact or not (journalPanel.Visible or preview.Visible)
	journalShell.Visible = compact and journalPanel.Visible
	journalButton.Visible = not (compact and (journalPanel.Visible or preview.Visible))
	invite.Visible = journalButton.Visible
	if compact and (journalPanel.Visible or preview.Visible) then
		shop.Visible = false
	end
end
journalPanel:GetPropertyChangedSignal("Visible"):Connect(updatePanelVisibility)
preview:GetPropertyChangedSignal("Visible"):Connect(updatePanelVisibility)

local function layout()
	compact = UserInputService.TouchEnabled or gui.AbsoluteSize.Y < 420
	local portrait = gui.AbsoluteSize.X < gui.AbsoluteSize.Y
	dockBottom = portrait and 136 or 48
	local height = compact and (detailsExpanded and 80 or 32) or 108
	local maxWidth = compact and not detailsExpanded and 188 or (compact and portrait and 300 or 320)
	card.Size = UDim2.new(1, -16, 0, height)
	cardLimit.MaxSize = Vector2.new(maxWidth, height)
	local top = compact and 0 or 6
	if not compact or not portrait then
		local topbar = GuiService:GetInsetArea(Enum.ScreenInsets.TopbarSafeInsets)
		local device = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
		local center = gui.AbsoluteSize.X / 2
		local halfWidth = math.min(maxWidth, gui.AbsoluteSize.X - 16) / 2
		if center - halfWidth >= topbar.Min.X + 8 and center + halfWidth <= topbar.Max.X - 8 then
			top = math.max(-36, device.Min.Y + 8, topbar.Min.Y + 8)
		end
	end
	card.Position = UDim2.new(0.5, 0, 0, top)
	brand.Visible = not compact
	detailsToggle.Visible = compact
	detailsArrow.Text = detailsExpanded and "⌃" or "⌄"
	hint.Visible = not compact or detailsExpanded
	radio.Visible = hint.Visible
	objective.Size = UDim2.new(1, compact and -94 or -79, 0, 22)
	objective.TextSize = compact and 13 or 16
	rail.Position = UDim2.fromOffset(10, compact and 23 or 44)
	hint.Position = UDim2.fromOffset(10, compact and 27 or 49)
	radio.Position = UDim2.fromOffset(10, compact and 53 or 77)
	hint.Size = UDim2.new(1, -20, 0, compact and 26 or 28)
	radio.Size = UDim2.new(1, -20, 0, compact and 26 or 28)
	hint.TextSize = compact and 11 or 12
	radio.TextSize = hint.TextSize
	objective.Position = UDim2.fromOffset(10, compact and 1 or 20)
	timer.Position = UDim2.new(1, compact and -26 or -10, 0, compact and 1 or 20)
	timer.TextSize = compact and 14 or 18
	local dockY = compact and UDim.new(1, -dockBottom) or UDim.new(0, top + height + 7)
	local buttonWidth = math.clamp(math.floor((gui.AbsoluteSize.X - 36) / 3), 44, portrait and 82 or 94)
	local spacing = buttonWidth + 6
	journalButton.Position = UDim2.new(UDim.new(0.5, compact and -spacing or -146), dockY)
	invite.Position = UDim2.new(UDim.new(0.5, compact and 0 or -8), dockY)
	journalButton.Size = UDim2.fromOffset(compact and buttonWidth or 130, compact and 44 or 36)
	invite.Size = journalButton.Size
	invite.TextSize = compact and 11 or 13
	invite.TextTruncate = compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
	local panelTop = top + height + 47
	local sideJournal = compact and not portrait and gui.AbsoluteSize.X >= 620
	journalShell.AnchorPoint = Vector2.new(sideJournal and 0 or 0.5, 0)
	journalShell.Position = sideJournal and UDim2.fromOffset(12, 8) or UDim2.new(0.5, 0, 0, 8)
	journalShell.Size = UDim2.fromOffset(math.min(gui.AbsoluteSize.X - 24, sideJournal and 292 or 346),
		math.min(gui.AbsoluteSize.Y - 24, portrait and 320 or 224))
	journalPanel.Parent = compact and journalShell or gui
	journalPanel.AnchorPoint = Vector2.new(compact and 0 or 0.5, 0)
	journalPanel.Position = compact and UDim2.fromOffset(0, 4) or UDim2.new(0.5, 0, 0, panelTop)
	journalPanel.BackgroundTransparency = compact and 1 or 0
	journalPanel.UIStroke.Enabled = not compact
	journalLimit.MaxSize = Vector2.new(346, compact and 320 or 224)
	if compact then
		journalPanel.Size = UDim2.new(1, 0, 1, -62)
	end
	musicToggle.Parent = compact and journalFooter or journalPanel
	effectsToggle.Parent = musicToggle.Parent
	musicToggle.Size = UDim2.new(0.5, compact and -28 or -18, 0, 44)
	effectsToggle.Size = musicToggle.Size
	if compact then
		musicToggle.Position = UDim2.fromOffset(0, 0)
		effectsToggle.Position = UDim2.new(0.5, -22, 0, 0)
	end
	broadcastLine.Position, broadcastLine.Size = UDim2.fromOffset(12, compact and 4 or 6), UDim2.new(1, -24, 0, compact and 20 or 25)
	shelterLine.Position, shelterLine.Size = UDim2.fromOffset(12, compact and 25 or 32), UDim2.new(1, -24, 0, compact and 20 or 25)
	journalStatus.Position, journalStatus.Size = UDim2.fromOffset(12, compact and 47 or 58), UDim2.new(1, -24, 0, compact and 26 or 38)
	archiveTitle.Position = UDim2.fromOffset(12, compact and 74 or 97)
	westRecord.Position, westRecord.Size = UDim2.fromOffset(12, compact and 93 or 117), UDim2.new(1, -24, 0, compact and 29 or 39)
	eastRecord.Position, eastRecord.Size = UDim2.fromOffset(12, compact and 122 or 157), UDim2.new(1, -24, 0, compact and 29 or 39)
	archiveReward.Position = UDim2.fromOffset(12, compact and 150 or 198)
	shop.Size = UDim2.fromOffset(compact and buttonWidth or 146, compact and 44 or 36)
	shop.Position = UDim2.new(UDim.new(0.5, compact and spacing or 138), dockY)
	shop.TextSize = compact and 11 or 14
	local sideLocker = compact and not portrait and gui.AbsoluteSize.X >= 620
	previewLimit.MaxSize = Vector2.new(sideLocker and 292 or 326, 164)
	preview.AnchorPoint = sideLocker and Vector2.new(1, 0.5) or Vector2.new(0.5, 0)
	preview.Position = if sideLocker then UDim2.new(1, -12, 0.5, 0)
		elseif compact and portrait then UDim2.new(0.5, 0, 1, -220)
		elseif compact then UDim2.new(0.5, 0, 0.5, -82)
		else UDim2.new(0.5, 0, 0, panelTop)
	updatePanelVisibility()
end
detailsToggle.Activated:Connect(function()
	detailsExpanded = not detailsExpanded
	layout()
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
layout()

local passOffers = {
	Aurora = {id = Config.CosmeticPassId},
	Crew = {id = Config.CrewPassId},
}
local lastCaught = player:GetAttribute("Caught") or 0
local caughtUntil = 0
local pendingPassId
local promptRetryAt = 0
local promptTimeoutSeconds = 15
local offered = false
local previewTracked = false
local commerce = Config.CosmeticPassId > 0 and shared:WaitForChild("Commerce")

local roleAction = require(script.Parent.RoleAction).mount(gui, player, state, shared, colors, add, t)

local function draw()
	invite.Visible = not (compact and (journalPanel.Visible or preview.Visible))
	if not openingInvite then
		invite.Text = inviteLabel()
	end
	local phase = state:GetAttribute("Phase")
	local count = state:GetAttribute("Delivered") or 0
	local target = state:GetAttribute("Target") or Config.Target
	local deliveries = player:GetAttribute("ShiftDeliveries") or 0
	if phase ~= "live" then
		handoffUntil, caughtUntil = 0, 0
		needsRecoveryGuide = false
	end
	local justDelivered = os.clock() < handoffUntil
	local serverTime = workspace:GetServerTimeNow()
	local remaining = math.max(0, math.ceil((state:GetAttribute("EndsAt") or 0) - serverTime))
	local decoyActive = (state:GetAttribute("DecoyUntil") or 0) > serverTime
	local carrying = player:GetAttribute("Carrying")
	local blackBox = player:GetAttribute("BlackBoxCarrying") == true
	local boxStatus = state:GetAttribute("BlackBoxStatus")
	local decoyReady = phase == "live" and state:GetAttribute("DecoyReady") == true and not carrying
	local tracked = phase == "live" and player:GetAttribute("Tracked") == true
	local aurora = player:GetAttribute("Aurora")
	local ending = state:GetAttribute("Ending")
	local route = Operations.Routes[state:GetAttribute("Operation")]
	local terminal = CollectionService:GetTagged("FreightDelivery")[1]
	local deliveryPrompt = terminal and terminal:FindFirstChildWhichIsA("ProximityPrompt", true)
	if deliveryPrompt then
		deliveryPrompt.Enabled = phase == "live" and carrying == true
	end
	local beacon = CollectionService:GetTagged("FreightDecoy")[1]
	local decoyPrompt = beacon and beacon:FindFirstChildWhichIsA("ProximityPrompt", true)
	if decoyPrompt then
		decoyPrompt.Enabled = decoyReady
	end
	drawGuide(phase, carrying, route, deliveries == 0 or needsRecoveryGuide or justDelivered)
	drawJournal()
	brand.Text = state:GetAttribute("Map") == "yard" and t("07 / FREIGHT YARD", "07 / ГРУЗОВОЙ ДВОР") or route and string.upper(localized(route.name)) or t("DEPOT 07   /   THE LAST SIGNAL", "ДЕПО 07   /   ПОСЛЕДНИЙ СИГНАЛ")
	timer.Text = phase == "waiting" and "—" or string.format("%d:%02d", remaining // 60, remaining % 60)
	timer.TextColor3 = (phase == "routing" or (phase == "live" and remaining <= 20)) and colors.amber or colors.cyan
	cardStroke.Color = tracked and colors.red or colors.slate
	objective.TextColor3 = compact and tracked and colors.red or colors.paper
	for i, segment in segments do
		segment.BackgroundColor3 = i <= count and colors.cyan or colors.slate
	end
	hint.TextColor3 = colors.paper
	if phase == "live" then
		objective.Text = if compact and tracked then t("RUN!", "БЕГИ!")
			else string.format(t("Power  %d/%d", "Питание  %d/%d"), count, target)
		if carrying and decoyActive then
			hint.TextColor3 = colors.cyan
			hint.Text = t("Sentinel diverted. Get to the airlock!", "Sentinel отвлечён. Беги в шлюз!")
		elseif blackBox then
			hint.TextColor3 = colors.red
			hint.Text = t("Black box secured. Run to the airlock!", "Ящик у тебя. Беги в шлюз!")
		elseif carrying then
			hint.TextColor3 = tracked and colors.red or colors.amber
			hint.Text = tracked and t("Sentinel has a lock. Run to the amber airlock!", "Sentinel засёк тебя. Беги в янтарный шлюз!")
				or t("Battery secured. Bring it to the airlock console.", "Батарея у тебя. Отнеси её к консоли шлюза.")
		elseif os.clock() < caughtUntil then
			hint.TextColor3 = colors.red
			hint.Text = t("Caught. Try a different lane.", "Дрон поймал тебя. Попробуй другой проход.")
		elseif decoyReady then
			hint.TextColor3 = colors.cyan
			hint.Text = t("Use the beacon to cover your teammate.", "Включи маяк, чтобы прикрыть напарника.")
		elseif justDelivered then
			hint.TextColor3 = colors.cyan
			hint.Text = string.format(t("Battery delivered. %d more to go.", "Батарея принята. Осталось: %d."), math.max(0, target - count))
		else
			hint.Text = t("Take a blue battery. Bring it back to the airlock.", "Возьми синюю батарею. Отнеси её обратно в шлюз.")
		end
		if boxStatus == "secured" then
			radio.Text = t("Mira: Black box recovered. Check the log.", "Мира: Ящик доставлен. Проверь журнал.")
		elseif blackBox then
			radio.Text = t("Mira: That signal is drawing Sentinel in!", "Мира: Сигнал ящика притягивает Sentinel!")
		elseif boxStatus == "available" then
			radio.Text = t("Mira: Beyond the west gate, look for a red case.", "Мира: За западными воротами ищи красный кейс.")
		elseif route then
			radio.Text = localized(count >= 3 and route.middle or route.start)
		elseif count >= 3 then
			radio.Text = t("Mira: I found the order. Someone cut the power on purpose.", "Мира: Нашла приказ. Питание отключили намеренно.")
		elseif count >= 1 then
			radio.Text = t("Mira: One line is back. The archive is waking up.", "Мира: Первая линия ожила. Архив включается.")
		else
			radio.Text = t("Mira: Someone killed the lights. Get a cell before the relay dies.", "Мира: Кто-то вырубил свет. Возьми батарею, пока реле живо.")
		end
	elseif phase == "routing" then
		objective.Text = compact and t("Choose route", "Выбери путь") or t("Route the power", "Куда подать ток?")
		hint.Text = t("Choose BROADCAST or SHELTER at the airlock.", "В шлюзе выбери консоль «Эфир» или «Укрытие».")
		radio.Text = t("Mira: Only one circuit. We can send the proof or light the shelter.", "Мира: Хватит на одну линию. Передадим запись или спасём укрытие.")
	elseif phase == "won" then
		local broadcast = ending == "broadcast"
		objective.Text = if broadcast then t("Signal sent", "Сигнал передан")
			elseif compact then t("Shelter lit", "Укрытие спасено")
			else t("Shelter powered", "Укрытие под светом")
		local nextObjective = Operations.nextObjective(player:GetAttribute("EndingBroadcast"), player:GetAttribute("EndingShelter"),
			player:GetAttribute("ArchiveWest"), player:GetAttribute("ArchiveEast"))
		hint.Text = localized(nextObjectives[nextObjective])
		if state:GetAttribute("RouteSource") == "automatic" then
			radio.Text = t("Mira: Time ran out. The relay powered the shelter.", "Мира: Время вышло. Реле запитало укрытие.")
		else
			radio.Text = broadcast and t("Mira: The city heard us. They have the recording.", "Мира: Город нас услышал. Запись у них.")
				or t("Mira: The shelter is lit. Everyone inside is safe.", "Мира: В укрытии свет. Люди в безопасности.")
		end
		if player:GetAttribute("ArchiveUnlockedThisShift") then
			radio.Text = t("New recording recovered. Open the log.", "Новая запись найдена. Открой журнал.")
		end
		if player:GetAttribute("DispatchCompletedThisShift") then
			hint.Text = t("Weekly contract completed. See the log.", "Контракт недели выполнен. Открой журнал.")
		elseif nextObjective == "complete" then
			local week = state:GetAttribute("DispatchWeek")
			if week ~= nil and player:GetAttribute("DispatchLastWeek") ~= week then
				hint.Text = localized(Dispatch.Objectives[Dispatch.objective(week)])
			end
		end
		if not compact then
			brand.Text = string.format(t("SHIFT COMPLETE   /   YOUR DELIVERIES %d", "СМЕНА ЗАВЕРШЕНА   /   ТВОИ ДОСТАВКИ %d"), deliveries)
		end
		local best = player:GetAttribute("BestClearSeconds")
		if player:GetAttribute("NewBestThisShift") and best then
			local announcement = t("New personal best  /  ", "Новый личный рекорд  /  ") .. formatClearTime(best)
			if not compact then
				brand.Text = announcement
			elseif not player:GetAttribute("DispatchCompletedThisShift") then
				hint.Text = announcement
			end
		end
	elseif phase == "briefing" then
		objective.Text = compact and t("Next shift", "Подготовка") or t("Prepare your crew", "Подготовка экипажа")
		hint.Text = t("Open the log: choose your role, Heat and upgrades.", "Открой журнал: выбери роль, Тревогу и улучшения.")
		radio.Text = string.format(t("Scrap +%d · balance %d", "Scrap +%d · всего %d"), player:GetAttribute("LastScrapAward") or 0, player:GetAttribute("Scrap") or 0)
	elseif phase == "lost" then
		objective.Text = t("Signal lost", "Сигнал потерян")
		hint.Text = string.format(t("Crew charge %d/%d. You delivered %d.", "Заряд команды %d/%d. Твои доставки: %d."), count, target, deliveries)
		radio.Text = deliveries == 0
			and t("Next shift starts automatically. Follow the battery marker.", "Смена начнётся сама. Ищи метку батареи.")
			or t("Next shift starts automatically. Try another lane.", "Смена начнётся сама. Попробуй другой проход.")
	else
		objective.Text = t("Night shift", "Ночная смена")
		hint.Text = t("Restore the relay. Start with a blue cell.", "Верни связь. Начни с синей батареи.")
		radio.Text = t("Mira: I’m at dispatch. Follow the amber lights home.", "Мира: Я в диспетчерской. Янтарный свет ведёт обратно.")
	end
	if phase == "live" and state:GetAttribute("SentinelVariant") == "Tracker" then
		if tracked then
			if compact then objective.Text = t("HIDE!", "ПРЯЧЬСЯ!") end
			hint.Text = t("Tracker sees the cell. Get behind solid cover.", "Следопыт видит груз. Скройся за контейнером.")
		end
		radio.Text = state:GetAttribute("SentinelMode") == "search"
			and t("Mira: Tracker lost you. Stay behind cover.", "Мира: Следопыт потерял тебя. Оставайся за укрытием.")
			or t("Mira: Tracker follows cargo light. Break its line of sight.", "Мира: Следопыт видит свет груза. Скройся за контейнером.")
	end
	if phase == "live" and state:GetAttribute("Map") == "yard" then
		local train = state:GetAttribute("TrainStatus")
		radio.Text = train == "warning" and t("Mira: Train approaching. Stay behind the red signals!", "Мира: Приближается состав. Жди за красными сигналами!")
			or train == "passing" and t("Train crossing. Wait for cyan signals.", "Идёт состав. Дождись бирюзового сигнала.")
			or (state:GetAttribute("SentinelVariant") == "Tracker" and radio.Text or t("Mira: Crossing clear. The far cells are beyond the tracks.", "Мира: Переезд свободен. Дальние батареи за путями."))
		if compact and train ~= "clear" then
			objective.Text = train == "warning" and t("TRAIN SOON", "СКОРО ПОЕЗД") or t("WAIT", "ПОДОЖДИ")
			objective.TextColor3 = colors.amber
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local safeToBrowse = phase == "won" or phase == "lost" or phase == "briefing"
		or (phase == "live" and root ~= nil and root.Position.Z >= Config.AirlockSafeZ)
	if carrying or not safeToBrowse or journalPanel.Visible then
		preview.Visible = false
	end
	local wonBefore = (player:GetAttribute("Wins") or 0) > 0
		or player:GetAttribute("EndingBroadcast") or player:GetAttribute("EndingShelter")
	shop.Visible = safeToBrowse and not carrying and (wonBefore or aurora == true or player:GetAttribute("Crew") == true)
		and not journalPanel.Visible and not preview.Visible
	shop.Text = phase == "won" and player:GetAttribute("SignalUnlockedThisShift")
		and (compact and t("NEW STYLE", "НОВЫЙ СТИЛЬ") or t("NEW FINISH", "НОВЫЙ СТИЛЬ"))
		or (compact and t("LOCKER", "СТИЛИ") or t("BATTERY LOCKER", "ОФОРМЛЕНИЕ"))
	if (shop.Visible or preview.Visible) and commerce and passOffers.Aurora.price and aurora == false and wonBefore and not offered then
		offered = true
		commerce:FireServer(1)
	end
	if preview.Visible and selectedFinish == "Aurora" and offered and not previewTracked then
		previewTracked = true
		commerce:FireServer(2)
	end
	for finish, stroke in finishTiles do
		stroke.Transparency = finish == selectedFinish and 0.15 or 1
	end
	local equipped = PowerCell.equipped(player) == selectedFinish
	local owned = PowerCell.canEquip(player, selectedFinish)
	local offer = passOffers[selectedFinish]
	local ownership = offer and player:GetAttribute(selectedFinish)
	local forSale = offer and ownership == false and offer.price ~= nil
	local waitingForPrompt = os.clock() < promptRetryAt
	buy.Interactable = (owned and not equipped) or (forSale and not waitingForPrompt)
	buy.TextColor3 = buy.Interactable and PowerCell.Finishes[selectedFinish] or colors.paper
	if selectedFinish == "Aurora" then
		finishDetail.Text = t("Violet battery and delivery pulse", "Фиолетовая батарея и эффект сдачи")
	elseif selectedFinish == "Crew" then
		finishDetail.Text = t("Striped case, 07 patch and signal ring", "Корпус, нашивка 07 и сигнальное кольцо")
	elseif selectedFinish == "Signal" then
		finishDetail.Text = t("Reward for your first ending", "Награда за первую концовку")
	else
		finishDetail.Text = t("Standard depot battery and pulse", "Стандартная батарея и эффект сдачи")
	end
	buy.Text = if equipped then t("Equipped", "Выбрано")
		elseif owned then t("Equip", "Выбрать")
		elseif selectedFinish == "Signal" then t("Finish a shift", "Заверши смену")
		elseif offer and offer.id > 0 and ownership == nil then t("Checking…", "Проверяем…")
		elseif forSale and waitingForPrompt then t("Opening Roblox…", "Открываем Roblox…")
		elseif forSale then string.format(t("Buy · %d R$", "Купить · %d R$"), offer.price)
		else t("Not for sale", "Не продаётся")
end

shop.Activated:Connect(function()
	if shop.Visible then
		selectedFinish = if not player:GetAttribute("PreferredCellFinish") and PowerCell.canEquip(player, "Signal")
			then "Signal" else PowerCell.equipped(player)
		preview.Visible = true
		shop.Visible = false
	end
end)
buy.Activated:Connect(function()
	if not preview.Visible or player:GetAttribute("Carrying") then
		return
	end
	if PowerCell.canEquip(player, selectedFinish) then
		equipFinish:FireServer(selectedFinish)
		return
	end
	local finish = selectedFinish
	local offer = passOffers[finish]
	if not offer or not offer.price or os.clock() < promptRetryAt or player:GetAttribute(finish) ~= false then
		return
	end
	-- Roblox may never report completion if it cannot display the prompt.
	pendingPassId = offer.id
	promptRetryAt = os.clock() + promptTimeoutSeconds
	local ok = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, offer.id)
	if not ok then
		pendingPassId = nil
		promptRetryAt = 0
	elseif finish == "Aurora" and commerce then
		if offered and not previewTracked then
			previewTracked = true
			commerce:FireServer(2)
		end
		commerce:FireServer(3)
	end
end)

for _, offer in passOffers do
	if offer.id <= 0 then continue end
	task.spawn(function()
		for attempt = 1, 3 do
			local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, offer.id, Enum.InfoType.GamePass)
			if ok then
				if info and info.IsForSale == true and type(info.PriceInRobux) == "number" and info.PriceInRobux > 0 then
					offer.price = info.PriceInRobux
				end
				break
			end
			task.wait(attempt)
		end
	end)
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(buyer, passId)
	if buyer == player and passId == pendingPassId then
		pendingPassId = nil
		promptRetryAt = 0
	end
end)

player:GetAttributeChangedSignal("Caught"):Connect(function()
	local count = player:GetAttribute("Caught") or 0
	if count > lastCaught then
		caughtUntil = os.clock() + 3.5
		handoffUntil = 0
		needsRecoveryGuide = true
	end
	lastCaught = count
end)

while gui.Parent do
	draw()
	roleAction.draw(compact, invite, journalPanel.Visible or preview.Visible)
	task.wait(0.2)
end
