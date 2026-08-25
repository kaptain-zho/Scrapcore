--!strict

local POWER_LEVEL_CAP = 300
local MAXIMUM_TRACKED_LEVEL = 1_000_000
local SCORE_ONLY_XP_PER_LEVEL = 50
local MAX_UPGRADE_RANK = 30
local CURVE_STRENGTH = 1.5

-- Preserve the validated Level 8 pacing. Requirements from Level 8 onward use
-- the bounded curve below so active Level 300 runs remain a 20–45 minute goal.
local EARLY_XP_REQUIREMENTS = table.freeze({
	40,
	55,
	70,
	90,
	115,
	145,
	180,
})

-- Levels 1–30 preserve the accepted prototype schedule. The remaining 50
-- grants are deliberately explicit so later pacing changes remain reviewable.
local UPGRADE_POINT_LEVELS = table.freeze({
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
	11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
	21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
	35, 40, 45, 50, 55, 60, 65, 70, 75,
	80, 86, 91, 97, 102, 108, 113, 118, 124, 129, 134, 140, 145, 150,
	156, 161, 167, 172, 178, 183, 189, 194, 200, 206, 211, 217, 222, 228, 233, 239, 244, 250,
	256, 262, 268, 274, 280, 286, 292, 296, 300,
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
	}),
	["Attack Rate"] = table.freeze({
		AttributeName = "AttackRateUpgradeLevel",
		DisplayName = "Attack Rate",
		Description = "Weapon attack rate",
	}),
	Damage = table.freeze({
		AttributeName = "DamageUpgradeLevel",
		DisplayName = "Damage",
		Description = "Weapon damage",
	}),
	Health = table.freeze({
		AttributeName = "HealthUpgradeLevel",
		DisplayName = "Health",
		Description = "Maximum health",
	}),
	["Health Regen"] = table.freeze({
		AttributeName = "HealthRegenUpgradeLevel",
		DisplayName = "Health Regen",
		Description = "Health restored after avoiding damage",
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

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function clampUpgradeRank(rank: number): number
	if not isFinite(rank) then
		return 0
	end
	return math.clamp(math.floor(rank), 0, MAX_UPGRADE_RANK)
end

local function getUpgradeFactor(rank: number): number
	local safeRank = clampUpgradeRank(rank)
	if safeRank <= 0 then
		return 0
	elseif safeRank >= MAX_UPGRADE_RANK then
		return 1
	end

	local normalizedRank = safeRank / MAX_UPGRADE_RANK
	local denominator = math.exp(CURVE_STRENGTH) - 1
	local factor = (math.exp(CURVE_STRENGTH * normalizedRank) - 1) / denominator
	if not isFinite(factor) then
		return 0
	end
	return math.clamp(factor, 0, 1)
end

local function getUpgradeValue(rank: number, rankZeroValue: number, rankThirtyValue: number): number
	local factor = getUpgradeFactor(rank)
	return rankZeroValue + (rankThirtyValue - rankZeroValue) * factor
end

local function clampTrackedLevel(level: number): number
	if not isFinite(level) then
		return 1
	end
	return math.clamp(math.floor(level), 1, MAXIMUM_TRACKED_LEVEL)
end

local function getXPToNextLevel(level: number): number
	local safeLevel = clampTrackedLevel(level)
	if safeLevel >= MAXIMUM_TRACKED_LEVEL then
		return 0
	end
	if safeLevel <= #EARLY_XP_REQUIREMENTS then
		return EARLY_XP_REQUIREMENTS[safeLevel]
	end
	if safeLevel >= POWER_LEVEL_CAP then
		return SCORE_ONLY_XP_PER_LEVEL
	end

	local curveStartLevel = #EARLY_XP_REQUIREMENTS + 1
	local curveEndLevel = POWER_LEVEL_CAP - 1
	local normalizedLevel = (safeLevel - curveStartLevel) / (curveEndLevel - curveStartLevel)
	local requirement = 35 + 15 * normalizedLevel ^ 1.3
	return math.floor(requirement + 0.5)
end

local function getCumulativeXPToReachLevel(level: number): number
	local safeLevel = clampTrackedLevel(level)
	local cappedTarget = math.min(safeLevel, POWER_LEVEL_CAP)
	local total = 0
	for currentLevel = 1, cappedTarget - 1 do
		total += getXPToNextLevel(currentLevel)
	end
	if safeLevel > POWER_LEVEL_CAP then
		total += (safeLevel - POWER_LEVEL_CAP) * SCORE_ONLY_XP_PER_LEVEL
	end
	return total
end

local function getEarnedUpgradePoints(level: number): number
	local safeLevel = math.min(clampTrackedLevel(level), POWER_LEVEL_CAP)
	local points = 0
	for _, grantLevel in UPGRADE_POINT_LEVELS do
		if grantLevel > safeLevel then
			break
		end
		points += 1
	end
	return points
end

local function getSpeedMultiplier(rank: number): number
	return getUpgradeValue(rank, 1, 1.2)
end

local function getAttackRateMultiplier(rank: number): number
	return getUpgradeValue(rank, 1, 0.7)
end

local function getDamageMultiplier(rank: number): number
	return getUpgradeValue(rank, 1, 1.4)
end

local function getHealthBonus(rank: number): number
	return getUpgradeValue(rank, 0, 50)
end

local function getHealthRegenPerSecond(rank: number): number
	return getUpgradeValue(rank, 0, 3)
end

local ProgressionConfig = table.freeze({
	-- LevelCap remains the power-progression boundary for compatibility. RunLevel
	-- continues through MaximumTrackedLevel, but levels above 300 grant score only.
	LevelCap = POWER_LEVEL_CAP,
	PowerLevelCap = POWER_LEVEL_CAP,
	MaximumTrackedLevel = MAXIMUM_TRACKED_LEVEL,
	ScoreOnlyStartLevel = POWER_LEVEL_CAP + 1,
	ScoreOnlyXPPerLevel = SCORE_ONLY_XP_PER_LEVEL,
	StartingUpgradePoints = 1,
	MaxUpgradeRank = MAX_UPGRADE_RANK,
	CurveStrength = CURVE_STRENGTH,
	MaxUnspentUpgradePoints = #UPGRADE_POINT_LEVELS,
	MaxServerXPAward = 10_000,
	MaxRunXP = 180,
	BaseMaxHealth = 100,
	MaxUpgradedMaxHealth = 150,
	HealthRegenDamageDelay = 5,
	HealthRegenTickInterval = 0.1,
	MaxHealthRegenPerSecond = 3,
	UpgradeRequestWindow = 1,
	MaxUpgradeRequestsPerWindow = 8,
	MinimumUpgradeRequestInterval = 0.08,
	MaxBreakableDamagePerHit = 100,
	EarlyXPRequirements = EARLY_XP_REQUIREMENTS,
	UpgradePointLevels = UPGRADE_POINT_LEVELS,
	UpgradeOrder = UPGRADE_ORDER,
	Upgrades = UPGRADES,
	Breakables = BREAKABLES,
	ClampUpgradeRank = clampUpgradeRank,
	GetUpgradeFactor = getUpgradeFactor,
	GetUpgradeValue = getUpgradeValue,
	GetXPToNextLevel = getXPToNextLevel,
	GetCumulativeXPToReachLevel = getCumulativeXPToReachLevel,
	GetEarnedUpgradePoints = getEarnedUpgradePoints,
	GetSpeedMultiplier = getSpeedMultiplier,
	GetAttackRateMultiplier = getAttackRateMultiplier,
	GetDamageMultiplier = getDamageMultiplier,
	GetHealthBonus = getHealthBonus,
	GetHealthRegenPerSecond = getHealthRegenPerSecond,
})

return ProgressionConfig
