--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local CombatConfig = require(shared:WaitForChild("CombatConfig"))
local EvolutionConfig = require(shared:WaitForChild("EvolutionConfig"))
local ImpactFoundryConfig = require(shared:WaitForChild("ImpactFoundryConfig"))
local MovementConfig = require(shared:WaitForChild("MovementConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local AuthoritativeDamageService = require(script.Parent:WaitForChild("AuthoritativeDamageService"))
local BreakableObjectService = require(script.Parent:WaitForChild("BreakableObjectService"))
local DisplacementResistanceService = require(script.Parent:WaitForChild("DisplacementResistanceService"))
local EvolutionRouteService = require(script.Parent:WaitForChild("EvolutionRouteService"))
local PlayerSessionService = require(script.Parent:WaitForChild("PlayerSessionService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

export type MovementAuthorization = {
	legalMaxSpeed: number,
	maximumAcceleration: number,
	maximumSampleDistance: number,
	speedTolerance: number,
	clearViolation: boolean,
}

type ImpactState = {
	phase: string,
	character: Model?,
	nextAttackAt: number,
	phaseStartedAt: number,
	phaseEndsAt: number,
	windupDuration: number,
	cooldown: number,
	damage: number,
	attackSerial: number,
	lastSequence: number,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	acceptedRequests: number,
	rejectedRequests: number,
	strikeCount: number,
	affectedTargetCount: number,
	characterAddedConnection: RBXScriptConnection?,
	diedConnection: RBXScriptConnection?,
	routeConnection: RBXScriptConnection?,
	sessionConnection: RBXScriptConnection?,
}

type Candidate = { model: Model, targetPart: BasePart, humanoid: Humanoid?, breakable: Model?, distance: number }

local states: {[Player]: ImpactState} = {}
local initialized = false
local requestRemote: RemoteEvent? = nil
local broadcastRemote: RemoteEvent? = nil
local KNOCKBACK_VELOCITY_ATTRIBUTE = "CombatKnockbackVelocity"
local KNOCKBACK_STARTED_AT_ATTRIBUTE = "CombatKnockbackStartedAt"
local KNOCKBACK_UNTIL_ATTRIBUTE = "CombatKnockbackUntil"

local ImpactFoundryCombatService = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getOrCreateRemote(name: string): RemoteEvent
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	elseif not remotes:IsA("Folder") then error("ReplicatedStorage.Remotes must be a Folder") end
	local existing = remotes:FindFirstChild(name)
	if existing ~= nil then
		if not existing:IsA("RemoteEvent") then error(string.format("ReplicatedStorage.Remotes.%s must be a RemoteEvent", name)) end
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local function getAliveCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if character == nil or character.Parent == nil then return nil, nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then return nil, nil, nil end
	return character, humanoid, root
end

local function getOrigin(character: Model): (Vector3?, BasePart?)
	local chassis = character:FindFirstChild("RobotChassis")
	if chassis == nil or not chassis:IsA("Model") then return nil, nil end
	local equipped = chassis:FindFirstChild(ClassConfig.EquippedImpactFoundryName)
	if equipped == nil or not equipped:IsA("Model") then return nil, nil end
	local weaponRoot = equipped:FindFirstChild("ImpactFoundryRoot", true)
	local hitOrigin = equipped:FindFirstChild("ImpactFoundryHitOrigin", true)
	if weaponRoot == nil or not weaponRoot:IsA("BasePart") or hitOrigin == nil or not hitOrigin:IsA("Attachment") then return nil, nil end
	return hitOrigin.WorldPosition, weaponRoot
end

local function getTargetFromPart(part: BasePart): (Model?, Humanoid?, BasePart?)
	local current: Instance? = part
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			local root = current:FindFirstChild("HumanoidRootPart")
			if humanoid ~= nil and root ~= nil and root:IsA("BasePart") then return current, humanoid, root end
		end
		current = current.Parent
	end
	return nil, nil, nil
end

local function hasLineOfSight(origin: Vector3, target: Instance, targetPart: BasePart, attacker: Model): boolean
	local direction = targetPart.Position - origin
	if direction.Magnitude <= 0.01 then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker }
	params.IgnoreWater = true
	local result = Workspace:Raycast(origin, direction, params)
	return result == nil or result.Instance:IsDescendantOf(target)
end

local function isInWeaponArea(origin: Vector3, attackerRoot: BasePart, targetPart: BasePart): (boolean, number)
	local offset = targetPart.Position - origin
	local distance = offset.Magnitude
	if distance > ImpactFoundryConfig.MaximumTargetRange or math.abs(offset.Y) > ImpactFoundryConfig.MaximumVerticalDifference then return false, distance end
	local horizontal = Vector3.new(offset.X, 0, offset.Z)
	local forward = Vector3.new(attackerRoot.CFrame.LookVector.X, 0, attackerRoot.CFrame.LookVector.Z)
	if horizontal.Magnitude <= 0.01 then return true, distance end
	return forward.Magnitude > 0.01 and forward.Unit:Dot(horizontal.Unit) >= ImpactFoundryConfig.MinimumForwardDot, distance
end

local function applyKnockback(target: Model, targetRoot: BasePart, direction: Vector3)
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude <= 0.01 then return end
	local resistance = DisplacementResistanceService.GetHorizontalMultiplier(target, horizontal)
	local speed = math.clamp(ImpactFoundryConfig.KnockbackSpeed * resistance, 0, CombatConfig.MaxHorizontalKnockbackSpeed)
	local velocity = horizontal.Unit * speed
	local now = Workspace:GetServerTimeNow()
	target:SetAttribute(KNOCKBACK_VELOCITY_ATTRIBUTE, velocity)
	target:SetAttribute(KNOCKBACK_STARTED_AT_ATTRIBUTE, now)
	target:SetAttribute(KNOCKBACK_UNTIL_ATTRIBUTE, now + CombatConfig.KnockbackDuration)
	targetRoot:ApplyImpulse(velocity * targetRoot.AssemblyMass)
	task.delay(CombatConfig.KnockbackDuration, function()
		if target.Parent == nil or targetRoot.Parent == nil then return end
		local current = targetRoot.AssemblyLinearVelocity
		targetRoot.AssemblyLinearVelocity = Vector3.new(0, current.Y, 0)
	end)
end

local function resolveStrike(player: Player, state: ImpactState): number
	local character, _humanoid, attackerRoot = getAliveCharacter(player)
	if character == nil or attackerRoot == nil or character ~= state.character or not PlayerSessionService.IsArena(player) or not EvolutionRouteService.IsImpactFoundryActive(player) or character:GetAttribute("ImpactFoundryReady") ~= true then return 0 end
	local origin = getOrigin(character)
	if origin == nil then return 0 end
	local forward = Vector3.new(attackerRoot.CFrame.LookVector.X, 0, attackerRoot.CFrame.LookVector.Z)
	if forward.Magnitude <= 0.01 then return 0 end
	forward = forward.Unit
	local center = origin + forward * ImpactFoundryConfig.QueryForwardOffset
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.MaxParts = ImpactFoundryConfig.MaximumQueryParts
	local parts = Workspace:GetPartBoundsInBox(CFrame.lookAt(center, center + forward), ImpactFoundryConfig.QueryBoxSize, params)
	local candidates: {Candidate} = {}
	local seen: {[Model]: boolean} = {}
	for _, part in parts do
		local breakable = BreakableObjectService.GetBreakableFromPart(part)
		if breakable ~= nil then
			if seen[breakable] then continue end
			local targetPart = breakable.PrimaryPart
			if targetPart == nil then continue end
			local valid, distance = isInWeaponArea(origin, attackerRoot, targetPart)
			if not valid or not hasLineOfSight(origin, breakable, targetPart, character) then continue end
			seen[breakable] = true
			table.insert(candidates, { model = breakable, targetPart = targetPart, humanoid = nil, breakable = breakable, distance = distance })
			continue
		end
		local target, targetHumanoid, targetRoot = getTargetFromPart(part)
		if target == nil or targetHumanoid == nil or targetRoot == nil or target == character or targetHumanoid.Health <= 0 or seen[target] then continue end
		local targetPlayer = Players:GetPlayerFromCharacter(target)
		if targetPlayer ~= nil and not PlayerSessionService.IsArena(targetPlayer) then continue end
		local valid, distance = isInWeaponArea(origin, attackerRoot, targetRoot)
		if not valid or not hasLineOfSight(origin, target, targetRoot, character) then continue end
		seen[target] = true
		table.insert(candidates, { model = target, targetPart = targetRoot, humanoid = targetHumanoid, breakable = nil, distance = distance })
	end
	table.sort(candidates, function(left: Candidate, right: Candidate): boolean return left.distance < right.distance end)
	local affected = 0
	for _, candidate in candidates do
		if affected >= ImpactFoundryConfig.MaximumTargetsPerStrike then break end
		if candidate.breakable ~= nil then
			local applied = BreakableObjectService.Damage(candidate.breakable, player, state.damage * ImpactFoundryConfig.BreakableDamageMultiplier)
			if applied > 0 then affected += 1 end
		elseif candidate.humanoid ~= nil then
			local healthBefore = candidate.humanoid.Health
			local applied = AuthoritativeDamageService.ApplyHumanoidDamage(candidate.humanoid, state.damage)
			if applied > 0 then
				applyKnockback(candidate.model, candidate.targetPart, candidate.targetPart.Position - attackerRoot.Position)
				affected += 1
			end
			if healthBefore > 0 and candidate.humanoid.Health <= 0 then ProgressionService.AwardElimination(player, Players:GetPlayerFromCharacter(candidate.model), candidate.humanoid) end
		end
	end
	return affected
end

local function broadcast(player: Player, state: ImpactState)
	player:SetAttribute("ImpactFoundryAttackPhase", state.phase)
	player:SetAttribute("ImpactFoundryAttackSerial", state.attackSerial)
	player:SetAttribute("ImpactFoundryPhaseStartedAt", state.phaseStartedAt)
	player:SetAttribute("ImpactFoundryPhaseEndsAt", state.phaseEndsAt)
	local remote = broadcastRemote
	if remote ~= nil then remote:FireAllClients(player, state.attackSerial, state.phase, state.phaseStartedAt, state.phaseEndsAt) end
end

local function setPhase(player: Player, state: ImpactState, phase: string, startedAt: number, endsAt: number)
	state.phase = phase
	state.phaseStartedAt = startedAt
	state.phaseEndsAt = endsAt
	broadcast(player, state)
end

local function cancel(player: Player, state: ImpactState)
	state.character = nil
	state.nextAttackAt = 0
	DisplacementResistanceService.Clear(player)
	setPhase(player, state, "Idle", Workspace:GetServerTimeNow(), 0)
end

local function reject(player: Player, state: ImpactState)
	state.rejectedRequests += 1
	player:SetAttribute("ImpactFoundryRejectedRequestCount", state.rejectedRequests)
end

local function handleRequest(player: Player, sequenceValue: unknown, ...: unknown)
	local state = states[player]
	if state == nil then return end
	local now = Workspace:GetServerTimeNow()
	if now - state.requestWindowStartedAt >= ImpactFoundryConfig.RequestRateWindow then state.requestWindowStartedAt = now state.requestsInWindow = 0 end
	state.requestsInWindow += 1
	if state.requestsInWindow > ImpactFoundryConfig.MaximumRequestsPerWindow or now - state.lastRequestAt < ImpactFoundryConfig.MinimumRequestInterval then state.lastRequestAt = now reject(player, state) return end
	state.lastRequestAt = now
	if select("#", ...) ~= 0 or typeof(sequenceValue) ~= "number" then reject(player, state) return end
	local sequence = sequenceValue :: number
	if not isFinite(sequence) or sequence % 1 ~= 0 or sequence <= state.lastSequence or sequence > state.lastSequence + ImpactFoundryConfig.MaximumSequenceAdvance then reject(player, state) return end
	state.lastSequence = sequence
	local character, _humanoid, _root = getAliveCharacter(player)
	if state.phase ~= "Idle" or now < state.nextAttackAt or character == nil or not PlayerSessionService.IsArena(player) or not EvolutionRouteService.IsImpactFoundryActive(player) or character:GetAttribute("ImpactFoundryReady") ~= true or getOrigin(character) == nil then reject(player, state) return end
	local attackRateRank = ProgressionService.GetUpgradeRank(player, "Attack Rate")
	local damageRank = ProgressionService.GetUpgradeRank(player, "Damage")
	state.character = character
	state.windupDuration = ImpactFoundryConfig.GetWindupDuration(attackRateRank)
	state.cooldown = ImpactFoundryConfig.GetCooldown(attackRateRank)
	state.damage = ImpactFoundryConfig.GetDamage(damageRank)
	state.nextAttackAt = now + state.cooldown
	state.attackSerial += 1
	state.acceptedRequests += 1
	player:SetAttribute("ImpactFoundryAcceptedRequestCount", state.acceptedRequests)
	setPhase(player, state, "Windup", now, now + state.windupDuration)
	DisplacementResistanceService.BeginFrontalCommitment(player, character, now + state.windupDuration, ImpactFoundryConfig.FrontalResistanceMultiplier, ImpactFoundryConfig.FrontalResistanceMinimumDot)
end

local function update(_deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	for player, state in states do
		if state.phase == "Idle" then continue end
		local character, humanoid = getAliveCharacter(player)
		if character == nil or humanoid == nil or character ~= state.character or not PlayerSessionService.IsArena(player) or not EvolutionRouteService.IsImpactFoundryActive(player) or character:GetAttribute("ImpactFoundryReady") ~= true or getOrigin(character) == nil then cancel(player, state) continue end
		if state.phase == "Windup" and now >= state.phaseEndsAt then
			DisplacementResistanceService.Clear(player)
			local affected = resolveStrike(player, state)
			state.strikeCount += 1
			state.affectedTargetCount += affected
			player:SetAttribute("ImpactFoundryStrikeCount", state.strikeCount)
			player:SetAttribute("ImpactFoundryAffectedTargetCount", state.affectedTargetCount)
			setPhase(player, state, "Impact", now, now + ImpactFoundryConfig.ImpactFeedbackDuration)
		elseif state.phase == "Impact" and now >= state.phaseEndsAt then
			setPhase(player, state, "Recovery", now, state.nextAttackAt)
		elseif state.phase == "Recovery" and now >= state.nextAttackAt then
			state.character = nil
			setPhase(player, state, "Idle", now, 0)
		end
	end
end

local function bindCharacter(player: Player, character: Model)
	local state = states[player]
	if state == nil then return end
	if state.diedConnection ~= nil then state.diedConnection:Disconnect() end
	cancel(player, state)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid == nil or not humanoid:IsA("Humanoid") or states[player] ~= state or player.Character ~= character then return end
		state.diedConnection = humanoid.Died:Connect(function() if states[player] == state then cancel(player, state) end end)
	end)
end

local function connectPlayer(player: Player)
	if states[player] ~= nil then return end
	local now = Workspace:GetServerTimeNow()
	local state: ImpactState = {
		phase = "Idle", character = nil, nextAttackAt = 0, phaseStartedAt = now, phaseEndsAt = 0,
		windupDuration = ImpactFoundryConfig.WindupAtRankZero, cooldown = ImpactFoundryConfig.CooldownAtRankZero, damage = ImpactFoundryConfig.DamageAtRankZero,
		attackSerial = 0, lastSequence = 0, requestWindowStartedAt = now, requestsInWindow = 0, lastRequestAt = -math.huge,
		acceptedRequests = 0, rejectedRequests = 0, strikeCount = 0, affectedTargetCount = 0,
		characterAddedConnection = nil, diedConnection = nil, routeConnection = nil, sessionConnection = nil,
	}
	states[player] = state
	player:SetAttribute("ImpactFoundryAcceptedRequestCount", 0)
	player:SetAttribute("ImpactFoundryRejectedRequestCount", 0)
	player:SetAttribute("ImpactFoundryStrikeCount", 0)
	player:SetAttribute("ImpactFoundryAffectedTargetCount", 0)
	broadcast(player, state)
	state.routeConnection = player:GetAttributeChangedSignal(EvolutionConfig.CurrentNodeAttribute):Connect(function() if not EvolutionRouteService.IsImpactFoundryActive(player) then cancel(player, state) end end)
	state.sessionConnection = player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(function() if not PlayerSessionService.IsArena(player) then cancel(player, state) end end)
	state.characterAddedConnection = player.CharacterAdded:Connect(function(character: Model) bindCharacter(player, character) end)
	if player.Character ~= nil then bindCharacter(player, player.Character) end
end

local function disconnectPlayer(player: Player)
	local state = states[player]
	if state == nil then return end
	for _, connection in { state.characterAddedConnection, state.diedConnection, state.routeConnection, state.sessionConnection } do if connection ~= nil then connection:Disconnect() end end
	DisplacementResistanceService.Clear(player)
	states[player] = nil
end

function ImpactFoundryCombatService.GetMovementAuthorization(player: Player): MovementAuthorization?
	local state = states[player]
	if state == nil or state.phase ~= "Windup" or not EvolutionRouteService.IsImpactFoundryActive(player) then return nil end
	local speedRank = ProgressionService.GetUpgradeRank(player, "Speed")
	local normalMaxSpeed = MovementConfig.MaxSpeed * ProgressionConfig.GetSpeedMultiplier(speedRank)
	return {
		legalMaxSpeed = normalMaxSpeed * ImpactFoundryConfig.WindupMovementSpeedMultiplier,
		maximumAcceleration = MovementConfig.ServerMaxAcceleration * ImpactFoundryConfig.WindupSteeringMultiplier,
		maximumSampleDistance = MovementConfig.ServerMaxTeleportDistance,
		speedTolerance = MovementConfig.ServerSpeedTolerance,
		clearViolation = false,
	}
end

function ImpactFoundryCombatService.CancelForPlayer(player: Player)
	local state = states[player]
	if state ~= nil then cancel(player, state) end
end

local function validateConfiguration()
	local epsilon = 0.0001
	if math.abs(ImpactFoundryConfig.GetWindupDuration(0) - ImpactFoundryConfig.WindupAtRankZero) > epsilon
		or math.abs(ImpactFoundryConfig.GetWindupDuration(ProgressionConfig.MaxUpgradeRank) - ImpactFoundryConfig.WindupAtRankThirty) > epsilon
		or math.abs(ImpactFoundryConfig.GetCooldown(0) - ImpactFoundryConfig.CooldownAtRankZero) > epsilon
		or math.abs(ImpactFoundryConfig.GetCooldown(ProgressionConfig.MaxUpgradeRank) - ImpactFoundryConfig.CooldownAtRankThirty) > epsilon
		or math.abs(ImpactFoundryConfig.GetDamage(0) - ImpactFoundryConfig.DamageAtRankZero) > epsilon
		or math.abs(ImpactFoundryConfig.GetDamage(ProgressionConfig.MaxUpgradeRank) - ImpactFoundryConfig.DamageAtRankThirty) > epsilon
		or ImpactFoundryConfig.WindupAtRankThirty <= ImpactFoundryConfig.ImpactFeedbackDuration
		or ImpactFoundryConfig.CooldownAtRankThirty <= ImpactFoundryConfig.WindupAtRankThirty + ImpactFoundryConfig.ImpactFeedbackDuration
		or ImpactFoundryConfig.MaximumTargetsPerStrike < 1 or ImpactFoundryConfig.MaximumTargetsPerStrike > 2
		or ImpactFoundryConfig.KnockbackSpeed > CombatConfig.MaxHorizontalKnockbackSpeed
		or ImpactFoundryConfig.DamageAtRankThirty > 50
		or ImpactFoundryConfig.BreakableDamageMultiplier > 1.75
	then error("ImpactFoundryConfig produces unsafe or inconsistent prototype values") end
end

function ImpactFoundryCombatService.Init()
	if initialized then return end
	validateConfiguration()
	initialized = true
	PlayerSessionService.Init()
	ProgressionService.Init()
	EvolutionRouteService.Init()
	BreakableObjectService.Init()
	requestRemote = getOrCreateRemote("ImpactFoundryAttackRequest")
	broadcastRemote = getOrCreateRemote("ImpactFoundryStateBroadcast")
	local activeRequestRemote = requestRemote :: RemoteEvent
	activeRequestRemote.OnServerEvent:Connect(handleRequest)
	RunService.Heartbeat:Connect(update)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do connectPlayer(player) end
end

return ImpactFoundryCombatService
