--!strict

export type CombatModifiers = {
	DamageBonus: number,
	MaxDamage: number,
	KnockbackSpeed: number,
	CooldownPenalty: number,
	MaxCooldown: number,
}

export type ClassDefinition = {
	DisplayName: string,
	Tier: number,
	Enabled: boolean,
	Status: string,
	Role: string,
	Tradeoff: string,
	Combat: CombatModifiers?,
}

local definitions: {[string]: ClassDefinition} = {
	ScrapRunner = table.freeze({
		DisplayName = "Scrap Runner",
		Tier = 1,
		Enabled = true,
		Status = "Implemented",
		Role = "Flexible close-range robot",
		Tradeoff = "Balanced standard hammer with no specialization.",
	}),
	Striker = table.freeze({
		DisplayName = "Striker",
		Tier = 8,
		Enabled = true,
		Status = "Prototype",
		Role = "Heavy close-range disruptor",
		Tradeoff = "Heavy hammer hits, stronger shove, slower recovery.",
		Combat = table.freeze({
			DamageBonus = 5,
			MaxDamage = 40,
			KnockbackSpeed = 22,
			CooldownPenalty = 0.08,
			MaxCooldown = 0.98,
		}),
	}),
	Spinner = table.freeze({
		DisplayName = "Spinner",
		Tier = 8,
		Enabled = false,
		Status = "Coming Soon",
		Role = "Space-control specialist",
		Tradeoff = "Future rotating pressure weapon with commitment risk.",
	}),
	Rammer = table.freeze({
		DisplayName = "Rammer",
		Tier = 8,
		Enabled = false,
		Status = "Coming Soon",
		Role = "Mobile collision initiator",
		Tradeoff = "Future forward-impact kit that must choose its approach.",
	}),
	Pilebreaker = table.freeze({
		DisplayName = "Pilebreaker",
		Tier = 20,
		Enabled = false,
		Status = "Future Work",
		Role = "Single-impact armor breaker",
		Tradeoff = "Future Striker specialization.",
	}),
	TwinMaul = table.freeze({
		DisplayName = "Twin Maul",
		Tier = 20,
		Enabled = false,
		Status = "Future Work",
		Role = "Sustained close-range bruiser",
		Tradeoff = "Future Striker specialization.",
	}),
	Stormring = table.freeze({
		DisplayName = "Stormring",
		Tier = 20,
		Enabled = false,
		Status = "Future Work",
		Role = "Perimeter control specialist",
		Tradeoff = "Future Spinner specialization.",
	}),
	Ripsaw = table.freeze({
		DisplayName = "Ripsaw",
		Tier = 20,
		Enabled = false,
		Status = "Future Work",
		Role = "Focused pursuit specialist",
		Tradeoff = "Future Spinner specialization.",
	}),
	Ironclad = table.freeze({
		DisplayName = "Ironclad",
		Tier = 20,
		Enabled = false,
		Status = "Future Work",
		Role = "Defensive line breaker",
		Tradeoff = "Future Rammer specialization.",
	}),
	Liftjack = table.freeze({
		DisplayName = "Liftjack",
		Tier = 20,
		Enabled = false,
		Status = "Future Work",
		Role = "Positional control specialist",
		Tradeoff = "Future Rammer specialization.",
	}),
}

local ClassConfig = table.freeze({
	BaseClassId = "ScrapRunner",
	Level8Threshold = 8,
	Level20Threshold = 20,
	ClassAttribute = "RunClass",
	EligibilityAttribute = "ClassEvolutionEligible",
	SelectedAttribute = "ClassEvolutionSelected",
	RequestRateWindow = 1,
	MaxRequestsPerWindow = 5,
	MinimumRequestInterval = 0.12,
	MaxServerCooldown = 1.10,
	Definitions = table.freeze(definitions),
	Level8Order = table.freeze({ "Striker", "Spinner", "Rammer" }),
	StandardHammerHeadSize = Vector3.new(2.875, 1.312, 1.062),
	StandardHammerFaceSize = Vector3.new(3.312, 0.9, 0.688),
	StrikerHammerHeadSize = Vector3.new(3.55, 1.65, 1.32),
	StrikerHammerFaceSize = Vector3.new(4.05, 1.05, 0.82),
})

return ClassConfig
