--!strict

export type State = {
	phase: string,
	attackSerial: number,
	startedAt: number,
	endsAt: number,
	fullChargeTime: number,
	chargeAmount: number,
	dashDirection: Vector3,
	dashSpeed: number,
	predicted: boolean,
	predictionExpiresAt: number,
}

local idleState: State = {
	phase = "Idle",
	attackSerial = 0,
	startedAt = 0,
	endsAt = 0,
	fullChargeTime = 0,
	chargeAmount = 0,
	dashDirection = Vector3.zero,
	dashSpeed = 0,
	predicted = false,
	predictionExpiresAt = 0,
}

local currentState = idleState

local RammerClientState = {}

function RammerClientState.Get(): State
	return currentState
end

function RammerClientState.Set(nextState: State)
	currentState = nextState
end

function RammerClientState.Clear()
	currentState = idleState
end

return RammerClientState
