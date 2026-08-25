--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaConfig = require(shared:WaitForChild("ArenaConfig"))
local ExtractionConfig = require(shared:WaitForChild("ExtractionConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local AuthoritativeDamageService = require(script.Parent:WaitForChild("AuthoritativeDamageService"))
local PlayerSessionService = require(script.Parent:WaitForChild("PlayerSessionService"))
local ProfileDataService = require(script.Parent:WaitForChild("ProfileDataService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local RammerCombatService = require(script.Parent:WaitForChild("RammerCombatService"))
local SpinnerCombatService = require(script.Parent:WaitForChild("SpinnerCombatService"))
local ImpactFoundryCombatService = require(script.Parent:WaitForChild("ImpactFoundryCombatService"))

type AttemptState = {
	phase: string,
	serial: number,
	deadline: number,
	countingStartedAt: number,
	runSerial: number,
	requestWindowStartedAt: number,
	requestsInWindow: number,
	lastRequestAt: number,
	acceptedAttempts: number,
	rejectedAttempts: number,
	timerResets: number,
	characterAddedConnection: RBXScriptConnection?,
	diedConnection: RBXScriptConnection?,
	sessionConnection: RBXScriptConnection?,
}

local GENERATED_ATTRIBUTE = "ScrapcoreExtractionGenerated"
local STATUS_REMOTE_NAME = "ExtractionStatus"
local states: {[Player]: AttemptState} = {}
local initialized = false
local statusRemote: RemoteEvent? = nil
local zonePrompt: ProximityPrompt? = nil
local heartbeatAccumulator = 0

local ExtractionService = {}

local function getOrCreateRemote(): RemoteEvent
	local remotesInstance = ReplicatedStorage:FindFirstChild("Remotes")
	if remotesInstance == nil then
		remotesInstance = Instance.new("Folder")
		remotesInstance.Name = "Remotes"
		remotesInstance.Parent = ReplicatedStorage
	elseif not remotesInstance:IsA("Folder") then
		error("ReplicatedStorage.Remotes must be a Folder")
	end
	local existing = remotesInstance:FindFirstChild(STATUS_REMOTE_NAME)
	if existing ~= nil then
		if not existing:IsA("RemoteEvent") then
			error("ReplicatedStorage.Remotes.ExtractionStatus must be a RemoteEvent")
		end
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = STATUS_REMOTE_NAME
	remote.Parent = remotesInstance
	return remote
end

local function createPart(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = transparency < 0.5
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function validatePlacement()
	local halfArena = ArenaConfig.PlayableSize * 0.5
	local halfZone = Vector2.new(ExtractionConfig.ZoneSize.X, ExtractionConfig.ZoneSize.Z) * 0.5
	local center = Vector2.new(ExtractionConfig.ZoneCenter.X, ExtractionConfig.ZoneCenter.Z)
	if
		math.abs(center.X) + halfZone.X >= halfArena.X - ArenaConfig.WallThickness
		or math.abs(center.Y) + halfZone.Y >= halfArena.Y - ArenaConfig.WallThickness
	then
		error("Extraction zone must remain fully inside the arena walls")
	end
	for _, spawnPosition in ArenaConfig.SpawnPositions do
		local spawn = Vector2.new(spawnPosition.X, spawnPosition.Z)
		if (spawn - center).Magnitude < ArenaConfig.SpawnClearance + halfZone.Magnitude then
			error("Extraction zone overlaps an arena spawn clearance")
		end
	end
	local lobbyCenter = Vector2.new(SessionConfig.LobbyCenter.X, SessionConfig.LobbyCenter.Z)
	if (lobbyCenter - center).Magnitude < 250 then
		error("Extraction zone is too close to the workshop lobby")
	end
end

local function createInstructionGui(board: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ExtractionInstructions"
	gui.Size = UDim2.fromOffset(520, 150)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 100
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(10, 20, 24)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(52, 220, 236)
	stroke.Thickness = 2
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 35)
	title.Font = Enum.Font.GothamBold
	title.Text = ExtractionConfig.PortalTitle
	title.TextColor3 = Color3.fromRGB(80, 230, 245)
	title.TextSize = 25
	title.Parent = frame

	local instructions = Instance.new("TextLabel")
	instructions.Name = "Conditions"
	instructions.BackgroundTransparency = 1
	instructions.Position = UDim2.fromOffset(12, 45)
	instructions.Size = UDim2.new(1, -24, 1, -52)
	instructions.Font = Enum.Font.GothamMedium
	instructions.Text = ExtractionConfig.PortalInstructions
	instructions.TextColor3 = Color3.fromRGB(235, 240, 242)
	instructions.TextSize = 15
	instructions.TextWrapped = true
	instructions.TextYAlignment = Enum.TextYAlignment.Top
	instructions.Parent = frame
end

local function buildExtractionZone(): ProximityPrompt
	validatePlacement()
	local arena = Workspace:WaitForChild("GrayboxArena")
	local existing = arena:FindFirstChild(ExtractionConfig.ZoneName)
	if existing ~= nil then
		if existing:GetAttribute(GENERATED_ATTRIBUTE) ~= true then
			error(string.format("Preserving non-generated %s; relocate it before extraction generation", existing:GetFullName()))
		end
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = ExtractionConfig.ZoneName
	model:SetAttribute(GENERATED_ATTRIBUTE, true)
	model:SetAttribute("ExtractionDuration", ExtractionConfig.ExtractionDuration)
	model.Parent = arena

	local center = ExtractionConfig.ZoneCenter
	local padY = ArenaConfig.FloorCenter.Y + ArenaConfig.FloorThickness * 0.5 + 0.06
	local cyan = Color3.fromRGB(46, 217, 235)
	local dark = Color3.fromRGB(23, 42, 48)
	createPart(
		model,
		"ExtractionPad",
		Vector3.new(center.X, padY, center.Z),
		Vector3.new(ExtractionConfig.ZoneSize.X, 0.12, ExtractionConfig.ZoneSize.Z),
		dark,
		Enum.Material.Metal,
		0.1
	)
	local halfX = ExtractionConfig.ZoneSize.X * 0.5
	local halfZ = ExtractionConfig.ZoneSize.Z * 0.5
	createPart(model, "NorthBoundary", Vector3.new(center.X, padY + 0.08, center.Z - halfZ), Vector3.new(ExtractionConfig.ZoneSize.X, 0.16, 0.35), cyan, Enum.Material.Neon, 0.1)
	createPart(model, "SouthBoundary", Vector3.new(center.X, padY + 0.08, center.Z + halfZ), Vector3.new(ExtractionConfig.ZoneSize.X, 0.16, 0.35), cyan, Enum.Material.Neon, 0.1)
	createPart(model, "WestBoundary", Vector3.new(center.X - halfX, padY + 0.08, center.Z), Vector3.new(0.35, 0.16, ExtractionConfig.ZoneSize.Z), cyan, Enum.Material.Neon, 0.1)
	createPart(model, "EastBoundary", Vector3.new(center.X + halfX, padY + 0.08, center.Z), Vector3.new(0.35, 0.16, ExtractionConfig.ZoneSize.Z), cyan, Enum.Material.Neon, 0.1)

	local portalZ = center.Z + halfZ - 1
	createPart(model, "PortalLeft", Vector3.new(center.X - 4.6, 3.6, portalZ), Vector3.new(1.1, 5.2, 1.1), cyan, Enum.Material.Metal, 0)
	createPart(model, "PortalRight", Vector3.new(center.X + 4.6, 3.6, portalZ), Vector3.new(1.1, 5.2, 1.1), cyan, Enum.Material.Metal, 0)
	createPart(model, "PortalBeam", Vector3.new(center.X, 6.0, portalZ), Vector3.new(10.3, 0.9, 1.1), cyan, Enum.Material.Neon, 0.05)
	local board = createPart(model, "InstructionBoard", Vector3.new(center.X, 6.7, center.Z - halfZ + 1), Vector3.new(1, 1, 1), cyan, Enum.Material.SmoothPlastic, 1)
	createInstructionGui(board)

	local promptAnchor = createPart(model, "PromptAnchor", Vector3.new(center.X, 2.5, center.Z), Vector3.new(1, 1, 1), cyan, Enum.Material.SmoothPlastic, 1)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BeginExtractionPrompt"
	prompt.ActionText = "BANK RUN XP"
	prompt.ObjectText = "10-SECOND EXTRACTION"
	prompt.HoldDuration = ExtractionConfig.PromptHoldDuration
	prompt.MaxActivationDistance = ExtractionConfig.PromptActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = promptAnchor
	model.PrimaryPart = promptAnchor
	return prompt
end

local function fireStatus(player: Player, state: AttemptState, status: string, value: number?)
	local remote = statusRemote
	if remote ~= nil then
		remote:FireClient(player, status, state.serial, value)
	end
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

local function isInsideZone(root: BasePart): boolean
	local offset = root.Position - ExtractionConfig.ZoneCenter
	local half = ExtractionConfig.ZoneSize * 0.5
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Y) <= half.Y
		and math.abs(offset.Z) <= half.Z
end

local function clearAttempt(player: Player, state: AttemptState, status: string?)
	if state.phase == "Idle" then
		return
	end
	state.phase = "Idle"
	state.deadline = 0
	state.countingStartedAt = 0
	state.runSerial = -1
	if status ~= nil then
		fireStatus(player, state, status, nil)
	end
end

local function rejectAttempt(player: Player, state: AttemptState, status: string?)
	state.rejectedAttempts += 1
	player:SetAttribute("ExtractionRejectedAttemptCount", state.rejectedAttempts)
	if status ~= nil then
		fireStatus(player, state, status, nil)
	end
end

local function consumeRequestRate(player: Player, state: AttemptState, now: number): boolean
	if now - state.requestWindowStartedAt >= ExtractionConfig.RequestRateWindow then
		state.requestWindowStartedAt = now
		state.requestsInWindow = 0
	end
	state.requestsInWindow += 1
	if
		state.requestsInWindow > ExtractionConfig.MaximumRequestsPerWindow
		or now - state.lastRequestAt < ExtractionConfig.MinimumRequestInterval
	then
		state.lastRequestAt = now
		rejectAttempt(player, state, nil)
		return false
	end
	state.lastRequestAt = now
	return true
end

local function startAttempt(player: Player): boolean
	local state = states[player]
	if state == nil then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	if not consumeRequestRate(player, state, now) then
		return false
	end
	if state.phase ~= "Idle" then
		rejectAttempt(player, state, nil)
		return false
	end
	local _character, humanoid, root = getAliveCharacter(player)
	local unbankedXP = ProgressionService.GetUnbankedRunXP(player)
	if
		not PlayerSessionService.IsArena(player)
		or humanoid == nil
		or root == nil
		or not isInsideZone(root)
		or unbankedXP <= 0
		or not ProfileDataService.IsLoaded(player)
	then
		rejectAttempt(player, state, if not ProfileDataService.IsLoaded(player) then "BankingFailed" else nil)
		return false
	end
	local runSerial = ProgressionService.GetRunSerial(player)
	if not ProgressionService.IsRunActive(player, runSerial) then
		rejectAttempt(player, state, nil)
		return false
	end

	state.serial += 1
	state.phase = "Counting"
	state.countingStartedAt = now
	state.deadline = now + ExtractionConfig.ExtractionDuration
	state.runSerial = runSerial
	state.acceptedAttempts += 1
	player:SetAttribute("ExtractionAcceptedAttemptCount", state.acceptedAttempts)
	fireStatus(player, state, "Started", state.deadline)
	return true
end

local function completeAttempt(player: Player, state: AttemptState, serial: number, runSerial: number, amount: number)
	local success, bankedXP = ProfileDataService.BankRunXP(player, amount, runSerial)
	if states[player] ~= state or state.serial ~= serial or state.phase ~= "Banking" then
		return
	end
	if not success then
		state.phase = "Idle"
		state.deadline = 0
		state.countingStartedAt = 0
		state.runSerial = -1
		fireStatus(player, state, "BankingFailed", bankedXP)
		return
	end

	state.phase = "Idle"
	state.deadline = 0
	state.countingStartedAt = 0
	state.runSerial = -1
	fireStatus(player, state, "Banked", amount)
	SpinnerCombatService.CancelForPlayer(player)
	RammerCombatService.CancelForPlayer(player)
	ImpactFoundryCombatService.CancelForPlayer(player)
	PlayerSessionService.ReturnToLobby(player)
end

local function updateAttempts(deltaTime: number)
	if deltaTime <= 0 then
		return
	end
	heartbeatAccumulator += deltaTime
	if heartbeatAccumulator < ExtractionConfig.ServerUpdateInterval then
		return
	end
	heartbeatAccumulator = 0
	local now = Workspace:GetServerTimeNow()
	for player, state in states do
		if state.phase ~= "Counting" then
			continue
		end
		local _character, humanoid, root = getAliveCharacter(player)
		if
			humanoid == nil
			or root == nil
			or not PlayerSessionService.IsArena(player)
			or not ProgressionService.IsRunActive(player, state.runSerial)
			or ProgressionService.GetUnbankedRunXP(player) <= 0
		then
			clearAttempt(player, state, nil)
			continue
		end
		if not isInsideZone(root) then
			clearAttempt(player, state, "Cancelled")
			continue
		end
		if now >= state.deadline then
			local amount = ProgressionService.GetUnbankedRunXP(player)
			if amount <= 0 then
				clearAttempt(player, state, nil)
				continue
			end
			state.phase = "Banking"
			player:SetAttribute("ExtractionLastQualifiedDuration", now - state.countingStartedAt)
			local serial = state.serial
			local runSerial = state.runSerial
			task.spawn(completeAttempt, player, state, serial, runSerial, amount)
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
	clearAttempt(player, state, nil)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if
			humanoid == nil
			or not humanoid:IsA("Humanoid")
			or states[player] ~= state
			or player.Character ~= character
		then
			return
		end
		state.diedConnection = humanoid.Died:Connect(function()
			if states[player] == state then
				clearAttempt(player, state, nil)
			end
		end)
	end)
end

local function connectPlayer(player: Player)
	if states[player] ~= nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local state: AttemptState = {
		phase = "Idle",
		serial = 0,
		deadline = 0,
		countingStartedAt = 0,
		runSerial = -1,
		requestWindowStartedAt = now,
		requestsInWindow = 0,
		lastRequestAt = -math.huge,
		acceptedAttempts = 0,
		rejectedAttempts = 0,
		timerResets = 0,
		characterAddedConnection = nil,
		diedConnection = nil,
		sessionConnection = nil,
	}
	states[player] = state
	player:SetAttribute("ExtractionAcceptedAttemptCount", 0)
	player:SetAttribute("ExtractionRejectedAttemptCount", 0)
	player:SetAttribute("ExtractionTimerResetCount", 0)
	player:SetAttribute("ExtractionLastQualifiedDuration", 0)
	state.characterAddedConnection = player.CharacterAdded:Connect(function(character: Model)
		bindCharacter(player, character)
	end)
	state.sessionConnection = player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(function()
		if not PlayerSessionService.IsArena(player) then
			clearAttempt(player, state, nil)
		end
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
	if state.sessionConnection ~= nil then
		state.sessionConnection:Disconnect()
	end
	states[player] = nil
end

function ExtractionService.TryStartForStudioTest(player: Player): boolean
	return RunService:IsStudio() and startAttempt(player)
end

function ExtractionService.GetStudioDebugSnapshot(player: Player): any
	if not RunService:IsStudio() then
		return nil
	end
	local state = states[player]
	if state == nil then
		return nil
	end
	local _character, humanoid, root = getAliveCharacter(player)
	return {
		phase = state.phase,
		serial = state.serial,
		deadline = state.deadline,
		countingStartedAt = state.countingStartedAt,
		runSerial = state.runSerial,
		insideZone = root ~= nil and isInsideZone(root),
		alive = humanoid ~= nil,
		unbankedXP = ProgressionService.GetUnbankedRunXP(player),
		bankedXP = ProfileDataService.GetBankedXP(player),
		acceptedAttempts = state.acceptedAttempts,
		rejectedAttempts = state.rejectedAttempts,
		timerResets = state.timerResets,
	}
end

function ExtractionService.Init()
	if initialized then
		return
	end
	initialized = true
	ProfileDataService.Init()
	PlayerSessionService.Init()
	ProgressionService.Init()
	SpinnerCombatService.Init()
	RammerCombatService.Init()
	ImpactFoundryCombatService.Init()
	statusRemote = getOrCreateRemote()
	zonePrompt = buildExtractionZone()
	local activeZonePrompt = zonePrompt :: ProximityPrompt
	activeZonePrompt.Triggered:Connect(startAttempt)
	AuthoritativeDamageService.Connect(function(player: Player, _amount: number, serverTime: number)
		local state = states[player]
		if state == nil or state.phase ~= "Counting" then
			return
		end
		state.deadline = serverTime + ExtractionConfig.ExtractionDuration
		state.countingStartedAt = serverTime
		state.timerResets += 1
		player:SetAttribute("ExtractionTimerResetCount", state.timerResets)
		fireStatus(player, state, "HitReset", state.deadline)
	end)
	RunService.Heartbeat:Connect(updateAttempts)
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return ExtractionService
