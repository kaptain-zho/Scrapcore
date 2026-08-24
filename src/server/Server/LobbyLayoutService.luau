--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local SessionConfig = require(shared:WaitForChild("SessionConfig"))

local initialized = false
local lobbyModel: Model? = nil
local lobbySpawn: SpawnLocation? = nil
local mainPortalPart: BasePart? = nil
local mainPortalPrompt: ProximityPrompt? = nil
local futurePrompts: {ProximityPrompt} = {}

local LobbyLayoutService = {}

local COLORS = table.freeze({
	Floor = Color3.fromRGB(43, 48, 55),
	Wall = Color3.fromRGB(54, 60, 68),
	Steel = Color3.fromRGB(67, 75, 84),
	DarkSteel = Color3.fromRGB(34, 39, 46),
	Cyan = Color3.fromRGB(35, 198, 225),
	CyanDim = Color3.fromRGB(28, 104, 119),
	Orange = Color3.fromRGB(230, 132, 42),
	ComingSoon = Color3.fromRGB(105, 91, 122),
	Text = Color3.fromRGB(239, 245, 248),
})

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = canCollide
	part.CanTouch = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createLabel(
	adornee: BasePart,
	name: string,
	text: string,
	width: number,
	height: number,
	offset: Vector3,
	accent: Color3
)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 150
	billboard.Size = UDim2.fromOffset(width, height)
	billboard.StudsOffsetWorldSpace = offset
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(15, 19, 24)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = COLORS.Text
	label.TextStrokeColor3 = Color3.fromRGB(4, 6, 8)
	label.TextStrokeTransparency = 0.45
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Transparency = 0.1
	stroke.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = label
end

local function createPortalFrame(
	parent: Instance,
	name: string,
	position: Vector3,
	accent: Color3,
	labelText: string,
	active: boolean
): (Model, Part, ProximityPrompt)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("PortalActive", active)
	model.Parent = parent

	createPart(
		model,
		"LeftPost",
		Vector3.new(1.4, 8.5, 1.6),
		CFrame.new(position + Vector3.new(-6.1, 0, 0)),
		COLORS.Steel,
		Enum.Material.Metal,
		true
	)
	createPart(
		model,
		"RightPost",
		Vector3.new(1.4, 8.5, 1.6),
		CFrame.new(position + Vector3.new(6.1, 0, 0)),
		COLORS.Steel,
		Enum.Material.Metal,
		true
	)
	local header = createPart(
		model,
		"Header",
		Vector3.new(13.6, 1.4, 1.8),
		CFrame.new(position + Vector3.new(0, 4.75, 0)),
		COLORS.DarkSteel,
		Enum.Material.Metal,
		true
	)
	local portal = createPart(
		model,
		"PortalField",
		Vector3.new(10.4, 7.2, 0.5),
		CFrame.new(position),
		accent,
		if active then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		false
	)
	portal.Transparency = if active then 0.42 else 0.68
	createLabel(header, "PortalLabel", labelText, 260, 52, Vector3.new(0, 2.2, 0), accent)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = if active then "DeployPrompt" else "ComingSoonPrompt"
	prompt.ActionText = if active then "Deploy" else "View"
	prompt.ObjectText = if active then "Main Arena" else "Coming Soon"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = if active then 0.45 else 0
	prompt.MaxActivationDistance = if active then SessionConfig.MainPortalActivationDistance else 10
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = portal
	return model, portal, prompt
end

local function createWorkshopZone(parent: Instance, center: Vector3)
	local zone = Instance.new("Model")
	zone.Name = "RobotCustomizationPlaceholder"
	zone:SetAttribute("ComingSoon", true)
	zone.Parent = parent
	local platform = createPart(
		zone,
		"DisplayPlatform",
		Vector3.new(22, 1.2, 18),
		CFrame.new(center + Vector3.new(0, 0.6, 0)),
		COLORS.DarkSteel,
		Enum.Material.Metal,
		true
	)
	createPart(zone, "LeftFrame", Vector3.new(1, 7, 1), CFrame.new(center + Vector3.new(-10, 4, -8)), COLORS.Steel, Enum.Material.Metal, true)
	createPart(zone, "RightFrame", Vector3.new(1, 7, 1), CFrame.new(center + Vector3.new(10, 4, -8)), COLORS.Steel, Enum.Material.Metal, true)
	local header = createPart(zone, "Header", Vector3.new(21, 1.2, 1.2), CFrame.new(center + Vector3.new(0, 7.3, -8)), COLORS.DarkSteel, Enum.Material.Metal, true)
	createLabel(header, "CustomizationLabel", "ROBOT CUSTOMIZATION\nCOMING SOON", 300, 68, Vector3.new(0, 2, 0), COLORS.Orange)
	createPart(zone, "DisplayPlinth", Vector3.new(8, 1, 8), CFrame.new(center + Vector3.new(0, 1.7, 0)), COLORS.CyanDim, Enum.Material.Metal, true)
	platform:SetAttribute("ReservedForFutureSkins", true)
end

local function createLeaderboard(parent: Instance, center: Vector3)
	local board = Instance.new("Model")
	board.Name = "ArenaLeadersPlaceholder"
	board:SetAttribute("ComingSoon", true)
	board.Parent = parent
	createPart(board, "LeftSupport", Vector3.new(1, 7, 1), CFrame.new(center + Vector3.new(-8.5, 0, 0)), COLORS.Steel, Enum.Material.Metal, true)
	createPart(board, "RightSupport", Vector3.new(1, 7, 1), CFrame.new(center + Vector3.new(8.5, 0, 0)), COLORS.Steel, Enum.Material.Metal, true)
	local face = createPart(board, "BlankBoard", Vector3.new(18, 8.5, 1), CFrame.new(center + Vector3.new(0, 1, 0)), COLORS.DarkSteel, Enum.Material.Metal, true)
	createLabel(face, "LeadersLabel", "ARENA LEADERS\nCOMING SOON", 300, 72, Vector3.new(0, 5.8, 0), COLORS.Cyan)
end

local function createReservedPanel(parent: Instance, name: string, center: Vector3)
	local panel = createPart(parent, name, Vector3.new(17, 7, 0.8), CFrame.new(center), COLORS.DarkSteel, Enum.Material.Metal, true)
	panel:SetAttribute("ReservedPromotionalPlacement", true)
	createLabel(panel, name .. "Label", "FUTURE ANNOUNCEMENT", 220, 38, Vector3.new(0, 4.8, 0), COLORS.Steel)
end

function LobbyLayoutService.Init()
	if initialized then
		return
	end
	initialized = true

	local existing = Workspace:FindFirstChild("WorkshopLobby")
	if existing ~= nil then
		if existing:GetAttribute(SessionConfig.LobbyGeneratedAttribute) ~= true then
			error("Workspace.WorkshopLobby exists but is not generated by LobbyLayoutService")
		end
		existing:Destroy()
	end

	local center = SessionConfig.LobbyCenter
	local size = SessionConfig.LobbySize
	local model = Instance.new("Model")
	model.Name = "WorkshopLobby"
	model:SetAttribute(SessionConfig.LobbyGeneratedAttribute, true)
	model:SetAttribute("LobbyWidth", size.X)
	model:SetAttribute("LobbyDepth", size.Y)

	createPart(
		model,
		"Floor",
		Vector3.new(size.X, SessionConfig.LobbyFloorThickness, size.Y),
		CFrame.new(center + Vector3.new(0, SessionConfig.LobbyFloorThickness * 0.5, 0)),
		COLORS.Floor,
		Enum.Material.Concrete,
		true
	)
	local wallY = SessionConfig.LobbyWallHeight * 0.5 + SessionConfig.LobbyFloorThickness
	local halfWidth = size.X * 0.5
	local halfDepth = size.Y * 0.5
	createPart(model, "NorthWall", Vector3.new(size.X + 4, SessionConfig.LobbyWallHeight, SessionConfig.LobbyWallThickness), CFrame.new(center + Vector3.new(0, wallY, -halfDepth - 1)), COLORS.Wall, Enum.Material.Concrete, true)
	createPart(model, "SouthWall", Vector3.new(size.X + 4, SessionConfig.LobbyWallHeight, SessionConfig.LobbyWallThickness), CFrame.new(center + Vector3.new(0, wallY, halfDepth + 1)), COLORS.Wall, Enum.Material.Concrete, true)
	createPart(model, "WestWall", Vector3.new(SessionConfig.LobbyWallThickness, SessionConfig.LobbyWallHeight, size.Y), CFrame.new(center + Vector3.new(-halfWidth - 1, wallY, 0)), COLORS.Wall, Enum.Material.Concrete, true)
	createPart(model, "EastWall", Vector3.new(SessionConfig.LobbyWallThickness, SessionConfig.LobbyWallHeight, size.Y), CFrame.new(center + Vector3.new(halfWidth + 1, wallY, 0)), COLORS.Wall, Enum.Material.Concrete, true)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(28, 1, 18)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 1.5, 27))
	spawn.Color = COLORS.CyanDim
	spawn.Material = Enum.Material.Metal
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.CanTouch = false
	spawn.CanQuery = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = model
	createLabel(spawn, "SpawnLabel", "WORKSHOP ARRIVAL", 230, 40, Vector3.new(0, 3, 0), COLORS.Cyan)

	local centerPad = createPart(model, "SocialFloorMark", Vector3.new(30, 0.16, 24), CFrame.new(center + Vector3.new(0, 1.08, 0)), COLORS.DarkSteel, Enum.Material.Metal, false)
	centerPad:SetAttribute("CentralSocialSpace", true)
	createPart(model, "CenterStripeNorthSouth", Vector3.new(2, 0.18, 66), CFrame.new(center + Vector3.new(0, 1.1, 0)), COLORS.CyanDim, Enum.Material.Neon, false)
	createPart(model, "CenterStripeEastWest", Vector3.new(54, 0.18, 2), CFrame.new(center + Vector3.new(0, 1.1, 0)), COLORS.CyanDim, Enum.Material.Neon, false)

	local _, portalPart, portalPrompt = createPortalFrame(
		model,
		"MainArenaPortal",
		SessionConfig.MainPortalPosition,
		COLORS.Cyan,
		"MAIN ARENA",
		true
	)
	mainPortalPart = portalPart
	mainPortalPrompt = portalPrompt

	local futureDefinitions = {
		{ name = "DuelsPortal", label = "DUELS\nCOMING SOON", position = center + Vector3.new(-42, 4.5, -26) },
		{ name = "TeamBattlePortal", label = "TEAM BATTLE\nCOMING SOON", position = center + Vector3.new(42, 4.5, -26) },
		{ name = "RankedPortal", label = "RANKED\nCOMING SOON", position = center + Vector3.new(48, 4.5, 2) },
	}
	for _, definition in futureDefinitions do
		local _, _, prompt = createPortalFrame(
			model,
			definition.name,
			definition.position,
			COLORS.ComingSoon,
			definition.label,
			false
		)
		table.insert(futurePrompts, prompt)
	end

	createWorkshopZone(model, center + Vector3.new(-43, 0, 8))
	createLeaderboard(model, center + Vector3.new(27, 4.3, 36))
	createReservedPanel(model, "ReservedAnnouncementWest", center + Vector3.new(-55, 5, -8))
	createReservedPanel(model, "ReservedAnnouncementEast", center + Vector3.new(55, 5, 20))

	model.Parent = Workspace
	lobbyModel = model
	lobbySpawn = spawn

	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant ~= spawn then
			descendant.Enabled = false
		end
	end
end

function LobbyLayoutService.GetLobby(): Model
	LobbyLayoutService.Init()
	return lobbyModel :: Model
end

function LobbyLayoutService.GetLobbySpawn(): SpawnLocation
	LobbyLayoutService.Init()
	return lobbySpawn :: SpawnLocation
end

function LobbyLayoutService.GetMainPortalPart(): BasePart
	LobbyLayoutService.Init()
	return mainPortalPart :: BasePart
end

function LobbyLayoutService.GetMainPortalPrompt(): ProximityPrompt
	LobbyLayoutService.Init()
	return mainPortalPrompt :: ProximityPrompt
end

function LobbyLayoutService.GetFuturePrompts(): {ProximityPrompt}
	LobbyLayoutService.Init()
	return futurePrompts
end

return LobbyLayoutService
