--!strict

local ProfileDataConfig = table.freeze({
	SchemaVersion = 1,
	DataStoreName = "ScrapcoreProfile_v1",
	DataStoreScope = "BankedProfileXP",
	KeyPrefix = "Player_",
	EnableLiveDataStore = false,
	AllowLiveDataStoreInStudio = false,
	MaximumProcessedReceipts = 48,
	MaximumBankedXP = 1_000_000_000,
	MaximumRetries = 3,
	InitialRetryBackoff = 0.35,
	RetryBackoffMultiplier = 2,
})

return ProfileDataConfig
