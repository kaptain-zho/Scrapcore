--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig = require(shared:WaitForChild("MovementConfig"))

type PlayerState = {
	character: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	lastPosition: Vector3,
	lastVelocity: Vector3,
	lastSafeCFrame: CFrame,
	lastSampleAt: number,
	consecutiveViolations: number,
	lastTelemetryAt: number,
	lastSequence: number,
	malformedRequests: number,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes == nil then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local existingRemote = remotes:FindFirstChild("RobotMovementTelemetry")
if existingRemote ~= nil and not existingRemote:IsA("RemoteEvent") then
	error("ReplicatedStorage.Remotes.RobotMovementTelemetry must be a RemoteEvent")
end

local telemetryRemote = existingRemote :: RemoteEvent?
if telemetryRemote == nil then
	telemetryRemote = Instance.new("RemoteEvent")
	telemetryRemote.Name = "RobotMovementTelemetry"
	telemetryRemote.Parent = remotes
end

local playerStates: {[Player]: PlayerState} = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function hideDefaultCharacter(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CastShadow = false
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end
end

local function createChassis(character: Model, root: BasePart)
	local oldChassis = character:FindFirstChild("RobotChassis")
	if oldChassis ~= nil then
		oldChassis:Destroy()
	end

	local chassis = Instance.new("Part")
	chassis.Name = "RobotChassis"
	chassis.Size = MovementConfig.ChassisSize
	chassis.Color = Color3.fromRGB(92, 101, 112)
	chassis.Material = Enum.Material.Metal
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.CanCollide = false
	chassis.Massless = true
	chassis.CFrame = root.CFrame
	chassis.Parent = character

	local chassisWeld = Instance.new("WeldConstraint")
	chassisWeld.Part0 = root
	chassisWeld.Part1 = chassis
	chassisWeld.Parent = chassis

	local frontIndicator = Instance.new("Part")
	frontIndicator.Name = "FrontIndicator"
	frontIndicator.Size = Vector3.new(MovementConfig.ChassisSize.X * 0.6, 0.25, 0.5)
	frontIndicator.Color = Color3.fromRGB(238, 168, 64)
	frontIndicator.Material = Enum.Material.Neon
	frontIndicator.CanCollide = false
	frontIndicator.Massless = true
	frontIndicator.CFrame = root.CFrame * CFrame.new(0, MovementConfig.ChassisSize.Y * 0.5 + 0.2, -MovementConfig.ChassisSize.Z * 0.5 + 0.35)
	frontIndicator.Parent = character

	local indicatorWeld = Instance.new("WeldConstraint")
	indicatorWeld.Part0 = chassis
	indicatorWeld.Part1 = frontIndicator
	indicatorWeld.Parent = frontIndicator
end

local function configureCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") or root == nil or not root:IsA("BasePart") then
		warn(string.format("Unable to configure robot character for %s", player.Name))
		return
	end

	hideDefaultCharacter(character)
	createChassis(character, root)

	humanoid.AutoRotate = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	local now = os.clock()
	playerStates[player] = {
		character = character,
		humanoid = humanoid,
		root = root,
		lastPosition = root.Position,
		lastVelocity = Vector3.zero,
		lastSafeCFrame = root.CFrame,
		lastSampleAt = now,
		consecutiveViolations = 0,
		lastTelemetryAt = 0,
		lastSequence = 0,
		malformedRequests = 0,
	}
end

local function connectPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		task.spawn(configureCharacter, player, character)
	end)

	if player.Character ~= nil then
		task.spawn(configureCharacter, player, player.Character)
	end
end

-- Telemetry is intentionally sparse and grants no gameplay authority. Future weapon hits,
-- damage, cooldowns, and rewards must be validated and resolved by the server.
telemetryRemote.OnServerEvent:Connect(function(player: Player, sequenceValue: unknown, extraValue: unknown)
	local state = playerStates[player]
	if state == nil then
		return
	end

	local receivedAt = os.clock()
	if receivedAt - state.lastTelemetryAt < 1 / MovementConfig.MaxTelemetryRate then
		state.malformedRequests += 1
		return
	end
	state.lastTelemetryAt = receivedAt

	if typeof(sequenceValue) ~= "number" or extraValue ~= nil then
		state.malformedRequests += 1
		return
	end

	local sequence = sequenceValue :: number
	if not isFinite(sequence) or sequence % 1 ~= 0 or sequence <= state.lastSequence then
		state.malformedRequests += 1
		return
	end

	state.lastSequence = sequence
end)

Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(function(player: Player)
	playerStates[player] = nil
end)

for _, player in Players:GetPlayers() do
	connectPlayer(player)
end

local monitorAccumulator = 0

RunService.Heartbeat:Connect(function(deltaTime: number)
	monitorAccumulator += deltaTime
	if monitorAccumulator < MovementConfig.ServerMonitorInterval then
		return
	end
	monitorAccumulator %= MovementConfig.ServerMonitorInterval

	local now = os.clock()
	for _, state in playerStates do
		local character = state.character
		local humanoid = state.humanoid
		local root = state.root
		if character == nil or humanoid == nil or root == nil or character.Parent == nil or humanoid.Health <= 0 then
			continue
		end

		local elapsed = math.max(now - state.lastSampleAt, MovementConfig.ServerMonitorInterval)
		local position = root.Position
		local planarPosition = Vector3.new(position.X, 0, position.Z)
		local previousPlanarPosition = Vector3.new(state.lastPosition.X, 0, state.lastPosition.Z)
		local planarVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
		local distance = (planarPosition - previousPlanarPosition).Magnitude
		local measuredSpeed = distance / elapsed
		local physicalSpeed = planarVelocity.Magnitude
		local measuredAcceleration = (planarVelocity - state.lastVelocity).Magnitude / elapsed

		local teleported = distance > MovementConfig.ServerMaxTeleportDistance
		local exceededSpeed = math.max(measuredSpeed, physicalSpeed) > MovementConfig.MaxSpeed + MovementConfig.ServerSpeedTolerance
		local exceededAcceleration = measuredAcceleration > MovementConfig.ServerMaxAcceleration
		local violatedMovementLimit = teleported or exceededSpeed or exceededAcceleration

		if violatedMovementLimit then
			state.consecutiveViolations += 1
		else
			state.consecutiveViolations = 0
			state.lastSafeCFrame = root.CFrame
		end

		local shouldCorrect = teleported or state.consecutiveViolations >= MovementConfig.ServerViolationSamples
		if shouldCorrect then
			character:PivotTo(state.lastSafeCFrame)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			state.lastPosition = state.lastSafeCFrame.Position
			state.lastVelocity = Vector3.zero
			state.consecutiveViolations = 0
		else
			state.lastPosition = position
			state.lastVelocity = planarVelocity
		end
		state.lastSampleAt = now
	end
end)
