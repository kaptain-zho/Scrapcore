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
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local telemetryRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RobotMovementTelemetry") :: RemoteEvent
local camera = assert(Workspace.CurrentCamera, "CurrentCamera is required for robot controls") :: Camera

local KNOCKBACK_VELOCITY_ATTRIBUTE = "CombatKnockbackVelocity"
local KNOCKBACK_STARTED_AT_ATTRIBUTE = "CombatKnockbackStartedAt"
local KNOCKBACK_UNTIL_ATTRIBUTE = "CombatKnockbackUntil"

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

local function setCharacter(character: Model)
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
		cameraInitialized = false
	end
end

player.CharacterAdded:Connect(function(character: Model)
	task.spawn(setCharacter, character)
end)

player.CharacterRemoving:Connect(function(character: Model)
	if currentRoot ~= nil and currentRoot:IsDescendantOf(character) then
		currentHumanoid = nil
		currentRoot = nil
		currentAimOrientation = nil
		currentMovementVelocity = nil
		smoothedVelocity = Vector3.zero
	end
end)

if player.Character ~= nil then
	task.spawn(setCharacter, player.Character)
end

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
	local rankValue = player:GetAttribute("MobilityUpgradeLevel")
	local rank = if typeof(rankValue) == "number" and isFinite(rankValue)
		then math.clamp(math.floor(rankValue), 0, ProgressionConfig.MaxUpgradeRank)
		else 0
	return MovementConfig.MaxSpeed * ProgressionConfig.GetMobilityMultiplier(rank)
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
	local targetVelocity = moveDirection * currentMaxSpeed
	local movementSharpness = getMovementSharpness(smoothedVelocity, targetVelocity)
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
		movementVelocity.PlaneVelocity = Vector2.new(
			smoothedVelocity.X + knockbackVelocity.X,
			smoothedVelocity.Z + knockbackVelocity.Z
		)
	end

	local aimDirection = getMouseAimDirection(root)
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

	local lookAtPosition = root.Position + Vector3.new(0, MovementConfig.CameraLookAtHeight, 0)
	local desiredCamera = CFrame.lookAt(root.Position + MovementConfig.CameraOffset, lookAtPosition)
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
