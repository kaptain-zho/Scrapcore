--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local commitments: {[Player]: { character: Model, expiresAt: number, multiplier: number, minimumDot: number }} = {}

local DisplacementResistanceService = {}

function DisplacementResistanceService.BeginFrontalCommitment(
	player: Player,
	character: Model,
	expiresAt: number,
	multiplier: number,
	minimumDot: number
)
	if
		player.Character ~= character
		or character.Parent == nil
		or expiresAt <= Workspace:GetServerTimeNow()
		or multiplier < 0
		or multiplier > 1
		or minimumDot < -1
		or minimumDot > 1
	then
		return
	end
	commitments[player] = {
		character = character,
		expiresAt = expiresAt,
		multiplier = multiplier,
		minimumDot = minimumDot,
	}
end

function DisplacementResistanceService.Clear(player: Player)
	commitments[player] = nil
end

function DisplacementResistanceService.GetHorizontalMultiplier(
	target: Model,
	knockbackDirection: Vector3
): number
	local player = Players:GetPlayerFromCharacter(target)
	if player == nil then
		return 1
	end
	local commitment = commitments[player]
	if
		commitment == nil
		or commitment.character ~= target
		or target.Parent == nil
		or Workspace:GetServerTimeNow() > commitment.expiresAt
	then
		commitments[player] = nil
		return 1
	end
	local root = target:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return 1
	end
	local horizontalKnockback = Vector3.new(knockbackDirection.X, 0, knockbackDirection.Z)
	local horizontalForward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if horizontalKnockback.Magnitude <= 0.01 or horizontalForward.Magnitude <= 0.01 then
		return 1
	end
	local directionTowardSource = -horizontalKnockback.Unit
	return if horizontalForward.Unit:Dot(directionTowardSource) >= commitment.minimumDot
		then commitment.multiplier
		else 1
end

Players.PlayerRemoving:Connect(function(player: Player)
	commitments[player] = nil
end)

return DisplacementResistanceService
