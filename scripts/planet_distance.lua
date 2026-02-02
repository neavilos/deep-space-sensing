--- Planet Distance Calculator
--- Calculates distances between planets using their star map positions.
--- Uses LuaSpaceLocationPrototype.position for Cartesian coordinates.
---
--- @module deep_space_sensing.planet_distance

local constants = require("scripts.constants")

local planet_distance = {}

--- Gets observer properties for a planet
--- Reads from custom_tooltip_fields set in data-final-fixes
--- @param planet_name string The planet name
--- @return table props { base_scale, decay_scale, orbital_capacity, attrition_rate }
function planet_distance.get_observer_properties(planet_name)
	local defaults = constants.DEFAULT_CONTRIBUTION_CONFIG
	local result = {
		base_scale = defaults.base_scale,
		decay_scale = defaults.decay_scale,
		orbital_capacity = defaults.orbital_capacity,
		attrition_rate = defaults.attrition_rate,
	}
	
	local location = prototypes.space_location[planet_name]
	if location and location.custom_tooltip_fields then
		for _, field in ipairs(location.custom_tooltip_fields) do
			if field.name == "dss_base_contribution_scale" then
				result.base_scale = tonumber(field.value) or defaults.base_scale
			elseif field.name == "dss_decay_scale" then
				result.decay_scale = tonumber(field.value) or defaults.decay_scale
			elseif field.name == "dss_orbital_capacity" then
				result.orbital_capacity = tonumber(field.value) or defaults.orbital_capacity
			elseif field.name == "dss_attrition_rate" then
				result.attrition_rate = tonumber(field.value) or defaults.attrition_rate
			end
		end
	end
	
	return result
end

--- Calculates Euclidean distance between two Cartesian points
--- @param pos1 MapPosition First position {x: number, y: number}
--- @param pos2 MapPosition Second position {x: number, y: number}
--- @return number distance The Euclidean distance
local function euclidean_distance(pos1, pos2)
	local dx = pos2.x - pos1.x
	local dy = pos2.y - pos1.y
	return math.sqrt(dx * dx + dy * dy)
end

--- Gets the position of a planet on the star map
--- @param planet_name string The name of the planet
--- @return MapPosition|nil position The position or nil if not found
function planet_distance.get_planet_position(planet_name)
	-- Try to get from prototypes first (works for both discovered and undiscovered locations)
	local location_proto = prototypes.space_location[planet_name]

	if location_proto and location_proto.position then
		return location_proto.position
	end

	-- Fallback to game.planets for backwards compatibility
	local planet = game.planets[planet_name]
	if planet and planet.prototype then
		return planet.prototype.position
	end

	return nil
end

--- Calculates the straight-line distance between two planets
--- @param planet1_name string Name of the first planet
--- @param planet2_name string Name of the second planet
--- @return number|nil distance Distance between planets, or nil if calculation failed
function planet_distance.calculate_distance(planet1_name, planet2_name)
	local pos1 = planet_distance.get_planet_position(planet1_name)
	local pos2 = planet_distance.get_planet_position(planet2_name)

	if not pos1 or not pos2 then
		return nil
	end

	return euclidean_distance(pos1, pos2)
end

--- Calculates sensing contribution based on distance from observer to target
--- Uses exponential decay for both observer and target properties
--- @param distance number The distance between planets
--- @param observer_config table Configuration { base_scale: number, decay_scale: number }
--- @param target_decay_scale number|nil Target's decay scale (optional)
--- @return number contribution The sensing contribution per satellite
function planet_distance.calculate_sensing_contribution(distance, observer_config, target_decay_scale)
    if distance == nil or distance == 0 then
        return 0
    end
    
    local defaults = constants.DEFAULT_CONTRIBUTION_CONFIG
    local base_scale = observer_config.base_scale or defaults.base_scale
    local observer_decay = observer_config.decay_scale or defaults.decay_scale or 25
    local target_decay = target_decay_scale or defaults.decay_scale or 25
    
    -- Dual exponential decay: contribution = base_scale * e^(-distance / observer_decay) * e^(-distance / target_decay)
    -- Signal degrades both from observer's equipment limitations AND target's properties
    local observer_factor = math.exp(-distance / observer_decay)
    local target_factor = math.exp(-distance / target_decay)
    local contribution = base_scale * observer_factor * target_factor
    
    return contribution
end

--- Builds a contribution map for all planets relative to a target planet
--- @param target_planet_name string Name of the target planet to discover
--- @return table contributions Map of observer_planet_name -> contribution_value
function planet_distance.build_contribution_map(target_planet_name)
	local contributions = {}

	-- Get target's decay scale from custom-input
	local target_props = planet_distance.get_observer_properties(target_planet_name)
	local target_decay_scale = target_props.decay_scale

	-- Get all space locations from prototypes (includes both discovered and undiscovered)
	for observer_planet_name, _ in pairs(prototypes.space_location) do
		if observer_planet_name ~= target_planet_name then
			local distance = planet_distance.calculate_distance(observer_planet_name, target_planet_name)

			if distance then
				-- Get observer's properties from custom-input
				local observer_props = planet_distance.get_observer_properties(observer_planet_name)

				contributions[observer_planet_name] = planet_distance.calculate_sensing_contribution(distance, observer_props, target_decay_scale)
			else
				-- Fallback to 0 if we can't calculate
				contributions[observer_planet_name] = 0
			end
		end
	end

	return contributions
end

--- Builds contribution maps for all discoverable planets
--- @param discoverable_planets table Array of planet names
--- @return table maps Map of target_planet_name -> (observer_planet_name -> contribution_value)
function planet_distance.build_all_contribution_maps(discoverable_planets)
	local all_maps = {}

	for _, planet_name in ipairs(discoverable_planets) do
		all_maps[planet_name] = planet_distance.build_contribution_map(planet_name)
	end

	return all_maps
end

--- Debug function to print all planet distances to a target planet
--- @param target_planet_name string The target planet to calculate distances to
function planet_distance.debug_print_distances(target_planet_name)
	game.print(string.format("=== Planet Distances to %s ===", target_planet_name))

	local target_pos = planet_distance.get_planet_position(target_planet_name)
	if target_pos then
		game.print(string.format("  Target position: (%.2f, %.2f)", target_pos.x, target_pos.y))
	else
		game.print("  ERROR: Target position not found!")
		return
	end

	-- Get target's decay scale from custom-input
	local target_props = planet_distance.get_observer_properties(target_planet_name)
	local target_decay_scale = target_props.decay_scale

	for location_name, _ in pairs(prototypes.space_location) do
		if location_name ~= target_planet_name then
			local observer_pos = planet_distance.get_planet_position(location_name)
			local distance = planet_distance.calculate_distance(location_name, target_planet_name)
			
			-- Get observer config from custom-input
			local observer_props = planet_distance.get_observer_properties(location_name)
			
			local contribution = planet_distance.calculate_sensing_contribution(distance, observer_props, target_decay_scale)

			if distance and observer_pos then
				game.print(
					string.format(
						"  %s: pos(%.2f,%.2f) dist=%.2f base=%.2f decay=%.0f contrib=%.6f",
						location_name,
						observer_pos.x,
						observer_pos.y,
						distance,
						observer_props.base_scale,
						observer_props.decay_scale,
						contribution
					)
				)
			else
				game.print(
					string.format(
						"  %s: Unable to calculate (pos=%s, dist=%s)",
						location_name,
						observer_pos and "ok" or "nil",
						distance and "ok" or "nil"
					)
				)
			end
		end
	end
end

--- Debug function to print current contribution maps from storage
--- @param force LuaForce The force to print contributions for
--- @param target_planet_name string The target planet
function planet_distance.debug_print_stored_contributions(force, target_planet_name)
	local KEYS = constants.STORAGE_KEYS
	game.print(string.format("=== Stored Contributions for %s (force: %s) ===", target_planet_name, force.name))

	if not storage[KEYS.CONTRIBUTION_PROBABILITIES] then
		game.print("  No contribution maps in storage!")
		return
	end

	if not storage[KEYS.CONTRIBUTION_PROBABILITIES][force.name] then
		game.print("  No contribution maps for this force!")
		return
	end

	local map = storage[KEYS.CONTRIBUTION_PROBABILITIES][force.name][target_planet_name]
	if not map then
		game.print("  No contribution map for this planet!")
		return
	end

	for observer_planet, contribution in pairs(map) do
		game.print(string.format("  %s: %.6f (%.4f%%)", observer_planet, contribution, contribution * 100))
	end
end

return planet_distance
