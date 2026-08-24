--!strict

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local PLAYER_COLLISION_GROUP = "ScrapcorePlayers"
local BREAKABLE_COLLISION_GROUP = "ScrapcoreBreakables"

type PlayerConnections = {
	characterAdded: RBXScriptConnection,
	characterDescendantAdded: RBXScriptConnection?,
}

local initialized = false
local playerConnections: {[Player]: PlayerConnections} = {}

local CollisionGroupService = {
	PlayerCollisionGroup = PLAYER_COLLISION_GROUP,
	BreakableCollisionGroup = BREAKABLE_COLLISION_GROUP,
}

local function registerCollisionGroup(name: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

local function configureCollisionMatrix()
	registerCollisionGroup(PLAYER_COLLISION_GROUP)
	registerCollisionGroup(BREAKABLE_COLLISION_GROUP)

	PhysicsService:CollisionGroupSetCollidable(PLAYER_COLLISION_GROUP, PLAYER_COLLISION_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(PLAYER_COLLISION_GROUP, BREAKABLE_COLLISION_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(PLAYER_COLLISION_GROUP, "Default", true)
	PhysicsService:CollisionGroupSetCollidable(BREAKABLE_COLLISION_GROUP, "Default", true)
end

function CollisionGroupService.ApplyCharacterPart(part: BasePart)
	part.CollisionGroup = PLAYER_COLLISION_GROUP
end

function CollisionGroupService.ApplyBreakablePart(part: BasePart)
	part.CollisionGroup = BREAKABLE_COLLISION_GROUP
end

function CollisionGroupService.ApplyCharacter(character: Instance)
	if character:IsA("BasePart") then
		CollisionGroupService.ApplyCharacterPart(character)
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			CollisionGroupService.ApplyCharacterPart(descendant)
		end
	end
end

function CollisionGroupService.ApplyBreakable(model: Instance)
	if model:IsA("BasePart") then
		CollisionGroupService.ApplyBreakablePart(model)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			CollisionGroupService.ApplyBreakablePart(descendant)
		end
	end
end

local function bindCharacter(player: Player, character: Model)
	local connections = playerConnections[player]
	if connections == nil then
		return
	end
	if connections.characterDescendantAdded ~= nil then
		connections.characterDescendantAdded:Disconnect()
	end

	CollisionGroupService.ApplyCharacter(character)
	connections.characterDescendantAdded = character.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("BasePart") then
			CollisionGroupService.ApplyCharacterPart(descendant)
		end
	end)
end

local function connectPlayer(player: Player)
	if playerConnections[player] ~= nil then
		return
	end

	local characterAdded = player.CharacterAdded:Connect(function(character: Model)
		bindCharacter(player, character)
	end)
	playerConnections[player] = {
		characterAdded = characterAdded,
		characterDescendantAdded = nil,
	}
	if player.Character ~= nil then
		bindCharacter(player, player.Character)
	end
end

local function disconnectPlayer(player: Player)
	local connections = playerConnections[player]
	if connections == nil then
		return
	end
	connections.characterAdded:Disconnect()
	if connections.characterDescendantAdded ~= nil then
		connections.characterDescendantAdded:Disconnect()
	end
	playerConnections[player] = nil
end

function CollisionGroupService.Init()
	if initialized then
		return
	end
	initialized = true
	configureCollisionMatrix()

	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return CollisionGroupService
