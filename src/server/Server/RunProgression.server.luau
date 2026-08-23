--!strict

local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local ArenaLayoutService = require(script.Parent:WaitForChild("ArenaLayoutService"))
local BreakableObjectService = require(script.Parent:WaitForChild("BreakableObjectService"))

ProgressionService.Init()
ArenaLayoutService.Init()
BreakableObjectService.Init()
