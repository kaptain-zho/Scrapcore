--!strict

local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local ClassService = require(script.Parent:WaitForChild("ClassService"))
local CollisionGroupService = require(script.Parent:WaitForChild("CollisionGroupService"))
local ArenaLayoutService = require(script.Parent:WaitForChild("ArenaLayoutService"))
local BreakableObjectService = require(script.Parent:WaitForChild("BreakableObjectService"))

CollisionGroupService.Init()
ProgressionService.Init()
ClassService.Init()
ArenaLayoutService.Init()
BreakableObjectService.Init()
