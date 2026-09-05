--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestRemote = remotes:WaitForChild("DevToolsRequest") :: RemoteEvent
local stateRemote = remotes:WaitForChild("DevToolsState") :: RemoteEvent
local playerGui = player:WaitForChild("PlayerGui")

local ACTION_NAME = "ScrapcoreToggleDevTools"
local ACTIONS = {
	{ "+10 XP", "AddXP10" },
	{ "+50 XP", "AddXP50" },
	{ "+100 XP", "AddXP100" },
	{ "+500 XP", "AddXP500" },
	{ "To Level 8", "ToLevel8" },
	{ "To Level 20", "ToLevel20" },
	{ "To Level 30", "ToLevel30" },
	{ "To Level 35", "ToLevel35" },
	{ "To Level 75", "ToLevel75" },
	{ "To Level 150", "ToLevel150" },
	{ "To Level 250", "ToLevel250" },
	{ "To Level 300", "ToLevel300" },
	{ "Unlimited Points", "ToggleUnlimitedPoints" },
	{ "Reset Run", "ResetRun" },
	{ "Return to Lobby", "ReturnToLobby" },
	{ "Move to Arena Portal", "StudioTestMoveToMainPortal" },
	{ "Heal to Full", "HealToFull" },
	{ "Activate Impact Foundry", "StudioTestActivateImpactFoundry" },
	{ "Activate Motion Works", "StudioTestActivateMotionWorks" },
}

local oldGui = playerGui:FindFirstChild("ScrapcoreDevTools")
if oldGui ~= nil then
	oldGui:Destroy()
end
ContextActionService:UnbindAction(ACTION_NAME)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScrapcoreDevTools"
screenGui.DisplayOrder = 90
screenGui.IgnoreGuiInset = false
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 18, 0.5, 0)
panel.Size = UDim2.fromOffset(380, 620)
panel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(320, 500)
sizeConstraint.MaxSize = Vector2.new(400, 640)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(150, 80, 230)
stroke.Thickness = 1
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 10)
title.Size = UDim2.new(1, -62, 0, 24)
title.Font = Enum.Font.GothamBold
title.Text = "SCRAPCORE DEV TOOLS — STUDIO ONLY"
title.TextColor3 = Color3.fromRGB(215, 180, 255)
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -10, 0, 8)
closeButton.Size = UDim2.fromOffset(32, 28)
closeButton.BackgroundColor3 = Color3.fromRGB(50, 42, 62)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(245, 245, 250)
closeButton.TextSize = 20
closeButton.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 5)
closeCorner.Parent = closeButton

local stateLabel = Instance.new("TextLabel")
stateLabel.Name = "State"
stateLabel.BackgroundColor3 = Color3.fromRGB(27, 30, 39)
stateLabel.BorderSizePixel = 0
stateLabel.Position = UDim2.fromOffset(12, 46)
stateLabel.Size = UDim2.new(1, -24, 0, 78)
stateLabel.Font = Enum.Font.Code
stateLabel.Text = "Awaiting server authorization..."
stateLabel.TextColor3 = Color3.fromRGB(225, 230, 240)
stateLabel.TextSize = 13
stateLabel.TextWrapped = true
stateLabel.TextXAlignment = Enum.TextXAlignment.Left
stateLabel.TextYAlignment = Enum.TextYAlignment.Center
stateLabel.Parent = panel

local statePadding = Instance.new("UIPadding")
statePadding.PaddingLeft = UDim.new(0, 10)
statePadding.PaddingRight = UDim.new(0, 10)
statePadding.Parent = stateLabel

local buttonContainer = Instance.new("Frame")
buttonContainer.Name = "Actions"
buttonContainer.BackgroundTransparency = 1
buttonContainer.Position = UDim2.fromOffset(12, 136)
buttonContainer.Size = UDim2.new(1, -24, 1, -148)
buttonContainer.Parent = panel

local grid = Instance.new("UIGridLayout")
grid.CellPadding = UDim2.fromOffset(8, 6)
grid.CellSize = UDim2.new(0.5, -4, 0, 40)
grid.FillDirectionMaxCells = 2
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = buttonContainer

local authorized = false

local function sendAction(action: string)
	if authorized then
		requestRemote:FireServer(action)
	end
end

for order, definition in ACTIONS do
	local button = Instance.new("TextButton")
	button.Name = definition[2]
	button.LayoutOrder = order
	button.BackgroundColor3 = Color3.fromRGB(55, 43, 72)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.Text = definition[1]
	button.TextColor3 = Color3.fromRGB(241, 237, 248)
	button.TextSize = 13
	button.Parent = buttonContainer

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 5)
	buttonCorner.Parent = button

	button.Activated:Connect(function()
		sendAction(definition[2])
	end)
end

local function setPanelVisible(visible: boolean)
	if authorized then
		panel.Visible = visible
	end
end

closeButton.Activated:Connect(function()
	setPanelVisible(false)
end)

local function toggleAction(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass
	end
	setPanelVisible(not panel.Visible)
	return Enum.ContextActionResult.Sink
end

local function hasExactStateShape(payload: unknown): boolean
	if typeof(payload) ~= "table" then
		return false
	end
	local value = payload :: {[any]: any}
	local count = 0
	for _ in value do
		count += 1
	end
	return count == 8
		and typeof(value.Authorized) == "boolean"
		and typeof(value.Level) == "number"
		and typeof(value.XP) == "number"
		and typeof(value.XPToNext) == "number"
		and typeof(value.Points) == "number"
		and typeof(value.Class) == "string"
		and typeof(value.Route) == "string"
		and typeof(value.Unlimited) == "boolean"
end

stateRemote.OnClientEvent:Connect(function(payload: unknown)
	if not hasExactStateShape(payload) then
		return
	end
	local state = payload :: {[string]: any}
	if not state.Authorized then
		authorized = false
		panel.Visible = false
		screenGui.Enabled = false
		ContextActionService:UnbindAction(ACTION_NAME)
		return
	end
	if not authorized then
		authorized = true
		screenGui.Enabled = true
		ContextActionService:BindAction(ACTION_NAME, toggleAction, false, Enum.KeyCode.F2)
	end
	stateLabel.Text = string.format(
		"LEVEL %d  |  XP %d / %d  |  POINTS %s\nCLASS %s  |  ROUTE %s  |  UNLIMITED %s",
		math.floor(state.Level),
		math.floor(state.XP),
		math.floor(state.XPToNext),
		if state.Unlimited then "∞" else tostring(math.floor(state.Points)),
		state.Class,
		state.Route,
		if state.Unlimited then "ON" else "OFF"
	)
end)

requestRemote:FireServer("RequestState")
