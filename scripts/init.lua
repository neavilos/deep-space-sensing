--- Deep Space Sensing Core Module
--- Manages satellite-based planet discovery mechanics.
---
--- @module deep_space_sensing

local planet_distance = require("scripts.planet_distance")
local constants = require("scripts.constants")

local deep_space_sensing = {}

-- Re-export constants for convenience
deep_space_sensing.constants = constants
deep_space_sensing.SCAN_INTERVAL_SECONDS = constants.SCAN_INTERVAL_SECONDS

--- Callbacks to notify when GUI should refresh (avoids circular dependency)
local refresh_callbacks = {}

--- Register a callback to be called when the GUI should refresh
--- @param callback function The callback function to call
function deep_space_sensing.register_refresh_callback(callback)
	table.insert(refresh_callbacks, callback)
end

--- Call all registered refresh callbacks
local function notify_refresh()
	for _, callback in ipairs(refresh_callbacks) do
		callback()
	end
end

--- Configuration for discoverable planets
--- Structure: { [planet_name] = { tech_name, hardness, options... } }
--- @type table<string, table>
local DISCOVERABLE_PLANETS = {}

--- Shorthand for storage keys
local KEYS = constants.STORAGE_KEYS

--- Helper to get a value from custom_tooltip_fields by name
--- @param fields table The custom_tooltip_fields array
--- @param field_name string The field name to find
--- @return string|nil value The field value or nil
local function get_tooltip_field(fields, field_name)
	if not fields then
		return nil
	end
	for _, field in ipairs(fields) do
		if field.name == field_name then
			return field.value
		end
	end
	return nil
end

--- Reads planet configs from custom-input prototypes (set by data stage)
function deep_space_sensing.load_configs_from_prototypes()
	DISCOVERABLE_PLANETS = {}

	for name, proto in pairs(prototypes.custom_input) do
		if name:match("^deep%-space%-sensing%-config%-") then
			local fields = proto.custom_tooltip_fields
			local location = get_tooltip_field(fields, "dss_location")

			if location then
				DISCOVERABLE_PLANETS[location] = {
					tech_name = "??", -- Will be found below
					display_name = prototypes.space_location[location]
							and prototypes.space_location[location].localised_name
						or location,
					hardness = tonumber(get_tooltip_field(fields, "dss_hardness")),
					minimum_strength = tonumber(get_tooltip_field(fields, "dss_minimum_strength")),
					icon_sprite = get_tooltip_field(fields, "dss_gui_sprite") or "technology/unknown",
					order = get_tooltip_field(fields, "dss_order") or "z",
				}
			end
		end
	end

	-- Find technology names by scanning for unlock-space-location effects
	for name, tech in pairs(prototypes.technology) do
		if tech.effects then
			for _, effect in pairs(tech.effects) do
				if effect.type == "unlock-space-location" then
					local location = effect.space_location
					if DISCOVERABLE_PLANETS[location] then
						DISCOVERABLE_PLANETS[location].tech_name = name
					end
				end
			end
		end
	end
end

function deep_space_sensing.setup_satellites_counter()
	-- Initialize satellite counters for all forces
	if not storage[KEYS.ORBITAL_SATELLITES] then
		storage[KEYS.ORBITAL_SATELLITES] = {}
	end

	for _, force in pairs(game.forces) do
		if not storage[KEYS.ORBITAL_SATELLITES][force.name] then
			storage[KEYS.ORBITAL_SATELLITES][force.name] = {}
		end

		for planet_name, _ in pairs(game.planets) do
			if not storage[KEYS.ORBITAL_SATELLITES][force.name][planet_name] then
				storage[KEYS.ORBITAL_SATELLITES][force.name][planet_name] = 0
			end
		end
	end
end

-- Legacy alias
deep_space_sensing.setup_deep_space_sensing_satellites_counter = deep_space_sensing.setup_satellites_counter

function deep_space_sensing.setup_planetary_contribution(force_rebuild)
	if force_rebuild then
		storage[KEYS.CONTRIBUTION_PROBABILITIES] = nil
	end

	-- Ensure per-force container
	if not storage[KEYS.CONTRIBUTION_PROBABILITIES] then
		storage[KEYS.CONTRIBUTION_PROBABILITIES] = {}
	end

	-- Build contribution maps for all discoverable planets
	-- Contribution is now based on observer planet properties, not target
	local discoverable_list = {}
	for planet_name, _ in pairs(DISCOVERABLE_PLANETS) do
		table.insert(discoverable_list, planet_name)
	end

	local maps = planet_distance.build_all_contribution_maps(discoverable_list)

	-- Store per-force so lookups always index by force first
	for _, force in pairs(game.forces) do
		storage[KEYS.CONTRIBUTION_PROBABILITIES][force.name] = maps
	end
end

-- Legacy alias
deep_space_sensing.setup_deep_space_sensing_planetary_contribution = deep_space_sensing.setup_planetary_contribution

function deep_space_sensing.on_satellite_launched(cargo_pod)
	-- Get the force that launched the satellite
	local launching_force = cargo_pod.force
	if not launching_force then
		return
	end

	local force_name = launching_force.name
	local origin_planet = cargo_pod.cargo_pod_origin.surface.planet.name

	-- Get the satellite item stack to determine quality
	local inventory = cargo_pod.get_inventory(defines.inventory.cargo_unit)
	local stack = inventory and inventory.find_item_stack(constants.OBSERVATION_SATELLITE_ITEM)

	-- Determine strength based on quality level (0-4, clamped)
	local quality_level = 0
	local quality_name = "normal"
	if stack and stack.quality then
		quality_level = math.min(stack.quality.level, 4) -- Clamp to max tier
		quality_name = stack.quality.name -- Keep name for display
	end
	local strength = constants.QUALITY_STRENGTH[quality_level] or 1.0

	-- Initialize if needed
	if not storage[KEYS.ORBITAL_SATELLITES] then
		deep_space_sensing.setup_satellites_counter()
	end

	if not storage[KEYS.ORBITAL_SATELLITES][force_name] then
		storage[KEYS.ORBITAL_SATELLITES][force_name] = {}
	end

	if not storage[KEYS.ORBITAL_SATELLITES][force_name][origin_planet] then
		storage[KEYS.ORBITAL_SATELLITES][force_name][origin_planet] = 0
	end

	-- Add strength (not just count) to the total
	storage[KEYS.ORBITAL_SATELLITES][force_name][origin_planet] = (
		storage[KEYS.ORBITAL_SATELLITES][force_name][origin_planet] + strength
	)

	-- Log satellite deployment
	log(
		string.format(
			"[Deep Space Sensing] %s satellite deployed in %s orbit. Total strength: %.1f",
			quality_name,
			origin_planet,
			storage[KEYS.ORBITAL_SATELLITES][force_name][origin_planet]
		)
	)

	-- Notify any registered GUI refresh callbacks
	notify_refresh()
end

--- Gets the list of discoverable planets
--- @return table Map of planet_name -> config (includes tech_name, display_name)
function deep_space_sensing.get_discoverable_planets()
	-- Return a map with config info for the GUI
	local result = {}
	for planet_name, config in pairs(DISCOVERABLE_PLANETS) do
		result[planet_name] = {
			tech_name = config.tech_name,
			display_name = config.display_name or planet_name,
			icon_sprite = config.icon_sprite,
			order = config.order or "z",
		}
	end
	return result
end

--- Gets the display name for a planet
--- @param planet_name string The planet name
--- @return string display_name The display name (or planet_name if not set)
function deep_space_sensing.get_display_name(planet_name)
	local config = DISCOVERABLE_PLANETS[planet_name]
	if config and config.display_name then
		return config.display_name
	end
	return planet_name
end

--- Gets the full configuration for a discoverable planet
--- @param planet_name string The planet name
--- @return table|nil config The planet configuration or nil if not registered
function deep_space_sensing.get_planet_config(planet_name)
	return DISCOVERABLE_PLANETS[planet_name]
end

--- Checks if a force has any satellites in orbit
--- @param force LuaForce The force to check
--- @return boolean has_satellites True if at least one satellite is in orbit
function deep_space_sensing.has_any_satellites(force)
	local force_name = force.name

	if not storage[KEYS.ORBITAL_SATELLITES] or not storage[KEYS.ORBITAL_SATELLITES][force_name] then
		return false
	end

	for _, count in pairs(storage[KEYS.ORBITAL_SATELLITES][force_name]) do
		if count > 0 then
			return true
		end
	end

	return false
end

--- Gets the satellite efficiency multiplier from the infinite tech
--- @param force LuaForce The force to check
--- @return number multiplier The efficiency multiplier (1.0 + 0.1 per level)
function deep_space_sensing.get_efficiency_multiplier(force)
	local tech = force.technologies["observation-satellite-efficiency"]
	if tech then
		-- For infinite techs: level = next level to research after completing current
		-- After completing level N, tech.level becomes N+1
		-- So completed levels = level - 1 (clamped to 0)
		local completed_levels = math.max(0, tech.level - 1)
		return 1.0 + (0.10 * completed_levels)
	end
	return 1.0
end

--- Gets the orbital capacity multiplier from the infinite tech
--- @param force LuaForce The force to check
--- @return number multiplier The capacity multiplier (1.0 + 0.1 per level)
function deep_space_sensing.get_capacity_multiplier(force)
	local tech = force.technologies["orbital-capacity-upgrade"]
	if tech then
		local completed_levels = math.max(0, tech.level - 1)
		return 1.0 + (0.10 * completed_levels)
	end
	return 1.0
end

--- Gets the durability multiplier from the infinite tech (reduces attrition)
--- @param force LuaForce The force to check
--- @return number multiplier The durability multiplier (attrition divided by this)
function deep_space_sensing.get_durability_multiplier(force)
	local tech = force.technologies["satellite-synchronization"]
	if tech then
		local completed_levels = math.max(0, tech.level - 1)
		return 1.0 + (0.10 * completed_levels)
	end
	return 1.0
end

--- Calculates the effective satellite count with overflow penalty
--- Satellites over capacity contribute with exponential decay
--- @param satellite_count number Raw satellite count
--- @param capacity number Orbital capacity
--- @return number effective_count The effective satellite count
function deep_space_sensing.get_effective_satellite_count(satellite_count, capacity)
	if satellite_count <= capacity or capacity <= 0 then
		return satellite_count
	end
	-- Over-capacity satellites contribute with exponential decay
	local overflow = satellite_count - capacity
	local effective_overflow = overflow * math.exp(-overflow / constants.OVERFLOW_SCALE)
	return capacity + effective_overflow
end

--- Calculates the current discovery chance for a planet for a given force
--- Takes into account the planet's hardness multiplier and efficiency tech
--- @param force LuaForce The force to calculate for
--- @param planet_name string The target planet
--- @return number chance The discovery chance (0 to 1)
function deep_space_sensing.calculate_discovery_chance(force, planet_name)
	local force_name = force.name

	if
		not storage[KEYS.CONTRIBUTION_PROBABILITIES]
		or not storage[KEYS.ORBITAL_SATELLITES]
		or not storage[KEYS.ORBITAL_SATELLITES][force_name]
		or not storage[KEYS.CONTRIBUTION_PROBABILITIES][force_name]
	then
		return 0
	end

	-- Get multipliers from infinite techs
	local efficiency_multiplier = deep_space_sensing.get_efficiency_multiplier(force)
	local capacity_multiplier = deep_space_sensing.get_capacity_multiplier(force)

	local sensing_fidelity = 0
	local contribution_map = storage[KEYS.CONTRIBUTION_PROBABILITIES][force_name][planet_name]

	if contribution_map then
		for observer_planet, contribution in pairs(contribution_map) do
			local raw_count = storage[KEYS.ORBITAL_SATELLITES][force_name][observer_planet] or 0
			-- Get observer properties to check capacity (apply capacity multiplier from tech)
			local observer_props = planet_distance.get_observer_properties(observer_planet)
			local effective_capacity = observer_props.orbital_capacity * capacity_multiplier
			local effective_count = deep_space_sensing.get_effective_satellite_count(raw_count, effective_capacity)
			-- Apply efficiency multiplier to satellite contribution
			sensing_fidelity = sensing_fidelity + effective_count * contribution * efficiency_multiplier
		end
	end

	-- Apply hardness as exponential decay (higher hardness = lower chance)
	-- Formula: sensing_fidelity * e^(-hardness * global_multiplier)
	local config = DISCOVERABLE_PLANETS[planet_name]
	if config and config.hardness then
		local effective_hardness = config.hardness * constants.GLOBAL_HARDNESS_MULTIPLIER
		sensing_fidelity = sensing_fidelity * math.exp(-effective_hardness)
	end

	return sensing_fidelity
end

function deep_space_sensing.discover_planet(planet_name, discovery_tech_name, force)
	-- Automatically research the technology (no science pack cost)
	local discovery_technology = force.technologies[discovery_tech_name]
	if discovery_technology then
		discovery_technology.researched = true

		-- Notify all players in the force (use display name)
		local display_name = deep_space_sensing.get_display_name(planet_name)
		force.print({ "deep-space-sensing.planet-discovered-notification", display_name })
	else
		log(
			string.format(
				"[Deep Space Sensing] Warning: Technology '%s' not found for planet '%s'",
				discovery_tech_name,
				planet_name
			)
		)
	end

	-- Clear the target for this force
	if storage[KEYS.DISCOVERY_TARGETS] then
		storage[KEYS.DISCOVERY_TARGETS][force.name] = nil
	end

	-- Notify any registered GUI refresh callbacks
	notify_refresh()
end

--- Calculates the attrition chance for a planet based on satellite count vs capacity
--- Attrition only applies at or above capacity, then ramps up exponentially
--- @param satellite_count number Current satellite count
--- @param capacity number Orbital capacity
--- @param base_attrition number Base attrition rate
--- @return number attrition_chance Per-satellite death chance per minute
function deep_space_sensing.calculate_attrition_chance(satellite_count, capacity, base_attrition)
	if capacity <= 0 or satellite_count < capacity then
		return 0
	end

	-- At capacity: base attrition. Above capacity: ramps up exponentially
	local excess = satellite_count - capacity
	return base_attrition * math.exp(excess / constants.ATTRITION_SCALE)
end

--- Processes attrition for all satellites of a force
--- Called once per scan cycle before discovery attempts
--- @param force LuaForce The force to process
function deep_space_sensing.process_attrition(force)
	local force_name = force.name
	if not storage[KEYS.ORBITAL_SATELLITES] or not storage[KEYS.ORBITAL_SATELLITES][force_name] then
		return
	end

	local satellites = storage[KEYS.ORBITAL_SATELLITES][force_name]
	local total_lost = 0
	local capacity_mult = deep_space_sensing.get_capacity_multiplier(force)
	local durability_mult = deep_space_sensing.get_durability_multiplier(force)

	for planet_name, satellite_count in pairs(satellites) do
		if satellite_count > 0 then
			local observer_props = planet_distance.get_observer_properties(planet_name)
			-- Apply capacity multiplier from tech
			local effective_capacity = observer_props.orbital_capacity * capacity_mult
			local attrition_chance = deep_space_sensing.calculate_attrition_chance(
				satellite_count,
				effective_capacity,
				observer_props.attrition_rate
			)
			-- Apply durability multiplier to reduce attrition
			attrition_chance = attrition_chance / durability_mult

			-- Calculate expected satellites lost, with probabilistic rounding
			local expected_loss = satellite_count * attrition_chance
			local satellites_lost = math.floor(expected_loss)
			if math.random() < (expected_loss - satellites_lost) then
				satellites_lost = satellites_lost + 1
			end

			if satellites_lost > 0 then
				satellites[planet_name] = math.max(0, satellite_count - satellites_lost)
				total_lost = total_lost + satellites_lost
			end
		end
	end

	if total_lost > 0 then
		log(string.format("[Deep Space Sensing] Attrition: %s lost %d satellites", force_name, total_lost))
		notify_refresh()
	end
end

function deep_space_sensing.progress_for_force(force)
	local force_name = force.name

	if
		not storage[KEYS.CONTRIBUTION_PROBABILITIES]
		or not storage[KEYS.ORBITAL_SATELLITES]
		or not storage[KEYS.ORBITAL_SATELLITES][force_name]
	then
		deep_space_sensing.setup_planetary_contribution()
		deep_space_sensing.setup_satellites_counter()
	end

	-- Get the currently targeted planet for this force
	if not storage[KEYS.DISCOVERY_TARGETS] then
		storage[KEYS.DISCOVERY_TARGETS] = {}
	end

	local target_planet = storage[KEYS.DISCOVERY_TARGETS][force_name]
	if not target_planet then
		return -- No target selected, nothing to scan for
	end

	local planet_config = DISCOVERABLE_PLANETS[target_planet]
	if not planet_config then
		return -- Invalid target
	end

	local discovery_tech_name = planet_config.tech_name

	-- Check if already discovered
	local tech = force.technologies[discovery_tech_name]
	if not tech or tech.researched then
		storage[KEYS.DISCOVERY_TARGETS][force_name] = nil
		return
	end

	-- Check prerequisites
	if tech.prerequisites then
		for _, prereq_tech in pairs(tech.prerequisites) do
			if not prereq_tech.researched then
				return -- Prerequisites not met
			end
		end
	end

	-- Check minimum strength requirement
	local meets_min, current, required = deep_space_sensing.check_minimum_strength(force, target_planet)
	if not meets_min then
		-- Auto-stop scanning if minimum strength is no longer met
		storage[KEYS.DISCOVERY_TARGETS][force_name] = nil
		force.print({
			"deep-space-sensing.insufficient-strength",
			deep_space_sensing.get_display_name(target_planet),
			string.format("%.1f", current),
			string.format("%.1f", required),
		})
		notify_refresh()
		return
	end

	-- Calculate sensing fidelity for this planet
	local sensing_fidelity = deep_space_sensing.calculate_discovery_chance(force, target_planet)

	-- Attempt to discover
	local sensing_roll = math.random()
	if sensing_roll < sensing_fidelity then
		deep_space_sensing.discover_planet(target_planet, discovery_tech_name, force)
	end
end

-- Legacy alias
deep_space_sensing.progress_deep_space_sensing_for_force = deep_space_sensing.progress_for_force

function deep_space_sensing.on_progress_tick(event)
	-- Only do scan work while at least one force has an active target
	if not storage[KEYS.DISCOVERY_TARGETS] or not storage[KEYS.NEXT_SCAN_TICK] then
		return
	end

	local did_scan = false
	local scan_interval_ticks = constants.SCAN_INTERVAL_SECONDS * 60

	-- Process scans for each force based on their individual timer
	for _, force in pairs(game.forces) do
		if
			not force.technologies[constants.UNLOCK_TECHNOLOGY]
			or not force.technologies[constants.UNLOCK_TECHNOLOGY].researched
		then
			goto continue_force
		end

		-- Check if this force has a target and their scan timer has elapsed
		local next_scan = storage[KEYS.NEXT_SCAN_TICK][force.name]
		if storage[KEYS.DISCOVERY_TARGETS][force.name] and next_scan and game.tick >= next_scan then
			deep_space_sensing.progress_for_force(force)
			-- Schedule next scan 60 seconds from now
			storage[KEYS.NEXT_SCAN_TICK][force.name] = game.tick + scan_interval_ticks
			did_scan = true
		end

		::continue_force::
	end

	if did_scan then
		-- Notify GUIs to refresh after scan
		notify_refresh()
	end
end

-- Legacy alias
deep_space_sensing.on_progress_deep_space_sensing_tick = deep_space_sensing.on_progress_tick

--- Processes satellite attrition for all forces
--- Called every minute independently of scanning
function deep_space_sensing.on_attrition_tick(event)
	for _, force in pairs(game.forces) do
		if
			force.technologies[constants.UNLOCK_TECHNOLOGY]
			and force.technologies[constants.UNLOCK_TECHNOLOGY].researched
		then
			deep_space_sensing.process_attrition(force)
		end
	end
	-- GUI refresh happens inside process_attrition only when satellites are lost
end

--- Gets the progress toward the next scan (0 to 1) for a force
--- @param force LuaForce The force to check
--- @return number progress Progress from 0 (just started) to 1 (about to scan)
function deep_space_sensing.get_scan_progress(force)
	if not storage[KEYS.NEXT_SCAN_TICK] or not storage[KEYS.NEXT_SCAN_TICK][force.name] then
		return 0
	end

	local scan_interval_ticks = constants.SCAN_INTERVAL_SECONDS * 60
	local next_scan = storage[KEYS.NEXT_SCAN_TICK][force.name]
	local ticks_remaining = next_scan - game.tick

	if ticks_remaining <= 0 then
		return 1
	end

	return 1 - (ticks_remaining / scan_interval_ticks)
end

--- Gets the seconds until the next scan for a force
--- @param force LuaForce The force to check
--- @return number seconds Seconds until the next scan
function deep_space_sensing.get_seconds_until_scan(force)
	if not storage[KEYS.NEXT_SCAN_TICK] or not storage[KEYS.NEXT_SCAN_TICK][force.name] then
		return constants.SCAN_INTERVAL_SECONDS
	end

	local next_scan = storage[KEYS.NEXT_SCAN_TICK][force.name]
	local ticks_remaining = math.max(next_scan - game.tick, 0)

	return math.ceil(ticks_remaining / 60)
end

--- Registers a planet as discoverable via deep space sensing
--- @param config table Planet configuration:
---   - planet_name: string (required) - The name of the planet in game.planets
---   - tech_name: string (required) - The technology that unlocks this planet
---   - hardness: number (optional, default 1.0) - Discovery difficulty multiplier (higher = harder)
---   - base_contribution_scale: number (optional) - Affects distance contribution calculation
---   - max_contribution: number (optional) - Maximum contribution per satellite
--- @return boolean success True if registered successfully
--- @return string|nil error_message Error message if registration failed
function deep_space_sensing.register_discoverable_planet(config, legacy_tech_name)
	-- Handle legacy call signature: (planet_name, tech_name)
	if type(config) == "string" then
		local planet_name = config
		config = {
			planet_name = planet_name,
			tech_name = legacy_tech_name,
		}
	end

	-- Validate required fields
	if not config.planet_name or type(config.planet_name) ~= "string" then
		return false, "planet_name is required and must be a string"
	end

	if not config.tech_name or type(config.tech_name) ~= "string" then
		return false, "tech_name is required and must be a string"
	end

	local defaults = constants.DEFAULT_PLANET_CONFIG

	-- Apply defaults
	local planet_config = {
		tech_name = config.tech_name,
		display_name = config.display_name or config.planet_name, -- Fallback to planet_name if not provided
		hardness = config.hardness or defaults.hardness,
		base_contribution_scale = config.base_contribution_scale or defaults.base_contribution_scale,
		decay_scale = config.decay_scale or defaults.decay_scale,
		minimum_strength = config.minimum_strength or defaults.minimum_strength,
	}

	DISCOVERABLE_PLANETS[config.planet_name] = planet_config

	return true, nil
end

--- Gets the default configuration values
--- @return table defaults The default configuration
function deep_space_sensing.get_default_config()
	return constants.DEFAULT_PLANET_CONFIG
end

--- Checks if any planets are registered for discovery
--- @return boolean has_planets True if at least one planet is registered
function deep_space_sensing.has_registered_planets()
	return next(DISCOVERABLE_PLANETS) ~= nil
end

--- Gets the current discovery target for a force
--- @param force LuaForce The force
--- @return string|nil target_planet The target planet name or nil
function deep_space_sensing.get_discovery_target(force)
	if not storage[KEYS.DISCOVERY_TARGETS] then
		return nil
	end
	return storage[KEYS.DISCOVERY_TARGETS][force.name]
end

--- Sets the discovery target for a force
--- @param force LuaForce The force
--- @param planet_name string|nil The target planet name (nil to clear)
function deep_space_sensing.set_discovery_target(force, planet_name)
	if not storage[KEYS.DISCOVERY_TARGETS] then
		storage[KEYS.DISCOVERY_TARGETS] = {}
	end
	storage[KEYS.DISCOVERY_TARGETS][force.name] = planet_name

	-- Set next scan tick when starting to scan (60 seconds from now)
	if planet_name then
		if not storage[KEYS.NEXT_SCAN_TICK] then
			storage[KEYS.NEXT_SCAN_TICK] = {}
		end
		storage[KEYS.NEXT_SCAN_TICK][force.name] = game.tick + (constants.SCAN_INTERVAL_SECONDS * 60)
	end

	notify_refresh()
end

--- Gets satellite counts for a force
--- @param force LuaForce The force
--- @return table|nil counts Map of planet_name -> satellite_count
function deep_space_sensing.get_satellite_counts(force)
	if not storage[KEYS.ORBITAL_SATELLITES] then
		return nil
	end
	return storage[KEYS.ORBITAL_SATELLITES][force.name]
end

--- Checks if a force meets the minimum strength requirement for a planet
--- @param force LuaForce The force to check
--- @param planet_name string The target planet
--- @return boolean meets_requirement True if minimum strength is met
--- @return number current_strength The current effective strength toward this target
--- @return number required_strength The required minimum strength
function deep_space_sensing.check_minimum_strength(force, planet_name)
	local config = DISCOVERABLE_PLANETS[planet_name]
	if not config then
		return false, 0, 0
	end

	local required_strength = config.minimum_strength or 0
	local force_name = force.name

	-- Get efficiency multiplier from infinite tech
	local efficiency_multiplier = deep_space_sensing.get_efficiency_multiplier(force)

	-- Calculate effective network strength toward this target (distance-adjusted)
	local current_strength = 0

	if
		storage[KEYS.CONTRIBUTION_PROBABILITIES]
		and storage[KEYS.ORBITAL_SATELLITES]
		and storage[KEYS.ORBITAL_SATELLITES][force_name]
		and storage[KEYS.CONTRIBUTION_PROBABILITIES][force_name]
	then
		local contribution_map = storage[KEYS.CONTRIBUTION_PROBABILITIES][force_name][planet_name]
		if contribution_map then
			for observer_planet, contribution in pairs(contribution_map) do
				local satellite_count = storage[KEYS.ORBITAL_SATELLITES][force_name][observer_planet] or 0
				-- Apply efficiency multiplier to satellite contribution
				current_strength = current_strength + satellite_count * contribution * efficiency_multiplier
			end
		end
	end

	return current_strength >= required_strength, current_strength, required_strength
end

return deep_space_sensing
