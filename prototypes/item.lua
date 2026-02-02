data:extend({
	{
		type = "item",
		name = "deep-space-sensing-observation-satellite",
		icon = "__base__/graphics/icons/satellite.png",
		subgroup = "deep-space-sensing",
		stack_size = 1,
		weight = 1000 * 1000, -- 1000 kg
		send_to_orbit_mode = "automated",
		rocket_launch_products = {
			{ type = "item", name = "space-science-pack", amount_min = 10, amount_max = 100 },
		},
	},
})
