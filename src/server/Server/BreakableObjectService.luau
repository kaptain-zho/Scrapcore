--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local ArenaLayoutService = require(script.Parent:WaitForChild("ArenaLayoutService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local CollisionGroupService = require(script.Parent:WaitForChild("CollisionGroupService"))
local PlayerSessionService = require(script.Parent:WaitForChild("PlayerSessionService"))

type BreakableDefinition = {
	DisplayName: string,
	MaxHealth: number,
	XPReward: number,
	RespawnDelay: number,
	Rarity: string?,
}

type StoredPartState = {
	part: BasePart,
	transparency: number,
	color: Color3,
	canCollide: boolean,
	canQuery: boolean,
	canTouch: boolean,
}

type Contribution = {
	damage: number,
	runSerial: number,
}

type BreakableState = {
	model: Model,
	definition: BreakableDefinition,
	health: number,
	active: boolean,
	respawnSerial: number,
	flashSerial: number,
	parts: {StoredPartState},
	contributions: {[Player]: Contribution},
	statusGui: BillboardGui,
	statusLabel: TextLabel,
	healthFill: Frame,
	highlight: Highlight,
	burst: ParticleEmitter,
}

type Allocation = {
	player: Player,
	xp: number,
	fraction: number,
}

local definitions = ProgressionConfig.Breakables :: {[string]: BreakableDefinition}
local states: {[Model]: BreakableState} = {}
local partOwners: {[BasePart]: Model} = {}
local initialized = false
local breakablesFolder: Folder? = nil

local BreakableObjectService = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function getOrCreateStatus(primaryPart: BasePart): (BillboardGui, TextLabel, Frame)
	local existing = primaryPart:FindFirstChild("BreakableStatus")
	if existing ~= nil then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BreakableStatus"
	billboard.Adornee = primaryPart
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 85
	billboard.Size = UDim2.fromOffset(120, 30)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, primaryPart.Size.Y * 0.5 + 1.5, 0)
	billboard.Parent = primaryPart

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = billboard

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextColor3 = Color3.fromRGB(235, 242, 255)
	statusLabel.TextSize = 10
	statusLabel.TextStrokeColor3 = Color3.fromRGB(12, 16, 22)
	statusLabel.TextStrokeTransparency = 0.35
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.Size = UDim2.new(1, 0, 0, 16)
	statusLabel.Parent = panel

	local barBackground = Instance.new("Frame")
	barBackground.Name = "HealthBarBackground"
	barBackground.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
	barBackground.BackgroundTransparency = 0.35
	barBackground.BorderSizePixel = 0
	barBackground.Size = UDim2.new(1, -16, 0, 6)
	barBackground.Position = UDim2.new(0, 8, 1, -9)
	barBackground.Parent = panel

	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.BackgroundColor3 = Color3.fromRGB(70, 220, 130)
	healthFill.BorderSizePixel = 0
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.Parent = barBackground

	return billboard, statusLabel, healthFill
end

local function createFeedback(model: Model, primaryPart: BasePart): (Highlight, ParticleEmitter)
	local oldHighlight = model:FindFirstChild("BreakableDamageFlash")
	if oldHighlight ~= nil then
		oldHighlight:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "BreakableDamageFlash"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 240, 140)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.Parent = model

	local oldBurst = primaryPart:FindFirstChild("BreakableBurst")
	if oldBurst ~= nil then
		oldBurst:Destroy()
	end

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "BreakableBurst"
	burst.Color = ColorSequence.new(Color3.fromRGB(255, 180, 45), Color3.fromRGB(90, 95, 105))
	burst.Lifetime = NumberRange.new(0.25, 0.55)
	burst.Rate = 0
	burst.Speed = NumberRange.new(5, 10)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.RotSpeed = NumberRange.new(-180, 180)
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	burst.Parent = primaryPart

	return highlight, burst
end

local function updateDisplay(state: BreakableState)
	state.model:SetAttribute("BreakableHealth", state.health)
	state.model:SetAttribute("BreakableMaxHealth", state.definition.MaxHealth)
	state.model:SetAttribute("BreakableActive", state.active)
	state.statusGui.Enabled = state.active

	if state.active then
		state.statusLabel.Text = string.format(
			"%s  %d/%d",
			state.definition.DisplayName,
			math.ceil(state.health),
			state.definition.MaxHealth
		)
		state.healthFill.BackgroundColor3 = if state.health / state.definition.MaxHealth <= 0.3
			then Color3.fromRGB(240, 80, 70)
			else Color3.fromRGB(70, 220, 130)
		state.healthFill.Size = UDim2.fromScale(
			math.clamp(state.health / state.definition.MaxHealth, 0, 1),
			1
		)
	else
		state.statusLabel.Text = ""
		state.healthFill.Size = UDim2.fromScale(0, 1)
	end
end

local function setGeometryActive(state: BreakableState, isActive: boolean)
	for _, stored in state.parts do
		local part = stored.part
		if part.Parent == nil then
			continue
		end
		part.Anchored = true
		if isActive then
			part.Transparency = stored.transparency
			part.Color = stored.color
			part.CanCollide = stored.canCollide
			part.CanQuery = stored.canQuery
			part.CanTouch = stored.canTouch
		else
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

local function flashDamage(state: BreakableState)
	state.flashSerial += 1
	local flashSerial = state.flashSerial
	state.highlight.FillColor = Color3.fromRGB(255, 240, 140)
	state.highlight.Enabled = true
	task.delay(0.08, function()
		if state.flashSerial == flashSerial and state.active then
			state.highlight.Enabled = false
		end
	end)
end

local function distributeXP(state: BreakableState)
	local eligible: {Contribution} = {}
	local playersByContribution: {[Contribution]: Player} = {}
	local totalDamage = 0

	for player, contribution in state.contributions do
		if
			contribution.damage > 0
			and ProgressionService.IsRunActive(player, contribution.runSerial)
		then
			table.insert(eligible, contribution)
			playersByContribution[contribution] = player
			totalDamage += contribution.damage
		end
	end
	if totalDamage <= 0 then
		return
	end

	local allocations: {Allocation} = {}
	local assignedXP = 0
	for _, contribution in eligible do
		local rawXP = state.definition.XPReward * contribution.damage / totalDamage
		local baseXP = math.floor(rawXP)
		assignedXP += baseXP
		table.insert(allocations, {
			player = playersByContribution[contribution],
			xp = baseXP,
			fraction = rawXP - baseXP,
		})
	end

	table.sort(allocations, function(left: Allocation, right: Allocation): boolean
		if left.fraction == right.fraction then
			return left.player.UserId < right.player.UserId
		end
		return left.fraction > right.fraction
	end)

	local remainder = state.definition.XPReward - assignedXP
	for index = 1, remainder do
		local allocation = allocations[(index - 1) % #allocations + 1]
		allocation.xp += 1
	end

	for _, allocation in allocations do
		if allocation.xp > 0 then
			ProgressionService.AwardXP(allocation.player, allocation.xp)
		end
	end
end

local function respawn(state: BreakableState, respawnSerial: number)
	if
		state.model.Parent == nil
		or state.respawnSerial ~= respawnSerial
		or state.active
	then
		return
	end

	state.health = state.definition.MaxHealth
	state.active = true
	table.clear(state.contributions)
	state.highlight.Enabled = false
	setGeometryActive(state, true)
	updateDisplay(state)
end

local function destroyBreakable(state: BreakableState)
	if not state.active then
		return
	end

	state.active = false
	state.health = 0
	state.respawnSerial += 1
	state.flashSerial += 1
	local respawnSerial = state.respawnSerial
	distributeXP(state)

	state.highlight.FillColor = Color3.fromRGB(255, 110, 40)
	state.highlight.Enabled = true
	state.burst:Emit(18)
	updateDisplay(state)

	task.delay(0.12, function()
		if state.respawnSerial ~= respawnSerial or state.active then
			return
		end
		state.highlight.Enabled = false
		setGeometryActive(state, false)
	end)

	task.delay(state.definition.RespawnDelay, function()
		respawn(state, respawnSerial)
	end)
end

local function bindBreakable(model: Model)
	if states[model] ~= nil then
		return
	end

	local typeValue = model:GetAttribute("BreakableType")
	if typeof(typeValue) ~= "string" then
		error(string.format("%s requires string BreakableType attribute", model:GetFullName()))
	end
	local definition = definitions[typeValue :: string]
	if definition == nil then
		error(string.format("%s has unknown BreakableType %s", model:GetFullName(), typeValue))
	end

	local primaryPart = model.PrimaryPart
	if primaryPart == nil then
		local hitbox = model:FindFirstChild("Hitbox")
		if hitbox == nil or not hitbox:IsA("BasePart") then
			error(string.format("%s requires PrimaryPart or Hitbox", model:GetFullName()))
		end
		model.PrimaryPart = hitbox
		primaryPart = hitbox
	end

	local storedParts: {StoredPartState} = {}
	CollisionGroupService.ApplyBreakable(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if not descendant.Anchored then
				error(string.format("%s must keep every breakable part anchored", model:GetFullName()))
			end
			table.insert(storedParts, {
				part = descendant,
				transparency = descendant.Transparency,
				color = descendant.Color,
				canCollide = descendant.CanCollide,
				canQuery = descendant.CanQuery,
				canTouch = descendant.CanTouch,
			})
			partOwners[descendant] = model
		end
	end
	if #storedParts == 0 then
		error(string.format("%s requires at least one BasePart", model:GetFullName()))
	end

	local statusGui, statusLabel, healthFill = getOrCreateStatus(primaryPart)
	local highlight, burst = createFeedback(model, primaryPart)
	local state: BreakableState = {
		model = model,
		definition = definition,
		health = definition.MaxHealth,
		active = true,
		respawnSerial = 0,
		flashSerial = 0,
		parts = storedParts,
		contributions = {},
		statusGui = statusGui,
		statusLabel = statusLabel,
		healthFill = healthFill,
		highlight = highlight,
		burst = burst,
	}
	states[model] = state
	model:SetAttribute("BreakableXPReward", definition.XPReward)
	model:SetAttribute("BreakableRespawnDelay", definition.RespawnDelay)
	model:SetAttribute("BreakableRarity", definition.Rarity)
	updateDisplay(state)
end

function BreakableObjectService.GetBreakableFromPart(part: BasePart): Model?
	return partOwners[part]
end

function BreakableObjectService.Damage(model: Model, attacker: Player, amount: number): (number, boolean)
	local state = states[model]
	if
		state == nil
		or not state.active
		or not PlayerSessionService.IsArena(attacker)
		or not isFinite(amount)
		or amount <= 0
	then
		return 0, false
	end

	local runSerial = ProgressionService.GetRunSerial(attacker)
	if not ProgressionService.IsRunActive(attacker, runSerial) then
		return 0, false
	end

	local appliedDamage = math.min(
		state.health,
		math.clamp(amount, 0, ProgressionConfig.MaxBreakableDamagePerHit)
	)
	if appliedDamage <= 0 then
		return 0, false
	end

	local contribution = state.contributions[attacker]
	if contribution == nil or contribution.runSerial ~= runSerial then
		contribution = {
			damage = 0,
			runSerial = runSerial,
		}
		state.contributions[attacker] = contribution
	end
	contribution.damage += appliedDamage

	state.health -= appliedDamage
	flashDamage(state)
	updateDisplay(state)
	if state.health <= 0 then
		destroyBreakable(state)
		return appliedDamage, true
	end
	return appliedDamage, false
end

function BreakableObjectService.Init()
	if initialized then
		return
	end
	initialized = true
	PlayerSessionService.Init()
	CollisionGroupService.Init()
	ProgressionService.Init()
	ArenaLayoutService.Init()

	local arena = Workspace:WaitForChild("GrayboxArena")
	local folderInstance = arena:WaitForChild("Breakables", 10)
	if folderInstance == nil or not folderInstance:IsA("Folder") then
		error("Workspace.GrayboxArena.Breakables must be a Folder")
	end
	breakablesFolder = folderInstance

	for _, child in folderInstance:GetChildren() do
		if child:IsA("Model") then
			bindBreakable(child)
		end
	end
	folderInstance.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") then
			bindBreakable(child)
		end
	end)
	folderInstance.ChildRemoved:Connect(function(child: Instance)
		if not child:IsA("Model") then
			return
		end
		local state = states[child]
		if state == nil then
			return
		end
		for _, stored in state.parts do
			partOwners[stored.part] = nil
		end
		states[child] = nil
	end)
end

return BreakableObjectService
