--!strict

local MovementConfig = table.freeze({
	MaxSpeed = 26,
	Acceleration = 70,
	Deceleration = 90,
	TurnSpeedRadians = math.rad(540),
	InputSendRate = 20,
	MaxRemoteRate = 30,
	InputTimeout = 0.3,
	ChassisSize = Vector3.new(5, 1.5, 7),
	CameraOffset = Vector3.new(0, 34, 26),
	CameraLookAtHeight = 0.5,
	CameraFollowSharpness = 9,
})

return MovementConfig
