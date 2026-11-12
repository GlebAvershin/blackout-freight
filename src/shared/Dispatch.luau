local Dispatch = {RewardWeeks = 3}

Dispatch.Objectives = {
	{"Deliver 2 cells and win.", "Сдай 2 батареи и выиграй."},
	{"Deliver a cell and win without being caught.", "Сдай батарею и выиграй без поимок."},
	{"Deliver a cell and win within 2 minutes.", "Сдай батарею и выиграй за 2 минуты."},
}

function Dispatch.week(unixTime)
	-- Unix time began on a Thursday, so offset to the Monday UTC boundary.
	return (unixTime + 3 * 86400) // 604800
end

function Dispatch.objective(week)
	return week % #Dispatch.Objectives + 1
end

function Dispatch.qualifies(week, deliveries, catches, elapsed)
	local objective = Dispatch.objective(week)
	if objective == 1 then
		return deliveries >= 2
	elseif objective == 2 then
		return deliveries >= 1 and catches == 0
	end
	return deliveries >= 1 and elapsed <= 120
end

return Dispatch
