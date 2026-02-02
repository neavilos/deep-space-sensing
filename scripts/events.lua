--- Deep Space Sensing Event Subscriptions
--- Handles all event subscriptions for the deep space sensing system.
---
--- @module deep_space_sensing.events

local deep_space_sensing = require("scripts.init")
local constants = require("scripts.constants")
local planetary_discovery_gui = require("scripts.planetary_discovery_gui")
local sensing_gui = require("scripts.gui")

-- Initialize on game start
script.on_init(function()
    deep_space_sensing.load_configs_from_prototypes()
    deep_space_sensing.setup_satellites_counter()
    deep_space_sensing.setup_planetary_contribution(true)
    sensing_gui.initialize_all_players()
end)

script.on_configuration_changed(function()
    deep_space_sensing.load_configs_from_prototypes()
    deep_space_sensing.setup_satellites_counter()
    deep_space_sensing.setup_planetary_contribution(true)
    sensing_gui.initialize_all_players()
end)

-- Reload configs from prototypes when loading a save
script.on_load(function()
    deep_space_sensing.load_configs_from_prototypes()
end)

-- Handle research completion
script.on_event(defines.events.on_research_finished, function(event)
    -- Deep space sensing tech unlocked
    if event.research.name == constants.UNLOCK_TECHNOLOGY then
        deep_space_sensing.setup_satellites_counter()
        deep_space_sensing.setup_planetary_contribution(true)
    end
    
    -- Refresh GUI when upgrade techs are researched (values will change)
    if event.research.name == "deep-space-sensing-observation-satellite-efficiency"
        or event.research.name == "deep-space-sensing-orbital-capacity-upgrade"
        or event.research.name == "deep-space-sensing-satellite-synchronization" then
        planetary_discovery_gui.refresh_all_guis()
    end
    
    -- Create GUI button for players when tech is researched
    sensing_gui.on_research_finished(event)
end)

-- Handle cargo pod launches
script.on_event(defines.events.on_cargo_pod_finished_ascending, function(event)
    local cargo_pod = event.cargo_pod 

    local inventory = cargo_pod.get_inventory(defines.inventory.cargo_unit)
    if not inventory then
        return
    end

    if inventory.find_item_stack(constants.OBSERVATION_SATELLITE_ITEM) then
        deep_space_sensing.on_satellite_launched(cargo_pod)
    end
end)

-- Handle player creation
script.on_event(defines.events.on_player_created, function(event)
    sensing_gui.on_player_created(event)
end)

-- Handle GUI clicks
script.on_event(defines.events.on_gui_click, function(event)
    sensing_gui.on_gui_click(event)
    planetary_discovery_gui.on_gui_click(event)
end)

-- Handle GUI closed
script.on_event(defines.events.on_gui_closed, function(event)
    planetary_discovery_gui.on_gui_closed(event)
end)

-- Deep space sensing scan check (every second to check per-force timers)
script.on_nth_tick(60, function(event)
    deep_space_sensing.on_progress_tick(event)
end)

-- Satellite attrition (every 60 seconds)
script.on_nth_tick(60 * 60, function(event)
    deep_space_sensing.on_attrition_tick(event)
end)

-- Deep space sensing GUI progress bar update (10 fps is smooth enough for 60s timer)
script.on_nth_tick(6, function(_)
    planetary_discovery_gui.update_progress_bars()
end)

-- Register the refresh callback now that all modules are loaded
planetary_discovery_gui.register_refresh_callback()

return {}
