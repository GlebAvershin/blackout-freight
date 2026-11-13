local SectorBlackout = {
	FixtureTag = "FreightSwitchyardLight",
	WarningSeconds = 2,
	DarkSeconds = 7,
	EarliestSeconds = 35,
}

function SectorBlackout.contains(position)
	return math.abs(position.X) < 68 and position.Z >= -11 and position.Z < 21
end

return table.freeze(SectorBlackout)
