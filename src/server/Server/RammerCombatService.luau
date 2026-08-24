--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local CombatConfig = require(shared:WaitForChild("CombatConfig"))
local MovementConfig = require(shared:WaitForChild("MovementConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local RammerConfig = require(shared:WaitForChild("RammerConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local BreakableObjectService = require(script.Parent:WaitForChild("BreakableObjectService"))
local ClassService = require(script.Parent:WaitForChild("ClassService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local PlayerSessionService = require(script.Parent:WaitForChild("PlayerSessionService"))
local AuthoritativeDamageService = require(script.Parent:WaitForChild("AuthoritativeDamageService"))

local ROBOT_CHASSIS_NAME = "RobotChassis"
local RAMMER_HIT_ORIGIN_NAME = "RammerHitOrigin"
local KNOCKBACK_VELOCITY_ATTRIBUTE = "CombatKnockbackVelocity"
local KNOCKBACK_STARTED_AT_ATTRIBUTE = "CombatKnockbackStartedAt"
local KNOCKBACK_UNTIL_ATTRIBUTE = "CombatKnockbackUntil"

export type MovementAuthorization = {
	phase: string,
	legalMaxSpeed: number,
	maximumAcceleration: number,
	maximumSampleDistance: number,
	speedTolerance: number,
	clearViolation: boolean,
}

type RammerState = {
	phase: string,
	character: Model?,
	nextStartAt: number,
	phaseStartedAt: number,
	phaseEndsAt: number,
	leaseExpiresAt: number,
	chargeStartedAt: number,
	fullChargeTime: number,
	cooldown: number,
	maximumImpactDamage: number,
	chargeAmount: number,
	dashStartedAt: number,
	dashEndsAt: number,
	dashDirection: Vector3,
	authorizedDashSpeed: number,
	dashStartPosition: Vector3,
	damageResolved: boolean,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	lastKeepaliveAt: number,
	lastSequence: number,
	attackSerial: number,
	acceptedRequests: number,
	rejectedRequests: number,
	impactCount: number,
	characterAddedConnection: RBXScriptConnection?,
	diedConnection: RBXScriptConnection?,
	classChangedConnection: RBXScriptConnection?,
	sessionChangedConnection: RBXScriptConnection?,
}

type TargetCandidate = {
	model: Model,
	targetPart: BasePart,
	humanoid: Humanoid?,
	breakable: Model?,
	distance: number,
}

local states: {[Player]: RammerState} = {}
local initialized = false
local intentRemote: RemoteEvent? = nil
local stateBroadcastRemote: RemoteEvent? = nil

local RammerCombatService = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
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

local function getRammerOrigin(character: Model): (Vector3?, BasePart?)
	local chassis = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassis == nil or not chassis:IsA("Model") then
		return nil, nil
	end
	local rammer = chassis:FindFirstChild(ClassConfig.EquippedRammerName)
	if rammer == nil or not rammer:IsA("Model") then
		return nil, nil
	end
	local rammerRoot = rammer:FindFirstChild("RammerRoot", true)
	local hitOrigin = rammer:FindFirstChild(RAMMER_HIT_ORIGIN_NAME, true)
	if
		rammerRoot == nil
		or not rammerRoot:IsA("BasePart")
		or hitOrigin == nil
		or not hitOrigin:IsA("Attachment")
	then
		return nil, nil
	end
	return hitOrigin.WorldPosition, rammerRoot
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
	if direction.Magnitude <= 0.01 then
		return true
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { attacker }
	raycastParams.IgnoreWater = true
	local result = Workspace:Raycast(origin, direction, raycastParams)
	return result == nil or result.Instance:IsDescendantOf(target)
end

local function isSolidDashObstacle(character: Model, root: BasePart, direction: Vector3): boolean
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true
	local result = Workspace:Raycast(
		root.Position + Vector3.new(0, 0.2, 0),
		direction * RammerConfig.DashObstacleProbeDistance,
		raycastParams
	)
	if result == nil or not result.Instance:IsA("BasePart") or not result.Instance.CanCollide then
		return false
	end
	if BreakableObjectService.GetBreakableFromPart(result.Instance) ~= nil then
		return false
	end
	local current: Instance? = result.Instance
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") ~= nil then
			return false
		end
		current = current.Parent
	end
	return true
end

local function isInWeaponArea(
	origin: Vector3,
	dashDirection: Vector3,
	targetPart: BasePart
): (boolean, number)
	local offset = targetPart.Position - origin
	local distance = offset.Magnitude
	if distance > RammerConfig.MaximumTargetRange or math.abs(offset.Y) > RammerConfig.MaximumVerticalDifference then
		return false, distance
	end
	local horizontal = Vector3.new(offset.X, 0, offset.Z)
	if horizontal.Magnitude <= 0.01 then
		return true, distance
	end
	return dashDirection:Dot(horizontal.Unit) >= RammerConfig.MinimumForwardDot, distance
end

local function broadcastPhase(player: Player, state: RammerState)
	player:SetAttribute("RammerAttackSerial", state.attackSerial)
	player:SetAttribute("RammerAttackPhase", state.phase)
	player:SetAttribute("RammerPhaseStartedAt", state.phaseStartedAt)
	player:SetAttribute("RammerPhaseEndsAt", state.phaseEndsAt)
	player:SetAttribute("RammerFullChargeTime", state.fullChargeTime)
	player:SetAttribute("RammerChargeAmount", state.chargeAmount)
	player:SetAttribute("RammerDashDirection", state.dashDirection)
	player:SetAttribute("RammerAuthorizedDashSpeed", state.authorizedDashSpeed)
	player:SetAttribute("RammerCooldownEndsAt", state.nextStartAt)
	local remote = stateBroadcastRemote
	if remote ~= nil then
		remote:FireAllClients(
			player,
			state.attackSerial,
			state.phase,
			state.phaseStartedAt,
			state.phaseEndsAt,
			state.fullChargeTime,
			state.chargeAmount,
			state.dashDirection,
			state.authorizedDashSpeed
		)
	end
end

local function setPhase(player: Player, state: RammerState, phase: string, startedAt: number, endsAt: number)
	state.phase = phase
	state.phaseStartedAt = startedAt
	state.phaseEndsAt = endsAt
	broadcastPhase(player, state)
end

local function clearAttackState(state: RammerState)
	state.character = nil
	state.leaseExpiresAt = 0
	state.chargeStartedAt = 0
	state.chargeAmount = 0
	state.dashStartedAt = 0
	state.dashEndsAt = 0
	state.dashDirection = Vector3.zero
	state.authorizedDashSpeed = 0
	state.dashStartPosition = Vector3.zero
	state.damageResolved = false
end

local function cancelImmediately(player: Player, state: RammerState)
	clearAttackState(state)
	state.nextStartAt = 0
	setPhase(player, state, "Idle", Workspace:GetServerTimeNow(), 0)
end

local function cancelHold(player: Player, state: RammerState, now: number)
	clearAttackState(state)
	state.nextStartAt = 0
	setPhase(player, state, "Cancelled", now, now + RammerConfig.ChargeCancelDuration)
end

local function enterCooldown(player: Player, state: RammerState, now: number)
	state.character = nil
	state.leaseExpiresAt = 0
	state.dashEndsAt = 0
	state.dashDirection = Vector3.zero
	state.authorizedDashSpeed = 0
	state.dashStartPosition = Vector3.zero
	state.damageResolved = false
	if now >= state.nextStartAt then
		state.chargeAmount = 0
		setPhase(player, state, "Idle", now, 0)
	else
		setPhase(player, state, "Cooldown", now, state.nextStartAt)
	end
end

local function applyHorizontalKnockback(target: Model, targetRoot: BasePart, direction: Vector3, speed: number)
	local safeSpeed = math.clamp(speed, 0, math.min(RammerConfig.MaximumServerKnockback, CombatConfig.MaxHorizontalKnockbackSpeed))
	if direction.Magnitude <= 0.01 or safeSpeed <= 0 then
		return
	end
	local knockbackVelocity = direction.Unit * safeSpeed
	local startedAt = Workspace:GetServerTimeNow()
	target:SetAttribute(KNOCKBACK_VELOCITY_ATTRIBUTE, knockbackVelocity)
	target:SetAttribute(KNOCKBACK_STARTED_AT_ATTRIBUTE, startedAt)
	target:SetAttribute(KNOCKBACK_UNTIL_ATTRIBUTE, startedAt + CombatConfig.KnockbackDuration)
	targetRoot:ApplyImpulse(knockbackVelocity * targetRoot.AssemblyMass)
	task.delay(CombatConfig.KnockbackDuration, function()
		if target.Parent == nil or targetRoot.Parent == nil then
			return
		end
		local currentVelocity = targetRoot.AssemblyLinearVelocity
		targetRoot.AssemblyLinearVelocity = Vector3.new(0, currentVelocity.Y, 0)
	end)
end

local function calculateImpact(state: RammerState, closingSpeed: number): (number, number)
	local legalSpeed = math.max(
		state.authorizedDashSpeed * RammerConfig.FullImpactClosingSpeedRatio,
		RammerConfig.MinimumImpactClosingSpeed + 0.01
	)
	local speedFactor = math.clamp(
		(closingSpeed - RammerConfig.MinimumImpactClosingSpeed)
			/ (legalSpeed - RammerConfig.MinimumImpactClosingSpeed),
		0,
		1
	)
	local chargedDamage = RammerConfig.MinimumImpactDamage
		+ (state.maximumImpactDamage - RammerConfig.MinimumImpactDamage) * state.chargeAmount
	local damage = RammerConfig.MinimumImpactDamage
		+ (chargedDamage - RammerConfig.MinimumImpactDamage) * speedFactor
	local chargedKnockback = RammerConfig.MinimumImpactKnockback
		+ (RammerConfig.FullChargeKnockback - RammerConfig.MinimumImpactKnockback) * state.chargeAmount
	local knockback = RammerConfig.MinimumImpactKnockback
		+ (chargedKnockback - RammerConfig.MinimumImpactKnockback) * speedFactor
	return math.clamp(damage, RammerConfig.MinimumImpactDamage, RammerConfig.MaximumServerDamage),
		math.clamp(knockback, 0, RammerConfig.MaximumServerKnockback)
end

local function clampDashVelocity(player: Player, root: BasePart)
	local normalMaxSpeed = MovementConfig.MaxSpeed
		* ProgressionConfig.GetSpeedMultiplier(ProgressionService.GetUpgradeRank(player, "Speed"))
	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontal.Magnitude > normalMaxSpeed then
		local clamped = horizontal.Unit * normalMaxSpeed
		root.AssemblyLinearVelocity = Vector3.new(clamped.X, velocity.Y, clamped.Z)
	end
end

local function resolveImpact(player: Player, state: RammerState, now: number): boolean
	if state.damageResolved then
		return false
	end
	local character, _humanoid, attackerRoot = getAliveCharacter(player)
	if
		character == nil
		or attackerRoot == nil
		or not PlayerSessionService.IsArena(player)
		or character ~= state.character
		or ClassService.GetClassId(player) ~= ClassConfig.RammerClassId
		or character:GetAttribute("RammerReady") ~= true
	then
		return false
	end
	local origin = getRammerOrigin(character)
	if origin == nil then
		return false
	end
	local horizontalVelocity = Vector3.new(attackerRoot.AssemblyLinearVelocity.X, 0, attackerRoot.AssemblyLinearVelocity.Z)
	local closingSpeed = math.clamp(
		horizontalVelocity:Dot(state.dashDirection),
		0,
		state.authorizedDashSpeed
	)
	if closingSpeed < RammerConfig.MinimumImpactClosingSpeed then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.MaxParts = RammerConfig.MaximumQueryParts
	local queryCenter = origin + state.dashDirection * RammerConfig.QueryForwardOffset
	local queryCFrame = CFrame.lookAt(queryCenter, queryCenter + state.dashDirection)
	local nearbyParts = Workspace:GetPartBoundsInBox(queryCFrame, RammerConfig.QueryBoxSize, overlapParams)
	local candidates: {TargetCandidate} = {}
	local seen: {[Model]: boolean} = {}

	for _, part in nearbyParts do
		local breakable = BreakableObjectService.GetBreakableFromPart(part)
		if breakable ~= nil then
			if seen[breakable] == true then
				continue
			end
			local targetPart = breakable.PrimaryPart
			if targetPart == nil then
				continue
			end
			local validArea, distance = isInWeaponArea(origin, state.dashDirection, targetPart)
			if not validArea or not hasLineOfSight(origin, breakable, targetPart, character) then
				continue
			end
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
			or seen[target] == true
		then
			continue
		end
		local targetPlayer = Players:GetPlayerFromCharacter(target)
		if targetPlayer ~= nil and not PlayerSessionService.IsArena(targetPlayer) then
			continue
		end
		local validArea, distance = isInWeaponArea(origin, state.dashDirection, targetRoot)
		if not validArea or not hasLineOfSight(origin, target, targetRoot, character) then
			continue
		end
		seen[target] = true
		table.insert(candidates, {
			model = target,
			targetPart = targetRoot,
			humanoid = targetHumanoid,
			breakable = nil,
			distance = distance,
		})
	end

	table.sort(candidates, function(left: TargetCandidate, right: TargetCandidate): boolean
		return left.distance < right.distance
	end)
	local candidate = candidates[1]
	if candidate == nil then
		return false
	end

	local damage, knockback = calculateImpact(state, closingSpeed)
	local affected = false
	if candidate.breakable ~= nil then
		local breakableDamage = damage * RammerConfig.RammerBreakableDamageMultiplier
		local appliedDamage, destroyed = BreakableObjectService.Damage(candidate.breakable, player, breakableDamage)
		affected = appliedDamage > 0
		if destroyed then
			state.nextStartAt = math.min(
				state.nextStartAt,
				state.dashStartedAt + RammerConfig.RammerBreakableDestroyCooldown
			)
		end
	elseif candidate.humanoid ~= nil and candidate.humanoid.Health > 0 then
		local healthBefore = candidate.humanoid.Health
		local appliedDamage = AuthoritativeDamageService.ApplyHumanoidDamage(candidate.humanoid, damage)
		if appliedDamage > 0 then
			applyHorizontalKnockback(candidate.model, candidate.targetPart, state.dashDirection, knockback)
			affected = true
		end
		if healthBefore > 0 and candidate.humanoid.Health <= 0 then
			local targetPlayer = Players:GetPlayerFromCharacter(candidate.model)
			ProgressionService.AwardElimination(player, targetPlayer, candidate.humanoid)
		end
	end
	if not affected then
		return false
	end

	state.damageResolved = true
	clampDashVelocity(player, attackerRoot)
	state.impactCount += 1
	player:SetAttribute("RammerImpactCount", state.impactCount)
	player:SetAttribute("RammerLastImpactDamage", damage)
	player:SetAttribute("RammerLastImpactKnockback", knockback)
	setPhase(player, state, "Impact", now, now + RammerConfig.ImpactFeedbackDuration)
	return true
end

local function rejectRequest(player: Player, state: RammerState)
	state.rejectedRequests += 1
	player:SetAttribute("RammerRejectedRequestCount", state.rejectedRequests)
end

local function acceptRequest(player: Player, state: RammerState)
	state.acceptedRequests += 1
	player:SetAttribute("RammerAcceptedRequestCount", state.acceptedRequests)
end

local function beginDash(player: Player, state: RammerState, character: Model, root: BasePart, now: number)
	local holdDuration = math.max(now - state.chargeStartedAt, 0)
	state.chargeAmount = RammerConfig.GetChargeAmount(holdDuration, state.fullChargeTime)
	local look = root.CFrame.LookVector
	local direction = Vector3.new(look.X, 0, look.Z)
	if direction.Magnitude <= 0.01 then
		cancelHold(player, state, now)
		return
	end
	state.character = character
	state.dashDirection = direction.Unit
	state.authorizedDashSpeed = RammerConfig.GetAuthorizedDashSpeed(
		ProgressionService.GetUpgradeRank(player, "Speed"),
		state.chargeAmount
	)
	state.dashStartedAt = now
	state.dashEndsAt = now + RammerConfig.DashDuration
	state.dashStartPosition = root.Position
	player:SetAttribute("RammerLastDashStartedAt", now)
	player:SetAttribute("RammerLastDashStartPosition", state.dashStartPosition)
	state.damageResolved = false
	state.leaseExpiresAt = 0
	state.nextStartAt = now + state.cooldown
	setPhase(player, state, "Dash", now, state.dashEndsAt)
end

local function handleIntent(player: Player, intentValue: unknown, sequenceValue: unknown, ...: unknown)
	local state = states[player]
	if state == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now - state.requestWindowStartedAt >= RammerConfig.RequestRateWindow then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if
		state.requestsInWindow > RammerConfig.MaximumRequestsPerWindow
		or now - state.lastRequestAt < RammerConfig.MinimumRequestInterval
	then
		state.lastRequestAt = now
		rejectRequest(player, state)
		return
	end
	state.lastRequestAt = now

	if select("#", ...) ~= 0 or typeof(intentValue) ~= "string" or typeof(sequenceValue) ~= "number" then
		rejectRequest(player, state)
		return
	end
	local intent = intentValue :: string
	local sequence = sequenceValue :: number
	if
		(intent ~= "Start" and intent ~= "KeepAlive" and intent ~= "Release" and intent ~= "Cancel")
		or not isFinite(sequence)
		or sequence % 1 ~= 0
		or sequence <= state.lastSequence
		or sequence > state.lastSequence + RammerConfig.MaximumSequenceAdvance
	then
		rejectRequest(player, state)
		return
	end
	state.lastSequence = sequence
	if not PlayerSessionService.IsArena(player) then
		rejectRequest(player, state)
		if state.phase ~= "Idle" then
			cancelImmediately(player, state)
		end
		return
	end

	local character, _humanoid, root = getAliveCharacter(player)
	if
		character == nil
		or root == nil
		or ClassService.GetClassId(player) ~= ClassConfig.RammerClassId
		or character:GetAttribute("RammerReady") ~= true
		or getRammerOrigin(character) == nil
	then
		rejectRequest(player, state)
		if state.phase ~= "Idle" and state.phase ~= "Cooldown" then
			cancelImmediately(player, state)
		end
		return
	end

	if intent == "Start" then
		if state.phase ~= "Idle" or now < state.nextStartAt then
			rejectRequest(player, state)
			return
		end
		local attackRateRank = ProgressionService.GetUpgradeRank(player, "Attack Rate")
		local damageRank = ProgressionService.GetUpgradeRank(player, "Damage")
		state.character = character
		state.fullChargeTime = RammerConfig.GetFullChargeTime(attackRateRank)
		state.cooldown = RammerConfig.GetCooldown(attackRateRank)
		state.maximumImpactDamage = RammerConfig.GetFullImpactDamage(damageRank)
		state.chargeAmount = 0
		state.chargeStartedAt = now
		state.leaseExpiresAt = now + RammerConfig.HoldLeaseTimeout
		state.lastKeepaliveAt = now
		state.attackSerial += 1
		setPhase(player, state, "Charging", now, now + state.fullChargeTime)
		acceptRequest(player, state)
		return
	end

	if intent == "KeepAlive" then
		if
			(state.phase ~= "Charging" and state.phase ~= "Ready")
			or state.character ~= character
			or now - state.lastKeepaliveAt < RammerConfig.MinimumKeepaliveInterval
		then
			rejectRequest(player, state)
			return
		end
		state.lastKeepaliveAt = now
		state.leaseExpiresAt = now + RammerConfig.HoldLeaseTimeout
		acceptRequest(player, state)
		return
	end

	if intent == "Cancel" then
		if (state.phase ~= "Charging" and state.phase ~= "Ready" and state.phase ~= "Dash") or state.character ~= character then
			rejectRequest(player, state)
			return
		end
		if state.phase == "Dash" then
			state.damageResolved = true
			clampDashVelocity(player, root)
			setPhase(player, state, "Recovery", now, now + RammerConfig.MissRecoveryDuration)
		else
			cancelHold(player, state, now)
		end
		acceptRequest(player, state)
		return
	end

	if (state.phase ~= "Charging" and state.phase ~= "Ready") or state.character ~= character then
		rejectRequest(player, state)
		return
	end
	local holdDuration = now - state.chargeStartedAt
	if holdDuration < RammerConfig.MinimumValidHold then
		cancelHold(player, state, now)
		acceptRequest(player, state)
		return
	end
	beginDash(player, state, character, root, now)
	acceptRequest(player, state)
end

local function updateActiveRammers(_deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	for player, state in states do
		if state.phase == "Idle" then
			continue
		end
		if not PlayerSessionService.IsArena(player) then
			cancelImmediately(player, state)
			continue
		end
		if state.phase == "Cooldown" then
			if now >= state.nextStartAt then
				state.chargeAmount = 0
				setPhase(player, state, "Idle", now, 0)
			end
			continue
		elseif state.phase == "Cancelled" then
			if now >= state.phaseEndsAt then
				setPhase(player, state, "Idle", now, 0)
			end
			continue
		end

		local character, humanoid, root = getAliveCharacter(player)
		local validCharacter = character ~= nil
			and humanoid ~= nil
			and root ~= nil
			and character == state.character
			and character:GetAttribute("RammerReady") == true
			and ClassService.GetClassId(player) == ClassConfig.RammerClassId
			and getRammerOrigin(character) ~= nil
		if not validCharacter then
			cancelImmediately(player, state)
			continue
		end

		if state.phase == "Charging" or state.phase == "Ready" then
			if now >= state.leaseExpiresAt then
				cancelHold(player, state, now)
			elseif state.phase == "Charging" and now >= state.phaseEndsAt then
				state.chargeAmount = 1
				setPhase(player, state, "Ready", now, 0)
			else
				state.chargeAmount = RammerConfig.GetChargeAmount(now - state.chargeStartedAt, state.fullChargeTime)
				player:SetAttribute("RammerChargeAmount", state.chargeAmount)
			end
		elseif state.phase == "Dash" then
			local safeCharacter = character :: Model
			local safeRoot = root :: BasePart
			if now >= state.dashEndsAt then
				clampDashVelocity(player, safeRoot)
				setPhase(player, state, "Recovery", now, now + RammerConfig.MissRecoveryDuration)
			elseif isSolidDashObstacle(safeCharacter, safeRoot, state.dashDirection) then
				local velocity = safeRoot.AssemblyLinearVelocity
				safeRoot.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
				state.damageResolved = true
				setPhase(player, state, "Recovery", now, now + RammerConfig.MissRecoveryDuration)
			else
				resolveImpact(player, state, now)
			end
		elseif state.phase == "Impact" or state.phase == "Recovery" then
			if now >= state.phaseEndsAt then
				enterCooldown(player, state, now)
			end
		end
	end
end

local function bindCharacter(player: Player, character: Model)
	local state = states[player]
	if state == nil then
		return
	end
	if state.diedConnection ~= nil then
		state.diedConnection:Disconnect()
		state.diedConnection = nil
	end
	cancelImmediately(player, state)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		local latestState = states[player]
		if humanoid == nil or not humanoid:IsA("Humanoid") or latestState == nil or player.Character ~= character then
			return
		end
		latestState.diedConnection = humanoid.Died:Connect(function()
			if states[player] == latestState then
				cancelImmediately(player, latestState)
			end
		end)
	end)
end

local function connectPlayer(player: Player)
	if states[player] ~= nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local state: RammerState = {
		phase = "Idle",
		character = nil,
		nextStartAt = 0,
		phaseStartedAt = now,
		phaseEndsAt = 0,
		leaseExpiresAt = 0,
		chargeStartedAt = 0,
		fullChargeTime = RammerConfig.FullChargeAtRankZero,
		cooldown = RammerConfig.CooldownAtRankZero,
		maximumImpactDamage = RammerConfig.FullImpactDamageAtRankZero,
		chargeAmount = 0,
		dashStartedAt = 0,
		dashEndsAt = 0,
		dashDirection = Vector3.zero,
		authorizedDashSpeed = 0,
		dashStartPosition = Vector3.zero,
		damageResolved = false,
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastRequestAt = -math.huge,
		lastKeepaliveAt = -math.huge,
		lastSequence = 0,
		attackSerial = 0,
		acceptedRequests = 0,
		rejectedRequests = 0,
		impactCount = 0,
		characterAddedConnection = nil,
		diedConnection = nil,
		classChangedConnection = nil,
		sessionChangedConnection = nil,
	}
	states[player] = state
	player:SetAttribute("RammerAcceptedRequestCount", 0)
	player:SetAttribute("RammerRejectedRequestCount", 0)
	player:SetAttribute("RammerImpactCount", 0)
	player:SetAttribute("RammerMovementViolationCount", 0)
	player:SetAttribute("RammerLastImpactDamage", 0)
	player:SetAttribute("RammerLastImpactKnockback", 0)
	player:SetAttribute("RammerLastDashStartedAt", 0)
	player:SetAttribute("RammerLastDashStartPosition", Vector3.zero)
	broadcastPhase(player, state)

	state.classChangedConnection = player:GetAttributeChangedSignal(ClassConfig.ClassAttribute):Connect(function()
		if ClassService.GetClassId(player) ~= ClassConfig.RammerClassId then
			cancelImmediately(player, state)
		end
	end)
	state.sessionChangedConnection = player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(function()
		if not PlayerSessionService.IsArena(player) then
			cancelImmediately(player, state)
		end
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
	if state.diedConnection ~= nil then
		state.diedConnection:Disconnect()
	end
	if state.classChangedConnection ~= nil then
		state.classChangedConnection:Disconnect()
	end
	if state.sessionChangedConnection ~= nil then
		state.sessionChangedConnection:Disconnect()
	end
	states[player] = nil
end

function RammerCombatService.GetMovementAuthorization(player: Player, root: BasePart): MovementAuthorization?
	local state = states[player]
	if
		state == nil
		or not PlayerSessionService.IsArena(player)
		or state.character ~= player.Character
		or root.Parent ~= state.character
	then
		return nil
	end
	local speedRank = ProgressionService.GetUpgradeRank(player, "Speed")
	local normalMaxSpeed = MovementConfig.MaxSpeed * ProgressionConfig.GetSpeedMultiplier(speedRank)
	if state.phase == "Charging" or state.phase == "Ready" then
		return {
			phase = state.phase,
			legalMaxSpeed = normalMaxSpeed * RammerConfig.ChargeMovementSpeedMultiplier,
			maximumAcceleration = MovementConfig.ServerMaxAcceleration * RammerConfig.ChargeSteeringMultiplier,
			maximumSampleDistance = MovementConfig.ServerMaxTeleportDistance,
			speedTolerance = RammerConfig.ChargeSpeedTolerance,
			clearViolation = false,
		}
	elseif state.phase ~= "Dash" then
		return nil
	end

	local now = Workspace:GetServerTimeNow()
	local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local forwardSpeed = velocity:Dot(state.dashDirection)
	local lateralVelocity = velocity - state.dashDirection * forwardSpeed
	local displacement = Vector3.new(
		root.Position.X - state.dashStartPosition.X,
		0,
		root.Position.Z - state.dashStartPosition.Z
	)
	local forwardDisplacement = displacement:Dot(state.dashDirection)
	local lateralDisplacement = displacement - state.dashDirection * forwardDisplacement
	local directionDot = if velocity.Magnitude > 0.01 then velocity.Unit:Dot(state.dashDirection) else 1
	local pastDirectionGrace = now - state.dashStartedAt >= RammerConfig.DashDirectionGracePeriod
	local clearViolation = now > state.dashEndsAt + MovementConfig.ServerMonitorInterval
		or velocity.Magnitude > state.authorizedDashSpeed + RammerConfig.DashSpeedTolerance
		or (pastDirectionGrace and forwardSpeed < -RammerConfig.DashSpeedTolerance)
		or (pastDirectionGrace and directionDot < RammerConfig.MinimumDashDirectionDot)
		or (pastDirectionGrace and lateralVelocity.Magnitude > state.authorizedDashSpeed * RammerConfig.DashSteeringMultiplier + 1)
		or displacement.Magnitude > RammerConfig.MaximumDashDisplacement
		or forwardDisplacement < -1
		or lateralDisplacement.Magnitude > RammerConfig.MaximumDashLateralDisplacement
	return {
		phase = state.phase,
		legalMaxSpeed = state.authorizedDashSpeed,
		maximumAcceleration = RammerConfig.DashAccelerationAllowance,
		maximumSampleDistance = RammerConfig.MaximumDashDisplacement,
		speedTolerance = 0,
		clearViolation = clearViolation,
	}
end

function RammerCombatService.CancelMovementViolation(player: Player)
	local state = states[player]
	if state == nil or state.phase ~= "Dash" then
		return
	end
	local countValue = player:GetAttribute("RammerMovementViolationCount")
	local count = if typeof(countValue) == "number" and isFinite(countValue) then math.max(math.floor(countValue), 0) else 0
	player:SetAttribute("RammerMovementViolationCount", count + 1)
	local now = Workspace:GetServerTimeNow()
	local character, _humanoid, root = getAliveCharacter(player)
	if character == state.character and root ~= nil then
		clampDashVelocity(player, root)
	end
	state.damageResolved = true
	setPhase(player, state, "Recovery", now, now + RammerConfig.MissRecoveryDuration)
end

function RammerCombatService.CancelForPlayer(player: Player)
	local state = states[player]
	if state ~= nil then
		cancelImmediately(player, state)
	end
end

local function validateConfiguration()
	local epsilon = 0.0001
	if
		math.abs(RammerConfig.GetFullChargeTime(0) - RammerConfig.FullChargeAtRankZero) > epsilon
		or math.abs(RammerConfig.GetFullChargeTime(ProgressionConfig.MaxUpgradeRank) - RammerConfig.FullChargeAtRankThirty) > epsilon
		or math.abs(RammerConfig.GetCooldown(0) - RammerConfig.CooldownAtRankZero) > epsilon
		or math.abs(RammerConfig.GetCooldown(ProgressionConfig.MaxUpgradeRank) - RammerConfig.CooldownAtRankThirty) > epsilon
		or math.abs(RammerConfig.GetFullImpactDamage(0) - RammerConfig.FullImpactDamageAtRankZero) > epsilon
		or math.abs(RammerConfig.GetFullImpactDamage(ProgressionConfig.MaxUpgradeRank) - RammerConfig.FullImpactDamageAtRankThirty) > epsilon
		or math.abs(RammerConfig.GetAuthorizedDashSpeed(ProgressionConfig.MaxUpgradeRank, 1) - RammerConfig.MaximumAuthorizedDashSpeed) > epsilon
		or RammerConfig.RammerBreakableDamageMultiplier < 2.5
		or RammerConfig.RammerBreakableDamageMultiplier > 3.5
		or RammerConfig.RammerBreakableDestroyCooldown < 0.35
		or RammerConfig.RammerBreakableDestroyCooldown > 0.65
		or math.min(
			RammerConfig.FullImpactDamageAtRankThirty * RammerConfig.RammerBreakableDamageMultiplier,
			ProgressionConfig.MaxBreakableDamagePerHit
		) >= 150
		or RammerConfig.HoldKeepaliveInterval <= RammerConfig.MinimumKeepaliveInterval
		or RammerConfig.HoldLeaseTimeout <= RammerConfig.HoldKeepaliveInterval * 2
		or RammerConfig.MaximumTargetsPerCharge ~= 1
		or RammerConfig.MaximumServerDamage > 45
		or RammerConfig.MaximumServerKnockback > CombatConfig.MaxHorizontalKnockbackSpeed
	then
		error("RammerConfig produces unsafe or inconsistent prototype values")
	end
end

function RammerCombatService.Init()
	if initialized then
		return
	end
	validateConfiguration()
	initialized = true
	PlayerSessionService.Init()
	ProgressionService.Init()
	ClassService.Init()
	BreakableObjectService.Init()
	intentRemote = getOrCreateRemote("RammerAttackIntent")
	stateBroadcastRemote = getOrCreateRemote("RammerStateBroadcast")
	local attackIntentRemote = intentRemote :: RemoteEvent
	attackIntentRemote.OnServerEvent:Connect(handleIntent)
	RunService.Heartbeat:Connect(updateActiveRammers)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return RammerCombatService
