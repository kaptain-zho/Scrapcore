--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local CombatConfig = require(shared:WaitForChild("CombatConfig"))
local MovementConfig = require(shared:WaitForChild("MovementConfig"))

type UpgradeDefinition = {
	AttributeName: string,
	DisplayName: string,
	Description: string,
	PerPoint: number,
}

type PlayerRunState = {
	runSerial: number,
	unlimitedUpgradePoints: boolean,
	writingUnlimitedAttribute: boolean,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	acceptedRequests: number,
	rejectedRequests: number,
	characterAddedConnection: RBXScriptConnection?,
	characterChildAddedConnection: RBXScriptConnection?,
	diedConnection: RBXScriptConnection?,
	healthChangedConnection: RBXScriptConnection?,
	unlimitedAttributeConnection: RBXScriptConnection?,
	humanoid: Humanoid?,
	lastObservedHealth: number,
	lastDamageAt: number,
}

local upgradeDefinitions = ProgressionConfig.Upgrades :: {[string]: UpgradeDefinition}
local playerStates: {[Player]: PlayerRunState} = {}
local initialized = false
local upgradeRequestRemote: RemoteEvent? = nil
local DEV_UNLIMITED_ATTRIBUTE = "DevUnlimitedUpgradePoints"

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

local function getStrictIntegerAttribute(
	instance: Instance,
	name: string,
	minimum: number,
	maximum: number
): number?
	local value = instance:GetAttribute(name)
	if
		typeof(value) ~= "number"
		or not isFinite(value)
		or value % 1 ~= 0
		or value < minimum
		or value > maximum
	then
		return nil
	end
	return value
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
	player:SetAttribute("UnspentUpgradePoints", ProgressionConfig.StartingUpgradePoints)
	setUpgradeRanksToZero(player)
end

local function applyHealthToHumanoid(player: Player, humanoid: Humanoid)
	local rank = ProgressionService.GetUpgradeRank(player, "Health")
	local newMaxHealth = ProgressionConfig.BaseMaxHealth + ProgressionConfig.GetHealthBonus(rank)
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
	state.lastDamageAt = Workspace:GetServerTimeNow()
	state.lastObservedHealth = if state.humanoid ~= nil then state.humanoid.Health else 0
	resetRunAttributes(player)
end

local function disableDefaultHealthRegeneration(instance: Instance)
	if instance.Name == "Health" and instance:IsA("BaseScript") then
		instance.Enabled = false
	end
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
	if state.healthChangedConnection ~= nil then
		state.healthChangedConnection:Disconnect()
		state.healthChangedConnection = nil
	end
	if state.characterChildAddedConnection ~= nil then
		state.characterChildAddedConnection:Disconnect()
	end
	for _, child in character:GetChildren() do
		disableDefaultHealthRegeneration(child)
	end
	state.characterChildAddedConnection = character.ChildAdded:Connect(disableDefaultHealthRegeneration)
	state.humanoid = nil

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
		applyHealthToHumanoid(player, humanoid)
		currentState.humanoid = humanoid
		currentState.lastObservedHealth = humanoid.Health
		currentState.lastDamageAt = Workspace:GetServerTimeNow()
		currentState.healthChangedConnection = humanoid.HealthChanged:Connect(function(health: number)
			local latestState = playerStates[player]
			if
				latestState == nil
				or latestState.runSerial ~= runSerial
				or latestState.humanoid ~= humanoid
			then
				return
			end
			if health < latestState.lastObservedHealth - 0.001 then
				latestState.lastDamageAt = Workspace:GetServerTimeNow()
			end
			latestState.lastObservedHealth = health
		end)
		currentState.diedConnection = humanoid.Died:Connect(function()
			local latestState = playerStates[player]
			if latestState ~= nil and latestState.runSerial == runSerial then
				if latestState.healthChangedConnection ~= nil then
					latestState.healthChangedConnection:Disconnect()
					latestState.healthChangedConnection = nil
				end
				latestState.humanoid = nil
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
		unlimitedUpgradePoints = false,
		writingUnlimitedAttribute = false,
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastRequestAt = -math.huge,
		acceptedRequests = 0,
		rejectedRequests = 0,
		characterAddedConnection = nil,
		characterChildAddedConnection = nil,
		diedConnection = nil,
		healthChangedConnection = nil,
		unlimitedAttributeConnection = nil,
		humanoid = nil,
		lastObservedHealth = 0,
		lastDamageAt = now,
	}
	playerStates[player] = state
	player:SetAttribute("ProgressionAcceptedUpgradeCount", 0)
	player:SetAttribute("ProgressionRejectedUpgradeCount", 0)
	player:SetAttribute(DEV_UNLIMITED_ATTRIBUTE, false)
	resetRun(player)

	state.unlimitedAttributeConnection = player:GetAttributeChangedSignal(DEV_UNLIMITED_ATTRIBUTE):Connect(function()
		if state.writingUnlimitedAttribute then
			return
		end
		state.writingUnlimitedAttribute = true
		player:SetAttribute(DEV_UNLIMITED_ATTRIBUTE, state.unlimitedUpgradePoints)
		state.writingUnlimitedAttribute = false
	end)

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
	if state.characterChildAddedConnection ~= nil then
		state.characterChildAddedConnection:Disconnect()
	end
	if state.healthChangedConnection ~= nil then
		state.healthChangedConnection:Disconnect()
	end
	if state.unlimitedAttributeConnection ~= nil then
		state.unlimitedAttributeConnection:Disconnect()
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
	local multiplier = ProgressionConfig.GetDamageMultiplier(ProgressionService.GetUpgradeRank(player, "Damage"))
	return baseDamage * multiplier
end

function ProgressionService.IsUnlimitedUpgradePoints(player: Player): boolean
	local state = playerStates[player]
	return state ~= nil and state.unlimitedUpgradePoints
end

function ProgressionService.SetUnlimitedUpgradePoints(player: Player, enabled: boolean): boolean
	local state = playerStates[player]
	if state == nil then
		return false
	end
	state.unlimitedUpgradePoints = enabled
	state.writingUnlimitedAttribute = true
	player:SetAttribute(DEV_UNLIMITED_ATTRIBUTE, enabled)
	state.writingUnlimitedAttribute = false
	return true
end

function ProgressionService.GetXPNeededToReachLevel(player: Player, targetLevel: number): number
	if not isFinite(targetLevel) or targetLevel % 1 ~= 0 then
		return 0
	end
	local level = getStrictIntegerAttribute(player, "RunLevel", 1, ProgressionConfig.LevelCap)
	local xp = getStrictIntegerAttribute(player, "RunXP", 0, ProgressionConfig.MaxServerXPAward)
	local safeTarget = math.clamp(targetLevel, 1, ProgressionConfig.LevelCap)
	if level == nil or xp == nil or level >= safeTarget then
		return 0
	end

	local needed = math.max(ProgressionConfig.GetXPToNextLevel(level) - xp, 0)
	for intermediateLevel = level + 1, safeTarget - 1 do
		needed += ProgressionConfig.GetXPToNextLevel(intermediateLevel)
	end
	return needed
end

function ProgressionService.HealToFull(player: Player): boolean
	local state = playerStates[player]
	local humanoid = getAliveHumanoid(player)
	if state == nil or humanoid == nil then
		return false
	end
	applyHealthToHumanoid(player, humanoid)
	humanoid.Health = humanoid.MaxHealth
	state.lastObservedHealth = humanoid.Health
	return true
end

function ProgressionService.GetHammerCooldown(player: Player, baseCooldown: number): number
	local multiplier = ProgressionConfig.GetAttackRateMultiplier(
		ProgressionService.GetUpgradeRank(player, "Attack Rate")
	)
	return baseCooldown * multiplier
end

function ProgressionService.GetMovementSpeed(player: Player, baseSpeed: number): number
	local multiplier = ProgressionConfig.GetSpeedMultiplier(ProgressionService.GetUpgradeRank(player, "Speed"))
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
		applyHealthToHumanoid(player, humanoid)
	end
end

local function isDerivedUpgradeValueSafe(category: string, rank: number): boolean
	if category == "Speed" then
		local maxSpeed = MovementConfig.MaxSpeed * ProgressionConfig.GetSpeedMultiplier(rank)
		return isFinite(maxSpeed)
			and maxSpeed >= MovementConfig.MaxSpeed
			and maxSpeed <= MovementConfig.MaxUpgradedSpeed + 0.001
	elseif category == "Attack Rate" then
		local cooldown = CombatConfig.Cooldown * ProgressionConfig.GetAttackRateMultiplier(rank)
		return isFinite(cooldown)
			and cooldown >= CombatConfig.MinCooldown
			and cooldown <= CombatConfig.Cooldown
	elseif category == "Damage" then
		local damage = CombatConfig.Damage * ProgressionConfig.GetDamageMultiplier(rank)
		return isFinite(damage) and damage >= 0 and damage <= CombatConfig.MaxDamage
	elseif category == "Health" then
		local maxHealth = ProgressionConfig.BaseMaxHealth + ProgressionConfig.GetHealthBonus(rank)
		return isFinite(maxHealth)
			and maxHealth >= ProgressionConfig.BaseMaxHealth
			and maxHealth <= ProgressionConfig.MaxUpgradedMaxHealth
	elseif category == "Health Regen" then
		local regenPerSecond = ProgressionConfig.GetHealthRegenPerSecond(rank)
		return isFinite(regenPerSecond)
			and regenPerSecond >= 0
			and regenPerSecond <= ProgressionConfig.MaxHealthRegenPerSecond
	end
	return false
end

local function validateUpgradeConfiguration()
	for _, category in ProgressionConfig.UpgradeOrder do
		if not isDerivedUpgradeValueSafe(category, ProgressionConfig.MaxUpgradeRank) then
			error(string.format("ProgressionConfig produces an unsafe Rank %d %s value", ProgressionConfig.MaxUpgradeRank, category))
		end
	end
end

local function handleUpgradeRequest(
	player: Player,
	categoryValue: unknown,
	requestedRankValue: unknown,
	...: unknown
)
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

	if
		select("#", ...) ~= 0
		or typeof(categoryValue) ~= "string"
		or typeof(requestedRankValue) ~= "number"
	then
		rejectUpgradeRequest(player, state)
		return
	end

	local category = categoryValue :: string
	local requestedRank = requestedRankValue :: number
	local definition = upgradeDefinitions[category]
	if
		definition == nil
		or not isFinite(requestedRank)
		or requestedRank % 1 ~= 0
		or getAliveHumanoid(player) == nil
	then
		rejectUpgradeRequest(player, state)
		return
	end

	local level = getStrictIntegerAttribute(player, "RunLevel", 1, ProgressionConfig.LevelCap)
	local points = getStrictIntegerAttribute(
		player,
		"UnspentUpgradePoints",
		0,
		ProgressionConfig.MaxUnspentUpgradePoints
	)
	if level == nil or points == nil then
		rejectUpgradeRequest(player, state)
		return
	end

	local ranksByCategory: {[string]: number} = {}
	local totalSpent = 0
	for _, existingCategory in ProgressionConfig.UpgradeOrder do
		local existingDefinition = upgradeDefinitions[existingCategory]
		local existingRank = getStrictIntegerAttribute(
			player,
			existingDefinition.AttributeName,
			0,
			ProgressionConfig.MaxUpgradeRank
		)
		if existingRank == nil then
			rejectUpgradeRequest(player, state)
			return
		end
		ranksByCategory[existingCategory] = existingRank
		totalSpent += existingRank
	end

	local earnedPoints = ProgressionConfig.GetEarnedUpgradePoints(level)
	local rank = ranksByCategory[category]
	local unlimitedUpgradePoints = state.unlimitedUpgradePoints
	if
		rank >= ProgressionConfig.MaxUpgradeRank
		or requestedRank ~= rank + 1
		or requestedRank > ProgressionConfig.MaxUpgradeRank
		or not isDerivedUpgradeValueSafe(category, requestedRank)
	then
		rejectUpgradeRequest(player, state)
		return
	end
	if
		not unlimitedUpgradePoints
		and (
			points <= 0
			or totalSpent >= earnedPoints
			or points ~= earnedPoints - totalSpent
		)
	then
		rejectUpgradeRequest(player, state)
		return
	end

	if not unlimitedUpgradePoints then
		player:SetAttribute("UnspentUpgradePoints", points - 1)
	end
	player:SetAttribute(definition.AttributeName, requestedRank)
	if category == "Health" then
		local humanoid = getAliveHumanoid(player)
		if humanoid ~= nil then
			applyHealthToHumanoid(player, humanoid)
		end
	end

	state.acceptedRequests += 1
	player:SetAttribute("ProgressionAcceptedUpgradeCount", state.acceptedRequests)
end

local healthRegenAccumulator = 0

local function updateHealthRegeneration(deltaTime: number)
	if not isFinite(deltaTime) or deltaTime <= 0 then
		return
	end
	healthRegenAccumulator += deltaTime
	if healthRegenAccumulator < ProgressionConfig.HealthRegenTickInterval then
		return
	end

	local elapsed = healthRegenAccumulator
	healthRegenAccumulator = 0
	local now = Workspace:GetServerTimeNow()
	for player, state in playerStates do
		local humanoid = state.humanoid
		if
			humanoid == nil
			or humanoid.Parent == nil
			or humanoid.Health <= 0
			or humanoid.Health >= humanoid.MaxHealth
			or now - state.lastDamageAt < ProgressionConfig.HealthRegenDamageDelay
		then
			continue
		end

		local rank = ProgressionService.GetUpgradeRank(player, "Health Regen")
		local regenPerSecond = ProgressionConfig.GetHealthRegenPerSecond(rank)
		if regenPerSecond <= 0 or regenPerSecond > ProgressionConfig.MaxHealthRegenPerSecond then
			continue
		end

		local newHealth = math.min(humanoid.Health + regenPerSecond * elapsed, humanoid.MaxHealth)
		state.lastObservedHealth = newHealth
		humanoid.Health = newHealth
	end
end

function ProgressionService.Init()
	if initialized then
		return
	end
	validateUpgradeConfiguration()
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
	RunService.Heartbeat:Connect(updateHealthRegeneration)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return ProgressionService
