--!strict

local HUDLayoutConfig = {}

HUDLayoutConfig.Margin = 12
HUDLayoutConfig.HealthTop = 12
HUDLayoutConfig.HealthHeight = 42
HUDLayoutConfig.UpperRailTop = 66
HUDLayoutConfig.DesktopProgressionTop = 134
HUDLayoutConfig.PortraitProgressionTop = 134
HUDLayoutConfig.PortraitEvolutionTop = 242
HUDLayoutConfig.DesktopPlayerListReserveWidth = 304
HUDLayoutConfig.DesktopMinimumWidth = 900

export type LayoutMode = "Desktop" | "LandscapeCompact" | "PortraitCompact"

function HUDLayoutConfig.GetMode(viewport: Vector2): LayoutMode
	if viewport.X < viewport.Y then
		return "PortraitCompact"
	elseif viewport.X < HUDLayoutConfig.DesktopMinimumWidth or viewport.Y < 700 then
		return "LandscapeCompact"
	end
	return "Desktop"
end

function HUDLayoutConfig.GetProgressionPosition(viewport: Vector2): UDim2
	local mode = HUDLayoutConfig.GetMode(viewport)
	if mode == "Desktop" then
		return UDim2.fromOffset(HUDLayoutConfig.Margin, HUDLayoutConfig.DesktopProgressionTop)
	elseif mode == "PortraitCompact" then
		return UDim2.new(1, -HUDLayoutConfig.Margin, 0, HUDLayoutConfig.PortraitProgressionTop)
	end
	return UDim2.new(1, -HUDLayoutConfig.Margin, 0, HUDLayoutConfig.UpperRailTop)
end

function HUDLayoutConfig.GetArenaProfilePosition(_viewport: Vector2): UDim2
	return UDim2.fromOffset(HUDLayoutConfig.Margin, HUDLayoutConfig.UpperRailTop)
end

return table.freeze(HUDLayoutConfig)
