--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local upgradeRequestRemote = remotes:WaitForChild("ProgressionUpgradeRequest") :: RemoteEvent

type UpgradeDefinition = {
	AttributeName: string,
	DisplayName: string,
	Description: string,
	PerPoint: number,
}

local upgradeDefinitions = ProgressionConfig.Upgrades :: {[string]: UpgradeDefinition}
local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("ScrapcoreProgressionHUD")
if oldGui ~= nil then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScrapcoreProgressionHUD"
screenGui.DisplayOrder = 20
screenGui.IgnoreGuiInset = false
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -18, 0.5, 0)
panel.Size = UDim2.fromOffset(300, 340)
panel.BackgroundColor3 = Color3.fromRGB(13, 18, 25)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = screenGui

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
title.Text = "RUN EVOLUTION"
title.TextColor3 = Color3.fromRGB(90, 220, 255)
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -32, 0, 24)
title.Parent = panel

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "Level"
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextColor3 = Color3.fromRGB(240, 245, 250)
levelLabel.TextSize = 16
levelLabel.TextXAlignment = Enum.TextXAlignment.Left
levelLabel.Position = UDim2.fromOffset(16, 38)
levelLabel.Size = UDim2.new(0.5, -16, 0, 22)
levelLabel.Parent = panel

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name = "Points"
pointsLabel.BackgroundTransparency = 1
pointsLabel.Font = Enum.Font.GothamBold
pointsLabel.TextColor3 = Color3.fromRGB(255, 205, 70)
pointsLabel.TextSize = 15
pointsLabel.TextXAlignment = Enum.TextXAlignment.Right
pointsLabel.Position = UDim2.new(0.5, 0, 0, 38)
pointsLabel.Size = UDim2.new(0.5, -16, 0, 22)
pointsLabel.Parent = panel

local xpBarBackground = Instance.new("Frame")
xpBarBackground.Name = "XPBarBackground"
xpBarBackground.BackgroundColor3 = Color3.fromRGB(40, 48, 60)
xpBarBackground.BorderSizePixel = 0
xpBarBackground.Position = UDim2.fromOffset(16, 66)
xpBarBackground.Size = UDim2.new(1, -32, 0, 22)
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
xpLabel.TextSize = 13
xpLabel.Size = UDim2.fromScale(1, 1)
xpLabel.ZIndex = 2
xpLabel.Parent = xpBarBackground

local upgradeHeader = Instance.new("TextLabel")
upgradeHeader.Name = "UpgradeHeader"
upgradeHeader.BackgroundTransparency = 1
upgradeHeader.Font = Enum.Font.GothamBold
upgradeHeader.Text = "SPEND 1 POINT"
upgradeHeader.TextColor3 = Color3.fromRGB(180, 190, 205)
upgradeHeader.TextSize = 12
upgradeHeader.TextXAlignment = Enum.TextXAlignment.Left
upgradeHeader.Position = UDim2.fromOffset(16, 98)
upgradeHeader.Size = UDim2.new(1, -32, 0, 18)
upgradeHeader.Parent = panel

local buttonContainer = Instance.new("Frame")
buttonContainer.Name = "UpgradeButtons"
buttonContainer.BackgroundTransparency = 1
buttonContainer.Position = UDim2.fromOffset(16, 120)
buttonContainer.Size = UDim2.new(1, -32, 0, 208)
buttonContainer.Parent = panel

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 5)
buttonLayout.FillDirection = Enum.FillDirection.Vertical
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonContainer

local buttons: {[string]: TextButton} = {}
local lastRequestAt = -math.huge

local function getIntegerAttribute(name: string, minimum: number, maximum: number): number
	local value = player:GetAttribute(name)
	if typeof(value) ~= "number" then
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
	button.TextSize = 13
	button.TextWrapped = true
	button.Size = UDim2.new(1, 0, 0, 37)
	button.Parent = buttonContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = button

	button.Activated:Connect(function()
		local now = Workspace:GetServerTimeNow()
		if now - lastRequestAt < ProgressionConfig.MinimumUpgradeRequestInterval then
			return
		end
		lastRequestAt = now
		upgradeRequestRemote:FireServer(category)
	end)
	buttons[category] = button
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

	levelLabel.Text = string.format("LEVEL %d", level)
	pointsLabel.Text = string.format("POINTS %d", points)
	if level >= ProgressionConfig.LevelCap or xpToNext <= 0 then
		xpLabel.Text = "LEVEL CAP"
		xpFill.Size = UDim2.fromScale(1, 1)
	else
		xpLabel.Text = string.format("%d / %d XP", xp, xpToNext)
		xpFill.Size = UDim2.fromScale(math.clamp(xp / xpToNext, 0, 1), 1)
	end

	for _, category in ProgressionConfig.UpgradeOrder do
		local definition = upgradeDefinitions[category]
		local rank = getIntegerAttribute(definition.AttributeName, 0, ProgressionConfig.MaxUpgradeRank)
		local button = buttons[category]
		button.Text = string.format(
			"%s  %d/%d   %s",
			definition.DisplayName,
			rank,
			ProgressionConfig.MaxUpgradeRank,
			definition.Description
		)
		local canUpgrade = points > 0 and rank < ProgressionConfig.MaxUpgradeRank
		button.Active = canUpgrade
		button.AutoButtonColor = canUpgrade
		button.BackgroundColor3 = if canUpgrade
			then Color3.fromRGB(35, 90, 108)
			else Color3.fromRGB(40, 45, 52)
		button.TextTransparency = if canUpgrade then 0 else 0.3
	end
end

local watchedAttributes = {
	"RunLevel",
	"RunXP",
	"XPToNextLevel",
	"UnspentUpgradePoints",
}
for _, category in ProgressionConfig.UpgradeOrder do
	table.insert(watchedAttributes, upgradeDefinitions[category].AttributeName)
end
for _, attributeName in watchedAttributes do
	player:GetAttributeChangedSignal(attributeName):Connect(updateHUD)
end

updateHUD()
