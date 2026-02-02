--- Deep Space Sensing Data-Final-Fixes
--- Scans all technologies for unlock-space-location effects and converts opted-in ones
--- to scripted research with satellite-based discovery mechanics.
--- Also transforms deep_space_sensing_properties into custom_tooltip_fields for runtime access.

local utils = require("lib.utils")

-- Read default parameter settings
local default_hardness = settings.startup["deep-space-sensing-default-hardness"].value
local default_minimum_strength = settings.startup["deep-space-sensing-default-minimum-strength"].value
local default_base_contribution_scale = settings.startup["deep-space-sensing-default-base-contribution-scale"].value
local default_decay_scale = settings.startup["deep-space-sensing-default-decay-scale"].value
local default_orbital_capacity = settings.startup["deep-space-sensing-default-orbital-capacity"].value
local default_attrition_rate = settings.startup["deep-space-sensing-default-attrition-rate"].value

-- Transform deep_space_sensing_properties into custom_tooltip_fields for all locations
-- This makes the data accessible at runtime via prototypes.space_location[name].custom_tooltip_fields
local function add_observer_tooltip_fields(location)
	local props = location.deep_space_sensing_properties or {}
	utils.add_tooltip_fields(location, {
		dss_base_contribution_scale = props.base_contribution_scale or default_base_contribution_scale,
		dss_decay_scale = props.decay_scale or default_decay_scale,
		dss_orbital_capacity = props.orbital_capacity or default_orbital_capacity,
		dss_attrition_rate = props.attrition_rate or default_attrition_rate,
	})
end

for _, location in pairs(data.raw["space-location"] or {}) do
	add_observer_tooltip_fields(location)
end
for _, location in pairs(data.raw.planet or {}) do
	add_observer_tooltip_fields(location)
end

-- Get opted-in locations from settings and API
local opted_in_locations = utils.get_opted_in_locations()

-- Scan all technologies
for _, tech in pairs(data.raw.technology) do
	if tech.effects then
		for _, effect in ipairs(tech.effects) do
			if effect.type == "unlock-space-location" then
				local location = effect.space_location

				-- Check if opted in (either via API or user manually added it)
				if opted_in_locations[location] then
					local location_proto = utils.get_location_prototype(location)
					local tech_params = tech.deep_space_sensing_parameters or {}

					utils.ensure_prerequisite(tech, "deep-space-sensing")
					tech.unit = nil

					-- Build research_trigger
					tech.research_trigger = {
						type = "scripted",
						icon = "__base__/graphics/icons/satellite.png",
						icon_size = 64,
						trigger_description = tech_params.trigger_description or {
							"",
							"Launch observation satellites and scan for ",
							"[space-location=" .. location .. "]",
						},
					}

					-- Store config in custom-input prototype for control stage
					local config_proto = {
						type = "custom-input",
						name = "deep-space-sensing-config-" .. location,
						key_sequence = "",
						action = "lua",
						localised_name = (location_proto and location_proto.localised_name) or location,
					}
					utils.add_tooltip_fields(config_proto, {
						dss_location = location,
						dss_hardness = tech_params.hardness or default_hardness,
						dss_minimum_strength = tech_params.minimum_strength or default_minimum_strength,
						dss_gui_sprite = "space-location/" .. location,
						dss_order = tech_params.order or "z",
					})
					data:extend({ config_proto })

					log("[Deep Space Sensing] Converted " .. tech.name .. " to scripted research for " .. location)
				end
			end
		end
	end
end
