--!strict

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local upgradeRequestRemote = remotes:WaitForChild("ProgressionUpgradeRequest") :: RemoteEvent

type UpgradeDefinition = {
	AttributeName: string,
	DisplayName: string,
	Description: string,
}

local upgradeDefinitions = ProgressionConfig.Upgrades :: {[string]: UpgradeDefinition}
local DEV_UNLIMITED_ATTRIBUTE = "DevUnlimitedUpgradePoints"
local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("ScrapcoreProgressionHUD")
if oldGui ~= nil then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScrapcoreProgressionHUD"
screenGui.DisplayOrder = 20
screenGui.IgnoreGuiInset = false
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -12, 0, 12)
panel.Size = UDim2.new(0.24, 0, 0, 96)
panel.BackgroundColor3 = Color3.fromRGB(13, 18, 25)
panel.BackgroundTransparency = 0.18
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelSizeConstraint = Instance.new("UISizeConstraint")
panelSizeConstraint.MinSize = Vector2.new(210, 96)
panelSizeConstraint.MaxSize = Vector2.new(280, 348)
panelSizeConstraint.Parent = panel

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(58, 78, 96)
panelStroke.Transparency = 0.15
panelStroke.Thickness = 1
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "RUN GROWTH"
title.TextColor3 = Color3.fromRGB(90, 220, 255)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.fromOffset(10, 5)
title.Size = UDim2.new(1, -20, 0, 18)
title.Parent = panel

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "Level"
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextColor3 = Color3.fromRGB(240, 245, 250)
levelLabel.TextSize = 13
levelLabel.TextXAlignment = Enum.TextXAlignment.Left
levelLabel.Position = UDim2.fromOffset(10, 25)
levelLabel.Size = UDim2.new(0.5, -10, 0, 18)
levelLabel.Parent = panel

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name = "Points"
pointsLabel.BackgroundTransparency = 1
pointsLabel.Font = Enum.Font.GothamBold
pointsLabel.TextColor3 = Color3.fromRGB(255, 205, 70)
pointsLabel.TextSize = 12
pointsLabel.TextXAlignment = Enum.TextXAlignment.Right
pointsLabel.Position = UDim2.new(0.5, 0, 0, 25)
pointsLabel.Size = UDim2.new(0.5, -10, 0, 18)
pointsLabel.Parent = panel

local xpBarBackground = Instance.new("Frame")
xpBarBackground.Name = "XPBarBackground"
xpBarBackground.BackgroundColor3 = Color3.fromRGB(40, 48, 60)
xpBarBackground.BorderSizePixel = 0
xpBarBackground.Position = UDim2.fromOffset(10, 49)
xpBarBackground.Size = UDim2.new(1, -20, 0, 18)
xpBarBackground.Parent = panel

local xpBarCorner = Instance.new("UICorner")
xpBarCorner.CornerRadius = UDim.new(0, 5)
xpBarCorner.Parent = xpBarBackground

local xpFill = Instance.new("Frame")
xpFill.Name = "XPFill"
xpFill.BackgroundColor3 = Color3.fromRGB(35, 185, 240)
xpFill.BorderSizePixel = 0
xpFill.Size = UDim2.fromScale(0, 1)
xpFill.Parent = xpBarBackground

local xpFillCorner = Instance.new("UICorner")
xpFillCorner.CornerRadius = UDim.new(0, 5)
xpFillCorner.Parent = xpFill

local xpLabel = Instance.new("TextLabel")
xpLabel.Name = "XP"
xpLabel.BackgroundTransparency = 1
xpLabel.Font = Enum.Font.GothamMedium
xpLabel.TextColor3 = Color3.fromRGB(245, 248, 252)
xpLabel.TextSize = 11
xpLabel.Size = UDim2.fromScale(1, 1)
xpLabel.ZIndex = 2
xpLabel.Parent = xpBarBackground

local classControlLabel = Instance.new("TextLabel")
classControlLabel.Name = "ClassControl"
classControlLabel.BackgroundTransparency = 1
classControlLabel.Font = Enum.Font.GothamBold
classControlLabel.Text = "SPINNER — Hold LMB to Spin"
classControlLabel.TextColor3 = Color3.fromRGB(196, 145, 245)
classControlLabel.TextSize = 10
classControlLabel.TextXAlignment = Enum.TextXAlignment.Left
classControlLabel.Position = UDim2.fromOffset(10, 70)
classControlLabel.Size = UDim2.new(1, -20, 0, 17)
classControlLabel.Visible = false
classControlLabel.Parent = panel

local evolutionStatusLabel = Instance.new("TextLabel")
evolutionStatusLabel.Name = "EvolutionStatus"
evolutionStatusLabel.BackgroundTransparency = 1
evolutionStatusLabel.Font = Enum.Font.GothamMedium
evolutionStatusLabel.Text = "Evolution at Level 8"
evolutionStatusLabel.TextColor3 = Color3.fromRGB(170, 185, 198)
evolutionStatusLabel.TextSize = 10
evolutionStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
evolutionStatusLabel.Position = UDim2.fromOffset(10, 70)
evolutionStatusLabel.Size = UDim2.new(1, -20, 0, 17)
evolutionStatusLabel.Parent = panel

local upgradeToggleButton = Instance.new("TextButton")
upgradeToggleButton.Name = "UpgradeToggleButton"
upgradeToggleButton.Position = UDim2.fromOffset(6, 3)
upgradeToggleButton.Size = UDim2.fromOffset(44, 44)
upgradeToggleButton.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
upgradeToggleButton.BorderSizePixel = 0
upgradeToggleButton.Font = Enum.Font.GothamBold
upgradeToggleButton.Text = "E"
upgradeToggleButton.TextColor3 = Color3.fromRGB(25, 28, 31)
upgradeToggleButton.TextSize = 18
upgradeToggleButton.Visible = false
upgradeToggleButton.Parent = panel

local upgradeToggleCorner = Instance.new("UICorner")
upgradeToggleCorner.CornerRadius = UDim.new(0, 7)
upgradeToggleCorner.Parent = upgradeToggleButton

local healthPanel = Instance.new("Frame")
healthPanel.Name = "PlayerHealth"
healthPanel.AnchorPoint = Vector2.new(0.5, 0)
healthPanel.Position = UDim2.new(0.5, 0, 0, 12)
healthPanel.Size = UDim2.fromOffset(600, 42)
healthPanel.BackgroundColor3 = Color3.fromRGB(13, 18, 25)
healthPanel.BackgroundTransparency = 0.18
healthPanel.BorderSizePixel = 0
healthPanel.Visible = false
healthPanel.Parent = screenGui

local healthSizeConstraint = Instance.new("UISizeConstraint")
healthSizeConstraint.MinSize = Vector2.new(220, 42)
healthSizeConstraint.MaxSize = Vector2.new(720, 42)
healthSizeConstraint.Parent = healthPanel

local healthCorner = Instance.new("UICorner")
healthCorner.CornerRadius = UDim.new(0, 7)
healthCorner.Parent = healthPanel

local healthLabel = Instance.new("TextLabel")
healthLabel.Name = "HealthText"
healthLabel.BackgroundTransparency = 1
healthLabel.Font = Enum.Font.GothamBold
healthLabel.TextColor3 = Color3.fromRGB(240, 245, 250)
healthLabel.TextSize = 12
healthLabel.TextXAlignment = Enum.TextXAlignment.Center
healthLabel.Position = UDim2.fromOffset(9, 3)
healthLabel.Size = UDim2.new(1, -18, 0, 17)
healthLabel.Parent = healthPanel

local healthBarBackground = Instance.new("Frame")
healthBarBackground.Name = "HealthBarBackground"
healthBarBackground.BackgroundColor3 = Color3.fromRGB(40, 48, 60)
healthBarBackground.BorderSizePixel = 0
healthBarBackground.Position = UDim2.fromOffset(9, 24)
healthBarBackground.Size = UDim2.new(1, -18, 0, 10)
healthBarBackground.Parent = healthPanel

local healthBarCorner = Instance.new("UICorner")
healthBarCorner.CornerRadius = UDim.new(0, 4)
healthBarCorner.Parent = healthBarBackground

local healthFill = Instance.new("Frame")
healthFill.Name = "HealthFill"
healthFill.BackgroundColor3 = Color3.fromRGB(70, 220, 130)
healthFill.BorderSizePixel = 0
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.Parent = healthBarBackground

local healthFillCorner = Instance.new("UICorner")
healthFillCorner.CornerRadius = UDim.new(0, 4)
healthFillCorner.Parent = healthFill

local function updateResponsiveLayout()
	local currentCamera = Workspace.CurrentCamera
	if currentCamera == nil then
		return
	end
	local viewport = currentCamera.ViewportSize
	local healthWidth: number
	if viewport.X >= 900 then
		healthWidth = math.clamp(viewport.X * 0.5, 420, 720)
	elseif viewport.X > viewport.Y then
		healthWidth = math.clamp(viewport.X * 0.72, 280, 540)
	else
		healthWidth = math.clamp(viewport.X - 24, 220, 420)
	end
	healthPanel.Size = UDim2.fromOffset(healthWidth, 42)
	healthPanel.Position = UDim2.new(0.5, 0, 0, 12)
	panel.Position = UDim2.new(1, -12, 0, if viewport.X >= 900 then 12 else 66)
end

local viewportConnection: RBXScriptConnection? = nil
local function connectCurrentCamera()
	if viewportConnection ~= nil then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	local currentCamera = Workspace.CurrentCamera
	if currentCamera ~= nil then
		viewportConnection = currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
	updateResponsiveLayout()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCurrentCamera)
connectCurrentCamera()

local upgradeHeader = Instance.new("TextLabel")
upgradeHeader.Name = "UpgradeHeader"
upgradeHeader.BackgroundTransparency = 1
upgradeHeader.Font = Enum.Font.GothamBold
upgradeHeader.Text = "SPEND 1 POINT"
upgradeHeader.TextColor3 = Color3.fromRGB(180, 190, 205)
upgradeHeader.TextSize = 12
upgradeHeader.TextXAlignment = Enum.TextXAlignment.Left
upgradeHeader.Position = UDim2.fromOffset(10, 100)
upgradeHeader.Size = UDim2.new(1, -20, 0, 18)
upgradeHeader.Visible = false
upgradeHeader.Parent = panel

local buttonContainer = Instance.new("Frame")
buttonContainer.Name = "UpgradeButtons"
buttonContainer.BackgroundTransparency = 1
buttonContainer.Position = UDim2.fromOffset(10, 122)
buttonContainer.Size = UDim2.new(1, -20, 0, 196)
buttonContainer.Visible = false
buttonContainer.Parent = panel

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 4)
buttonLayout.FillDirection = Enum.FillDirection.Vertical
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonContainer

local buttons: {[string]: TextButton} = {}
local lastRequestAt = -math.huge

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getIntegerAttribute(name: string, minimum: number, maximum: number): number
	local value = player:GetAttribute(name)
	if typeof(value) ~= "number" or not isFinite(value) then
		return minimum
	end
	return math.clamp(math.floor(value), minimum, maximum)
end

for order, category in ProgressionConfig.UpgradeOrder do
	local definition = upgradeDefinitions[category]
	local button = Instance.new("TextButton")
	button.Name = category .. "Button"
	button.LayoutOrder = order
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(35, 55, 68)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextColor3 = Color3.fromRGB(235, 242, 248)
	button.TextSize = 12
	button.TextWrapped = false
	button.Size = UDim2.new(1, 0, 0, 36)
	button.Parent = buttonContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = button

	button.Activated:Connect(function()
		local unlimitedPoints = player:GetAttribute(DEV_UNLIMITED_ATTRIBUTE) == true
		local points = getIntegerAttribute(
			"UnspentUpgradePoints",
			0,
			ProgressionConfig.MaxUnspentUpgradePoints
		)
		local rank = getIntegerAttribute(
			definition.AttributeName,
			0,
			ProgressionConfig.MaxUpgradeRank
		)
		if (not unlimitedPoints and points <= 0) or rank >= ProgressionConfig.MaxUpgradeRank then
			return
		end
		local now = Workspace:GetServerTimeNow()
		if now - lastRequestAt < ProgressionConfig.MinimumUpgradeRequestInterval then
			return
		end
		lastRequestAt = now
		upgradeRequestRemote:FireServer(category, rank + 1)
	end)
	buttons[category] = button
end

local upgradeMenuOpen = false
local pendingAutomaticUpgradeOpen = false
local lastObservedPoints: number? = nil
local lastObservedUnlimited = false

local function getEvolutionPanel(): GuiObject?
	local evolutionGui = playerGui:FindFirstChild("ClassEvolutionHUD")
	if evolutionGui == nil or not evolutionGui:IsA("ScreenGui") then
		return nil
	end
	local evolutionPanel = evolutionGui:FindFirstChild("EvolutionPanel")
	return if evolutionPanel ~= nil and evolutionPanel:IsA("GuiObject") then evolutionPanel else nil
end

local function isEvolutionBlocking(): boolean
	if player:GetAttribute("ClassEvolutionEligible") ~= true then
		return false
	end
	local evolutionPanel = getEvolutionPanel()
	return evolutionPanel == nil or evolutionPanel.Visible
end

local function updateHUD()
	local level = getIntegerAttribute("RunLevel", 1, ProgressionConfig.LevelCap)
	local xp = getIntegerAttribute("RunXP", 0, ProgressionConfig.MaxServerXPAward)
	local xpToNext = getIntegerAttribute("XPToNextLevel", 0, ProgressionConfig.MaxServerXPAward)
	local points = getIntegerAttribute(
		"UnspentUpgradePoints",
		0,
		ProgressionConfig.MaxUnspentUpgradePoints
	)
	local unlimitedPoints = player:GetAttribute(DEV_UNLIMITED_ATTRIBUTE) == true
	local classValue = player:GetAttribute(ClassConfig.ClassAttribute)
	local classId = if typeof(classValue) == "string"
		then classValue :: string
		else ClassConfig.BaseClassId
	local hasSelectedLevel8Class = classId == ClassConfig.StrikerClassId
		or classId == ClassConfig.SpinnerClassId
		or classId == ClassConfig.RammerClassId
	local showSpinnerControl = classId == ClassConfig.SpinnerClassId
	local showRammerControl = classId == ClassConfig.RammerClassId
	local showClassControl = showSpinnerControl or showRammerControl
	local initiallyAvailable = lastObservedPoints == nil and points > 0
	local gainedPoint = lastObservedPoints ~= nil and points > (lastObservedPoints :: number)
	local gainedUnlimited = unlimitedPoints and not lastObservedUnlimited
	local evolutionBlocking = isEvolutionBlocking()
	if points <= 0 and not unlimitedPoints then
		upgradeMenuOpen = false
		pendingAutomaticUpgradeOpen = false
	elseif evolutionBlocking then
		if upgradeMenuOpen or initiallyAvailable or gainedPoint or gainedUnlimited then
			pendingAutomaticUpgradeOpen = true
		end
		upgradeMenuOpen = false
	elseif pendingAutomaticUpgradeOpen then
		upgradeMenuOpen = true
		pendingAutomaticUpgradeOpen = false
	elseif initiallyAvailable or gainedPoint or gainedUnlimited then
		upgradeMenuOpen = true
	end
	lastObservedPoints = points
	lastObservedUnlimited = unlimitedPoints

	levelLabel.Text = string.format("LEVEL %d", level)
	pointsLabel.Text = if unlimitedPoints
		then "∞ POINTS"
		else string.format("%d %s", points, if points == 1 then "POINT" else "POINTS")
	if level >= ProgressionConfig.LevelCap or xpToNext <= 0 then
		xpLabel.Text = "LEVEL CAP"
		xpFill.Size = UDim2.fromScale(1, 1)
	else
		xpLabel.Text = string.format("%d / %d XP", xp, xpToNext)
		xpFill.Size = UDim2.fromScale(math.clamp(xp / xpToNext, 0, 1), 1)
	end

	classControlLabel.Visible = showClassControl
	if showRammerControl then
		classControlLabel.Text = "RAMMER — Hold LMB, Release to Charge"
		classControlLabel.TextColor3 = ClassConfig.RammerAccentColor
	else
		classControlLabel.Text = "SPINNER — Hold LMB to Spin"
		classControlLabel.TextColor3 = ClassConfig.SpinnerAccentColor
	end
	local statusY = if showClassControl then 88 else 70
	evolutionStatusLabel.Position = UDim2.fromOffset(10, statusY)
	if hasSelectedLevel8Class and level >= ClassConfig.Level20Threshold then
		evolutionStatusLabel.Text = "Level 20 Evolution — Coming Soon"
		evolutionStatusLabel.TextColor3 = Color3.fromRGB(196, 145, 245)
	elseif hasSelectedLevel8Class then
		evolutionStatusLabel.Text = "Next Evolution at Level 20"
		evolutionStatusLabel.TextColor3 = Color3.fromRGB(170, 185, 198)
	elseif level >= ClassConfig.Level8Threshold then
		evolutionStatusLabel.Text = "EVOLUTION READY"
		evolutionStatusLabel.TextColor3 = Color3.fromRGB(255, 205, 70)
	else
		evolutionStatusLabel.Text = "Evolution at Level 8"
		evolutionStatusLabel.TextColor3 = Color3.fromRGB(170, 185, 198)
	end

	local showToggle = points > 0 or unlimitedPoints
	upgradeToggleButton.Visible = showToggle
	title.Position = UDim2.fromOffset(if showToggle then 58 else 10, 5)
	title.Size = UDim2.new(1, if showToggle then -68 else -20, 0, 18)
	levelLabel.Position = UDim2.fromOffset(if showToggle then 58 else 10, 25)
	levelLabel.Size = UDim2.new(0.5, if showToggle then -58 else -10, 0, 18)

	local collapsedHeight = if showClassControl then 114 else 96
	local upgradeHeaderY = collapsedHeight + 4
	local upgradeButtonsY = upgradeHeaderY + 22
	local expandedHeight = upgradeButtonsY + 208
	upgradeHeader.Position = UDim2.fromOffset(10, upgradeHeaderY)
	buttonContainer.Position = UDim2.fromOffset(10, upgradeButtonsY)
	local showUpgradeChoices = showToggle and upgradeMenuOpen and not evolutionBlocking
	upgradeHeader.Text = if unlimitedPoints then "UNLIMITED POINTS" else "SPEND 1 POINT"
	upgradeHeader.Visible = showUpgradeChoices
	buttonContainer.Visible = showUpgradeChoices
	panel.Size = UDim2.new(0.24, 0, 0, if showUpgradeChoices then expandedHeight else collapsedHeight)

	for _, category in ProgressionConfig.UpgradeOrder do
		local definition = upgradeDefinitions[category]
		local rank = getIntegerAttribute(definition.AttributeName, 0, ProgressionConfig.MaxUpgradeRank)
		local button = buttons[category]
		button.Text = string.format("%s %d/%d", definition.DisplayName, rank, ProgressionConfig.MaxUpgradeRank)
		local canUpgrade = showUpgradeChoices and rank < ProgressionConfig.MaxUpgradeRank
		button.Visible = canUpgrade
		button.Active = canUpgrade
		button.AutoButtonColor = canUpgrade
		button.BackgroundColor3 = if canUpgrade
			then Color3.fromRGB(35, 90, 108)
			else Color3.fromRGB(40, 45, 52)
		button.TextTransparency = if canUpgrade then 0 else 0.3
	end
end

local function toggleUpgradeMenu()
	local points = getIntegerAttribute(
		"UnspentUpgradePoints",
		0,
		ProgressionConfig.MaxUnspentUpgradePoints
	)
	if points <= 0 and player:GetAttribute(DEV_UNLIMITED_ATTRIBUTE) ~= true then
		return
	end
	if isEvolutionBlocking() then
		pendingAutomaticUpgradeOpen = true
		upgradeMenuOpen = false
	else
		upgradeMenuOpen = not upgradeMenuOpen
		pendingAutomaticUpgradeOpen = false
	end
	updateHUD()
end

upgradeToggleButton.Activated:Connect(toggleUpgradeMenu)

local UPGRADE_TOGGLE_ACTION_NAME = "ScrapcoreToggleUpgrades"
local function handleUpgradeToggleAction(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass
	end
	toggleUpgradeMenu()
	return Enum.ContextActionResult.Sink
end

ContextActionService:UnbindAction(UPGRADE_TOGGLE_ACTION_NAME)
ContextActionService:BindActionAtPriority(
	UPGRADE_TOGGLE_ACTION_NAME,
	handleUpgradeToggleAction,
	false,
	Enum.ContextActionPriority.High.Value + 2,
	Enum.KeyCode.E
)

local evolutionPanelConnection: RBXScriptConnection? = nil
local function bindEvolutionPanel()
	if evolutionPanelConnection ~= nil then
		evolutionPanelConnection:Disconnect()
		evolutionPanelConnection = nil
	end
	local evolutionPanel = getEvolutionPanel()
	if evolutionPanel ~= nil then
		evolutionPanelConnection = evolutionPanel:GetPropertyChangedSignal("Visible"):Connect(updateHUD)
	end
	task.defer(updateHUD)
end

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == "ClassEvolutionHUD" then
		task.defer(bindEvolutionPanel)
	end
end)
playerGui.ChildRemoved:Connect(function(child: Instance)
	if child.Name == "ClassEvolutionHUD" then
		bindEvolutionPanel()
	end
end)
bindEvolutionPanel()

local currentHumanoid: Humanoid? = nil
local healthConnections: {RBXScriptConnection} = {}
local displayedHealthRatio = 1
local targetHealthRatio = 1
local HEALTH_FILL_SHARPNESS = 14

local function disconnectHealthConnections()
	for _, connection in healthConnections do
		connection:Disconnect()
	end
	table.clear(healthConnections)
end

local function updateHealthHUD(snapFill: boolean?)
	local humanoid = currentHumanoid
	if humanoid == nil or humanoid.Parent == nil then
		healthPanel.Visible = false
		displayedHealthRatio = 0
		targetHealthRatio = 0
		return
	end

	local maxHealth = math.max(humanoid.MaxHealth, 1)
	local currentHealth = math.clamp(humanoid.Health, 0, maxHealth)
	local healthRatio = math.clamp(currentHealth / maxHealth, 0, 1)
	targetHealthRatio = healthRatio
	if snapFill == true then
		displayedHealthRatio = healthRatio
	end
	healthPanel.Visible = true
	healthLabel.Text = string.format(
		"ROBOT HEALTH  %d/%d",
		math.floor(currentHealth + 0.5),
		math.floor(maxHealth + 0.5)
	)
	healthFill.Size = UDim2.fromScale(displayedHealthRatio, 1)
	healthFill.BackgroundColor3 = if healthRatio <= 0.3
		then Color3.fromRGB(240, 80, 70)
		elseif healthRatio <= 0.6
		then Color3.fromRGB(245, 185, 65)
		else Color3.fromRGB(70, 220, 130)
end

local function bindCharacterHealth(character: Model)
	disconnectHealthConnections()
	currentHumanoid = nil
	updateHealthHUD()

	local humanoidInstance = character:WaitForChild("Humanoid", 10)
	if
		humanoidInstance == nil
		or not humanoidInstance:IsA("Humanoid")
		or player.Character ~= character
	then
		return
	end

	currentHumanoid = humanoidInstance
	table.insert(healthConnections, humanoidInstance.HealthChanged:Connect(function()
		updateHealthHUD()
	end))
	table.insert(healthConnections, humanoidInstance:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		updateHealthHUD()
	end))
	updateHealthHUD(true)
end

RunService.PreRender:Connect(function(deltaTime: number)
	if not healthPanel.Visible then
		return
	end
	local alpha = 1 - math.exp(-HEALTH_FILL_SHARPNESS * deltaTime)
	displayedHealthRatio += (targetHealthRatio - displayedHealthRatio) * alpha
	healthFill.Size = UDim2.fromScale(math.clamp(displayedHealthRatio, 0, 1), 1)
end)

local watchedAttributes = {
	"RunLevel",
	"RunXP",
	"XPToNextLevel",
	"UnspentUpgradePoints",
	"RunClass",
	"ClassEvolutionEligible",
	"ClassEvolutionSelected",
	DEV_UNLIMITED_ATTRIBUTE,
}
for _, category in ProgressionConfig.UpgradeOrder do
	table.insert(watchedAttributes, upgradeDefinitions[category].AttributeName)
end
for _, attributeName in watchedAttributes do
	player:GetAttributeChangedSignal(attributeName):Connect(updateHUD)
end

player.CharacterAdded:Connect(function(character: Model)
	task.spawn(bindCharacterHealth, character)
end)
player.CharacterRemoving:Connect(function(character: Model)
	local humanoid = currentHumanoid
	if humanoid ~= nil and humanoid:IsDescendantOf(character) then
		disconnectHealthConnections()
		currentHumanoid = nil
		updateHealthHUD()
	end
end)
if player.Character ~= nil then
	task.spawn(bindCharacterHealth, player.Character)
end

script.Destroying:Connect(function()
	ContextActionService:UnbindAction(UPGRADE_TOGGLE_ACTION_NAME)
	if viewportConnection ~= nil then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	if evolutionPanelConnection ~= nil then
		evolutionPanelConnection:Disconnect()
		evolutionPanelConnection = nil
	end
	disconnectHealthConnections()
end)

updateHUD()
