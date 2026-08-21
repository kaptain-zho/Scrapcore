--!strict

local MovementConfig = table.freeze({
	MaxSpeed = 26,
	AccelerationSharpness = 7,
	DecelerationSharpness = 10,
	DirectionChangeSharpness = 9,
	AimTurnSharpness = 14,
	AimMaxAngularSpeed = math.rad(540),
	AimMaxTorque = 100000,
	MovementMaxPlanarForce = 50000,
	ClientTelemetryRate = 2,
	MaxTelemetryRate = 5,
	ServerMonitorInterval = 0.1,
	ServerSpeedTolerance = 10,
	ServerMaxAcceleration = 600,
	ServerMaxTeleportDistance = 35,
	ServerViolationSamples = 3,
	ChassisSize = Vector3.new(6, 1.5, 7.2),
	ChassisGroundHeight = 1.5,
	CollisionDensity = 0.7,
	CollisionFriction = 0,
	CollisionElasticity = 0,
	CameraOffset = Vector3.new(0, 34, 26),
	CameraLookAtHeight = 0.5,
	CameraFollowSharpness = 9,
})

return MovementConfig
