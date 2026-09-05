--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig = require(shared:WaitForChild("MovementConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))

local SPOOL_AT_RANK_ZERO = 0.62
local SPOOL_AT_RANK_THIRTY = 0.46
local PULSE_INTERVAL_AT_RANK_ZERO = 0.34
local PULSE_INTERVAL_AT_RANK_THIRTY = 0.26
local RECOVERY_AT_RANK_ZERO = 1.20
local RECOVERY_AT_RANK_THIRTY = 0.92
local DAMAGE_AT_RANK_ZERO = 9
local DAMAGE_AT_RANK_THIRTY = 13

local function getSpoolDuration(attackRateRank: number): number
	return ProgressionConfig.GetUpgradeValue(attackRateRank, SPOOL_AT_RANK_ZERO, SPOOL_AT_RANK_THIRTY)
end

local function getPulseInterval(attackRateRank: number): number
	return ProgressionConfig.GetUpgradeValue(
		attackRateRank,
		PULSE_INTERVAL_AT_RANK_ZERO,
		PULSE_INTERVAL_AT_RANK_THIRTY
	)
end

local function getRecoveryDuration(attackRateRank: number): number
	return ProgressionConfig.GetUpgradeValue(
		attackRateRank,
		RECOVERY_AT_RANK_ZERO,
		RECOVERY_AT_RANK_THIRTY
	)
end

local function getPulseDamage(damageRank: number): number
	return ProgressionConfig.GetUpgradeValue(damageRank, DAMAGE_AT_RANK_ZERO, DAMAGE_AT_RANK_THIRTY)
end

local function getNormalMaxSpeed(speedRank: number): number
	return MovementConfig.MaxSpeed * ProgressionConfig.GetSpeedMultiplier(speedRank)
end

local function getDrivenSpeed(speedRank: number, output: number): number
	local alpha = math.clamp(output, 0, 1)
	local multiplier = 0.72 + (1.32 - 0.72) * alpha
	return getNormalMaxSpeed(speedRank) * multiplier
end

local function getDrivenSteeringMultiplier(output: number): number
	return 0.85 + (0.40 - 0.85) * math.clamp(output, 0, 1)
end

local function getDirectionalSpeedLimit(speedRank: number, output: number, forwardDot: number): number
	local normal = getNormalMaxSpeed(speedRank)
	local driven = getDrivenSpeed(speedRank, output)
	-- Reverse/side motion never inherits the forward drive bonus.
	return math.min(driven, normal + math.max(driven - normal, 0) * math.clamp(forwardDot, 0, 1))
end

return table.freeze({
	-- Internal Level 20 prototype tuning. Public Level 20 selection remains disabled.
	SpoolAtRankZero = SPOOL_AT_RANK_ZERO,
	SpoolAtRankThirty = SPOOL_AT_RANK_THIRTY,
	PulseIntervalAtRankZero = PULSE_INTERVAL_AT_RANK_ZERO,
	PulseIntervalAtRankThirty = PULSE_INTERVAL_AT_RANK_THIRTY,
	RecoveryAtRankZero = RECOVERY_AT_RANK_ZERO,
	RecoveryAtRankThirty = RECOVERY_AT_RANK_THIRTY,
	DamageAtRankZero = DAMAGE_AT_RANK_ZERO,
	DamageAtRankThirty = DAMAGE_AT_RANK_THIRTY,
	MaximumEnergy = 100,
	MinimumStartEnergy = 20,
	EnergyDrainPerSecond = 28,
	EnergyRechargePerSecond = 24,
	OutputRampDuration = 1.10,
	CoastdownDuration = 0.42,
	SpoolMovementSpeedMultiplier = 0.72,
	SpoolSteeringMultiplier = 0.68,
	CoastMovementSpeedMultiplier = 0.82,
	DrivenMinimumSpeedMultiplier = 0.72,
	DrivenMaximumSpeedMultiplier = 1.32,
	DrivenMinimumSteeringMultiplier = 0.40,
	DrivenMaximumSteeringMultiplier = 0.85,
	MinimumObservedForwardSpeed = 8,
	FullOutputObservedForwardSpeed = 32,
	MinimumDrivenDirectionDot = 0.48,
	ForwardInputDeadzone = 0.10,
	MaximumTargetsPerPulse = 2,
	MaximumQueryParts = 64,
	QueryBoxSize = Vector3.new(4.4, 2.8, 3.8),
	QueryForwardOffset = 1.05,
	MaximumTargetRange = 6.1,
	MaximumVerticalDifference = 3.8,
	MinimumForwardTargetDot = 0.52,
	PulseKnockbackSpeed = 5,
	BreakableDamageMultiplier = 1.50,
	MaximumServerPulseDamage = 13,
	MaximumMovementAcceleration = 760,
	MaximumSampleDistance = 6.5,
	MaximumSampleInterval = 0.50,
	MovementSpeedTolerance = 6,
	MaximumDrivenTurnRate = math.rad(420),
	TurnDirectionGrace = math.rad(12),
	-- Stop before the 3.6-stud chassis half-length contacts a solid wall.
	-- The extra margin absorbs prediction/physics settling without changing hit range.
	ObstacleProbeDistance = 5.0,
	-- This prototype runs on the flat arena; spawn platforms are one stud high.
	MinimumRootHeightAboveFloor = 0.2,
	MaximumRootHeightAboveFloor = 3.0,
	MaximumVerticalSpeed = 40,
	MaximumEnergyStep = 0.2,
	HoldKeepaliveInterval = 0.40,
	MinimumKeepaliveInterval = 0.18,
	HoldLeaseTimeout = 1.25,
	RequestRateWindow = 1,
	MaximumRequestsPerWindow = 9,
	MinimumRequestInterval = 0.06,
	MaximumSequenceAdvance = 32,
	MaximumBroadcastAge = 8,
	MaximumReplicatedPhaseDuration = 2,
	StateReplicationInterval = 0.10,
	MaximumCatchUpPulsesPerHeartbeat = 2,
	PredictionReconcileTimeout = 0.85,
	ActiveRollerAngularSpeed = math.rad(820),
	CoastRollerAngularSpeed = math.rad(420),
	VisualCarriageTravel = 0.32,
	GetSpoolDuration = getSpoolDuration,
	GetPulseInterval = getPulseInterval,
	GetRecoveryDuration = getRecoveryDuration,
	GetPulseDamage = getPulseDamage,
	GetNormalMaxSpeed = getNormalMaxSpeed,
	GetDrivenSpeed = getDrivenSpeed,
	GetDirectionalSpeedLimit = getDirectionalSpeedLimit,
	GetDrivenSteeringMultiplier = getDrivenSteeringMultiplier,
})
