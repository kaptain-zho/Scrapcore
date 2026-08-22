--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))

type UpgradeDefinition = {
	AttributeName: string,
	DisplayName: string,
	Description: string,
	PerPoint: number,
}

type PlayerRunState = {
	runSerial: number,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	acceptedRequests: number,
	rejectedRequests: number,
	characterAddedConnection: RBXScriptConnection?,
	diedConnection: RBXScriptConnection?,
}

local upgradeDefinitions = ProgressionConfig.Upgrades :: {[string]: UpgradeDefinition}
local playerStates: {[Player]: PlayerRunState} = {}
local initialized = false
local upgradeRequestRemote: RemoteEvent? = nil

local ProgressionService = {}

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

local function setUpgradeRanksToZero(player: Player)
	for _, category in ProgressionConfig.UpgradeOrder do
		local definition = upgradeDefinitions[category]
		player:SetAttribute(definition.AttributeName, 0)
	end
end

local function resetRunAttributes(player: Player)
	player:SetAttribute("RunLevel", 1)
	player:SetAttribute("RunXP", 0)
	player:SetAttribute("XPToNextLevel", ProgressionConfig.GetXPToNextLevel(1))
	player:SetAttribute("UnspentUpgradePoints", 0)
	setUpgradeRanksToZero(player)
end

local function applyArmorToHumanoid(player: Player, humanoid: Humanoid)
	local rank = ProgressionService.GetUpgradeRank(player, "Armor")
	local newMaxHealth = ProgressionConfig.BaseMaxHealth + ProgressionConfig.GetArmorBonus(rank)
	local oldMaxHealth = math.max(humanoid.MaxHealth, 1)
	local healthRatio = math.clamp(humanoid.Health / oldMaxHealth, 0, 1)
	humanoid.MaxHealth = newMaxHealth
	if humanoid.Health > 0 then
		humanoid.Health = math.clamp(newMaxHealth * healthRatio, 1, newMaxHealth)
	end
end

local function rejectUpgradeRequest(player: Player, state: PlayerRunState)
	state.rejectedRequests += 1
	player:SetAttribute("ProgressionRejectedUpgradeCount", state.rejectedRequests)
end

local function resetRun(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	state.runSerial += 1
	resetRunAttributes(player)
end

local function bindCharacter(player: Player, character: Model)
	local state = playerStates[player]
	if state == nil then
		return
	end

	resetRun(player)
	local runSerial = state.runSerial
	if state.diedConnection ~= nil then
		state.diedConnection:Disconnect()
		state.diedConnection = nil
	end

	task.spawn(function()
		local humanoidInstance = character:WaitForChild("Humanoid", 10)
		local currentState = playerStates[player]
		if
			humanoidInstance == nil
			or not humanoidInstance:IsA("Humanoid")
			or currentState == nil
			or currentState.runSerial ~= runSerial
			or player.Character ~= character
		then
			return
		end

		local humanoid = humanoidInstance
		applyArmorToHumanoid(player, humanoid)
		currentState.diedConnection = humanoid.Died:Connect(function()
			local latestState = playerStates[player]
			if latestState ~= nil and latestState.runSerial == runSerial then
				resetRun(player)
			end
		end)
	end)
end

local function connectPlayer(player: Player)
	if playerStates[player] ~= nil then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local state: PlayerRunState = {
		runSerial = 0,
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastRequestAt = -math.huge,
		acceptedRequests = 0,
		rejectedRequests = 0,
		characterAddedConnection = nil,
		diedConnection = nil,
	}
	playerStates[player] = state
	player:SetAttribute("ProgressionAcceptedUpgradeCount", 0)
	player:SetAttribute("ProgressionRejectedUpgradeCount", 0)
	resetRun(player)

	state.characterAddedConnection = player.CharacterAdded:Connect(function(character: Model)
		bindCharacter(player, character)
	end)
	if player.Character ~= nil then
		bindCharacter(player, player.Character)
	end
end

local function disconnectPlayer(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	if state.characterAddedConnection ~= nil then
		state.characterAddedConnection:Disconnect()
	end
	if state.diedConnection ~= nil then
		state.diedConnection:Disconnect()
	end
	playerStates[player] = nil
end

function ProgressionService.GetUpgradeRank(player: Player, category: string): number
	local definition = upgradeDefinitions[category]
	if definition == nil then
		return 0
	end
	return getIntegerAttribute(player, definition.AttributeName, 0, ProgressionConfig.MaxUpgradeRank)
end

function ProgressionService.GetRunSerial(player: Player): number
	local state = playerStates[player]
	return if state ~= nil then state.runSerial else -1
end

function ProgressionService.IsRunActive(player: Player, runSerial: number): boolean
	local state = playerStates[player]
	return state ~= nil and state.runSerial == runSerial and getAliveHumanoid(player) ~= nil
end

function ProgressionService.GetHammerDamage(player: Player, baseDamage: number): number
	local multiplier = ProgressionConfig.GetPowerMultiplier(ProgressionService.GetUpgradeRank(player, "Power"))
	return baseDamage * multiplier
end

function ProgressionService.GetHammerCooldown(player: Player, baseCooldown: number): number
	local multiplier = ProgressionConfig.GetRecoveryMultiplier(ProgressionService.GetUpgradeRank(player, "Recovery"))
	return baseCooldown * multiplier
end

function ProgressionService.GetHammerKnockback(player: Player, baseKnockback: number): number
	local multiplier = ProgressionConfig.GetForceMultiplier(ProgressionService.GetUpgradeRank(player, "Force"))
	return baseKnockback * multiplier
end

function ProgressionService.GetMovementSpeed(player: Player, baseSpeed: number): number
	local multiplier = ProgressionConfig.GetMobilityMultiplier(ProgressionService.GetUpgradeRank(player, "Mobility"))
	return baseSpeed * multiplier
end

function ProgressionService.AwardXP(player: Player, amount: number): number
	local state = playerStates[player]
	if
		state == nil
		or getAliveHumanoid(player) == nil
		or not isFinite(amount)
		or amount <= 0
	then
		return 0
	end

	local remaining = math.clamp(math.floor(amount), 0, ProgressionConfig.MaxServerXPAward)
	local requestedAward = remaining
	local level = getIntegerAttribute(player, "RunLevel", 1, ProgressionConfig.LevelCap)
	local xp = getIntegerAttribute(player, "RunXP", 0, ProgressionConfig.MaxServerXPAward)
	local points = getIntegerAttribute(
		player,
		"UnspentUpgradePoints",
		0,
		ProgressionConfig.MaxUnspentUpgradePoints
	)

	while remaining > 0 and level < ProgressionConfig.LevelCap do
		local needed = ProgressionConfig.GetXPToNextLevel(level)
		local room = math.max(needed - xp, 0)
		if remaining < room then
			xp += remaining
			remaining = 0
		else
			remaining -= room
			level += 1
			xp = 0
			points = math.clamp(
				points + ProgressionConfig.UpgradePointsPerLevel,
				0,
				ProgressionConfig.MaxUnspentUpgradePoints
			)
		end
	end

	if level >= ProgressionConfig.LevelCap then
		level = ProgressionConfig.LevelCap
		xp = 0
	end

	player:SetAttribute("RunLevel", level)
	player:SetAttribute("RunXP", xp)
	player:SetAttribute("XPToNextLevel", ProgressionConfig.GetXPToNextLevel(level))
	player:SetAttribute("UnspentUpgradePoints", points)
	return requestedAward - remaining
end

function ProgressionService.AwardElimination(
	attacker: Player,
	targetPlayer: Player?,
	targetHumanoid: Humanoid
): boolean
	if
		targetPlayer == nil
		or targetPlayer == attacker
		or targetHumanoid.Health > 0
		or targetHumanoid:GetAttribute("ScrapcoreEliminationRewarded") == true
	then
		return false
	end

	targetHumanoid:SetAttribute("ScrapcoreEliminationRewarded", true)
	return ProgressionService.AwardXP(attacker, ProgressionConfig.PlayerEliminationXP) > 0
end

function ProgressionService.ResetRun(player: Player)
	resetRun(player)
	local humanoid = getAliveHumanoid(player)
	if humanoid ~= nil then
		applyArmorToHumanoid(player, humanoid)
	end
end

local function handleUpgradeRequest(player: Player, categoryValue: unknown, ...: unknown)
	local state = playerStates[player]
	if state == nil then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now - state.requestWindowStartedAt >= ProgressionConfig.UpgradeRequestWindow then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if
		state.requestsInWindow > ProgressionConfig.MaxUpgradeRequestsPerWindow
		or now - state.lastRequestAt < ProgressionConfig.MinimumUpgradeRequestInterval
	then
		rejectUpgradeRequest(player, state)
		return
	end
	state.lastRequestAt = now

	if select("#", ...) ~= 0 or typeof(categoryValue) ~= "string" then
		rejectUpgradeRequest(player, state)
		return
	end

	local category = categoryValue :: string
	local definition = upgradeDefinitions[category]
	if definition == nil or getAliveHumanoid(player) == nil then
		rejectUpgradeRequest(player, state)
		return
	end

	local points = getIntegerAttribute(
		player,
		"UnspentUpgradePoints",
		0,
		ProgressionConfig.MaxUnspentUpgradePoints
	)
	local rank = getIntegerAttribute(player, definition.AttributeName, 0, ProgressionConfig.MaxUpgradeRank)
	if points <= 0 or rank >= ProgressionConfig.MaxUpgradeRank then
		rejectUpgradeRequest(player, state)
		return
	end

	player:SetAttribute("UnspentUpgradePoints", points - 1)
	player:SetAttribute(definition.AttributeName, rank + 1)
	if category == "Armor" then
		local humanoid = getAliveHumanoid(player)
		if humanoid ~= nil then
			applyArmorToHumanoid(player, humanoid)
		end
	end

	state.acceptedRequests += 1
	player:SetAttribute("ProgressionAcceptedUpgradeCount", state.acceptedRequests)
end

function ProgressionService.Init()
	if initialized then
		return
	end
	initialized = true

	local remotesInstance = ReplicatedStorage:FindFirstChild("Remotes")
	if remotesInstance == nil then
		remotesInstance = Instance.new("Folder")
		remotesInstance.Name = "Remotes"
		remotesInstance.Parent = ReplicatedStorage
	elseif not remotesInstance:IsA("Folder") then
		error("ReplicatedStorage.Remotes must be a Folder")
	end
	local remotes = remotesInstance :: Folder

	local existingRemote = remotes:FindFirstChild("ProgressionUpgradeRequest")
	if existingRemote ~= nil and not existingRemote:IsA("RemoteEvent") then
		error("ReplicatedStorage.Remotes.ProgressionUpgradeRequest must be a RemoteEvent")
	end
	if existingRemote == nil then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "ProgressionUpgradeRequest"
		remote.Parent = remotes
		upgradeRequestRemote = remote
	else
		upgradeRequestRemote = existingRemote :: RemoteEvent
	end

	(upgradeRequestRemote :: RemoteEvent).OnServerEvent:Connect(handleUpgradeRequest)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return ProgressionService
