local Progression = {}
Progression.Catalog = table.freeze({
	Coil = table.freeze({price = 40, en = "Beacon coil · cooldown 20s", ru = "Катушка маяка · откат 20 с"}),
	Lens = table.freeze({price = 80, en = "Beacon lens · distraction 6s", ru = "Линза маяка · отвлечение 6 с"}),
})
function Progression.reward(deliveries, multiplier)
	return math.floor(math.clamp(deliveries, 0, 5) * 10 * multiplier)
end
function Progression.chooseHeat(votes, novice)
	if novice then return 1 end
	local counts = {0, 0, 0}
	for _, vote in votes do
		if type(vote) == "number" and vote % 1 == 0 and vote >= 1 and vote <= 3 then counts[vote] += 1 end
	end
	local chosen = 1
	for level = 2, 3 do if counts[level] > counts[chosen] then chosen = level end end
	return chosen
end
return Progression
