--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MAXIMUM_DAMAGE_PER_APPLICATION = 500

local lastDamageAt: {[Player]: number} = {}
local damageEvent = Instance.new("BindableEvent")

local AuthoritativeDamageService = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function AuthoritativeDamageService.ApplyHumanoidDamage(humanoid: Humanoid, amount: number): number
	if humanoid.Parent == nil or humanoid.Health <= 0 or not isFinite(amount) or amount <= 0 then
		return 0
	end
	local safeAmount = math.clamp(amount, 0, MAXIMUM_DAMAGE_PER_APPLICATION)
	local healthBefore = humanoid.Health
	humanoid:TakeDamage(safeAmount)
	local appliedDamage = math.max(healthBefore - humanoid.Health, 0)
	if appliedDamage <= 0 then
		return 0
	end

	local character = humanoid.Parent
	local player = if character ~= nil and character:IsA("Model")
		then Players:GetPlayerFromCharacter(character)
		else nil
	if player ~= nil then
		local now = Workspace:GetServerTimeNow()
		lastDamageAt[player] = now
		damageEvent:Fire(player, appliedDamage, now)
	end
	return appliedDamage
end

function AuthoritativeDamageService.GetLastDamageAt(player: Player): number
	return lastDamageAt[player] or -math.huge
end

function AuthoritativeDamageService.Connect(
	callback: (player: Player, amount: number, serverTime: number) -> ()
): RBXScriptConnection
	return damageEvent.Event:Connect(callback)
end

Players.PlayerRemoving:Connect(function(player: Player)
	lastDamageAt[player] = nil
end)

return AuthoritativeDamageService
