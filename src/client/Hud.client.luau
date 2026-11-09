local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local SocialService = game:GetService("SocialService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Freight")
local Config = require(shared:WaitForChild("Config"))
local Operations = require(shared:WaitForChild("Operations"))
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
local card = add("Frame", gui, {
	Name = "ShiftCard", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0.94, 0, 0, 146), BackgroundColor3 = colors.ink, BackgroundTransparency = 0.07, BorderSizePixel = 0,
})
local cardLimit = add("UISizeConstraint", card, {MaxSize = Vector2.new(402, 146)})
add("UICorner", card, {CornerRadius = UDim.new(0, 5)})
add("UIStroke", card, {Color = colors.slate, Thickness = 1})

local function label(parent, name, x, y, width, height, px, color, heavy)
	return add("TextLabel", parent, {
		Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = width and UDim2.fromOffset(width, height) or UDim2.new(1, -2 * x, 0, height),
		Font = heavy and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = px, TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "", AutoLocalize = false, TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local brand = label(card, "Brand", 14, 7, nil, 16, 11, colors.muted, true)
local objective = label(card, "Objective", 14, 26, nil, 29, 20, colors.paper, true)
objective.Size = UDim2.new(1, -105, 0, 29)
local timer = label(card, "Timer", 0, 26, 83, 29, 24, colors.cyan, true)
timer.AnchorPoint = Vector2.new(1, 0)
timer.Position = UDim2.new(1, -14, 0, 26)
timer.TextXAlignment = Enum.TextXAlignment.Right
timer.Font = Enum.Font.RobotoMono

local rail = add("Frame", card, {
	Position = UDim2.fromOffset(14, 59), Size = UDim2.new(1, -28, 0, 5), BackgroundTransparency = 1,
})
local segments = {}
for i = 1, Config.Target do
	segments[i] = add("Frame", rail, {
		Position = UDim2.fromScale((i - 1) / Config.Target, 0),
		Size = UDim2.new(1 / Config.Target, -4, 1, 0), BorderSizePixel = 0, BackgroundColor3 = colors.slate,
	})
end
local hint = label(card, "Hint", 14, 70, nil, 28, 13, colors.paper, true)
hint.TextWrapped = true
hint.TextTruncate = Enum.TextTruncate.None
local radio = label(card, "Radio", 14, 103, nil, 33, 13, colors.muted, false)
radio.TextWrapped = true
radio.TextTruncate = Enum.TextTruncate.None
local divider = add("Frame", card, {
	Position = UDim2.fromOffset(14, 100), Size = UDim2.new(1, -28, 0, 1), BackgroundColor3 = colors.slate, BorderSizePixel = 0,
})

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
local inviteLabel = t("Invite friends", "Позвать друзей")
invite.Text = inviteLabel
local openingInvite = false
invite.Activated:Connect(function()
	if openingInvite then
		return
	end
	openingInvite = true
	invite.Text = t("Checking…", "Проверяем…")
	local result = FriendInvite.open(SocialService, player, game.GameId > 0 and not RunService:IsStudio())
	if result == "local" then
		invite.Text = t("Published game only", "После публикации")
	elseif result == "unavailable" then
		invite.Text = t("Unavailable", "Недоступно")
	else
		invite.Text = inviteLabel
	end
	task.wait(3)
	invite.Text = inviteLabel
	openingInvite = false
end)

local journalPanel = add("ScrollingFrame", gui, {
	Name = "EndingJournal", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0.92, 0, 0, 104),
	BackgroundColor3 = colors.ink, BorderSizePixel = 0, Visible = false, ScrollBarThickness = 4,
	ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.fromOffset(0, 224),
})
add("UISizeConstraint", journalPanel, {MaxSize = Vector2.new(346, 224)})
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
for _, line in {westRecord, eastRecord} do
	line.TextWrapped = true
	line.TextTruncate = Enum.TextTruncate.None
end
journalButton.Activated:Connect(function()
	journalPanel.Visible = not journalPanel.Visible
	if journalPanel.Visible then
		journalPanel.CanvasPosition = Vector2.zero
	end
end)

local function drawGuide(phase, carrying, route)
	if phase ~= "live" or player:GetAttribute("FirstDelivery") then
		marker.Enabled = false
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

local function drawJournal()
	local broadcast = player:GetAttribute("EndingBroadcast") == true
	local shelter = player:GetAttribute("EndingShelter") == true
	local count = (broadcast and 1 or 0) + (shelter and 1 or 0)
	local west = player:GetAttribute("ArchiveWest") == true
	local east = player:GetAttribute("ArchiveEast") == true
	local records = (west and 1 or 0) + (east and 1 or 0)
	local progress = count == 2 and (t("Archive", "Архив") .. "  " .. records .. "/2") or (t("Log", "Журнал") .. "  " .. count .. "/2")
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
	local top = journalPanel.Position.Y.Offset
	local height = count == 2 and 224 or 122
	journalPanel.CanvasSize = UDim2.fromOffset(0, height)
	journalPanel.Size = UDim2.new(0.92, 0, 0, math.clamp(gui.AbsoluteSize.Y - top - 8, 42, height))
end

if russian then
	local labels = {
		["Take cell"] = "Взять", ["Power cell"] = "Батарея",
		["Deliver"] = "Сдать", ["Airlock"] = "Шлюз",
		["Send recording"] = "Передать запись", ["Power shelter"] = "Запитать укрытие", ["Route power"] = "Направить энергию",
	}
	ProximityPromptService.PromptShown:Connect(function(prompt)
		prompt.ActionText = labels[prompt.ActionText] or prompt.ActionText
		prompt.ObjectText = labels[prompt.ObjectText] or prompt.ObjectText
	end)
end

local shop = add("TextButton", gui, {
	Name = "AuroraLens", Position = UDim2.new(0.5, 0, 0, 156), AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(240, 43), BackgroundColor3 = colors.ink, TextColor3 = colors.aurora,
	TextSize = 14, Font = Enum.Font.GothamBold, Text = "", AutoLocalize = false, Visible = false,
})
add("UICorner", shop, {CornerRadius = UDim.new(0, 8)})
add("UIStroke", shop, {Color = colors.aurora, Transparency = 0.45})
local function layout()
	local compact = gui.AbsoluteSize.Y < 420
	local height = compact and 112 or 146
	card.Size = UDim2.new(0.94, 0, 0, height)
	cardLimit.MaxSize = Vector2.new(compact and 374 or 402, height)
	brand.Visible = not compact
	objective.Position = UDim2.fromOffset(14, compact and 6 or 26)
	timer.Position = UDim2.new(1, -14, 0, compact and 6 or 26)
	rail.Position = UDim2.fromOffset(14, compact and 37 or 59)
	hint.Position = UDim2.fromOffset(14, compact and 43 or 70)
	divider.Position = UDim2.fromOffset(14, compact and 72 or 100)
	radio.Position = UDim2.fromOffset(14, compact and 74 or 103)
	journalButton.Position = UDim2.new(0.5, -69, 0, height + 13)
	invite.Position = UDim2.new(0.5, 69, 0, height + 13)
	journalPanel.Position = UDim2.new(0.5, 0, 0, height + 53)
	shop.Position = journalPanel.Position
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

local available = false
local price
local lastCaught = player:GetAttribute("Caught") or 0
local caughtUntil = 0
local pending = false

local function draw()
	local phase = state:GetAttribute("Phase")
	local count = state:GetAttribute("Delivered") or 0
	local target = state:GetAttribute("Target") or Config.Target
	local winCount = player:GetAttribute("Wins") or 0
	local remaining = math.max(0, math.ceil((state:GetAttribute("EndsAt") or 0) - workspace:GetServerTimeNow()))
	local carrying = player:GetAttribute("Carrying")
	local aurora = player:GetAttribute("Aurora")
	local ending = state:GetAttribute("Ending")
	local route = Operations.Routes[state:GetAttribute("Operation")]
	local terminal = CollectionService:GetTagged("FreightDelivery")[1]
	local deliveryPrompt = terminal and terminal:FindFirstChildWhichIsA("ProximityPrompt", true)
	if deliveryPrompt then
		deliveryPrompt.Enabled = phase == "live" and carrying == true
	end
	drawGuide(phase, carrying, route)
	drawJournal()
	brand.Text = route and string.upper(localized(route.name)) or t("DEPOT 07   /   THE LAST SIGNAL", "ДЕПО 07   /   ПОСЛЕДНИЙ СИГНАЛ")
	timer.Text = phase == "waiting" and "—" or string.format("%d:%02d", remaining // 60, remaining % 60)
	timer.TextColor3 = (phase == "routing" or (phase == "live" and remaining <= 20)) and colors.amber or colors.cyan
	for i, segment in segments do
		segment.BackgroundColor3 = i <= count and colors.cyan or colors.slate
	end
	hint.TextColor3 = colors.paper
	if phase == "live" then
		objective.Text = string.format(t("Power  %d/%d", "Питание  %d/%d"), count, target)
		if carrying then
			hint.TextColor3 = aurora and colors.aurora or colors.amber
			hint.Text = t("The drone tracks the battery. Run to the amber airlock!", "Дрон засёк батарею. Беги в янтарный шлюз!")
		elseif os.clock() < caughtUntil then
			hint.TextColor3 = colors.red
			hint.Text = t("Caught. The cell is back in its socket.", "Дрон поймал тебя. Батарея на постаменте.")
		else
			hint.Text = t("Take a blue battery. Bring it back to the airlock.", "Возьми синюю батарею. Отнеси её обратно в шлюз.")
		end
		if route then
			radio.Text = localized(count >= 3 and route.middle or route.start)
		elseif count >= 3 then
			radio.Text = t("Mira: I found the order. Someone cut the power on purpose.", "Мира: Нашла приказ. Питание отключили намеренно.")
		elseif count >= 1 then
			radio.Text = t("Mira: One line is back. The archive is waking up.", "Мира: Первая линия ожила. Архив включается.")
		else
			radio.Text = t("Mira: The drone only chases people carrying a battery.", "Мира: Дрон преследует только тех, кто несёт батарею.")
		end
	elseif phase == "routing" then
		objective.Text = t("Route the power", "Куда подать ток?")
		hint.Text = t("At the airlock: broadcast left, shelter right.", "В шлюзе: эфир слева, укрытие справа.")
		radio.Text = t("Mira: Only one circuit. We can send the proof or light the shelter.", "Мира: Хватит на одну линию. Передадим запись или спасём укрытие.")
	elseif phase == "won" then
		local broadcast = ending == "broadcast"
		objective.Text = broadcast and t("Signal sent", "Сигнал передан") or t("Shelter powered", "Укрытие под светом")
		hint.Text = string.format(t("Shifts cleared this session: %d", "Смен завершено за сеанс: %d"), winCount)
		if state:GetAttribute("RouteSource") == "automatic" then
			radio.Text = t("Mira: Time ran out. The relay powered the shelter.", "Мира: Время вышло. Реле запитало укрытие.")
		else
			radio.Text = broadcast and t("Mira: The city heard us. They have the recording.", "Мира: Город нас услышал. Запись у них.")
				or t("Mira: The shelter is lit. Everyone inside is safe.", "Мира: В укрытии свет. Люди в безопасности.")
		end
		if player:GetAttribute("ArchiveUnlockedThisShift") then
			hint.Text = t("New recording recovered. Open the log.", "Новая запись найдена. Открой журнал.")
		end
	elseif phase == "lost" then
		objective.Text = t("Signal lost", "Сигнал потерян")
		hint.Text = t("The relay ran out of time. Another shift is starting.", "Время вышло. Скоро новая смена.")
		radio.Text = t("Mira: Depot 07 to city control… do you read?", "Мира: Депо 07 вызывает город… Кто-нибудь слышит?")
	else
		objective.Text = t("Night shift", "Ночная смена")
		hint.Text = t("Restore the relay. Start with a blue cell.", "Верни связь. Начни с синей батареи.")
		radio.Text = t("Mira: I’m at dispatch. Follow the amber lights home.", "Мира: Я в диспетчерской. Янтарный свет ведёт обратно.")
	end
	shop.Visible = (phase == "won" or phase == "lost") and available and winCount > 0 and not aurora and not journalPanel.Visible
	shop.Text = pending and t("Opening Roblox…", "Открываем Roblox…") or (price and ("AURORA LENS  /  " .. price .. " R$") or "AURORA LENS")
end

if Config.CosmeticPassId > 0 then
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, Config.CosmeticPassId, Enum.InfoType.GamePass)
		if ok and info.IsForSale then
			price = info.PriceInRobux
			available = true
		end
	end)
	shop.Activated:Connect(function()
		if pending or not shop.Visible then
			return
		end
		pending = true
		local ok = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, Config.CosmeticPassId)
		if not ok then
			pending = false
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(buyer, passId)
		if buyer == player and passId == Config.CosmeticPassId then
			pending = false
		end
	end)
end

player:GetAttributeChangedSignal("Caught"):Connect(function()
	local count = player:GetAttribute("Caught") or 0
	if count > lastCaught then
		caughtUntil = os.clock() + 3.5
	end
	lastCaught = count
end)

while gui.Parent do
	draw()
	task.wait(0.2)
end
