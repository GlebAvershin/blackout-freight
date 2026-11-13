-- Optional reading lives in the journal's scroll area, not the gameplay HUD.
local Panel = {}
function Panel.mount(parent, player, shared, colors, add, t)
	local season = require(shared.Season)
	local config = require(shared.Config)
	local marketplace = game:GetService("MarketplaceService")
	local frame = add("Frame",parent,{Name="Season",BackgroundTransparency=1,Size=UDim2.new(1,-24,0,440)})
	local function label(name,y,height,color,bold)
		return add("TextLabel",frame,{Name=name,Position=UDim2.fromOffset(0,y),Size=UDim2.new(1,0,0,height),
			BackgroundTransparency=1,TextColor3=color,TextSize=12,TextWrapped=true,AutoLocalize=false,
			TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
			Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham})
	end
	local heading=label("Heading",0,28,colors.cyan,true)
	heading.Text=t("LOST SIGNAL · FREE SEASON", "ПОТЕРЯННЫЙ СИГНАЛ · БЕСПЛАТНО")
	local dates=label("Dates",30,44,colors.muted,false)
	local progress=label("Progress",76,44,colors.paper,false)
	local bar=add("Frame",frame,{Name="ProgressBar",Position=UDim2.fromOffset(0,122),Size=UDim2.new(1,0,0,4),BackgroundColor3=colors.slate,BorderSizePixel=0})
	local fill=add("Frame",bar,{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=colors.cyan,BorderSizePixel=0})
	local selected=1
	local buttons={}
	for i,chapter in season.Chapters do
		local b=add("TextButton",frame,{Name="Chapter"..i,Position=UDim2.fromOffset(0,134+(i-1)*48),Size=UDim2.new(1,0,0,44),
			BackgroundColor3=colors.slate,TextColor3=colors.paper,TextSize=12,TextWrapped=true,AutoLocalize=false,Font=Enum.Font.GothamBold})
		add("UICorner",b,{CornerRadius=UDim.new(0,5)})
		b.Activated:Connect(function() selected=i end)
		buttons[i]=b
	end
	local detail=label("Detail",282,150,colors.muted,false)
		local offers = {}
	local function offer(id, attribute, en, ru, ownedEN, ownedRU, subscribe)
		if id == 0 or id == "" then return end
		local button = add("TextButton",frame,{Name=attribute,Size=UDim2.new(1,0,0,44),
			BackgroundColor3=colors.slate,TextColor3=colors.paper,TextSize=12,TextWrapped=true,AutoLocalize=false,Font=Enum.Font.GothamBold})
		add("UICorner",button,{CornerRadius=UDim.new(0,5)})
		table.insert(offers,{button=button,attribute=attribute,title=t(en,ru),owned=t(ownedEN,ownedRU)})
		button.Activated:Connect(function()
			if player:GetAttribute(attribute) ~= false or (attribute == "ShiftPass" and not season.active(os.time())) then return end
			pcall(function()
				if subscribe then marketplace:PromptSubscriptionPurchase(player,id)
				else marketplace:PromptGamePassPurchase(player,id) end
			end)
		end)
	end
	offer(config.ShiftPassId,"ShiftPass","Shift Pass · three season patch styles","Пропуск смены · три сезонные нашивки","Shift Pass owned","Пропуск смены приобретён")
	offer(config.DoubleScrapPassId,"DoubleScrap","2× Scrap · same hourly cap","2× Scrap · тот же лимит в час","2× Scrap active","2× Scrap действует")
	offer(config.DepotClubSubscriptionId,"DepotClub","Depot Club · rotating patch + 25% Scrap","Клуб депо · сменная нашивка и +25% Scrap","Depot Club active","Клуб депо действует",true)
	local ad, adAvailable, checkingAd
	if config.RewardedScrapProductId > 0 then
		ad = add("TextButton",frame,{Name="RewardedScrap",Visible=false,Size=UDim2.new(1,0,0,44),
			Text=t("Watch a video · +25 Scrap","Посмотреть ролик · +25 Scrap"),
			BackgroundColor3=colors.slate,TextColor3=colors.paper,TextSize=12,TextWrapped=true,AutoLocalize=false,Font=Enum.Font.GothamBold})
		add("UICorner",ad,{CornerRadius=UDim.new(0,5)})
		local ads = game:GetService("AdService")
		local checkedAt = -120
		local function check()
			if checkingAd or os.clock()-checkedAt < 120 then return end
			checkingAd, checkedAt = true, os.clock()
			task.spawn(function()
				local ok, result = pcall(ads.GetAdAvailabilityNowAsync,ads,Enum.AdFormat.RewardedVideo)
				adAvailable = ok and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
				checkingAd = false
			end)
		end
		parent:GetPropertyChangedSignal("Visible"):Connect(function()
			if parent.Visible then check() end
		end)
		ad.Activated:Connect(function()
			if not adAvailable then return end
			adAvailable = false
			checkedAt = os.clock()
			local remote = shared:FindFirstChild("RewardedScrap")
			if remote then remote:FireServer() end
		end)
	end
	local api={}
	function api.draw(y)
		frame.Position=UDim2.fromOffset(12,y)
		local active=season.active(os.time())
		dates.Text=active and t("13 Nov–24 Dec 2026 UTC. Earned recordings and the Echo patch stay yours.", "13 ноября–24 декабря 2026 UTC. Записи и знак «Эхо» остаются навсегда.")
			or t("Event inactive. Your earned recordings and Echo patch remain available.", "Событие неактивно. Полученные записи и знак «Эхо» остаются доступны.")
		local count=math.clamp(player:GetAttribute("SeasonDeliveries") or 0,0,30)
		local tier=player:GetAttribute("SeasonTier") or 0
		progress.Text=string.format(t("%d/30 verified deliveries · %d/3 recordings. Complete the story for the Echo sleeve patch.", "%d/30 проверенных доставок · %d/3 записей. Собери историю и получи знак «Эхо»."),count,tier)
		fill.Size=UDim2.fromScale(count/30,1)
		for i,b in buttons do
			b.Text=(tier>=i and "✓ " or "○ ")..t(season.Chapters[i].en,season.Chapters[i].ru)
			b.TextColor3=selected==i and colors.cyan or colors.paper
		end
		local chapter=season.Chapters[selected]
		if tier>=selected then
			detail.Text=t(chapter.textEN,chapter.textRU)
		elseif selected==1 then
			detail.Text=t("Recover the relay: deliver 5 cells during the event. Only your verified deliveries count; all maps and Heat levels work.", "Восстанови реле: сдай 5 батарей во время события. Учитываются твои проверенные доставки на любой карте и Тревоге.")
		elseif selected==2 then
			detail.Text=t("Deliver 15 cells and win Broadcast during the event. Make at least one verified delivery in the winning shift.", "Сдай 15 батарей и победи с концовкой «Эфир» во время события. В победной смене нужна хотя бы одна твоя проверенная доставка.")
		else
			detail.Text=t("Deliver 30 cells and win both Broadcast and Shelter during the event, with a verified delivery in each. Unlocks the final recording and a permanent Echo patch.", "Сдай 30 батарей и получи «Эфир» и «Укрытие» во время события, с личной доставкой в каждой победе. Награда — финальная запись и постоянный знак «Эхо».")
		end
		local height = 440
		for _, item in offers do
			local owned = player:GetAttribute(item.attribute)
			local visible = owned ~= nil and (item.attribute ~= "ShiftPass" or active or owned)
			item.button.Visible = visible
			item.button.Interactable = visible and not owned
			item.button.Text = owned and item.owned or item.title
			if visible then
				item.button.Position = UDim2.fromOffset(0,height)
				height += 50
			end
		end
		if ad then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			ad.Visible = adAvailable == true and root ~= nil and root.Position.Z >= config.AirlockSafeZ and not player:GetAttribute("Carrying")
			if ad.Visible then
				ad.Position = UDim2.fromOffset(0,height)
				height += 50
			end
		end
		frame.Size = UDim2.new(1,-24,0,height)
		return y+height+8
	end
	return api
end
return Panel
