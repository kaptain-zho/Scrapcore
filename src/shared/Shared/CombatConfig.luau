--!strict

local CombatConfig = table.freeze({
	Damage = 25,
	MaxDamage = 40,
	Windup = 0.30,
	ActiveTime = 0.10,
	Recovery = 0.50,
	Cooldown = 0.90,
	MinCooldown = 0.60,
	Range = 10.5,
	MaxVerticalDifference = 5,
	HitQueryRadius = 3,
	HorizontalKnockbackSpeed = 18,
	MaxHorizontalKnockbackSpeed = 26,
	KnockbackDuration = 0.25,
	KnockbackAccelerationAllowance = 900,
	SwingWindupAngle = math.rad(70),
	SwingFollowThroughAngle = math.rad(-70),
	RequestRateWindow = 1,
	MaxRequestsPerWindow = 8,
	MaxSequenceAdvance = 32,
	MaxQueryParts = 64,
	MaxBroadcastAge = 2,
	TestDummyResetDelay = 2,
})

return CombatConfig
