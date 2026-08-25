--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local ExtractionConfig = require(shared:WaitForChild("ExtractionConfig"))
local EvolutionConfig = require(shared:WaitForChild("EvolutionConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local DevToolsConfig = require(script.Parent:WaitForChild("DevToolsConfig"))
local ClassService = require(script.Parent:WaitForChild("ClassService"))
local EvolutionRouteService = require(script.Parent:WaitForChild("EvolutionRouteService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local PlayerSessionService = require(script.Parent:WaitForChild("PlayerSessionService"))
local AuthoritativeDamageService = require(script.Parent:WaitForChild("AuthoritativeDamageService"))
local ProfileDataService = require(script.Parent:WaitForChild("ProfileDataService"))

type PlayerDevState = {
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	acceptedActions: number,
	rejectedRequests: number,
	stateUpdateQueued: boolean,
	attributeConnections: {RBXScriptConnection},
	characterAddedConnection: RBXScriptConnection?,
}

local XP_ACTIONS = table.freeze({
	AddXP10 = 10,
	AddXP50 = 50,
	AddXP100 = 100,
	AddXP500 = 500,
})

local LEVEL_ACTIONS = table.freeze({
	ToLevel8 = 8,
	ToLevel20 = 20,
	ToLevel30 = 30,
	ToLevel35 = 35,
	ToLevel75 = 75,
	ToLevel150 = 150,
	ToLevel250 = 250,
	ToLevel300 = 300,
})

local states: {[Player]: PlayerDevState} = {}
local initialized = false
local requestRemote: RemoteEvent? = nil
local stateRemote: RemoteEvent? = nil

local DevToolsService = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getIntegerAttribute(instance: Instance, name: string, minimum: number, maximum: number): number
	local value = instance:GetAttribute(name)
	if typeof(value) ~= "number" or not isFinite(value) then
		return minimum
	end
	return math.clamp(math.floor(value), minimum, maximum)
end

local function isAuthorized(player: Player): boolean
	return DevToolsConfig.IsAuthorized(player.UserId, RunService:IsStudio())
end

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

local function fireState(player: Player, authorized: boolean)
	local remote = stateRemote
	if remote == nil then
		return
	end
	if not authorized then
		remote:FireClient(player, {
			Authorized = false,
			Level = 1,
			XP = 0,
			XPToNext = 0,
			Points = 0,
			Class = ClassConfig.BaseClassId,
			Route = ClassConfig.BaseClassId,
			Unlimited = false,
		})
		return
	end
	remote:FireClient(player, {
		Authorized = true,
		Level = getIntegerAttribute(player, "RunLevel", 1, ProgressionConfig.MaximumTrackedLevel),
		XP = getIntegerAttribute(player, "RunXP", 0, ProgressionConfig.MaxRunXP),
		XPToNext = getIntegerAttribute(player, "XPToNextLevel", 0, ProgressionConfig.MaxRunXP),
		Points = getIntegerAttribute(
			player,
			"UnspentUpgradePoints",
			0,
			ProgressionConfig.MaxUnspentUpgradePoints
		),
		Class = ClassService.GetClassId(player),
		Route = EvolutionRouteService.GetCurrentNodeId(player),
		Unlimited = ProgressionService.IsUnlimitedUpgradePoints(player),
	})
end

local function queueStateUpdate(player: Player)
	local state = states[player]
	if state == nil or state.stateUpdateQueued then
		return
	end
	state.stateUpdateQueued = true
	task.defer(function()
		local latestState = states[player]
		if latestState == nil then
			return
		end
		latestState.stateUpdateQueued = false
		fireState(player, isAuthorized(player))
	end)
end

local function rejectRequest(player: Player, state: PlayerDevState)
	state.rejectedRequests += 1
	player:SetAttribute("DevToolsRejectedRequestCount", state.rejectedRequests)
end

local function awardXPToLevel(player: Player, targetLevel: number): number
	local remaining = ProgressionService.GetXPNeededToReachLevel(player, targetLevel)
	local requested = remaining
	while remaining > 0 do
		local chunk = math.min(remaining, ProgressionConfig.MaxServerXPAward)
		local applied = ProgressionService.AwardXP(player, chunk)
		if applied <= 0 then
			break
		end
		remaining -= applied
	end
	return requested - remaining
end

local function resetRun(player: Player)
	-- Character respawn is the canonical lifecycle: progression, class, combat,
	-- visuals, collision, and standard weapon services all reset from it.
	player:LoadCharacter()
end

local function performAction(player: Player, action: string): string?
	local xpAmount = XP_ACTIONS[action]
	if xpAmount ~= nil then
		local applied = ProgressionService.AwardXP(player, xpAmount)
		return string.format("%s (%d XP applied)", action, applied)
	end

	local targetLevel = LEVEL_ACTIONS[action]
	if targetLevel ~= nil then
		local applied = awardXPToLevel(player, targetLevel)
		return string.format("%s (%d XP applied)", action, applied)
	end

	if action == "ToggleUnlimitedPoints" then
		local enabled = not ProgressionService.IsUnlimitedUpgradePoints(player)
		if not ProgressionService.SetUnlimitedUpgradePoints(player, enabled) then
			return nil
		end
		if not enabled then
			resetRun(player)
		end
		return string.format("%s (%s)", action, if enabled then "enabled" else "disabled and run reset")
	elseif action == "ResetRun" then
		resetRun(player)
		return action
	elseif action == "ReturnToLobby" then
		return if PlayerSessionService.ReturnToLobby(player) then action else nil
	elseif action == "StudioTestMoveToMainPortal" then
		if not RunService:IsStudio() then
			return nil
		end
		local portal = Workspace:FindFirstChild("WorkshopLobby")
		local portalPart = if portal ~= nil then portal:FindFirstChild("PortalField", true) else nil
		if portalPart == nil or not portalPart:IsA("BasePart") then
			return nil
		end
		local destination = CFrame.new(portalPart.Position + Vector3.new(0, 0, -3))
		return if PlayerSessionService.TeleportForStudioTest(player, destination) then action else nil
	elseif action == "StudioTestMoveToExtraction" then
		if not RunService:IsStudio() or not PlayerSessionService.IsArena(player) then
			return nil
		end
		local destination = CFrame.new(ExtractionConfig.ZoneCenter)
		return if PlayerSessionService.TeleportForStudioTest(player, destination) then action else nil
	elseif action == "StudioTestAuthoritativeDamage10" then
		if not RunService:IsStudio() or not PlayerSessionService.IsArena(player) then
			return nil
		end
		local character = player.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid == nil or AuthoritativeDamageService.ApplyHumanoidDamage(humanoid, 10) <= 0 then
			return nil
		end
		return action
	elseif action == "StudioTestProfileNormal" then
		return if ProfileDataService.SetStudioMockWriteMode(player, "Normal") then action else nil
	elseif action == "StudioTestProfileFailAll" then
		return if ProfileDataService.SetStudioMockWriteMode(player, "FailAll") then action else nil
	elseif action == "StudioTestProfileUncertainOnce" then
		return if ProfileDataService.SetStudioMockWriteMode(player, "UncertainOnce") then action else nil
	elseif action == "StudioTestReloadMockProfile" then
		return if ProfileDataService.ReloadStudioMockProfile(player) then action else nil
	elseif action == "StudioTestProfileUnavailable" then
		return if ProfileDataService.SetStudioMockProfileUnavailable(player) then action else nil
	elseif action == "StudioTestActivateImpactFoundry" then
		if not RunService:IsStudio() or not PlayerSessionService.IsArena(player) then
			return nil
		end
		if ClassService.GetClassId(player) == ClassConfig.BaseClassId then
			return nil
		end
		awardXPToLevel(player, ClassConfig.Level20Threshold)
		return if EvolutionRouteService.ActivateImpactFoundryForStudio(player) then action else nil
	elseif action == "HealToFull" then
		return if ProgressionService.HealToFull(player) then action else nil
	end
	return nil
end

local function handleRequest(player: Player, actionValue: unknown, ...: unknown)
	local state = states[player]
	if state == nil then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now - state.requestWindowStartedAt >= DevToolsConfig.RequestWindow then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if
		state.requestsInWindow > DevToolsConfig.MaximumRequestsPerWindow
		or now - state.lastRequestAt < DevToolsConfig.MinimumRequestInterval
	then
		state.lastRequestAt = now
		rejectRequest(player, state)
		return
	end
	state.lastRequestAt = now

	if select("#", ...) ~= 0 or typeof(actionValue) ~= "string" then
		rejectRequest(player, state)
		return
	end
	if not isAuthorized(player) then
		fireState(player, false)
		rejectRequest(player, state)
		return
	end

	local action = actionValue :: string
	if action == "RequestState" then
		fireState(player, true)
		return
	end
	local actionDetail = performAction(player, action)
	if actionDetail == nil then
		rejectRequest(player, state)
		return
	end

	state.acceptedActions += 1
	player:SetAttribute("DevToolsAcceptedActionCount", state.acceptedActions)
	print(string.format(
		"[Scrapcore DevTools] %s (%d) used %s",
		player.Name,
		player.UserId,
		actionDetail
	))
	queueStateUpdate(player)
end

local function connectPlayer(player: Player)
	if states[player] ~= nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local state: PlayerDevState = {
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastRequestAt = -math.huge,
		acceptedActions = 0,
		rejectedRequests = 0,
		stateUpdateQueued = false,
		attributeConnections = {},
		characterAddedConnection = nil,
	}
	states[player] = state
	player:SetAttribute("DevToolsAcceptedActionCount", 0)
	player:SetAttribute("DevToolsRejectedRequestCount", 0)

	for _, attributeName in {
		"RunLevel",
		"RunXP",
		"UnspentUpgradePoints",
		ClassConfig.ClassAttribute,
		EvolutionConfig.CurrentNodeAttribute,
		"DevUnlimitedUpgradePoints",
	} do
		table.insert(
			state.attributeConnections,
			player:GetAttributeChangedSignal(attributeName):Connect(function()
				queueStateUpdate(player)
			end)
		)
	end
	state.characterAddedConnection = player.CharacterAdded:Connect(function()
		task.defer(queueStateUpdate, player)
	end)
	task.defer(queueStateUpdate, player)
end

local function disconnectPlayer(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	for _, connection in state.attributeConnections do
		connection:Disconnect()
	end
	if state.characterAddedConnection ~= nil then
		state.characterAddedConnection:Disconnect()
	end
	states[player] = nil
end

function DevToolsService.IsAuthorizedForContext(userId: number, isStudio: boolean): boolean
	return DevToolsConfig.IsAuthorized(userId, isStudio)
end

function DevToolsService.Init()
	if initialized then
		return
	end
	initialized = true
	PlayerSessionService.Init()
	ProgressionService.Init()
	ClassService.Init()
	EvolutionRouteService.Init()
	requestRemote = getOrCreateRemote("DevToolsRequest")
	stateRemote = getOrCreateRemote("DevToolsState")
	local activeRequestRemote = requestRemote :: RemoteEvent
	activeRequestRemote.OnServerEvent:Connect(handleRequest)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return DevToolsService
