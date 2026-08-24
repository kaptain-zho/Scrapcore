--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local CombatConfig = require(shared:WaitForChild("CombatConfig"))
local MovementConfig = require(shared:WaitForChild("MovementConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local RammerConfig = require(shared:WaitForChild("RammerConfig"))
local SpinnerConfig = require(shared:WaitForChild("SpinnerConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local classRequestRemote = remotes:WaitForChild("ClassEvolutionRequest") :: RemoteEvent
local devToolsRequestRemote = remotes:WaitForChild("DevToolsRequest") :: RemoteEvent
local hammerRequestRemote = remotes:WaitForChild("HammerAttackRequest") :: RemoteEvent
local progressionRequestRemote = remotes:WaitForChild("ProgressionUpgradeRequest") :: RemoteEvent
local rammerIntentRemote = remotes:WaitForChild("RammerAttackIntent") :: RemoteEvent
local spinnerIntentRemote = remotes:WaitForChild("SpinnerAttackIntent") :: RemoteEvent

local ROUTE_START = Vector3.new(0, 0, 150)
local ROUTE_QUOTAS = table.freeze({
	ScrapPileCommon = 14,
	ScrapPileRare = 4,
	ScrapPileEpic = 2,
	ReinforcedCrate = 4,
	PowerCore = 4,
})
local BALANCED_BUILD = table.freeze({
	Speed = 2,
	["Attack Rate"] = 2,
	Damage = 2,
	Health = 1,
	["Health Regen"] = 1,
})
local TARGET_LEVEL = 11
local MOVEMENT_TIMEOUT = 30
local ATTACK_TIMEOUT = 20
local RAMMER_LANE_DISTANCE = 18
local RAMMER_LANE_TOLERANCE = 1.25
local RAMMER_RELEASE_ALIGNMENT_DOT = 0.9995
local RAMMER_MAX_DRIVER_MISSES_PER_TARGET = 4
local SPINNER_FIXTURE_FOLDER_NAME = "Level8SpinnerClusterFixture"

type TargetTiming = {
	Name: string,
	BreakableType: string,
	StartingHealth: number,
	Elapsed: number,
	Attempts: number,
	Misses: number,
}

type Result = {
	ClassId: string,
	Status: string,
	StartedAt: number,
	FinishedAt: number,
	Elapsed: number,
	TravelTime: number,
	CombatTime: number,
	XPGained: number,
	XPPerMinute: number,
	Level9At: number?,
	Level10At: number?,
	Level11At: number?,
	AttackAttempts: number,
	AcceptedAttacks: number,
	RejectedAttacks: number,
	AcceptedRequests: number,
	RejectedRequests: number,
	Misses: number,
	UnaffectedPulses: number,
	Destroyed: {[string]: number},
	RouteNames: {string},
	TargetTimings: {TargetTiming},
	MissReasons: {string},
	RammerDestroyCooldownSamples: {number},
	RammerNonDestroyCooldownSamples: {number},
	Failure: string?,
}

type ClusterResult = {
	Status: string,
	ClusterSize: number,
	StartedAt: number,
	ActiveStartedAt: number,
	FinishedAt: number,
	WholeDuration: number,
	ActiveContactTime: number,
	PulseCount: number,
	TargetsInFirstPulse: number,
	MaximumTargetsInOnePulse: number,
	TotalDamage: number,
	CombinedDPS: number,
	XPGained: number,
	AcceptedRequests: number,
	RejectedRequests: number,
	DamageByTarget: {[string]: number},
	Failure: string?,
}

type DriveState = {
	mode: string,
	targetPosition: Vector3,
	stopDistance: number,
	smoothedVelocity: Vector3,
	lastRammerDashSerial: number,
	predictedDashDirection: Vector3,
	predictedDashSpeed: number,
	predictedDashEndsAt: number,
}

local currentResult: Result? = nil
local currentClusterResult: ClusterResult? = nil
local running = false
local nextHammerSequence = 0
local nextSpinnerSequence = 0
local nextRammerSequence = 0

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function waitFor(predicate: () -> boolean, timeout: number): boolean
	local deadline = os.clock() + timeout
	repeat
		if predicate() then
			return true
		end
		task.wait(0.05)
	until os.clock() >= deadline
	return predicate()
end

local function getRootAndHumanoid(): (BasePart, Humanoid)
	local character = player.Character
	assert(character ~= nil and character.Parent ~= nil, "Balance route requires a live character")
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	assert(root ~= nil and root:IsA("BasePart"), "Balance route requires HumanoidRootPart")
	assert(humanoid ~= nil and humanoid.Health > 0, "Balance route requires a live Humanoid")
	return root, humanoid
end

local function getUpgradeAttribute(category: string): string
	local definition = ProgressionConfig.Upgrades[category]
	assert(definition ~= nil, string.format("Unknown upgrade category %s", category))
	return definition.AttributeName
end

local function establishBalancedBuild(classId: string)
	devToolsRequestRemote:FireServer("ResetRun")
	assert(waitFor(function(): boolean
		return player:GetAttribute("RunLevel") == 1 and player:GetAttribute("RunClass") == ClassConfig.BaseClassId
	end, 5), "Developer reset did not complete")
	-- ResetRun starts the canonical respawn lifecycle. Give the replacement
	-- character and the developer-action rate limiter time to settle before the
	-- next authorized action.
	task.wait(0.35)

	devToolsRequestRemote:FireServer("ToLevel8")
	assert(waitFor(function(): boolean
		return player:GetAttribute("RunLevel") == 8
	end, 5), "Developer Level 8 action did not complete")

	for _, category in ProgressionConfig.UpgradeOrder do
		local desiredRank = BALANCED_BUILD[category] or 0
		local attributeName = getUpgradeAttribute(category)
		while (player:GetAttribute(attributeName) or 0) < desiredRank do
			local rankValue = player:GetAttribute(attributeName)
			local rank = if typeof(rankValue) == "number" then math.floor(rankValue) else 0
			progressionRequestRemote:FireServer(category, rank + 1)
			task.wait(0.14)
		end
	end
	assert(player:GetAttribute("UnspentUpgradePoints") == 0, "Balanced build did not spend exactly eight points")

	classRequestRemote:FireServer(classId)
	assert(waitFor(function(): boolean
		return player:GetAttribute(ClassConfig.ClassAttribute) == classId
	end, 5), string.format("Server did not accept %s", classId))
	task.wait(0.5)
end

local function createRoute(): {Model}
	local arena = Workspace:WaitForChild("GrayboxArena")
	local folder = arena:WaitForChild("Breakables")
	assert(folder:IsA("Folder"), "GrayboxArena.Breakables must be a Folder")

	local candidatesByType: {[string]: {Model}} = {}
	for breakableType in ROUTE_QUOTAS do
		candidatesByType[breakableType] = {}
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			local breakableType = child:GetAttribute("BreakableType")
			if typeof(breakableType) == "string" and candidatesByType[breakableType] ~= nil then
				table.insert(candidatesByType[breakableType], child)
			end
		end
	end
	for breakableType, candidates in candidatesByType do
		table.sort(candidates, function(left: Model, right: Model): boolean
			return left.Name < right.Name
		end)
		assert(#candidates >= ROUTE_QUOTAS[breakableType], string.format("Not enough %s route objects", breakableType))
	end

	local remaining: {[string]: number} = {}
	for breakableType, count in ROUTE_QUOTAS do
		remaining[breakableType] = count
	end
	local used: {[Model]: boolean} = {}
	local route: {Model} = {}
	local cursor = ROUTE_START

	while #route < 28 do
		local best: Model? = nil
		local bestDistance = math.huge
		for breakableType, candidates in candidatesByType do
			if remaining[breakableType] <= 0 then
				continue
			end
			for _, candidate in candidates do
				if used[candidate] or candidate.PrimaryPart == nil then
					continue
				end
				local distance = (candidate.PrimaryPart.Position - cursor).Magnitude
				if distance < bestDistance - 0.001 or (math.abs(distance - bestDistance) <= 0.001 and best ~= nil and candidate.Name < best.Name) then
					best = candidate
					bestDistance = distance
				end
			end
		end
		assert(best ~= nil, "Unable to complete deterministic farming route")
		used[best] = true
		table.insert(route, best)
		local breakableType = best:GetAttribute("BreakableType") :: string
		remaining[breakableType] -= 1
		cursor = (best.PrimaryPart :: BasePart).Position
	end
	return route
end

local function getPlanarDirection(fromPosition: Vector3, toPosition: Vector3): (Vector3, number)
	local offset = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	return if offset.Magnitude > 0.001 then offset.Unit else Vector3.zero, offset.Magnitude
end

local function getMovementSharpness(currentVelocity: Vector3, targetVelocity: Vector3): number
	if targetVelocity.Magnitude < currentVelocity.Magnitude then
		return MovementConfig.DecelerationSharpness
	end
	if currentVelocity.Magnitude > 0.01 and targetVelocity.Magnitude > 0.01 and currentVelocity.Unit:Dot(targetVelocity.Unit) < 0.99 then
		return MovementConfig.DirectionChangeSharpness
	end
	return MovementConfig.AccelerationSharpness
end

local function createDriveOverride(): (DriveState, RBXScriptConnection)
	local drive: DriveState = {
		mode = "Stop",
		targetPosition = Vector3.zero,
		stopDistance = 0,
		smoothedVelocity = Vector3.zero,
		lastRammerDashSerial = 0,
		predictedDashDirection = Vector3.zero,
		predictedDashSpeed = 0,
		predictedDashEndsAt = 0,
	}
	local connection = RunService.PreSimulation:Connect(function(deltaTime: number)
		local ok, root, humanoid = pcall(getRootAndHumanoid)
		if not ok then
			return
		end
		local movementVelocity = root:FindFirstChild("RobotMovementVelocity")
		local aimOrientation = root:FindFirstChild("RobotAimOrientation")
		if movementVelocity == nil or not movementVelocity:IsA("LinearVelocity") then
			return
		end

		local direction, distance = getPlanarDirection(root.Position, drive.targetPosition)
		local speedRankValue = player:GetAttribute("SpeedUpgradeLevel")
		local speedRank = if typeof(speedRankValue) == "number" and isFinite(speedRankValue)
			then ProgressionConfig.ClampUpgradeRank(speedRankValue)
			else 0
		local maximumSpeed = MovementConfig.MaxSpeed * ProgressionConfig.GetSpeedMultiplier(speedRank)
		local targetVelocity = Vector3.zero
		local planarForce = MovementConfig.MovementMaxPlanarForce
		if drive.mode == "Move" and distance > drive.stopDistance then
			targetVelocity = direction * maximumSpeed
		elseif
			(drive.mode == "None" or drive.mode == "PredictDash")
			and player:GetAttribute("RammerAttackPhase") == "Dash"
		then
			local dashDirectionValue = player:GetAttribute("RammerDashDirection")
			local dashSpeedValue = player:GetAttribute("RammerAuthorizedDashSpeed")
			local dashEndsAtValue = player:GetAttribute("RammerPhaseEndsAt")
			if
				typeof(dashDirectionValue) == "Vector3"
				and dashDirectionValue.Magnitude > 0.01
				and typeof(dashSpeedValue) == "number"
				and isFinite(dashSpeedValue)
				and typeof(dashEndsAtValue) == "number"
				and Workspace:GetServerTimeNow() <= dashEndsAtValue
			then
				direction = Vector3.new(dashDirectionValue.X, 0, dashDirectionValue.Z).Unit
				targetVelocity = direction * math.min(dashSpeedValue, RammerConfig.MaximumAuthorizedDashSpeed)
				maximumSpeed = math.min(dashSpeedValue, RammerConfig.MaximumAuthorizedDashSpeed)
				planarForce *= RammerConfig.DashPlanarForceMultiplier
				local dashSerialValue = player:GetAttribute("RammerAttackSerial")
				if typeof(dashSerialValue) == "number" and dashSerialValue ~= drive.lastRammerDashSerial then
					drive.smoothedVelocity = targetVelocity
					drive.lastRammerDashSerial = dashSerialValue
				end
			end
		elseif
			drive.mode == "PredictDash"
			and Workspace:GetServerTimeNow() <= drive.predictedDashEndsAt
			and drive.predictedDashDirection.Magnitude > 0.01
		then
			direction = drive.predictedDashDirection
			targetVelocity = direction * drive.predictedDashSpeed
			maximumSpeed = drive.predictedDashSpeed
			planarForce *= RammerConfig.DashPlanarForceMultiplier
		else
			drive.lastRammerDashSerial = 0
		end
		local sharpness = getMovementSharpness(drive.smoothedVelocity, targetVelocity)
		local alpha = 1 - math.exp(-sharpness * deltaTime)
		drive.smoothedVelocity = drive.smoothedVelocity:Lerp(targetVelocity, alpha)
		if drive.smoothedVelocity.Magnitude < 0.01 then
			drive.smoothedVelocity = Vector3.zero
		end

		movementVelocity.MaxPlanarAxesForce = Vector2.new(planarForce, planarForce)
		movementVelocity.PlaneVelocity = Vector2.new(drive.smoothedVelocity.X, drive.smoothedVelocity.Z)
		humanoid.WalkSpeed = drive.smoothedVelocity.Magnitude
		humanoid:Move(if drive.smoothedVelocity.Magnitude > 0 then drive.smoothedVelocity.Unit else Vector3.zero, false)
		if aimOrientation ~= nil and aimOrientation:IsA("AlignOrientation") and direction.Magnitude > 0 then
			aimOrientation.CFrame = CFrame.lookAt(Vector3.zero, direction)
		end
	end)
	return drive, connection
end

local function moveTo(drive: DriveState, targetPosition: Vector3, stopDistance: number): number
	local startedAt = Workspace:GetServerTimeNow()
	drive.mode = "Move"
	drive.targetPosition = targetPosition
	drive.stopDistance = stopDistance
	local arrived = waitFor(function(): boolean
		local root = getRootAndHumanoid()
		local _, distance = getPlanarDirection(root.Position, targetPosition)
		return distance <= stopDistance
	end, MOVEMENT_TIMEOUT)
	drive.mode = "Stop"
	drive.targetPosition = targetPosition
	drive.stopDistance = stopDistance
	assert(arrived, string.format("Route movement timed out at %.1f, %.1f", targetPosition.X, targetPosition.Z))
	assert(waitFor(function(): boolean
		return drive.smoothedVelocity.Magnitude < 0.5
	end, 2), "Route robot did not settle before attacking")
	return Workspace:GetServerTimeNow() - startedAt
end

local function getPlanarLookVector(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local planar = Vector3.new(look.X, 0, look.Z)
	return if planar.Magnitude > 0.001 then planar.Unit else Vector3.zero
end

local function getRammerOriginPosition(): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local origin = character:FindFirstChild("RammerHitOrigin", true)
	if origin ~= nil and origin:IsA("Attachment") then
		return origin.WorldPosition
	end
	return nil
end

local function hasLineOfSightToTarget(target: Model): boolean
	local origin = getRammerOriginPosition()
	local targetPart = target.PrimaryPart
	local character = player.Character
	if origin == nil or targetPart == nil or character == nil then
		return false
	end
	local offset = targetPart.Position - origin
	if offset.Magnitude <= 0.001 then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local result = Workspace:Raycast(origin, offset, params)
	return result == nil or result.Instance:IsDescendantOf(target)
end

local function faceRammerTarget(drive: DriveState, target: Model): (number, boolean)
	local targetPart = target.PrimaryPart
	assert(targetPart ~= nil, "Rammer target lost PrimaryPart")
	drive.mode = "Stop"
	drive.targetPosition = targetPart.Position
	drive.stopDistance = 0
	local aligned = waitFor(function(): boolean
		local root = getRootAndHumanoid()
		local direction = getPlanarDirection(root.Position, targetPart.Position)
		return direction.Magnitude > 0 and getPlanarLookVector(root):Dot(direction) >= RAMMER_RELEASE_ALIGNMENT_DOT
	end, 2)
	local root = getRootAndHumanoid()
	local direction = getPlanarDirection(root.Position, targetPart.Position)
	local dot = if direction.Magnitude > 0 then getPlanarLookVector(root):Dot(direction) else -1
	return dot, aligned and hasLineOfSightToTarget(target)
end

local function acquireRammerLane(drive: DriveState, target: Model, savedLane: Vector3?): (Vector3, number)
	local targetPart = target.PrimaryPart
	assert(targetPart ~= nil, "Rammer target lost PrimaryPart")
	local root = getRootAndHumanoid()
	local travelTime = 0
	local lanePosition = savedLane
	if lanePosition == nil then
		local outward, distance = getPlanarDirection(targetPart.Position, root.Position)
		assert(outward.Magnitude > 0, "Rammer cannot derive an approach lane")
		if math.abs(distance - RAMMER_LANE_DISTANCE) <= 2 then
			lanePosition = root.Position
		else
			lanePosition = Vector3.new(
				targetPart.Position.X + outward.X * RAMMER_LANE_DISTANCE,
				root.Position.Y,
				targetPart.Position.Z + outward.Z * RAMMER_LANE_DISTANCE
			)
			travelTime += moveTo(drive, lanePosition, RAMMER_LANE_TOLERANCE)
		end
	else
		travelTime += moveTo(drive, lanePosition, RAMMER_LANE_TOLERANCE)
	end

	local _, laneDistance = getPlanarDirection((getRootAndHumanoid()).Position, targetPart.Position)
	assert(
		math.abs(laneDistance - RAMMER_LANE_DISTANCE) <= 2.5,
		string.format("Rammer lane distance %.2f is outside the legal driver band", laneDistance)
	)
	local alignmentDot, clearLine = faceRammerTarget(drive, target)
	assert(
		alignmentDot >= RAMMER_RELEASE_ALIGNMENT_DOT,
		string.format("Rammer lane alignment %.4f did not settle", alignmentDot)
	)
	assert(clearLine, "Rammer route lane does not have clear line of sight")
	return lanePosition, travelTime
end

local function getBreakableHealth(model: Model): number
	local value = model:GetAttribute("BreakableHealth")
	return if typeof(value) == "number" and isFinite(value) then value else 0
end

local function attackWithHammer(model: Model, result: Result, sequence: number): number
	local cooldown = math.clamp(
		CombatConfig.Cooldown * ProgressionConfig.GetAttackRateMultiplier(2)
			+ (ClassConfig.Definitions.Striker.Combat :: any).CooldownPenalty,
		CombatConfig.MinCooldown,
		(ClassConfig.Definitions.Striker.Combat :: any).MaxCooldown
	)
	while model:GetAttribute("BreakableActive") == true do
		local healthBefore = getBreakableHealth(model)
		local acceptedBefore = player:GetAttribute("HammerAcceptedAttackCount")
		sequence += 1
		result.AttackAttempts += 1
		hammerRequestRemote:FireServer(sequence)
		task.wait(CombatConfig.Windup + CombatConfig.ActiveTime + 0.08)
		local acceptedAfter = player:GetAttribute("HammerAcceptedAttackCount")
		if typeof(acceptedBefore) == "number" and typeof(acceptedAfter) == "number" and acceptedAfter > acceptedBefore then
			result.AcceptedAttacks += 1
		else
			result.RejectedAttacks += 1
		end
		if getBreakableHealth(model) >= healthBefore - 0.001 then
			result.Misses += 1
		end
		task.wait(math.max(cooldown - CombatConfig.Windup - CombatConfig.ActiveTime - 0.03, 0.05))
	end
	return sequence
end

local function attackWithSpinner(model: Model, result: Result, sequence: number): number
	local healthBefore = getBreakableHealth(model)
	local serialBefore = player:GetAttribute("SpinnerAttackSerial")
	local pulseBefore = player:GetAttribute("SpinnerPulseCount")
	local affectedBefore = player:GetAttribute("SpinnerAffectedTargetCount")
	sequence += 1
	result.AttackAttempts += 1
	spinnerIntentRemote:FireServer("Start", sequence)
	local accepted = waitFor(function(): boolean
		local serial = player:GetAttribute("SpinnerAttackSerial")
		return typeof(serial) == "number" and typeof(serialBefore) == "number" and serial > serialBefore
	end, 0.6)
	if accepted then
		result.AcceptedAttacks += 1
	else
		result.RejectedAttacks += 1
		return sequence
	end

	local nextKeepaliveAt = Workspace:GetServerTimeNow() + SpinnerConfig.HoldKeepaliveInterval
	local deadline = os.clock() + ATTACK_TIMEOUT
	while model:GetAttribute("BreakableActive") == true and os.clock() < deadline do
		local now = Workspace:GetServerTimeNow()
		if now >= nextKeepaliveAt then
			nextKeepaliveAt = now + SpinnerConfig.HoldKeepaliveInterval
			sequence += 1
			spinnerIntentRemote:FireServer("KeepAlive", sequence)
		end
		task.wait(0.05)
	end
	sequence += 1
	spinnerIntentRemote:FireServer("Stop", sequence)
	assert(model:GetAttribute("BreakableActive") ~= true, string.format("Spinner did not destroy %s", model.Name))
	local pulseAfter = player:GetAttribute("SpinnerPulseCount")
	local affectedAfter = player:GetAttribute("SpinnerAffectedTargetCount")
	if
		typeof(pulseBefore) == "number"
		and typeof(pulseAfter) == "number"
		and typeof(affectedBefore) == "number"
		and typeof(affectedAfter) == "number"
	then
		result.UnaffectedPulses += math.max((pulseAfter - pulseBefore) - (affectedAfter - affectedBefore), 0)
	end
	if getBreakableHealth(model) >= healthBefore - 0.001 then
		result.Misses += 1
	end
	assert(waitFor(function(): boolean
		return player:GetAttribute("SpinnerAttackPhase") == "Idle"
	end, SpinnerConfig.PostSpinCooldown + SpinnerConfig.SpinDownDuration + 1), "Spinner cooldown did not finish")
	return sequence
end

local function getRammerBreakableHoldDuration(remainingHealth: number): number
	local fullChargeTime = RammerConfig.GetFullChargeTime(BALANCED_BUILD["Attack Rate"])
	local maximumImpactDamage = RammerConfig.GetFullImpactDamage(BALANCED_BUILD.Damage)
	local requiredImpactDamage = math.min(remainingHealth, ProgressionConfig.MaxBreakableDamagePerHit)
		/ RammerConfig.RammerBreakableDamageMultiplier
	local requiredChargeAmount = if maximumImpactDamage > RammerConfig.MinimumImpactDamage
		then math.clamp(
			(requiredImpactDamage - RammerConfig.MinimumImpactDamage)
				/ (maximumImpactDamage - RammerConfig.MinimumImpactDamage),
			0,
			1
		)
		else 1
	return math.max(RammerConfig.MinimumValidHold, fullChargeTime * requiredChargeAmount)
end

local function attackWithRammer(model: Model, drive: DriveState, result: Result, sequence: number): (number, number)
	local lanePosition: Vector3? = nil
	local repositionTime = 0
	local driverMisses = 0
	lanePosition, repositionTime = acquireRammerLane(drive, model, nil)
	while model:GetAttribute("BreakableActive") == true do
		local healthBefore = getBreakableHealth(model)
		local holdDuration = getRammerBreakableHoldDuration(healthBefore)
		local serialBefore = player:GetAttribute("RammerAttackSerial")
		local impactBeforeValue = player:GetAttribute("RammerImpactCount")
		local impactBefore = if typeof(impactBeforeValue) == "number" then impactBeforeValue else 0
		local alignmentDot, clearLine = faceRammerTarget(drive, model)
		assert(alignmentDot >= RAMMER_RELEASE_ALIGNMENT_DOT, "Rammer lost frontal alignment before charge")
		assert(clearLine, "Rammer lost line of sight before charge")
		sequence += 1
		result.AttackAttempts += 1
		rammerIntentRemote:FireServer("Start", sequence)
		local accepted = waitFor(function(): boolean
			local serial = player:GetAttribute("RammerAttackSerial")
			return typeof(serial) == "number" and typeof(serialBefore) == "number" and serial > serialBefore
		end, 0.6)
		if not accepted then
			result.RejectedAttacks += 1
			return sequence
		end
		result.AcceptedAttacks += 1

		local startedAt = Workspace:GetServerTimeNow()
		local nextKeepaliveAt = startedAt + RammerConfig.HoldKeepaliveInterval
		while Workspace:GetServerTimeNow() - startedAt < holdDuration + 0.04 do
			local now = Workspace:GetServerTimeNow()
			if now >= nextKeepaliveAt then
				nextKeepaliveAt = now + RammerConfig.HoldKeepaliveInterval
				sequence += 1
				rammerIntentRemote:FireServer("KeepAlive", sequence)
			end
			task.wait(0.04)
		end
		local root = getRootAndHumanoid()
		local predictedDirection = getPlanarLookVector(root)
		local chargeAmount = RammerConfig.GetChargeAmount(
			Workspace:GetServerTimeNow() - startedAt,
			RammerConfig.GetFullChargeTime(BALANCED_BUILD["Attack Rate"])
		)
		drive.predictedDashDirection = predictedDirection
		drive.predictedDashSpeed = RammerConfig.GetAuthorizedDashSpeed(BALANCED_BUILD.Speed, chargeAmount)
		drive.predictedDashEndsAt = Workspace:GetServerTimeNow() + RammerConfig.DashDuration
		drive.smoothedVelocity = predictedDirection * drive.predictedDashSpeed
		drive.mode = "PredictDash"
		sequence += 1
		rammerIntentRemote:FireServer("Release", sequence)
		local maximumClosingSpeed = 0
		local minimumOriginDistance = math.huge
		local earlyRecovery = false
		local dashStartedAtValue = player:GetAttribute("RammerLastDashStartedAt")
		local dashStartedAt = if typeof(dashStartedAtValue) == "number"
			then dashStartedAtValue
			else Workspace:GetServerTimeNow()
		local dashDeadline = os.clock() + RammerConfig.DashDuration + RammerConfig.MissRecoveryDuration + 1
		repeat
			local phase = player:GetAttribute("RammerAttackPhase")
			if phase == "Cooldown" or phase == "Idle" then
				break
			end
			local root = getRootAndHumanoid()
			local dashDirectionValue = player:GetAttribute("RammerDashDirection")
			if typeof(dashDirectionValue) == "Vector3" and dashDirectionValue.Magnitude > 0.01 then
				local direction = Vector3.new(dashDirectionValue.X, 0, dashDirectionValue.Z).Unit
				local velocity = root.AssemblyLinearVelocity
				local planarVelocity = Vector3.new(velocity.X, 0, velocity.Z)
				maximumClosingSpeed = math.max(maximumClosingSpeed, planarVelocity:Dot(direction))
			end
			local origin = getRammerOriginPosition()
			local targetPart = model.PrimaryPart
			if origin ~= nil and targetPart ~= nil then
				minimumOriginDistance = math.min(minimumOriginDistance, (targetPart.Position - origin).Magnitude)
			end
			if
				phase == "Recovery"
				and Workspace:GetServerTimeNow() < dashStartedAt + RammerConfig.DashDuration - 0.03
			then
				earlyRecovery = true
			end
			task.wait(0.02)
		until os.clock() >= dashDeadline
		local phase = player:GetAttribute("RammerAttackPhase")
		assert(phase == "Cooldown" or phase == "Idle", "Rammer dash did not resolve")
		drive.mode = "Stop"
		drive.targetPosition = (model.PrimaryPart :: BasePart).Position
		local missed = getBreakableHealth(model) >= healthBefore - 0.001
		if not missed then
			local cooldownEndsAtValue = player:GetAttribute("RammerCooldownEndsAt")
			local dashStartedAtValue = player:GetAttribute("RammerLastDashStartedAt")
			if typeof(cooldownEndsAtValue) == "number" and typeof(dashStartedAtValue) == "number" then
				local cooldownDuration = cooldownEndsAtValue - dashStartedAtValue
				if model:GetAttribute("BreakableActive") == true then
					table.insert(result.RammerNonDestroyCooldownSamples, cooldownDuration)
				else
					table.insert(result.RammerDestroyCooldownSamples, cooldownDuration)
				end
			end
		end
		if missed then
			result.Misses += 1
			driverMisses += 1
			local impactAfterValue = player:GetAttribute("RammerImpactCount")
			local impactAfter = if typeof(impactAfterValue) == "number" then impactAfterValue else impactBefore
			local reason = if impactAfter > impactBefore
				then "another target consumed the one-target impact"
				elseif alignmentDot < RAMMER_RELEASE_ALIGNMENT_DOT then "release alignment was below the driver threshold"
				elseif not clearLine then "line of sight was blocked before release"
				elseif maximumClosingSpeed < RammerConfig.MinimumImpactClosingSpeed
					then "observed closing speed never reached the server minimum"
				elseif minimumOriginDistance > RammerConfig.MaximumTargetRange
					then "the weapon origin never entered server range"
				elseif earlyRecovery then "the dash entered recovery early, consistent with an obstacle"
				else "server found no valid target despite legal driver metrics"
			table.insert(result.MissReasons, string.format(
				"%s: %s (alignment=%.4f, maxClosing=%.2f, minOriginDistance=%.2f)",
				model.Name,
				reason,
				alignmentDot,
				maximumClosingSpeed,
				minimumOriginDistance
			))
			assert(
				driverMisses <= RAMMER_MAX_DRIVER_MISSES_PER_TARGET,
				string.format("Rammer driver exceeded the miss ceiling for %s", model.Name)
			)
		end
		assert(waitFor(function(): boolean
			return player:GetAttribute("RammerAttackPhase") == "Idle"
		end, RammerConfig.GetCooldown(2) + 1), "Rammer cooldown did not finish")
		if model:GetAttribute("BreakableActive") == true then
			local elapsed: number
			lanePosition, elapsed = acquireRammerLane(drive, model, if missed then nil else lanePosition)
			repositionTime += elapsed
		end
	end
	return sequence, repositionTime
end

local function calculateXPFromLevelEight(): number
	local levelValue = player:GetAttribute("RunLevel")
	local xpValue = player:GetAttribute("RunXP")
	local level = if typeof(levelValue) == "number" then math.clamp(math.floor(levelValue), 8, ProgressionConfig.LevelCap) else 8
	local xp = if typeof(xpValue) == "number" then math.max(math.floor(xpValue), 0) else 0
	local total = xp
	for completedLevel = 8, level - 1 do
		total += ProgressionConfig.GetXPToNextLevel(completedLevel)
	end
	return total
end

local function runRoute(classId: string): Result
	assert(RunService:IsStudio(), "Level 8 balance measurement is Studio-only")
	assert(
		classId == ClassConfig.StrikerClassId
			or classId == ClassConfig.SpinnerClassId
			or classId == ClassConfig.RammerClassId,
		"Unsupported Level 8 class"
	)
	establishBalancedBuild(classId)
	local route = createRoute()
	local result: Result = {
		ClassId = classId,
		Status = "WarmingUp",
		StartedAt = 0,
		FinishedAt = 0,
		Elapsed = 0,
		TravelTime = 0,
		CombatTime = 0,
		XPGained = 0,
		XPPerMinute = 0,
		Level9At = nil,
		Level10At = nil,
		Level11At = nil,
		AttackAttempts = 0,
		AcceptedAttacks = 0,
		RejectedAttacks = 0,
		AcceptedRequests = 0,
		RejectedRequests = 0,
		Misses = 0,
		UnaffectedPulses = 0,
		Destroyed = {
			ScrapPileCommon = 0,
			ScrapPileRare = 0,
			ScrapPileEpic = 0,
			ReinforcedCrate = 0,
			PowerCore = 0,
		},
		RouteNames = {},
		TargetTimings = {},
		MissReasons = {},
		RammerDestroyCooldownSamples = {},
		RammerNonDestroyCooldownSamples = {},
		Failure = nil,
	}
	currentResult = result
	for _, model in route do
		table.insert(result.RouteNames, model.Name)
	end

	local drive, driveConnection = createDriveOverride()
	local robotController = script.Parent:FindFirstChild("RobotController")
	local restoreRobotController = robotController ~= nil
		and robotController:IsA("LocalScript")
		and robotController.Enabled
	if restoreRobotController then
		(robotController :: LocalScript).Enabled = false
	end
	local destroyedConnections: {RBXScriptConnection} = {}
	local destroyedSeen: {[Model]: boolean} = {}
	for _, model in (Workspace.GrayboxArena.Breakables :: Folder):GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		table.insert(destroyedConnections, model:GetAttributeChangedSignal("BreakableActive"):Connect(function()
			if model:GetAttribute("BreakableActive") ~= false or destroyedSeen[model] then
				return
			end
			destroyedSeen[model] = true
			local breakableType = model:GetAttribute("BreakableType")
			if typeof(breakableType) == "string" and result.Destroyed[breakableType] ~= nil then
				result.Destroyed[breakableType] += 1
			end
		end))
	end

	local ok, failure = xpcall(function()
		local routeStart = Vector3.new(ROUTE_START.X, getRootAndHumanoid().Position.Y, ROUTE_START.Z)
		moveTo(drive, routeStart, 3)
		result.Status = "Running"
		result.StartedAt = Workspace:GetServerTimeNow()
		local acceptedAttribute = if classId == ClassConfig.StrikerClassId
			then "HammerAcceptedAttackCount"
			elseif classId == ClassConfig.SpinnerClassId then "SpinnerAcceptedRequestCount"
			else "RammerAcceptedRequestCount"
		local rejectedAttribute = if classId == ClassConfig.StrikerClassId
			then "HammerRejectedRequestCount"
			elseif classId == ClassConfig.SpinnerClassId then "SpinnerRejectedRequestCount"
			else "RammerRejectedRequestCount"
		local acceptedBefore = player:GetAttribute(acceptedAttribute)
		local rejectedBefore = player:GetAttribute(rejectedAttribute)
		local sequence = if classId == ClassConfig.StrikerClassId
			then nextHammerSequence
			elseif classId == ClassConfig.SpinnerClassId then nextSpinnerSequence
			else nextRammerSequence

		local levelConnection = player:GetAttributeChangedSignal("RunLevel"):Connect(function()
			local level = player:GetAttribute("RunLevel")
			local elapsed = Workspace:GetServerTimeNow() - result.StartedAt
			if typeof(level) ~= "number" then
				return
			end
			if level >= 9 and result.Level9At == nil then result.Level9At = elapsed end
			if level >= 10 and result.Level10At == nil then result.Level10At = elapsed end
			if level >= 11 and result.Level11At == nil then result.Level11At = elapsed end
		end)

		for _, model in route do
			if (player:GetAttribute("RunLevel") :: any) >= TARGET_LEVEL then
				break
			end
			if model.Parent == nil or model.PrimaryPart == nil or model:GetAttribute("BreakableActive") ~= true then
				continue
			end
			local stopDistance = if classId == ClassConfig.StrikerClassId
				then 8
				elseif classId == ClassConfig.SpinnerClassId then 7
				else 18
			result.TravelTime += moveTo(drive, model.PrimaryPart.Position, stopDistance)
			task.wait(0.15)
			local combatStartedAt = Workspace:GetServerTimeNow()
			local attemptsBefore = result.AttackAttempts
			local missesBefore = result.Misses
			local startingHealth = getBreakableHealth(model)
			local repositionTime = 0
			if classId == ClassConfig.StrikerClassId then
				sequence = attackWithHammer(model, result, sequence)
			elseif classId == ClassConfig.SpinnerClassId then
				sequence = attackWithSpinner(model, result, sequence)
			else
				sequence, repositionTime = attackWithRammer(model, drive, result, sequence)
			end
			local targetElapsed = Workspace:GetServerTimeNow() - combatStartedAt
			result.TravelTime += repositionTime
			result.CombatTime += math.max(targetElapsed - repositionTime, 0)
			local breakableType = model:GetAttribute("BreakableType")
			table.insert(result.TargetTimings, {
				Name = model.Name,
				BreakableType = if typeof(breakableType) == "string" then breakableType else "Unknown",
				StartingHealth = startingHealth,
				Elapsed = targetElapsed,
				Attempts = result.AttackAttempts - attemptsBefore,
				Misses = result.Misses - missesBefore,
			})
		end
		if classId == ClassConfig.StrikerClassId then
			nextHammerSequence = sequence
		elseif classId == ClassConfig.SpinnerClassId then
			nextSpinnerSequence = sequence
		else
			nextRammerSequence = sequence
		end
		levelConnection:Disconnect()
		result.FinishedAt = Workspace:GetServerTimeNow()
		result.Elapsed = result.FinishedAt - result.StartedAt
		result.XPGained = calculateXPFromLevelEight()
		result.XPPerMinute = if result.Elapsed > 0 then result.XPGained * 60 / result.Elapsed else 0
		local acceptedAfter = player:GetAttribute(acceptedAttribute)
		local rejectedAfter = player:GetAttribute(rejectedAttribute)
		result.AcceptedRequests = if typeof(acceptedBefore) == "number" and typeof(acceptedAfter) == "number"
			then acceptedAfter - acceptedBefore
			else 0
		result.RejectedRequests = if typeof(rejectedBefore) == "number" and typeof(rejectedAfter) == "number"
			then rejectedAfter - rejectedBefore
			else 0
		assert(player:GetAttribute("RunLevel") >= TARGET_LEVEL, "Route ended before gaining three levels")
		result.Status = "Complete"
	end, debug.traceback)

	drive.mode = "Stop"
	drive.smoothedVelocity = Vector3.zero
	driveConnection:Disconnect()
	if restoreRobotController and robotController ~= nil and robotController:IsA("LocalScript") then
		robotController.Enabled = true
	end
	for _, connection in destroyedConnections do
		connection:Disconnect()
	end
	if not ok then
		result.Status = "Failed"
		result.Failure = tostring(failure)
		result.FinishedAt = Workspace:GetServerTimeNow()
		result.Elapsed = if result.StartedAt > 0 then result.FinishedAt - result.StartedAt else 0
	end
	return result
end

local function runRammerTargetFixture(): Result
	assert(RunService:IsStudio(), "Rammer target measurement is Studio-only")
	local fixture = Workspace:FindFirstChild("Level8RammerTargetFixture")
	assert(fixture ~= nil and fixture:IsA("Folder"), "Rammer target fixture folder is missing")
	local targets: {Model} = {}
	for _, child in fixture:GetChildren() do
		if child:IsA("Model") and child.PrimaryPart ~= nil then
			table.insert(targets, child)
		end
	end
	table.sort(targets, function(left: Model, right: Model): boolean
		local leftHealth = left:GetAttribute("TargetHealth")
		local rightHealth = right:GetAttribute("TargetHealth")
		return (if typeof(leftHealth) == "number" then leftHealth else 0)
			< (if typeof(rightHealth) == "number" then rightHealth else 0)
	end)
	assert(#targets == 4, "Rammer target fixture must contain four targets")
	establishBalancedBuild(ClassConfig.RammerClassId)

	local result: Result = {
		ClassId = ClassConfig.RammerClassId,
		Status = "WarmingUp",
		StartedAt = 0,
		FinishedAt = 0,
		Elapsed = 0,
		TravelTime = 0,
		CombatTime = 0,
		XPGained = 0,
		XPPerMinute = 0,
		Level9At = nil,
		Level10At = nil,
		Level11At = nil,
		AttackAttempts = 0,
		AcceptedAttacks = 0,
		RejectedAttacks = 0,
		AcceptedRequests = 0,
		RejectedRequests = 0,
		Misses = 0,
		UnaffectedPulses = 0,
		Destroyed = {},
		RouteNames = {},
		TargetTimings = {},
		MissReasons = {},
		RammerDestroyCooldownSamples = {},
		RammerNonDestroyCooldownSamples = {},
		Failure = nil,
	}
	currentResult = result

	local drive, driveConnection = createDriveOverride()
	local robotController = script.Parent:FindFirstChild("RobotController")
	local restoreRobotController = robotController ~= nil
		and robotController:IsA("LocalScript")
		and robotController.Enabled
	if restoreRobotController then
		(robotController :: LocalScript).Enabled = false
	end

	local ok, failure = xpcall(function()
		local acceptedBeforeValue = player:GetAttribute("RammerAcceptedRequestCount")
		local rejectedBeforeValue = player:GetAttribute("RammerRejectedRequestCount")
		local acceptedBefore = if typeof(acceptedBeforeValue) == "number" then acceptedBeforeValue else 0
		local rejectedBefore = if typeof(rejectedBeforeValue) == "number" then rejectedBeforeValue else 0
		local sequence = nextRammerSequence
		result.Status = "Running"
		result.StartedAt = Workspace:GetServerTimeNow()
		for _, target in targets do
			assert(target:GetAttribute("BreakableActive") == true, string.format("%s is not active", target.Name))
			result.TravelTime += moveTo(drive, (target.PrimaryPart :: BasePart).Position, RAMMER_LANE_DISTANCE)
			local startedAt = Workspace:GetServerTimeNow()
			local attemptsBefore = result.AttackAttempts
			local missesBefore = result.Misses
			local startingHealth = getBreakableHealth(target)
			local repositionTime: number
			sequence, repositionTime = attackWithRammer(target, drive, result, sequence)
			local elapsed = Workspace:GetServerTimeNow() - startedAt
			result.TravelTime += repositionTime
			result.CombatTime += math.max(elapsed - repositionTime, 0)
			table.insert(result.TargetTimings, {
				Name = target.Name,
				BreakableType = "StationaryHumanoid",
				StartingHealth = startingHealth,
				Elapsed = elapsed,
				Attempts = result.AttackAttempts - attemptsBefore,
				Misses = result.Misses - missesBefore,
			})
		end
		nextRammerSequence = sequence
		result.FinishedAt = Workspace:GetServerTimeNow()
		result.Elapsed = result.FinishedAt - result.StartedAt
		local acceptedAfterValue = player:GetAttribute("RammerAcceptedRequestCount")
		local rejectedAfterValue = player:GetAttribute("RammerRejectedRequestCount")
		result.AcceptedRequests = (if typeof(acceptedAfterValue) == "number" then acceptedAfterValue else acceptedBefore)
			- acceptedBefore
		result.RejectedRequests = (if typeof(rejectedAfterValue) == "number" then rejectedAfterValue else rejectedBefore)
			- rejectedBefore
		result.Status = "Complete"
	end, debug.traceback)

	drive.mode = "Stop"
	drive.smoothedVelocity = Vector3.zero
	driveConnection:Disconnect()
	if restoreRobotController and robotController ~= nil and robotController:IsA("LocalScript") then
		robotController.Enabled = true
	end
	if not ok then
		result.Status = "Failed"
		result.Failure = tostring(failure)
		result.FinishedAt = Workspace:GetServerTimeNow()
		result.Elapsed = if result.StartedAt > 0 then result.FinishedAt - result.StartedAt else 0
	end
	return result
end

local function getSpinnerFixture(): (Folder, {Model}, Vector3, Vector3)
	local fixture = Workspace:WaitForChild(SPINNER_FIXTURE_FOLDER_NAME, 3)
	assert(fixture ~= nil and fixture:IsA("Folder"), "Spinner cluster fixture folder is missing")
	local stagingPosition = fixture:GetAttribute("StagingPosition")
	local targetPosition = fixture:GetAttribute("TargetPosition")
	assert(typeof(stagingPosition) == "Vector3", "Spinner fixture StagingPosition is missing")
	assert(typeof(targetPosition) == "Vector3", "Spinner fixture TargetPosition is missing")
	local targets: {Model} = {}
	for _, child in fixture:GetChildren() do
		if child:IsA("ObjectValue") and child.Value ~= nil and child.Value:IsA("Model") then
			local model = child.Value
			assert(model:GetAttribute("BreakableActive") == true, string.format("%s is not active", model.Name))
			table.insert(targets, model)
		end
	end
	table.sort(targets, function(left: Model, right: Model): boolean
		return left.Name < right.Name
	end)
	local declaredSize = fixture:GetAttribute("ClusterSize")
	assert(typeof(declaredSize) == "number" and declaredSize == #targets, "Spinner fixture size does not match references")
	assert(
		#targets == 2 or #targets == 4 or #targets == 6 or #targets == 7,
		"Spinner fixture must contain 2, 4, 6, or 7 targets"
	)
	return fixture, targets, stagingPosition, targetPosition
end

local function runSpinnerCluster(): ClusterResult
	assert(RunService:IsStudio(), "Spinner cluster measurement is Studio-only")
	local _, targets, stagingPosition, targetPosition = getSpinnerFixture()
	establishBalancedBuild(ClassConfig.SpinnerClassId)
	local result: ClusterResult = {
		Status = "WarmingUp",
		ClusterSize = #targets,
		StartedAt = 0,
		ActiveStartedAt = 0,
		FinishedAt = 0,
		WholeDuration = 0,
		ActiveContactTime = 0,
		PulseCount = 0,
		TargetsInFirstPulse = 0,
		MaximumTargetsInOnePulse = 0,
		TotalDamage = 0,
		CombinedDPS = 0,
		XPGained = 0,
		AcceptedRequests = 0,
		RejectedRequests = 0,
		DamageByTarget = {},
		Failure = nil,
	}
	currentClusterResult = result

	local drive, driveConnection = createDriveOverride()
	local robotController = script.Parent:FindFirstChild("RobotController")
	local restoreRobotController = robotController ~= nil
		and robotController:IsA("LocalScript")
		and robotController.Enabled
	if restoreRobotController then
		(robotController :: LocalScript).Enabled = false
	end

	local ok, failure = xpcall(function()
		moveTo(drive, stagingPosition, 0.35)
		drive.mode = "Stop"
		drive.targetPosition = targetPosition
		assert(waitFor(function(): boolean
			local root = getRootAndHumanoid()
			local direction = getPlanarDirection(root.Position, targetPosition)
			return direction.Magnitude > 0 and getPlanarLookVector(root):Dot(direction) >= 0.995
		end, 2), "Spinner did not face the cluster")

		local initialHealth: {[Model]: number} = {}
		local previousHealth: {[Model]: number} = {}
		for _, target in targets do
			local health = getBreakableHealth(target)
			assert(health > 0, string.format("%s has no measurable health", target.Name))
			initialHealth[target] = health
			previousHealth[target] = health
		end
		local xpBefore = calculateXPFromLevelEight()
		local acceptedBeforeValue = player:GetAttribute("SpinnerAcceptedRequestCount")
		local rejectedBeforeValue = player:GetAttribute("SpinnerRejectedRequestCount")
		local acceptedBefore = if typeof(acceptedBeforeValue) == "number" then acceptedBeforeValue else 0
		local rejectedBefore = if typeof(rejectedBeforeValue) == "number" then rejectedBeforeValue else 0
		local pulseBeforeValue = player:GetAttribute("SpinnerPulseCount")
		local pulseBefore = if typeof(pulseBeforeValue) == "number" then pulseBeforeValue else 0
		local affectedBeforeValue = player:GetAttribute("SpinnerAffectedTargetCount")
		local affectedBefore = if typeof(affectedBeforeValue) == "number" then affectedBeforeValue else 0
		local serialBefore = player:GetAttribute("SpinnerAttackSerial")

		nextSpinnerSequence += 1
		result.Status = "Running"
		result.StartedAt = Workspace:GetServerTimeNow()
		spinnerIntentRemote:FireServer("Start", nextSpinnerSequence)
		assert(waitFor(function(): boolean
			local serial = player:GetAttribute("SpinnerAttackSerial")
			return typeof(serial) == "number" and typeof(serialBefore) == "number" and serial > serialBefore
		end, 0.8), "Server did not accept Spinner cluster start")
		assert(waitFor(function(): boolean
			return player:GetAttribute("SpinnerAttackPhase") == "Active"
		end, SpinnerConfig.GetSpinUpDuration(2) + 0.8), "Spinner cluster never became active")
		local activeStartedAtValue = player:GetAttribute("SpinnerPhaseStartedAt")
		result.ActiveStartedAt = if typeof(activeStartedAtValue) == "number"
			then activeStartedAtValue
			else Workspace:GetServerTimeNow()
		assert(waitFor(function(): boolean
			local pulseValue = player:GetAttribute("SpinnerPulseCount")
			return typeof(pulseValue) == "number" and pulseValue > pulseBefore
		end, SpinnerConfig.GetPulseInterval(2) + 0.8), "Spinner cluster did not produce its first pulse")
		local affectedAfterFirstValue = player:GetAttribute("SpinnerAffectedTargetCount")
		local affectedAfterFirst = if typeof(affectedAfterFirstValue) == "number"
			then affectedAfterFirstValue
			else affectedBefore
		result.TargetsInFirstPulse = affectedAfterFirst - affectedBefore
		result.MaximumTargetsInOnePulse = result.TargetsInFirstPulse

		local nextKeepaliveAt = Workspace:GetServerTimeNow() + SpinnerConfig.HoldKeepaliveInterval
		local deadline = os.clock() + ATTACK_TIMEOUT
		repeat
			local changedThisSample = 0
			local activeTargets = 0
			for _, target in targets do
				local health = getBreakableHealth(target)
				if health < previousHealth[target] - 0.001 then
					changedThisSample += 1
				end
				previousHealth[target] = health
				if target:GetAttribute("BreakableActive") == true then
					activeTargets += 1
				end
			end
			result.MaximumTargetsInOnePulse = math.max(result.MaximumTargetsInOnePulse, changedThisSample)
			if activeTargets == 0 then
				break
			end
			local now = Workspace:GetServerTimeNow()
			if now >= nextKeepaliveAt then
				nextKeepaliveAt = now + SpinnerConfig.HoldKeepaliveInterval
				nextSpinnerSequence += 1
				spinnerIntentRemote:FireServer("KeepAlive", nextSpinnerSequence)
			end
			task.wait(0.02)
		until os.clock() >= deadline
		for _, target in targets do
			assert(target:GetAttribute("BreakableActive") ~= true, string.format("Spinner cluster did not destroy %s", target.Name))
		end

		result.FinishedAt = Workspace:GetServerTimeNow()
		nextSpinnerSequence += 1
		spinnerIntentRemote:FireServer("Stop", nextSpinnerSequence)
		assert(waitFor(function(): boolean
			return player:GetAttribute("SpinnerAttackPhase") == "Idle"
		end, SpinnerConfig.PostSpinCooldown + SpinnerConfig.SpinDownDuration + 1), "Spinner cluster did not stop")
		task.wait(0.2)
		result.WholeDuration = result.FinishedAt - result.StartedAt
		result.ActiveContactTime = result.FinishedAt - result.ActiveStartedAt
		local pulseAfterValue = player:GetAttribute("SpinnerPulseCount")
		local pulseAfter = if typeof(pulseAfterValue) == "number" then pulseAfterValue else pulseBefore
		result.PulseCount = pulseAfter - pulseBefore
		for _, target in targets do
			local damage = initialHealth[target] - getBreakableHealth(target)
			result.DamageByTarget[target.Name] = damage
			result.TotalDamage += damage
		end
		result.CombinedDPS = if result.ActiveContactTime > 0 then result.TotalDamage / result.ActiveContactTime else 0
		result.XPGained = calculateXPFromLevelEight() - xpBefore
		local acceptedAfterValue = player:GetAttribute("SpinnerAcceptedRequestCount")
		local rejectedAfterValue = player:GetAttribute("SpinnerRejectedRequestCount")
		result.AcceptedRequests = (if typeof(acceptedAfterValue) == "number" then acceptedAfterValue else acceptedBefore)
			- acceptedBefore
		result.RejectedRequests = (if typeof(rejectedAfterValue) == "number" then rejectedAfterValue else rejectedBefore)
			- rejectedBefore
		local expectedMaximumTargets = math.min(#targets, SpinnerConfig.MaximumTargetsPerPulse)
		assert(result.TargetsInFirstPulse == expectedMaximumTargets, string.format(
			"Expected %d targets in the first pulse, observed %d",
			expectedMaximumTargets,
			result.TargetsInFirstPulse
		))
		assert(result.MaximumTargetsInOnePulse == expectedMaximumTargets, string.format(
			"Expected %d targets in one pulse, observed %d",
			expectedMaximumTargets,
			result.MaximumTargetsInOnePulse
		))
		result.Status = "Complete"
	end, debug.traceback)

	drive.mode = "Stop"
	drive.smoothedVelocity = Vector3.zero
	driveConnection:Disconnect()
	if restoreRobotController and robotController ~= nil and robotController:IsA("LocalScript") then
		robotController.Enabled = true
	end
	if not ok then
		result.Status = "Failed"
		result.Failure = tostring(failure)
		result.FinishedAt = Workspace:GetServerTimeNow()
	end
	return result
end

local Level8BalanceMeasurementRunner = {}

function Level8BalanceMeasurementRunner.RunAsync(classId: string): boolean
	if running or not RunService:IsStudio() then
		return false
	end
	running = true
	currentResult = nil
	task.spawn(function()
		local ok, result = pcall(runRoute, classId)
		if ok then
			currentResult = result
		else
			currentResult = {
				ClassId = classId,
				Status = "Failed",
				StartedAt = 0,
				FinishedAt = Workspace:GetServerTimeNow(),
				Elapsed = 0,
				TravelTime = 0,
				CombatTime = 0,
				XPGained = 0,
				XPPerMinute = 0,
				Level9At = nil,
				Level10At = nil,
				Level11At = nil,
				AttackAttempts = 0,
				AcceptedAttacks = 0,
				RejectedAttacks = 0,
				AcceptedRequests = 0,
				RejectedRequests = 0,
				Misses = 0,
				UnaffectedPulses = 0,
				Destroyed = {},
				RouteNames = {},
				TargetTimings = {},
				MissReasons = {},
				RammerDestroyCooldownSamples = {},
				RammerNonDestroyCooldownSamples = {},
				Failure = tostring(result),
			}
		end
		running = false
	end)
	return true
end

function Level8BalanceMeasurementRunner.RunSpinnerClusterAsync(): boolean
	if running or not RunService:IsStudio() then
		return false
	end
	running = true
	currentClusterResult = nil
	task.spawn(function()
		local ok, result = pcall(runSpinnerCluster)
		if ok then
			currentClusterResult = result
		else
			currentClusterResult = {
				Status = "Failed",
				ClusterSize = 0,
				StartedAt = 0,
				ActiveStartedAt = 0,
				FinishedAt = Workspace:GetServerTimeNow(),
				WholeDuration = 0,
				ActiveContactTime = 0,
				PulseCount = 0,
				TargetsInFirstPulse = 0,
				MaximumTargetsInOnePulse = 0,
				TotalDamage = 0,
				CombinedDPS = 0,
				XPGained = 0,
				AcceptedRequests = 0,
				RejectedRequests = 0,
				DamageByTarget = {},
				Failure = tostring(result),
			}
		end
		running = false
	end)
	return true
end

function Level8BalanceMeasurementRunner.RunRammerTargetFixtureAsync(): boolean
	if running or not RunService:IsStudio() then
		return false
	end
	running = true
	currentResult = nil
	task.spawn(function()
		local ok, result = pcall(runRammerTargetFixture)
		if ok then
			currentResult = result
		else
			currentResult = {
				ClassId = ClassConfig.RammerClassId,
				Status = "Failed",
				StartedAt = 0,
				FinishedAt = Workspace:GetServerTimeNow(),
				Elapsed = 0,
				TravelTime = 0,
				CombatTime = 0,
				XPGained = 0,
				XPPerMinute = 0,
				Level9At = nil,
				Level10At = nil,
				Level11At = nil,
				AttackAttempts = 0,
				AcceptedAttacks = 0,
				RejectedAttacks = 0,
				AcceptedRequests = 0,
				RejectedRequests = 0,
				Misses = 0,
				UnaffectedPulses = 0,
				Destroyed = {},
				RouteNames = {},
				TargetTimings = {},
				MissReasons = {},
				RammerDestroyCooldownSamples = {},
				RammerNonDestroyCooldownSamples = {},
				Failure = tostring(result),
			}
		end
		running = false
	end)
	return true
end

function Level8BalanceMeasurementRunner.GetStatus(): string
	if running then
		if currentResult ~= nil then
			return currentResult.Status
		end
		return if currentClusterResult ~= nil then currentClusterResult.Status else "Starting"
	end
	if currentResult ~= nil then
		return currentResult.Status
	end
	return if currentClusterResult ~= nil then currentClusterResult.Status else "Idle"
end

function Level8BalanceMeasurementRunner.GetResult(): Result?
	return currentResult
end

function Level8BalanceMeasurementRunner.GetSpinnerClusterResult(): ClusterResult?
	return currentClusterResult
end

return Level8BalanceMeasurementRunner
