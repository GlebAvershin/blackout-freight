local Operations = {DividerZ = 30, GapWidth = 16}

Operations.Routes = {
	west = {
		gap = -35, cells = {1, 2, 3, 5, 7, 8, 10, 12},
		name = {"West bypass", "Западный обход"},
		start = {"Mira: The main track is sealed. Follow the west lights.", "Мира: Главный путь закрыт. Иди на запад по огням."},
		middle = {"Mira: Someone logged a convoy before the blackout.", "Мира: Перед отключением здесь прошёл конвой."},
		record = {"Mira: They moved the relay key in a freight convoy.", "Мира: Ключ ретранслятора увезли грузовым конвоем."},
	},
	east = {
		gap = 35, cells = {1, 2, 4, 6, 7, 9, 11, 12},
		name = {"East service line", "Восточная ветка"},
		start = {"Mira: The east service gate is open. Follow its lights.", "Мира: Восточные ворота открыты. Иди по огням."},
		middle = {"Mira: The shelter relay sent a second distress call.", "Мира: Из укрытия отправили второй сигнал бедствия."},
		record = {"Mira: The distress call came before the shutdown order.", "Мира: Сигнал бедствия пришёл до приказа об отключении."},
	},
}

function Operations.next(eligible, current, last, replayWest)
	if replayWest then
		return "west"
	end
	if eligible and not current then
		return last == "west" and "east" or "west"
	end
	return nil
end

function Operations.nextObjective(broadcast, shelter, west, east)
	if not broadcast then
		return shelter and "broadcast" or "bothEndings"
	end
	if not shelter then
		return "shelter"
	end
	if not west then
		return east and "west" or "bothRecords"
	end
	return east and "complete" or "east"
end

function Operations.waypoint(route, x, z, goalX, goalZ)
	local divider = Operations.DividerZ
	local side = z >= divider and 1 or -1
	if (goalZ - divider) * side < 0 then
		if math.abs(x - route.gap) > 1 then
			return route.gap, divider + side * 4
		end
		return route.gap, divider - side * 4
	elseif math.abs(z - divider) < 3 and math.abs(x - route.gap) < 3 then
		return route.gap, divider + side * 4
	end
	return goalX, goalZ
end

return Operations
