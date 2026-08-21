--!strict

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig = require(shared:WaitForChild("MovementConfig"))

local ROBOT_CHASSIS_NAME = "RobotChassis"
local LEGACY_FRONT_INDICATOR_NAME = "FrontIndicator"
local ROBOT_VISUAL_ATTRIBUTE = "ScrapcorePlayableRobot"
local HIDDEN_RIG_COLLISION_GROUP = "ScrapcoreHiddenRig"
local ROBOT_TEMPLATE_NAME = "Robot_ChunkyIndustrial_B"
local TEMPORARY_TEAM_COLOR = Color3.fromRGB(0, 170, 255)
local TEAM_PANEL_NAMES = table.freeze({
	"TeamPanelTop",
	"TeamPanelLeft",
	"TeamPanelRight",
})

local assetLibrary = ServerStorage:WaitForChild("AssetLibrary")
local robotTemplates = assetLibrary:WaitForChild("Robots")
local robotTemplateInstance = robotTemplates:WaitForChild(ROBOT_TEMPLATE_NAME)
if not robotTemplateInstance:IsA("Model") then
	error(string.format("ServerStorage.AssetLibrary.Robots.%s must be a Model", ROBOT_TEMPLATE_NAME))
end
local robotTemplate = robotTemplateInstance

pcall(function()
	PhysicsService:RegisterCollisionGroup(HIDDEN_RIG_COLLISION_GROUP)
end)
PhysicsService:CollisionGroupSetCollidable(HIDDEN_RIG_COLLISION_GROUP, "Default", false)
PhysicsService:CollisionGroupSetCollidable(HIDDEN_RIG_COLLISION_GROUP, HIDDEN_RIG_COLLISION_GROUP, false)

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
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
			descendant.Massless = true
			descendant.CollisionGroup = HIDDEN_RIG_COLLISION_GROUP
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end
end

local function getRequiredTemplatePart(template: Model, partName: string): BasePart
	local instance = template:FindFirstChild(partName, true)
	if instance == nil or not instance:IsA("BasePart") then
		error(string.format("%s must contain BasePart %s", template:GetFullName(), partName))
	end
	return instance
end

local function validateRobotTemplate(template: Model)
	local robotRoot = getRequiredTemplatePart(template, "RobotRoot")
	local bodyCollision = getRequiredTemplatePart(template, "BodyCollision")
	local weaponMount = template:FindFirstChild("FrontWeaponMount", true)
	if weaponMount == nil or not weaponMount:IsA("Attachment") then
		error(string.format("%s must contain Attachment FrontWeaponMount", template:GetFullName()))
	end
	if template.PrimaryPart ~= robotRoot then
		error(string.format("%s.PrimaryPart must be RobotRoot", template:GetFullName()))
	end
	if (bodyCollision.Size - MovementConfig.ChassisSize).Magnitude > 0.01 then
		error(string.format("%s.BodyCollision must match MovementConfig.ChassisSize", template:GetFullName()))
	end
	if template:FindFirstChild("Hammer_Prototype", true) ~= nil then
		error(string.format("%s must not contain an active hammer", template:GetFullName()))
	end

	for _, panelName in TEAM_PANEL_NAMES do
		getRequiredTemplatePart(template, panelName)
	end

	local collidableParts = 0
	for _, descendant in template:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant.CanCollide then
				collidableParts += 1
			end
			if descendant ~= bodyCollision and (descendant.Anchored or not descendant.Massless or descendant.CanCollide) then
				error(string.format("%s contains unsafe decorative part %s", template:GetFullName(), descendant:GetFullName()))
			end
		end
	end
	if bodyCollision.Anchored or not bodyCollision.CanCollide or collidableParts ~= 1 then
		error(string.format("%s must contain exactly one unanchored gameplay collision body", template:GetFullName()))
	end
end

validateRobotTemplate(robotTemplate)

local function removeExistingChassis(character: Model)
	for _, child in character:GetChildren() do
		if
			child.Name == ROBOT_CHASSIS_NAME
			or child.Name == LEGACY_FRONT_INDICATOR_NAME
			or child:GetAttribute(ROBOT_VISUAL_ATTRIBUTE) == true
		then
			child:Destroy()
		end
	end
end

local function createChassis(character: Model, humanoid: Humanoid, root: BasePart)
	removeExistingChassis(character)

	local chassis = robotTemplate:Clone()
	chassis.Name = ROBOT_CHASSIS_NAME
	chassis:SetAttribute(ROBOT_VISUAL_ATTRIBUTE, true)

	local hammer = chassis:FindFirstChild("Hammer_Prototype", true)
	if hammer ~= nil then
		hammer:Destroy()
	end

	local robotRoot = getRequiredTemplatePart(chassis, "RobotRoot")
	local bodyCollision = getRequiredTemplatePart(chassis, "BodyCollision")
	local sourceRootCFrame = robotRoot.CFrame
	local verticalOffset = MovementConfig.ChassisGroundHeight - humanoid.HipHeight
	local chassisRootCFrame = root.CFrame * CFrame.new(0, verticalOffset, 0)
	chassis.PrimaryPart = robotRoot

	for _, panelName in TEAM_PANEL_NAMES do
		local panel = getRequiredTemplatePart(chassis, panelName)
		panel.Color = TEMPORARY_TEAM_COLOR
	end

	local chassisParts: {BasePart} = {}
	for _, descendant in chassis:GetDescendants() do
		if descendant:IsA("BasePart") then
			local rootOffset = sourceRootCFrame:ToObjectSpace(descendant.CFrame)
			descendant.CFrame = chassisRootCFrame * rootOffset
			descendant.Anchored = false
			if descendant == bodyCollision then
				descendant.Size = MovementConfig.ChassisSize
				descendant.Transparency = 1
				descendant.CanCollide = true
				descendant.CanTouch = false
				descendant.CanQuery = true
				descendant.Massless = true
				descendant.CollisionGroup = "Default"
				descendant.CustomPhysicalProperties = PhysicalProperties.new(
					MovementConfig.CollisionDensity,
					MovementConfig.CollisionFriction,
					MovementConfig.CollisionElasticity,
					100,
					100
				)
			else
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.Massless = true
				descendant.CollisionGroup = HIDDEN_RIG_COLLISION_GROUP
			end
			table.insert(chassisParts, descendant)
		end
	end

	chassis.Parent = character
	for _, part in chassisParts do
		local rootWeld = Instance.new("WeldConstraint")
		rootWeld.Name = "GameplayRootWeld"
		rootWeld.Part0 = root
		rootWeld.Part1 = part
		rootWeld.Parent = part
	end
end

local function configureCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") or root == nil or not root:IsA("BasePart") then
		warn(string.format("Unable to configure robot character for %s", player.Name))
		return
	end

	hideDefaultCharacter(character)
	root.Massless = false
	createChassis(character, humanoid, root)

	humanoid.AutoRotate = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Running)

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
