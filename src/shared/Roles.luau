local Roles = {}
Roles.Order = table.freeze({"Carrier", "Lure"})
Roles.Catalog = table.freeze({
	Carrier = table.freeze({en = "Carrier", ru = "Носильщик", cooldown = 24, duration = 3,
		detailEN = "Dash with cargo for 3s. Everyone can carry one item.", detailRU = "Рывок с грузом на 3 с. Все могут нести один предмет."}),
	Lure = table.freeze({en = "Lure", ru = "Приманка", cooldown = 30, duration = 4,
		detailEN = "Drop a lure during a chase. Beacons share a cooldown.", detailRU = "Оставь маяк во время погони. У маяков общий откат."}),
})
function Roles.canUse(role, phase, time, readyAt, carrying, outside, decoyReady)
	if not Roles.Catalog[role] or phase ~= "live" or time < readyAt or not outside then return false end
	return if role == "Carrier" then carrying == true else decoyReady == true
end
function Roles.speed(sprintUntil, time, carrying)
	return if carrying and time < sprintUntil then 22 else 16
end
return Roles
