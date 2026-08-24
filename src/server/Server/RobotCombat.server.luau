--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(shared:WaitForChild("CombatConfig"))
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local ClassService = require(script.Parent:WaitForChild("ClassService"))
local BreakableObjectService = require(script.Parent:WaitForChild("BreakableObjectService"))
local CollisionGroupService = require(script.Parent:WaitForChild("CollisionGroupService"))

ProgressionService.Init()
ClassService.Init()
BreakableObjectService.Init()
CollisionGroupService.Init()

local ROBOT_CHASSIS_NAME = "RobotChassis"
local EQUIPPED_HAMMER_NAME = "EquippedHammer"
local HAMMER_ATTRIBUTE = "ScrapcoreEquippedHammer"
local WEAPON_TEMPLATE_NAME = "Hammer_Industrial_A"
local WEAPON_MOTOR_NAME = "WeaponMountMotor"
local FRONT_WEAPON_MOUNT_NAME = "FrontWeaponMount"
local TEST_DUMMY_NAME = "HammerTestDummy"
local KNOCKBACK_VELOCITY_ATTRIBUTE = "CombatKnockbackVelocity"
local KNOCKBACK_STARTED_AT_ATTRIBUTE = "CombatKnockbackStartedAt"
local KNOCKBACK_UNTIL_ATTRIBUTE = "CombatKnockbackUntil"

local impactDelay = CombatConfig.Windup + CombatConfig.ActiveTime * 0.5
local totalSwingTime = CombatConfig.Windup + CombatConfig.ActiveTime + CombatConfig.Recovery
if math.abs(totalSwingTime - CombatConfig.Cooldown) > 0.001 then
	error("CombatConfig cooldown must match windup + active time + recovery")
end

local assetLibrary = ServerStorage:WaitForChild("AssetLibrary")
local weaponTemplates = assetLibrary:WaitForChild("Weapons")
local weaponTemplateInstance = weaponTemplates:WaitForChild(WEAPON_TEMPLATE_NAME)
if not weaponTemplateInstance:IsA("Model") then
	error(string.format("ServerStorage.AssetLibrary.Weapons.%s must be a Model", WEAPON_TEMPLATE_NAME))
end
local weaponTemplate = weaponTemplateInstance :: Model

local remotesInstance = ReplicatedStorage:FindFirstChild("Remotes")
if remotesInstance == nil then
	remotesInstance = Instance.new("Folder")
	remotesInstance.Name = "Remotes"
	remotesInstance.Parent = ReplicatedStorage
elseif not remotesInstance:IsA("Folder") then
	error("ReplicatedStorage.Remotes must be a Folder")
end
local remotes = remotesInstance :: Folder

local function getOrCreateRemote(name: string): RemoteEvent
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

local attackRequestRemote = getOrCreateRemote("HammerAttackRequest")
local attackBroadcastRemote = getOrCreateRemote("HammerAttackBroadcast")

type CombatState = {
	nextAttackAt: number,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastSequence: number,
	attackSerial: number,
	acceptedAttacks: number,
	rejectedRequests: number,
}

local combatStates: {[Player]: CombatState} = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getRequiredBasePart(model: Model, name: string): BasePart
	local instance = model:FindFirstChild(name, true)
	if instance == nil or not instance:IsA("BasePart") then
		error(string.format("%s must contain BasePart %s", model:GetFullName(), name))
	end
	return instance
end

local function validateWeaponTemplate(template: Model)
	local weaponRoot = getRequiredBasePart(template, "WeaponRoot")
	getRequiredBasePart(template, "HammerHandle")
	getRequiredBasePart(template, "HammerHead")
	getRequiredBasePart(template, "HammerFace")
	if template.PrimaryPart ~= weaponRoot then
		error(string.format("%s.PrimaryPart must be WeaponRoot", template:GetFullName()))
	end

	local partCount = 0
	for _, descendant in template:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
			if descendant.Anchored or not descendant.Massless or descendant.CanCollide or descendant.CanTouch or descendant.CanQuery then
				error(string.format("%s contains unsafe hammer part %s", template:GetFullName(), descendant:GetFullName()))
			end
		end
	end
	if partCount ~= 4 then
		error(string.format("%s must contain exactly four BaseParts", template:GetFullName()))
	end
end

validateWeaponTemplate(weaponTemplate)

local function removeExistingHammer(chassis: Model)
	for _, child in chassis:GetChildren() do
		if child.Name == EQUIPPED_HAMMER_NAME or child:GetAttribute(HAMMER_ATTRIBUTE) == true then
			child:Destroy()
		end
	end

	local robotRoot = chassis:FindFirstChild("RobotRoot", true)
	if robotRoot ~= nil then
		local oldMotor = robotRoot:FindFirstChild(WEAPON_MOTOR_NAME)
		if oldMotor ~= nil then
			oldMotor:Destroy()
		end
	end
end

local function attachHammer(character: Model): Model?
	local chassisInstance = character:WaitForChild(ROBOT_CHASSIS_NAME, 10)
	if chassisInstance == nil or not chassisInstance:IsA("Model") or character.Parent == nil then
		return nil
	end
	local chassis = chassisInstance
	removeExistingHammer(chassis)

	local robotRoot = getRequiredBasePart(chassis, "RobotRoot")
	local mountInstance = robotRoot:FindFirstChild(FRONT_WEAPON_MOUNT_NAME)
	if mountInstance == nil or not mountInstance:IsA("Attachment") then
		warn(string.format("Unable to equip hammer: %s is missing FrontWeaponMount", character:GetFullName()))
		return nil
	end
	local mount = mountInstance

	local hammer = weaponTemplate:Clone()
	hammer.Name = EQUIPPED_HAMMER_NAME
	hammer:SetAttribute(HAMMER_ATTRIBUTE, true)
	local weaponRoot = getRequiredBasePart(hammer, "WeaponRoot")
	local sourceRootCFrame = weaponRoot.CFrame
	local mountWorldCFrame = mount.WorldCFrame

	for _, descendant in hammer:GetDescendants() do
		if descendant:IsA("BasePart") then
			local rootOffset = sourceRootCFrame:ToObjectSpace(descendant.CFrame)
			descendant.CFrame = mountWorldCFrame * rootOffset
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			CollisionGroupService.ApplyCharacterPart(descendant)
		end
	end

	hammer.PrimaryPart = weaponRoot
	hammer.Parent = chassis
	CollisionGroupService.ApplyCharacter(hammer)

	local mountMotor = Instance.new("Motor6D")
	mountMotor.Name = WEAPON_MOTOR_NAME
	mountMotor.Part0 = robotRoot
	mountMotor.Part1 = weaponRoot
	mountMotor.C0 = mount.CFrame
	mountMotor.C1 = CFrame.identity
	mountMotor.Transform = CFrame.identity
	mountMotor.Parent = robotRoot

	character:SetAttribute("HammerReady", true)
	return hammer
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
	raycastParams.FilterDescendantsInstances = {attacker}
	raycastParams.IgnoreWater = true
	local result = Workspace:Raycast(origin, direction, raycastParams)
	return result == nil or result.Instance:IsDescendantOf(target)
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

	local safeKnockbackSpeed = math.clamp(
		knockbackSpeed,
		0,
		CombatConfig.MaxHorizontalKnockbackSpeed
	)
	local direction = horizontal.Unit
	local knockbackVelocity = direction * safeKnockbackSpeed
	local startedAt = Workspace:GetServerTimeNow()
	target:SetAttribute(KNOCKBACK_VELOCITY_ATTRIBUTE, knockbackVelocity)
	target:SetAttribute(KNOCKBACK_STARTED_AT_ATTRIBUTE, startedAt)
	target:SetAttribute(KNOCKBACK_UNTIL_ATTRIBUTE, startedAt + CombatConfig.KnockbackDuration)

	local impulse = knockbackVelocity * targetRoot.AssemblyMass
	targetRoot:ApplyImpulse(impulse)
	task.delay(CombatConfig.KnockbackDuration, function()
		if
			target.Parent == nil
			or targetRoot.Parent == nil
			or target:GetAttribute("ScrapcoreCombatTarget") ~= true
		then
			return
		end
		local currentVelocity = targetRoot.AssemblyLinearVelocity
		targetRoot.AssemblyLinearVelocity = Vector3.new(0, currentVelocity.Y, 0)
	end)
end

local function resolveAttack(
	player: Player,
	expectedCharacter: Model,
	attackDamage: number,
	knockbackSpeed: number
)
	local character, humanoid, attackerRoot = getAliveCharacter(player)
	if character == nil or humanoid == nil or attackerRoot == nil or character ~= expectedCharacter then
		return
	end

	local chassis = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassis == nil or not chassis:IsA("Model") then
		return
	end
	local hammer = chassis:FindFirstChild(EQUIPPED_HAMMER_NAME)
	if hammer == nil or not hammer:IsA("Model") then
		return
	end

	local robotRoot = getRequiredBasePart(chassis, "RobotRoot")
	local mount = robotRoot:FindFirstChild(FRONT_WEAPON_MOUNT_NAME)
	local weaponRoot = hammer:FindFirstChild("WeaponRoot", true)
	local hammerHead = hammer:FindFirstChild("HammerHead", true)
	if
		mount == nil
		or not mount:IsA("Attachment")
		or weaponRoot == nil
		or not weaponRoot:IsA("BasePart")
		or hammerHead == nil
		or not hammerHead:IsA("BasePart")
	then
		return
	end

	local headOffset = weaponRoot.CFrame:ToObjectSpace(hammerHead.CFrame)
	local impactAngle = (CombatConfig.SwingWindupAngle + CombatConfig.SwingFollowThroughAngle) * 0.5
	local impactHeadCFrame = mount.WorldCFrame * CFrame.Angles(0, impactAngle, 0) * headOffset
	local hitOrigin = impactHeadCFrame.Position

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.MaxParts = CombatConfig.MaxQueryParts
	local nearbyParts = Workspace:GetPartBoundsInRadius(hitOrigin, CombatConfig.HitQueryRadius, overlapParams)

	local hitHumanoids: {[Humanoid]: boolean} = {}
	local hitBreakables: {[Model]: boolean} = {}
	for _, part in nearbyParts do
		local breakable = BreakableObjectService.GetBreakableFromPart(part)
		if breakable ~= nil then
			if hitBreakables[breakable] == true then
				continue
			end
			hitBreakables[breakable] = true

			local targetPart = breakable.PrimaryPart
			if targetPart == nil then
				continue
			end
			local targetOffset = targetPart.Position - attackerRoot.Position
			if
				targetOffset.Magnitude > CombatConfig.Range
				or math.abs(targetOffset.Y) > CombatConfig.MaxVerticalDifference
				or not hasLineOfSight(mount.WorldPosition, breakable, targetPart, character)
			then
				continue
			end

			BreakableObjectService.Damage(breakable, player, attackDamage)
			continue
		end

		local target, targetHumanoid, targetRoot = getTargetFromPart(part)
		if
			target == nil
			or targetHumanoid == nil
			or targetRoot == nil
			or target == character
			or targetHumanoid.Health <= 0
			or hitHumanoids[targetHumanoid] == true
		then
			continue
		end

		local targetOffset = targetRoot.Position - attackerRoot.Position
		if targetOffset.Magnitude > CombatConfig.Range or math.abs(targetOffset.Y) > CombatConfig.MaxVerticalDifference then
			continue
		end
		if not hasLineOfSight(mount.WorldPosition, target, targetRoot, character) then
			continue
		end

		hitHumanoids[targetHumanoid] = true
		local healthBefore = targetHumanoid.Health
		targetHumanoid:TakeDamage(attackDamage)
		applyHorizontalKnockback(attackerRoot, target, targetRoot, knockbackSpeed)
		if healthBefore > 0 and targetHumanoid.Health <= 0 then
			local targetPlayer = Players:GetPlayerFromCharacter(target)
			ProgressionService.AwardElimination(player, targetPlayer, targetHumanoid)
		end
	end
end

local function rejectRequest(player: Player, state: CombatState)
	state.rejectedRequests += 1
	player:SetAttribute("HammerRejectedRequestCount", state.rejectedRequests)
end

local function handleAttackRequest(player: Player, sequenceValue: unknown, ...: unknown)
	local state = combatStates[player]
	if state == nil then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now - state.requestWindowStartedAt >= CombatConfig.RequestRateWindow then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if state.requestsInWindow > CombatConfig.MaxRequestsPerWindow then
		rejectRequest(player, state)
		return
	end

	if select("#", ...) ~= 0 or typeof(sequenceValue) ~= "number" then
		rejectRequest(player, state)
		return
	end
	local sequence = sequenceValue :: number
	if
		not isFinite(sequence)
		or sequence % 1 ~= 0
		or sequence <= state.lastSequence
		or sequence > state.lastSequence + CombatConfig.MaxSequenceAdvance
	then
		rejectRequest(player, state)
		return
	end
	state.lastSequence = sequence

	local character, humanoid, root = getAliveCharacter(player)
	if character == nil or humanoid == nil or root == nil or character:GetAttribute("HammerReady") ~= true then
		rejectRequest(player, state)
		return
	end
	local classId = ClassService.GetClassId(player)
	if classId == ClassConfig.SpinnerClassId or classId == ClassConfig.RammerClassId then
		rejectRequest(player, state)
		return
	end
	if now < state.nextAttackAt then
		rejectRequest(player, state)
		return
	end

	local definition = ClassConfig.Definitions[classId]
	local combatModifiers = if definition ~= nil then definition.Combat else nil
	local cooldownPenalty = if combatModifiers ~= nil then combatModifiers.CooldownPenalty else 0
	local maximumCooldown = if combatModifiers ~= nil
		then math.min(combatModifiers.MaxCooldown, ClassConfig.MaxServerCooldown)
		else CombatConfig.Cooldown
	local cooldown = math.clamp(
		ProgressionService.GetHammerCooldown(player, CombatConfig.Cooldown) + cooldownPenalty,
		CombatConfig.MinCooldown,
		maximumCooldown
	)
	local damageBonus = if combatModifiers ~= nil then combatModifiers.DamageBonus else 0
	local maximumDamage = if combatModifiers ~= nil
		then math.min(combatModifiers.MaxDamage, CombatConfig.MaxDamage)
		else CombatConfig.MaxDamage
	local attackDamage = math.clamp(
		ProgressionService.GetHammerDamage(player, CombatConfig.Damage) + damageBonus,
		0,
		maximumDamage
	)
	local requestedKnockback = if combatModifiers ~= nil
		then combatModifiers.KnockbackSpeed
		else CombatConfig.HorizontalKnockbackSpeed
	local knockbackSpeed = math.clamp(requestedKnockback, 0, CombatConfig.MaxHorizontalKnockbackSpeed)

	state.nextAttackAt = now + cooldown
	state.attackSerial += 1
	state.acceptedAttacks += 1
	player:SetAttribute("HammerAcceptedAttackCount", state.acceptedAttacks)
	attackBroadcastRemote:FireAllClients(player, state.attackSerial, now)

	task.delay(impactDelay, function()
		resolveAttack(player, character, attackDamage, knockbackSpeed)
	end)
end

attackRequestRemote.OnServerEvent:Connect(handleAttackRequest)

local function configureCombatCharacter(character: Model)
	character:SetAttribute("HammerReady", false)
	attachHammer(character)
end

local function connectPlayer(player: Player)
	local now = Workspace:GetServerTimeNow()
	combatStates[player] = {
		nextAttackAt = 0,
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastSequence = 0,
		attackSerial = 0,
		acceptedAttacks = 0,
		rejectedRequests = 0,
	}
	player:SetAttribute("HammerAcceptedAttackCount", 0)
	player:SetAttribute("HammerRejectedRequestCount", 0)

	player.CharacterAdded:Connect(function(character: Model)
		task.spawn(configureCombatCharacter, character)
	end)
	if player.Character ~= nil then
		task.spawn(configureCombatCharacter, player.Character)
	end
end

Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(function(player: Player)
	combatStates[player] = nil
end)
for _, player in Players:GetPlayers() do
	connectPlayer(player)
end

local arena = Workspace:WaitForChild("GrayboxArena")
local initialDummyInstance = arena:WaitForChild(TEST_DUMMY_NAME)
if not initialDummyInstance:IsA("Model") then
	error(string.format("Workspace.GrayboxArena.%s must be a Model", TEST_DUMMY_NAME))
end
local initialDummy = initialDummyInstance :: Model
local dummyTemplate = initialDummy:Clone()
dummyTemplate.Parent = nil
local dummyResetCFrame = initialDummy:GetPivot()
local currentDummy: Model? = initialDummy

local function updateDummyLabel(dummy: Model, humanoid: Humanoid)
	local statusLabel = dummy:FindFirstChild("StatusLabel", true)
	if statusLabel ~= nil and statusLabel:IsA("TextLabel") then
		statusLabel.Text = string.format("HAMMER TEST DUMMY  %d / %d\nHold R nearby to reset", math.ceil(humanoid.Health), humanoid.MaxHealth)
	end
end

local function bindTestDummy(dummy: Model)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	local root = dummy:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		error(string.format("%s requires Humanoid and HumanoidRootPart", dummy:GetFullName()))
	end

	humanoid.PlatformStand = true
	updateDummyLabel(dummy, humanoid)
	humanoid.HealthChanged:Connect(function()
		updateDummyLabel(dummy, humanoid)
	end)

	local prompt = dummy:FindFirstChild("ResetPrompt", true)
	if prompt ~= nil and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(_player: Player)
			if currentDummy ~= dummy or humanoid.Health <= 0 then
				return
			end
			dummy:PivotTo(dummyResetCFrame)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			humanoid.Health = humanoid.MaxHealth
		end)
	end

	humanoid.Died:Connect(function()
		task.delay(CombatConfig.TestDummyResetDelay, function()
			if currentDummy ~= dummy then
				return
			end
			local replacement = dummyTemplate:Clone()
			replacement.Name = TEST_DUMMY_NAME
			replacement.Parent = arena
			replacement:PivotTo(dummyResetCFrame)
			currentDummy = replacement
			bindTestDummy(replacement)
			dummy:Destroy()
		end)
	end)
end

bindTestDummy(initialDummy)
