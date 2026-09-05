--!strict

export type State = {
	phase: string,
	attackSerial: number,
	startedAt: number,
	endsAt: number,
	energy: number,
	output: number,
	predicted: boolean,
	predictionExpiresAt: number,
}

local idleState: State = {
	phase = "Idle",
	attackSerial = 0,
	startedAt = 0,
	endsAt = 0,
	energy = 100,
	output = 0,
	predicted = false,
	predictionExpiresAt = 0,
}

local currentState = idleState
local MotionWorksClientState = {}

function MotionWorksClientState.Get(): State
	return currentState
end

function MotionWorksClientState.Set(nextState: State)
	currentState = nextState
end

function MotionWorksClientState.Clear()
	currentState = idleState
end

return MotionWorksClientState
