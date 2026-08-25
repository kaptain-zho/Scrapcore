--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local EvolutionConfig = require(shared:WaitForChild("EvolutionConfig"))
local ImpactFoundryConfig = require(shared:WaitForChild("ImpactFoundryConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local ImpactFoundryClientState = require(script.Parent:WaitForChild("ImpactFoundryClientState"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local attackRequestRemote = remotes:WaitForChild("ImpactFoundryAttackRequest") :: RemoteEvent
local stateBroadcastRemote = remotes:WaitForChild("ImpactFoundryStateBroadcast") :: RemoteEvent

type VisualState = {
	phase: string,
	attackSerial: number,
	startedAt: number,
	endsAt: number,
	predicted: boolean,
	predictionExpiresAt: number,
}

local VALID_PHASES = table.freeze({
	Idle = true,
	Windup = true,
	Impact = true,
	Recovery = true,
})

local visualStates: {[Player]: VisualState} = {}
local requestSequence = 0

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isImpactFoundryActive(targetPlayer: Player): boolean
	return targetPlayer:GetAttribute(SessionConfig.SessionAttribute) == SessionConfig.ArenaState
		and targetPlayer:GetAttribute(EvolutionConfig.CurrentNodeAttribute) == ClassConfig.ImpactFoundryNodeId
end

local function getUpgradeRank(attributeName: string): number
	local value = player:GetAttribute(attributeName)
	if typeof(value) ~= "number" or not isFinite(value) then
		return 0
	end
	return math.clamp(math.floor(value), 0, ProgressionConfig.MaxUpgradeRank)
end

local function setVisualState(targetPlayer: Player, state: VisualState)
	visualStates[targetPlayer] = state
	if targetPlayer == player then
		ImpactFoundryClientState.Set(state)
	end
end

local function clearLocalState()
	visualStates[player] = nil
	ImpactFoundryClientState.Clear()
end

local function requestStrike()
	local character = player.Character
	if
		not isImpactFoundryActive(player)
		or character == nil
		or character.Parent == nil
		or character:GetAttribute("ImpactFoundryReady") ~= true
	then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local authoritativePhase = player:GetAttribute("ImpactFoundryAttackPhase")
	local current = visualStates[player]
	if
		(typeof(authoritativePhase) == "string" and authoritativePhase ~= "Idle")
		or (current ~= nil and current.phase ~= "Idle")
	then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local duration = ImpactFoundryConfig.GetWindupDuration(getUpgradeRank("AttackRateUpgradeLevel"))
	requestSequence += 1
	setVisualState(player, {
		phase = "Windup",
		attackSerial = -requestSequence,
		startedAt = now,
		endsAt = now + duration,
		predicted = true,
		predictionExpiresAt = now + ImpactFoundryConfig.PredictionReconcileTimeout,
	})
	attackRequestRemote:FireServer(requestSequence)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	requestStrike()
end)

local function validateBroadcast(
	attackerValue: unknown,
	attackSerialValue: unknown,
	phaseValue: unknown,
	startedAtValue: unknown,
	endsAtValue: unknown
): (Player?, VisualState?)
	if
		typeof(attackerValue) ~= "Instance"
		or not (attackerValue :: Instance):IsA("Player")
		or typeof(attackSerialValue) ~= "number"
		or typeof(phaseValue) ~= "string"
		or typeof(startedAtValue) ~= "number"
		or typeof(endsAtValue) ~= "number"
	then
		return nil, nil
	end
	local attacker = attackerValue :: Player
	local attackSerial = attackSerialValue :: number
	local phase = phaseValue :: string
	local startedAt = startedAtValue :: number
	local endsAt = endsAtValue :: number
	if
		not isFinite(attackSerial)
		or attackSerial % 1 ~= 0
		or attackSerial < 0
		or VALID_PHASES[phase] ~= true
		or not isFinite(startedAt)
		or not isFinite(endsAt)
		or math.abs(Workspace:GetServerTimeNow() - startedAt) > ImpactFoundryConfig.MaximumBroadcastAge
		or endsAt < 0
		or endsAt - startedAt > ImpactFoundryConfig.MaximumReplicatedPhaseDuration
	then
		return nil, nil
	end
	return attacker, {
		phase = phase,
		attackSerial = attackSerial,
		startedAt = startedAt,
		endsAt = endsAt,
		predicted = false,
		predictionExpiresAt = 0,
	}
end

stateBroadcastRemote.OnClientEvent:Connect(function(...: unknown)
	local attacker, state = validateBroadcast(...)
	if attacker == nil or state == nil then
		return
	end
	setVisualState(attacker, state)
end)

local function getMotor(character: Model): Motor6D?
	local motor = character:FindFirstChild(ClassConfig.ImpactFoundryWeaponMotorName, true)
	return if motor ~= nil and motor:IsA("Motor6D") then motor else nil
end

local function getVisualPart(character: Model, name: string): BasePart?
	local part = character:FindFirstChild(name, true)
	return if part ~= nil and part:IsA("BasePart") then part else nil
end

local function getPhaseAlpha(state: VisualState, now: number): number
	local duration = state.endsAt - state.startedAt
	if duration <= 0 then
		return 1
	end
	return math.clamp((now - state.startedAt) / duration, 0, 1)
end

RunService.RenderStepped:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for targetPlayer, state in visualStates do
		local character = targetPlayer.Character
		if character == nil or character.Parent == nil or not isImpactFoundryActive(targetPlayer) then
			visualStates[targetPlayer] = nil
			if targetPlayer == player then
				ImpactFoundryClientState.Clear()
			end
			continue
		end
		if state.predicted and now > state.predictionExpiresAt then
			setVisualState(targetPlayer, {
				phase = "Idle",
				attackSerial = 0,
				startedAt = now,
				endsAt = 0,
				predicted = false,
				predictionExpiresAt = 0,
			})
			state = visualStates[targetPlayer]
		end
		local motor = getMotor(character)
		if motor == nil then
			continue
		end
		local alpha = getPhaseAlpha(state, now)
		local extension = 0
		if state.phase == "Windup" then
			extension = ImpactFoundryConfig.VisualWindupRetraction * (1 - math.cos(alpha * math.pi * 0.5))
		elseif state.phase == "Impact" then
			extension = -ImpactFoundryConfig.VisualImpactExtension * math.sin(alpha * math.pi)
		elseif state.phase == "Recovery" then
			extension = ImpactFoundryConfig.VisualRecoveryRetraction * (1 - alpha)
		end
		motor.Transform = CFrame.new(0, 0, extension)

		local glow = getVisualPart(character, "WindupGlow")
		if glow ~= nil then
			glow.Transparency = if state.phase == "Windup"
				then 0.72 - alpha * 0.42
				elseif state.phase == "Impact" then 0.18 else 0.86
		end
		for _, name in { "LeftRecoveryVent", "RightRecoveryVent" } do
			local vent = getVisualPart(character, name)
			if vent ~= nil then
				vent.Transparency = if state.phase == "Recovery" then 0.35 else 0.72
			end
		end
	end
end)

player:GetAttributeChangedSignal(EvolutionConfig.CurrentNodeAttribute):Connect(function()
	if not isImpactFoundryActive(player) then
		clearLocalState()
	end
end)
player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(function()
	if not isImpactFoundryActive(player) then
		clearLocalState()
	end
end)
player.CharacterAdded:Connect(clearLocalState)

for _, targetPlayer in Players:GetPlayers() do
	local phase = targetPlayer:GetAttribute("ImpactFoundryAttackPhase")
	local serial = targetPlayer:GetAttribute("ImpactFoundryAttackSerial")
	local startedAt = targetPlayer:GetAttribute("ImpactFoundryPhaseStartedAt")
	local endsAt = targetPlayer:GetAttribute("ImpactFoundryPhaseEndsAt")
	local attacker, state = validateBroadcast(targetPlayer, serial, phase, startedAt, endsAt)
	if attacker ~= nil and state ~= nil then
		setVisualState(attacker, state)
	end
end
