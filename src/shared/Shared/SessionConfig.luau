--!strict

local LOBBY_CENTER = Vector3.new(0, 0, 700)

local SessionConfig = table.freeze({
	SessionAttribute = "PlayerSessionState",
	LobbyState = "Lobby",
	ArenaState = "Arena",
	LobbyGeneratedAttribute = "ScrapcoreGeneratedLobby",
	LobbyCenter = LOBBY_CENTER,
	LobbySize = Vector2.new(120, 90),
	LobbyFloorThickness = 1,
	LobbyWallHeight = 14,
	LobbyWallThickness = 2,
	LobbySpawnPositions = table.freeze({
		LOBBY_CENTER + Vector3.new(-9, 1.95, 30),
		LOBBY_CENTER + Vector3.new(9, 1.95, 30),
		LOBBY_CENTER + Vector3.new(-9, 1.95, 20),
		LOBBY_CENTER + Vector3.new(9, 1.95, 20),
	}),
	MainPortalPosition = LOBBY_CENTER + Vector3.new(0, 4.5, -34),
	MainPortalActivationDistance = 14,
	DeployCooldown = 1.5,
	DeployRequestWindow = 1,
	MaximumDeployRequestsPerWindow = 5,
	MinimumDeployRequestInterval = 0.12,
	CharacterRootHeight = 1.95,
	LobbyProtectionName = "ScrapcoreLobbyProtection",
	MaximumFeedbackLength = 96,
	DeploymentAcceptedFeedback = "Deployment accepted. Entering the Main Arena...",
})

return SessionConfig
