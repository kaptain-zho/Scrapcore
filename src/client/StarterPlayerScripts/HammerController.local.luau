--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(shared:WaitForChild("CombatConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local attackRequestRemote = remotes:WaitForChild("HammerAttackRequest") :: RemoteEvent
local attackBroadcastRemote = remotes:WaitForChild("HammerAttackBroadcast") :: RemoteEvent

local WEAPON_MOTOR_NAME = "WeaponMountMotor"

type SwingState = {
	startedAt: number,
	attackId: number,
	predicted: boolean,
}

local activeSwings: {[Model]: SwingState} = {}
local requestSequence = 0
local nextLocalAttackAt = 0

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getCurrentCooldown(): number
	local rankValue = player:GetAttribute("AttackRateUpgradeLevel")
	local rank = if typeof(rankValue) == "number" and isFinite(rankValue)
		then math.clamp(math.floor(rankValue), 0, ProgressionConfig.MaxUpgradeRank)
		else 0
	return math.clamp(
		CombatConfig.Cooldown * ProgressionConfig.GetAttackRateMultiplier(rank),
		CombatConfig.MinCooldown,
		CombatConfig.Cooldown
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

local function getSwingAngle(elapsed: number): number?
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

	local recoveryElapsed = activeElapsed - CombatConfig.ActiveTime
	if recoveryElapsed < CombatConfig.Recovery then
		local alpha = recoveryElapsed / CombatConfig.Recovery
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

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	requestAttack()
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

player.CharacterAdded:Connect(function()
	nextLocalAttackAt = 0
end)

RunService.PreRender:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for character, swing in activeSwings do
		if character.Parent == nil then
			activeSwings[character] = nil
			continue
		end

		local motor = getWeaponMotor(character)
		local angle = getSwingAngle(now - swing.startedAt)
		if angle == nil then
			if motor ~= nil then
				motor.C0 = getRestC0(motor)
			end
			activeSwings[character] = nil
		elseif motor ~= nil then
			motor.C0 = getRestC0(motor) * CFrame.Angles(0, angle, 0)
		end
	end
end)
