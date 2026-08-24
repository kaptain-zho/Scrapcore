--!strict

local LEVEL_CAP = 30
local UPGRADE_POINTS_PER_LEVEL = 1
local MAX_UPGRADE_RANK = 30

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
	"Speed",
	"Attack Rate",
	"Damage",
	"Health",
	"Health Regen",
})

local UPGRADES = table.freeze({
	Speed = table.freeze({
		AttributeName = "SpeedUpgradeLevel",
		DisplayName = "Speed",
		Description = "Maximum movement speed",
		PerPoint = 0.2 / MAX_UPGRADE_RANK,
	}),
	["Attack Rate"] = table.freeze({
		AttributeName = "AttackRateUpgradeLevel",
		DisplayName = "Attack Rate",
		Description = "Weapon attack rate",
		PerPoint = 0.3 / MAX_UPGRADE_RANK,
	}),
	Damage = table.freeze({
		AttributeName = "DamageUpgradeLevel",
		DisplayName = "Damage",
		Description = "Weapon damage",
		PerPoint = 0.4 / MAX_UPGRADE_RANK,
	}),
	Health = table.freeze({
		AttributeName = "HealthUpgradeLevel",
		DisplayName = "Health",
		Description = "Maximum health",
		PerPoint = 50 / MAX_UPGRADE_RANK,
	}),
	["Health Regen"] = table.freeze({
		AttributeName = "HealthRegenUpgradeLevel",
		DisplayName = "Health Regen",
		Description = "Health restored after avoiding damage",
		PerPoint = 0.1,
	}),
})

local BREAKABLES = table.freeze({
	ScrapPileCommon = table.freeze({
		TemplateName = "ScrapPile",
		Rarity = "Common",
		DisplayName = "COMMON SCRAP",
		MaxHealth = 25,
		XPReward = 10,
		RespawnDelay = 8,
		BaseColor = Color3.fromRGB(64, 72, 80),
		AccentColor = Color3.fromRGB(45, 180, 210),
	}),
	ScrapPileRare = table.freeze({
		TemplateName = "ScrapPile",
		Rarity = "Rare",
		DisplayName = "RARE SCRAP",
		MaxHealth = 75,
		XPReward = 30,
		RespawnDelay = 15,
		BaseColor = Color3.fromRGB(64, 72, 80),
		AccentColor = Color3.fromRGB(145, 85, 215),
	}),
	ScrapPileEpic = table.freeze({
		TemplateName = "ScrapPile",
		Rarity = "Epic",
		DisplayName = "EPIC SCRAP",
		MaxHealth = 150,
		XPReward = 60,
		RespawnDelay = 30,
		BaseColor = Color3.fromRGB(64, 72, 80),
		AccentColor = Color3.fromRGB(235, 150, 45),
	}),
	ReinforcedCrate = table.freeze({
		TemplateName = "ReinforcedCrate",
		DisplayName = "REINFORCED CRATE",
		MaxHealth = 75,
		XPReward = 30,
		RespawnDelay = 15,
	}),
	PowerCore = table.freeze({
		TemplateName = "PowerCore",
		DisplayName = "POWER CORE",
		MaxHealth = 150,
		XPReward = 75,
		RespawnDelay = 30,
	}),
})

local function clampUpgradeRank(rank: number): number
	return math.clamp(math.floor(rank), 0, MAX_UPGRADE_RANK)
end

local function getXPToNextLevel(level: number): number
	local safeLevel = math.clamp(math.floor(level), 1, LEVEL_CAP)
	if safeLevel >= LEVEL_CAP then
		return 0
	end
	return XP_REQUIREMENTS[safeLevel]
end

local function getEarnedUpgradePoints(level: number): number
	local safeLevel = math.clamp(math.floor(level), 1, LEVEL_CAP)
	return safeLevel * UPGRADE_POINTS_PER_LEVEL
end

local function getSpeedMultiplier(rank: number): number
	return 1 + clampUpgradeRank(rank) * UPGRADES.Speed.PerPoint
end

local function getAttackRateMultiplier(rank: number): number
	return math.max(0.7, 1 - clampUpgradeRank(rank) * UPGRADES["Attack Rate"].PerPoint)
end

local function getDamageMultiplier(rank: number): number
	return 1 + clampUpgradeRank(rank) * UPGRADES.Damage.PerPoint
end

local function getHealthBonus(rank: number): number
	return clampUpgradeRank(rank) * UPGRADES.Health.PerPoint
end

local function getHealthRegenPerSecond(rank: number): number
	return clampUpgradeRank(rank) * UPGRADES["Health Regen"].PerPoint
end

local ProgressionConfig = table.freeze({
	LevelCap = LEVEL_CAP,
	UpgradePointsPerLevel = UPGRADE_POINTS_PER_LEVEL,
	StartingUpgradePoints = UPGRADE_POINTS_PER_LEVEL,
	MaxUpgradeRank = MAX_UPGRADE_RANK,
	MaxUnspentUpgradePoints = LEVEL_CAP * UPGRADE_POINTS_PER_LEVEL,
	MaxServerXPAward = 10000,
	PlayerEliminationXP = 60,
	BaseMaxHealth = 100,
	MaxUpgradedMaxHealth = 150,
	HealthRegenDamageDelay = 5,
	HealthRegenTickInterval = 0.1,
	MaxHealthRegenPerSecond = 3,
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
	GetEarnedUpgradePoints = getEarnedUpgradePoints,
	GetSpeedMultiplier = getSpeedMultiplier,
	GetAttackRateMultiplier = getAttackRateMultiplier,
	GetDamageMultiplier = getDamageMultiplier,
	GetHealthBonus = getHealthBonus,
	GetHealthRegenPerSecond = getHealthRegenPerSecond,
})

return ProgressionConfig
