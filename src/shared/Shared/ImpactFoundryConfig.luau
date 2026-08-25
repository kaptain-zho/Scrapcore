--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))

local WINDUP_AT_RANK_ZERO = 0.55
local WINDUP_AT_RANK_THIRTY = 0.42
local COOLDOWN_AT_RANK_ZERO = 1.50
local COOLDOWN_AT_RANK_THIRTY = 1.20
local DAMAGE_AT_RANK_ZERO = 38
local DAMAGE_AT_RANK_THIRTY = 50

local function getWindupDuration(attackRateRank: number): number
	return ProgressionConfig.GetUpgradeValue(attackRateRank, WINDUP_AT_RANK_ZERO, WINDUP_AT_RANK_THIRTY)
end

local function getCooldown(attackRateRank: number): number
	return ProgressionConfig.GetUpgradeValue(attackRateRank, COOLDOWN_AT_RANK_ZERO, COOLDOWN_AT_RANK_THIRTY)
end

local function getDamage(damageRank: number): number
	return ProgressionConfig.GetUpgradeValue(damageRank, DAMAGE_AT_RANK_ZERO, DAMAGE_AT_RANK_THIRTY)
end

return table.freeze({
	-- Internal Level 20 prototype tuning. Public selection remains disabled.
	WindupAtRankZero = WINDUP_AT_RANK_ZERO,
	WindupAtRankThirty = WINDUP_AT_RANK_THIRTY,
	CooldownAtRankZero = COOLDOWN_AT_RANK_ZERO,
	CooldownAtRankThirty = COOLDOWN_AT_RANK_THIRTY,
	DamageAtRankZero = DAMAGE_AT_RANK_ZERO,
	DamageAtRankThirty = DAMAGE_AT_RANK_THIRTY,
	ImpactFeedbackDuration = 0.14,
	BreakableDamageMultiplier = 1.75,
	KnockbackSpeed = 25,
	MaximumTargetsPerStrike = 2,
	QueryBoxSize = Vector3.new(5.8, 3.2, 4.6),
	QueryForwardOffset = 1.2,
	MaximumTargetRange = 7.2,
	MaximumVerticalDifference = 4,
	MinimumForwardDot = 0.35,
	MaximumQueryParts = 72,
	WindupMovementSpeedMultiplier = 0.65,
	WindupSteeringMultiplier = 0.60,
	FrontalResistanceMultiplier = 0.45,
	FrontalResistanceMinimumDot = math.cos(math.rad(55)),
	RequestRateWindow = 1,
	MaximumRequestsPerWindow = 6,
	MinimumRequestInterval = 0.10,
	MaximumSequenceAdvance = 32,
	MaximumBroadcastAge = 2,
	MaximumReplicatedPhaseDuration = 1.6,
	PredictionReconcileTimeout = 0.75,
	VisualWindupRetraction = 0.38,
	VisualImpactExtension = 0.62,
	VisualRecoveryRetraction = 0.18,
	GetWindupDuration = getWindupDuration,
	GetCooldown = getCooldown,
	GetDamage = getDamage,
})
