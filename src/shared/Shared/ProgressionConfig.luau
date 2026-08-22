--!strict

local XP_REQUIREMENTS = table.freeze({
	40,
	55,
	70,
	90,
	115,
	145,
	180,
	220,
	265,
	315,
	370,
	430,
	495,
	565,
	640,
	720,
	805,
	895,
	990,
	1090,
	1195,
	1305,
	1420,
	1540,
	1665,
	1795,
	1930,
	2070,
	2215,
})

local UPGRADE_ORDER = table.freeze({
	"Power",
	"Armor",
	"Mobility",
	"Recovery",
	"Force",
})

local UPGRADES = table.freeze({
	Power = table.freeze({
		AttributeName = "PowerUpgradeLevel",
		DisplayName = "Power",
		Description = "+8% hammer damage",
		PerPoint = 0.08,
	}),
	Armor = table.freeze({
		AttributeName = "ArmorUpgradeLevel",
		DisplayName = "Armor",
		Description = "+10 maximum health",
		PerPoint = 10,
	}),
	Mobility = table.freeze({
		AttributeName = "MobilityUpgradeLevel",
		DisplayName = "Mobility",
		Description = "+4% movement speed",
		PerPoint = 0.04,
	}),
	Recovery = table.freeze({
		AttributeName = "RecoveryUpgradeLevel",
		DisplayName = "Recovery",
		Description = "-6% hammer cooldown",
		PerPoint = 0.06,
	}),
	Force = table.freeze({
		AttributeName = "ForceUpgradeLevel",
		DisplayName = "Force",
		Description = "+8% hammer knockback",
		PerPoint = 0.08,
	}),
})

local BREAKABLES = table.freeze({
	ScrapPile = table.freeze({
		DisplayName = "SCRAP PILE",
		MaxHealth = 25,
		XPReward = 10,
		RespawnDelay = 8,
	}),
	ReinforcedCrate = table.freeze({
		DisplayName = "REINFORCED CRATE",
		MaxHealth = 75,
		XPReward = 30,
		RespawnDelay = 15,
	}),
	PowerCore = table.freeze({
		DisplayName = "POWER CORE",
		MaxHealth = 150,
		XPReward = 75,
		RespawnDelay = 30,
	}),
})

local function clampUpgradeRank(rank: number): number
	return math.clamp(math.floor(rank), 0, 5)
end

local function getXPToNextLevel(level: number): number
	local safeLevel = math.clamp(math.floor(level), 1, 30)
	if safeLevel >= 30 then
		return 0
	end
	return XP_REQUIREMENTS[safeLevel]
end

local function getPowerMultiplier(rank: number): number
	return 1 + clampUpgradeRank(rank) * UPGRADES.Power.PerPoint
end

local function getArmorBonus(rank: number): number
	return clampUpgradeRank(rank) * UPGRADES.Armor.PerPoint
end

local function getMobilityMultiplier(rank: number): number
	return 1 + clampUpgradeRank(rank) * UPGRADES.Mobility.PerPoint
end

local function getRecoveryMultiplier(rank: number): number
	return math.max(0.7, 1 - clampUpgradeRank(rank) * UPGRADES.Recovery.PerPoint)
end

local function getForceMultiplier(rank: number): number
	return 1 + clampUpgradeRank(rank) * UPGRADES.Force.PerPoint
end

local ProgressionConfig = table.freeze({
	LevelCap = 30,
	UpgradePointsPerLevel = 1,
	MaxUpgradeRank = 5,
	MaxUnspentUpgradePoints = 29,
	MaxServerXPAward = 10000,
	PlayerEliminationXP = 60,
	BaseMaxHealth = 100,
	UpgradeRequestWindow = 1,
	MaxUpgradeRequestsPerWindow = 8,
	MinimumUpgradeRequestInterval = 0.08,
	MaxBreakableDamagePerHit = 100,
	XPRequirements = XP_REQUIREMENTS,
	UpgradeOrder = UPGRADE_ORDER,
	Upgrades = UPGRADES,
	Breakables = BREAKABLES,
	ClampUpgradeRank = clampUpgradeRank,
	GetXPToNextLevel = getXPToNextLevel,
	GetPowerMultiplier = getPowerMultiplier,
	GetArmorBonus = getArmorBonus,
	GetMobilityMultiplier = getMobilityMultiplier,
	GetRecoveryMultiplier = getRecoveryMultiplier,
	GetForceMultiplier = getForceMultiplier,
})

return ProgressionConfig
