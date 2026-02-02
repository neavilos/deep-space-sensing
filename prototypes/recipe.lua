data:extend({
	{
		type = "recipe",
		name = "observation-satellite",
		category = "electronics",
		subgroup = "deep-space-sensing",
		enabled = false,
		energy_required = 80,
		ingredients = {
			{ type = "item", name = "low-density-structure", amount = 100 },
			{ type = "item", name = "solar-panel", amount = 100 },
			{ type = "item", name = "accumulator", amount = 100 },
			{ type = "item", name = "radar", amount = 5 },
			{ type = "item", name = "processing-unit", amount = 100 },
			{ type = "item", name = "rocket-fuel", amount = 50 },
			{ type = "item", name = "superconductor", amount = 50 },
		},
		results = {
			{ type = "item", name = "observation-satellite", amount = 1 },
		},
	},
})
