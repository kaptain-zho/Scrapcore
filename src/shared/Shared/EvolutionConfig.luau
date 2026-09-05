--!strict

export type GateDefinition = { Level: number, Status: string, SelectionImplemented: boolean, Description: string }
export type RouteNode = {
	DisplayName: string,
	Level: number,
	ParentIds: {string},
	Children: {string},
	Status: string,
	PrototypeAvailable: boolean,
	PublicSelectable: boolean,
}

local EVOLUTION_GATES = table.freeze({ 8, 20, 35, 75, 150, 250, 300 })
local LEVEL_20_PUBLIC_ENABLED = false
local GATE_DEFINITIONS: {[number]: GateDefinition} = {
	[8] = table.freeze({ Level = 8, Status = "Implemented", SelectionImplemented = true, Description = "Choose Striker, Spinner, or Rammer for this life." }),
	[20] = table.freeze({ Level = 20, Status = "Internal Prototype", SelectionImplemented = false, Description = "Three families are under construction; Impact Foundry and Motion Works are Studio-testable only." }),
	[35] = table.freeze({ Level = 35, Status = "Approved Route Data", SelectionImplemented = false, Description = "Approved graph data only; no Level 35 robot is implemented." }),
	[75] = table.freeze({ Level = 75, Status = "Approved Route Data", SelectionImplemented = false, Description = "Approved graph data only; no Level 75 robot is implemented." }),
	[150] = table.freeze({ Level = 150, Status = "Approved Route Data", SelectionImplemented = false, Description = "Approved graph data only; no Level 150 robot is implemented." }),
	[250] = table.freeze({ Level = 250, Status = "Approved Route Data", SelectionImplemented = false, Description = "Approved graph data only; no Level 250 robot is implemented." }),
	[300] = table.freeze({ Level = 300, Status = "Approved Route Data", SelectionImplemented = false, Description = "Final approved route-data gate; no Level 300 robot is implemented." }),
}

local function routeNode(displayName: string, level: number, parentIds: {string}, children: {string}, status: string, prototypeAvailable: boolean?, publicSelectable: boolean?): RouteNode
	return table.freeze({
		DisplayName = displayName,
		Level = level,
		ParentIds = table.freeze(parentIds),
		Children = table.freeze(children),
		Status = status,
		PrototypeAvailable = prototypeAvailable == true,
		PublicSelectable = publicSelectable == true,
	})
end

local NODE_ORDER = table.freeze({
	"ScrapRunner",
	"Striker", "Spinner", "Rammer",
	"ImpactFoundry", "MotionWorks", "FieldRig",
	"Pilebreaker", "TwinMaul", "Stormring", "Ripsaw", "Ironclad", "Liftjack",
	"Faultpress", "Crossmaul", "ArcCrown", "Slipsaw", "Pincaster", "Counterfort",
	"Quakeclock", "Dreadring", "VectorRasp", "Farneedle", "Snarewright", "BastionJack",
	"RuptureDrive", "Crownmill", "NeedleRack", "DeadlockRig", "ReprisalFort", "PhantomRail",
	"TectonicForge", "MawHalo", "NorthstarLance", "Lockgrid", "Flashsaw", "IronSanctum",
})

local ROUTE_NODES: {[string]: RouteNode} = {
	ScrapRunner = routeNode("Scrap Runner", 1, {}, { "Striker", "Spinner", "Rammer" }, "Implemented", true, true),
	Striker = routeNode("Striker", 8, { "ScrapRunner" }, { "ImpactFoundry", "MotionWorks", "FieldRig" }, "Prototype", true, true),
	Spinner = routeNode("Spinner", 8, { "ScrapRunner" }, { "ImpactFoundry", "MotionWorks", "FieldRig" }, "Prototype", true, true),
	Rammer = routeNode("Rammer", 8, { "ScrapRunner" }, { "ImpactFoundry", "MotionWorks", "FieldRig" }, "Prototype", true, true),
	ImpactFoundry = routeNode("Impact Foundry", 20, { "Striker", "Spinner", "Rammer" }, { "Pilebreaker", "TwinMaul", "Ironclad" }, "Studio Prototype", true, false),
	MotionWorks = routeNode("Motion Works", 20, { "Striker", "Spinner", "Rammer" }, { "TwinMaul", "Stormring", "Ripsaw" }, "Studio Prototype", true, false),
	FieldRig = routeNode("Field Rig", 20, { "Striker", "Spinner", "Rammer" }, { "Stormring", "Ironclad", "Liftjack" }, "Future Work"),
	Pilebreaker = routeNode("Pilebreaker", 35, { "ImpactFoundry" }, { "Faultpress", "Crossmaul" }, "Future Work"),
	TwinMaul = routeNode("Twin Maul", 35, { "ImpactFoundry", "MotionWorks" }, { "Crossmaul", "ArcCrown" }, "Future Work"),
	Stormring = routeNode("Stormring", 35, { "MotionWorks", "FieldRig" }, { "ArcCrown", "Pincaster" }, "Future Work"),
	Ripsaw = routeNode("Ripsaw", 35, { "MotionWorks" }, { "Slipsaw" }, "Future Work"),
	Ironclad = routeNode("Ironclad", 35, { "ImpactFoundry", "FieldRig" }, { "Faultpress", "Counterfort" }, "Future Work"),
	Liftjack = routeNode("Liftjack", 35, { "FieldRig" }, { "Slipsaw", "Pincaster", "Counterfort" }, "Future Work"),
	Faultpress = routeNode("Faultpress", 75, { "Pilebreaker", "Ironclad" }, { "Quakeclock", "Dreadring" }, "Future Work"),
	Crossmaul = routeNode("Crossmaul", 75, { "Pilebreaker", "TwinMaul" }, { "Quakeclock", "Farneedle" }, "Future Work"),
	ArcCrown = routeNode("Arc Crown", 75, { "TwinMaul", "Stormring" }, { "Dreadring", "VectorRasp" }, "Future Work"),
	Slipsaw = routeNode("Slipsaw", 75, { "Ripsaw", "Liftjack" }, { "VectorRasp", "BastionJack" }, "Future Work"),
	Pincaster = routeNode("Pincaster", 75, { "Stormring", "Liftjack" }, { "Farneedle", "Snarewright" }, "Future Work"),
	Counterfort = routeNode("Counterfort", 75, { "Ironclad", "Liftjack" }, { "Snarewright", "BastionJack" }, "Future Work"),
	Quakeclock = routeNode("Quakeclock", 150, { "Faultpress", "Crossmaul" }, { "RuptureDrive", "ReprisalFort" }, "Future Work"),
	Dreadring = routeNode("Dreadring", 150, { "Faultpress", "ArcCrown" }, { "Crownmill" }, "Future Work"),
	VectorRasp = routeNode("Vector Rasp", 150, { "ArcCrown", "Slipsaw" }, { "RuptureDrive", "Crownmill", "PhantomRail" }, "Future Work"),
	Farneedle = routeNode("Farneedle", 150, { "Crossmaul", "Pincaster" }, { "NeedleRack", "PhantomRail" }, "Future Work"),
	Snarewright = routeNode("Snarewright", 150, { "Pincaster", "Counterfort" }, { "NeedleRack", "DeadlockRig" }, "Future Work"),
	BastionJack = routeNode("Bastion Jack", 150, { "Slipsaw", "Counterfort" }, { "DeadlockRig", "ReprisalFort" }, "Future Work"),
	RuptureDrive = routeNode("Rupture Drive", 250, { "Quakeclock", "VectorRasp" }, { "TectonicForge", "MawHalo" }, "Future Work"),
	Crownmill = routeNode("Crownmill", 250, { "Dreadring", "VectorRasp" }, { "MawHalo", "Flashsaw" }, "Future Work"),
	NeedleRack = routeNode("Needle Rack", 250, { "Farneedle", "Snarewright" }, { "NorthstarLance", "Lockgrid" }, "Future Work"),
	DeadlockRig = routeNode("Deadlock Rig", 250, { "Snarewright", "BastionJack" }, { "Lockgrid", "IronSanctum" }, "Future Work"),
	ReprisalFort = routeNode("Reprisal Fort", 250, { "Quakeclock", "BastionJack" }, { "TectonicForge", "IronSanctum" }, "Future Work"),
	PhantomRail = routeNode("Phantom Rail", 250, { "VectorRasp", "Farneedle" }, { "NorthstarLance", "Flashsaw" }, "Future Work"),
	TectonicForge = routeNode("Tectonic Forge", 300, { "RuptureDrive", "ReprisalFort" }, {}, "Future Work"),
	MawHalo = routeNode("Maw Halo", 300, { "RuptureDrive", "Crownmill" }, {}, "Future Work"),
	NorthstarLance = routeNode("Northstar Lance", 300, { "NeedleRack", "PhantomRail" }, {}, "Future Work"),
	Lockgrid = routeNode("Lockgrid", 300, { "NeedleRack", "DeadlockRig" }, {}, "Future Work"),
	Flashsaw = routeNode("Flashsaw", 300, { "Crownmill", "PhantomRail" }, {}, "Future Work"),
	IronSanctum = routeNode("Iron Sanctum", 300, { "DeadlockRig", "ReprisalFort" }, {}, "Future Work"),
}

local function getNextGate(level: number): number?
	if level ~= level or level <= -math.huge or level >= math.huge then
		return EVOLUTION_GATES[1]
	end
	local safeLevel = math.max(math.floor(level), 1)
	for _, gate in EVOLUTION_GATES do
		if gate > safeLevel then return gate end
	end
	return nil
end

return table.freeze({
	Gates = EVOLUTION_GATES,
	GateDefinitions = table.freeze(GATE_DEFINITIONS),
	NodeOrder = NODE_ORDER,
	RouteNodes = table.freeze(ROUTE_NODES),
	Level20PublicEnabled = LEVEL_20_PUBLIC_ENABLED,
	CurrentNodeAttribute = "EvolutionCurrentNode",
	CommittedFamilyAttribute = "EvolutionCommittedLevel20Family",
	ReachedGatesAttribute = "EvolutionReachedGates",
	RouteRunSerialAttribute = "EvolutionRouteRunSerial",
	Level8AncestryAttribute = "EvolutionLevel8Ancestry",
	AcceptedRequestCountAttribute = "EvolutionRouteAcceptedRequestCount",
	RejectedRequestCountAttribute = "EvolutionRouteRejectedRequestCount",
	GetNextGate = getNextGate,
})
