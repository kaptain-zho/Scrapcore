--!strict

local ENABLE_OUTSIDE_STUDIO = false
local ALLOWED_USER_IDS = table.freeze({} :: {number})

local function isAuthorized(userId: number, isStudio: boolean): boolean
	if isStudio then
		return true
	end
	if not ENABLE_OUTSIDE_STUDIO then
		return false
	end
	for _, allowedUserId in ALLOWED_USER_IDS do
		if userId == allowedUserId then
			return true
		end
	end
	return false
end

return table.freeze({
	-- Production access is deliberately off. Add explicit numeric UserIds only when
	-- an approved private-server workflow exists, then separately enable the switch.
	EnableOutsideStudio = ENABLE_OUTSIDE_STUDIO,
	AllowedUserIds = ALLOWED_USER_IDS,
	RequestWindow = 1,
	MaximumRequestsPerWindow = 10,
	MinimumRequestInterval = 0.05,
	IsAuthorized = isAuthorized,
})
