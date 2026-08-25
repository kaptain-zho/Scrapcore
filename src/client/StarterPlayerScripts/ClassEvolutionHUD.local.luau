--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local shared = ReplicatedStorage:WaitForChild("Shared")
local ClassConfig = require(shared:WaitForChild("ClassConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local classRequestRemote = remotes:WaitForChild("ClassEvolutionRequest") :: RemoteEvent

local PANEL_WIDTH = 340
local PANEL_HEIGHT = 314
local COLORS = {
	Background = Color3.fromRGB(20, 25, 31),
	Surface = Color3.fromRGB(33, 41, 50),
	SurfaceDisabled = Color3.fromRGB(43, 46, 51),
	Border = Color3.fromRGB(91, 107, 119),
	Text = Color3.fromRGB(238, 244, 247),
	MutedText = Color3.fromRGB(171, 184, 192),
	Accent = Color3.fromRGB(244, 154, 45),
	Available = Color3.fromRGB(43, 132, 139),
	Confirm = Color3.fromRGB(48, 150, 109),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ClassEvolutionHUD"
screenGui.DisplayOrder = 18
screenGui.IgnoreGuiInset = false
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "EvolutionPanel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -12, 0.5, 20)
panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
panel.BackgroundColor3 = COLORS.Background
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.Border
panelStroke.Transparency = 0.2
panelStroke.Thickness = 1
panelStroke.Parent = panel

local header = Instance.new("TextLabel")
header.Name = "Header"
header.Position = UDim2.fromOffset(16, 12)
header.Size = UDim2.new(1, -62, 0, 25)
header.BackgroundTransparency = 1
header.Font = Enum.Font.GothamBold
header.Text = "LEVEL 8 EVOLUTION"
header.TextColor3 = COLORS.Text
header.TextSize = 18
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = panel

local subheader = Instance.new("TextLabel")
subheader.Name = "Subheader"
subheader.Position = UDim2.fromOffset(16, 38)
subheader.Size = UDim2.new(1, -32, 0, 32)
subheader.BackgroundTransparency = 1
subheader.Font = Enum.Font.Gotham
subheader.Text = "Choose one path for this life. XP and upgrades stay intact."
subheader.TextColor3 = COLORS.MutedText
subheader.TextSize = 12
subheader.TextWrapped = true
subheader.TextXAlignment = Enum.TextXAlignment.Left
subheader.TextYAlignment = Enum.TextYAlignment.Top
subheader.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -10, 0, 9)
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.BackgroundColor3 = COLORS.Surface
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "×"
closeButton.TextColor3 = COLORS.Text
closeButton.TextSize = 22
closeButton.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = closeButton

local cards = Instance.new("Frame")
cards.Name = "ClassCards"
cards.Position = UDim2.fromOffset(12, 76)
cards.Size = UDim2.new(1, -24, 1, -88)
cards.BackgroundTransparency = 1
cards.Parent = panel

local cardLayout = Instance.new("UIListLayout")
cardLayout.FillDirection = Enum.FillDirection.Vertical
cardLayout.Padding = UDim.new(0, 7)
cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardLayout.Parent = cards

local function addCard(classId: string, layoutOrder: number): TextButton
	local definition = ClassConfig.Definitions[classId]
	assert(definition ~= nil, string.format("Missing class definition %s", classId))
	local enabled = definition.Enabled == true

	local card = Instance.new("TextButton")
	card.Name = classId .. "Card"
	card.LayoutOrder = layoutOrder
	card.Size = UDim2.new(1, 0, 0, 68)
	card.BackgroundColor3 = if enabled then COLORS.Surface else COLORS.SurfaceDisabled
	card.BackgroundTransparency = if enabled then 0 else 0.2
	card.BorderSizePixel = 0
	card.AutoButtonColor = enabled
	card.Active = enabled
	card.Selectable = enabled
	card.Text = ""
	card.Parent = cards

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stripe = Instance.new("Frame")
	stripe.Name = "StatusStripe"
	stripe.Size = UDim2.fromOffset(5, 68)
	stripe.BackgroundColor3 = if enabled then COLORS.Available else COLORS.Border
	stripe.BorderSizePixel = 0
	stripe.Parent = card

	local stripeCorner = Instance.new("UICorner")
	stripeCorner.CornerRadius = UDim.new(0, 8)
	stripeCorner.Parent = stripe

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ClassName"
	nameLabel.Position = UDim2.fromOffset(14, 7)
	nameLabel.Size = UDim2.new(0.55, -14, 0, 20)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = definition.DisplayName
	nameLabel.TextColor3 = if enabled then COLORS.Text else COLORS.MutedText
	nameLabel.TextSize = 15
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.AnchorPoint = Vector2.new(1, 0)
	statusLabel.Position = UDim2.new(1, -10, 0, 8)
	statusLabel.Size = UDim2.new(0.45, -10, 0, 18)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Text = if enabled then "AVAILABLE" else "COMING SOON"
	statusLabel.TextColor3 = if enabled then COLORS.Accent else COLORS.MutedText
	statusLabel.TextSize = 10
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.Parent = card

	local roleLabel = Instance.new("TextLabel")
	roleLabel.Name = "Role"
	roleLabel.Position = UDim2.fromOffset(14, 28)
	roleLabel.Size = UDim2.new(1, -26, 0, 15)
	roleLabel.BackgroundTransparency = 1
	roleLabel.Font = Enum.Font.GothamMedium
	roleLabel.Text = definition.Role
	roleLabel.TextColor3 = if enabled then COLORS.Text else COLORS.MutedText
	roleLabel.TextSize = 11
	roleLabel.TextXAlignment = Enum.TextXAlignment.Left
	roleLabel.Parent = card

	local tradeoffLabel = Instance.new("TextLabel")
	tradeoffLabel.Name = "Tradeoff"
	tradeoffLabel.Position = UDim2.fromOffset(14, 44)
	tradeoffLabel.Size = UDim2.new(1, -26, 0, 18)
	tradeoffLabel.BackgroundTransparency = 1
	tradeoffLabel.Font = Enum.Font.Gotham
	tradeoffLabel.Text = definition.Tradeoff
	tradeoffLabel.TextColor3 = COLORS.MutedText
	tradeoffLabel.TextSize = 10
	tradeoffLabel.TextWrapped = true
	tradeoffLabel.TextXAlignment = Enum.TextXAlignment.Left
	tradeoffLabel.Parent = card
	return card
end

local strikerCard = addCard("Striker", 1)
local spinnerCard = addCard("Spinner", 2)
local rammerCard = addCard("Rammer", 3)

local evolveButton = Instance.new("TextButton")
evolveButton.Name = "EvolveButton"
evolveButton.AnchorPoint = Vector2.new(1, 0.5)
evolveButton.Position = UDim2.new(1, -12, 0.5, 20)
evolveButton.Size = UDim2.fromOffset(98, 42)
evolveButton.BackgroundColor3 = COLORS.Accent
evolveButton.BorderSizePixel = 0
evolveButton.Font = Enum.Font.GothamBold
evolveButton.Text = "EVOLVE"
evolveButton.TextColor3 = Color3.fromRGB(25, 28, 31)
evolveButton.TextSize = 14
evolveButton.Visible = false
evolveButton.Parent = screenGui

local evolveCorner = Instance.new("UICorner")
evolveCorner.CornerRadius = UDim.new(0, 9)
evolveCorner.Parent = evolveButton

local confirmOverlay = Instance.new("Frame")
confirmOverlay.Name = "Confirmation"
confirmOverlay.Size = UDim2.fromScale(1, 1)
confirmOverlay.BackgroundColor3 = COLORS.Background
confirmOverlay.BackgroundTransparency = 0.02
confirmOverlay.BorderSizePixel = 0
confirmOverlay.Visible = false
confirmOverlay.ZIndex = 10
confirmOverlay.Parent = panel

local confirmCorner = Instance.new("UICorner")
confirmCorner.CornerRadius = UDim.new(0, 10)
confirmCorner.Parent = confirmOverlay

local confirmTitle = Instance.new("TextLabel")
confirmTitle.Position = UDim2.fromOffset(24, 56)
confirmTitle.Size = UDim2.new(1, -48, 0, 30)
confirmTitle.BackgroundTransparency = 1
confirmTitle.Font = Enum.Font.GothamBold
confirmTitle.Text = "CONFIRM EVOLUTION?"
confirmTitle.TextColor3 = COLORS.Text
confirmTitle.TextSize = 20
confirmTitle.ZIndex = 11
confirmTitle.Parent = confirmOverlay

local confirmBody = Instance.new("TextLabel")
confirmBody.Position = UDim2.fromOffset(30, 98)
confirmBody.Size = UDim2.new(1, -60, 0, 78)
confirmBody.BackgroundTransparency = 1
confirmBody.Font = Enum.Font.Gotham
confirmBody.Text = "This choice lasts until your robot is destroyed."
confirmBody.TextColor3 = COLORS.MutedText
confirmBody.TextSize = 14
confirmBody.TextWrapped = true
confirmBody.TextYAlignment = Enum.TextYAlignment.Top
confirmBody.ZIndex = 11
confirmBody.Parent = confirmOverlay

local confirmStatus = Instance.new("TextLabel")
confirmStatus.Position = UDim2.fromOffset(30, 185)
confirmStatus.Size = UDim2.new(1, -60, 0, 20)
confirmStatus.BackgroundTransparency = 1
confirmStatus.Font = Enum.Font.GothamMedium
confirmStatus.Text = ""
confirmStatus.TextColor3 = COLORS.Accent
confirmStatus.TextSize = 12
confirmStatus.ZIndex = 11
confirmStatus.Parent = confirmOverlay

local confirmButton = Instance.new("TextButton")
confirmButton.Name = "ConfirmEvolutionButton"
confirmButton.Position = UDim2.new(0.5, 4, 1, -66)
confirmButton.Size = UDim2.new(0.5, -20, 0, 44)
confirmButton.BackgroundColor3 = COLORS.Confirm
confirmButton.BorderSizePixel = 0
confirmButton.Font = Enum.Font.GothamBold
confirmButton.Text = "CONFIRM"
confirmButton.TextColor3 = COLORS.Text
confirmButton.TextSize = 13
confirmButton.ZIndex = 11
confirmButton.Parent = confirmOverlay

local cancelButton = Instance.new("TextButton")
cancelButton.Name = "CancelButton"
cancelButton.Position = UDim2.new(0, 16, 1, -66)
cancelButton.Size = UDim2.new(0.5, -20, 0, 44)
cancelButton.BackgroundColor3 = COLORS.Surface
cancelButton.BorderSizePixel = 0
cancelButton.Font = Enum.Font.GothamBold
cancelButton.Text = "CANCEL"
cancelButton.TextColor3 = COLORS.Text
cancelButton.TextSize = 13
cancelButton.ZIndex = 11
cancelButton.Parent = confirmOverlay

for _, button in { confirmButton, cancelButton } do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
end

local dismissed = false
local wasEligible = false
local awaitingSelection = false
local requestSerial = 0
local selectedClassId: string? = nil

local function hasSelectedClass(): boolean
	local classValue = player:GetAttribute(ClassConfig.ClassAttribute)
	return typeof(classValue) == "string" and classValue ~= ClassConfig.BaseClassId
end

local function isEligible(): boolean
	return player:GetAttribute(SessionConfig.SessionAttribute) == SessionConfig.ArenaState
		and player:GetAttribute(ClassConfig.EligibilityAttribute) == true
		and not hasSelectedClass()
end

local function refreshVisibility()
	local isArena = player:GetAttribute(SessionConfig.SessionAttribute) == SessionConfig.ArenaState
	screenGui.Enabled = isArena
	local eligible = isEligible()
	if eligible and not wasEligible then
		dismissed = false
	end
	wasEligible = eligible
	if not eligible then
		panel.Visible = false
		evolveButton.Visible = false
		confirmOverlay.Visible = false
		awaitingSelection = false
		selectedClassId = nil
		return
	end
	panel.Visible = not dismissed
	evolveButton.Visible = dismissed
end

local function configureCard(card: TextButton, mode: string)
	local stripe = card:FindFirstChild("StatusStripe") :: Frame
	local nameLabel = card:FindFirstChild("ClassName") :: TextLabel
	local statusLabel = card:FindFirstChild("Status") :: TextLabel
	local roleLabel = card:FindFirstChild("Role") :: TextLabel
	local tradeoffLabel = card:FindFirstChild("Tradeoff") :: TextLabel

	if mode == "landscapeCompact" then
		card.Size = UDim2.new(1 / 3, -4, 1, 0)
		stripe.Size = UDim2.new(0, 5, 1, 0)
		nameLabel.Position = UDim2.fromOffset(10, 4)
		nameLabel.Size = UDim2.new(1, -18, 0, 15)
		nameLabel.TextSize = 12
		statusLabel.AnchorPoint = Vector2.zero
		statusLabel.Position = UDim2.fromOffset(10, 19)
		statusLabel.Size = UDim2.new(1, -18, 0, 13)
		statusLabel.TextSize = 8
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		roleLabel.Position = UDim2.fromOffset(10, 33)
		roleLabel.Size = UDim2.new(1, -18, 0, 18)
		roleLabel.TextSize = 8
		roleLabel.TextWrapped = true
		roleLabel.TextYAlignment = Enum.TextYAlignment.Top
		tradeoffLabel.Position = UDim2.fromOffset(10, 52)
		tradeoffLabel.Size = UDim2.new(1, -18, 1, -56)
		tradeoffLabel.TextSize = 8
		tradeoffLabel.TextYAlignment = Enum.TextYAlignment.Top
	elseif mode == "portraitCompact" then
		card.Size = UDim2.new(1, 0, 0, 70)
		stripe.Size = UDim2.new(0, 5, 1, 0)
		nameLabel.Position = UDim2.fromOffset(10, 5)
		nameLabel.Size = UDim2.new(0.48, -10, 0, 16)
		nameLabel.TextSize = 11
		statusLabel.AnchorPoint = Vector2.new(1, 0)
		statusLabel.Position = UDim2.new(1, -6, 0, 6)
		statusLabel.Size = UDim2.new(0.52, -4, 0, 13)
		statusLabel.TextSize = 7
		statusLabel.TextXAlignment = Enum.TextXAlignment.Right
		roleLabel.Position = UDim2.fromOffset(10, 22)
		roleLabel.Size = UDim2.new(1, -18, 0, 15)
		roleLabel.TextSize = 8
		roleLabel.TextWrapped = true
		roleLabel.TextYAlignment = Enum.TextYAlignment.Top
		tradeoffLabel.Position = UDim2.fromOffset(10, 39)
		tradeoffLabel.Size = UDim2.new(1, -18, 0, 27)
		tradeoffLabel.TextSize = 8
		tradeoffLabel.TextYAlignment = Enum.TextYAlignment.Top
	else
		card.Size = UDim2.new(1, 0, 0, 68)
		stripe.Size = UDim2.fromOffset(5, 68)
		nameLabel.Position = UDim2.fromOffset(14, 7)
		nameLabel.Size = UDim2.new(0.55, -14, 0, 20)
		nameLabel.TextSize = 15
		statusLabel.AnchorPoint = Vector2.new(1, 0)
		statusLabel.Position = UDim2.new(1, -10, 0, 8)
		statusLabel.Size = UDim2.new(0.45, -10, 0, 18)
		statusLabel.TextSize = 10
		statusLabel.TextXAlignment = Enum.TextXAlignment.Right
		roleLabel.Position = UDim2.fromOffset(14, 28)
		roleLabel.Size = UDim2.new(1, -26, 0, 15)
		roleLabel.TextSize = 11
		roleLabel.TextWrapped = false
		roleLabel.TextYAlignment = Enum.TextYAlignment.Center
		tradeoffLabel.Position = UDim2.fromOffset(14, 44)
		tradeoffLabel.Size = UDim2.new(1, -26, 0, 18)
		tradeoffLabel.TextSize = 10
		tradeoffLabel.TextYAlignment = Enum.TextYAlignment.Center
	end
end

local function updateResponsiveLayout()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local viewport = camera.ViewportSize
	local mode = "desktop"
	if viewport.X < viewport.Y then
		mode = "portraitCompact"
	elseif viewport.Y < 700 then
		mode = "landscapeCompact"
	end

	panelScale.Scale = 1
	if mode == "landscapeCompact" then
		local compactWidth = math.clamp(viewport.X - 472, 300, 380)
		panel.AnchorPoint = Vector2.new(0.5, 0)
		panel.Position = UDim2.new(0.5, 0, 0, 12)
		panel.Size = UDim2.fromOffset(compactWidth, 156)
		header.Text = "LEVEL 8 EVOLUTION"
		header.Position = UDim2.fromOffset(12, 5)
		header.Size = UDim2.new(1, -70, 0, 20)
		header.TextSize = 15
		subheader.Text = "Choose one path for this life. XP and upgrades stay intact."
		subheader.Position = UDim2.fromOffset(12, 27)
		subheader.Size = UDim2.new(1, -70, 0, 24)
		subheader.TextSize = 9
		closeButton.Position = UDim2.new(1, -7, 0, 4)
		closeButton.Size = UDim2.fromOffset(44, 44)
		cards.Position = UDim2.fromOffset(10, 58)
		cards.Size = UDim2.new(1, -20, 1, -68)
		cardLayout.FillDirection = Enum.FillDirection.Horizontal
		cardLayout.Padding = UDim.new(0, 6)
		evolveButton.AnchorPoint = Vector2.new(0.5, 0)
		evolveButton.Position = UDim2.new(0.5, 0, 0, 12)
		evolveButton.Size = UDim2.fromOffset(112, 44)
		confirmTitle.Position = UDim2.fromOffset(18, 8)
		confirmTitle.Size = UDim2.new(1, -36, 0, 24)
		confirmTitle.TextSize = 16
		confirmBody.Position = UDim2.fromOffset(22, 34)
		confirmBody.Size = UDim2.new(1, -44, 0, 42)
		confirmBody.TextSize = 10
		confirmStatus.Position = UDim2.fromOffset(22, 78)
		confirmStatus.Size = UDim2.new(1, -44, 0, 16)
		confirmStatus.TextSize = 10
		cancelButton.Position = UDim2.new(0, 14, 1, -50)
		cancelButton.Size = UDim2.new(0.5, -18, 0, 40)
		confirmButton.Position = UDim2.new(0.5, 4, 1, -50)
		confirmButton.Size = UDim2.new(0.5, -18, 0, 40)
	elseif mode == "portraitCompact" then
		local compactWidth = math.clamp(viewport.X - 246, 140, 180)
		panel.AnchorPoint = Vector2.zero
		panel.Position = UDim2.fromOffset(12, 12)
		panel.Size = UDim2.fromOffset(compactWidth, 306)
		header.Text = "EVOLUTION"
		header.Position = UDim2.fromOffset(10, 8)
		header.Size = UDim2.new(1, -66, 0, 19)
		header.TextSize = 12
		subheader.Text = "Choose one path for this life."
		subheader.Position = UDim2.fromOffset(10, 50)
		subheader.Size = UDim2.new(1, -20, 0, 16)
		subheader.TextSize = 9
		closeButton.Position = UDim2.new(1, -6, 0, 6)
		closeButton.Size = UDim2.fromOffset(44, 44)
		cards.Position = UDim2.fromOffset(8, 70)
		cards.Size = UDim2.new(1, -16, 1, -78)
		cardLayout.FillDirection = Enum.FillDirection.Vertical
		cardLayout.Padding = UDim.new(0, 4)
		evolveButton.AnchorPoint = Vector2.zero
		evolveButton.Position = UDim2.fromOffset(12, 12)
		evolveButton.Size = UDim2.fromOffset(compactWidth, 44)
		confirmTitle.Position = UDim2.fromOffset(12, 38)
		confirmTitle.Size = UDim2.new(1, -24, 0, 28)
		confirmTitle.TextSize = 13
		confirmBody.Position = UDim2.fromOffset(12, 72)
		confirmBody.Size = UDim2.new(1, -24, 0, 82)
		confirmBody.TextSize = 10
		confirmStatus.Position = UDim2.fromOffset(12, 160)
		confirmStatus.Size = UDim2.new(1, -24, 0, 30)
		confirmStatus.TextSize = 9
		cancelButton.Position = UDim2.new(0, 10, 1, -54)
		cancelButton.Size = UDim2.new(0.5, -13, 0, 42)
		confirmButton.Position = UDim2.new(0.5, 3, 1, -54)
		confirmButton.Size = UDim2.new(0.5, -13, 0, 42)
	else
		local panelCenterY = math.clamp(330 + PANEL_HEIGHT * 0.5, PANEL_HEIGHT * 0.5 + 12, viewport.Y - PANEL_HEIGHT * 0.5 - 12)
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -12, 0, panelCenterY)
		panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
		header.Text = "LEVEL 8 EVOLUTION"
		header.Position = UDim2.fromOffset(16, 12)
		header.Size = UDim2.new(1, -62, 0, 25)
		header.TextSize = 18
		subheader.Text = "Choose one path for this life. XP and upgrades stay intact."
		subheader.Position = UDim2.fromOffset(16, 38)
		subheader.Size = UDim2.new(1, -32, 0, 32)
		subheader.TextSize = 12
		closeButton.Position = UDim2.new(1, -10, 0, 9)
		closeButton.Size = UDim2.fromOffset(34, 34)
		cards.Position = UDim2.fromOffset(12, 76)
		cards.Size = UDim2.new(1, -24, 1, -88)
		cardLayout.FillDirection = Enum.FillDirection.Vertical
		cardLayout.Padding = UDim.new(0, 7)
		evolveButton.AnchorPoint = Vector2.new(1, 0)
		evolveButton.Position = UDim2.new(1, -12, 0, 330)
		evolveButton.Size = UDim2.fromOffset(98, 44)
		confirmTitle.Position = UDim2.fromOffset(24, 56)
		confirmTitle.Size = UDim2.new(1, -48, 0, 30)
		confirmTitle.TextSize = 20
		confirmBody.Position = UDim2.fromOffset(30, 98)
		confirmBody.Size = UDim2.new(1, -60, 0, 78)
		confirmBody.TextSize = 14
		confirmStatus.Position = UDim2.fromOffset(30, 185)
		confirmStatus.Size = UDim2.new(1, -60, 0, 20)
		confirmStatus.TextSize = 12
		cancelButton.Position = UDim2.new(0, 16, 1, -66)
		cancelButton.Size = UDim2.new(0.5, -20, 0, 44)
		confirmButton.Position = UDim2.new(0.5, 4, 1, -66)
		confirmButton.Size = UDim2.new(0.5, -20, 0, 44)
	end

	configureCard(strikerCard, mode)
	configureCard(spinnerCard, mode)
	configureCard(rammerCard, mode)

	task.defer(function()
		if panel.Parent == nil or Workspace.CurrentCamera ~= camera then
			return
		end
		local progressionGui = playerGui:FindFirstChild("ScrapcoreProgressionHUD")
		if progressionGui == nil or not progressionGui:IsA("ScreenGui") then
			return
		end
		local progressPanel = progressionGui:FindFirstChild("Panel")
		local healthPanel = progressionGui:FindFirstChild("PlayerHealth")
		if
			progressPanel == nil
			or not progressPanel:IsA("GuiObject")
			or healthPanel == nil
			or not healthPanel:IsA("GuiObject")
		then
			return
		end

		local progressLeft = progressPanel.AbsolutePosition.X
		local progressBottom = progressPanel.AbsolutePosition.Y + progressPanel.AbsoluteSize.Y
		local healthBottom = healthPanel.AbsolutePosition.Y + healthPanel.AbsoluteSize.Y
		local extractionBottom = healthBottom
		local extractionGui = playerGui:FindFirstChild("ScrapcoreExtractionHUD")
		if extractionGui ~= nil and extractionGui:IsA("ScreenGui") then
			local extractionSummary = extractionGui:FindFirstChild("ProfileXPSummary")
			if extractionSummary ~= nil and extractionSummary:IsA("GuiObject") and extractionSummary.Visible then
				extractionBottom = math.max(
					extractionBottom,
					extractionSummary.AbsolutePosition.Y + extractionSummary.AbsoluteSize.Y
				)
			end
		end
		local desiredPanelX = panel.AbsolutePosition.X
		local desiredPanelY = panel.AbsolutePosition.Y
		local desiredWidth = panel.AbsoluteSize.X
		local desiredHeight = panel.AbsoluteSize.Y

		if mode == "landscapeCompact" then
			desiredPanelY = extractionBottom + 12
			desiredWidth = math.clamp(progressLeft - 24, 280, 380)
			desiredPanelX = progressLeft - 12 - desiredWidth
		elseif mode == "portraitCompact" then
			desiredPanelX = 12
			desiredPanelY = extractionBottom + 12
			desiredWidth = math.max(progressLeft - 12 - desiredPanelX, 136)
			desiredHeight = math.clamp(viewport.Y - desiredPanelY - 12, 286, 306)
		else
			desiredPanelY = progressBottom + 12
		end

		panel.Size = UDim2.fromOffset(desiredWidth, desiredHeight)
		panel.Position += UDim2.fromOffset(
			desiredPanelX - panel.AbsolutePosition.X,
			desiredPanelY - panel.AbsolutePosition.Y
		)

		local desiredEvolveX = if mode == "landscapeCompact"
			then desiredPanelX + (desiredWidth - evolveButton.AbsoluteSize.X) * 0.5
			elseif mode == "portraitCompact" then desiredPanelX
			else desiredPanelX + desiredWidth - evolveButton.AbsoluteSize.X
		local desiredEvolveY = desiredPanelY
		evolveButton.Position += UDim2.fromOffset(
			desiredEvolveX - evolveButton.AbsolutePosition.X,
			desiredEvolveY - evolveButton.AbsolutePosition.Y
		)
	end)
end

closeButton.Activated:Connect(function()
	dismissed = true
	confirmOverlay.Visible = false
	selectedClassId = nil
	refreshVisibility()
end)

evolveButton.Activated:Connect(function()
	if not isEligible() then
		return
	end
	dismissed = false
	refreshVisibility()
end)

local function openConfirmation(classId: string)
	if not isEligible() or awaitingSelection then
		return
	end
	local definition = ClassConfig.Definitions[classId]
	if definition == nil or definition.Enabled ~= true then
		return
	end
	selectedClassId = classId
	confirmTitle.Text = string.format("EVOLVE INTO %s?", string.upper(definition.DisplayName))
	confirmBody.Text = string.format(
		"%s\n\nThis choice lasts until your robot is destroyed.",
		definition.Tradeoff
	)
	confirmStatus.Text = ""
	confirmOverlay.Visible = true
end

strikerCard.Activated:Connect(function()
	openConfirmation(ClassConfig.StrikerClassId)
end)

spinnerCard.Activated:Connect(function()
	openConfirmation(ClassConfig.SpinnerClassId)
end)

rammerCard.Activated:Connect(function()
	openConfirmation(ClassConfig.RammerClassId)
end)

cancelButton.Activated:Connect(function()
	if awaitingSelection then
		return
	end
	confirmOverlay.Visible = false
	selectedClassId = nil
end)

confirmButton.Activated:Connect(function()
	local classId = selectedClassId
	if awaitingSelection or not isEligible() or classId == nil then
		return
	end
	local definition = ClassConfig.Definitions[classId]
	if definition == nil or definition.Enabled ~= true then
		return
	end
	awaitingSelection = true
	requestSerial += 1
	local thisRequest = requestSerial
	confirmStatus.Text = "Requesting server approval…"
	classRequestRemote:FireServer(classId)
	task.delay(1.5, function()
		if requestSerial ~= thisRequest or not awaitingSelection then
			return
		end
		awaitingSelection = false
		if isEligible() then
			confirmStatus.Text = "Not accepted. You can try again."
		else
			refreshVisibility()
		end
	end)
end)

player:GetAttributeChangedSignal(ClassConfig.ClassAttribute):Connect(function()
	if hasSelectedClass() then
		requestSerial += 1
		awaitingSelection = false
		selectedClassId = nil
	end
	refreshVisibility()
end)
player:GetAttributeChangedSignal(ClassConfig.EligibilityAttribute):Connect(refreshVisibility)
player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(refreshVisibility)

local viewportConnection: RBXScriptConnection? = nil
local function connectCurrentCamera()
	if viewportConnection ~= nil then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
	updateResponsiveLayout()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCurrentCamera)

local progressionLayoutConnections: {RBXScriptConnection} = {}
local function disconnectProgressionLayout()
	for _, connection in progressionLayoutConnections do
		connection:Disconnect()
	end
	table.clear(progressionLayoutConnections)
end

local function bindProgressionLayout()
	disconnectProgressionLayout()
	local progressionGui = playerGui:FindFirstChild("ScrapcoreProgressionHUD")
	if progressionGui ~= nil and progressionGui:IsA("ScreenGui") then
		for _, name in { "Panel", "PlayerHealth" } do
			local guiObject = progressionGui:FindFirstChild(name)
			if guiObject ~= nil and guiObject:IsA("GuiObject") then
				table.insert(
					progressionLayoutConnections,
					guiObject:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateResponsiveLayout)
				)
				table.insert(
					progressionLayoutConnections,
					guiObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResponsiveLayout)
				)
			end
		end
	end
	task.defer(updateResponsiveLayout)
end

playerGui.ChildAdded:Connect(function(child: Instance)
	if child.Name == "ScrapcoreProgressionHUD" then
		task.defer(bindProgressionLayout)
	end
end)
playerGui.ChildRemoved:Connect(function(child: Instance)
	if child.Name == "ScrapcoreProgressionHUD" then
		bindProgressionLayout()
	end
end)

connectCurrentCamera()
bindProgressionLayout()
refreshVisibility()
