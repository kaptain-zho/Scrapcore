--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local CombatConfig = require(shared:WaitForChild("CombatConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local SpinnerConfig = require(shared:WaitForChild("SpinnerConfig"))
local BreakableObjectService = require(script.Parent:WaitForChild("BreakableObjectService"))
local ClassService = require(script.Parent:WaitForChild("ClassService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

local ROBOT_CHASSIS_NAME = "RobotChassis"
local SPINNER_HIT_ORIGIN_NAME = "SpinnerHitOrigin"
local KNOCKBACK_VELOCITY_ATTRIBUTE = "CombatKnockbackVelocity"
local KNOCKBACK_STARTED_AT_ATTRIBUTE = "CombatKnockbackStartedAt"
local KNOCKBACK_UNTIL_ATTRIBUTE = "CombatKnockbackUntil"

type SpinnerState = {
	phase: string,
	character: Model?,
	nextStartAt: number,
	phaseStartedAt: number,
	phaseEndsAt: number,
	nextPulseAt: number,
	leaseExpiresAt: number,
	spinUpDuration: number,
	pulseInterval: number,
	pulseDamage: number,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	lastKeepaliveAt: number,
	lastSequence: number,
	attackSerial: number,
	acceptedRequests: number,
	rejectedRequests: number,
	pulseCount: number,
	affectedTargetCount: number,
	characterAddedConnection: RBXScriptConnection?,
	diedConnection: RBXScriptConnection?,
	classChangedConnection: RBXScriptConnection?,
}

type TargetCandidate = {
	model: Model,
	targetPart: BasePart,
	humanoid: Humanoid?,
	breakable: Model?,
	distance: number,
}

local states: {[Player]: SpinnerState} = {}
local initialized = false
local intentRemote: RemoteEvent? = nil
local stateBroadcastRemote: RemoteEvent? = nil

local SpinnerCombatService = {}

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

local function getSpinnerOrigin(character: Model): (Vector3?, BasePart?)
	local chassis = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassis == nil or not chassis:IsA("Model") then
		return nil, nil
	end
	local spinner = chassis:FindFirstChild(ClassConfig.EquippedSpinnerName)
	if spinner == nil or not spinner:IsA("Model") then
		return nil, nil
	end
	local spinnerRoot = spinner:FindFirstChild("SpinnerRoot", true)
	local hitOrigin = spinner:FindFirstChild(SPINNER_HIT_ORIGIN_NAME, true)
	if
		spinnerRoot == nil
		or not spinnerRoot:IsA("BasePart")
		or hitOrigin == nil
		or not hitOrigin:IsA("Attachment")
	then
		return nil, nil
	end
	return hitOrigin.WorldPosition, spinnerRoot
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

local function isInWeaponArea(origin: Vector3, attackerRoot: BasePart, targetPart: BasePart): (boolean, number)
	local offset = targetPart.Position - origin
	local distance = offset.Magnitude
	if distance > SpinnerConfig.MaximumTargetRange or math.abs(offset.Y) > SpinnerConfig.MaximumVerticalDifference then
		return false, distance
	end
	local horizontal = Vector3.new(offset.X, 0, offset.Z)
	if horizontal.Magnitude <= 0.01 then
		return true, distance
	end
	local forward = Vector3.new(attackerRoot.CFrame.LookVector.X, 0, attackerRoot.CFrame.LookVector.Z)
	if forward.Magnitude <= 0.01 then
		return false, distance
	end
	return forward.Unit:Dot(horizontal.Unit) >= SpinnerConfig.MinimumForwardDot, distance
end

local function applyHorizontalKnockback(
	attackerRoot: BasePart,
	target: Model,
	targetRoot: BasePart,
	knockbackSpeed: number
)
	local displacement = targetRoot.Position - attackerRoot.Position
	local horizontal = Vector3.new(displacement.X, 0, displacement.Z)
	if horizontal.Magnitude <= 0.01 then
		local look = attackerRoot.CFrame.LookVector
		horizontal = Vector3.new(look.X, 0, look.Z)
	end
	if horizontal.Magnitude <= 0.01 then
		return
	end

	local safeSpeed = math.clamp(knockbackSpeed, 0, CombatConfig.MaxHorizontalKnockbackSpeed)
	local knockbackVelocity = horizontal.Unit * safeSpeed
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

local function resolvePulse(player: Player, state: SpinnerState): number
	local character, _humanoid, attackerRoot = getAliveCharacter(player)
	if
		character == nil
		or attackerRoot == nil
		or character ~= state.character
		or ClassService.GetClassId(player) ~= ClassConfig.SpinnerClassId
		or character:GetAttribute("SpinnerReady") ~= true
	then
		return 0
	end
	local origin = getSpinnerOrigin(character)
	if origin == nil then
		return 0
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.MaxParts = SpinnerConfig.MaximumQueryParts
	local nearbyParts = Workspace:GetPartBoundsInRadius(origin, SpinnerConfig.QueryRadius, overlapParams)
	local candidates: {TargetCandidate} = {}
	local seenModels: {[Model]: boolean} = {}

	for _, part in nearbyParts do
		local breakable = BreakableObjectService.GetBreakableFromPart(part)
		if breakable ~= nil then
			if seenModels[breakable] == true then
				continue
			end
			local targetPart = breakable.PrimaryPart
			if targetPart == nil then
				continue
			end
			local inArea, distance = isInWeaponArea(origin, attackerRoot, targetPart)
			if not inArea or not hasLineOfSight(origin, breakable, targetPart, character) then
				continue
			end
			seenModels[breakable] = true
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
			or seenModels[target] == true
		then
			continue
		end
		local inArea, distance = isInWeaponArea(origin, attackerRoot, targetRoot)
		if not inArea or not hasLineOfSight(origin, target, targetRoot, character) then
			continue
		end
		seenModels[target] = true
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

	local affected = 0
	for _, candidate in candidates do
		if affected >= SpinnerConfig.MaximumTargetsPerPulse then
			break
		end
		if candidate.breakable ~= nil then
			local appliedDamage = BreakableObjectService.Damage(candidate.breakable, player, state.pulseDamage)
			if appliedDamage > 0 then
				affected += 1
			end
		elseif candidate.humanoid ~= nil and candidate.humanoid.Health > 0 then
			local healthBefore = candidate.humanoid.Health
			candidate.humanoid:TakeDamage(state.pulseDamage)
			applyHorizontalKnockback(
				attackerRoot,
				candidate.model,
				candidate.targetPart,
				SpinnerConfig.PulseKnockbackSpeed
			)
			affected += 1
			if healthBefore > 0 and candidate.humanoid.Health <= 0 then
				local targetPlayer = Players:GetPlayerFromCharacter(candidate.model)
				ProgressionService.AwardElimination(player, targetPlayer, candidate.humanoid)
			end
		end
	end
	return affected
end

local function broadcastPhase(player: Player, state: SpinnerState)
	player:SetAttribute("SpinnerAttackSerial", state.attackSerial)
	player:SetAttribute("SpinnerPhaseStartedAt", state.phaseStartedAt)
	player:SetAttribute("SpinnerPhaseEndsAt", state.phaseEndsAt)
	player:SetAttribute("SpinnerAttackPhase", state.phase)
	local broadcastRemote = stateBroadcastRemote
	if broadcastRemote == nil then
		return
	end
	broadcastRemote:FireAllClients(
		player,
		state.attackSerial,
		state.phase,
		state.phaseStartedAt,
		state.phaseEndsAt
	)
end

local function setPhase(player: Player, state: SpinnerState, phase: string, startedAt: number, endsAt: number)
	state.phase = phase
	state.phaseStartedAt = startedAt
	state.phaseEndsAt = endsAt
	broadcastPhase(player, state)
end

local function cancelSpinner(player: Player, state: SpinnerState)
	if state.phase == "Idle" and state.character == nil then
		return
	end
	state.character = nil
	state.nextStartAt = 0
	state.nextPulseAt = 0
	state.leaseExpiresAt = 0
	setPhase(player, state, "Idle", Workspace:GetServerTimeNow(), 0)
end

local function beginSpinDown(player: Player, state: SpinnerState, now: number)
	state.nextPulseAt = 0
	state.leaseExpiresAt = 0
	state.nextStartAt = now + SpinnerConfig.PostSpinCooldown
	setPhase(player, state, "SpinDown", now, now + SpinnerConfig.SpinDownDuration)
end

local function rejectRequest(player: Player, state: SpinnerState)
	state.rejectedRequests += 1
	player:SetAttribute("SpinnerRejectedRequestCount", state.rejectedRequests)
end

local function acceptRequest(player: Player, state: SpinnerState)
	state.acceptedRequests += 1
	player:SetAttribute("SpinnerAcceptedRequestCount", state.acceptedRequests)
end

local function handleIntent(player: Player, intentValue: unknown, sequenceValue: unknown, ...: unknown)
	local state = states[player]
	if state == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now - state.requestWindowStartedAt >= SpinnerConfig.RequestRateWindow then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if
		state.requestsInWindow > SpinnerConfig.MaximumRequestsPerWindow
		or now - state.lastRequestAt < SpinnerConfig.MinimumRequestInterval
	then
		state.lastRequestAt = now
		rejectRequest(player, state)
		return
	end
	state.lastRequestAt = now

	if
		select("#", ...) ~= 0
		or typeof(intentValue) ~= "string"
		or typeof(sequenceValue) ~= "number"
	then
		rejectRequest(player, state)
		return
	end
	local intent = intentValue :: string
	local sequence = sequenceValue :: number
	if
		(intent ~= "Start" and intent ~= "Stop" and intent ~= "KeepAlive")
		or not isFinite(sequence)
		or sequence % 1 ~= 0
		or sequence <= state.lastSequence
		or sequence > state.lastSequence + SpinnerConfig.MaximumSequenceAdvance
	then
		rejectRequest(player, state)
		return
	end
	state.lastSequence = sequence

	local character, _humanoid, _root = getAliveCharacter(player)
	if
		character == nil
		or ClassService.GetClassId(player) ~= ClassConfig.SpinnerClassId
		or character:GetAttribute("SpinnerReady") ~= true
	then
		rejectRequest(player, state)
		return
	end
	local origin = getSpinnerOrigin(character)
	if origin == nil then
		rejectRequest(player, state)
		return
	end

	if intent == "KeepAlive" then
		if
			(state.phase ~= "SpinUp" and state.phase ~= "Active")
			or state.character ~= character
			or now - state.lastKeepaliveAt < SpinnerConfig.MinimumKeepaliveInterval
		then
			rejectRequest(player, state)
			return
		end
		state.lastKeepaliveAt = now
		state.leaseExpiresAt = now + SpinnerConfig.HoldLeaseTimeout
		acceptRequest(player, state)
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
		state.spinUpDuration = SpinnerConfig.GetSpinUpDuration(attackRateRank)
		state.pulseInterval = SpinnerConfig.GetPulseInterval(attackRateRank)
		state.pulseDamage = SpinnerConfig.GetPulseDamage(damageRank)
		state.attackSerial += 1
		state.nextPulseAt = 0
		state.lastKeepaliveAt = now
		state.leaseExpiresAt = now + SpinnerConfig.HoldLeaseTimeout
		setPhase(player, state, "SpinUp", now, now + state.spinUpDuration)
		acceptRequest(player, state)
		return
	end

	if (state.phase ~= "SpinUp" and state.phase ~= "Active") or state.character ~= character then
		rejectRequest(player, state)
		return
	end
	beginSpinDown(player, state, now)
	acceptRequest(player, state)
end

local function updateActiveSpinners(_deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	for player, state in states do
		if state.phase == "Idle" then
			continue
		end

		local character = player.Character
		local validCharacter = character ~= nil
			and character == state.character
			and character.Parent ~= nil
			and character:GetAttribute("SpinnerReady") == true
			and ClassService.GetClassId(player) == ClassConfig.SpinnerClassId
			and character:FindFirstChildOfClass("Humanoid") ~= nil
			and (character:FindFirstChildOfClass("Humanoid") :: Humanoid).Health > 0
			and getSpinnerOrigin(character) ~= nil
		if not validCharacter then
			cancelSpinner(player, state)
			continue
		end
		if
			(state.phase == "SpinUp" or state.phase == "Active")
			and now >= state.leaseExpiresAt
		then
			beginSpinDown(player, state, now)
			continue
		end

		if state.phase == "SpinUp" then
			if now >= state.phaseEndsAt then
				state.nextPulseAt = now
				setPhase(player, state, "Active", now, 0)
			end
		elseif state.phase == "Active" then
			local pulseIterations = 0
			while now >= state.nextPulseAt and pulseIterations < SpinnerConfig.MaximumCatchUpPulsesPerHeartbeat do
				local affected = resolvePulse(player, state)
				state.pulseCount += 1
				state.affectedTargetCount += affected
				player:SetAttribute("SpinnerPulseCount", state.pulseCount)
				player:SetAttribute("SpinnerAffectedTargetCount", state.affectedTargetCount)
				state.nextPulseAt += state.pulseInterval
				pulseIterations += 1
			end
			if pulseIterations >= SpinnerConfig.MaximumCatchUpPulsesPerHeartbeat and now >= state.nextPulseAt then
				state.nextPulseAt = now + state.pulseInterval
			end
		elseif state.phase == "SpinDown" then
			if now >= state.phaseEndsAt then
				setPhase(player, state, "Cooldown", now, state.nextStartAt)
			end
		elseif state.phase == "Cooldown" and now >= state.nextStartAt then
			state.character = nil
			setPhase(player, state, "Idle", now, 0)
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
	cancelSpinner(player, state)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		local latestState = states[player]
		if humanoid == nil or not humanoid:IsA("Humanoid") or latestState == nil or player.Character ~= character then
			return
		end
		latestState.diedConnection = humanoid.Died:Connect(function()
			if states[player] == latestState then
				cancelSpinner(player, latestState)
			end
		end)
	end)
end

local function connectPlayer(player: Player)
	if states[player] ~= nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local state: SpinnerState = {
		phase = "Idle",
		character = nil,
		nextStartAt = 0,
		phaseStartedAt = now,
		phaseEndsAt = 0,
		nextPulseAt = 0,
		leaseExpiresAt = 0,
		spinUpDuration = SpinnerConfig.SpinUpAtRankZero,
		pulseInterval = SpinnerConfig.PulseIntervalAtRankZero,
		pulseDamage = SpinnerConfig.PulseDamageAtRankZero,
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastRequestAt = -math.huge,
		lastKeepaliveAt = -math.huge,
		lastSequence = 0,
		attackSerial = 0,
		acceptedRequests = 0,
		rejectedRequests = 0,
		pulseCount = 0,
		affectedTargetCount = 0,
		characterAddedConnection = nil,
		diedConnection = nil,
		classChangedConnection = nil,
	}
	states[player] = state
	player:SetAttribute("SpinnerAcceptedRequestCount", 0)
	player:SetAttribute("SpinnerRejectedRequestCount", 0)
	player:SetAttribute("SpinnerPulseCount", 0)
	player:SetAttribute("SpinnerAffectedTargetCount", 0)
	player:SetAttribute("SpinnerAttackPhase", "Idle")
	player:SetAttribute("SpinnerAttackSerial", 0)
	player:SetAttribute("SpinnerPhaseStartedAt", now)
	player:SetAttribute("SpinnerPhaseEndsAt", 0)

	state.classChangedConnection = player:GetAttributeChangedSignal(ClassConfig.ClassAttribute):Connect(function()
		if ClassService.GetClassId(player) ~= ClassConfig.SpinnerClassId then
			cancelSpinner(player, state)
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
	states[player] = nil
end

local function validateConfiguration()
	local epsilon = 0.0001
	if
		math.abs(SpinnerConfig.GetSpinUpDuration(0) - SpinnerConfig.SpinUpAtRankZero) > epsilon
		or math.abs(SpinnerConfig.GetSpinUpDuration(ProgressionConfig.MaxUpgradeRank) - SpinnerConfig.SpinUpAtRankThirty) > epsilon
		or math.abs(SpinnerConfig.GetPulseInterval(0) - SpinnerConfig.PulseIntervalAtRankZero) > epsilon
		or math.abs(SpinnerConfig.GetPulseInterval(ProgressionConfig.MaxUpgradeRank) - SpinnerConfig.PulseIntervalAtRankThirty) > epsilon
		or math.abs(SpinnerConfig.GetPulseDamage(0) - SpinnerConfig.PulseDamageAtRankZero) > epsilon
		or math.abs(SpinnerConfig.GetPulseDamage(ProgressionConfig.MaxUpgradeRank) - SpinnerConfig.PulseDamageAtRankThirty) > epsilon
		or SpinnerConfig.PulseKnockbackSpeed > CombatConfig.MaxHorizontalKnockbackSpeed
		or SpinnerConfig.MaximumTargetsPerPulse < 1
		or SpinnerConfig.MaximumTargetsPerPulse > 6
		or SpinnerConfig.HoldKeepaliveInterval <= SpinnerConfig.MinimumKeepaliveInterval
		or SpinnerConfig.HoldLeaseTimeout <= SpinnerConfig.HoldKeepaliveInterval * 2
	then
		error("SpinnerConfig produces unsafe or inconsistent prototype values")
	end
end

function SpinnerCombatService.Init()
	if initialized then
		return
	end
	validateConfiguration()
	initialized = true
	ProgressionService.Init()
	ClassService.Init()
	BreakableObjectService.Init()
	intentRemote = getOrCreateRemote("SpinnerAttackIntent")
	stateBroadcastRemote = getOrCreateRemote("SpinnerStateBroadcast")
	local attackIntentRemote = intentRemote :: RemoteEvent
	attackIntentRemote.OnServerEvent:Connect(handleIntent)
	RunService.Heartbeat:Connect(updateActiveSpinners)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return SpinnerCombatService
