--!strict

local ExtractionConfig = table.freeze({
	ZoneName = "RunXPExtraction",
	ZoneCenter = Vector3.new(166, 3.5, 166),
	ZoneSize = Vector3.new(18, 7, 18),
	BreakableClearance = 18,
	ExtractionDuration = 10,
	ServerUpdateInterval = 0.05,
	PromptActivationDistance = 10,
	PromptHoldDuration = 0.35,
	RequestRateWindow = 3,
	MaximumRequestsPerWindow = 5,
	MinimumRequestInterval = 0.2,
	MaximumUnbankedRunXP = 10_000_000,
	StatusMessageDuration = 2.5,
	RunXPAttribute = "UnbankedRunXP",
	BankedXPAttribute = "BankedProfileXP",
	ProfileLoadedAttribute = "ProfileDataLoaded",
	ProfileStatusAttribute = "ProfileDataStatus",
	ProfileAdapterAttribute = "ProfileDataAdapter",
	LifetimeExtractedXPAttribute = "LifetimeExtractedXP",
	SuccessfulExtractionsAttribute = "SuccessfulExtractions",
	PortalTitle = "BANK YOUR RUN XP",
	PortalInstructions = table.concat({
		"Remain undamaged inside the extraction zone for 10 seconds",
		"Taking damage resets the timer",
		"Leaving cancels extraction; dying or disconnecting loses all unbanked XP",
	}, "\n"),
})

return ExtractionConfig
