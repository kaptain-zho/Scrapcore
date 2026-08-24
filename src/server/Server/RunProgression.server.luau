--!strict

local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local ClassService = require(script.Parent:WaitForChild("ClassService"))
local SpinnerCombatService = require(script.Parent:WaitForChild("SpinnerCombatService"))
local RammerCombatService = require(script.Parent:WaitForChild("RammerCombatService"))
local DevToolsService = require(script.Parent:WaitForChild("DevToolsService"))
local CollisionGroupService = require(script.Parent:WaitForChild("CollisionGroupService"))
local ArenaLayoutService = require(script.Parent:WaitForChild("ArenaLayoutService"))
local BreakableObjectService = require(script.Parent:WaitForChild("BreakableObjectService"))

CollisionGroupService.Init()
ProgressionService.Init()
ClassService.Init()
SpinnerCombatService.Init()
RammerCombatService.Init()
DevToolsService.Init()
ArenaLayoutService.Init()
BreakableObjectService.Init()
