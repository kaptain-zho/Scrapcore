--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local RammerConfig = require(shared:WaitForChild("RammerConfig"))
local RammerClientState = require(script.Parent:WaitForChild("RammerClientState"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local intentRemote = remotes:WaitForChild("RammerAttackIntent") :: RemoteEvent
local stateBroadcastRemote = remotes:WaitForChild("RammerStateBroadcast") :: RemoteEvent

type VisualState = {
	phase: string,
	attackSerial: number,
	startedAt: number,
	endsAt: number,
	fullChargeTime: number,
	chargeAmount: number,
	dashDirection: Vector3,
	dashSpeed: number,
	predicted: boolean,
	predictionExpiresAt: number,
}

local validPhases = table.freeze({
	Idle = true,
	Charging = true,
	Ready = true,
	Dash = true,
	Impact = true,
	Recovery = true,
	Cooldown = true,
	Cancelled = true,
})

local visualStates: {[Model]: VisualState} = {}
local trackedPlayers: {[Player]: {RBXScriptConnection}} = {}
local requestSequence = 0
local primaryHeld = false
local nextKeepaliveAt = 0

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getClassId(targetPlayer: Player): string
	local value = targetPlayer:GetAttribute(ClassConfig.ClassAttribute)
	return if typeof(value) == "string" then value else ClassConfig.BaseClassId
end

local function getUpgradeRank(attributeName: string): number
	local value = player:GetAttribute(attributeName)
	if typeof(value) ~= "number" or not isFinite(value) then
		return 0
	end
	return math.clamp(math.floor(value), 0, ProgressionConfig.MaxUpgradeRank)
end

local function getHorizontalFacing(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local horizontal = Vector3.new(look.X, 0, look.Z)
	return if horizontal.Magnitude > 0.01 then horizontal.Unit else Vector3.new(0, 0, -1)
end

local function setVisualState(character: Model, nextState: VisualState)
	visualStates[character] = nextState
	if character == player.Character then
		RammerClientState.Set(nextState)
	end
end

local function clearLocalState()
	primaryHeld = false
	nextKeepaliveAt = 0
	RammerClientState.Clear()
	local character = player.Character
	if character ~= nil then
		visualStates[character] = nil
	end
end

local function beginPredictedCharge()
	local character = player.Character
	if
		getClassId(player) ~= ClassConfig.RammerClassId
		or character == nil
		or character.Parent == nil
		or character:GetAttribute("RammerReady") ~= true
	then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local authoritativePhase = player:GetAttribute("RammerAttackPhase")
	local existing = visualStates[character]
	if
		(typeof(authoritativePhase) == "string" and authoritativePhase ~= "Idle")
		or (existing ~= nil and existing.phase ~= "Idle")
	then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local fullChargeTime = RammerConfig.GetFullChargeTime(getUpgradeRank("AttackRateUpgradeLevel"))
	setVisualState(character, {
		phase = "Charging",
		attackSerial = -(requestSequence + 1),
		startedAt = now,
		endsAt = now + fullChargeTime,
		fullChargeTime = fullChargeTime,
		chargeAmount = 0,
		dashDirection = Vector3.zero,
		dashSpeed = 0,
		predicted = true,
		predictionExpiresAt = now + RammerConfig.PredictionReconcileTimeout,
	})
	requestSequence += 1
	intentRemote:FireServer("Start", requestSequence)
	nextKeepaliveAt = now + RammerConfig.HoldKeepaliveInterval
end

local function releasePredictedCharge(cancelOnly: boolean)
	local character = player.Character
	if character == nil or character.Parent == nil or getClassId(player) ~= ClassConfig.RammerClassId then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local current = visualStates[character]
	requestSequence += 1
	if cancelOnly then
		intentRemote:FireServer("Cancel", requestSequence)
		if current ~= nil and (current.phase == "Charging" or current.phase == "Ready" or current.phase == "Dash") then
			setVisualState(character, {
				phase = "Cancelled",
				attackSerial = current.attackSerial,
				startedAt = now,
				endsAt = now + RammerConfig.ChargeCancelDuration,
				fullChargeTime = current.fullChargeTime,
				chargeAmount = 0,
				dashDirection = Vector3.zero,
				dashSpeed = 0,
				predicted = true,
				predictionExpiresAt = now + RammerConfig.PredictionReconcileTimeout,
			})
		end
		return
	end

	intentRemote:FireServer("Release", requestSequence)
	if current == nil or (current.phase ~= "Charging" and current.phase ~= "Ready") then
		return
	end
	local holdDuration = now - current.startedAt
	if holdDuration < RammerConfig.MinimumValidHold then
		setVisualState(character, {
			phase = "Cancelled",
			attackSerial = current.attackSerial,
			startedAt = now,
			endsAt = now + RammerConfig.ChargeCancelDuration,
			fullChargeTime = current.fullChargeTime,
			chargeAmount = 0,
			dashDirection = Vector3.zero,
			dashSpeed = 0,
			predicted = true,
			predictionExpiresAt = now + RammerConfig.PredictionReconcileTimeout,
		})
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local chargeAmount = RammerConfig.GetChargeAmount(holdDuration, current.fullChargeTime)
	local direction = getHorizontalFacing(root)
	local dashSpeed = RammerConfig.GetAuthorizedDashSpeed(getUpgradeRank("SpeedUpgradeLevel"), chargeAmount)
	setVisualState(character, {
		phase = "Dash",
		attackSerial = current.attackSerial,
		startedAt = now,
		endsAt = now + RammerConfig.DashDuration,
		fullChargeTime = current.fullChargeTime,
		chargeAmount = chargeAmount,
		dashDirection = direction,
		dashSpeed = dashSpeed,
		predicted = true,
		predictionExpiresAt = now + RammerConfig.PredictionReconcileTimeout,
	})
end

local function sendKeepalive()
	if not primaryHeld or getClassId(player) ~= ClassConfig.RammerClassId then
		return
	end
	local character = player.Character
	local state = if character ~= nil then visualStates[character] else nil
	if
		character == nil
		or character.Parent == nil
		or character:GetAttribute("RammerReady") ~= true
		or state == nil
		or (state.phase ~= "Charging" and state.phase ~= "Ready")
	then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now < nextKeepaliveAt then
		return
	end
	nextKeepaliveAt = now + RammerConfig.HoldKeepaliveInterval
	requestSequence += 1
	intentRemote:FireServer("KeepAlive", requestSequence)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if getClassId(player) ~= ClassConfig.RammerClassId or primaryHeld then
		return
	end
	primaryHeld = true
	beginPredictedCharge()
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not primaryHeld then
		return
	end
	primaryHeld = false
	nextKeepaliveAt = 0
	releasePredictedCharge(false)
end)

UserInputService.WindowFocusReleased:Connect(function()
	if not primaryHeld then
		return
	end
	primaryHeld = false
	nextKeepaliveAt = 0
	releasePredictedCharge(true)
end)

local function validateBroadcast(
	attackerValue: unknown,
	attackSerialValue: unknown,
	phaseValue: unknown,
	startedAtValue: unknown,
	endsAtValue: unknown,
	fullChargeTimeValue: unknown,
	chargeAmountValue: unknown,
	directionValue: unknown,
	dashSpeedValue: unknown
): (Player?, VisualState?)
	if
		typeof(attackerValue) ~= "Instance"
		or not (attackerValue :: Instance):IsA("Player")
		or typeof(attackSerialValue) ~= "number"
		or typeof(phaseValue) ~= "string"
		or typeof(startedAtValue) ~= "number"
		or typeof(endsAtValue) ~= "number"
		or typeof(fullChargeTimeValue) ~= "number"
		or typeof(chargeAmountValue) ~= "number"
		or typeof(directionValue) ~= "Vector3"
		or typeof(dashSpeedValue) ~= "number"
	then
		return nil, nil
	end
	local attacker = attackerValue :: Player
	local attackSerial = attackSerialValue :: number
	local phase = phaseValue :: string
	local startedAt = startedAtValue :: number
	local endsAt = endsAtValue :: number
	local fullChargeTime = fullChargeTimeValue :: number
	local chargeAmount = chargeAmountValue :: number
	local direction = directionValue :: Vector3
	local dashSpeed = dashSpeedValue :: number
	if
		validPhases[phase] ~= true
		or not isFinite(attackSerial)
		or attackSerial % 1 ~= 0
		or attackSerial < 0
		or not isFinite(startedAt)
		or not isFinite(endsAt)
		or not isFinite(fullChargeTime)
		or not isFinite(chargeAmount)
		or not isFinite(direction.X)
		or not isFinite(direction.Y)
		or not isFinite(direction.Z)
		or not isFinite(dashSpeed)
		or chargeAmount < 0
		or chargeAmount > 1
		or dashSpeed < 0
		or dashSpeed > RammerConfig.MaximumAuthorizedDashSpeed
		or math.abs(Workspace:GetServerTimeNow() - startedAt) > RammerConfig.MaximumBroadcastAge
	then
		return nil, nil
	end
	return attacker, {
		phase = phase,
		attackSerial = attackSerial,
		startedAt = startedAt,
		endsAt = endsAt,
		fullChargeTime = fullChargeTime,
		chargeAmount = chargeAmount,
		dashDirection = direction,
		dashSpeed = dashSpeed,
		predicted = false,
		predictionExpiresAt = 0,
	}
end

stateBroadcastRemote.OnClientEvent:Connect(function(...: unknown)
	local attacker, state = validateBroadcast(...)
	if attacker == nil or state == nil then
		return
	end
	local character = attacker.Character
	if character == nil or character.Parent == nil then
		return
	end
	setVisualState(character, state)
end)

local function syncFromAttributes(attacker: Player)
	local character = attacker.Character
	if character == nil or character.Parent == nil then
		return
	end
	local attackerValue, state = validateBroadcast(
		attacker,
		attacker:GetAttribute("RammerAttackSerial"),
		attacker:GetAttribute("RammerAttackPhase"),
		attacker:GetAttribute("RammerPhaseStartedAt"),
		attacker:GetAttribute("RammerPhaseEndsAt"),
		attacker:GetAttribute("RammerFullChargeTime"),
		attacker:GetAttribute("RammerChargeAmount"),
		attacker:GetAttribute("RammerDashDirection"),
		attacker:GetAttribute("RammerAuthorizedDashSpeed")
	)
	if attackerValue ~= nil and state ~= nil then
		setVisualState(character, state)
	end
end

local function disconnectPlayer(attacker: Player)
	local connections = trackedPlayers[attacker]
	if connections ~= nil then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	trackedPlayers[attacker] = nil
	local character = attacker.Character
	if character ~= nil then
		visualStates[character] = nil
	end
end

local function connectPlayer(attacker: Player)
	if trackedPlayers[attacker] ~= nil then
		return
	end
	local connections: {RBXScriptConnection} = {}
	trackedPlayers[attacker] = connections
	for _, attributeName in {
		"RammerAttackSerial",
		"RammerAttackPhase",
		"RammerPhaseStartedAt",
		"RammerPhaseEndsAt",
		"RammerFullChargeTime",
		"RammerChargeAmount",
		"RammerDashDirection",
		"RammerAuthorizedDashSpeed",
	} do
		table.insert(connections, attacker:GetAttributeChangedSignal(attributeName):Connect(function()
			syncFromAttributes(attacker)
		end))
	end
	table.insert(connections, attacker.CharacterAdded:Connect(function()
		task.defer(syncFromAttributes, attacker)
	end))
	if attacker.Character ~= nil then
		task.defer(syncFromAttributes, attacker)
	end
end

Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(disconnectPlayer)
for _, otherPlayer in Players:GetPlayers() do
	connectPlayer(otherPlayer)
end

player.CharacterRemoving:Connect(clearLocalState)
player:GetAttributeChangedSignal(ClassConfig.ClassAttribute):Connect(function()
	if getClassId(player) ~= ClassConfig.RammerClassId then
		clearLocalState()
	end
end)

local function getMotor(character: Model): Motor6D?
	local motor = character:FindFirstChild(ClassConfig.RammerWeaponMotorName, true)
	return if motor ~= nil and motor:IsA("Motor6D") then motor else nil
end

local function updateVisual(character: Model, state: VisualState, now: number)
	local motor = getMotor(character)
	if motor == nil then
		return
	end
	local chargeAmount = state.chargeAmount
	if state.phase == "Charging" then
		chargeAmount = RammerConfig.GetChargeAmount(now - state.startedAt, state.fullChargeTime)
	elseif state.phase == "Ready" then
		chargeAmount = 1
	end
	chargeAmount = math.clamp(chargeAmount, 0, 1)

	local braceDistance = if state.phase == "Dash" or state.phase == "Impact" then -0.30 else -0.16 * chargeAmount
	motor.Transform = CFrame.new(0, 0, braceDistance)
	local indicator = character:FindFirstChild("RammerChargeIndicator", true)
	if indicator ~= nil and indicator:IsA("BasePart") then
		indicator.Size = Vector3.new(0.32 + 1.55 * chargeAmount, 0.12, 1.4)
		indicator.Transparency = if state.phase == "Ready"
			then 0.08
			elseif state.phase == "Charging" then 0.58 - 0.38 * chargeAmount
			else 0.72
	end
	local dashGlow = character:FindFirstChild("RammerDashGlow", true)
	if dashGlow ~= nil and dashGlow:IsA("BasePart") then
		dashGlow.Transparency = if state.phase == "Impact"
			then 0.06
			elseif state.phase == "Dash" then 0.28
			elseif state.phase == "Recovery" then 0.74
			else 1
	end
end

RunService.Heartbeat:Connect(function()
	sendKeepalive()
	local now = Workspace:GetServerTimeNow()
	for character, state in visualStates do
		if character.Parent == nil then
			visualStates[character] = nil
			continue
		end
		if state.predicted and now >= state.predictionExpiresAt then
			visualStates[character] = nil
			if character == player.Character then
				RammerClientState.Clear()
			end
			local motor = getMotor(character)
			if motor ~= nil then
				motor.Transform = CFrame.identity
			end
			continue
		end
		if state.phase == "Charging" and now >= state.endsAt then
			state.phase = "Ready"
			state.chargeAmount = 1
		elseif
			(state.phase == "Cancelled" or state.phase == "Dash" or state.phase == "Impact" or state.phase == "Recovery")
			and state.endsAt > 0
			and now >= state.endsAt
			and state.predicted
		then
			state.phase = "Idle"
		end
		updateVisual(character, state, now)
	end
end)

script.Destroying:Connect(function()
	if primaryHeld and getClassId(player) == ClassConfig.RammerClassId then
		primaryHeld = false
		releasePredictedCharge(true)
	end
	for attacker in trackedPlayers do
		disconnectPlayer(attacker)
	end
	table.clear(visualStates)
	RammerClientState.Clear()
end)
