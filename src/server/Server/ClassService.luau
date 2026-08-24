--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local CollisionGroupService = require(script.Parent:WaitForChild("CollisionGroupService"))
local PlayerSessionService = require(script.Parent:WaitForChild("PlayerSessionService"))

type CombatModifiers = {
	DamageBonus: number,
	MaxDamage: number,
	KnockbackSpeed: number,
	CooldownPenalty: number,
	MaxCooldown: number,
}

type ClassDefinition = {
	DisplayName: string,
	Tier: number,
	Enabled: boolean,
	Status: string,
	Role: string,
	Tradeoff: string,
	Combat: CombatModifiers?,
}

type PlayerClassState = {
	classId: string,
	selectedRunSerial: number,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	acceptedRequests: number,
	rejectedRequests: number,
	writingAttributes: boolean,
	characterAddedConnection: RBXScriptConnection?,
	diedConnection: RBXScriptConnection?,
	levelChangedConnection: RBXScriptConnection?,
	classAttributeConnection: RBXScriptConnection?,
	eligibilityAttributeConnection: RBXScriptConnection?,
	selectedAttributeConnection: RBXScriptConnection?,
	sessionAttributeConnection: RBXScriptConnection?,
}

local ROBOT_CHASSIS_NAME = "RobotChassis"
local EQUIPPED_HAMMER_NAME = "EquippedHammer"
local HAMMER_ATTRIBUTE = "ScrapcoreEquippedHammer"
local HAMMER_MOTOR_NAME = "WeaponMountMotor"
local CLASS_VISUAL_MODEL_NAME = "ClassEvolutionVisuals"
local SPINNER_ATTRIBUTE = "ScrapcoreEquippedSpinner"
local RAMMER_ATTRIBUTE = "ScrapcoreEquippedRammer"
local FRONT_WEAPON_MOUNT_NAME = "FrontWeaponMount"
local SPINNER_HIT_ORIGIN_NAME = "SpinnerHitOrigin"
local RAMMER_HIT_ORIGIN_NAME = "RammerHitOrigin"
local STRIKER_CLASS_ID = ClassConfig.StrikerClassId
local SPINNER_CLASS_ID = ClassConfig.SpinnerClassId
local RAMMER_CLASS_ID = ClassConfig.RammerClassId

local classDefinitions = ClassConfig.Definitions :: {[string]: ClassDefinition}
local playerStates: {[Player]: PlayerClassState} = {}
local initialized = false
local classRequestRemote: RemoteEvent? = nil

local ClassService = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getAliveHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character == nil or character.Parent == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

local function getStrictRunLevel(player: Player): number?
	local value = player:GetAttribute("RunLevel")
	if
		typeof(value) ~= "number"
		or not isFinite(value)
		or value % 1 ~= 0
		or value < 1
		or value > ProgressionConfig.LevelCap
	then
		return nil
	end
	return value
end

local function setReplicatedState(player: Player, state: PlayerClassState, eligible: boolean)
	state.writingAttributes = true
	player:SetAttribute(ClassConfig.ClassAttribute, state.classId)
	player:SetAttribute(ClassConfig.EligibilityAttribute, eligible)
	player:SetAttribute(ClassConfig.SelectedAttribute, state.classId ~= ClassConfig.BaseClassId)
	state.writingAttributes = false
end

local function currentClassId(player: Player, state: PlayerClassState): string
	if not PlayerSessionService.IsArena(player) or state.classId == ClassConfig.BaseClassId then
		return ClassConfig.BaseClassId
	end
	local runSerial = ProgressionService.GetRunSerial(player)
	if state.selectedRunSerial ~= runSerial or not ProgressionService.IsRunActive(player, runSerial) then
		return ClassConfig.BaseClassId
	end
	return state.classId
end

local function updateEligibility(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	if state.classId ~= ClassConfig.BaseClassId and currentClassId(player, state) == ClassConfig.BaseClassId then
		state.classId = ClassConfig.BaseClassId
		state.selectedRunSerial = -1
	end
	local runLevel = getStrictRunLevel(player)
	local runSerial = ProgressionService.GetRunSerial(player)
	local eligible = state.classId == ClassConfig.BaseClassId
		and PlayerSessionService.IsArena(player)
		and runLevel ~= nil
		and runLevel >= ClassConfig.Level8Threshold
		and ProgressionService.IsRunActive(player, runSerial)
	setReplicatedState(player, state, eligible)
end

local function enforceReplicatedState(player: Player)
	local state = playerStates[player]
	if state == nil or state.writingAttributes then
		return
	end
	updateEligibility(player)
end

local function removeSpinner(chassis: Model)
	for _, child in chassis:GetChildren() do
		if child.Name == ClassConfig.EquippedSpinnerName or child:GetAttribute(SPINNER_ATTRIBUTE) == true then
			child:Destroy()
		end
	end

	local robotRoot = chassis:FindFirstChild("RobotRoot", true)
	if robotRoot ~= nil then
		local spinnerMotor = robotRoot:FindFirstChild(ClassConfig.SpinnerWeaponMotorName)
		if spinnerMotor ~= nil then
			spinnerMotor:Destroy()
		end
	end

	local character = chassis.Parent
	if character ~= nil and character:IsA("Model") then
		character:SetAttribute("SpinnerReady", false)
	end
end

local function removeRammer(chassis: Model)
	for _, child in chassis:GetChildren() do
		if child.Name == ClassConfig.EquippedRammerName or child:GetAttribute(RAMMER_ATTRIBUTE) == true then
			child:Destroy()
		end
	end

	local robotRoot = chassis:FindFirstChild("RobotRoot", true)
	if robotRoot ~= nil then
		local rammerMotor = robotRoot:FindFirstChild(ClassConfig.RammerWeaponMotorName)
		if rammerMotor ~= nil then
			rammerMotor:Destroy()
		end
	end

	local character = chassis.Parent
	if character ~= nil and character:IsA("Model") then
		character:SetAttribute("RammerReady", false)
	end
end

local function removeHammer(chassis: Model)
	for _, child in chassis:GetChildren() do
		if child.Name == EQUIPPED_HAMMER_NAME or child:GetAttribute(HAMMER_ATTRIBUTE) == true then
			child:Destroy()
		end
	end

	local robotRoot = chassis:FindFirstChild("RobotRoot", true)
	if robotRoot ~= nil then
		local hammerMotor = robotRoot:FindFirstChild(HAMMER_MOTOR_NAME)
		if hammerMotor ~= nil then
			hammerMotor:Destroy()
		end
	end

	local character = chassis.Parent
	if character ~= nil and character:IsA("Model") then
		character:SetAttribute("HammerReady", false)
	end
end

local function restoreStandardLoadout(chassis: Model)
	removeSpinner(chassis)
	removeRammer(chassis)
	local hammer = chassis:FindFirstChild(EQUIPPED_HAMMER_NAME)
	if hammer ~= nil and hammer:IsA("Model") then
		local hammerHead = hammer:FindFirstChild("HammerHead", true)
		if hammerHead ~= nil and hammerHead:IsA("BasePart") then
			hammerHead.Size = ClassConfig.StandardHammerHeadSize
		end
		local hammerFace = hammer:FindFirstChild("HammerFace", true)
		if hammerFace ~= nil and hammerFace:IsA("BasePart") then
			hammerFace.Size = ClassConfig.StandardHammerFaceSize
		end
	end

	local oldVisuals = chassis:FindFirstChild(CLASS_VISUAL_MODEL_NAME)
	if oldVisuals ~= nil then
		oldVisuals:Destroy()
	end
end

local function clearAllLoadout(chassis: Model)
	removeSpinner(chassis)
	removeRammer(chassis)
	removeHammer(chassis)
	local oldVisuals = chassis:FindFirstChild(CLASS_VISUAL_MODEL_NAME)
	if oldVisuals ~= nil then
		oldVisuals:Destroy()
	end
end

local function createWeldedVisual(
	parent: Model,
	name: string,
	weldTo: BasePart,
	localCFrame: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = weldTo.CFrame * localCFrame
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Parent = parent
	CollisionGroupService.ApplyCharacterPart(part)

	local weld = Instance.new("WeldConstraint")
	weld.Name = name .. "Weld"
	weld.Part0 = weldTo
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function applyStrikerVisuals(character: Model): boolean
	local chassisInstance = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassisInstance == nil or not chassisInstance:IsA("Model") then
		return false
	end
	local chassis = chassisInstance
	local robotRoot = chassis:FindFirstChild("RobotRoot", true)
	local hammer = chassis:FindFirstChild(EQUIPPED_HAMMER_NAME)
	if robotRoot == nil or not robotRoot:IsA("BasePart") or hammer == nil or not hammer:IsA("Model") then
		return false
	end

	restoreStandardLoadout(chassis)
	local hammerHead = hammer:FindFirstChild("HammerHead", true)
	local hammerFace = hammer:FindFirstChild("HammerFace", true)
	if
		hammerHead == nil
		or not hammerHead:IsA("BasePart")
		or hammerFace == nil
		or not hammerFace:IsA("BasePart")
	then
		return false
	end
	hammerHead.Size = ClassConfig.StrikerHammerHeadSize
	hammerFace.Size = ClassConfig.StrikerHammerFaceSize

	local visuals = Instance.new("Model")
	visuals.Name = CLASS_VISUAL_MODEL_NAME
	visuals:SetAttribute("ClassId", STRIKER_CLASS_ID)
	visuals:SetAttribute("OriginalScrapcoreVisual", true)
	visuals.Parent = chassis

	createWeldedVisual(
		visuals,
		"StrikerMountBrace",
		robotRoot,
		CFrame.new(0, 0.64, -3.02),
		Vector3.new(2.8, 0.55, 0.72),
		Color3.fromRGB(48, 56, 65),
		Enum.Material.Metal
	)
	createWeldedVisual(
		visuals,
		"StrikerIdentificationAccent",
		robotRoot,
		CFrame.new(0, 0.98, -3.40),
		Vector3.new(0.9, 0.16, 0.38),
		Color3.fromRGB(244, 154, 45),
		Enum.Material.SmoothPlastic
	)
	return true
end

local function createSpinnerVisualPart(
	parent: Model,
	name: string,
	spinnerRoot: BasePart,
	localCFrame: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number?,
	shape: Enum.PartType?
): BasePart
	local part = createWeldedVisual(parent, name, spinnerRoot, localCFrame, size, color, material)
	part.Transparency = transparency or 0
	part.Shape = shape or Enum.PartType.Block
	return part
end

local function applySpinnerVisuals(character: Model): boolean
	local chassisInstance = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassisInstance == nil or not chassisInstance:IsA("Model") then
		return false
	end
	local chassis = chassisInstance
	local robotRoot = chassis:FindFirstChild("RobotRoot", true)
	if robotRoot == nil or not robotRoot:IsA("BasePart") then
		return false
	end
	local mountInstance = robotRoot:FindFirstChild(FRONT_WEAPON_MOUNT_NAME)
	if mountInstance == nil or not mountInstance:IsA("Attachment") then
		return false
	end

	restoreStandardLoadout(chassis)
	removeHammer(chassis)

	local classVisuals = Instance.new("Model")
	classVisuals.Name = CLASS_VISUAL_MODEL_NAME
	classVisuals:SetAttribute("ClassId", SPINNER_CLASS_ID)
	classVisuals:SetAttribute("OriginalScrapcoreVisual", true)
	classVisuals.Parent = chassis
	createWeldedVisual(
		classVisuals,
		"SpinnerFrontBrace",
		robotRoot,
		CFrame.new(0, 0.48, -3.25),
		Vector3.new(3.4, 0.48, 0.75),
		Color3.fromRGB(52, 59, 69),
		Enum.Material.Metal
	)
	createWeldedVisual(
		classVisuals,
		"SpinnerIdentificationAccent",
		robotRoot,
		CFrame.new(0, 0.86, -3.42),
		Vector3.new(1.25, 0.14, 0.36),
		ClassConfig.SpinnerAccentColor,
		Enum.Material.SmoothPlastic
	)

	local spinner = Instance.new("Model")
	spinner.Name = ClassConfig.EquippedSpinnerName
	spinner:SetAttribute(SPINNER_ATTRIBUTE, true)
	spinner:SetAttribute("ClassId", SPINNER_CLASS_ID)
	spinner:SetAttribute("OriginalScrapcoreVisual", true)

	local spinnerRoot = Instance.new("Part")
	spinnerRoot.Name = "SpinnerRoot"
	spinnerRoot.Size = Vector3.new(0.2, 0.2, 0.2)
	spinnerRoot.CFrame = mountInstance.WorldCFrame
	spinnerRoot.Transparency = 1
	spinnerRoot.Anchored = false
	spinnerRoot.Massless = true
	spinnerRoot.CanCollide = false
	spinnerRoot.CanTouch = false
	spinnerRoot.CanQuery = false
	spinnerRoot.CastShadow = false
	spinnerRoot.Parent = spinner
	CollisionGroupService.ApplyCharacterPart(spinnerRoot)

	local hitOrigin = Instance.new("Attachment")
	hitOrigin.Name = SPINNER_HIT_ORIGIN_NAME
	hitOrigin.CFrame = CFrame.new(0, -0.18, -0.48)
	hitOrigin.Parent = spinnerRoot

	local discCFrame = CFrame.new(0, -0.18, -0.48) * CFrame.Angles(0, 0, math.rad(90))
	createSpinnerVisualPart(
		spinner,
		"FlywheelCore",
		spinnerRoot,
		discCFrame,
		Vector3.new(0.34, 4.2, 4.2),
		Color3.fromRGB(57, 64, 73),
		Enum.Material.Metal,
		0,
		Enum.PartType.Cylinder
	)
	createSpinnerVisualPart(
		spinner,
		"SpinnerMotionBlur",
		spinnerRoot,
		discCFrame,
		Vector3.new(0.12, 4.65, 4.65),
		ClassConfig.SpinnerAccentColor,
		Enum.Material.Neon,
		0.82,
		Enum.PartType.Cylinder
	)

	local toothDefinitions = {
		{ angle = math.rad(4), distance = 2.25, size = Vector3.new(0.78, 0.5, 1.15) },
		{ angle = math.rad(127), distance = 2.18, size = Vector3.new(0.62, 0.46, 0.92) },
		{ angle = math.rad(244), distance = 2.30, size = Vector3.new(0.92, 0.54, 1.02) },
	}
	for index, tooth in toothDefinitions do
		local toothCFrame = CFrame.new(0, -0.12, -0.48)
			* CFrame.Angles(0, tooth.angle, 0)
			* CFrame.new(0, 0, -tooth.distance)
		createSpinnerVisualPart(
			spinner,
			"AsymmetricTooth" .. index,
			spinnerRoot,
			toothCFrame,
			tooth.size,
			if index == 2 then ClassConfig.SpinnerAccentColor else Color3.fromRGB(86, 93, 102),
			Enum.Material.Metal,
			0,
			Enum.PartType.Block
		)
	end

	spinner.PrimaryPart = spinnerRoot
	spinner.Parent = chassis

	local spinnerMotor = Instance.new("Motor6D")
	spinnerMotor.Name = ClassConfig.SpinnerWeaponMotorName
	spinnerMotor.Part0 = robotRoot
	spinnerMotor.Part1 = spinnerRoot
	spinnerMotor.C0 = mountInstance.CFrame
	spinnerMotor.C1 = CFrame.identity
	spinnerMotor.Transform = CFrame.identity
	spinnerMotor.Parent = robotRoot

	character:SetAttribute("SpinnerReady", true)
	return true
end

local function createRammerVisualPart(
	parent: Model,
	className: "Part" | "WedgePart",
	name: string,
	rammerRoot: BasePart,
	localCFrame: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number?
): BasePart
	local part = if className == "WedgePart" then Instance.new("WedgePart") else Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = rammerRoot.CFrame * localCFrame
	part.Color = color
	part.Material = material
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Parent = parent
	CollisionGroupService.ApplyCharacterPart(part)

	local weld = Instance.new("WeldConstraint")
	weld.Name = name .. "Weld"
	weld.Part0 = rammerRoot
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function applyRammerVisuals(character: Model): boolean
	local chassisInstance = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassisInstance == nil or not chassisInstance:IsA("Model") then
		return false
	end
	local chassis = chassisInstance
	local robotRoot = chassis:FindFirstChild("RobotRoot", true)
	if robotRoot == nil or not robotRoot:IsA("BasePart") then
		return false
	end
	local mountInstance = robotRoot:FindFirstChild(FRONT_WEAPON_MOUNT_NAME)
	if mountInstance == nil or not mountInstance:IsA("Attachment") then
		return false
	end

	restoreStandardLoadout(chassis)
	removeHammer(chassis)

	local classVisuals = Instance.new("Model")
	classVisuals.Name = CLASS_VISUAL_MODEL_NAME
	classVisuals:SetAttribute("ClassId", RAMMER_CLASS_ID)
	classVisuals:SetAttribute("OriginalScrapcoreVisual", true)
	classVisuals.Parent = chassis
	createWeldedVisual(
		classVisuals,
		"RammerFrontBrace",
		robotRoot,
		CFrame.new(0, 0.42, -3.28),
		Vector3.new(4.4, 0.52, 0.78),
		Color3.fromRGB(50, 57, 66),
		Enum.Material.Metal
	)
	createWeldedVisual(
		classVisuals,
		"RammerIdentificationAccent",
		robotRoot,
		CFrame.new(0.85, 0.84, -3.47),
		Vector3.new(1.25, 0.14, 0.42),
		ClassConfig.RammerAccentColor,
		Enum.Material.SmoothPlastic
	)

	local rammer = Instance.new("Model")
	rammer.Name = ClassConfig.EquippedRammerName
	rammer:SetAttribute(RAMMER_ATTRIBUTE, true)
	rammer:SetAttribute("ClassId", RAMMER_CLASS_ID)
	rammer:SetAttribute("OriginalScrapcoreVisual", true)

	local rammerRoot = Instance.new("Part")
	rammerRoot.Name = "RammerRoot"
	rammerRoot.Size = Vector3.new(0.2, 0.2, 0.2)
	rammerRoot.CFrame = mountInstance.WorldCFrame
	rammerRoot.Transparency = 1
	rammerRoot.Anchored = false
	rammerRoot.Massless = true
	rammerRoot.CanCollide = false
	rammerRoot.CanTouch = false
	rammerRoot.CanQuery = false
	rammerRoot.CastShadow = false
	rammerRoot.Parent = rammer
	CollisionGroupService.ApplyCharacterPart(rammerRoot)

	local hitOrigin = Instance.new("Attachment")
	hitOrigin.Name = RAMMER_HIT_ORIGIN_NAME
	hitOrigin.CFrame = CFrame.new(0, -0.08, -2.4)
	hitOrigin.Parent = rammerRoot

	createRammerVisualPart(
		rammer,
		"WedgePart",
		"LowImpactWedge",
		rammerRoot,
		CFrame.new(0, -0.28, -1.42) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(4.8, 0.76, 2.8),
		Color3.fromRGB(58, 65, 74),
		Enum.Material.Metal,
		0
	)
	createRammerVisualPart(
		rammer,
		"Part",
		"LeftImpactRail",
		rammerRoot,
		CFrame.new(-1.55, -0.08, -1.95) * CFrame.Angles(0, math.rad(-5), 0),
		Vector3.new(0.48, 0.48, 3.55),
		Color3.fromRGB(92, 99, 106),
		Enum.Material.Metal,
		0
	)
	createRammerVisualPart(
		rammer,
		"Part",
		"RightImpactRail",
		rammerRoot,
		CFrame.new(1.32, -0.02, -1.72) * CFrame.Angles(0, math.rad(7), 0),
		Vector3.new(0.62, 0.56, 3.15),
		Color3.fromRGB(78, 86, 96),
		Enum.Material.Metal,
		0
	)
	createRammerVisualPart(
		rammer,
		"Part",
		"RammerChargeIndicator",
		rammerRoot,
		CFrame.new(0, 0.27, -0.82),
		Vector3.new(0.32, 0.12, 1.4),
		ClassConfig.RammerAccentColor,
		Enum.Material.Neon,
		0.55
	)
	createRammerVisualPart(
		rammer,
		"Part",
		"RammerDashGlow",
		rammerRoot,
		CFrame.new(0, 0.06, 0.5),
		Vector3.new(2.2, 0.08, 2.4),
		ClassConfig.RammerAccentColor,
		Enum.Material.Neon,
		1
	)

	rammer.PrimaryPart = rammerRoot
	rammer.Parent = chassis

	local rammerMotor = Instance.new("Motor6D")
	rammerMotor.Name = ClassConfig.RammerWeaponMotorName
	rammerMotor.Part0 = robotRoot
	rammerMotor.Part1 = rammerRoot
	rammerMotor.C0 = mountInstance.CFrame
	rammerMotor.C1 = CFrame.identity
	rammerMotor.Transform = CFrame.identity
	rammerMotor.Parent = robotRoot

	character:SetAttribute("RammerReady", true)
	return true
end

local function applyCurrentVisuals(player: Player)
	local state = playerStates[player]
	local character = player.Character
	if state == nil or character == nil or character.Parent == nil then
		return
	end
	local chassisInstance = character:FindFirstChild(ROBOT_CHASSIS_NAME)
	if chassisInstance ~= nil and chassisInstance:IsA("Model") and not PlayerSessionService.IsArena(player) then
		clearAllLoadout(chassisInstance)
		return
	end
	if chassisInstance ~= nil and chassisInstance:IsA("Model") and currentClassId(player, state) == ClassConfig.BaseClassId then
		restoreStandardLoadout(chassisInstance)
		return
	end
	local classId = currentClassId(player, state)
	if classId ~= STRIKER_CLASS_ID and classId ~= SPINNER_CLASS_ID and classId ~= RAMMER_CLASS_ID then
		return
	end

	for _ = 1, 40 do
		if player.Character ~= character or character.Parent == nil then
			return
		end
		local applied = if classId == STRIKER_CLASS_ID
			then applyStrikerVisuals(character)
			elseif classId == SPINNER_CLASS_ID
			then applySpinnerVisuals(character)
			else applyRammerVisuals(character)
		if applied then
			return
		end
		task.wait(0.05)
	end
	warn(string.format("Unable to apply %s visuals for %s", classId, player.Name))
end

local function resetClass(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	state.classId = ClassConfig.BaseClassId
	state.selectedRunSerial = -1
	setReplicatedState(player, state, false)
	task.spawn(applyCurrentVisuals, player)
end

local function rejectRequest(player: Player, state: PlayerClassState)
	state.rejectedRequests += 1
	player:SetAttribute("ClassRejectedRequestCount", state.rejectedRequests)
end

local function handleClassRequest(player: Player, classValue: unknown, ...: unknown)
	local state = playerStates[player]
	if state == nil then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now - state.requestWindowStartedAt >= ClassConfig.RequestRateWindow then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if state.requestsInWindow > ClassConfig.MaxRequestsPerWindow then
		rejectRequest(player, state)
		return
	end
	if now - state.lastRequestAt < ClassConfig.MinimumRequestInterval then
		state.lastRequestAt = now
		rejectRequest(player, state)
		return
	end
	state.lastRequestAt = now

	if select("#", ...) ~= 0 or typeof(classValue) ~= "string" then
		rejectRequest(player, state)
		return
	end
	local requestedClassId = classValue :: string
	local definition = classDefinitions[requestedClassId]
	if definition == nil or definition.Tier ~= ClassConfig.Level8Threshold or not definition.Enabled then
		rejectRequest(player, state)
		return
	end
	if state.classId ~= ClassConfig.BaseClassId then
		rejectRequest(player, state)
		return
	end

	local runLevel = getStrictRunLevel(player)
	local runSerial = ProgressionService.GetRunSerial(player)
	if
		runLevel == nil
		or runLevel < ClassConfig.Level8Threshold
		or not PlayerSessionService.IsArena(player)
		or getAliveHumanoid(player) == nil
		or not ProgressionService.IsRunActive(player, runSerial)
	then
		rejectRequest(player, state)
		return
	end

	state.classId = requestedClassId
	state.selectedRunSerial = runSerial
	state.acceptedRequests += 1
	player:SetAttribute("ClassAcceptedRequestCount", state.acceptedRequests)
	setReplicatedState(player, state, false)
	task.spawn(applyCurrentVisuals, player)
end

local function bindCharacter(player: Player, character: Model)
	local state = playerStates[player]
	if state == nil then
		return
	end
	if state.diedConnection ~= nil then
		state.diedConnection:Disconnect()
		state.diedConnection = nil
	end
	resetClass(player)
	character:SetAttribute("SpinnerReady", false)
	character:SetAttribute("RammerReady", false)

	task.spawn(function()
		local humanoidInstance = character:WaitForChild("Humanoid", 10)
		local latestState = playerStates[player]
		if
			humanoidInstance == nil
			or not humanoidInstance:IsA("Humanoid")
			or latestState == nil
			or player.Character ~= character
		then
			return
		end
		latestState.diedConnection = humanoidInstance.Died:Connect(function()
			if playerStates[player] == latestState then
				resetClass(player)
			end
		end)
		task.defer(updateEligibility, player)
	end)
end

local function connectPlayer(player: Player)
	if playerStates[player] ~= nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local state: PlayerClassState = {
		classId = ClassConfig.BaseClassId,
		selectedRunSerial = -1,
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastRequestAt = -math.huge,
		acceptedRequests = 0,
		rejectedRequests = 0,
		writingAttributes = false,
		characterAddedConnection = nil,
		diedConnection = nil,
		levelChangedConnection = nil,
		classAttributeConnection = nil,
		eligibilityAttributeConnection = nil,
		selectedAttributeConnection = nil,
		sessionAttributeConnection = nil,
	}
	playerStates[player] = state
	player:SetAttribute("ClassAcceptedRequestCount", 0)
	player:SetAttribute("ClassRejectedRequestCount", 0)
	setReplicatedState(player, state, false)

	state.levelChangedConnection = player:GetAttributeChangedSignal("RunLevel"):Connect(function()
		updateEligibility(player)
	end)
	state.classAttributeConnection = player:GetAttributeChangedSignal(ClassConfig.ClassAttribute):Connect(function()
		enforceReplicatedState(player)
	end)
	state.eligibilityAttributeConnection = player:GetAttributeChangedSignal(ClassConfig.EligibilityAttribute):Connect(function()
		enforceReplicatedState(player)
	end)
	state.selectedAttributeConnection = player:GetAttributeChangedSignal(ClassConfig.SelectedAttribute):Connect(function()
		enforceReplicatedState(player)
	end)
	state.sessionAttributeConnection = player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(function()
		resetClass(player)
	end)
	state.characterAddedConnection = player.CharacterAdded:Connect(function(character: Model)
		bindCharacter(player, character)
	end)
	if player.Character ~= nil then
		bindCharacter(player, player.Character)
	else
		updateEligibility(player)
	end
end

local function disconnectPlayer(player: Player)
	local state = playerStates[player]
	if state == nil then
		return
	end
	local function disconnect(connection: RBXScriptConnection?)
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	disconnect(state.characterAddedConnection)
	disconnect(state.diedConnection)
	disconnect(state.levelChangedConnection)
	disconnect(state.classAttributeConnection)
	disconnect(state.eligibilityAttributeConnection)
	disconnect(state.selectedAttributeConnection)
	disconnect(state.sessionAttributeConnection)
	playerStates[player] = nil
end

function ClassService.GetClassId(player: Player): string
	local state = playerStates[player]
	return if state ~= nil then currentClassId(player, state) else ClassConfig.BaseClassId
end

function ClassService.Init()
	if initialized then
		return
	end
	initialized = true
	PlayerSessionService.Init()
	ProgressionService.Init()
	CollisionGroupService.Init()

	local remotesInstance = ReplicatedStorage:FindFirstChild("Remotes")
	if remotesInstance == nil then
		remotesInstance = Instance.new("Folder")
		remotesInstance.Name = "Remotes"
		remotesInstance.Parent = ReplicatedStorage
	elseif not remotesInstance:IsA("Folder") then
		error("ReplicatedStorage.Remotes must be a Folder")
	end
	local remotes = remotesInstance :: Folder
	local existingRemote = remotes:FindFirstChild("ClassEvolutionRequest")
	if existingRemote ~= nil then
		if not existingRemote:IsA("RemoteEvent") then
			error("ReplicatedStorage.Remotes.ClassEvolutionRequest must be a RemoteEvent")
		end
		classRequestRemote = existingRemote
	else
		local remote = Instance.new("RemoteEvent")
		remote.Name = "ClassEvolutionRequest"
		remote.Parent = remotes
		classRequestRemote = remote
	end

	(classRequestRemote :: RemoteEvent).OnServerEvent:Connect(handleClassRequest)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return ClassService
