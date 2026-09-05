--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local CombatConfig = require(shared:WaitForChild("CombatConfig"))
local EvolutionConfig = require(shared:WaitForChild("EvolutionConfig"))
local MotionWorksConfig = require(shared:WaitForChild("MotionWorksConfig"))
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

type MotionState = {
	phase: string,
	character: Model?,
	nextStartAt: number,
	phaseStartedAt: number,
	phaseEndsAt: number,
	leaseExpiresAt: number,
	spoolDuration: number,
	pulseInterval: number,
	recoveryDuration: number,
	pulseDamage: number,
	nextPulseAt: number,
	energy: number,
	output: number,
	lastUpdateAt: number,
	lastReplicatedAt: number,
	attackSerial: number,
	lastSequence: number,
	lastKeepaliveAt: number,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	acceptedRequests: number,
	rejectedRequests: number,
	pulseCount: number,
	affectedTargetCount: number,
	movementViolationCount: number,
	authorizedForward: Vector3,
	lastAuthorizationAt: number,
	characterAddedConnection: RBXScriptConnection?,
	diedConnection: RBXScriptConnection?,
	routeConnection: RBXScriptConnection?,
	sessionConnection: RBXScriptConnection?,
}

type Candidate = {
	model: Model,
	targetPart: BasePart,
	humanoid: Humanoid?,
	breakable: Model?,
	distance: number,
}

local states: {[Player]: MotionState} = {}
local initialized = false
local intentRemote: RemoteEvent? = nil
local broadcastRemote: RemoteEvent? = nil
local KNOCKBACK_VELOCITY_ATTRIBUTE = "CombatKnockbackVelocity"
local KNOCKBACK_STARTED_AT_ATTRIBUTE = "CombatKnockbackStartedAt"
local KNOCKBACK_UNTIL_ATTRIBUTE = "CombatKnockbackUntil"

local MotionWorksCombatService = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getOrCreateRemote(name: string): RemoteEvent
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	elseif not remotes:IsA("Folder") then
		error("ReplicatedStorage.Remotes must be a Folder")
	end
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

local function getAliveCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if character == nil or character.Parent == nil then return nil, nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function isVerticalPositionValid(root: BasePart): boolean
	local arena = Workspace:FindFirstChild("GrayboxArena")
	local floor = if arena ~= nil then arena:FindFirstChild("Floor") else nil
	if floor == nil or not floor:IsA("BasePart") then return false end
	local height = root.Position.Y - (floor.Position.Y + floor.Size.Y * 0.5)
	local verticalSpeed = root.AssemblyLinearVelocity.Y
	return isFinite(height)
		and isFinite(verticalSpeed)
		and height >= MotionWorksConfig.MinimumRootHeightAboveFloor
		and height <= MotionWorksConfig.MaximumRootHeightAboveFloor
		and math.abs(verticalSpeed) <= MotionWorksConfig.MaximumVerticalSpeed
end

local function getOrigin(character: Model): (Vector3?, BasePart?)
	local chassis = character:FindFirstChild("RobotChassis")
	if chassis == nil or not chassis:IsA("Model") then return nil, nil end
	local equipped = chassis:FindFirstChild(ClassConfig.EquippedMotionWorksName)
	if equipped == nil or not equipped:IsA("Model") then return nil, nil end
	local weaponRoot = equipped:FindFirstChild("MotionWorksRoot", true)
	local hitOrigin = equipped:FindFirstChild("MotionWorksHitOrigin", true)
	if
		weaponRoot == nil
		or not weaponRoot:IsA("BasePart")
		or hitOrigin == nil
		or not hitOrigin:IsA("Attachment")
	then
		return nil, nil
	end
	return hitOrigin.WorldPosition, weaponRoot
end

local function getTargetFromPart(part: BasePart): (Model?, Humanoid?, BasePart?)
	local current: Instance? = part
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			local root = current:FindFirstChild("HumanoidRootPart")
			if humanoid ~= nil and root ~= nil and root:IsA("BasePart") then
				return current, humanoid, root
			end
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

local function isSolidObstacle(character: Model, root: BasePart, forward: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local result = Workspace:Raycast(
		root.Position + Vector3.new(0, 0.2, 0),
		forward * MotionWorksConfig.ObstacleProbeDistance,
		params
	)
	if result == nil or not result.Instance:IsA("BasePart") or not result.Instance.CanCollide then return false end
	if BreakableObjectService.GetBreakableFromPart(result.Instance) ~= nil then return false end
	local current: Instance? = result.Instance
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") ~= nil then return false end
		current = current.Parent
	end
	return true
end

local function isInWeaponArea(origin: Vector3, forward: Vector3, targetPart: BasePart): (boolean, number)
	local offset = targetPart.Position - origin
	local distance = offset.Magnitude
	if distance > MotionWorksConfig.MaximumTargetRange or math.abs(offset.Y) > MotionWorksConfig.MaximumVerticalDifference then
		return false, distance
	end
	local horizontal = Vector3.new(offset.X, 0, offset.Z)
	if horizontal.Magnitude <= 0.01 then return true, distance end
	return forward:Dot(horizontal.Unit) >= MotionWorksConfig.MinimumForwardTargetDot, distance
end

local function applyKnockback(target: Model, targetRoot: BasePart, direction: Vector3)
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude <= 0.01 then return end
	local resistance = DisplacementResistanceService.GetHorizontalMultiplier(target, horizontal)
	local speed = math.clamp(
		MotionWorksConfig.PulseKnockbackSpeed * resistance,
		0,
		CombatConfig.MaxHorizontalKnockbackSpeed
	)
	local velocity = horizontal.Unit * speed
	local now = Workspace:GetServerTimeNow()
	target:SetAttribute(KNOCKBACK_VELOCITY_ATTRIBUTE, velocity)
	target:SetAttribute(KNOCKBACK_STARTED_AT_ATTRIBUTE, now)
	target:SetAttribute(KNOCKBACK_UNTIL_ATTRIBUTE, now + CombatConfig.KnockbackDuration)
	targetRoot:ApplyImpulse(velocity * targetRoot.AssemblyMass)
end

local function getForward(root: BasePart): Vector3?
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	return if forward.Magnitude > 0.01 then forward.Unit else nil
end

local function getObservedForwardSpeed(root: BasePart, targetRoot: BasePart, forward: Vector3): number
	local attackerVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local forwardSpeed = math.max(attackerVelocity:Dot(forward), 0)
	local targetVelocity = Vector3.new(targetRoot.AssemblyLinearVelocity.X, 0, targetRoot.AssemblyLinearVelocity.Z)
	local offset = targetRoot.Position - root.Position
	local towardTarget = Vector3.new(offset.X, 0, offset.Z)
	if towardTarget.Magnitude <= 0.01 then return 0 end
	local closingSpeed = (attackerVelocity - targetVelocity):Dot(towardTarget.Unit)
	-- A target moving toward the carriage cannot inflate damage beyond attacker-owned motion.
	return math.max(math.min(forwardSpeed, closingSpeed), 0)
end

local function resolvePulse(player: Player, state: MotionState): number
	local character, _humanoid, root = getAliveCharacter(player)
	if
		character == nil
		or root == nil
		or character ~= state.character
		or not PlayerSessionService.IsArena(player)
		or not EvolutionRouteService.IsMotionWorksActive(player)
		or character:GetAttribute("MotionWorksReady") ~= true
	then
		return 0
	end
	local origin = getOrigin(character)
	local forward = getForward(root)
	if origin == nil or forward == nil or not isVerticalPositionValid(root) then return 0 end
	local rootVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local rootForwardSpeed = rootVelocity:Dot(forward)
	if
		rootForwardSpeed < MotionWorksConfig.MinimumObservedForwardSpeed
		or rootVelocity.Magnitude <= 0.01
		or rootVelocity.Unit:Dot(forward) < MotionWorksConfig.MinimumDrivenDirectionDot
	then
		return 0
	end

	local center = origin + forward * MotionWorksConfig.QueryForwardOffset
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.MaxParts = MotionWorksConfig.MaximumQueryParts
	local parts = Workspace:GetPartBoundsInBox(
		CFrame.lookAt(center, center + forward),
		MotionWorksConfig.QueryBoxSize,
		params
	)
	local candidates: {Candidate} = {}
	local seen: {[Model]: boolean} = {}
	for _, part in parts do
		local breakable = BreakableObjectService.GetBreakableFromPart(part)
		if breakable ~= nil then
			if seen[breakable] then continue end
			local targetPart = breakable.PrimaryPart
			if targetPart == nil then continue end
			local valid, distance = isInWeaponArea(origin, forward, targetPart)
			if not valid or not hasLineOfSight(origin, breakable, targetPart, character) then continue end
			seen[breakable] = true
			table.insert(candidates, {
				model = breakable,
				targetPart = targetPart,
				humanoid = nil,
				breakable = breakable,
				distance = distance,
			})
			continue
		end
		local target, targetHumanoid, targetRoot = getTargetFromPart(part)
		if
			target == nil
			or targetHumanoid == nil
			or targetRoot == nil
			or target == character
			or targetHumanoid.Health <= 0
			or seen[target]
		then
			continue
		end
		local targetPlayer = Players:GetPlayerFromCharacter(target)
		if targetPlayer ~= nil and not PlayerSessionService.IsArena(targetPlayer) then continue end
		local valid, distance = isInWeaponArea(origin, forward, targetRoot)
		if not valid or not hasLineOfSight(origin, target, targetRoot, character) then continue end
		seen[target] = true
		table.insert(candidates, {
			model = target,
			targetPart = targetRoot,
			humanoid = targetHumanoid,
			breakable = nil,
			distance = distance,
		})
	end
	table.sort(candidates, function(left: Candidate, right: Candidate): boolean
		return left.distance < right.distance
	end)

	local affected = 0
	for _, candidate in candidates do
		if affected >= MotionWorksConfig.MaximumTargetsPerPulse then break end
		local observedSpeed = getObservedForwardSpeed(root, candidate.targetPart, forward)
		if observedSpeed < MotionWorksConfig.MinimumObservedForwardSpeed then continue end
		local speedAlpha = math.clamp(
			(observedSpeed - MotionWorksConfig.MinimumObservedForwardSpeed)
				/ (MotionWorksConfig.FullOutputObservedForwardSpeed - MotionWorksConfig.MinimumObservedForwardSpeed),
			0,
			1
		)
		local strength = math.clamp(math.min(state.output, 0.35 + 0.65 * speedAlpha), 0, 1)
		local damage = math.clamp(
			state.pulseDamage * strength,
			0,
			MotionWorksConfig.MaximumServerPulseDamage
		)
		if damage <= 0 then continue end
		if candidate.breakable ~= nil then
			local applied = BreakableObjectService.Damage(
				candidate.breakable,
				player,
				damage * MotionWorksConfig.BreakableDamageMultiplier
			)
			if applied > 0 then affected += 1 end
		elseif candidate.humanoid ~= nil and candidate.humanoid.Health > 0 then
			local healthBefore = candidate.humanoid.Health
			local applied = AuthoritativeDamageService.ApplyHumanoidDamage(candidate.humanoid, damage)
			if applied > 0 then
				applyKnockback(candidate.model, candidate.targetPart, forward)
				affected += 1
			end
			if healthBefore > 0 and candidate.humanoid.Health <= 0 then
				ProgressionService.AwardElimination(
					player,
					Players:GetPlayerFromCharacter(candidate.model),
					candidate.humanoid
				)
			end
		end
	end
	return affected
end

local function broadcast(player: Player, state: MotionState, forceRemote: boolean?)
	player:SetAttribute("MotionWorksAttackPhase", state.phase)
	player:SetAttribute("MotionWorksAttackSerial", state.attackSerial)
	player:SetAttribute("MotionWorksPhaseStartedAt", state.phaseStartedAt)
	player:SetAttribute("MotionWorksPhaseEndsAt", state.phaseEndsAt)
	player:SetAttribute("MotionWorksEnergy", state.energy)
	player:SetAttribute("MotionWorksOutput", state.output)
	local remote = broadcastRemote
	if remote ~= nil and forceRemote == true then
		remote:FireAllClients(
			player,
			state.attackSerial,
			state.phase,
			state.phaseStartedAt,
			state.phaseEndsAt,
			state.energy,
			state.output
		)
	end
end

local function setPhase(player: Player, state: MotionState, phase: string, startedAt: number, endsAt: number)
	state.phase = phase
	state.phaseStartedAt = startedAt
	state.phaseEndsAt = endsAt
	state.lastReplicatedAt = startedAt
	broadcast(player, state, true)
end

local function cancelImmediately(player: Player, state: MotionState, restoreEnergy: boolean?)
	state.character = nil
	state.nextStartAt = 0
	state.nextPulseAt = 0
	state.leaseExpiresAt = 0
	state.output = 0
	if restoreEnergy == true then state.energy = MotionWorksConfig.MaximumEnergy end
	setPhase(player, state, "Idle", Workspace:GetServerTimeNow(), 0)
end

local function beginCoastdown(player: Player, state: MotionState, now: number)
	if state.phase ~= "Spooling" and state.phase ~= "Driven" then return end
	state.nextPulseAt = 0
	state.leaseExpiresAt = 0
	state.nextStartAt = now + MotionWorksConfig.CoastdownDuration + state.recoveryDuration
	setPhase(player, state, "Coastdown", now, now + MotionWorksConfig.CoastdownDuration)
end

local function reject(player: Player, state: MotionState)
	state.rejectedRequests += 1
	player:SetAttribute("MotionWorksRejectedRequestCount", state.rejectedRequests)
end

local function accept(player: Player, state: MotionState)
	state.acceptedRequests += 1
	player:SetAttribute("MotionWorksAcceptedRequestCount", state.acceptedRequests)
end

local function handleIntent(player: Player, intentValue: unknown, sequenceValue: unknown, ...: unknown)
	local state = states[player]
	if state == nil then return end
	local now = Workspace:GetServerTimeNow()
	if now - state.requestWindowStartedAt >= MotionWorksConfig.RequestRateWindow then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if
		state.requestsInWindow > MotionWorksConfig.MaximumRequestsPerWindow
		or now - state.lastRequestAt < MotionWorksConfig.MinimumRequestInterval
	then
		state.lastRequestAt = now
		reject(player, state)
		return
	end
	state.lastRequestAt = now
	if select("#", ...) ~= 0 or typeof(intentValue) ~= "string" or typeof(sequenceValue) ~= "number" then
		reject(player, state)
		return
	end
	local intent = intentValue :: string
	local sequence = sequenceValue :: number
	if
		(intent ~= "Start" and intent ~= "KeepAlive" and intent ~= "Stop" and intent ~= "Cancel")
		or not isFinite(sequence)
		or sequence % 1 ~= 0
		or sequence <= state.lastSequence
		or sequence > state.lastSequence + MotionWorksConfig.MaximumSequenceAdvance
	then
		reject(player, state)
		return
	end
	state.lastSequence = sequence
	local character, _humanoid, root = getAliveCharacter(player)
	if
		character == nil
		or root == nil
		or not PlayerSessionService.IsArena(player)
		or not EvolutionRouteService.IsMotionWorksActive(player)
		or character:GetAttribute("MotionWorksReady") ~= true
		or getOrigin(character) == nil
	then
		reject(player, state)
		if state.phase ~= "Idle" then cancelImmediately(player, state, false) end
		return
	end

	if intent == "Start" then
		if state.phase ~= "Idle" or now < state.nextStartAt or state.energy < MotionWorksConfig.MinimumStartEnergy
			or not isVerticalPositionValid(root :: BasePart) then
			reject(player, state)
			return
		end
		local attackRateRank = ProgressionService.GetUpgradeRank(player, "Attack Rate")
		local damageRank = ProgressionService.GetUpgradeRank(player, "Damage")
		state.character = character
		state.spoolDuration = MotionWorksConfig.GetSpoolDuration(attackRateRank)
		state.pulseInterval = MotionWorksConfig.GetPulseInterval(attackRateRank)
		state.recoveryDuration = MotionWorksConfig.GetRecoveryDuration(attackRateRank)
		state.pulseDamage = MotionWorksConfig.GetPulseDamage(damageRank)
		state.nextPulseAt = 0
		state.output = 0
		state.attackSerial += 1
		state.lastKeepaliveAt = now
		state.leaseExpiresAt = now + MotionWorksConfig.HoldLeaseTimeout
		setPhase(player, state, "Spooling", now, now + state.spoolDuration)
		accept(player, state)
		return
	end

	if intent == "KeepAlive" then
		if
			(state.phase ~= "Spooling" and state.phase ~= "Driven")
			or state.character ~= character
			or now - state.lastKeepaliveAt < MotionWorksConfig.MinimumKeepaliveInterval
		then
			reject(player, state)
			return
		end
		state.lastKeepaliveAt = now
		state.leaseExpiresAt = now + MotionWorksConfig.HoldLeaseTimeout
		accept(player, state)
		return
	end

	if (state.phase ~= "Spooling" and state.phase ~= "Driven") or state.character ~= character then
		reject(player, state)
		return
	end
	beginCoastdown(player, state, now)
	accept(player, state)
end

local function update(_deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	for player, state in states do
		local elapsed = math.clamp(now - state.lastUpdateAt, 0, MotionWorksConfig.MaximumEnergyStep)
		state.lastUpdateAt = now
		if state.phase == "Idle" then
			local previousEnergy = state.energy
			state.energy = math.min(
				MotionWorksConfig.MaximumEnergy,
				state.energy + MotionWorksConfig.EnergyRechargePerSecond * elapsed
			)
			if
				state.energy ~= previousEnergy
				and now - state.lastReplicatedAt >= MotionWorksConfig.StateReplicationInterval
			then
				state.lastReplicatedAt = now
				broadcast(player, state, false)
			end
			continue
		end

		local character, _humanoid, root = getAliveCharacter(player)
		local valid = character ~= nil
			and root ~= nil
			and character == state.character
			and PlayerSessionService.IsArena(player)
			and EvolutionRouteService.IsMotionWorksActive(player)
			and character:GetAttribute("MotionWorksReady") == true
			and getOrigin(character) ~= nil
		if not valid then
			cancelImmediately(player, state, true)
			continue
		end
		local safeCharacter = character :: Model
		local safeRoot = root :: BasePart

		if (state.phase == "Spooling" or state.phase == "Driven") and now >= state.leaseExpiresAt then
			beginCoastdown(player, state, now)
		elseif state.phase == "Spooling" and now >= state.phaseEndsAt then
			state.output = 0
			state.nextPulseAt = now + state.pulseInterval
			state.authorizedForward = getForward(safeRoot) or Vector3.new(0, 0, -1)
			state.lastAuthorizationAt = now
			setPhase(player, state, "Driven", now, 0)
		elseif state.phase == "Driven" then
			state.energy = math.max(0, state.energy - MotionWorksConfig.EnergyDrainPerSecond * elapsed)
			state.output = math.clamp(
				(now - state.phaseStartedAt) / MotionWorksConfig.OutputRampDuration,
				0,
				1
			)
			local forward = getForward(safeRoot)
			if state.energy <= 0 or forward == nil or isSolidObstacle(safeCharacter, safeRoot, forward) then
				beginCoastdown(player, state, now)
			else
				local iterations = 0
				while now >= state.nextPulseAt and iterations < MotionWorksConfig.MaximumCatchUpPulsesPerHeartbeat do
					local affected = resolvePulse(player, state)
					state.pulseCount += 1
					state.affectedTargetCount += affected
					player:SetAttribute("MotionWorksPulseCount", state.pulseCount)
					player:SetAttribute("MotionWorksAffectedTargetCount", state.affectedTargetCount)
					state.nextPulseAt += state.pulseInterval
					iterations += 1
				end
				if iterations >= MotionWorksConfig.MaximumCatchUpPulsesPerHeartbeat and now >= state.nextPulseAt then
					state.nextPulseAt = now + state.pulseInterval
				end
			end
		elseif state.phase == "Coastdown" then
			state.energy = math.min(
				MotionWorksConfig.MaximumEnergy,
				state.energy + MotionWorksConfig.EnergyRechargePerSecond * elapsed
			)
			local duration = math.max(MotionWorksConfig.CoastdownDuration, 0.001)
			state.output = math.clamp((state.phaseEndsAt - now) / duration, 0, 1) * state.output
			if now >= state.phaseEndsAt then
				state.output = 0
				setPhase(player, state, "Recovery", now, state.nextStartAt)
			end
		elseif state.phase == "Recovery" then
			state.energy = math.min(
				MotionWorksConfig.MaximumEnergy,
				state.energy + MotionWorksConfig.EnergyRechargePerSecond * elapsed
			)
			if now >= state.nextStartAt then
				state.character = nil
				setPhase(player, state, "Idle", now, 0)
			end
		end

		local needsContinuousReplication = state.phase == "Driven"
			or state.phase == "Coastdown"
			or (state.phase == "Recovery" and state.energy < MotionWorksConfig.MaximumEnergy)
		if
			needsContinuousReplication
			and now - state.lastReplicatedAt >= MotionWorksConfig.StateReplicationInterval
		then
			state.lastReplicatedAt = now
			broadcast(player, state, true)
		end
	end
end

local function bindCharacter(player: Player, character: Model)
	local state = states[player]
	if state == nil then return end
	if state.diedConnection ~= nil then state.diedConnection:Disconnect() end
	cancelImmediately(player, state, true)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid == nil or not humanoid:IsA("Humanoid") or states[player] ~= state or player.Character ~= character then
			return
		end
		state.diedConnection = humanoid.Died:Connect(function()
			if states[player] == state then cancelImmediately(player, state, true) end
		end)
	end)
end

local function connectPlayer(player: Player)
	if states[player] ~= nil then return end
	local now = Workspace:GetServerTimeNow()
	local state: MotionState = {
		phase = "Idle", character = nil, nextStartAt = 0, phaseStartedAt = now, phaseEndsAt = 0,
		leaseExpiresAt = 0, spoolDuration = MotionWorksConfig.SpoolAtRankZero,
		pulseInterval = MotionWorksConfig.PulseIntervalAtRankZero,
		recoveryDuration = MotionWorksConfig.RecoveryAtRankZero,
		pulseDamage = MotionWorksConfig.DamageAtRankZero, nextPulseAt = 0,
		energy = MotionWorksConfig.MaximumEnergy, output = 0, lastUpdateAt = now, lastReplicatedAt = now,
		attackSerial = 0, lastSequence = 0, lastKeepaliveAt = -math.huge,
		requestWindowStartedAt = now, requestsInWindow = 0, lastRequestAt = -math.huge,
		acceptedRequests = 0, rejectedRequests = 0, pulseCount = 0, affectedTargetCount = 0,
		movementViolationCount = 0, characterAddedConnection = nil, diedConnection = nil,
		authorizedForward = Vector3.new(0, 0, -1), lastAuthorizationAt = now,
		routeConnection = nil, sessionConnection = nil,
	}
	states[player] = state
	player:SetAttribute("MotionWorksAcceptedRequestCount", 0)
	player:SetAttribute("MotionWorksRejectedRequestCount", 0)
	player:SetAttribute("MotionWorksPulseCount", 0)
	player:SetAttribute("MotionWorksAffectedTargetCount", 0)
	player:SetAttribute("MotionWorksMovementViolationCount", 0)
	broadcast(player, state, false)
	state.routeConnection = player:GetAttributeChangedSignal(EvolutionConfig.CurrentNodeAttribute):Connect(function()
		if not EvolutionRouteService.IsMotionWorksActive(player) then cancelImmediately(player, state, true) end
	end)
	state.sessionConnection = player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(function()
		if not PlayerSessionService.IsArena(player) then cancelImmediately(player, state, true) end
	end)
	state.characterAddedConnection = player.CharacterAdded:Connect(function(character: Model) bindCharacter(player, character) end)
	if player.Character ~= nil then bindCharacter(player, player.Character) end
end

local function disconnectPlayer(player: Player)
	local state = states[player]
	if state == nil then return end
	for _, connection in { state.characterAddedConnection, state.diedConnection, state.routeConnection, state.sessionConnection } do
		if connection ~= nil then connection:Disconnect() end
	end
	states[player] = nil
end

function MotionWorksCombatService.GetMovementAuthorization(player: Player, root: BasePart, measuredVelocity: Vector3?, sampleElapsed: number?): MovementAuthorization?
	local state = states[player]
	if
		state == nil
		or state.character ~= player.Character
		or root.Parent ~= state.character
		or not EvolutionRouteService.IsMotionWorksActive(player)
	then
		return nil
	end
	local speedRank = ProgressionService.GetUpgradeRank(player, "Speed")
	local normalMaxSpeed = MotionWorksConfig.GetNormalMaxSpeed(speedRank)
	local boundedElapsed = math.clamp(sampleElapsed or MovementConfig.ServerMonitorInterval, 0, MotionWorksConfig.MaximumSampleInterval)
	local maximumSampleDistance = math.max(MotionWorksConfig.MaximumSampleDistance,
		(MotionWorksConfig.GetDrivenSpeed(speedRank, 1) + MotionWorksConfig.MovementSpeedTolerance) * boundedElapsed)
	local verticalViolation = not isVerticalPositionValid(root)
	if state.phase == "Spooling" then
		return {
			legalMaxSpeed = normalMaxSpeed * MotionWorksConfig.SpoolMovementSpeedMultiplier,
			maximumAcceleration = MovementConfig.ServerMaxAcceleration * MotionWorksConfig.SpoolSteeringMultiplier,
			maximumSampleDistance = MovementConfig.ServerMaxTeleportDistance,
			speedTolerance = MovementConfig.ServerSpeedTolerance,
			clearViolation = verticalViolation,
		}
	elseif state.phase == "Coastdown" then
		local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local forward = getForward(root)
		local dot = if forward ~= nil and velocity.Magnitude > 0.01 then velocity.Unit:Dot(forward) else 0
		local sampledDot = if forward ~= nil and measuredVelocity ~= nil and measuredVelocity.Magnitude > 0.01
			then measuredVelocity.Unit:Dot(forward) else dot
		return {
			-- Retain only the forward inertial envelope during the bounded coast.
			-- The client has already reduced its target speed; delayed replication
			-- must not turn a normal release into a movement correction.
			legalMaxSpeed = math.min(MotionWorksConfig.GetDirectionalSpeedLimit(speedRank, 1, dot),
				MotionWorksConfig.GetDirectionalSpeedLimit(speedRank, 1, sampledDot)),
			maximumAcceleration = math.min(MotionWorksConfig.MaximumMovementAcceleration, MovementConfig.ServerMaxAcceleration * normalMaxSpeed / MovementConfig.MaxSpeed),
			maximumSampleDistance = maximumSampleDistance,
			speedTolerance = MotionWorksConfig.MovementSpeedTolerance,
			clearViolation = verticalViolation,
		}
	elseif state.phase ~= "Driven" then
		return nil
	end

	local forward = getForward(root)
	if forward == nil then return nil end
	local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local forwardSpeed = velocity:Dot(forward)
	local directionDot = if velocity.Magnitude > 0.01 then velocity.Unit:Dot(forward) else 1
	local sampledVelocity = measuredVelocity or velocity
	local sampledDot = if sampledVelocity.Magnitude > 0.01 then sampledVelocity.Unit:Dot(forward) else 1
	local legalMaxSpeed = MotionWorksConfig.GetDirectionalSpeedLimit(speedRank, state.output, directionDot)
	local sampledSpeedLimit = MotionWorksConfig.GetDirectionalSpeedLimit(speedRank, state.output, sampledDot)
	local steering = MotionWorksConfig.GetDrivenSteeringMultiplier(state.output)
	local usesDrivenAllowance = velocity.Magnitude > normalMaxSpeed + MotionWorksConfig.MovementSpeedTolerance
	local now = Workspace:GetServerTimeNow()
	local authorizationElapsed = math.max(now - state.lastAuthorizationAt, MovementConfig.ServerMonitorInterval)
	local maximumTurn = math.min(
		MotionWorksConfig.MaximumDrivenTurnRate * steering * authorizationElapsed
			+ MotionWorksConfig.TurnDirectionGrace,
		math.pi
	)
	local turnedTooFar = state.authorizedForward:Dot(forward) < math.cos(maximumTurn)
	local clearViolation = verticalViolation
		or velocity.Magnitude > legalMaxSpeed + MotionWorksConfig.MovementSpeedTolerance
		or (usesDrivenAllowance and forwardSpeed < 0)
		or (usesDrivenAllowance and directionDot < MotionWorksConfig.MinimumDrivenDirectionDot)
		or turnedTooFar
	-- Sampled displacement and physical velocity each have a directional envelope.
	-- This retains turning tolerance without lending the forward bonus to strafing.
	if not turnedTooFar then
		state.authorizedForward = forward
		state.lastAuthorizationAt = now
	end
	return {
		-- Replication can deliver a single position jump at 150 ms. Directional
		-- displacement uses the shared consecutive-sample guard, not an instant
		-- cancellation; forged physical velocity still cancels immediately above.
		legalMaxSpeed = math.min(legalMaxSpeed, sampledSpeedLimit),
		-- No direction receives more acceleration than ordinary upgraded movement.
		maximumAcceleration = math.min(MotionWorksConfig.MaximumMovementAcceleration, MovementConfig.ServerMaxAcceleration * normalMaxSpeed / MovementConfig.MaxSpeed),
		maximumSampleDistance = maximumSampleDistance,
		speedTolerance = MotionWorksConfig.MovementSpeedTolerance,
		clearViolation = clearViolation,
	}
end

function MotionWorksCombatService.CancelMovementViolation(player: Player)
	local state = states[player]
	if state == nil or (state.phase ~= "Driven" and state.phase ~= "Spooling" and state.phase ~= "Coastdown") then return end
	state.movementViolationCount += 1
	player:SetAttribute("MotionWorksMovementViolationCount", state.movementViolationCount)
	beginCoastdown(player, state, Workspace:GetServerTimeNow())
end

function MotionWorksCombatService.CancelForPlayer(player: Player)
	local state = states[player]
	if state ~= nil then cancelImmediately(player, state, true) end
end

local function validateConfiguration()
	local epsilon = 0.0001
	local rankThirty = ProgressionConfig.MaxUpgradeRank
	local endpointValues = {
		MotionWorksConfig.GetSpoolDuration(0),
		MotionWorksConfig.GetSpoolDuration(rankThirty),
		MotionWorksConfig.GetPulseInterval(0),
		MotionWorksConfig.GetPulseInterval(rankThirty),
		MotionWorksConfig.GetRecoveryDuration(0),
		MotionWorksConfig.GetRecoveryDuration(rankThirty),
		MotionWorksConfig.GetPulseDamage(0),
		MotionWorksConfig.GetPulseDamage(rankThirty),
		MotionWorksConfig.GetDrivenSpeed(0, 0),
		MotionWorksConfig.GetDrivenSpeed(0, 1),
		MotionWorksConfig.GetDrivenSpeed(rankThirty, 1),
		MotionWorksConfig.ObstacleProbeDistance,
		MotionWorksConfig.MinimumRootHeightAboveFloor,
		MotionWorksConfig.MaximumRootHeightAboveFloor,
		MotionWorksConfig.MaximumVerticalSpeed,
		MotionWorksConfig.MaximumSampleInterval,
	}
	for _, value in endpointValues do
		if not isFinite(value) or value <= 0 then
			error("MotionWorksConfig contains a non-finite or non-positive endpoint")
		end
	end
	if
		math.abs(MotionWorksConfig.GetSpoolDuration(0) - MotionWorksConfig.SpoolAtRankZero) > epsilon
		or math.abs(MotionWorksConfig.GetSpoolDuration(ProgressionConfig.MaxUpgradeRank) - MotionWorksConfig.SpoolAtRankThirty) > epsilon
		or math.abs(MotionWorksConfig.GetPulseInterval(0) - MotionWorksConfig.PulseIntervalAtRankZero) > epsilon
		or math.abs(MotionWorksConfig.GetPulseInterval(ProgressionConfig.MaxUpgradeRank) - MotionWorksConfig.PulseIntervalAtRankThirty) > epsilon
		or math.abs(MotionWorksConfig.GetRecoveryDuration(0) - MotionWorksConfig.RecoveryAtRankZero) > epsilon
		or math.abs(MotionWorksConfig.GetRecoveryDuration(ProgressionConfig.MaxUpgradeRank) - MotionWorksConfig.RecoveryAtRankThirty) > epsilon
		or math.abs(MotionWorksConfig.GetPulseDamage(0) - MotionWorksConfig.DamageAtRankZero) > epsilon
		or math.abs(MotionWorksConfig.GetPulseDamage(ProgressionConfig.MaxUpgradeRank) - MotionWorksConfig.DamageAtRankThirty) > epsilon
		or MotionWorksConfig.SpoolAtRankThirty >= MotionWorksConfig.SpoolAtRankZero
		or MotionWorksConfig.PulseIntervalAtRankThirty >= MotionWorksConfig.PulseIntervalAtRankZero
		or MotionWorksConfig.RecoveryAtRankThirty >= MotionWorksConfig.RecoveryAtRankZero
		or MotionWorksConfig.DamageAtRankThirty <= MotionWorksConfig.DamageAtRankZero
		or MotionWorksConfig.GetDrivenSpeed(0, 1) <= MotionWorksConfig.GetDrivenSpeed(0, 0)
		or MotionWorksConfig.GetDrivenSpeed(rankThirty, 1) <= MotionWorksConfig.GetDrivenSpeed(0, 1)
		or MotionWorksConfig.MinimumStartEnergy <= 0
		or MotionWorksConfig.MinimumStartEnergy > MotionWorksConfig.MaximumEnergy
		or MotionWorksConfig.EnergyDrainPerSecond <= 0
		or MotionWorksConfig.EnergyRechargePerSecond <= 0
		or MotionWorksConfig.MaximumTargetsPerPulse < 1
		or MotionWorksConfig.MaximumTargetsPerPulse > 2
		or MotionWorksConfig.MaximumServerPulseDamage > 13
		or MotionWorksConfig.PulseKnockbackSpeed > CombatConfig.MaxHorizontalKnockbackSpeed
		or MotionWorksConfig.BreakableDamageMultiplier > 1.75
		or MotionWorksConfig.HoldKeepaliveInterval <= MotionWorksConfig.MinimumKeepaliveInterval
		or MotionWorksConfig.HoldLeaseTimeout <= MotionWorksConfig.HoldKeepaliveInterval * 2
		or MotionWorksConfig.GetDrivenSpeed(ProgressionConfig.MaxUpgradeRank, 1) >= 47.2
	then
		error("MotionWorksConfig produces unsafe or inconsistent prototype values")
	end
end

function MotionWorksCombatService.Init()
	if initialized then return end
	validateConfiguration()
	initialized = true
	PlayerSessionService.Init()
	ProgressionService.Init()
	EvolutionRouteService.Init()
	BreakableObjectService.Init()
	intentRemote = getOrCreateRemote("MotionWorksAttackIntent")
	broadcastRemote = getOrCreateRemote("MotionWorksStateBroadcast")
	local activeIntentRemote = intentRemote :: RemoteEvent
	activeIntentRemote.OnServerEvent:Connect(handleIntent)
	RunService.Heartbeat:Connect(update)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do connectPlayer(player) end
end

return MotionWorksCombatService
