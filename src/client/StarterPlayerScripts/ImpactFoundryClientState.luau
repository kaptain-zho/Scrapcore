--!strict

export type State = {
	phase: string,
	attackSerial: number,
	startedAt: number,
	endsAt: number,
	predicted: boolean,
	predictionExpiresAt: number,
}

local idleState: State = {
	phase = "Idle",
	attackSerial = 0,
	startedAt = 0,
	endsAt = 0,
	predicted = false,
	predictionExpiresAt = 0,
}

local currentState = idleState

local ImpactFoundryClientState = {}

function ImpactFoundryClientState.Get(): State
	return currentState
end

function ImpactFoundryClientState.Set(nextState: State)
	currentState = nextState
end

function ImpactFoundryClientState.Clear()
	currentState = idleState
end

return ImpactFoundryClientState
