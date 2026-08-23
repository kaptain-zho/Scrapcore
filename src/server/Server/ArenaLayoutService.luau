--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaConfig = require(shared:WaitForChild("ArenaConfig"))
local ProgressionConfig = require(shared:WaitForChild("ProgressionConfig"))
local breakableDefinitions = ProgressionConfig.Breakables :: {[string]: unknown}

type ZoneDefinition = {
	Name: string,
	BreakableType: string,
	Count: number,
	MinAxisDistance: number,
	MaxAxisDistance: number,
}

type Exclusion = {
	position: Vector2,
	radius: number,
}

type Placement = {
	position: Vector2,
	zoneName: string,
	breakableType: string,
	index: number,
}

local GENERATED_ATTRIBUTE = "ArenaGeneratedBreakable"
local initialized = false
local generatedCount = 0

local ArenaLayoutService = {}

local function getRequiredFolder(parent: Instance, name: string): Folder
	local instance = parent:WaitForChild(name, 10)
	if instance == nil or not instance:IsA("Folder") then
		error(string.format("%s.%s must be a Folder", parent:GetFullName(), name))
	end
	return instance
end

local function validateTemplate(template: Model, breakableType: string)
	if template:GetAttribute("BreakableType") ~= breakableType then
		error(string.format("%s must have BreakableType %s", template:GetFullName(), breakableType))
	end
	if template.PrimaryPart == nil then
		error(string.format("%s requires a PrimaryPart", template:GetFullName()))
	end

	local partCount = 0
	for _, descendant in template:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
			if not descendant.Anchored then
				error(string.format("%s must keep every template part anchored", template:GetFullName()))
			end
		end
	end
	if partCount == 0 then
		error(string.format("%s requires at least one BasePart", template:GetFullName()))
	end
end

local function isClear(candidate: Vector2, placements: {Placement}, exclusions: {Exclusion}): boolean
	for _, placement in placements do
		if (candidate - placement.position).Magnitude < ArenaConfig.MinimumBreakableSpacing then
			return false
		end
	end
	for _, exclusion in exclusions do
		if (candidate - exclusion.position).Magnitude < exclusion.radius then
			return false
		end
	end
	return true
end

local function createExclusions(): {Exclusion}
	local exclusions: {Exclusion} = {
		{
			position = Vector2.zero,
			radius = ArenaConfig.CenterClearance,
		},
		{
			position = Vector2.new(ArenaConfig.DummyPosition.X, ArenaConfig.DummyPosition.Z),
			radius = ArenaConfig.DummyClearance,
		},
	}
	for _, spawnPosition in ArenaConfig.SpawnPositions do
		table.insert(exclusions, {
			position = Vector2.new(spawnPosition.X, spawnPosition.Z),
			radius = ArenaConfig.SpawnClearance,
		})
	end
	return exclusions
end

local function generatePlacements(): {Placement}
	local random = Random.new(ArenaConfig.GenerationSeed)
	local placements: {Placement} = {}
	local exclusions = createExclusions()

	for _, zoneValue in ArenaConfig.BreakableZones do
		local zone = zoneValue :: ZoneDefinition
		local maximumAxisDistance = math.min(ArenaConfig.PlayableSize.X, ArenaConfig.PlayableSize.Y) * 0.5
			- ArenaConfig.WallClearance
		if zone.MaxAxisDistance > maximumAxisDistance then
			error(string.format("Arena zone %s exceeds configured wall clearance", zone.Name))
		end
		if breakableDefinitions[zone.BreakableType] == nil then
			error(string.format("Arena zone %s uses unknown breakable type %s", zone.Name, zone.BreakableType))
		end

		for index = 1, zone.Count do
			local placed = false
			for _ = 1, ArenaConfig.MaximumPlacementAttemptsPerObject do
				local candidate = Vector2.new(
					random:NextNumber(-zone.MaxAxisDistance, zone.MaxAxisDistance),
					random:NextNumber(-zone.MaxAxisDistance, zone.MaxAxisDistance)
				)
				local axisDistance = math.max(math.abs(candidate.X), math.abs(candidate.Y))
				if axisDistance < zone.MinAxisDistance or not isClear(candidate, placements, exclusions) then
					continue
				end

				table.insert(placements, {
					position = candidate,
					zoneName = zone.Name,
					breakableType = zone.BreakableType,
					index = index,
				})
				placed = true
				break
			end
			if not placed then
				error(string.format("Unable to place %s %d with configured spacing", zone.BreakableType, index))
			end
		end
	end
	return placements
end

local function clearPreviousGeneration(breakables: Folder)
	for _, child in breakables:GetChildren() do
		if child:GetAttribute(GENERATED_ATTRIBUTE) == true then
			child:Destroy()
		elseif child:IsA("Model") then
			error(string.format(
				"%s contains non-generated model %s; preserve or relocate it before generation",
				breakables:GetFullName(),
				child.Name
			))
		end
	end
end

function ArenaLayoutService.Init()
	if initialized then
		return
	end
	initialized = true

	local arena = Workspace:WaitForChild("GrayboxArena")
	local floorInstance = arena:WaitForChild("Floor", 10)
	if floorInstance == nil or not floorInstance:IsA("BasePart") then
		error("Workspace.GrayboxArena.Floor must be a BasePart")
	end
	local floor = floorInstance :: BasePart
	if
		math.abs(floor.Size.X - ArenaConfig.PlayableSize.X) > 0.01
		or math.abs(floor.Size.Z - ArenaConfig.PlayableSize.Y) > 0.01
		or (floor.Position - ArenaConfig.FloorCenter).Magnitude > 0.01
	then
		error("Workspace.GrayboxArena.Floor does not match ArenaConfig")
	end
	local breakables = getRequiredFolder(arena, "Breakables")
	local assetLibrary = getRequiredFolder(ServerStorage, "AssetLibrary")
	local templateFolder = getRequiredFolder(assetLibrary, "Breakables")

	clearPreviousGeneration(breakables)
	local templates: {[string]: Model} = {}
	for _, zoneValue in ArenaConfig.BreakableZones do
		local zone = zoneValue :: ZoneDefinition
		if templates[zone.BreakableType] ~= nil then
			continue
		end
		local templateInstance = templateFolder:WaitForChild(zone.BreakableType, 10)
		if templateInstance == nil or not templateInstance:IsA("Model") then
			error(string.format("%s.%s must be a Model", templateFolder:GetFullName(), zone.BreakableType))
		end
		validateTemplate(templateInstance, zone.BreakableType)
		templates[zone.BreakableType] = templateInstance
	end

	local placements = generatePlacements()
	local floorTop = floor.Position.Y + floor.Size.Y * 0.5
	local random = Random.new(ArenaConfig.GenerationSeed + 1)
	for _, placement in placements do
		local template = templates[placement.breakableType]
		local clone = template:Clone()
		clone.Name = string.format("%s_%03d", placement.breakableType, placement.index)
		clone:SetAttribute(GENERATED_ATTRIBUTE, true)
		clone:SetAttribute("ArenaZone", placement.zoneName)
		clone:SetAttribute("ArenaGenerationIndex", placement.index)
		local primaryPart = clone.PrimaryPart :: BasePart
		local y = floorTop + primaryPart.Size.Y * 0.5
		clone:PivotTo(
			CFrame.new(placement.position.X, y, placement.position.Y)
				* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		)
		clone.Parent = breakables
	end

	generatedCount = #placements
	breakables:SetAttribute("GeneratedBreakableCount", generatedCount)
	breakables:SetAttribute("ArenaGenerationSeed", ArenaConfig.GenerationSeed)
end

function ArenaLayoutService.GetGeneratedCount(): number
	return generatedCount
end

return ArenaLayoutService
