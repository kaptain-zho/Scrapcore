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
	moveDirection: Vector3,
	aimDirection: Vector3,
	currentSpeed: number,
	lastInputAt: number,
	lastRemoteAt: number,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes == nil then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local existingRemote = remotes:FindFirstChild("RobotMovementInput")
if existingRemote ~= nil and not existingRemote:IsA("RemoteEvent") then
	error("ReplicatedStorage.Remotes.RobotMovementInput must be a RemoteEvent")
end

local movementRemote = existingRemote :: RemoteEvent?
if movementRemote == nil then
	movementRemote = Instance.new("RemoteEvent")
	movementRemote.Name = "RobotMovementInput"
	movementRemote.Parent = remotes
end

local playerStates: {[Player]: PlayerState} = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isFiniteVector(vector: Vector3): boolean
	return isFinite(vector.X) and isFinite(vector.Y) and isFinite(vector.Z)
end

local function moveTowards(current: number, target: number, maximumDelta: number): number
	if current < target then
		return math.min(current + maximumDelta, target)
	end

	return math.max(current - maximumDelta, target)
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

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant:SetNetworkOwner(nil)
		end
	end

	playerStates[player] = {
		character = character,
		humanoid = humanoid,
		root = root,
		moveDirection = Vector3.zero,
		aimDirection = Vector3.new(0, 0, -1),
		currentSpeed = 0,
		lastInputAt = 0,
		lastRemoteAt = 0,
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

movementRemote.OnServerEvent:Connect(function(player: Player, moveDirectionValue: unknown, aimDirectionValue: unknown)
	local state = playerStates[player]
	if state == nil then
		return
	end

	local receivedAt = os.clock()
	if receivedAt - state.lastRemoteAt < 1 / MovementConfig.MaxRemoteRate then
		return
	end
	state.lastRemoteAt = receivedAt

	if typeof(moveDirectionValue) ~= "Vector3" or typeof(aimDirectionValue) ~= "Vector3" then
		return
	end

	local moveDirection = moveDirectionValue :: Vector3
	local aimDirection = aimDirectionValue :: Vector3
	if not isFiniteVector(moveDirection) or not isFiniteVector(aimDirection) then
		return
	end

	moveDirection = Vector3.new(moveDirection.X, 0, moveDirection.Z)
	aimDirection = Vector3.new(aimDirection.X, 0, aimDirection.Z)
	if moveDirection.Magnitude > 1.05 or aimDirection.Magnitude < 0.95 or aimDirection.Magnitude > 1.05 then
		return
	end

	state.moveDirection = if moveDirection.Magnitude > 0 then moveDirection.Unit * math.min(moveDirection.Magnitude, 1) else Vector3.zero
	state.aimDirection = aimDirection.Unit
	state.lastInputAt = receivedAt
end)

Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(function(player: Player)
	playerStates[player] = nil
end)

for _, player in Players:GetPlayers() do
	connectPlayer(player)
end

RunService.Heartbeat:Connect(function(deltaTime: number)
	local now = os.clock()

	for player, state in playerStates do
		local character = state.character
		local humanoid = state.humanoid
		local root = state.root
		if character == nil or humanoid == nil or root == nil or character.Parent == nil or humanoid.Health <= 0 then
			continue
		end

		local moveDirection = state.moveDirection
		if now - state.lastInputAt > MovementConfig.InputTimeout then
			moveDirection = Vector3.zero
		end

		local targetSpeed = MovementConfig.MaxSpeed * math.min(moveDirection.Magnitude, 1)
		local acceleration = if targetSpeed > state.currentSpeed then MovementConfig.Acceleration else MovementConfig.Deceleration
		state.currentSpeed = moveTowards(state.currentSpeed, targetSpeed, acceleration * deltaTime)
		humanoid.WalkSpeed = math.min(state.currentSpeed, MovementConfig.MaxSpeed)
		humanoid:Move(if moveDirection.Magnitude > 0 then moveDirection.Unit else Vector3.zero, false)

		local currentLook = root.CFrame.LookVector
		local currentYaw = math.atan2(-currentLook.X, -currentLook.Z)
		local desiredYaw = math.atan2(-state.aimDirection.X, -state.aimDirection.Z)
		local yawDelta = math.atan2(math.sin(desiredYaw - currentYaw), math.cos(desiredYaw - currentYaw))
		local clampedDelta = math.clamp(yawDelta, -MovementConfig.TurnSpeedRadians * deltaTime, MovementConfig.TurnSpeedRadians * deltaTime)
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, currentYaw + clampedDelta, 0)
	end
end)
