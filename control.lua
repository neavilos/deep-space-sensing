--- Deep Space Sensing Control Script
--- Main entry point for the mod's runtime logic.

local deep_space_sensing = require("scripts.init")
local planet_distance = require("scripts.planet_distance")
local planetary_discovery_gui = require("scripts.planetary_discovery_gui")
local constants = require("scripts.constants")
local KEYS = constants.STORAGE_KEYS

-- Load all event subscriptions (includes initialization)
require("scripts.events")

-- Remote interface for debugging
remote.add_interface("deep-space-sensing", {
    rebuild_sensing = function()
        deep_space_sensing.setup_satellites_counter()
        deep_space_sensing.setup_planetary_contribution(true)
        game.print("Rebuilt sensing contribution maps")
    end,
    debug_contributions = function()
        local force_name = game.player.force.name
        local probs = storage.deep_space_orbital_satellite_contribution_probabilities
        if not probs or not probs[force_name] then
            game.print("No contribution probabilities stored")
            return
        end
        for target, planets in pairs(probs[force_name]) do
            game.print("=== " .. target .. " ===")
            for planet, contrib in pairs(planets) do
                game.print("  " .. planet .. ": " .. string.format("%.6f (%.4f%%)", contrib, contrib * 100))
            end
        end
    end,
    debug_satellites = function()
        local force_name = game.player.force.name
        local sats = storage.deep_space_orbital_observation_satellites
        if not sats or not sats[force_name] then
            game.print("No satellites tracked")
            return
        end
        for planet, count in pairs(sats[force_name]) do
            game.print(planet .. ": " .. count)
        end
    end,
    debug_distances = function(target_planet_name)
        planet_distance.debug_print_distances(target_planet_name)
    end,
    debug_stored_contributions = function(target_planet_name)
        planet_distance.debug_print_stored_contributions(game.player.force, target_planet_name)
    end,
    add_satellites = function(planet_name, count)
        local force_name = game.player.force.name
        
        -- Initialize if needed
        if not storage[KEYS.ORBITAL_SATELLITES] then
            deep_space_sensing.setup_satellites_counter()
        end
        
        if not storage[KEYS.ORBITAL_SATELLITES][force_name] then
            storage[KEYS.ORBITAL_SATELLITES][force_name] = {}
        end
        
        if not storage[KEYS.ORBITAL_SATELLITES][force_name][planet_name] then
            storage[KEYS.ORBITAL_SATELLITES][force_name][planet_name] = 0
        end
        
        -- Add satellites
        local old_count = storage[KEYS.ORBITAL_SATELLITES][force_name][planet_name]
        storage[KEYS.ORBITAL_SATELLITES][force_name][planet_name] = old_count + count
        local new_count = storage[KEYS.ORBITAL_SATELLITES][force_name][planet_name]
        
        game.print(string.format("[Debug] Added %d satellites to %s orbit. Total: %.1f", 
            count, planet_name, new_count))
        
        -- Refresh GUIs
        planetary_discovery_gui.refresh_all_guis()
    end,
    debug_location = function(location_name)
        local location = prototypes.space_location[location_name]
        if not location then
            game.print("Space location '" .. location_name .. "' not found")
            return
        end
        
        game.print("=== Space Location: " .. location_name .. " ===")
        game.print("localised_name: " .. serpent.line(location.localised_name))
        
        local planet_config = deep_space_sensing.get_planet_config(location_name)
        if planet_config then
            game.print("display_name in config: " .. serpent.line(planet_config.display_name))
        else
            game.print("Not registered as discoverable")
        end
    end,
    debug_observer_props = function(location_name)
        game.print("=== Observer Properties: " .. location_name .. " ===")
        
        local location = prototypes.space_location[location_name]
        if not location then
            game.print("  Space location not found: " .. location_name)
            return
        end
        
        if location.custom_tooltip_fields then
            game.print("  custom_tooltip_fields:")
            for _, field in ipairs(location.custom_tooltip_fields) do
                game.print("    " .. tostring(field.name) .. " = " .. tostring(field.value))
            end
        else
            game.print("  No custom_tooltip_fields found")
        end
        
        local props = planet_distance.get_observer_properties(location_name)
        game.print("  Parsed base_scale: " .. tostring(props.base_scale))
        game.print("  Parsed decay_scale: " .. tostring(props.decay_scale))
        
        -- Also show defaults for comparison
        game.print("  Default base_scale: " .. tostring(constants.DEFAULT_CONTRIBUTION_CONFIG.base_scale))
        game.print("  Default decay_scale: " .. tostring(constants.DEFAULT_CONTRIBUTION_CONFIG.decay_scale))
    end,
})
