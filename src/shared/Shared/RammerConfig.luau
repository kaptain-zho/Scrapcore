--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig = require(shared:WaitForChild("MovementConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))

local FULL_CHARGE_AT_RANK_ZERO = 1.20
local FULL_CHARGE_AT_RANK_THIRTY = 0.84
local COOLDOWN_AT_RANK_ZERO = 1.35
local COOLDOWN_AT_RANK_THIRTY = 0.95
local FULL_DAMAGE_AT_RANK_ZERO = 35
local FULL_DAMAGE_AT_RANK_THIRTY = 45

local function getFullChargeTime(attackRateRank: number): number
	return ProgressionConfig.GetUpgradeValue(
		attackRateRank,
		FULL_CHARGE_AT_RANK_ZERO,
		FULL_CHARGE_AT_RANK_THIRTY
	)
end

local function getCooldown(attackRateRank: number): number
	return ProgressionConfig.GetUpgradeValue(
		attackRateRank,
		COOLDOWN_AT_RANK_ZERO,
		COOLDOWN_AT_RANK_THIRTY
	)
end

local function getFullImpactDamage(damageRank: number): number
	return ProgressionConfig.GetUpgradeValue(
		damageRank,
		FULL_DAMAGE_AT_RANK_ZERO,
		FULL_DAMAGE_AT_RANK_THIRTY
	)
end

local function getChargeAmount(holdDuration: number, fullChargeTime: number): number
	if fullChargeTime <= 0 then
		return 0
	end
	return math.clamp(holdDuration / fullChargeTime, 0, 1)
end

local function getAuthorizedDashSpeed(speedRank: number, chargeAmount: number): number
	local baseSpeed = MovementConfig.MaxSpeed * ProgressionConfig.GetSpeedMultiplier(speedRank)
	local bonus = 8 + (16 - 8) * math.clamp(chargeAmount, 0, 1)
	return math.min(baseSpeed + bonus, 47.2)
end

local RammerConfig = table.freeze({
	-- All Rammer values are provisional Phase 1 playtest tuning.
	MinimumValidHold = 0.20,
	FullChargeAtRankZero = FULL_CHARGE_AT_RANK_ZERO,
	FullChargeAtRankThirty = FULL_CHARGE_AT_RANK_THIRTY,
	CooldownAtRankZero = COOLDOWN_AT_RANK_ZERO,
	CooldownAtRankThirty = COOLDOWN_AT_RANK_THIRTY,
	ChargeMovementSpeedMultiplier = 0.75,
	ChargeSteeringMultiplier = 0.55,
	DashSteeringMultiplier = 0.20,
	DashDuration = 0.45,
	DashPlanarForceMultiplier = 4,
	MinimumDashSpeedBonus = 8,
	FullChargeDashSpeedBonus = 16,
	MaximumAuthorizedDashSpeed = 47.2,
	MinimumImpactDamage = 15,
	FullImpactDamageAtRankZero = FULL_DAMAGE_AT_RANK_ZERO,
	FullImpactDamageAtRankThirty = FULL_DAMAGE_AT_RANK_THIRTY,
	MinimumImpactKnockback = 9,
	FullChargeKnockback = 26,
	MaximumTargetsPerCharge = 1,
	HoldKeepaliveInterval = 0.4,
	HoldLeaseTimeout = 1.25,
	MinimumKeepaliveInterval = 0.2,
	RequestRateWindow = 1,
	MaximumRequestsPerWindow = 12,
	MinimumRequestInterval = 0,
	MaximumSequenceAdvance = 32,
	QueryBoxSize = Vector3.new(5.8, 3.2, 4.6),
	QueryForwardOffset = 1.35,
	DashObstacleProbeDistance = 5,
	MaximumTargetRange = 6.6,
	MaximumVerticalDifference = 4,
	MinimumForwardDot = 0.30,
	MinimumImpactClosingSpeed = 18,
	FullImpactClosingSpeedRatio = 0.90,
	MaximumQueryParts = 96,
	MaximumDashDisplacement = 23.5,
	MaximumDashLateralDisplacement = 5.0,
	MinimumDashDirectionDot = math.cos(math.rad(14)),
	DashSpeedTolerance = 3,
	ChargeSpeedTolerance = 3,
	DashDirectionGracePeriod = 0.18,
	DashAccelerationAllowance = 1800,
	ChargeCancelDuration = 0.16,
	ImpactFeedbackDuration = 0.14,
	MissRecoveryDuration = 0.22,
	PredictionReconcileTimeout = 0.8,
	MaximumBroadcastAge = 2,
	MaximumServerDamage = 45,
	MaximumServerKnockback = 26,
	GetFullChargeTime = getFullChargeTime,
	GetCooldown = getCooldown,
	GetFullImpactDamage = getFullImpactDamage,
	GetChargeAmount = getChargeAmount,
	GetAuthorizedDashSpeed = getAuthorizedDashSpeed,
})

return RammerConfig
