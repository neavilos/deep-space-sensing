--- Deep Space Sensing Data-Updates
--- Adds deep_space_sensing_properties to vanilla space-location prototypes
--- and deep_space_sensing_parameters to their discovery technologies.
--- Also adjusts recipe/tech requirements to avoid circular dependencies.

local utils = require("lib.utils")

-- Observer properties: how satellites from each location contribute to discoveries
-- Hardness uses exponential decay: discovery_rate * e^(-hardness * global_multiplier)
local vanilla_config = {
	-- Planets (data.raw.planet)
	-- orbital_capacity: soft cap on satellites, attrition_rate: base chance of satellite death per scan
	nauvis = {
		observer = {
			base_contribution_scale = 0.1,
			decay_scale = 25,
			orbital_capacity = 300,
			attrition_rate = 0.001,
		},
		tech = "planet-discovery-nauvis",
		hardness = 3.0,
		minimum_strength = 0.5,
		order = "a-a",
	},
	vulcanus = {
		observer = {
			base_contribution_scale = 0.06,
			decay_scale = 18,
			orbital_capacity = 500,
			attrition_rate = 0.002,
		},
		tech = "planet-discovery-vulcanus",
		hardness = 3.8,
		minimum_strength = 1.0,
		order = "a-b",
	},
	gleba = {
		observer = {
			base_contribution_scale = 0.18,
			decay_scale = 25,
			orbital_capacity = 420,
			attrition_rate = 0.0015,
		},
		tech = "planet-discovery-gleba",
		hardness = 4.1,
		minimum_strength = 1.0,
		order = "a-c",
	},
	fulgora = {
		observer = {
			base_contribution_scale = 0.2,
			decay_scale = 20,
			orbital_capacity = 240,
			attrition_rate = 0.002,
		},
		tech = "planet-discovery-fulgora",
		hardness = 4.4,
		minimum_strength = 1.0,
		order = "a-d",
	},
	aquilo = {
		observer = {
			base_contribution_scale = 0.12,
			decay_scale = 20,
			orbital_capacity = 160,
			attrition_rate = 0.003,
		},
		tech = "planet-discovery-aquilo",
		hardness = 7.6,
		minimum_strength = 4.0,
		order = "a-e",
	},
	-- Space locations (data.raw["space-location"])
	["solar-system-edge"] = {
		observer = {
			base_contribution_scale = 0.1,
			decay_scale = 30,
			orbital_capacity = 0,
			attrition_rate = 1.0,
		},
		tech = "promethium-science-pack",
		hardness = 8.2,
		minimum_strength = 10.0,
		order = "a-f",
	},
	["shattered-planet"] = {
		observer = {
			base_contribution_scale = 0.0,
			decay_scale = 1,
			orbital_capacity = 0,
			attrition_rate = 1.0,
		},
	},
}

for name, config in pairs(vanilla_config) do
	local location = data.raw.planet[name] or data.raw["space-location"][name]
	if location and config.observer then
		location.deep_space_sensing_properties = config.observer
	end
	if config.tech then
		local tech = data.raw.technology[config.tech]
		if tech then
			tech.deep_space_sensing_parameters = {
				hardness = config.hardness,
				minimum_strength = config.minimum_strength,
				order = config.order,
			}
		end
	end
end

-- Get opted-in locations from settings and API
local opted_in_locations = utils.get_opted_in_locations()

local tech = data.raw.technology["deep-space-sensing"]
local recipe = data.raw.recipe["observation-satellite"]

if not tech or not recipe then
	return -- Tech/recipe not loaded yet, skip
end

-- If Fulgora is being discovered, remove electromagnetic requirements
if opted_in_locations["fulgora"] then
	-- Remove superconductor from recipe
	if recipe.ingredients then
		local new_ingredients = {}
		for _, ingredient in ipairs(recipe.ingredients) do
			local name = ingredient.name or ingredient[1]
			if name ~= "superconductor" then
				table.insert(new_ingredients, ingredient)
			end
		end
		recipe.ingredients = new_ingredients
	end

	-- Remove electromagnetic-science-pack from tech unit
	if tech.unit and tech.unit.ingredients then
		local new_ingredients = {}
		for _, ingredient in ipairs(tech.unit.ingredients) do
			local name = ingredient[1] or ingredient.name
			if name ~= "electromagnetic-science-pack" then
				table.insert(new_ingredients, ingredient)
			end
		end
		tech.unit.ingredients = new_ingredients
	end

	-- Remove electromagnetic-science-pack from prerequisites
	if tech.prerequisites then
		local new_prerequisites = { "electric-energy-accumulators" }
		for _, prereq in ipairs(tech.prerequisites) do
			if prereq ~= "electromagnetic-science-pack" then
				table.insert(new_prerequisites, prereq)
			end
		end
		tech.prerequisites = new_prerequisites
	end

	log("[Deep Space Sensing] Fulgora discovery detected - removed electromagnetic requirements")
end

-- If Vulcanus is being discovered, remove metallurgic requirements
if opted_in_locations["vulcanus"] then
	-- Remove metallurgic-science-pack from tech unit
	if tech.unit and tech.unit.ingredients then
		local new_ingredients = {}
		for _, ingredient in ipairs(tech.unit.ingredients) do
			local name = ingredient[1] or ingredient.name
			if name ~= "metallurgic-science-pack" then
				table.insert(new_ingredients, ingredient)
			end
		end
		tech.unit.ingredients = new_ingredients
	end

	-- Remove metallurgic-science-pack from prerequisites
	if tech.prerequisites then
		local new_prerequisites = {}
		for _, prereq in ipairs(tech.prerequisites) do
			if prereq ~= "metallurgic-science-pack" then
				table.insert(new_prerequisites, prereq)
			end
		end
		tech.prerequisites = new_prerequisites
	end

	log("[Deep Space Sensing] Vulcanus discovery detected - removed metallurgic requirements")
end
