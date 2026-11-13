return table.freeze({
	Drone = table.freeze({
		Start = table.freeze({-19, 5.5, 12}),
		Patrol = table.freeze({table.freeze({-31, 5.5, 10}), table.freeze({0, 5.5, -38}), table.freeze({31, 5.5, 17})}),
		CatchRadius = 5.05,
		BlackBoxPriority = 0.45,
	}),
	Heat = table.freeze({
		table.freeze({ChaseSpeed = 13.7, BlackBoxSpeed = 15.3, PatrolSpeed = 8, ScrapMultiplier = 1}),
		table.freeze({ChaseSpeed = 14.2, BlackBoxSpeed = 15.6, PatrolSpeed = 9, ScrapMultiplier = 1.25}),
		table.freeze({ChaseSpeed = 14.7, BlackBoxSpeed = 15.9, PatrolSpeed = 10, ScrapMultiplier = 1.5}),
	}),
	Target = 5,
	ShiftSeconds = 165,
	CellCount = 8,
	AirlockSafeZ = 54,
	DecoySeconds = 5,
	DecoyCooldown = 25,
	RoutingSeconds = 25,
	CosmeticPassId = 2082542258, -- Aurora Lens for Blackout Freight.
	CrewPassId = 2088128252, -- Экипаж Депо 07 for Blackout Freight.
})
