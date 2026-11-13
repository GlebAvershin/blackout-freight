-- Optional reading lives in the journal's scroll area, not the gameplay HUD.
local Panel = {}
function Panel.mount(parent, player, shared, colors, add, t)
	local season = require(shared.Season)
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
		return y+448
	end
	return api
end
return Panel
