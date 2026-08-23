--!strict

local SPAWN_POSITIONS = table.freeze({
	Vector3.new(0, 1.5, 145),
	Vector3.new(145, 1.5, 0),
	Vector3.new(0, 1.5, -145),
	Vector3.new(-145, 1.5, 0),
})

local BREAKABLE_ZONES = table.freeze({
	table.freeze({ Name = "Center", BreakableType = "PowerCore", Count = 20, MinAxisDistance = 18, MaxAxisDistance = 55 }),
	table.freeze({ Name = "Middle", BreakableType = "ReinforcedCrate", Count = 40, MinAxisDistance = 65, MaxAxisDistance = 115 }),
	table.freeze({ Name = "Outer", BreakableType = "ScrapPile", Count = 80, MinAxisDistance = 125, MaxAxisDistance = 170 }),
})

local ArenaConfig = table.freeze({
	PlayableSize = Vector2.new(380, 380),
	FloorCenter = Vector3.new(0, 0.5, 0),
	FloorThickness = 1,
	WallThickness = 2,
	WallHeight = 8,
	WallCenterY = 4.5,
	GenerationSeed = 310031,
	MinimumBreakableSpacing = 12,
	MaximumPlacementAttemptsPerObject = 500,
	WallClearance = 18,
	CenterClearance = 14,
	SpawnClearance = 18,
	DummyClearance = 16,
	SpawnPositions = SPAWN_POSITIONS,
	DummyPosition = Vector3.new(0, 1.8, 118),
	BreakableZones = BREAKABLE_ZONES,
})

return ArenaConfig
