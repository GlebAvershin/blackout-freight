-- Lives inside the existing scrollable journal, never over the gameplay HUD.
local Panel = {}
function Panel.mount(parent, player, state, shared, colors, add, t)
	local progression = require(shared.Progression)
	local catalog = progression.Catalog
	local config = require(shared.Config)
	local roles = require(shared.Roles)
	local rankTrack = require(shared.RankTrack)
	local remote = shared:WaitForChild("Preparation")
	local frame = add("Frame", parent, {Name = "Workshop", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 730)})
	local heading = add("TextLabel", frame, {Name = "Balance", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = colors.cyan, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left})
	local function button(name, text, position, size)
		local b = add("TextButton", frame, {Name = name, Text = text, Position = position, Size = size,
			TextColor3 = colors.paper, BackgroundColor3 = colors.slate, TextSize = 12,
			Font = Enum.Font.GothamBold, TextWrapped = true, AutoLocalize = false})
		add("UICorner", b, {CornerRadius = UDim.new(0, 5)})
		return b
	end
	local votes, upgrades = {}, {}
	for level = 1, #config.Heat do
		local b = button("Heat" .. level, t("Heat ", "Тревога ") .. level, UDim2.new((level-1)%3/3, 2, 0, 32 + math.floor((level-1)/3)*50), UDim2.new(1/3, -4, 0, 44))
		b.Activated:Connect(function() remote:FireServer("heat", level) end)
		votes[level] = b
	end
	for index, id in progression.UpgradeOrder do
		local b = button(id, "", UDim2.fromOffset(0, 234 + (index-1)*50), UDim2.new(1, 0, 0, 44))
		b.Activated:Connect(function() remote:FireServer("upgrade", id) end)
		upgrades[id] = b
	end
	local status = add("TextLabel", frame, {Name = "Status", Position = UDim2.fromOffset(0, 334), Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1, TextColor3 = colors.muted, TextSize = 12, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham})
	local roleButtons = {}
	for index, id in roles.Order do
		local b = button("Role" .. id, t(roles.Catalog[id].en, roles.Catalog[id].ru),
			UDim2.new((index-1)%2/2, 2, 0, 390 + math.floor((index-1)/2)*50), UDim2.new(0.5, -4, 0, 44))
		b.Activated:Connect(function() remote:FireServer("role", id) end)
		roleButtons[id] = b
	end
	local roleDetail = add("TextLabel", frame, {Name = "RoleDetail", Position = UDim2.fromOffset(0, 488), Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1, TextColor3 = colors.muted, TextSize = 12, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham})
	local mapButtons = {}
	for index, id in {"depot", "yard"} do
		local b = button("Map" .. id, id == "yard" and t("Freight yard", "Грузовой двор") or t("Depot 07", "Депо 07"),
			UDim2.new((index-1)/2, 2, 0, 544), UDim2.new(0.5,-4,0,44))
		b.Activated:Connect(function() remote:FireServer("map", id) end)
		mapButtons[id] = b
	end
	local mapDetail = add("TextLabel", frame, {Name = "MapDetail", Position = UDim2.fromOffset(0,592), Size = UDim2.new(1,0,0,48),
		BackgroundTransparency = 1, TextColor3 = colors.muted, TextSize = 12, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham})
	local rankTitle = add("TextLabel", frame, {Name="RankTitle", Position=UDim2.fromOffset(0,640), Size=UDim2.new(1,0,0,24),
		BackgroundTransparency=1, TextColor3=colors.cyan, TextSize=13, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})
	local rankGoal = add("TextLabel", frame, {Name="RankGoal", Position=UDim2.fromOffset(0,668), Size=UDim2.new(1,0,0,48),
		BackgroundTransparency=1, TextColor3=colors.muted, TextSize=12, Font=Enum.Font.Gotham, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left})
	local rankBar = add("Frame", frame, {Name="RankProgress", Position=UDim2.fromOffset(0,722), Size=UDim2.new(1,0,0,4), BackgroundColor3=colors.slate, BorderSizePixel=0})
	local rankFill = add("Frame", rankBar, {Name="Fill", Size=UDim2.fromScale(0,1), BackgroundColor3=colors.cyan, BorderSizePixel=0})
	local pilotButton
	if config.SentinelPilotEnabled then
		pilotButton = button("Pilot", "", UDim2.fromOffset(0,730), UDim2.new(1,0,0,44))
		frame.Size = UDim2.new(1,-24,0,780)
		pilotButton.Activated:Connect(function()
			remote:FireServer("pilot", player:GetAttribute("PilotVolunteer") ~= true)
		end)
	end
	local api = {}
	function api.draw(y)
		frame.Position = UDim2.fromOffset(12, y)
		local balance = player:GetAttribute("Scrap") or 0
		heading.Text = string.format(t("WORKSHOP · %d Scrap · rank %d", "МАСТЕРСКАЯ · %d Scrap · ранг %d"), balance, player:GetAttribute("CrewRank") or 1)
		local phase = state:GetAttribute("Phase")
		local between = phase == "won" or phase == "lost" or phase == "briefing"
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local safe = between or (phase == "live" and root and root.Position.Z >= require(shared.Config).AirlockSafeZ)
		local profile = player:GetAttribute("ProfileStatus")
		local ready = profile == "ready" or profile == "local"
		for level, b in votes do
			b.Interactable = between and (level <= 3 or (player:GetAttribute("EndingBroadcast") and player:GetAttribute("EndingShelter")) == true)
			b.TextColor3 = (player:GetAttribute("HeatVote") or 1) == level and colors.amber or colors.paper
		end
		for id, b in upgrades do
			local item = catalog[id]
			local owned = player:GetAttribute("Upgrade" .. id)
			b.Text = t(item.en, item.ru) .. (owned and " ✓" or " · " .. item.price)
			b.Interactable = ready and safe == true and not player:GetAttribute("Carrying") and not owned and balance >= item.price
			b.TextColor3 = owned and colors.cyan or (b.Interactable and colors.paper or colors.muted)
		end
		status.Text = if profile == "unavailable" then t("Progress unavailable. Rejoin to retry.", "Прогресс недоступен. Перезайди для повторной загрузки.")
			elseif profile == "saving" then t("Saving progress…", "Сохраняем прогресс…")
			elseif not ready then t("Loading progress…", "Загружаем прогресс…")
			elseif between then t("Heat 4–5 require both endings for everyone. Heat 5 adds the Swarm.", "Тревога 4–5: нужны обе концовки у всех. На 5-й появляется Рой.")
			else t("Earn Scrap by delivering cells. Upgrade at the airlock; vote between shifts.", "Scrap дают за доставки. Улучшения — у шлюза, Тревога — между сменами.")
		local selected = player:GetAttribute("NextCrewRole") or "Carrier"
		for id, b in roleButtons do
			b.Interactable = between
			b.TextColor3 = selected == id and colors.cyan or colors.paper
		end
		local definition = roles.Catalog[selected] or roles.Catalog.Carrier
		roleDetail.Text = t(definition.detailEN, definition.detailRU)
		local unlocked = player:GetAttribute("EndingBroadcast") and player:GetAttribute("EndingShelter")
		for id,b in mapButtons do
			b.Interactable = between and (id == "depot" or unlocked == true)
			b.TextColor3 = (player:GetAttribute("MapVote") or "depot") == id and colors.amber or colors.paper
		end
		mapDetail.Text = unlocked and t("Crew majority chooses the yard. Everyone needs both endings.", "Двор выбирает большинство. У всех должны быть обе концовки.")
			or t("Complete both endings to unlock the freight yard.", "Пройди обе концовки, чтобы открыть Грузовой двор.")
		local xp = player:GetAttribute("RankXP") or 0
		local title, nextReward, fraction = rankTrack.progress(xp)
		rankTitle.Text = t("CAREER · ", "КАРЬЕРА · ") .. (title and t(title.en,title.ru) or t("Rookie", "Новичок"))
		rankGoal.Text = nextReward and string.format(t("Next: %s · %d/%d XP. Title + sleeve badge. Earn XP by delivering.", "Далее: %s · %d/%d XP. Позывной и знак за доставки."), t(nextReward.en,nextReward.ru), xp,nextReward.xp)
			or t("All career badges earned. Keep improving your crew time.", "Все знаки карьеры получены. Улучшай время экипажа.")
		rankFill.Size = UDim2.fromScale(fraction,1)
		if pilotButton then
			pilotButton.Interactable = between and unlocked == true
			pilotButton.Text = player:GetAttribute("PilotVolunteer")
				and t("Sentinel operator · volunteered", "Оператор Sentinel · заявка принята")
				or t("Volunteer to steer Sentinel · 3+ players", "Управлять Sentinel · от 3 игроков")
		end
		return y + (pilotButton and 788 or 738)
	end
	return api
end
return Panel
