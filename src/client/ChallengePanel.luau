local Panel = {}

function Panel.mount(parent, player, state, shared, colors, add, label, t)
	local challenges = require(shared.CrewChallenges)
	local config = require(shared.Config)
	local roles = require(shared.Roles)
	local remote = shared:WaitForChild("Preparation")
	local frame = add("Frame", parent, {
		Name = "CrewChallenges", Size = UDim2.new(1, -24, 0, 0), BackgroundTransparency = 1,
	})
	local function line(name, y, height, color)
		local item = label(frame, name, 0, y, nil, height, 12, color, true)
		item.TextWrapped = true
		item.TextTruncate = Enum.TextTruncate.None
		return item
	end
	local heading = line("Heading", 0, 24, colors.amber)
	heading.Text = t("DAILY SHIFT", "ЕЖЕДНЕВНАЯ СМЕНА")
	local detail = line("DailyRules", 24, 44, colors.muted)
	detail.Text = t("Depot 07 · Heat 1 · blackout. Everyone votes and delivers. Workshop upgrades are off.",
		"Депо 07 · Тревога 1 · блэкаут. Каждый голосует и сдаёт батарею. Улучшения мастерской отключены.")
	local function button(name, position, size)
		local item = add("TextButton", frame, {
			Name = name, Position = position, Size = size, BackgroundColor3 = colors.slate,
			TextColor3 = colors.paper, Font = Enum.Font.GothamBold, TextSize = 12,
			TextWrapped = true, AutoLocalize = false,
		})
		add("UICorner", item, {CornerRadius = UDim.new(0, 5)})
		return item
	end
	local vote = button("DailyVote", UDim2.fromOffset(0, 72), UDim2.new(1, 0, 0, 44))
	vote.Activated:Connect(function() remote:FireServer("daily", player:GetAttribute("DailyVote") ~= true) end)
	local result = line("DailyResult", 122, 84, colors.paper)
	local weekly = line("RoleOfWeek", 210, 52, colors.amber)
	local mastery = line("RoleMastery", 266, 106, colors.cyan)
	local rankTitle = line("RankingHeading", 378, 42, colors.amber)
	rankTitle.Text = t("WEEKLY RANKING · FASTEST DAILY SHIFTS", "РЕЙТИНГ НЕДЕЛИ · ЛУЧШЕЕ ВРЕМЯ")
	local ranking = line("Ranking", 474, 0, colors.paper)
	ranking.TextYAlignment = Enum.TextYAlignment.Top
	local size = 1
	local tabs = {}
	for count = 1, 4 do
		local tab = button("Bracket" .. count, UDim2.new((count - 1) / 4, 2, 0, 424), UDim2.new(0.25, -4, 0, 44))
		tab.Text = tostring(count)
		tab.Activated:Connect(function() size = count end)
		tabs[count] = tab
	end
	local function duration(seconds)
		return if seconds then string.format("%d:%02d", seconds // 60, seconds % 60) else "—"
	end
	return function(y)
		frame.Position = UDim2.fromOffset(12, y)
		local phase = state:GetAttribute("Phase")
		vote.Interactable = config.DailyShiftEnabled and config.SectorBlackoutEnabled
			and (phase == "won" or phase == "lost" or phase == "briefing")
		vote.Text = player:GetAttribute("DailyVote") and t("Daily vote cast · tap to cancel", "Голос за ежедневную смену · отменить")
			or (vote.Interactable and t("Vote for daily shift", "Выбрать ежедневную смену") or t("Vote between shifts", "Голосование между сменами"))
		local timestamp = workspace:GetServerTimeNow()
		local day = challenges.day(timestamp)
		local hasToday = player:GetAttribute("DailyRecordDay") == day
		local best = {}
		for count = 1, 4 do best[count] = count .. " · " .. duration(hasToday and player:GetAttribute("DailyBest" .. count) or nil) end
		local summary = t("Today's best by crew size", "Рекорды дня по размеру экипажа") .. "\n" .. table.concat(best, "   ")
		local seconds = state:GetAttribute("LastDailyResultSeconds")
		if seconds then
			summary = string.format(t("Daily result · %s · Heat 1 · crew %d", "Итог дня · %s · Тревога 1 · экипаж %d"),
				duration(seconds), state:GetAttribute("LastDailyResultCrew") or 1) .. "\n" .. summary
		end
		if player:GetAttribute("DailyTitle") then summary ..= "\n" .. t("Title earned: Daily Courier", "Позывной получен: Курьер дня") end
		result.Text = summary
		local week = challenges.week(timestamp)
		local role = roles.Catalog[challenges.roleOfWeek(week)]
		weekly.Text = string.format(t("ROLE OF THE WEEK · %s\nWin with 2 deliveries for +%d Scrap once.", "РОЛЬ НЕДЕЛИ · %s\nПобеда и 2 доставки дают +%d Scrap один раз."),
			t(role.en, role.ru), challenges.WeeklyBonus)
		if player:GetAttribute("RoleBonusWeek") == week then weekly.Text ..= t(" · Claimed", " · Получено") end
		local rows = {t("ROLE MASTERY · PATCH AT 5 / 15 / 30 DELIVERIES", "МАСТЕРСТВО · НАШИВКА ЗА 5 / 15 / 30 ДОСТАВОК")}
		for _, id in roles.Order do
			local count = player:GetAttribute("Mastery" .. id) or 0
			table.insert(rows, string.format("%s · %d/30 · %d/3", t(roles.Catalog[id].en, roles.Catalog[id].ru), count, challenges.tier(count)))
		end
		mastery.Text = table.concat(rows, "\n")
		for count, tab in tabs do tab.TextColor3 = count == size and colors.amber or colors.paper end
		local top = state:GetAttribute("WeeklyCrewTop" .. size)
		ranking.Text = if top == nil then t("Loading records…", "Загрузка рекордов…")
			elseif top == "" then t("No qualifying runs yet.", "Зачтённых смен пока нет.") else top
		local height = if top and top ~= "" then 360 else 44
		ranking.Size = UDim2.new(1, 0, 0, height)
		frame.Size = UDim2.new(1, -24, 0, 482 + height)
		return y + 482 + height
	end
end

return Panel
