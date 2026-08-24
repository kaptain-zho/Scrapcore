--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(shared:WaitForChild("CombatConfig"))
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local SpinnerConfig = require(shared:WaitForChild("SpinnerConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local attackRequestRemote = remotes:WaitForChild("HammerAttackRequest") :: RemoteEvent
local attackBroadcastRemote = remotes:WaitForChild("HammerAttackBroadcast") :: RemoteEvent
local spinnerIntentRemote = remotes:WaitForChild("SpinnerAttackIntent") :: RemoteEvent
local spinnerStateBroadcastRemote = remotes:WaitForChild("SpinnerStateBroadcast") :: RemoteEvent

local WEAPON_MOTOR_NAME = "WeaponMountMotor"

type SwingState = {
	startedAt: number,
	attackId: number,
	predicted: boolean,
}

type CombatModifiers = {
	DamageBonus: number,
	MaxDamage: number,
	KnockbackSpeed: number,
	CooldownPenalty: number,
	MaxCooldown: number,
}

type SpinVisualState = {
	phase: string,
	startedAt: number,
	endsAt: number,
	attackId: number,
	predicted: boolean,
	predictionExpiresAt: number,
	angle: number,
}

local activeSwings: {[Model]: SwingState} = {}
local activeSpins: {[Model]: SpinVisualState} = {}
local requestSequence = 0
local spinnerRequestSequence = 0
local nextLocalAttackAt = 0
local primaryAttackHeld = false
local nextSpinnerKeepaliveAt = 0

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getClassCombatModifiers(targetPlayer: Player): CombatModifiers?
	local classValue = targetPlayer:GetAttribute(ClassConfig.ClassAttribute)
	if typeof(classValue) ~= "string" then
		return nil
	end
	local definition = ClassConfig.Definitions[classValue]
	return if definition ~= nil then definition.Combat else nil
end

local function getClassId(targetPlayer: Player): string
	local classValue = targetPlayer:GetAttribute(ClassConfig.ClassAttribute)
	return if typeof(classValue) == "string" then classValue else ClassConfig.BaseClassId
end

local function getCurrentCooldown(): number
	local rankValue = player:GetAttribute("AttackRateUpgradeLevel")
	local rank = if typeof(rankValue) == "number" and isFinite(rankValue)
		then math.clamp(math.floor(rankValue), 0, ProgressionConfig.MaxUpgradeRank)
		else 0
	local combatModifiers = getClassCombatModifiers(player)
	local cooldownPenalty = if combatModifiers ~= nil then combatModifiers.CooldownPenalty else 0
	local maximumCooldown = if combatModifiers ~= nil
		then math.min(combatModifiers.MaxCooldown, ClassConfig.MaxServerCooldown)
		else CombatConfig.Cooldown
	return math.clamp(
		CombatConfig.Cooldown * ProgressionConfig.GetAttackRateMultiplier(rank) + cooldownPenalty,
		CombatConfig.MinCooldown,
		maximumCooldown
	)
end

local function getWeaponMotor(character: Model): Motor6D?
	local motor = character:FindFirstChild(WEAPON_MOTOR_NAME, true)
	return if motor ~= nil and motor:IsA("Motor6D") then motor else nil
end

local function getRestC0(motor: Motor6D): CFrame
	local part0 = motor.Part0
	if part0 ~= nil then
		local mount = part0:FindFirstChild("FrontWeaponMount")
		if mount ~= nil and mount:IsA("Attachment") then
			return mount.CFrame
		end
	end
	return motor.C0
end

local function getSwingAngle(character: Model, elapsed: number): number?
	if elapsed < 0 then
		return 0
	end
	if elapsed < CombatConfig.Windup then
		local alpha = elapsed / CombatConfig.Windup
		local eased = 1 - (1 - alpha) ^ 3
		return CombatConfig.SwingWindupAngle * eased
	end

	local activeElapsed = elapsed - CombatConfig.Windup
	if activeElapsed < CombatConfig.ActiveTime then
		local alpha = activeElapsed / CombatConfig.ActiveTime
		local eased = 0.5 - math.cos(alpha * math.pi) * 0.5
		return CombatConfig.SwingWindupAngle
			+ (CombatConfig.SwingFollowThroughAngle - CombatConfig.SwingWindupAngle) * eased
	end

	local attacker = Players:GetPlayerFromCharacter(character)
	local combatModifiers = if attacker ~= nil then getClassCombatModifiers(attacker) else nil
	local recoveryDuration = CombatConfig.Recovery
		+ (if combatModifiers ~= nil then combatModifiers.CooldownPenalty else 0)
	local recoveryElapsed = activeElapsed - CombatConfig.ActiveTime
	if recoveryElapsed < recoveryDuration then
		local alpha = recoveryElapsed / recoveryDuration
		local eased = 1 - (1 - alpha) ^ 2
		return CombatConfig.SwingFollowThroughAngle * (1 - eased)
	end
	return nil
end

local function beginSwing(character: Model, startedAt: number, attackId: number, predicted: boolean)
	activeSwings[character] = {
		startedAt = startedAt,
		attackId = attackId,
		predicted = predicted,
	}
end

local function requestAttack()
	local classId = getClassId(player)
	if classId == ClassConfig.SpinnerClassId or classId == ClassConfig.RammerClassId then
		return
	end
	local character = player.Character
	if character == nil or character.Parent == nil or character:GetAttribute("HammerReady") ~= true then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now < nextLocalAttackAt then
		return
	end
	nextLocalAttackAt = now + getCurrentCooldown()
	requestSequence += 1
	beginSwing(character, now, -requestSequence, true)
	attackRequestRemote:FireServer(requestSequence)
end

local function getSpinnerMotor(character: Model): Motor6D?
	local motor = character:FindFirstChild(ClassConfig.SpinnerWeaponMotorName, true)
	return if motor ~= nil and motor:IsA("Motor6D") then motor else nil
end

local function getSpinnerRestC0(motor: Motor6D): CFrame
	local part0 = motor.Part0
	if part0 ~= nil then
		local mount = part0:FindFirstChild("FrontWeaponMount")
		if mount ~= nil and mount:IsA("Attachment") then
			return mount.CFrame
		end
	end
	return motor.C0
end

local function getUpgradeRank(attributeName: string): number
	local value = player:GetAttribute(attributeName)
	if typeof(value) ~= "number" or not isFinite(value) then
		return 0
	end
	return math.clamp(math.floor(value), 0, ProgressionConfig.MaxUpgradeRank)
end

local function beginPredictedSpin(character: Model)
	local now = Workspace:GetServerTimeNow()
	local spinUpDuration = SpinnerConfig.GetSpinUpDuration(getUpgradeRank("AttackRateUpgradeLevel"))
	local previous = activeSpins[character]
	activeSpins[character] = {
		phase = "SpinUp",
		startedAt = now,
		endsAt = now + spinUpDuration,
		attackId = -(spinnerRequestSequence + 1),
		predicted = true,
		predictionExpiresAt = now + SpinnerConfig.PredictionReconcileTimeout,
		angle = if previous ~= nil then previous.angle else 0,
	}
end

local function requestSpinnerStart()
	local character = player.Character
	if
		getClassId(player) ~= ClassConfig.SpinnerClassId
		or character == nil
		or character.Parent == nil
		or character:GetAttribute("SpinnerReady") ~= true
	then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local existing = activeSpins[character]
	if existing ~= nil and existing.phase ~= "Idle" then
		return
	end
	beginPredictedSpin(character)
	spinnerRequestSequence += 1
	spinnerIntentRemote:FireServer("Start", spinnerRequestSequence)
	nextSpinnerKeepaliveAt = Workspace:GetServerTimeNow() + SpinnerConfig.HoldKeepaliveInterval
end

local function requestSpinnerStop()
	nextSpinnerKeepaliveAt = 0
	if getClassId(player) ~= ClassConfig.SpinnerClassId then
		return
	end
	local character = player.Character
	if character == nil or character.Parent == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local existing = activeSpins[character]
	if existing ~= nil and (existing.phase == "SpinUp" or existing.phase == "Active") then
		existing.phase = "SpinDown"
		existing.startedAt = now
		existing.endsAt = now + SpinnerConfig.SpinDownDuration
		existing.predicted = true
		existing.predictionExpiresAt = now + SpinnerConfig.PredictionReconcileTimeout
	end
	spinnerRequestSequence += 1
	spinnerIntentRemote:FireServer("Stop", spinnerRequestSequence)
end

local function sendSpinnerKeepalive()
	if not primaryAttackHeld or getClassId(player) ~= ClassConfig.SpinnerClassId then
		return
	end
	local character = player.Character
	if
		character == nil
		or character.Parent == nil
		or character:GetAttribute("SpinnerReady") ~= true
	then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local spin = activeSpins[character]
	if
		humanoid == nil
		or humanoid.Health <= 0
		or spin == nil
		or (spin.phase ~= "SpinUp" and spin.phase ~= "Active")
	then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now < nextSpinnerKeepaliveAt then
		return
	end
	nextSpinnerKeepaliveAt = now + SpinnerConfig.HoldKeepaliveInterval
	spinnerRequestSequence += 1
	spinnerIntentRemote:FireServer("KeepAlive", spinnerRequestSequence)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if primaryAttackHeld then
		return
	end
	primaryAttackHeld = true
	if getClassId(player) == ClassConfig.SpinnerClassId then
		requestSpinnerStart()
	elseif getClassId(player) ~= ClassConfig.RammerClassId then
		requestAttack()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local wasHeld = primaryAttackHeld
	primaryAttackHeld = false
	if wasHeld and getClassId(player) == ClassConfig.SpinnerClassId then
		requestSpinnerStop()
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	local wasHeld = primaryAttackHeld
	primaryAttackHeld = false
	if wasHeld and getClassId(player) == ClassConfig.SpinnerClassId then
		requestSpinnerStop()
	end
end)

attackBroadcastRemote.OnClientEvent:Connect(function(
	attackerValue: unknown,
	attackIdValue: unknown,
	startedAtValue: unknown
)
	if
		typeof(attackerValue) ~= "Instance"
		or not (attackerValue :: Instance):IsA("Player")
		or typeof(attackIdValue) ~= "number"
		or typeof(startedAtValue) ~= "number"
	then
		return
	end

	local attacker = attackerValue :: Player
	local attackId = attackIdValue :: number
	local startedAt = startedAtValue :: number
	if not isFinite(attackId) or attackId % 1 ~= 0 or attackId <= 0 or not isFinite(startedAt) then
		return
	end
	if math.abs(Workspace:GetServerTimeNow() - startedAt) > CombatConfig.MaxBroadcastAge then
		return
	end

	local character = attacker.Character
	if character == nil or character.Parent == nil then
		return
	end
	local existing = activeSwings[character]
	if
		attacker == player
		and existing ~= nil
		and existing.predicted
		and math.abs(existing.startedAt - startedAt) <= CombatConfig.MaxBroadcastAge
	then
		existing.attackId = attackId
		existing.predicted = false
		return
	end
	beginSwing(character, startedAt, attackId, false)
end)

local validSpinnerPhases = table.freeze({
	SpinUp = true,
	Active = true,
	SpinDown = true,
	Cooldown = true,
	Idle = true,
})

spinnerStateBroadcastRemote.OnClientEvent:Connect(function(
	attackerValue: unknown,
	attackIdValue: unknown,
	phaseValue: unknown,
	startedAtValue: unknown,
	endsAtValue: unknown
)
	if
		typeof(attackerValue) ~= "Instance"
		or not (attackerValue :: Instance):IsA("Player")
		or typeof(attackIdValue) ~= "number"
		or typeof(phaseValue) ~= "string"
		or typeof(startedAtValue) ~= "number"
		or typeof(endsAtValue) ~= "number"
	then
		return
	end
	local attacker = attackerValue :: Player
	local attackId = attackIdValue :: number
	local phase = phaseValue :: string
	local startedAt = startedAtValue :: number
	local endsAt = endsAtValue :: number
	if
		not isFinite(attackId)
		or attackId % 1 ~= 0
		or attackId < 0
		or validSpinnerPhases[phase] ~= true
		or not isFinite(startedAt)
		or not isFinite(endsAt)
		or math.abs(Workspace:GetServerTimeNow() - startedAt) > SpinnerConfig.MaximumBroadcastAge
	then
		return
	end
	local character = attacker.Character
	if character == nil or character.Parent == nil then
		return
	end
	local previous = activeSpins[character]
	if phase == "Idle" then
		local motor = getSpinnerMotor(character)
		if motor ~= nil then
			motor.C0 = getSpinnerRestC0(motor)
		end
		activeSpins[character] = nil
		return
	end
	activeSpins[character] = {
		phase = phase,
		startedAt = startedAt,
		endsAt = endsAt,
		attackId = attackId,
		predicted = false,
		predictionExpiresAt = 0,
		angle = if previous ~= nil then previous.angle else 0,
	}
end)

local spinnerPlayerConnections: {[Player]: {RBXScriptConnection}} = {}
local trackedSpinnerPlayers: {[Player]: boolean} = { [player] = true }

local function syncSpinnerFromAttributes(attacker: Player)
	local phaseValue = attacker:GetAttribute("SpinnerAttackPhase")
	local attackIdValue = attacker:GetAttribute("SpinnerAttackSerial")
	local startedAtValue = attacker:GetAttribute("SpinnerPhaseStartedAt")
	local endsAtValue = attacker:GetAttribute("SpinnerPhaseEndsAt")
	if
		typeof(phaseValue) ~= "string"
		or typeof(attackIdValue) ~= "number"
		or typeof(startedAtValue) ~= "number"
		or typeof(endsAtValue) ~= "number"
	then
		return
	end
	local phase = phaseValue :: string
	local attackId = attackIdValue :: number
	local startedAt = startedAtValue :: number
	local endsAt = endsAtValue :: number
	if
		validSpinnerPhases[phase] ~= true
		or not isFinite(attackId)
		or attackId % 1 ~= 0
		or attackId < 0
		or not isFinite(startedAt)
		or not isFinite(endsAt)
	then
		return
	end
	local character = attacker.Character
	if character == nil or character.Parent == nil then
		return
	end
	local previous = activeSpins[character]
	if phase == "Idle" then
		local motor = getSpinnerMotor(character)
		if motor ~= nil then
			motor.C0 = getSpinnerRestC0(motor)
		end
		activeSpins[character] = nil
		return
	end
	activeSpins[character] = {
		phase = phase,
		startedAt = startedAt,
		endsAt = endsAt,
		attackId = attackId,
		predicted = false,
		predictionExpiresAt = 0,
		angle = if previous ~= nil then previous.angle else 0,
	}
end

local function disconnectSpinnerPlayer(attacker: Player)
	local connections = spinnerPlayerConnections[attacker]
	if connections == nil then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	spinnerPlayerConnections[attacker] = nil
	trackedSpinnerPlayers[attacker] = nil
end

local function connectSpinnerPlayer(attacker: Player)
	trackedSpinnerPlayers[attacker] = true
	if spinnerPlayerConnections[attacker] ~= nil then
		return
	end
	local connections: {RBXScriptConnection} = {}
	for _, attributeName in {
		"SpinnerAttackPhase",
		"SpinnerAttackSerial",
		"SpinnerPhaseStartedAt",
		"SpinnerPhaseEndsAt",
	} do
		table.insert(
			connections,
			attacker:GetAttributeChangedSignal(attributeName):Connect(function()
				syncSpinnerFromAttributes(attacker)
			end)
		)
	end
	table.insert(connections, attacker.CharacterAdded:Connect(function()
		task.defer(syncSpinnerFromAttributes, attacker)
	end))
	spinnerPlayerConnections[attacker] = connections
	task.defer(syncSpinnerFromAttributes, attacker)
end

Players.PlayerAdded:Connect(connectSpinnerPlayer)
Players.PlayerRemoving:Connect(disconnectSpinnerPlayer)
for _, otherPlayer in Players:GetPlayers() do
	connectSpinnerPlayer(otherPlayer)
end

player.CharacterAdded:Connect(function()
	nextLocalAttackAt = 0
	primaryAttackHeld = false
	nextSpinnerKeepaliveAt = 0
end)

player.CharacterRemoving:Connect(function(character: Model)
	activeSpins[character] = nil
	activeSwings[character] = nil
	primaryAttackHeld = false
	nextSpinnerKeepaliveAt = 0
end)

player:GetAttributeChangedSignal(ClassConfig.ClassAttribute):Connect(function()
	primaryAttackHeld = false
	nextSpinnerKeepaliveAt = 0
	local character = player.Character
	if character == nil then
		return
	end
	if getClassId(player) == ClassConfig.SpinnerClassId then
		activeSwings[character] = nil
	elseif activeSpins[character] ~= nil then
		local motor = getSpinnerMotor(character)
		if motor ~= nil then
			motor.C0 = getSpinnerRestC0(motor)
		end
		activeSpins[character] = nil
	end
end)

script.Destroying:Connect(function()
	for _, connections in spinnerPlayerConnections do
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	table.clear(spinnerPlayerConnections)
	table.clear(trackedSpinnerPlayers)
	table.clear(activeSpins)
	table.clear(activeSwings)
end)

local function getSpinAngularSpeed(spin: SpinVisualState, now: number): number
	if spin.phase == "SpinUp" then
		local duration = math.max(spin.endsAt - spin.startedAt, 0.001)
		local alpha = math.clamp((now - spin.startedAt) / duration, 0, 1)
		return SpinnerConfig.ActiveAngularSpeed * alpha * alpha
	elseif spin.phase == "Active" then
		return SpinnerConfig.ActiveAngularSpeed
	elseif spin.phase == "SpinDown" then
		local duration = math.max(spin.endsAt - spin.startedAt, 0.001)
		local alpha = math.clamp((now - spin.startedAt) / duration, 0, 1)
		return SpinnerConfig.ActiveAngularSpeed * (1 - alpha) ^ 2
	end
	return 0
end

local function updateSpinnerBlur(character: Model, phase: string, now: number, spin: SpinVisualState)
	local blur = character:FindFirstChild("SpinnerMotionBlur", true)
	if blur == nil or not blur:IsA("BasePart") then
		return
	end
	if phase == "Active" then
		blur.Transparency = 0.42
	elseif phase == "SpinUp" then
		local duration = math.max(spin.endsAt - spin.startedAt, 0.001)
		local alpha = math.clamp((now - spin.startedAt) / duration, 0, 1)
		blur.Transparency = 0.82 - 0.30 * alpha
	elseif phase == "SpinDown" then
		blur.Transparency = 0.68
	else
		blur.Transparency = 0.90
	end
end

local function updateWeaponVisuals(deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	for character, swing in activeSwings do
		if character.Parent == nil then
			activeSwings[character] = nil
			continue
		end

		local motor = getWeaponMotor(character)
		local angle = getSwingAngle(character, now - swing.startedAt)
		if angle == nil then
			if motor ~= nil then
				motor.C0 = getRestC0(motor)
			end
			activeSwings[character] = nil
		elseif motor ~= nil then
			motor.C0 = getRestC0(motor) * CFrame.Angles(0, angle, 0)
		end
	end

	-- Attribute comparison is a no-allocation reconciliation fallback for phase changes
	-- that arrive before a weapon model or a remote listener is ready on this client.
	for attacker in trackedSpinnerPlayers do
		local character = attacker.Character
		if character == nil or character.Parent == nil then
			continue
		end
		local phaseValue = attacker:GetAttribute("SpinnerAttackPhase")
		local serialValue = attacker:GetAttribute("SpinnerAttackSerial")
		local existing = activeSpins[character]
		if
			typeof(phaseValue) == "string"
			and typeof(serialValue) == "number"
			and (
				existing == nil
				or existing.phase ~= phaseValue
				or existing.attackId ~= serialValue
			)
		then
			syncSpinnerFromAttributes(attacker)
		end
	end

	for character, spin in activeSpins do
		if character.Parent == nil then
			activeSpins[character] = nil
			continue
		end
		if spin.predicted and now >= spin.predictionExpiresAt then
			if spin.phase == "SpinUp" or spin.phase == "Active" then
				spin.phase = "SpinDown"
				spin.startedAt = now
				spin.endsAt = now + SpinnerConfig.SpinDownDuration
				spin.predictionExpiresAt = now + SpinnerConfig.SpinDownDuration
			elseif spin.phase == "SpinDown" then
				spin.phase = "Cooldown"
				spin.startedAt = now
				spin.endsAt = now
				spin.predicted = false
			end
		end

		local motor = getSpinnerMotor(character)
		if motor == nil then
			continue
		end
		spin.angle = (spin.angle + getSpinAngularSpeed(spin, now) * deltaTime) % (math.pi * 2)
		motor.C0 = getSpinnerRestC0(motor) * CFrame.Angles(0, spin.angle, 0)
		updateSpinnerBlur(character, spin.phase, now, spin)
	end
end

local hasRenderedWeaponFrame = false
RunService.PreRender:Connect(function(deltaTime: number)
	hasRenderedWeaponFrame = true
	updateWeaponVisuals(deltaTime)
end)
RunService.Heartbeat:Connect(function(deltaTime: number)
	sendSpinnerKeepalive()
	if not hasRenderedWeaponFrame then
		updateWeaponVisuals(deltaTime)
	end
end)
