--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))

local SPIN_UP_AT_RANK_ZERO = 0.40
local SPIN_UP_AT_RANK_THIRTY = 0.28
local PULSE_INTERVAL_AT_RANK_ZERO = 0.32
local PULSE_INTERVAL_AT_RANK_THIRTY = 0.24
local PULSE_DAMAGE_AT_RANK_ZERO = 7
local PULSE_DAMAGE_AT_RANK_THIRTY = 10

local function getSpinUpDuration(attackRateRank: number): number
	return ProgressionConfig.GetUpgradeValue(
		attackRateRank,
		SPIN_UP_AT_RANK_ZERO,
		SPIN_UP_AT_RANK_THIRTY
	)
end

local function getPulseInterval(attackRateRank: number): number
	return ProgressionConfig.GetUpgradeValue(
		attackRateRank,
		PULSE_INTERVAL_AT_RANK_ZERO,
		PULSE_INTERVAL_AT_RANK_THIRTY
	)
end

local function getPulseDamage(damageRank: number): number
	return ProgressionConfig.GetUpgradeValue(
		damageRank,
		PULSE_DAMAGE_AT_RANK_ZERO,
		PULSE_DAMAGE_AT_RANK_THIRTY
	)
end

local SpinnerConfig = table.freeze({
	-- All Spinner balance values are provisional Phase 1 playtest tuning.
	MaxUpgradeRank = ProgressionConfig.MaxUpgradeRank,
	SpinUpAtRankZero = SPIN_UP_AT_RANK_ZERO,
	SpinUpAtRankThirty = SPIN_UP_AT_RANK_THIRTY,
	PulseIntervalAtRankZero = PULSE_INTERVAL_AT_RANK_ZERO,
	PulseIntervalAtRankThirty = PULSE_INTERVAL_AT_RANK_THIRTY,
	PulseDamageAtRankZero = PULSE_DAMAGE_AT_RANK_ZERO,
	PulseDamageAtRankThirty = PULSE_DAMAGE_AT_RANK_THIRTY,
	SpinnerBreakableDamageMultiplier = 1.50,
	SpinDownDuration = 0.28,
	PostSpinCooldown = 1.1,
	HoldKeepaliveInterval = 0.4,
	HoldLeaseTimeout = 1.25,
	PulseKnockbackSpeed = 2.5,
	MaximumTargetsPerPulse = 6,
	QueryRadius = 4.8,
	MaximumTargetRange = 5.8,
	MaximumVerticalDifference = 4,
	MinimumForwardDot = -0.15,
	MaximumQueryParts = 96,
	MaximumCatchUpPulsesPerHeartbeat = 2,
	RequestRateWindow = 1,
	MaximumRequestsPerWindow = 12,
	MinimumRequestInterval = 0,
	MinimumKeepaliveInterval = 0.2,
	MaximumSequenceAdvance = 32,
	MaximumBroadcastAge = 2,
	PredictionReconcileTimeout = 0.75,
	ActiveAngularSpeed = math.rad(900),
	GetSpinUpDuration = getSpinUpDuration,
	GetPulseInterval = getPulseInterval,
	GetPulseDamage = getPulseDamage,
})

return SpinnerConfig
