--!strict

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig = require(shared:WaitForChild("MovementConfig"))
local CombatConfig = require(shared:WaitForChild("CombatConfig"))
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local RammerConfig = require(shared:WaitForChild("RammerConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local RammerClientState = require(script.Parent:WaitForChild("RammerClientState"))
local telemetryRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RobotMovementTelemetry") :: RemoteEvent
local camera = assert(Workspace.CurrentCamera, "CurrentCamera is required for robot controls") :: Camera

local KNOCKBACK_VELOCITY_ATTRIBUTE = "CombatKnockbackVelocity"
local KNOCKBACK_STARTED_AT_ATTRIBUTE = "CombatKnockbackStartedAt"
local KNOCKBACK_UNTIL_ATTRIBUTE = "CombatKnockbackUntil"
local CAMERA_ORBIT_ACTION_NAME = "RobotCameraOrbit"

local function sinkDefaultMovement(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
	"SinkDefaultRobotMovement",
	sinkDefaultMovement,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Space
)
camera.CameraType = Enum.CameraType.Scriptable

local currentHumanoid: Humanoid? = nil
local currentRoot: BasePart? = nil
local currentAimOrientation: AlignOrientation? = nil
local currentMovementVelocity: LinearVelocity? = nil
local smoothedVelocity = Vector3.zero
local cameraInitialized = false
local telemetryAccumulator = 0
local telemetrySequence = 0
local cameraYaw = 0
local targetCameraYaw = 0
local cameraZoomScale = 1
local targetCameraZoomScale = 1
local isCameraOrbitDragging = false
local previousMouseBehavior: Enum.MouseBehavior? = nil
local humanoidDiedConnection: RBXScriptConnection? = nil
local lastRammerDashSerial = 0
local lastCameraRootPosition: Vector3? = nil

local function wrapAngle(angle: number): number
	return math.atan2(math.sin(angle), math.cos(angle))
end

local function releaseCameraOrbit()
	if not isCameraOrbitDragging and previousMouseBehavior == nil then
		return
	end
	isCameraOrbitDragging = false
	local mouseBehavior = previousMouseBehavior
	previousMouseBehavior = nil
	UserInputService.MouseBehavior = if mouseBehavior ~= nil
		then mouseBehavior
		else Enum.MouseBehavior.Default
end

local function beginCameraOrbit()
	if isCameraOrbitDragging or not script.Enabled then
		return
	end
	previousMouseBehavior = UserInputService.MouseBehavior
	isCameraOrbitDragging = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
end

local function handleCameraOrbitAction(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		beginCameraOrbit()
		return if isCameraOrbitDragging
			then Enum.ContextActionResult.Sink
			else Enum.ContextActionResult.Pass
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		releaseCameraOrbit()
		return Enum.ContextActionResult.Sink
	end
	return if isCameraOrbitDragging
		then Enum.ContextActionResult.Sink
		else Enum.ContextActionResult.Pass
end

local function setCharacter(character: Model)
	releaseCameraOrbit()
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if humanoid ~= nil and humanoid:IsA("Humanoid") and root ~= nil and root:IsA("BasePart") then
		humanoid.AutoRotate = false

		local oldAimAttachment = root:FindFirstChild("RobotAimAttachment")
		if oldAimAttachment ~= nil then
			oldAimAttachment:Destroy()
		end
		local oldAimOrientation = root:FindFirstChild("RobotAimOrientation")
		if oldAimOrientation ~= nil then
			oldAimOrientation:Destroy()
		end

		local aimAttachment = Instance.new("Attachment")
		aimAttachment.Name = "RobotAimAttachment"
		aimAttachment.Parent = root

		local aimOrientation = Instance.new("AlignOrientation")
		aimOrientation.Name = "RobotAimOrientation"
		aimOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		aimOrientation.Attachment0 = aimAttachment
		aimOrientation.MaxTorque = MovementConfig.AimMaxTorque
		aimOrientation.MaxAngularVelocity = MovementConfig.AimMaxAngularSpeed
		aimOrientation.Responsiveness = MovementConfig.AimTurnSharpness
		aimOrientation.RigidityEnabled = false
		aimOrientation.ReactionTorqueEnabled = false
		aimOrientation.CFrame = CFrame.lookAt(Vector3.zero, root.CFrame.LookVector)
		aimOrientation.Parent = root

		local movementVelocity = Instance.new("LinearVelocity")
		movementVelocity.Name = "RobotMovementVelocity"
		movementVelocity.Attachment0 = aimAttachment
		movementVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		movementVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		movementVelocity.PrimaryTangentAxis = Vector3.xAxis
		movementVelocity.SecondaryTangentAxis = Vector3.zAxis
		movementVelocity.PlaneVelocity = Vector2.zero
		movementVelocity.ForceLimitsEnabled = true
		movementVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		movementVelocity.MaxPlanarAxesForce = Vector2.new(
			MovementConfig.MovementMaxPlanarForce,
			MovementConfig.MovementMaxPlanarForce
		)
		movementVelocity.ReactionForceEnabled = false
		movementVelocity.Parent = root

		currentHumanoid = humanoid
		currentRoot = root
		currentAimOrientation = aimOrientation
		currentMovementVelocity = movementVelocity
		smoothedVelocity = Vector3.zero
		lastRammerDashSerial = 0
		cameraInitialized = false
		lastCameraRootPosition = nil
		if humanoidDiedConnection ~= nil then
			humanoidDiedConnection:Disconnect()
		end
		humanoidDiedConnection = humanoid.Died:Connect(releaseCameraOrbit)
	end
end

player.CharacterAdded:Connect(function(character: Model)
	task.spawn(setCharacter, character)
end)

player.CharacterRemoving:Connect(function(character: Model)
	if currentRoot ~= nil and currentRoot:IsDescendantOf(character) then
		releaseCameraOrbit()
		if humanoidDiedConnection ~= nil then
			humanoidDiedConnection:Disconnect()
			humanoidDiedConnection = nil
		end
		currentHumanoid = nil
		currentRoot = nil
		currentAimOrientation = nil
		currentMovementVelocity = nil
		smoothedVelocity = Vector3.zero
		lastRammerDashSerial = 0
		lastCameraRootPosition = nil
	end
end)

player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(function()
	cameraInitialized = false
	lastCameraRootPosition = nil
	smoothedVelocity = Vector3.zero
	lastRammerDashSerial = 0
end)

if player.Character ~= nil then
	task.spawn(setCharacter, player.Character)
end

ContextActionService:BindActionAtPriority(
	CAMERA_ORBIT_ACTION_NAME,
	handleCameraOrbitAction,
	false,
	MovementConfig.CameraOrbitActionPriority,
	Enum.UserInputType.MouseButton2
)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		targetCameraZoomScale = math.clamp(
			targetCameraZoomScale - input.Position.Z * MovementConfig.CameraZoomWheelStep,
			MovementConfig.CameraMinZoomScale,
			MovementConfig.CameraMaxZoomScale
		)
	end
end)

UserInputService.WindowFocusReleased:Connect(releaseCameraOrbit)
script:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not script.Enabled then
		releaseCameraOrbit()
	end
end)
script.Destroying:Connect(function()
	releaseCameraOrbit()
	ContextActionService:UnbindAction(CAMERA_ORBIT_ACTION_NAME)
	ContextActionService:UnbindAction("SinkDefaultRobotMovement")
end)

local function getKeyboardAxes(): (number, number)
	local horizontal = 0
	local vertical = 0

	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		horizontal -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		horizontal += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		vertical += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		vertical -= 1
	end

	return horizontal, vertical
end

local function getCameraRelativeMovement(): Vector3
	local horizontal, vertical = getKeyboardAxes()
	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	if forward.Magnitude <= 0 or right.Magnitude <= 0 then
		return Vector3.zero
	end

	local movement = right.Unit * horizontal + forward.Unit * vertical
	return if movement.Magnitude > 1 then movement.Unit else movement
end

local function getMouseAimDirection(root: BasePart): Vector3
	local mousePosition = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
	if math.abs(ray.Direction.Y) < 0.001 then
		return root.CFrame.LookVector
	end

	local distance = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
	if distance <= 0 then
		return root.CFrame.LookVector
	end

	local hitPosition = ray.Origin + ray.Direction * distance
	local aimDirection = Vector3.new(hitPosition.X - root.Position.X, 0, hitPosition.Z - root.Position.Z)
	return if aimDirection.Magnitude > 0.001 then aimDirection.Unit else root.CFrame.LookVector
end

local function getMovementSharpness(currentVelocity: Vector3, targetVelocity: Vector3): number
	if targetVelocity.Magnitude < currentVelocity.Magnitude then
		return MovementConfig.DecelerationSharpness
	end

	if currentVelocity.Magnitude > 0.01 and targetVelocity.Magnitude > 0.01 then
		local alignment = currentVelocity.Unit:Dot(targetVelocity.Unit)
		if alignment < 0.99 then
			return MovementConfig.DirectionChangeSharpness
		end
	end

	return MovementConfig.AccelerationSharpness
end

local function rotateTowardAim(aimDirection: Vector3)
	local aimOrientation = currentAimOrientation
	if aimOrientation == nil then
		return
	end
	aimOrientation.CFrame = CFrame.lookAt(Vector3.zero, aimDirection)
end

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getCurrentMaxSpeed(): number
	local rankValue = player:GetAttribute("SpeedUpgradeLevel")
	local rank = if typeof(rankValue) == "number" and isFinite(rankValue)
		then math.clamp(math.floor(rankValue), 0, ProgressionConfig.MaxUpgradeRank)
		else 0
	return MovementConfig.MaxSpeed * ProgressionConfig.GetSpeedMultiplier(rank)
end

local function getCurrentClassId(): string
	local classValue = player:GetAttribute(ClassConfig.ClassAttribute)
	return if typeof(classValue) == "string" then classValue else ClassConfig.BaseClassId
end

local function isDashPathBlocked(root: BasePart, direction: Vector3): boolean
	local character = root.Parent
	if character == nil then
		return false
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true
	local result = Workspace:Raycast(
		root.Position + Vector3.new(0, 0.2, 0),
		direction * RammerConfig.DashObstacleProbeDistance,
		raycastParams
	)
	if result == nil or not result.Instance:IsA("BasePart") or not result.Instance.CanCollide then
		return false
	end
	local current: Instance? = result.Instance
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("BreakableActive") == true then
			return false
		end
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") ~= nil then
			return false
		end
		current = current.Parent
	end
	return true
end

local function getAuthorizedKnockback(root: BasePart): Vector3
	local character = root.Parent
	if character == nil then
		return Vector3.zero
	end
	local velocityValue = character:GetAttribute(KNOCKBACK_VELOCITY_ATTRIBUTE)
	local startedAtValue = character:GetAttribute(KNOCKBACK_STARTED_AT_ATTRIBUTE)
	local untilValue = character:GetAttribute(KNOCKBACK_UNTIL_ATTRIBUTE)
	if typeof(velocityValue) ~= "Vector3" or typeof(startedAtValue) ~= "number" or typeof(untilValue) ~= "number" then
		return Vector3.zero
	end

	local velocity = velocityValue :: Vector3
	local startedAt = startedAtValue :: number
	local untilTime = untilValue :: number
	if
		not isFinite(velocity.X)
		or not isFinite(velocity.Y)
		or not isFinite(velocity.Z)
		or not isFinite(startedAt)
		or not isFinite(untilTime)
		or velocity.Magnitude > CombatConfig.MaxHorizontalKnockbackSpeed + 0.01
		or untilTime - startedAt > CombatConfig.KnockbackDuration + 0.01
	then
		return Vector3.zero
	end

	local now = Workspace:GetServerTimeNow()
	local alpha = math.clamp((now - startedAt) / math.max(untilTime - startedAt, 0.001), 0, 1)
	return if now <= untilTime then velocity * (1 - alpha) else Vector3.zero
end

local function updateMovement(deltaTime: number)
	local humanoid = currentHumanoid
	local root = currentRoot
	if humanoid == nil or root == nil or root.Parent == nil or humanoid.Health <= 0 then
		return
	end

	local moveDirection = getCameraRelativeMovement()
	local currentMaxSpeed = getCurrentMaxSpeed()
	local rammerState = RammerClientState.Get()
	local isRammer = getCurrentClassId() == ClassConfig.RammerClassId
	local isCharging = isRammer and (rammerState.phase == "Charging" or rammerState.phase == "Ready")
	local isDashing = isRammer
		and rammerState.phase == "Dash"
		and Workspace:GetServerTimeNow() <= rammerState.endsAt
		and rammerState.dashDirection.Magnitude > 0.01
		and rammerState.dashSpeed > 0
	local targetVelocity: Vector3
	if isDashing then
		local dashDirection = Vector3.new(
			rammerState.dashDirection.X,
			0,
			rammerState.dashDirection.Z
		).Unit
		local lateralInput = moveDirection - dashDirection * moveDirection:Dot(dashDirection)
		local steeredDirection = dashDirection
		if lateralInput.Magnitude > 0.01 then
			steeredDirection = (dashDirection + lateralInput.Unit * RammerConfig.DashSteeringMultiplier).Unit
		end
		currentMaxSpeed = math.min(rammerState.dashSpeed, RammerConfig.MaximumAuthorizedDashSpeed)
		local blocked = isDashPathBlocked(root, dashDirection)
		targetVelocity = if blocked then Vector3.zero else steeredDirection * currentMaxSpeed
		if blocked then
			smoothedVelocity = Vector3.zero
		end
		if lastRammerDashSerial ~= rammerState.attackSerial then
			smoothedVelocity = targetVelocity
			lastRammerDashSerial = rammerState.attackSerial
		end
	else
		if isCharging then
			currentMaxSpeed *= RammerConfig.ChargeMovementSpeedMultiplier
		end
		targetVelocity = moveDirection * currentMaxSpeed
		lastRammerDashSerial = 0
	end
	local movementSharpness = getMovementSharpness(smoothedVelocity, targetVelocity)
	if isCharging then
		movementSharpness *= RammerConfig.ChargeSteeringMultiplier
	end
	local movementAlpha = 1 - math.exp(-movementSharpness * deltaTime)
	smoothedVelocity = smoothedVelocity:Lerp(targetVelocity, movementAlpha)
	if smoothedVelocity.Magnitude < 0.01 then
		smoothedVelocity = Vector3.zero
	end

	local speed = math.min(smoothedVelocity.Magnitude, currentMaxSpeed)
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = speed
	humanoid:Move(if speed > 0 then smoothedVelocity.Unit else Vector3.zero, false)
	local movementVelocity = currentMovementVelocity
	local knockbackVelocity = getAuthorizedKnockback(root)
	if movementVelocity ~= nil then
		local planarForce = MovementConfig.MovementMaxPlanarForce
			* (if isDashing then RammerConfig.DashPlanarForceMultiplier else 1)
		movementVelocity.MaxPlanarAxesForce = Vector2.new(planarForce, planarForce)
		movementVelocity.PlaneVelocity = Vector2.new(
			smoothedVelocity.X + knockbackVelocity.X,
			smoothedVelocity.Z + knockbackVelocity.Z
		)
	end

	local aimDirection = getMouseAimDirection(root)
	local aimOrientation = currentAimOrientation
	if aimOrientation ~= nil then
		aimOrientation.Responsiveness = MovementConfig.AimTurnSharpness
			* (if isDashing
				then RammerConfig.DashSteeringMultiplier
				elseif isCharging then RammerConfig.ChargeSteeringMultiplier
				else 1)
	end
	rotateTowardAim(aimDirection)

	telemetryAccumulator += deltaTime
	local telemetryInterval = 1 / MovementConfig.ClientTelemetryRate
	if telemetryAccumulator >= telemetryInterval then
		telemetryAccumulator %= telemetryInterval
		telemetrySequence += 1
		telemetryRemote:FireServer(telemetrySequence)
	end
end

local function updateCamera(deltaTime: number)
	local activeCamera = Workspace.CurrentCamera
	if activeCamera == nil then
		return
	end
	camera = activeCamera
	camera.CameraType = Enum.CameraType.Scriptable

	local root = currentRoot
	if root == nil or root.Parent == nil then
		return
	end
	if
		lastCameraRootPosition ~= nil
		and (root.Position - (lastCameraRootPosition :: Vector3)).Magnitude
			> MovementConfig.ServerMaxTeleportDistance
	then
		cameraInitialized = false
	end
	lastCameraRootPosition = root.Position

	if isCameraOrbitDragging then
		local mouseDelta = UserInputService:GetMouseDelta()
		targetCameraYaw = wrapAngle(
			targetCameraYaw - mouseDelta.X * MovementConfig.CameraOrbitDragSensitivity
		)
	end

	local orbitAlpha = 1 - math.exp(-MovementConfig.CameraOrbitSharpness * deltaTime)
	local yawDelta = wrapAngle(targetCameraYaw - cameraYaw)
	cameraYaw = wrapAngle(cameraYaw + yawDelta * orbitAlpha)
	local zoomAlpha = 1 - math.exp(-MovementConfig.CameraZoomSharpness * deltaTime)
	cameraZoomScale += (targetCameraZoomScale - cameraZoomScale) * zoomAlpha

	local lookAtPosition = root.Position + Vector3.new(0, MovementConfig.CameraLookAtHeight, 0)
	local scaledOffset = MovementConfig.CameraOffset * cameraZoomScale
	local orbitOffset = CFrame.Angles(0, cameraYaw, 0):VectorToWorldSpace(scaledOffset)
	local cameraPosition = root.Position + orbitOffset
	cameraPosition = Vector3.new(
		cameraPosition.X,
		math.max(cameraPosition.Y, root.Position.Y + MovementConfig.CameraMinimumHeight),
		cameraPosition.Z
	)
	local desiredCamera = CFrame.lookAt(cameraPosition, lookAtPosition)
	if not cameraInitialized then
		camera.CFrame = desiredCamera
		cameraInitialized = true
	else
		local followAlpha = 1 - math.exp(-MovementConfig.CameraFollowSharpness * deltaTime)
		camera.CFrame = camera.CFrame:Lerp(desiredCamera, followAlpha)
	end
end

local hasRenderedFrame = false

RunService.PreSimulation:Connect(updateMovement)
RunService.PreRender:Connect(function(deltaTime: number)
	hasRenderedFrame = true
	updateCamera(deltaTime)
end)
RunService.Heartbeat:Connect(function(deltaTime: number)
	if not hasRenderedFrame then
		updateCamera(deltaTime)
	end
end)
