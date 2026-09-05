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
local MotionWorksConfig = require(shared:WaitForChild("MotionWorksConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local MotionWorksClientState = require(script.Parent:WaitForChild("MotionWorksClientState"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local intentRemote = remotes:WaitForChild("MotionWorksAttackIntent") :: RemoteEvent
local stateBroadcastRemote = remotes:WaitForChild("MotionWorksStateBroadcast") :: RemoteEvent

type VisualState = MotionWorksClientState.State

local VALID_PHASES = table.freeze({
	Idle = true,
	Spooling = true,
	Driven = true,
	Coastdown = true,
	Recovery = true,
})

local visualStates: {[Player]: VisualState} = {}
local rollerAngles: {[Model]: number} = {}
local trackedPlayers: {[Player]: {RBXScriptConnection}} = {}
local requestSequence = 0
local primaryHeld = false
local nextKeepaliveAt = 0

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isMotionWorksActive(targetPlayer: Player): boolean
	return targetPlayer:GetAttribute(SessionConfig.SessionAttribute) == SessionConfig.ArenaState
		and targetPlayer:GetAttribute(EvolutionConfig.CurrentNodeAttribute) == ClassConfig.MotionWorksNodeId
end

local function getUpgradeRank(attributeName: string): number
	local value = player:GetAttribute(attributeName)
	if typeof(value) ~= "number" or not isFinite(value) then return 0 end
	return math.clamp(math.floor(value), 0, ProgressionConfig.MaxUpgradeRank)
end

local function setVisualState(targetPlayer: Player, state: VisualState)
	visualStates[targetPlayer] = state
	if targetPlayer == player then
		MotionWorksClientState.Set(state)
		if not state.predicted and state.phase ~= "Spooling" and state.phase ~= "Driven" then
			primaryHeld = false
			nextKeepaliveAt = 0
		end
	end
end

local function clearLocalState()
	primaryHeld = false
	nextKeepaliveAt = 0
	visualStates[player] = nil
	MotionWorksClientState.Clear()
end

local function beginPredictedSpool()
	local character = player.Character
	if
		not isMotionWorksActive(player)
		or primaryHeld
		or character == nil
		or character.Parent == nil
		or character:GetAttribute("MotionWorksReady") ~= true
	then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then return end
	local authoritativePhase = player:GetAttribute("MotionWorksAttackPhase")
	if typeof(authoritativePhase) == "string" and authoritativePhase ~= "Idle" then return end
	local energyValue = player:GetAttribute("MotionWorksEnergy")
	local energy = if typeof(energyValue) == "number" and isFinite(energyValue)
		then math.clamp(energyValue, 0, MotionWorksConfig.MaximumEnergy)
		else MotionWorksConfig.MaximumEnergy
	if energy < MotionWorksConfig.MinimumStartEnergy then return end

	local now = Workspace:GetServerTimeNow()
	local spoolDuration = MotionWorksConfig.GetSpoolDuration(getUpgradeRank("AttackRateUpgradeLevel"))
	primaryHeld = true
	requestSequence += 1
	setVisualState(player, {
		phase = "Spooling",
		attackSerial = -requestSequence,
		startedAt = now,
		endsAt = now + spoolDuration,
		energy = energy,
		output = 0,
		predicted = true,
		predictionExpiresAt = now + MotionWorksConfig.PredictionReconcileTimeout,
	})
	intentRemote:FireServer("Start", requestSequence)
	nextKeepaliveAt = now + MotionWorksConfig.HoldKeepaliveInterval
end

local function stopPredicted(cancelOnly: boolean)
	if not primaryHeld then return end
	primaryHeld = false
	nextKeepaliveAt = 0
	if not isMotionWorksActive(player) then return end
	requestSequence += 1
	intentRemote:FireServer(if cancelOnly then "Cancel" else "Stop", requestSequence)
	local current = visualStates[player]
	if current == nil or (current.phase ~= "Spooling" and current.phase ~= "Driven") then return end
	local now = Workspace:GetServerTimeNow()
	setVisualState(player, {
		phase = "Coastdown",
		attackSerial = current.attackSerial,
		startedAt = now,
		endsAt = now + MotionWorksConfig.CoastdownDuration,
		energy = current.energy,
		output = current.output,
		predicted = true,
		predictionExpiresAt = now + MotionWorksConfig.PredictionReconcileTimeout,
	})
end

local function sendKeepalive()
	if not primaryHeld or not isMotionWorksActive(player) then return end
	local state = visualStates[player]
	if state == nil or (state.phase ~= "Spooling" and state.phase ~= "Driven") then return end
	local now = Workspace:GetServerTimeNow()
	if now < nextKeepaliveAt then return end
	nextKeepaliveAt = now + MotionWorksConfig.HoldKeepaliveInterval
	requestSequence += 1
	intentRemote:FireServer("KeepAlive", requestSequence)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	beginPredictedSpool()
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then stopPredicted(false) end
end)

UserInputService.WindowFocusReleased:Connect(function()
	stopPredicted(true)
end)

local function validateState(
	attackerValue: unknown,
	serialValue: unknown,
	phaseValue: unknown,
	startedAtValue: unknown,
	endsAtValue: unknown,
	energyValue: unknown,
	outputValue: unknown
): (Player?, VisualState?)
	if
		typeof(attackerValue) ~= "Instance"
		or not (attackerValue :: Instance):IsA("Player")
		or typeof(serialValue) ~= "number"
		or typeof(phaseValue) ~= "string"
		or typeof(startedAtValue) ~= "number"
		or typeof(endsAtValue) ~= "number"
		or typeof(energyValue) ~= "number"
		or typeof(outputValue) ~= "number"
	then
		return nil, nil
	end
	local attacker = attackerValue :: Player
	local serial = serialValue :: number
	local phase = phaseValue :: string
	local startedAt = startedAtValue :: number
	local endsAt = endsAtValue :: number
	local energy = energyValue :: number
	local output = outputValue :: number
	if
		VALID_PHASES[phase] ~= true
		or not isFinite(serial)
		or serial % 1 ~= 0
		or serial < 0
		or not isFinite(startedAt)
		or not isFinite(endsAt)
		or not isFinite(energy)
		or not isFinite(output)
		or energy < 0
		or energy > MotionWorksConfig.MaximumEnergy + 0.01
		or output < 0
		or output > 1.01
		or math.abs(Workspace:GetServerTimeNow() - startedAt) > MotionWorksConfig.MaximumBroadcastAge
		or (endsAt > 0 and endsAt - startedAt > MotionWorksConfig.MaximumReplicatedPhaseDuration)
	then
		return nil, nil
	end
	return attacker, {
		phase = phase,
		attackSerial = serial,
		startedAt = startedAt,
		endsAt = endsAt,
		energy = energy,
		output = output,
		predicted = false,
		predictionExpiresAt = 0,
	}
end

stateBroadcastRemote.OnClientEvent:Connect(function(...: unknown)
	local attacker, state = validateState(...)
	if attacker ~= nil and state ~= nil then setVisualState(attacker, state) end
end)

local function syncFromAttributes(targetPlayer: Player)
	if not isMotionWorksActive(targetPlayer) then
		visualStates[targetPlayer] = nil
		if targetPlayer == player then MotionWorksClientState.Clear() end
		return
	end
	local attacker, state = validateState(
		targetPlayer,
		targetPlayer:GetAttribute("MotionWorksAttackSerial"),
		targetPlayer:GetAttribute("MotionWorksAttackPhase"),
		targetPlayer:GetAttribute("MotionWorksPhaseStartedAt"),
		targetPlayer:GetAttribute("MotionWorksPhaseEndsAt"),
		targetPlayer:GetAttribute("MotionWorksEnergy"),
		targetPlayer:GetAttribute("MotionWorksOutput")
	)
	if attacker ~= nil and state ~= nil then setVisualState(attacker, state) end
end

local function disconnectPlayer(targetPlayer: Player)
	local connections = trackedPlayers[targetPlayer]
	if connections ~= nil then
		for _, connection in connections do connection:Disconnect() end
	end
	trackedPlayers[targetPlayer] = nil
	local character = targetPlayer.Character
	if character ~= nil then rollerAngles[character] = nil end
	visualStates[targetPlayer] = nil
end

local function connectPlayer(targetPlayer: Player)
	if trackedPlayers[targetPlayer] ~= nil then return end
	local connections: {RBXScriptConnection} = {}
	trackedPlayers[targetPlayer] = connections
	for _, attributeName in {
		EvolutionConfig.CurrentNodeAttribute,
		SessionConfig.SessionAttribute,
		"MotionWorksAttackSerial",
		"MotionWorksAttackPhase",
		"MotionWorksPhaseStartedAt",
		"MotionWorksPhaseEndsAt",
		"MotionWorksEnergy",
		"MotionWorksOutput",
	} do
		table.insert(connections, targetPlayer:GetAttributeChangedSignal(attributeName):Connect(function()
			syncFromAttributes(targetPlayer)
		end))
	end
	table.insert(connections, targetPlayer.CharacterAdded:Connect(function()
		task.defer(syncFromAttributes, targetPlayer)
	end))
	table.insert(connections, targetPlayer.CharacterRemoving:Connect(function(character: Model)
		rollerAngles[character] = nil
		visualStates[targetPlayer] = nil
		if targetPlayer == player then clearLocalState() end
	end))
	task.defer(syncFromAttributes, targetPlayer)
end

Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(disconnectPlayer)
for _, targetPlayer in Players:GetPlayers() do connectPlayer(targetPlayer) end

local function getMotor(character: Model, name: string): Motor6D?
	local motor = character:FindFirstChild(name, true)
	return if motor ~= nil and motor:IsA("Motor6D") then motor else nil
end

local function getPart(character: Model, name: string): BasePart?
	local part = character:FindFirstChild(name, true)
	return if part ~= nil and part:IsA("BasePart") then part else nil
end

RunService.RenderStepped:Connect(function(deltaTime: number)
	sendKeepalive()
	local now = Workspace:GetServerTimeNow()
	for targetPlayer, state in visualStates do
		local character = targetPlayer.Character
		if character == nil or character.Parent == nil or not isMotionWorksActive(targetPlayer) then
			visualStates[targetPlayer] = nil
			continue
		end
		if state.predicted and now >= state.predictionExpiresAt then
			visualStates[targetPlayer] = nil
			if targetPlayer == player then MotionWorksClientState.Clear() end
			continue
		end
		if state.predicted and state.phase == "Spooling" and now >= state.endsAt then
			state.phase = "Driven"
			state.startedAt = now
			state.endsAt = 0
		end

		local output = math.clamp(state.output, 0, 1)
		if state.phase == "Spooling" then
			local duration = math.max(state.endsAt - state.startedAt, 0.001)
			output = math.clamp((now - state.startedAt) / duration, 0, 1) * 0.22
		elseif state.phase == "Driven" and state.predicted then
			output = math.clamp((now - state.startedAt) / MotionWorksConfig.OutputRampDuration, 0, 1)
		elseif state.phase == "Coastdown" then
			local duration = math.max(state.endsAt - state.startedAt, 0.001)
			output *= math.clamp((state.endsAt - now) / duration, 0, 1)
		end
		if state.predicted then state.output = output end

		local carriageMotor = getMotor(character, ClassConfig.MotionWorksWeaponMotorName)
		if carriageMotor ~= nil then
			carriageMotor.Transform = CFrame.new(0, 0, -MotionWorksConfig.VisualCarriageTravel * output)
		end
		local angularSpeed = if state.phase == "Driven"
			then MotionWorksConfig.ActiveRollerAngularSpeed * math.max(output, 0.2)
			elseif state.phase == "Coastdown" then MotionWorksConfig.CoastRollerAngularSpeed * output
			else MotionWorksConfig.CoastRollerAngularSpeed * output * 0.35
		local angle = ((rollerAngles[character] or 0) + angularSpeed * deltaTime) % (math.pi * 2)
		rollerAngles[character] = angle
		for _, motorName in { ClassConfig.MotionWorksFrontRollerMotorName, ClassConfig.MotionWorksRearRollerMotorName } do
			local motor = getMotor(character, motorName)
			if motor ~= nil then motor.Transform = CFrame.Angles(angle, 0, 0) end
		end
		local indicator = getPart(character, "MotionWorksEnergyIndicator")
		if indicator ~= nil then
			indicator.Size = Vector3.new(0.25 + 2.15 * state.energy / MotionWorksConfig.MaximumEnergy, 0.12, 0.22)
			indicator.Transparency = if state.phase == "Driven" then 0.10 else 0.42
		end
		local streak = getPart(character, "MotionWorksDriveGlow")
		if streak ~= nil then streak.Transparency = if state.phase == "Driven" then 0.72 - 0.50 * output else 1 end
	end
end)

player:GetAttributeChangedSignal(EvolutionConfig.CurrentNodeAttribute):Connect(function()
	if not isMotionWorksActive(player) then clearLocalState() end
end)
player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(function()
	if not isMotionWorksActive(player) then clearLocalState() end
end)
script.Destroying:Connect(function()
	if primaryHeld then stopPredicted(true) end
	for targetPlayer in trackedPlayers do disconnectPlayer(targetPlayer) end
	table.clear(visualStates)
	table.clear(rollerAngles)
	MotionWorksClientState.Clear()
end)
