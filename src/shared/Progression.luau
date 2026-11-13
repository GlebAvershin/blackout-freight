local Config = if script then require(script.Parent.Config) else require("./Config")
local Progression = {}
Progression.AdScrap = 25
Progression.UpgradeOrder = table.freeze({"Coil", "Lens", "Rack", "Lamp"})
Progression.Catalog = table.freeze({
	Coil = table.freeze({price = 40, en = "Beacon coil · cooldown 20s", ru = "Катушка маяка · откат 20 с"}),
	Rack = table.freeze({price = 400, en = "Cargo rack · second cell for Carrier", ru = "Крепление · вторая батарея Носильщика"}),
	Lamp = table.freeze({price = 300, en = "Headlamp · personal light", ru = "Фонарь · личный свет"}),
	Lens = table.freeze({price = 80, en = "Beacon lens · distraction 6s", ru = "Линза маяка · отвлечение 6 с"}),
})
function Progression.reward(deliveries, multiplier)
	return math.floor(math.clamp(deliveries, 0, 5) * 10 * multiplier)
end
-- Paid bonuses affect the wallet, never XP or seasonal progress, and do not stack.
function Progression.walletReward(base, doubleScrap, club)
	return if doubleScrap then base * 2 elseif club then math.floor(base * 1.25) else base
end
function Progression.chooseHeat(votes, novice, veteran)
	if novice then return 1 end
	local cap = if veteran then #Config.Heat else 3
	local counts = table.create(cap, 0)
	for _, vote in votes do
		if type(vote) == "number" and vote % 1 == 0 and vote >= 1 and vote <= cap then counts[vote] += 1 end
	end
	local chosen = 1
	for level = 2, cap do if counts[level] > counts[chosen] then chosen = level end end
	return chosen
end
return Progression
