--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local CollisionGroupService = require(script.Parent:WaitForChild("CollisionGroupService"))

type CombatModifiers = {
	DamageBonus: number,
	MaxDamage: number,
	KnockbackSpeed: number,
	CooldownPenalty: number,
	MaxCooldown: number,
}

type ClassDefinition = {
	DisplayName: string,
	Tier: number,
	Enabled: boolean,
	Status: string,
	Role: string,
	Tradeoff: string,
	Combat: CombatModifiers?,
}

type PlayerClassState = {
	classId: string,
	selectedRunSerial: number,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	acceptedRequests: number,
	rejectedRequests: number,
	writingAttributes: boolean,
	characterAddedConnection: RBXScriptConnection?,
	diedConnection: RBXScriptConnection?,
	levelChangedConnection: RBXScriptConnection?,
	classAttributeConnection: RBXScriptConnection?,
	eligibilityAttributeConnection: RBXScriptConnection?,
	selectedAttributeConnection: RBXScriptConnection?,
}

local ROBOT_CHASSIS_NAME = "RobotChassis"
local EQUIPPED_HAMMER_NAME = "EquippedHammer"
local CLASS_VISUAL_MODEL_NAME = "ClassEvolutionVisuals"
local STRIKER_CLASS_ID = "Striker"

local classDefinitions = ClassConfig.Definitions :: {[string]: ClassDefinition}
local playerStates: {[Player]: PlayerClassState} = {}
local initialized = false
local classRequestRemote: RemoteEvent? = nil

local ClassService = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getAliveHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character == nil or character.Parent == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

local function getStrictRunLevel(player: Player): number?
	local value = player:GetAttribute("RunLevel")
	if
		typeof(value) ~= "number"
		or not isFinite(value)
		or value % 1 ~= 0
		or value < 1
		or value > ProgressionConfig.LevelCap
	then
		return nil
	end
	return value
end

local function setReplicatedState(player: Player, state: PlayerClassState, eligible: boolean)
	state.writingAttributes = true
	player:SetAttribute(ClassConfig.ClassAttribute, state.classId)
	player:SetAttribute(ClassConfig.EligibilityAttribute, eligible)
	player:SetAttribute(ClassConfig.SelectedAttribute, state.classId ~= ClassConfig.BaseClassId)
	state.writingAttributes = false
end

local function currentClassId(player: Player, state: PlayerClassState): string
	if state.classId == ClassConfig.BaseClassId then
		return ClassConfig.BaseClassId
	end
	local runSerial = ProgressionService.GetRunSerial(player)
	if state.selectedRunSerial ~= runSerial or not ProgressionService.IsRunActive(player, runSerial) then
		return ClassConfig.BaseClassId
	end
	return state.classId
end

local function updateEligibility(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	if state.classId ~= ClassConfig.BaseClassId and currentClassId(player, state) == ClassConfig.BaseClassId then
		state.classId = ClassConfig.BaseClassId
		state.selectedRunSerial = -1
	end
	local runLevel = getStrictRunLevel(player)
	local runSerial = ProgressionService.GetRunSerial(player)
	local eligible = state.classId == ClassConfig.BaseClassId
		and runLevel ~= nil
		and runLevel >= ClassConfig.Level8Threshold
		and ProgressionService.IsRunActive(player, runSerial)
	setReplicatedState(player, state, eligible)
end

local function enforceReplicatedState(player: Player)
	local state = playerStates[player]
	if state == nil or state.writingAttributes then
		return
	end
	updateEligibility(player)
end

local function restoreStandardHammer(chassis: Model)
	local hammer = chassis:FindFirstChild(EQUIPPED_HAMMER_NAME)
	if hammer ~= nil and hammer:IsA("Model") then
		local hammerHead = hammer:FindFirstChild("HammerHead", true)
		if hammerHead ~= nil and hammerHead:IsA("BasePart") then
			hammerHead.Size = ClassConfig.StandardHammerHeadSize
		end
		local hammerFace = hammer:FindFirstChild("HammerFace", true)
		if hammerFace ~= nil and hammerFace:IsA("BasePart") then
			hammerFace.Size = ClassConfig.StandardHammerFaceSize
		end
	end

	local oldVisuals = chassis:FindFirstChild(CLASS_VISUAL_MODEL_NAME)
	if oldVisuals ~= nil then
		oldVisuals:Destroy()
	end
end

local function createWeldedVisual(
	parent: Model,
	name: string,
	weldTo: BasePart,
	localCFrame: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = weldTo.CFrame * localCFrame
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Parent = parent
	CollisionGroupService.ApplyCharacterPart(part)

	local weld = Instance.new("WeldConstraint")
	weld.Name = name .. "Weld"
	weld.Part0 = weldTo
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function applyStrikerVisuals(character: Model): boolean
	local chassisInstance = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassisInstance == nil or not chassisInstance:IsA("Model") then
		return false
	end
	local chassis = chassisInstance
	local robotRoot = chassis:FindFirstChild("RobotRoot", true)
	local hammer = chassis:FindFirstChild(EQUIPPED_HAMMER_NAME)
	if robotRoot == nil or not robotRoot:IsA("BasePart") or hammer == nil or not hammer:IsA("Model") then
		return false
	end

	restoreStandardHammer(chassis)
	local hammerHead = hammer:FindFirstChild("HammerHead", true)
	local hammerFace = hammer:FindFirstChild("HammerFace", true)
	if
		hammerHead == nil
		or not hammerHead:IsA("BasePart")
		or hammerFace == nil
		or not hammerFace:IsA("BasePart")
	then
		return false
	end
	hammerHead.Size = ClassConfig.StrikerHammerHeadSize
	hammerFace.Size = ClassConfig.StrikerHammerFaceSize

	local visuals = Instance.new("Model")
	visuals.Name = CLASS_VISUAL_MODEL_NAME
	visuals:SetAttribute("ClassId", STRIKER_CLASS_ID)
	visuals:SetAttribute("OriginalScrapcoreVisual", true)
	visuals.Parent = chassis

	createWeldedVisual(
		visuals,
		"StrikerMountBrace",
		robotRoot,
		CFrame.new(0, 0.64, -3.02),
		Vector3.new(2.8, 0.55, 0.72),
		Color3.fromRGB(48, 56, 65),
		Enum.Material.Metal
	)
	createWeldedVisual(
		visuals,
		"StrikerIdentificationAccent",
		robotRoot,
		CFrame.new(0, 0.98, -3.40),
		Vector3.new(0.9, 0.16, 0.38),
		Color3.fromRGB(244, 154, 45),
		Enum.Material.SmoothPlastic
	)
	return true
end

local function applyCurrentVisuals(player: Player)
	local state = playerStates[player]
	local character = player.Character
	if state == nil or character == nil or character.Parent == nil then
		return
	end
	local chassisInstance = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassisInstance ~= nil and chassisInstance:IsA("Model") and currentClassId(player, state) == ClassConfig.BaseClassId then
		restoreStandardHammer(chassisInstance)
		return
	end
	if currentClassId(player, state) ~= STRIKER_CLASS_ID then
		return
	end

	for _ = 1, 40 do
		if player.Character ~= character or character.Parent == nil then
			return
		end
		if applyStrikerVisuals(character) then
			return
		end
		task.wait(0.05)
	end
	warn(string.format("Unable to apply Striker visuals for %s", player.Name))
end

local function resetClass(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	state.classId = ClassConfig.BaseClassId
	state.selectedRunSerial = -1
	setReplicatedState(player, state, false)
	task.spawn(applyCurrentVisuals, player)
end

local function rejectRequest(player: Player, state: PlayerClassState)
	state.rejectedRequests += 1
	player:SetAttribute("ClassRejectedRequestCount", state.rejectedRequests)
end

local function handleClassRequest(player: Player, classValue: unknown, ...: unknown)
	local state = playerStates[player]
	if state == nil then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now - state.requestWindowStartedAt >= ClassConfig.RequestRateWindow then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if state.requestsInWindow > ClassConfig.MaxRequestsPerWindow then
		rejectRequest(player, state)
		return
	end
	if now - state.lastRequestAt < ClassConfig.MinimumRequestInterval then
		state.lastRequestAt = now
		rejectRequest(player, state)
		return
	end
	state.lastRequestAt = now

	if select("#", ...) ~= 0 or typeof(classValue) ~= "string" then
		rejectRequest(player, state)
		return
	end
	local requestedClassId = classValue :: string
	local definition = classDefinitions[requestedClassId]
	if definition == nil or definition.Tier ~= ClassConfig.Level8Threshold or not definition.Enabled then
		rejectRequest(player, state)
		return
	end
	if state.classId ~= ClassConfig.BaseClassId then
		rejectRequest(player, state)
		return
	end

	local runLevel = getStrictRunLevel(player)
	local runSerial = ProgressionService.GetRunSerial(player)
	if
		runLevel == nil
		or runLevel < ClassConfig.Level8Threshold
		or getAliveHumanoid(player) == nil
		or not ProgressionService.IsRunActive(player, runSerial)
	then
		rejectRequest(player, state)
		return
	end

	state.classId = requestedClassId
	state.selectedRunSerial = runSerial
	state.acceptedRequests += 1
	player:SetAttribute("ClassAcceptedRequestCount", state.acceptedRequests)
	setReplicatedState(player, state, false)
	task.spawn(applyCurrentVisuals, player)
end

local function bindCharacter(player: Player, character: Model)
	local state = playerStates[player]
	if state == nil then
		return
	end
	if state.diedConnection ~= nil then
		state.diedConnection:Disconnect()
		state.diedConnection = nil
	end
	resetClass(player)

	task.spawn(function()
		local humanoidInstance = character:WaitForChild("Humanoid", 10)
		local latestState = playerStates[player]
		if
			humanoidInstance == nil
			or not humanoidInstance:IsA("Humanoid")
			or latestState == nil
			or player.Character ~= character
		then
			return
		end
		latestState.diedConnection = humanoidInstance.Died:Connect(function()
			if playerStates[player] == latestState then
				resetClass(player)
			end
		end)
		task.defer(updateEligibility, player)
	end)
end

local function connectPlayer(player: Player)
	if playerStates[player] ~= nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local state: PlayerClassState = {
		classId = ClassConfig.BaseClassId,
		selectedRunSerial = -1,
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastRequestAt = -math.huge,
		acceptedRequests = 0,
		rejectedRequests = 0,
		writingAttributes = false,
		characterAddedConnection = nil,
		diedConnection = nil,
		levelChangedConnection = nil,
		classAttributeConnection = nil,
		eligibilityAttributeConnection = nil,
		selectedAttributeConnection = nil,
	}
	playerStates[player] = state
	player:SetAttribute("ClassAcceptedRequestCount", 0)
	player:SetAttribute("ClassRejectedRequestCount", 0)
	setReplicatedState(player, state, false)

	state.levelChangedConnection = player:GetAttributeChangedSignal("RunLevel"):Connect(function()
		updateEligibility(player)
	end)
	state.classAttributeConnection = player:GetAttributeChangedSignal(ClassConfig.ClassAttribute):Connect(function()
		enforceReplicatedState(player)
	end)
	state.eligibilityAttributeConnection = player:GetAttributeChangedSignal(ClassConfig.EligibilityAttribute):Connect(function()
		enforceReplicatedState(player)
	end)
	state.selectedAttributeConnection = player:GetAttributeChangedSignal(ClassConfig.SelectedAttribute):Connect(function()
		enforceReplicatedState(player)
	end)
	state.characterAddedConnection = player.CharacterAdded:Connect(function(character: Model)
		bindCharacter(player, character)
	end)
	if player.Character ~= nil then
		bindCharacter(player, player.Character)
	else
		updateEligibility(player)
	end
end

local function disconnectPlayer(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	local function disconnect(connection: RBXScriptConnection?)
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	disconnect(state.characterAddedConnection)
	disconnect(state.diedConnection)
	disconnect(state.levelChangedConnection)
	disconnect(state.classAttributeConnection)
	disconnect(state.eligibilityAttributeConnection)
	disconnect(state.selectedAttributeConnection)
	playerStates[player] = nil
end

function ClassService.GetClassId(player: Player): string
	local state = playerStates[player]
	return if state ~= nil then currentClassId(player, state) else ClassConfig.BaseClassId
end

function ClassService.Init()
	if initialized then
		return
	end
	initialized = true
	ProgressionService.Init()
	CollisionGroupService.Init()

	local remotesInstance = ReplicatedStorage:FindFirstChild("Remotes")
	if remotesInstance == nil then
		remotesInstance = Instance.new("Folder")
		remotesInstance.Name = "Remotes"
		remotesInstance.Parent = ReplicatedStorage
	elseif not remotesInstance:IsA("Folder") then
		error("ReplicatedStorage.Remotes must be a Folder")
	end
	local remotes = remotesInstance :: Folder
	local existingRemote = remotes:FindFirstChild("ClassEvolutionRequest")
	if existingRemote ~= nil then
		if not existingRemote:IsA("RemoteEvent") then
			error("ReplicatedStorage.Remotes.ClassEvolutionRequest must be a RemoteEvent")
		end
		classRequestRemote = existingRemote
	else
		local remote = Instance.new("RemoteEvent")
		remote.Name = "ClassEvolutionRequest"
		remote.Parent = remotes
		classRequestRemote = remote
	end

	(classRequestRemote :: RemoteEvent).OnServerEvent:Connect(handleClassRequest)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return ClassService
