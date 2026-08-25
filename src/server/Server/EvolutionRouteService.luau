--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local EvolutionConfig = require(shared:WaitForChild("EvolutionConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local ClassService = require(script.Parent:WaitForChild("ClassService"))
local CollisionGroupService = require(script.Parent:WaitForChild("CollisionGroupService"))
local DisplacementResistanceService = require(script.Parent:WaitForChild("DisplacementResistanceService"))
local PlayerSessionService = require(script.Parent:WaitForChild("PlayerSessionService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local RammerCombatService = require(script.Parent:WaitForChild("RammerCombatService"))
local SpinnerCombatService = require(script.Parent:WaitForChild("SpinnerCombatService"))

type RouteState = {
	currentNodeId: string,
	committedLevel20Family: string,
	level8Ancestry: string,
	reachedGates: {[number]: boolean},
	selectedByGate: {[number]: string},
	runSerial: number,
	writingAttributes: boolean,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	acceptedRequests: number,
	rejectedRequests: number,
	characterAddedConnection: RBXScriptConnection?,
	diedConnection: RBXScriptConnection?,
	classConnection: RBXScriptConnection?,
	sessionConnection: RBXScriptConnection?,
	attributeConnections: {RBXScriptConnection},
}

local ROUTE_REQUEST_WINDOW = 1
local MAXIMUM_ROUTE_REQUESTS_PER_WINDOW = 5
local MINIMUM_ROUTE_REQUEST_INTERVAL = 0.12
local MAXIMUM_NODE_ID_LENGTH = 48
local ROBOT_CHASSIS_NAME = "RobotChassis"
local CLASS_VISUAL_MODEL_NAME = "ClassEvolutionVisuals"
local IMPACT_ATTRIBUTE = "ScrapcoreEquippedImpactFoundry"
local IMPACT_HIT_ORIGIN_NAME = "ImpactFoundryHitOrigin"

local states: {[Player]: RouteState} = {}
local initialized = false
local requestRemote: RemoteEvent? = nil

local EvolutionRouteService = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getStrictRunLevel(player: Player): number?
	local value = player:GetAttribute("RunLevel")
	if typeof(value) ~= "number" or not isFinite(value) or value % 1 ~= 0 or value < 1 or value > ProgressionConfig.MaximumTrackedLevel then
		return nil
	end
	return value
end

local function getAliveCharacter(player: Player): (Model?, Humanoid?)
	local character = player.Character
	if character == nil or character.Parent == nil then return nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then return nil, nil end
	return character, humanoid
end

local function includes(values: {string}, expected: string): boolean
	for _, value in values do
		if value == expected then return true end
	end
	return false
end

local function serializeReachedGates(state: RouteState): string
	local values = { "1" }
	for _, gate in EvolutionConfig.Gates do
		if state.reachedGates[gate] then table.insert(values, tostring(gate)) end
	end
	return table.concat(values, ",")
end

local function writeReplicatedState(player: Player, state: RouteState)
	state.writingAttributes = true
	player:SetAttribute(EvolutionConfig.CurrentNodeAttribute, state.currentNodeId)
	player:SetAttribute(EvolutionConfig.CommittedFamilyAttribute, state.committedLevel20Family)
	player:SetAttribute(EvolutionConfig.ReachedGatesAttribute, serializeReachedGates(state))
	player:SetAttribute(EvolutionConfig.RouteRunSerialAttribute, state.runSerial)
	player:SetAttribute(EvolutionConfig.Level8AncestryAttribute, state.level8Ancestry)
	player:SetAttribute(EvolutionConfig.AcceptedRequestCountAttribute, state.acceptedRequests)
	player:SetAttribute(EvolutionConfig.RejectedRequestCountAttribute, state.rejectedRequests)
	state.writingAttributes = false
end

local function enforceReplicatedState(player: Player)
	local state = states[player]
	if state ~= nil and not state.writingAttributes then writeReplicatedState(player, state) end
end

local function removeImpactFoundryLoadout(character: Model)
	character:SetAttribute("ImpactFoundryReady", false)
	local chassis = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassis == nil or not chassis:IsA("Model") then return end
	for _, child in chassis:GetChildren() do
		if child.Name == ClassConfig.EquippedImpactFoundryName or child:GetAttribute(IMPACT_ATTRIBUTE) == true then child:Destroy() end
	end
	local robotRoot = chassis:FindFirstChild("RobotRoot", true)
	if robotRoot ~= nil then
		local motor = robotRoot:FindFirstChild(ClassConfig.ImpactFoundryWeaponMotorName)
		if motor ~= nil then motor:Destroy() end
	end
end

local function removeAllCombatLoadouts(character: Model)
	character:SetAttribute("HammerReady", false)
	character:SetAttribute("SpinnerReady", false)
	character:SetAttribute("RammerReady", false)
	character:SetAttribute("ImpactFoundryReady", false)
	local chassis = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassis == nil or not chassis:IsA("Model") then return end
	local removableNames = {
		EquippedHammer = true,
		[ClassConfig.EquippedSpinnerName] = true,
		[ClassConfig.EquippedRammerName] = true,
		[ClassConfig.EquippedImpactFoundryName] = true,
		[CLASS_VISUAL_MODEL_NAME] = true,
	}
	for _, child in chassis:GetChildren() do
		if removableNames[child.Name] == true then child:Destroy() end
	end
	local motorNames = {
		WeaponMountMotor = true,
		[ClassConfig.SpinnerWeaponMotorName] = true,
		[ClassConfig.RammerWeaponMotorName] = true,
		[ClassConfig.ImpactFoundryWeaponMotorName] = true,
	}
	for _, descendant in chassis:GetDescendants() do
		if descendant:IsA("Motor6D") and motorNames[descendant.Name] == true then descendant:Destroy() end
	end
end

local function createVisualPart(parent: Model, name: string, root: BasePart, localCFrame: CFrame, size: Vector3, color: Color3, material: Enum.Material, transparency: number?): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = root.CFrame * localCFrame
	part.Color = color
	part.Material = material
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = parent
	CollisionGroupService.ApplyCharacterPart(part)
	local weld = Instance.new("WeldConstraint")
	weld.Name = name .. "Weld"
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function applyImpactFoundryLoadout(character: Model): boolean
	local chassis = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassis == nil or not chassis:IsA("Model") then return false end
	local robotRoot = chassis:FindFirstChild("RobotRoot", true)
	if robotRoot == nil or not robotRoot:IsA("BasePart") then return false end
	local mount = robotRoot:FindFirstChild("FrontWeaponMount")
	if mount == nil or not mount:IsA("Attachment") then return false end

	removeAllCombatLoadouts(character)
	local equipped = Instance.new("Model")
	equipped.Name = ClassConfig.EquippedImpactFoundryName
	equipped:SetAttribute(IMPACT_ATTRIBUTE, true)
	equipped:SetAttribute("EvolutionNodeId", ClassConfig.ImpactFoundryNodeId)
	equipped:SetAttribute("OriginalScrapcoreVisual", true)

	local weaponRoot = Instance.new("Part")
	weaponRoot.Name = "ImpactFoundryRoot"
	weaponRoot.Size = Vector3.new(0.2, 0.2, 0.2)
	weaponRoot.CFrame = mount.WorldCFrame
	weaponRoot.Transparency = 1
	weaponRoot.Anchored = false
	weaponRoot.Massless = true
	weaponRoot.CanCollide = false
	weaponRoot.CanTouch = false
	weaponRoot.CanQuery = false
	weaponRoot.Parent = equipped
	CollisionGroupService.ApplyCharacterPart(weaponRoot)

	local hitOrigin = Instance.new("Attachment")
	hitOrigin.Name = IMPACT_HIT_ORIGIN_NAME
	hitOrigin.CFrame = CFrame.new(0, -0.04, -2.35)
	hitOrigin.Parent = weaponRoot

	local darkSteel = Color3.fromRGB(48, 57, 64)
	local mediumSteel = Color3.fromRGB(78, 88, 96)
	local accent = ClassConfig.ImpactFoundryAccentColor
	createVisualPart(equipped, "ImpulseHousing", weaponRoot, CFrame.new(0, 0.08, -0.68), Vector3.new(3.3, 1.05, 1.3), darkSteel, Enum.Material.Metal)
	createVisualPart(equipped, "ImpactFace", weaponRoot, CFrame.new(0, -0.04, -2.05), Vector3.new(4.65, 1.25, 0.58), mediumSteel, Enum.Material.Metal)
	createVisualPart(equipped, "LeftForgeBrace", weaponRoot, CFrame.new(-1.75, 0.08, -1.1) * CFrame.Angles(0, math.rad(-8), 0), Vector3.new(0.42, 0.72, 2.45), darkSteel, Enum.Material.Metal)
	createVisualPart(equipped, "RightForgeBrace", weaponRoot, CFrame.new(1.75, 0.08, -1.1) * CFrame.Angles(0, math.rad(8), 0), Vector3.new(0.42, 0.72, 2.45), darkSteel, Enum.Material.Metal)
	createVisualPart(equipped, "UpperClamp", weaponRoot, CFrame.new(0, 0.72, -1.1), Vector3.new(2.35, 0.34, 1.75), mediumSteel, Enum.Material.Metal)
	createVisualPart(equipped, "FoundryAccent", weaponRoot, CFrame.new(0, 0.76, -1.93), Vector3.new(2.0, 0.14, 0.22), accent, Enum.Material.Neon, 0.16)
	createVisualPart(equipped, "WindupGlow", weaponRoot, CFrame.new(0, 0.08, -2.38), Vector3.new(3.9, 0.18, 0.12), accent, Enum.Material.Neon, 0.88)
	createVisualPart(equipped, "LeftRecoveryVent", weaponRoot, CFrame.new(-1.25, 0.58, -0.42), Vector3.new(0.48, 0.18, 0.75), accent, Enum.Material.Neon, 0.9)
	createVisualPart(equipped, "RightRecoveryVent", weaponRoot, CFrame.new(1.25, 0.58, -0.42), Vector3.new(0.48, 0.18, 0.75), accent, Enum.Material.Neon, 0.9)

	equipped.PrimaryPart = weaponRoot
	equipped.Parent = chassis
	local motor = Instance.new("Motor6D")
	motor.Name = ClassConfig.ImpactFoundryWeaponMotorName
	motor.Part0 = robotRoot
	motor.Part1 = weaponRoot
	motor.C0 = mount.CFrame
	motor.C1 = CFrame.identity
	motor.Transform = CFrame.identity
	motor.Parent = robotRoot
	character:SetAttribute("ImpactFoundryReady", true)
	return true
end

local function resetRoute(player: Player, forceBase: boolean?)
	local state = states[player]
	if state == nil then return end
	local character = player.Character
	if character ~= nil then removeImpactFoundryLoadout(character) end
	DisplacementResistanceService.Clear(player)
	state.currentNodeId = ClassConfig.BaseClassId
	state.committedLevel20Family = ""
	state.level8Ancestry = ""
	table.clear(state.reachedGates)
	table.clear(state.selectedByGate)
	state.runSerial = ProgressionService.GetRunSerial(player)
	if forceBase ~= true and PlayerSessionService.IsArena(player) then
		local classId = ClassService.GetClassId(player)
		if classId ~= ClassConfig.BaseClassId then
			state.currentNodeId = classId
			state.level8Ancestry = classId
			state.reachedGates[8] = true
			state.selectedByGate[8] = classId
		end
	end
	writeReplicatedState(player, state)
end

local function syncLevel8Node(player: Player)
	local state = states[player]
	if state == nil or state.committedLevel20Family ~= "" then return end
	state.runSerial = ProgressionService.GetRunSerial(player)
	local classId = ClassService.GetClassId(player)
	if PlayerSessionService.IsArena(player) and classId ~= ClassConfig.BaseClassId then
		state.currentNodeId = classId
		state.level8Ancestry = classId
		state.reachedGates[8] = true
		state.selectedByGate[8] = classId
	else
		state.currentNodeId = ClassConfig.BaseClassId
		state.level8Ancestry = ""
		state.reachedGates[8] = nil
		state.selectedByGate[8] = nil
	end
	writeReplicatedState(player, state)
end

local function reject(player: Player, state: RouteState)
	state.rejectedRequests += 1
	writeReplicatedState(player, state)
end

local function consumeRate(player: Player, state: RouteState, now: number): boolean
	if now - state.requestWindowStartedAt >= ROUTE_REQUEST_WINDOW then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if state.requestsInWindow > MAXIMUM_ROUTE_REQUESTS_PER_WINDOW or now - state.lastRequestAt < MINIMUM_ROUTE_REQUEST_INTERVAL then
		state.lastRequestAt = now
		reject(player, state)
		return false
	end
	state.lastRequestAt = now
	return true
end

local function trySelect(player: Player, requestedNodeId: string, allowStudioPrototype: boolean): boolean
	local state = states[player]
	if state == nil then return false end
	local now = Workspace:GetServerTimeNow()
	if not consumeRate(player, state, now) then return false end
	local node = EvolutionConfig.RouteNodes[requestedNodeId]
	local runSerial = ProgressionService.GetRunSerial(player)
	local runLevel = getStrictRunLevel(player)
	local character, humanoid = getAliveCharacter(player)
	local authoritativeParent = if state.committedLevel20Family == "" then ClassService.GetClassId(player) else state.currentNodeId
	local authoritativeParentNode = EvolutionConfig.RouteNodes[authoritativeParent]
	if
		#requestedNodeId == 0
		or #requestedNodeId > MAXIMUM_NODE_ID_LENGTH
		or node == nil
		or requestedNodeId == state.currentNodeId
		or state.selectedByGate[node.Level] ~= nil
		or authoritativeParentNode == nil
		or not includes(node.ParentIds, authoritativeParent)
		or (authoritativeParentNode ~= nil and not includes(authoritativeParentNode.Children, requestedNodeId))
		or runLevel == nil
		or runLevel < node.Level
		or state.runSerial ~= runSerial
		or not ProgressionService.IsRunActive(player, runSerial)
		or not PlayerSessionService.IsArena(player)
		or character == nil
		or humanoid == nil
		or (allowStudioPrototype and not RunService:IsStudio())
		or (allowStudioPrototype and not node.PrototypeAvailable)
		or (not allowStudioPrototype and (not node.PublicSelectable or (node.Level == 20 and not EvolutionConfig.Level20PublicEnabled)))
	then
		reject(player, state)
		return false
	end
	if node.Level ~= ClassConfig.Level20Threshold or requestedNodeId ~= ClassConfig.ImpactFoundryNodeId then
		reject(player, state)
		return false
	end
	if not applyImpactFoundryLoadout(character) then
		reject(player, state)
		return false
	end
	SpinnerCombatService.CancelForPlayer(player)
	RammerCombatService.CancelForPlayer(player)
	state.currentNodeId = requestedNodeId
	state.committedLevel20Family = requestedNodeId
	state.level8Ancestry = authoritativeParent
	state.reachedGates[node.Level] = true
	state.selectedByGate[node.Level] = requestedNodeId
	state.acceptedRequests += 1
	writeReplicatedState(player, state)
	return true
end

local function connectPlayer(player: Player)
	if states[player] ~= nil then return end
	local now = Workspace:GetServerTimeNow()
	local state: RouteState = {
		currentNodeId = ClassConfig.BaseClassId,
		committedLevel20Family = "",
		level8Ancestry = "",
		reachedGates = {},
		selectedByGate = {},
		runSerial = ProgressionService.GetRunSerial(player),
		writingAttributes = false,
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastRequestAt = -math.huge,
		acceptedRequests = 0,
		rejectedRequests = 0,
		characterAddedConnection = nil,
		diedConnection = nil,
		classConnection = nil,
		sessionConnection = nil,
		attributeConnections = {},
	}
	states[player] = state
	for _, attributeName in {
		EvolutionConfig.CurrentNodeAttribute,
		EvolutionConfig.CommittedFamilyAttribute,
		EvolutionConfig.ReachedGatesAttribute,
		EvolutionConfig.RouteRunSerialAttribute,
		EvolutionConfig.Level8AncestryAttribute,
	} do
		table.insert(state.attributeConnections, player:GetAttributeChangedSignal(attributeName):Connect(function() enforceReplicatedState(player) end))
	end
	state.classConnection = player:GetAttributeChangedSignal(ClassConfig.ClassAttribute):Connect(function() syncLevel8Node(player) end)
	state.sessionConnection = player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(function()
		task.defer(function()
			if states[player] == state then
				resetRoute(player, true)
			end
		end)
	end)
	state.characterAddedConnection = player.CharacterAdded:Connect(function(character: Model)
		if state.diedConnection ~= nil then state.diedConnection:Disconnect() end
		task.defer(function()
			if states[player] == state and player.Character == character then
				resetRoute(player, true)
			end
		end)
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid == nil or not humanoid:IsA("Humanoid") or states[player] ~= state or player.Character ~= character then return end
			state.diedConnection = humanoid.Died:Connect(function()
				if states[player] == state then resetRoute(player, true) end
			end)
		end)
	end)
	resetRoute(player, true)
end

local function disconnectPlayer(player: Player)
	local state = states[player]
	if state == nil then return end
	for _, connection in state.attributeConnections do connection:Disconnect() end
	for _, connection in { state.characterAddedConnection, state.diedConnection, state.classConnection, state.sessionConnection } do
		if connection ~= nil then connection:Disconnect() end
	end
	local character = player.Character
	if character ~= nil then removeImpactFoundryLoadout(character) end
	DisplacementResistanceService.Clear(player)
	states[player] = nil
end

local function validateGraph()
	if #EvolutionConfig.NodeOrder ~= 37 then error("EvolutionConfig must contain exactly 37 approved nodes") end
	local seen: {[string]: boolean} = {}
	for _, nodeId in EvolutionConfig.NodeOrder do
		if seen[nodeId] or EvolutionConfig.RouteNodes[nodeId] == nil then error("EvolutionConfig node order is invalid") end
		seen[nodeId] = true
		local node = EvolutionConfig.RouteNodes[nodeId]
		for _, parentId in node.ParentIds do
			local parent = EvolutionConfig.RouteNodes[parentId]
			if parent == nil or parent.Level >= node.Level or not includes(parent.Children, nodeId) then error(string.format("EvolutionConfig parent edge %s -> %s is invalid", parentId, nodeId)) end
		end
		for _, childId in node.Children do
			local child = EvolutionConfig.RouteNodes[childId]
			if child == nil or child.Level <= node.Level or not includes(child.ParentIds, nodeId) then error(string.format("EvolutionConfig child edge %s -> %s is invalid", nodeId, childId)) end
		end
	end
	if EvolutionConfig.Level20PublicEnabled then error("Level 20 must remain disabled for ordinary players during the first prototype") end
end

function EvolutionRouteService.GetCurrentNodeId(player: Player): string
	local state = states[player]
	return if state ~= nil then state.currentNodeId else ClassConfig.BaseClassId
end

function EvolutionRouteService.IsImpactFoundryActive(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.currentNodeId == ClassConfig.ImpactFoundryNodeId and state.runSerial == ProgressionService.GetRunSerial(player) and PlayerSessionService.IsArena(player)
end

function EvolutionRouteService.ActivateImpactFoundryForStudio(player: Player): boolean
	return RunService:IsStudio() and trySelect(player, ClassConfig.ImpactFoundryNodeId, true)
end

function EvolutionRouteService.Init()
	if initialized then return end
	initialized = true
	validateGraph()
	PlayerSessionService.Init()
	ProgressionService.Init()
	ClassService.Init()
	CollisionGroupService.Init()
	SpinnerCombatService.Init()
	RammerCombatService.Init()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	elseif not remotes:IsA("Folder") then error("ReplicatedStorage.Remotes must be a Folder") end
	local existing = remotes:FindFirstChild("EvolutionRouteRequest")
	if existing ~= nil and not existing:IsA("RemoteEvent") then error("ReplicatedStorage.Remotes.EvolutionRouteRequest must be a RemoteEvent") end
	requestRemote = if existing ~= nil then existing :: RemoteEvent else Instance.new("RemoteEvent")
	local activeRequestRemote = requestRemote :: RemoteEvent
	if existing == nil then
		activeRequestRemote.Name = "EvolutionRouteRequest"
		activeRequestRemote.Parent = remotes
	end
	activeRequestRemote.OnServerEvent:Connect(function(player: Player, payloadValue: unknown, ...: unknown)
		local state = states[player]
		if state == nil then return end
		if select("#", ...) ~= 0 or typeof(payloadValue) ~= "table" then
			if consumeRate(player, state, Workspace:GetServerTimeNow()) then
				reject(player, state)
			end
			return
		end
		local payload = payloadValue :: {[any]: any}
		local fieldCount = 0
		for _ in payload do fieldCount += 1 end
		if
			fieldCount ~= 2
			or typeof(payload.NodeId) ~= "string"
			or typeof(payload.RunSerial) ~= "number"
			or not isFinite(payload.RunSerial)
			or payload.RunSerial % 1 ~= 0
			or payload.RunSerial ~= state.runSerial
		then
			if consumeRate(player, state, Workspace:GetServerTimeNow()) then
				reject(player, state)
			end
			return
		end
		trySelect(player, payload.NodeId :: string, false)
	end)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do connectPlayer(player) end
end

return EvolutionRouteService
