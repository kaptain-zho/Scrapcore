--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local ExtractionConfig = require(shared:WaitForChild("ExtractionConfig"))
local HUDLayoutConfig = require(shared:WaitForChild("HUDLayoutConfig"))
local SessionConfig = require(shared:WaitForChild("SessionConfig"))
local statusRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ExtractionStatus") :: RemoteEvent

local oldGui = playerGui:FindFirstChild("ScrapcoreExtractionHUD")
if oldGui ~= nil then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScrapcoreExtractionHUD"
screenGui.DisplayOrder = 23
screenGui.IgnoreGuiInset = false
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local summary = Instance.new("Frame")
summary.Name = "ProfileXPSummary"
summary.Position = UDim2.fromOffset(12, 12)
summary.Size = UDim2.new(0.3, 0, 0, 56)
summary.BackgroundColor3 = Color3.fromRGB(12, 20, 25)
summary.BackgroundTransparency = 0.12
summary.BorderSizePixel = 0
summary.Parent = screenGui

local summaryConstraint = Instance.new("UISizeConstraint")
summaryConstraint.MinSize = Vector2.new(220, 56)
summaryConstraint.MaxSize = Vector2.new(310, 56)
summaryConstraint.Parent = summary

local summaryCorner = Instance.new("UICorner")
summaryCorner.CornerRadius = UDim.new(0, 8)
summaryCorner.Parent = summary

local summaryStroke = Instance.new("UIStroke")
summaryStroke.Color = Color3.fromRGB(48, 157, 176)
summaryStroke.Transparency = 0.25
summaryStroke.Thickness = 1
summaryStroke.Parent = summary

local summaryLabel = Instance.new("TextLabel")
summaryLabel.Name = "XPValues"
summaryLabel.BackgroundTransparency = 1
summaryLabel.Position = UDim2.fromOffset(10, 6)
summaryLabel.Size = UDim2.new(1, -20, 1, -12)
summaryLabel.Font = Enum.Font.GothamBold
summaryLabel.Text = ""
summaryLabel.TextColor3 = Color3.fromRGB(225, 238, 242)
summaryLabel.TextSize = 12
summaryLabel.TextWrapped = true
summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
summaryLabel.TextYAlignment = Enum.TextYAlignment.Center
summaryLabel.Parent = summary

local statusPanel = Instance.new("Frame")
statusPanel.Name = "ExtractionStatus"
statusPanel.AnchorPoint = Vector2.new(0.5, 0)
statusPanel.Position = UDim2.new(0.5, 0, 0, 62)
statusPanel.Size = UDim2.new(0.5, 0, 0, 46)
statusPanel.BackgroundColor3 = Color3.fromRGB(10, 23, 28)
statusPanel.BackgroundTransparency = 0.08
statusPanel.BorderSizePixel = 0
statusPanel.Visible = false
statusPanel.Parent = screenGui

local statusConstraint = Instance.new("UISizeConstraint")
statusConstraint.MinSize = Vector2.new(260, 46)
statusConstraint.MaxSize = Vector2.new(500, 46)
statusConstraint.Parent = statusPanel

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = statusPanel

local statusStroke = Instance.new("UIStroke")
statusStroke.Color = Color3.fromRGB(55, 219, 235)
statusStroke.Thickness = 2
statusStroke.Parent = statusPanel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusText"
statusLabel.BackgroundTransparency = 1
statusLabel.Size = UDim2.fromScale(1, 1)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(238, 247, 250)
statusLabel.TextSize = 17
statusLabel.TextWrapped = true
statusLabel.Parent = statusPanel

local activeSerial = 0
local deadline = 0
local extracting = false
local transientText: string? = nil
local transientUntil = 0

local function getSafeIntegerAttribute(name: string, maximum: number): number
	local value = player:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value or value < 0 or value > maximum then
		return 0
	end
	return math.floor(value)
end

local function updateSummary()
	local isArena = player:GetAttribute(SessionConfig.SessionAttribute) == SessionConfig.ArenaState
	local camera = Workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
	local mode = HUDLayoutConfig.GetMode(viewport)
	local profileLoaded = player:GetAttribute(ExtractionConfig.ProfileLoadedAttribute) == true
	local bankedXP = getSafeIntegerAttribute(ExtractionConfig.BankedXPAttribute, 1_000_000_000)
	if isArena then
		local runXP = getSafeIntegerAttribute(
			ExtractionConfig.RunXPAttribute,
			ExtractionConfig.MaximumUnbankedRunXP
		)
		summary.Position = HUDLayoutConfig.GetArenaProfilePosition(viewport)
		statusPanel.Position = UDim2.new(
			0.5,
			0,
			0,
			if mode == "PortraitCompact" then 554 elseif mode == "LandscapeCompact" then 126 else 66
		)
		summaryLabel.Text = string.format(
			"RUN XP (UNBANKED): %s\nBANKED PROFILE XP: %s",
			tostring(runXP),
			if profileLoaded then tostring(bankedXP) else "UNAVAILABLE"
		)
	else
		summary.Position = UDim2.fromOffset(12, 132)
		statusPanel.Position = UDim2.new(0.5, 0, 0, 62)
		summaryLabel.Text = string.format(
			"BANKED PROFILE XP\n%s",
			if profileLoaded then tostring(bankedXP) else "LOADING / UNAVAILABLE"
		)
	end
end

local function showTransient(text: string, duration: number)
	transientText = text
	transientUntil = Workspace:GetServerTimeNow() + duration
	statusLabel.Text = text
	statusPanel.Visible = true
end

statusRemote.OnClientEvent:Connect(function(statusValue: unknown, serialValue: unknown, value: unknown)
	if
		typeof(statusValue) ~= "string"
		or typeof(serialValue) ~= "number"
		or serialValue ~= serialValue
		or serialValue % 1 ~= 0
		or serialValue < activeSerial
	then
		return
	end
	local status = statusValue :: string
	local serial = serialValue :: number
	activeSerial = serial
	if status == "Started" or status == "HitReset" then
		if typeof(value) ~= "number" or value ~= value or value <= 0 then
			return
		end
		deadline = value :: number
		extracting = true
		if status == "HitReset" then
			showTransient("HIT TAKEN — TIMER RESET", 1.1)
		else
			transientText = nil
			transientUntil = 0
			statusPanel.Visible = true
		end
	elseif status == "Cancelled" then
		extracting = false
		deadline = 0
		showTransient("EXTRACTION CANCELLED — RUN XP PRESERVED", ExtractionConfig.StatusMessageDuration)
	elseif status == "Banked" then
		if typeof(value) ~= "number" or value ~= value or value < 0 then
			return
		end
		extracting = false
		deadline = 0
		showTransient(string.format("%d XP BANKED", math.floor(value :: number)), ExtractionConfig.StatusMessageDuration)
	elseif status == "BankingFailed" then
		extracting = false
		deadline = 0
		showTransient("BANKING FAILED — TRY AGAIN", ExtractionConfig.StatusMessageDuration)
	end
end)

RunService.RenderStepped:Connect(function()
	local now = Workspace:GetServerTimeNow()
	if transientText ~= nil and now < transientUntil then
		statusLabel.Text = transientText
		statusPanel.Visible = true
		return
	end
	transientText = nil
	if extracting then
		local remaining = math.max(deadline - now, 0)
		statusLabel.Text = string.format("EXTRACTING — %.1fs", remaining)
		statusPanel.Visible = true
	else
		statusPanel.Visible = false
	end
end)

for _, attributeName in {
	SessionConfig.SessionAttribute,
	ExtractionConfig.RunXPAttribute,
	ExtractionConfig.BankedXPAttribute,
	ExtractionConfig.ProfileLoadedAttribute,
} do
	player:GetAttributeChangedSignal(attributeName):Connect(updateSummary)
end

local viewportConnection: RBXScriptConnection? = nil
local function bindViewport()
	if viewportConnection ~= nil then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateSummary)
	end
	updateSummary()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport)

bindViewport()
