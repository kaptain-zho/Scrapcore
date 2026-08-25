--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaConfig = require(shared:WaitForChild("ArenaConfig"))
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local LobbyLayoutService = require(script.Parent:WaitForChild("LobbyLayoutService"))
local ProfileDataService = require(script.Parent:WaitForChild("ProfileDataService"))

type PlayerSessionState = {
	state: string,
	writingAttribute: boolean,
	deploymentInProgress: boolean,
	nextDeployAt: number,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	acceptedDeployments: number,
	rejectedDeployments: number,
	teleportSerial: number,
	characterAddedConnection: RBXScriptConnection?,
	attributeConnection: RBXScriptConnection?,
	healthChangedConnection: RBXScriptConnection?,
}

local ROBOT_CHASSIS_NAME = "RobotChassis"
local CLASS_VISUAL_MODEL_NAME = "ClassEvolutionVisuals"
local EQUIPPED_WEAPON_NAMES = table.freeze({
	EquippedHammer = true,
	[ClassConfig.EquippedSpinnerName] = true,
	[ClassConfig.EquippedRammerName] = true,
	[ClassConfig.EquippedImpactFoundryName] = true,
})
local WEAPON_MOTOR_NAMES = table.freeze({
	WeaponMountMotor = true,
	[ClassConfig.SpinnerWeaponMotorName] = true,
	[ClassConfig.RammerWeaponMotorName] = true,
	[ClassConfig.ImpactFoundryWeaponMotorName] = true,
})

local states: {[Player]: PlayerSessionState} = {}
local initialized = false
local nextArenaSpawnIndex = 1
local deployRemote: RemoteEvent? = nil
local feedbackRemote: RemoteEvent? = nil
local progressionService: any = nil

local PlayerSessionService = {}

local function getOrCreateRemote(name: string): RemoteEvent
	local remotesInstance = ReplicatedStorage:FindFirstChild("Remotes")
	if remotesInstance == nil then
		remotesInstance = Instance.new("Folder")
		remotesInstance.Name = "Remotes"
		remotesInstance.Parent = ReplicatedStorage
	elseif not remotesInstance:IsA("Folder") then
		error("ReplicatedStorage.Remotes must be a Folder")
	end
	local remotes = remotesInstance :: Folder
	local existing = remotes:FindFirstChild(name)
	if existing ~= nil then
		if not existing:IsA("RemoteEvent") then
			error(string.format("ReplicatedStorage.Remotes.%s must be a RemoteEvent", name))
		end
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local function getProgressionService(): any
	if progressionService == nil then
		progressionService = require(script.Parent:WaitForChild("ProgressionService"))
	end
	return progressionService
end

local function sendFeedback(player: Player, message: string)
	local remote = feedbackRemote
	if remote == nil or #message > SessionConfig.MaximumFeedbackLength then
		return
	end
	remote:FireClient(player, message)
end

local function writeReplicatedState(player: Player, state: PlayerSessionState)
	state.writingAttribute = true
	player:SetAttribute(SessionConfig.SessionAttribute, state.state)
	state.writingAttribute = false
end

local function setSessionState(player: Player, state: PlayerSessionState, nextState: string)
	if nextState ~= SessionConfig.LobbyState and nextState ~= SessionConfig.ArenaState then
		error(string.format("Invalid Scrapcore session state %s", nextState))
	end
	state.state = nextState
	writeReplicatedState(player, state)
end

local function enforceReplicatedState(player: Player)
	local state = states[player]
	if state == nil or state.writingAttribute then
		return
	end
	writeReplicatedState(player, state)
end

local function getAliveCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if character == nil or character.Parent == nil then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function stripLobbyLoadout(character: Model)
	character:SetAttribute("HammerReady", false)
	character:SetAttribute("SpinnerReady", false)
	character:SetAttribute("RammerReady", false)
	character:SetAttribute("ImpactFoundryReady", false)
	local chassis = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassis == nil or not chassis:IsA("Model") then
		return
	end
	for _, child in chassis:GetChildren() do
		if EQUIPPED_WEAPON_NAMES[child.Name] == true or child.Name == CLASS_VISUAL_MODEL_NAME then
			child:Destroy()
		end
	end
	for _, descendant in chassis:GetDescendants() do
		if descendant:IsA("Motor6D") and WEAPON_MOTOR_NAMES[descendant.Name] == true then
			descendant:Destroy()
		end
	end
end

local function removeLobbyProtection(character: Model)
	local protection = character:FindFirstChild(SessionConfig.LobbyProtectionName)
	if protection ~= nil then
		protection:Destroy()
	end
end

local function applyLobbyProtection(player: Player, state: PlayerSessionState, character: Model, humanoid: Humanoid)
	removeLobbyProtection(character)
	local protection = Instance.new("ForceField")
	protection.Name = SessionConfig.LobbyProtectionName
	protection.Visible = false
	protection.Parent = character
	humanoid.MaxHealth = ProgressionConfig.BaseMaxHealth
	humanoid.Health = humanoid.MaxHealth
	if state.healthChangedConnection ~= nil then
		state.healthChangedConnection:Disconnect()
	end
	state.healthChangedConnection = humanoid.HealthChanged:Connect(function(health: number)
		local latestState = states[player]
		if
			latestState ~= state
			or latestState.state ~= SessionConfig.LobbyState
			or player.Character ~= character
			or humanoid.Parent == nil
			or health <= 0
			or health >= humanoid.MaxHealth
		then
			return
		end
		task.defer(function()
			if
				states[player] == state
				and state.state == SessionConfig.LobbyState
				and player.Character == character
				and humanoid.Parent ~= nil
				and humanoid.Health > 0
			then
				humanoid.Health = humanoid.MaxHealth
			end
		end)
	end)
end

local function disconnectHealthProtection(state: PlayerSessionState)
	if state.healthChangedConnection ~= nil then
		state.healthChangedConnection:Disconnect()
		state.healthChangedConnection = nil
	end
end

local function getLobbySpawnCFrame(player: Player): CFrame
	local spawnPositions = SessionConfig.LobbySpawnPositions
	local index = math.abs(player.UserId) % #spawnPositions + 1
	local position = spawnPositions[index]
	return CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
end

local function getArenaPlayerPositions(excludedPlayer: Player): {Vector3}
	local positions: {Vector3} = {}
	for otherPlayer, otherState in states do
		if otherPlayer == excludedPlayer or otherState.state ~= SessionConfig.ArenaState then
			continue
		end
		local _character, _humanoid, root = getAliveCharacter(otherPlayer)
		if root ~= nil then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

local function chooseArenaSpawnCFrame(player: Player): CFrame
	local occupiedPositions = getArenaPlayerPositions(player)
	local spawnPositions = ArenaConfig.SpawnPositions
	local bestIndex = nextArenaSpawnIndex
	local bestClearance = -math.huge
	for offset = 0, #spawnPositions - 1 do
		local index = (nextArenaSpawnIndex + offset - 1) % #spawnPositions + 1
		local configured = spawnPositions[index]
		local candidate = Vector3.new(configured.X, SessionConfig.CharacterRootHeight, configured.Z)
		local clearance = math.huge
		for _, occupied in occupiedPositions do
			local difference = Vector3.new(candidate.X - occupied.X, 0, candidate.Z - occupied.Z)
			clearance = math.min(clearance, difference.Magnitude)
		end
		if clearance > bestClearance then
			bestIndex = index
			bestClearance = clearance
		end
	end
	nextArenaSpawnIndex = bestIndex % #spawnPositions + 1
	local selected = spawnPositions[bestIndex]
	local position = Vector3.new(selected.X, SessionConfig.CharacterRootHeight, selected.Z)
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

local function markAuthorizedTeleport(state: PlayerSessionState)
	state.teleportSerial += 1
end

local function moveCharacter(character: Model, destination: CFrame)
	character:PivotTo(destination)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function applyCharacterSession(player: Player, character: Model)
	local state = states[player]
	if state == nil or player.Character ~= character then
		return
	end
	local humanoidInstance = character:WaitForChild("Humanoid", 10)
	local rootInstance = character:WaitForChild("HumanoidRootPart", 10)
	if
		humanoidInstance == nil
		or not humanoidInstance:IsA("Humanoid")
		or rootInstance == nil
		or not rootInstance:IsA("BasePart")
		or humanoidInstance.Health <= 0
		or states[player] ~= state
		or player.Character ~= character
	then
		return
	end

	local destination = if state.state == SessionConfig.LobbyState
		then getLobbySpawnCFrame(player)
		else chooseArenaSpawnCFrame(player)
	if state.state == SessionConfig.LobbyState then
		player.RespawnLocation = LobbyLayoutService.GetLobbySpawn()
		disconnectHealthProtection(state)
		stripLobbyLoadout(character)
		applyLobbyProtection(player, state, character, humanoidInstance)
	else
		disconnectHealthProtection(state)
		removeLobbyProtection(character)
		humanoidInstance.MaxHealth = ProgressionConfig.BaseMaxHealth
		humanoidInstance.Health = humanoidInstance.MaxHealth
	end
	moveCharacter(character, destination)
	markAuthorizedTeleport(state)

	local chassis = character:WaitForChild(ROBOT_CHASSIS_NAME, 10)
	if chassis == nil or states[player] ~= state or player.Character ~= character then
		return
	end
	if state.state == SessionConfig.LobbyState then
		stripLobbyLoadout(character)
	end
	moveCharacter(character, destination)
	markAuthorizedTeleport(state)
end

local function resetCanonicalRun(player: Player)
	local progression = getProgressionService()
	progression.SetUnlimitedUpgradePoints(player, false)
	progression.ResetRun(player)
end

local function rejectDeployment(player: Player, state: PlayerSessionState, message: string?)
	state.rejectedDeployments += 1
	player:SetAttribute("SessionRejectedDeployCount", state.rejectedDeployments)
	if message ~= nil then
		sendFeedback(player, message)
	end
end

local function consumeDeployRate(player: Player, state: PlayerSessionState, now: number): boolean
	if now - state.requestWindowStartedAt >= SessionConfig.DeployRequestWindow then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if
		state.requestsInWindow > SessionConfig.MaximumDeployRequestsPerWindow
		or now - state.lastRequestAt < SessionConfig.MinimumDeployRequestInterval
	then
		state.lastRequestAt = now
		rejectDeployment(player, state, nil)
		return false
	end
	state.lastRequestAt = now
	return true
end

local function requestDeployment(player: Player, payloadIsValid: boolean)
	local state = states[player]
	if state == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if not consumeDeployRate(player, state, now) then
		return
	end
	if not payloadIsValid then
		rejectDeployment(player, state, nil)
		return
	end
	if not ProfileDataService.IsLoaded(player) then
		rejectDeployment(player, state, "Profile data is unavailable. Deployment is blocked for your safety.")
		return
	end
	local character, _humanoid, root = getAliveCharacter(player)
	if
		state.state ~= SessionConfig.LobbyState
		or state.deploymentInProgress
		or now < state.nextDeployAt
		or character == nil
		or root == nil
	then
		rejectDeployment(player, state, nil)
		return
	end
	local portalPart = LobbyLayoutService.GetMainPortalPart()
	if (root.Position - portalPart.Position).Magnitude > SessionConfig.MainPortalActivationDistance then
		rejectDeployment(player, state, "Move closer to the MAIN ARENA portal.")
		return
	end

	state.deploymentInProgress = true
	state.nextDeployAt = now + SessionConfig.DeployCooldown
	state.acceptedDeployments += 1
	player:SetAttribute("SessionAcceptedDeployCount", state.acceptedDeployments)
	sendFeedback(player, SessionConfig.DeploymentAcceptedFeedback)
	setSessionState(player, state, SessionConfig.ArenaState)
	resetCanonicalRun(player)
	task.spawn(function()
		local currentCharacter = player.Character
		if currentCharacter ~= nil then
			applyCharacterSession(player, currentCharacter)
		end
		if states[player] == state then
			state.deploymentInProgress = false
		end
	end)
end

local function bindCharacter(player: Player, character: Model)
	local state = states[player]
	if state == nil then
		return
	end
	disconnectHealthProtection(state)
	task.spawn(applyCharacterSession, player, character)
end

local function connectPlayer(player: Player)
	if states[player] ~= nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local state: PlayerSessionState = {
		state = SessionConfig.LobbyState,
		writingAttribute = false,
		deploymentInProgress = false,
		nextDeployAt = 0,
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastRequestAt = -math.huge,
		acceptedDeployments = 0,
		rejectedDeployments = 0,
		teleportSerial = 0,
		characterAddedConnection = nil,
		attributeConnection = nil,
		healthChangedConnection = nil,
	}
	states[player] = state
	player:SetAttribute("SessionAcceptedDeployCount", 0)
	player:SetAttribute("SessionRejectedDeployCount", 0)
	writeReplicatedState(player, state)
	player.RespawnLocation = LobbyLayoutService.GetLobbySpawn()
	state.attributeConnection = player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(function()
		enforceReplicatedState(player)
	end)
	state.characterAddedConnection = player.CharacterAdded:Connect(function(character: Model)
		bindCharacter(player, character)
	end)
	if player.Character ~= nil then
		bindCharacter(player, player.Character)
	end
end

local function disconnectPlayer(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	if state.characterAddedConnection ~= nil then
		state.characterAddedConnection:Disconnect()
	end
	if state.attributeConnection ~= nil then
		state.attributeConnection:Disconnect()
	end
	disconnectHealthProtection(state)
	states[player] = nil
end

function PlayerSessionService.GetState(player: Player): string
	local state = states[player]
	return if state ~= nil then state.state else SessionConfig.LobbyState
end

function PlayerSessionService.IsArena(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.state == SessionConfig.ArenaState
end

function PlayerSessionService.IsLobby(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.state == SessionConfig.LobbyState
end

function PlayerSessionService.GetTeleportSerial(player: Player): number
	local state = states[player]
	return if state ~= nil then state.teleportSerial else -1
end

function PlayerSessionService.TeleportForStudioTest(player: Player, destination: CFrame): boolean
	if not RunService:IsStudio() then
		return false
	end
	local state = states[player]
	local character, _humanoid, _root = getAliveCharacter(player)
	if state == nil or character == nil then
		return false
	end
	moveCharacter(character, destination)
	markAuthorizedTeleport(state)
	return true
end

function PlayerSessionService.ReturnToLobby(player: Player): boolean
	local state = states[player]
	if state == nil then
		return false
	end
	state.deploymentInProgress = false
	state.nextDeployAt = Workspace:GetServerTimeNow() + SessionConfig.DeployCooldown
	setSessionState(player, state, SessionConfig.LobbyState)
	resetCanonicalRun(player)
	sendFeedback(player, "Returned to the Workshop lobby.")
	local character = player.Character
	if character ~= nil then
		task.spawn(applyCharacterSession, player, character)
	end
	return true
end

function PlayerSessionService.Init()
	if initialized then
		return
	end
	initialized = true
	LobbyLayoutService.Init()
	ProfileDataService.Init()
	deployRemote = getOrCreateRemote("LobbyDeployRequest")
	feedbackRemote = getOrCreateRemote("LobbyFeedback")

	local activeDeployRemote = deployRemote :: RemoteEvent
	activeDeployRemote.OnServerEvent:Connect(function(player: Player, ...: unknown)
		requestDeployment(player, select("#", ...) == 0)
	end)
	LobbyLayoutService.GetMainPortalPrompt().Triggered:Connect(function(player: Player)
		requestDeployment(player, true)
	end)
	for _, prompt in LobbyLayoutService.GetFuturePrompts() do
		prompt.Triggered:Connect(function(player: Player)
			if PlayerSessionService.IsLobby(player) then
				sendFeedback(player, string.format("%s is coming soon.", prompt.Parent.Parent.Name))
			end
		end)
	end

	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return PlayerSessionService
