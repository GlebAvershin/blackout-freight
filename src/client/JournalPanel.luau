local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local JournalPanel = {}

local function formatClearTime(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

JournalPanel.formatClearTime = formatClearTime

function JournalPanel.mount(gui, journalButton, player, state, shared, colors, add, label, t)
	local Operations = require(shared:WaitForChild("Operations"))
	local Dispatch = require(shared:WaitForChild("Dispatch"))
	local PowerCell = require(shared:WaitForChild("PowerCell"))
	local function localized(lines)
		return t(lines[1], lines[2])
	end

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
	local function settingToggle(owner, name, attribute, enabledText, disabledText)
		local button = add("TextButton", journalPanel, {
			Name = name, Size = UDim2.new(0.5, -18, 0, 44),
			BackgroundColor3 = colors.slate, TextColor3 = colors.paper,
			Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true, AutoLocalize = false,
		})
		add("UICorner", button, {CornerRadius = UDim.new(0, 5)})
		local function update()
			button.Text = owner:GetAttribute(attribute) and disabledText or enabledText
		end
		button.Activated:Connect(function()
			owner:SetAttribute(attribute, not owner:GetAttribute(attribute))
		end)
		owner:GetAttributeChangedSignal(attribute):Connect(update)
		update()
		return button
	end

	local musicToggle = settingToggle(SoundService, "MusicToggle", "FreightMusicMuted", t("Music: on", "Музыка: вкл"), t("Music: off", "Музыка: выкл"))
	local effectsToggle = settingToggle(SoundService, "EffectsToggle", "FreightEffectsMuted", t("Effects: on", "Эффекты: вкл"), t("Effects: off", "Эффекты: выкл"))
	local config = require(shared.Config)
	local lightsToggle = config.SectorBlackoutEnabled and settingToggle(player, "BlackoutTransitionToggle", "FreightSteadyLights",
		t("Light fade: on", "Затемнение: плавно"), t("Light fade: off", "Затемнение: сразу"))
	local pingsToggle = config.CrewPingsEnabled and settingToggle(player, "CrewPingToggle", "FreightMuteCrewPings",
		t("Crew pings: on", "Метки команды: вкл"), t("Crew pings: off", "Метки команды: выкл"))
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
	for _, line in {westRecord, eastRecord} do
		line.TextWrapped = true
		line.TextTruncate = Enum.TextTruncate.None
	end
	local function toggleJournal()
		journalPanel.Visible = not journalPanel.Visible
		if journalPanel.Visible then
			local section = if (player:GetAttribute("LastSeasonUnlocked") or 0)>0 and (player:GetAttribute("LastRankUnlocked") or 0)==0 then journalPanel:FindFirstChild("Season")
				elseif state:GetAttribute("Phase") == "briefing" then journalPanel:FindFirstChild("Workshop") else nil
			journalPanel.CanvasPosition = section and Vector2.new(0,section.Position.Y.Offset) or Vector2.zero
		end
	end
	journalButton.Activated:Connect(toggleJournal)
	closeJournal.Activated:Connect(toggleJournal)
	UserInputService.InputBegan:Connect(function(input, handled)
		if not handled and input.KeyCode == Enum.KeyCode.J then
			toggleJournal()
		end
	end)

	local progressionPanel = require(script.Parent.ProgressionPanel).mount(journalPanel, player, state, shared, colors, add, t)
	local seasonPanel = require(script.Parent.SeasonPanel).mount(journalPanel, player, shared, colors, add, t)

	local function draw(compact)
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
		local unlockedRank = player:GetAttribute("LastRankUnlocked") or 0
		if (player:GetAttribute("LastSeasonUnlocked") or 0)>0 and (phase=="won" or phase=="lost" or phase=="briefing") then
			progress=t("New recording!", "Новая запись!")
		end
		if unlockedRank > 0 and (phase == "won" or phase == "lost" or phase == "briefing") then
			progress = t("Rank ", "Ранг ") .. unlockedRank .. "!"
		end
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
		contentHeight = seasonPanel.draw(contentHeight + 8)
		if lightsToggle then lightsToggle.Position = UDim2.fromOffset(12, contentHeight) end
		if pingsToggle then pingsToggle.Position = UDim2.new(0.5, 6, 0, contentHeight) end
		if lightsToggle or pingsToggle then contentHeight += 52 end
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

	local function layout(compact, portrait, panelTop)
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
	end

	return {panel = journalPanel, shell = journalShell, draw = draw, layout = layout}
end

return JournalPanel
