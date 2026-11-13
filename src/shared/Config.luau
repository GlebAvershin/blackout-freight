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
		table.freeze({ChaseSpeed = 15, BlackBoxSpeed = 16.2, PatrolSpeed = 10.5, ScrapMultiplier = 1.8}),
		table.freeze({ChaseSpeed = 15.3, BlackBoxSpeed = 16.5, PatrolSpeed = 11, ScrapMultiplier = 2.2}),
	}),
	SentinelPilotEnabled = false, -- Enable after stable population and published multiplayer QA.
	SectorBlackoutEnabled = true,
	DailyShiftEnabled = true,
	CrewPingsEnabled = true,
	Target = 5,
	ShiftSeconds = 165,
	CellCount = 8,
	AirlockSafeZ = 54,
	DecoySeconds = 5,
	DecoyCooldown = 25,
	RoutingSeconds = 25,
	CosmeticPassId = 2082542258, -- Aurora Lens for Blackout Freight.
	ShiftPassId = 0, -- Set for this season after the playtest gate.
	DoubleScrapPassId = 0, -- Enable after economy validation.
	RewardedScrapProductId = 0, -- Enable serving in Creator Hub before configuring.
	DepotClubSubscriptionId = "", -- Enable after D7 validation.
	CrewPassId = 2088128252, -- Экипаж Депо 07 for Blackout Freight.
})
