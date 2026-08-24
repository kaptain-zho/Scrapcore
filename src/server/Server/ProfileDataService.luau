--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ExtractionConfig = require(shared:WaitForChild("ExtractionConfig"))
local ProfileDataConfig = require(script.Parent:WaitForChild("ProfileDataConfig"))

type ProfileData = {
	SchemaVersion: number,
	BankedXP: number,
	LifetimeExtractedXP: number,
	SuccessfulExtractions: number,
	ProcessedExtractionReceipts: {string},
}

type PendingReceipt = {
	id: string,
	amount: number,
	runSerial: number,
}

type ProfileState = {
	status: string,
	data: ProfileData?,
	pendingReceipt: PendingReceipt?,
	mockWriteMode: string,
	connections: {RBXScriptConnection},
	writingAttributes: boolean,
}

local states: {[Player]: ProfileState} = {}
local mockStore: {[number]: ProfileData} = {}
local initialized = false
local liveStore: GlobalDataStore? = nil

local ProfileDataService = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isSafeInteger(value: any, maximum: number): boolean
	return typeof(value) == "number"
		and isFinite(value)
		and value % 1 == 0
		and value >= 0
		and value <= maximum
end

local function defaultProfile(): ProfileData
	return {
		SchemaVersion = ProfileDataConfig.SchemaVersion,
		BankedXP = 0,
		LifetimeExtractedXP = 0,
		SuccessfulExtractions = 0,
		ProcessedExtractionReceipts = {},
	}
end

local function cloneProfile(data: ProfileData): ProfileData
	return {
		SchemaVersion = data.SchemaVersion,
		BankedXP = data.BankedXP,
		LifetimeExtractedXP = data.LifetimeExtractedXP,
		SuccessfulExtractions = data.SuccessfulExtractions,
		ProcessedExtractionReceipts = table.clone(data.ProcessedExtractionReceipts),
	}
end

local function sanitizeProfile(value: any): ProfileData?
	if value == nil then
		return defaultProfile()
	end
	if typeof(value) ~= "table" then
		return nil
	end
	local source = value :: {[any]: any}
	if
		source.SchemaVersion ~= ProfileDataConfig.SchemaVersion
		or not isSafeInteger(source.BankedXP, ProfileDataConfig.MaximumBankedXP)
		or not isSafeInteger(source.LifetimeExtractedXP, ProfileDataConfig.MaximumBankedXP)
		or not isSafeInteger(source.SuccessfulExtractions, ProfileDataConfig.MaximumBankedXP)
		or typeof(source.ProcessedExtractionReceipts) ~= "table"
	then
		return nil
	end

	local receipts: {string} = {}
	local seen: {[string]: boolean} = {}
	for _, receiptValue in source.ProcessedExtractionReceipts do
		if typeof(receiptValue) ~= "string" or #receiptValue < 8 or #receiptValue > 96 then
			return nil
		end
		if seen[receiptValue] ~= true then
			seen[receiptValue] = true
			table.insert(receipts, receiptValue)
		end
	end
	while #receipts > ProfileDataConfig.MaximumProcessedReceipts do
		table.remove(receipts, 1)
	end

	return {
		SchemaVersion = ProfileDataConfig.SchemaVersion,
		BankedXP = source.BankedXP,
		LifetimeExtractedXP = source.LifetimeExtractedXP,
		SuccessfulExtractions = source.SuccessfulExtractions,
		ProcessedExtractionReceipts = receipts,
	}
end

local function useLiveDataStore(): boolean
	if not ProfileDataConfig.EnableLiveDataStore then
		return false
	end
	return not RunService:IsStudio() or ProfileDataConfig.AllowLiveDataStoreInStudio
end

local function getAdapterName(): string
	return if useLiveDataStore() then "DataStore" else "Mock"
end

local function writeAttributes(player: Player, state: ProfileState)
	state.writingAttributes = true
	local data = state.data
	player:SetAttribute(ExtractionConfig.ProfileLoadedAttribute, state.status == "Loaded" and data ~= nil)
	player:SetAttribute(ExtractionConfig.ProfileStatusAttribute, state.status)
	player:SetAttribute(ExtractionConfig.ProfileAdapterAttribute, getAdapterName())
	player:SetAttribute(ExtractionConfig.BankedXPAttribute, if data ~= nil then data.BankedXP else 0)
	player:SetAttribute(
		ExtractionConfig.LifetimeExtractedXPAttribute,
		if data ~= nil then data.LifetimeExtractedXP else 0
	)
	player:SetAttribute(
		ExtractionConfig.SuccessfulExtractionsAttribute,
		if data ~= nil then data.SuccessfulExtractions else 0
	)
	state.writingAttributes = false
end

local function enforceAttributes(player: Player, state: ProfileState)
	if state.writingAttributes or states[player] ~= state then
		return
	end
	writeAttributes(player, state)
end

local function getKey(player: Player): string
	return ProfileDataConfig.KeyPrefix .. tostring(player.UserId)
end

local function waitBeforeRetry(attempt: number)
	if attempt >= ProfileDataConfig.MaximumRetries then
		return
	end
	task.wait(ProfileDataConfig.InitialRetryBackoff * ProfileDataConfig.RetryBackoffMultiplier ^ (attempt - 1))
end

local function loadFromDataStore(player: Player): ProfileData?
	local store = liveStore
	if store == nil then
		return nil
	end
	for attempt = 1, ProfileDataConfig.MaximumRetries do
		local success, result = pcall(function(): any
			return store:GetAsync(getKey(player))
		end)
		if success then
			return sanitizeProfile(result)
		end
		warn(string.format("Profile load attempt %d failed for user %d", attempt, player.UserId))
		waitBeforeRetry(attempt)
	end
	return nil
end

local function loadPlayer(player: Player)
	local state = states[player]
	if state == nil or state.status ~= "Loading" then
		return
	end
	local data: ProfileData?
	if useLiveDataStore() then
		data = loadFromDataStore(player)
	else
		local stored = mockStore[player.UserId]
		data = if stored ~= nil then cloneProfile(stored) else defaultProfile()
	end
	if states[player] ~= state or player.Parent ~= Players then
		return
	end
	if data == nil then
		state.status = "Failed"
		state.data = nil
		warn(string.format("Profile remained unavailable for user %d; deployment is blocked", player.UserId))
	else
		state.status = "Loaded"
		state.data = data
	end
	writeAttributes(player, state)
end

local function connectPlayer(player: Player)
	if states[player] ~= nil then
		return
	end
	local state: ProfileState = {
		status = "Loading",
		data = nil,
		pendingReceipt = nil,
		mockWriteMode = "Normal",
		connections = {},
		writingAttributes = false,
	}
	states[player] = state
	for _, attributeName in {
		ExtractionConfig.ProfileLoadedAttribute,
		ExtractionConfig.ProfileStatusAttribute,
		ExtractionConfig.ProfileAdapterAttribute,
		ExtractionConfig.BankedXPAttribute,
		ExtractionConfig.LifetimeExtractedXPAttribute,
		ExtractionConfig.SuccessfulExtractionsAttribute,
	} do
		table.insert(state.connections, player:GetAttributeChangedSignal(attributeName):Connect(function()
			enforceAttributes(player, state)
		end))
	end
	writeAttributes(player, state)
	task.spawn(loadPlayer, player)
end

local function disconnectPlayer(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	for _, connection in state.connections do
		connection:Disconnect()
	end
	states[player] = nil
end

local function containsReceipt(data: ProfileData, receiptId: string): boolean
	return table.find(data.ProcessedExtractionReceipts, receiptId) ~= nil
end

local function applyReceipt(data: ProfileData, receipt: PendingReceipt): ProfileData?
	if containsReceipt(data, receipt.id) then
		return cloneProfile(data)
	end
	if
		data.BankedXP > ProfileDataConfig.MaximumBankedXP - receipt.amount
		or data.LifetimeExtractedXP > ProfileDataConfig.MaximumBankedXP - receipt.amount
		or data.SuccessfulExtractions >= ProfileDataConfig.MaximumBankedXP
	then
		return nil
	end
	local updated = cloneProfile(data)
	updated.BankedXP += receipt.amount
	updated.LifetimeExtractedXP += receipt.amount
	updated.SuccessfulExtractions += 1
	table.insert(updated.ProcessedExtractionReceipts, receipt.id)
	while #updated.ProcessedExtractionReceipts > ProfileDataConfig.MaximumProcessedReceipts do
		table.remove(updated.ProcessedExtractionReceipts, 1)
	end
	return updated
end

local function bankMock(player: Player, state: ProfileState, receipt: PendingReceipt): ProfileData?
	for attempt = 1, ProfileDataConfig.MaximumRetries do
		local mode = state.mockWriteMode
		if mode == "FailAll" then
			waitBeforeRetry(attempt)
			continue
		end
		local current = mockStore[player.UserId]
		if current == nil then
			current = if state.data ~= nil then cloneProfile(state.data) else defaultProfile()
		end
		local updated = applyReceipt(current, receipt)
		if updated == nil then
			return nil
		end
		mockStore[player.UserId] = cloneProfile(updated)
		if mode == "UncertainOnce" and attempt == 1 then
			waitBeforeRetry(attempt)
			continue
		end
		return updated
	end
	return nil
end

local function bankDataStore(player: Player, receipt: PendingReceipt): ProfileData?
	local store = liveStore
	if store == nil then
		return nil
	end
	for attempt = 1, ProfileDataConfig.MaximumRetries do
		local invalidStoredValue = false
		local success, result = pcall(function(): any
			return store:UpdateAsync(getKey(player), function(currentValue: any)
				local current = sanitizeProfile(currentValue)
				if current == nil then
					invalidStoredValue = true
					return nil
				end
				local updated = applyReceipt(current, receipt)
				if updated == nil then
					invalidStoredValue = true
					return nil
				end
				return updated, { player.UserId }
			end)
		end)
		if success then
			local updated = sanitizeProfile(result)
			if updated ~= nil and containsReceipt(updated, receipt.id) then
				return updated
			end
			if invalidStoredValue then
				return nil
			end
		else
			warn(string.format("Profile bank attempt %d failed for user %d", attempt, player.UserId))
		end
		waitBeforeRetry(attempt)
	end
	return nil
end

function ProfileDataService.IsLoaded(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.status == "Loaded" and state.data ~= nil
end

function ProfileDataService.GetBankedXP(player: Player): number
	local state = states[player]
	return if state ~= nil and state.data ~= nil then state.data.BankedXP else 0
end

function ProfileDataService.HasPendingReceipt(player: Player, runSerial: number): boolean
	local state = states[player]
	local pending = if state ~= nil then state.pendingReceipt else nil
	return pending ~= nil and pending.runSerial == runSerial
end

function ProfileDataService.AbandonPendingReceipt(player: Player, runSerial: number)
	local state = states[player]
	local pending = if state ~= nil then state.pendingReceipt else nil
	if state ~= nil and pending ~= nil and pending.runSerial == runSerial then
		state.pendingReceipt = nil
	end
end

function ProfileDataService.BankRunXP(player: Player, amount: number, runSerial: number): (boolean, number)
	local state = states[player]
	if
		state == nil
		or state.status ~= "Loaded"
		or state.data == nil
		or player.Parent ~= Players
		or not isSafeInteger(amount, ExtractionConfig.MaximumUnbankedRunXP)
		or amount <= 0
		or not isSafeInteger(runSerial, 1_000_000_000)
	then
		return false, ProfileDataService.GetBankedXP(player)
	end

	local pending = state.pendingReceipt
	if pending ~= nil and (pending.amount ~= amount or pending.runSerial ~= runSerial) then
		return false, state.data.BankedXP
	end
	if pending == nil then
		pending = {
			id = HttpService:GenerateGUID(false),
			amount = amount,
			runSerial = runSerial,
		}
		state.pendingReceipt = pending
	end

	local updated = if useLiveDataStore()
		then bankDataStore(player, pending)
		else bankMock(player, state, pending)
	if updated == nil then
		return false, state.data.BankedXP
	end
	state.data = updated
	state.pendingReceipt = nil
	writeAttributes(player, state)
	return true, updated.BankedXP
end

function ProfileDataService.SetStudioMockWriteMode(player: Player, mode: string): boolean
	local state = states[player]
	if
		not RunService:IsStudio()
		or useLiveDataStore()
		or state == nil
		or (mode ~= "Normal" and mode ~= "FailAll" and mode ~= "UncertainOnce")
	then
		return false
	end
	state.mockWriteMode = mode
	return true
end

function ProfileDataService.ResetStudioMockProfiles(): boolean
	if not RunService:IsStudio() or useLiveDataStore() then
		return false
	end
	table.clear(mockStore)
	return true
end

function ProfileDataService.ReloadStudioMockProfile(player: Player): boolean
	local state = states[player]
	if
		not RunService:IsStudio()
		or useLiveDataStore()
		or state == nil
		or state.pendingReceipt ~= nil
	then
		return false
	end
	state.status = "Loading"
	state.data = nil
	writeAttributes(player, state)
	task.spawn(loadPlayer, player)
	return true
end

function ProfileDataService.SetStudioMockProfileUnavailable(player: Player): boolean
	local state = states[player]
	if
		not RunService:IsStudio()
		or useLiveDataStore()
		or state == nil
		or state.pendingReceipt ~= nil
	then
		return false
	end
	state.status = "Failed"
	state.data = nil
	writeAttributes(player, state)
	return true
end

function ProfileDataService.GetStudioDebugSnapshot(player: Player): any
	if not RunService:IsStudio() then
		return nil
	end
	local state = states[player]
	if state == nil then
		return nil
	end
	return {
		status = state.status,
		adapter = getAdapterName(),
		data = if state.data ~= nil then cloneProfile(state.data) else nil,
		pendingReceipt = if state.pendingReceipt ~= nil then table.clone(state.pendingReceipt) else nil,
		stored = if mockStore[player.UserId] ~= nil then cloneProfile(mockStore[player.UserId]) else nil,
	}
end

function ProfileDataService.Init()
	if initialized then
		return
	end
	initialized = true
	if useLiveDataStore() then
		liveStore = DataStoreService:GetDataStore(ProfileDataConfig.DataStoreName, ProfileDataConfig.DataStoreScope)
	end
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
end

return ProfileDataService
