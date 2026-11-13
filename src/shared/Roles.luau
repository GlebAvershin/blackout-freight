local Roles = {}
Roles.Order = table.freeze({"Carrier", "Lure", "Scout", "Technician"})
Roles.Catalog = table.freeze({
	Carrier = table.freeze({en = "Carrier", ru = "Носильщик", cooldown = 24, duration = 3,
		detailEN = "Dash with cargo for 3s. Workshop rack adds a second cell.", detailRU = "Рывок с грузом на 3 с. Крепление даёт второй слот."}),
	Lure = table.freeze({en = "Lure", ru = "Приманка", cooldown = 30, duration = 4,
		detailEN = "Drop a lure during a chase. Beacons share a cooldown.", detailRU = "Оставь маяк во время погони. У маяков общий откат."}),
	Scout = table.freeze({en = "Scout", ru = "Разведчик", cooldown = 12, duration = 5,
		detailEN = "Scan Sentinel through walls for 5s. No dash.", detailRU = "Видит Sentinel сквозь стены 5 с. Без рывка."}),
	Technician = table.freeze({en = "Technician", ru = "Техник", cooldown = 32, duration = 5, setup = 2,
		detailEN = "Stand still 2s: light hides nearby crew for 5s.", detailRU = "Стой 2 с: свет укроет экипаж рядом на 5 с."}),
})
function Roles.canUse(role, phase, time, readyAt, carrying, outside, decoyReady)
	if not Roles.Catalog[role] or phase ~= "live" or time < readyAt or not outside then return false end
	return if role == "Carrier" then carrying == true elseif role == "Lure" then decoyReady == true else true
end
function Roles.speed(sprintUntil, time, carrying)
	return if carrying and time < sprintUntil then 22 else 16
end
return Roles
