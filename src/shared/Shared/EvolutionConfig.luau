--!strict

export type GateDefinition = {
	Level: number,
	Status: string,
	SelectionImplemented: boolean,
	Description: string,
}

export type RouteNode = {
	Level: number,
	ParentId: string?,
	Children: {string},
	Status: string,
}

local EVOLUTION_GATES = table.freeze({ 8, 20, 35, 75, 150, 250, 300 })

local GATE_DEFINITIONS: {[number]: GateDefinition} = {
	[8] = table.freeze({
		Level = 8,
		Status = "Implemented",
		SelectionImplemented = true,
		Description = "Choose Striker, Spinner, or Rammer for this life.",
	}),
	[20] = table.freeze({
		Level = 20,
		Status = "Designed",
		SelectionImplemented = false,
		Description = "Choose one of two provisional specializations from the Level 8 branch.",
	}),
	[35] = table.freeze({
		Level = 35,
		Status = "Route Data Only",
		SelectionImplemented = false,
		Description = "Reserved evolution gate; robot choices are not designed or implemented.",
	}),
	[75] = table.freeze({
		Level = 75,
		Status = "Route Data Only",
		SelectionImplemented = false,
		Description = "Reserved evolution gate; robot choices are not designed or implemented.",
	}),
	[150] = table.freeze({
		Level = 150,
		Status = "Route Data Only",
		SelectionImplemented = false,
		Description = "Reserved evolution gate; robot choices are not designed or implemented.",
	}),
	[250] = table.freeze({
		Level = 250,
		Status = "Route Data Only",
		SelectionImplemented = false,
		Description = "Reserved evolution gate; robot choices are not designed or implemented.",
	}),
	[300] = table.freeze({
		Level = 300,
		Status = "Route Data Only",
		SelectionImplemented = false,
		Description = "Final power-progression gate; robot choices are not designed or implemented.",
	}),
}

local ROUTE_NODES: {[string]: RouteNode} = {
	ScrapRunner = table.freeze({
		Level = 1,
		ParentId = nil,
		Children = table.freeze({ "Striker", "Spinner", "Rammer" }),
		Status = "Implemented",
	}),
	Striker = table.freeze({
		Level = 8,
		ParentId = "ScrapRunner",
		Children = table.freeze({ "Pilebreaker", "TwinMaul" }),
		Status = "Implemented",
	}),
	Spinner = table.freeze({
		Level = 8,
		ParentId = "ScrapRunner",
		Children = table.freeze({ "Stormring", "Ripsaw" }),
		Status = "Implemented",
	}),
	Rammer = table.freeze({
		Level = 8,
		ParentId = "ScrapRunner",
		Children = table.freeze({ "Ironclad", "Liftjack" }),
		Status = "Implemented",
	}),
	Pilebreaker = table.freeze({ Level = 20, ParentId = "Striker", Children = table.freeze({}), Status = "Future Work" }),
	TwinMaul = table.freeze({ Level = 20, ParentId = "Striker", Children = table.freeze({}), Status = "Future Work" }),
	Stormring = table.freeze({ Level = 20, ParentId = "Spinner", Children = table.freeze({}), Status = "Future Work" }),
	Ripsaw = table.freeze({ Level = 20, ParentId = "Spinner", Children = table.freeze({}), Status = "Future Work" }),
	Ironclad = table.freeze({ Level = 20, ParentId = "Rammer", Children = table.freeze({}), Status = "Future Work" }),
	Liftjack = table.freeze({ Level = 20, ParentId = "Rammer", Children = table.freeze({}), Status = "Future Work" }),
}

local function getNextGate(level: number): number?
	if level ~= level or level <= -math.huge or level >= math.huge then
		return EVOLUTION_GATES[1]
	end
	local safeLevel = math.max(math.floor(level), 1)
	for _, gate in EVOLUTION_GATES do
		if gate > safeLevel then
			return gate
		end
	end
	return nil
end

return table.freeze({
	Gates = EVOLUTION_GATES,
	GateDefinitions = table.freeze(GATE_DEFINITIONS),
	RouteNodes = table.freeze(ROUTE_NODES),
	GetNextGate = getNextGate,
})
