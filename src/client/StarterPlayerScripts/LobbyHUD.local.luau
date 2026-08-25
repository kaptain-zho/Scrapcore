--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local HUDLayoutConfig = require(shared:WaitForChild("HUDLayoutConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local feedbackRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LobbyFeedback") :: RemoteEvent

local oldGui = playerGui:FindFirstChild("ScrapcoreLobbyHUD")
if oldGui ~= nil then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScrapcoreLobbyHUD"
screenGui.DisplayOrder = 24
screenGui.IgnoreGuiInset = false
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "ObjectivePanel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, HUDLayoutConfig.UpperRailTop)
panel.Size = UDim2.new(0.34, 0, 0, 64)
panel.BackgroundColor3 = Color3.fromRGB(13, 19, 24)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(240, 64)
sizeConstraint.MaxSize = Vector2.new(350, 64)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(35, 198, 225)
stroke.Transparency = 0.15
stroke.Thickness = 1
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 7)
title.Size = UDim2.new(1, -24, 0, 20)
title.Font = Enum.Font.GothamBold
title.Text = "WORKSHOP — SAFE ZONE"
title.TextColor3 = Color3.fromRGB(84, 224, 245)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local objective = Instance.new("TextLabel")
objective.Name = "Objective"
objective.BackgroundTransparency = 1
objective.Position = UDim2.fromOffset(12, 29)
objective.Size = UDim2.new(1, -24, 0, 26)
objective.Font = Enum.Font.GothamMedium
objective.Text = "Explore safely. Use MAIN ARENA → Deploy when ready."
objective.TextColor3 = Color3.fromRGB(224, 232, 238)
objective.TextSize = 11
objective.TextWrapped = true
objective.TextXAlignment = Enum.TextXAlignment.Left
objective.TextYAlignment = Enum.TextYAlignment.Top
objective.Parent = panel

local feedback = Instance.new("TextLabel")
feedback.Name = "Feedback"
feedback.AnchorPoint = Vector2.new(0.5, 0)
feedback.Position = UDim2.new(0.5, 0, 0, HUDLayoutConfig.UpperRailTop + 72)
feedback.Size = UDim2.new(0.34, 0, 0, 36)
feedback.BackgroundColor3 = Color3.fromRGB(23, 29, 36)
feedback.BackgroundTransparency = 0.08
feedback.BorderSizePixel = 0
feedback.Font = Enum.Font.GothamMedium
feedback.Text = ""
feedback.TextColor3 = Color3.fromRGB(238, 242, 246)
feedback.TextSize = 11
feedback.TextWrapped = true
feedback.Visible = false
feedback.Parent = screenGui

local feedbackConstraint = Instance.new("UISizeConstraint")
feedbackConstraint.MinSize = Vector2.new(240, 36)
feedbackConstraint.MaxSize = Vector2.new(350, 36)
feedbackConstraint.Parent = feedback

local feedbackCorner = Instance.new("UICorner")
feedbackCorner.CornerRadius = UDim.new(0, 6)
feedbackCorner.Parent = feedback

local feedbackSerial = 0
local deploymentFeedbackActive = false

local function updateVisibility()
	local isLobby = player:GetAttribute(SessionConfig.SessionAttribute) == SessionConfig.LobbyState
	panel.Visible = isLobby
	screenGui.Enabled = isLobby or deploymentFeedbackActive
	if not isLobby and not deploymentFeedbackActive then
		feedbackSerial += 1
		feedback.Visible = false
	end
end

feedbackRemote.OnClientEvent:Connect(function(messageValue: unknown)
	local isDeploymentFeedback = messageValue == SessionConfig.DeploymentAcceptedFeedback
	if
		typeof(messageValue) ~= "string"
		or #messageValue == 0
		or #messageValue > SessionConfig.MaximumFeedbackLength
		or (
			player:GetAttribute(SessionConfig.SessionAttribute) ~= SessionConfig.LobbyState
			and not isDeploymentFeedback
		)
	then
		return
	end
	feedbackSerial += 1
	local serial = feedbackSerial
	deploymentFeedbackActive = isDeploymentFeedback
	feedback.Text = messageValue
	feedback.Visible = true
	updateVisibility()
	task.delay(2.75, function()
		if feedbackSerial == serial then
			deploymentFeedbackActive = false
			feedback.Visible = false
			updateVisibility()
		end
	end)
end)

player:GetAttributeChangedSignal(SessionConfig.SessionAttribute):Connect(updateVisibility)
updateVisibility()
