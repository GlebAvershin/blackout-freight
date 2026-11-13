-- Free, server-awarded event track. Earned chapters remain readable after expiry.
local Season = {
	Id = "lost_signal_2026",
	StartsAt = 1794528000, -- 2026-11-13 00:00 UTC
	EndsAt = 1798156800, -- 2026-12-25 00:00 UTC, exclusive
	Goals = {5, 15, 30},
	Chapters = {
		{en="01 · The unanswered call", ru="01 · Неотвеченный вызов",
			textEN="Mira: The relay was still recording when the depot went dark. Five cells brought back a voice: 'Do not send the train.' It was my voice. Tomorrow's timestamp.",
			textRU="Мира: Реле продолжало запись после отключения. Пять батарей вернули голос: «Не отправляйте поезд». Это мой голос. С завтрашней датой."},
		{en="02 · A second frequency", ru="02 · Вторая частота",
			textEN="Mira: Your broadcast reached the freight yard. Someone answered with the shelter's emergency code. The Sentinel isn't guarding cargo. It is following that signal.",
			textRU="Мира: Ваш эфир дошёл до грузового двора. Кто-то ответил аварийным кодом убежища. Sentinel охраняет не груз. Он идёт за этим сигналом."},
		{en="03 · Echo crew", ru="03 · Экипаж «Эхо»",
			textEN="Mira: The shelter is powered. I compared both recordings: the warning came from our own relay, six minutes ahead. Keep the Echo patch. Next time, we follow the train together.",
			textRU="Мира: Убежище работает. Я сравнила обе записи: предупреждение пришло от нашего реле, на шесть минут раньше. Сохраните знак «Эхо». В следующий раз пойдём за поездом вместе."},
	},
}
function Season.active(time)
	return time >= Season.StartsAt and time < Season.EndsAt
end
function Season.copy(old)
	if old == nil then return {deliveries=0,broadcast=false,shelter=false} end
	assert(type(old)=="table", "Invalid season record")
	assert(type(old.deliveries)=="number" and old.deliveries>=0 and old.deliveries<=30 and old.deliveries%1==0, "Invalid season deliveries")
	assert(type(old.broadcast)=="boolean" and type(old.shelter)=="boolean", "Invalid season endings")
	return table.clone(old)
end
function Season.advance(old, deliveries, ending, time)
	assert(type(deliveries)=="number" and deliveries>=0 and deliveries<=5 and deliveries%1==0, "Invalid verified deliveries")
	assert(ending==nil or ending=="broadcast" or ending=="shelter", "Invalid season ending")
	local nextValue = Season.copy(old)
	if Season.active(time) and deliveries>0 then
		nextValue.deliveries = math.min(30,nextValue.deliveries+deliveries)
		if ending then nextValue[ending]=true end
	end
	return nextValue
end
function Season.tier(data)
	if not data or data.deliveries<5 then return 0 end
	if data.deliveries<15 or not data.broadcast then return 1 end
	if data.deliveries<30 or not data.shelter then return 2 end
	return 3
end
return Season
