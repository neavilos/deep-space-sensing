--- Planetary Discovery GUI Module
--- Provides an interactive interface for discovering planets via observation satellites.
--- Players select target planets and the satellite network attempts to discover them.
---
--- @module deep_space_sensing.planetary_discovery_gui

local constants = require("scripts.constants")
local deep_space_sensing = require("scripts.init")
local planet_distance = require("scripts.planet_distance")

local GUI_PREFIX = constants.GUI.PREFIX
local FRAME_NAME = constants.GUI.FRAME_NAME
local CONTENT_PANE_NAME = constants.GUI.CONTENT_PANE_NAME
local KEYS = constants.STORAGE_KEYS

--- Cache of GUI element references per player to avoid recursive search every tick
local element_cache = {}

local gui = {}

--- Creates the main planetary discovery GUI
--- @param player LuaPlayer The player to create the GUI for
function gui.create_gui(player)
	-- Don't create if it already exists
	if player.gui.screen[FRAME_NAME] then
		return
	end

	local frame = player.gui.screen.add({
		type = "frame",
		name = FRAME_NAME,
		direction = "vertical",
	})
	frame.auto_center = true

	-- Title bar
	local title_flow = frame.add({
		type = "flow",
		direction = "horizontal",
	})
	title_flow.style.horizontal_spacing = 8
	title_flow.add({
		type = "label",
		caption = { "deep-space-sensing.planetary-discovery-title" },
		style = "frame_title",
	})

	local drag_handle = title_flow.add({
		type = "empty-widget",
		style = "draggable_space_header",
	})
	drag_handle.style.height = 32
	drag_handle.style.horizontally_stretchable = true
	drag_handle.drag_target = frame

	-- Close button
	title_flow.add({
		type = "sprite-button",
		name = GUI_PREFIX .. "_close",
		sprite = "utility/close",
		style = "frame_action_button",
	})

	-- Main content area - horizontal split
	local content_flow = frame.add({
		type = "flow",
		name = CONTENT_PANE_NAME,
		direction = "horizontal",
	})
	content_flow.style.horizontal_spacing = 12

	-- Left panel: Network status (scrollable for many satellites)
	local left_scroll = content_flow.add({
		type = "scroll-pane",
		name = "network_panel",
		direction = "vertical",
	})
	left_scroll.style.minimal_width = 300
	left_scroll.style.maximal_height = 550
	left_scroll.style.padding = 8

	-- Right panel: Research targets
	local right_scroll = content_flow.add({
		type = "scroll-pane",
		name = "research_panel",
		direction = "vertical",
	})
	right_scroll.style.maximal_height = 550
	right_scroll.style.minimal_width = 320

	gui.refresh_content(player)

	player.opened = frame
end

--- Shows satellite network status section
--- @param network_flow LuaGuiElement The flow to add to
--- @param player LuaPlayer The player
--- @param current_target string|nil Current scan target
local function show_network_status(network_flow, player, current_target)
	local sensing = deep_space_sensing

	network_flow.add({
		type = "label",
		caption = { "deep-space-sensing.satellite-network-status" },
		style = "caption_label",
	})

	-- Show scan progress bar if scanning
	if current_target then
		local progress = sensing.get_scan_progress(player.force)
		local seconds_remaining = sensing.get_seconds_until_scan(player.force)

		local progress_flow = network_flow.add({
			type = "flow",
			direction = "horizontal",
		})
		progress_flow.style.vertical_align = "center"
		progress_flow.style.horizontal_spacing = 8

		progress_flow.add({
			type = "label",
			caption = { "deep-space-sensing.next-scan" },
		})

		local progress_bar = progress_flow.add({
			type = "progressbar",
			name = GUI_PREFIX .. "_scan_progress",
			value = progress,
		})
		progress_bar.style.width = 200

		local countdown = progress_flow.add({
			type = "label",
			name = GUI_PREFIX .. "_scan_countdown",
			caption = string.format("%ds", seconds_remaining),
		})

		-- Cache element references for fast updates
		element_cache[player.index] = {
			progress_bar = progress_bar,
			countdown = countdown,
		}
	else
		-- Clear cache when not scanning
		element_cache[player.index] = nil

		network_flow.add({
			type = "label",
			caption = { "deep-space-sensing.select-target-to-scan" },
		})
	end

	-- Show efficiency bonus if any
	local efficiency_multiplier = sensing.get_efficiency_multiplier(player.force)
	if efficiency_multiplier > 1.0 then
		local bonus_percent = (efficiency_multiplier - 1.0) * 100
		network_flow.add({
			type = "label",
			caption = { "deep-space-sensing.efficiency-bonus-display", string.format("%.0f", bonus_percent) },
		})
	end

	-- Show capacity bonus if any
	local capacity_multiplier = sensing.get_capacity_multiplier(player.force)
	if capacity_multiplier > 1.0 then
		local bonus_percent = (capacity_multiplier - 1.0) * 100
		network_flow.add({
			type = "label",
			caption = { "deep-space-sensing.capacity-bonus-display", string.format("%.0f", bonus_percent) },
		})
	end

	-- Show durability bonus if any
	local durability_multiplier = sensing.get_durability_multiplier(player.force)
	if durability_multiplier > 1.0 then
		local bonus_percent = (durability_multiplier - 1.0) * 100
		network_flow.add({
			type = "label",
			caption = { "deep-space-sensing.synchronization-bonus-display", string.format("%.0f", bonus_percent) },
		})
	end
end

--- Shows satellite strength list
--- @param network_flow LuaGuiElement The flow to add to
--- @param player LuaPlayer The player
--- @param current_target string|nil Current scan target
--- @return boolean has_satellites True if any satellites exist
local function show_satellite_list(network_flow, player, current_target)
	local sensing = deep_space_sensing
	local has_satellites = false
	local satellite_counts = sensing.get_satellite_counts(player.force)

	-- Get multipliers from infinite techs
	local efficiency_multiplier = sensing.get_efficiency_multiplier(player.force)
	local capacity_multiplier = sensing.get_capacity_multiplier(player.force)

	-- Get contribution map for current target if one is selected
	local contribution_map = nil
	if
		current_target
		and storage[KEYS.CONTRIBUTION_PROBABILITIES]
		and storage[KEYS.CONTRIBUTION_PROBABILITIES][player.force.name]
	then
		contribution_map = storage[KEYS.CONTRIBUTION_PROBABILITIES][player.force.name][current_target]
	end

	-- Get durability multiplier for attrition calculation
	local durability_multiplier = sensing.get_durability_multiplier(player.force)

	if satellite_counts then
		for planet_name, satellite_count in pairs(satellite_counts) do
			if satellite_count > 0 then
				has_satellites = true

				-- Get observer properties
				local observer_props = planet_distance.get_observer_properties(planet_name)
				local base_scale = observer_props.base_scale
				local effective_capacity = math.floor(observer_props.orbital_capacity * capacity_multiplier)

				-- Calculate effective satellite count (with overflow penalty)
				local effective_count = sensing.get_effective_satellite_count(satellite_count, effective_capacity)

				-- Calculate observer strength (includes efficiency bonus)
				local observer_strength = effective_count * base_scale * efficiency_multiplier
				local formatted_strength = string.format("%.2f", observer_strength)
				local formatted_count = string.format("%.0f", satellite_count)

				-- Get localized planet name
				local planet_display_name = planet_name
				local location_proto = prototypes.space_location[planet_name]
				if location_proto then
					planet_display_name = location_proto.localised_name
				end

				-- Calculate attrition info (only applies at or above capacity)
				local attrition_chance = sensing.calculate_attrition_chance(
					satellite_count,
					effective_capacity,
					observer_props.attrition_rate
				) / durability_multiplier
				local attrition_percent = attrition_chance * 100

				-- Determine status and color (attrition only at/above capacity)
				local is_at_capacity = satellite_count >= effective_capacity
				local font_color = nil
				local tooltip = nil

				if is_at_capacity then
					font_color = { 1, 0.5, 0.3 } -- Orange/red warning
					tooltip = { "deep-space-sensing.attrition-warning", string.format("%.2f", attrition_percent) }
				end

				-- Create row with icon and info
				local row_flow = network_flow.add({
					type = "flow",
					direction = "horizontal",
				})
				row_flow.style.vertical_align = "center"
				row_flow.style.horizontal_spacing = 6

				-- Planet icon
				row_flow.add({
					type = "sprite",
					sprite = "space-location/" .. planet_name,
					resize_to_sprite = false,
				}).style.size =
					{ 24, 24 }

				-- If we have a target selected, show effective contribution toward it
				local label
				if contribution_map and contribution_map[planet_name] then
					local effective_contribution = effective_count
						* contribution_map[planet_name]
						* efficiency_multiplier
					local formatted_contribution = string.format("%.2f", effective_contribution)
					label = row_flow.add({
						type = "label",
						caption = {
							"deep-space-sensing.satellite-strength-with-contribution-capacity",
							planet_display_name,
							formatted_strength,
							formatted_count,
							effective_capacity,
							formatted_contribution,
						},
					})
				else
					label = row_flow.add({
						type = "label",
						caption = {
							"deep-space-sensing.satellite-strength-capacity",
							planet_display_name,
							formatted_strength,
							formatted_count,
							effective_capacity,
						},
					})
				end

				if font_color then
					label.style.font_color = font_color
				end
				if tooltip then
					label.tooltip = tooltip
				end
			end
		end
	end

	if not has_satellites then
		network_flow.add({
			type = "label",
			caption = { "deep-space-sensing.no-satellites-in-orbit" },
		})
	end

	return has_satellites
end

--- Creates a single planet entry in the GUI
--- @param scroll_pane LuaGuiElement The scroll pane to add to
--- @param player LuaPlayer The player
--- @param planet_name string The planet name
--- @param planet_config table The planet configuration
--- @param current_target string|nil Current scan target
local function create_planet_entry(scroll_pane, player, planet_name, planet_config, current_target)
	local sensing = deep_space_sensing
	local discovery_tech_name = planet_config.tech_name
	local display_name = planet_config.display_name or planet_name
	local tech = player.force.technologies[discovery_tech_name]

	if not tech then
		return
	end

	-- Create planet entry
	local planet_frame = scroll_pane.add({
		type = "frame",
		direction = "vertical",
		style = "inside_shallow_frame",
	})
	planet_frame.style.padding = 8
	planet_frame.style.margin = 4

	local header_flow = planet_frame.add({
		type = "flow",
		direction = "horizontal",
	})
	header_flow.style.vertical_align = "center"
	header_flow.style.horizontal_spacing = 8

	-- Technology/Location icon
	header_flow.add({
		type = "sprite",
		sprite = planet_config.icon_sprite or ("technology/" .. discovery_tech_name),
		resize_to_sprite = false,
	}).style.size =
		{ 32, 32 }

	-- Planet name (display name)
	header_flow.add({
		type = "label",
		caption = display_name,
		style = "heading_2_label",
	})

	-- Status with color coding
	if tech.researched then
		local label = header_flow.add({
			type = "label",
			caption = { "deep-space-sensing.planet-discovered" },
		})
		label.style.font_color = { 0.3, 0.9, 0.3 } -- Green
	elseif current_target == planet_name then
		local label = header_flow.add({
			type = "label",
			caption = { "deep-space-sensing.planet-scanning" },
		})
		label.style.font_color = { 1, 0.85, 0.2 } -- Yellow/gold
	else
		local label = header_flow.add({
			type = "label",
			caption = { "deep-space-sensing.planet-undiscovered" },
		})
		label.style.font_color = { 0.6, 0.6, 0.6 } -- Gray
	end

	-- Prerequisites check
	local prereqs_met = true
	if tech.prerequisites then
		for _, prereq_tech in pairs(tech.prerequisites) do
			if not prereq_tech.researched then
				prereqs_met = false
				break
			end
		end
	end

	if not prereqs_met then
		planet_frame.add({
			type = "label",
			caption = { "deep-space-sensing.prerequisites-not-met" },
		})
	elseif not tech.researched then
		-- Check if force has any satellites
		local force_has_satellites = sensing.has_any_satellites(player.force)

		-- Show discovery chance (capped at 100% for display)
		local discovery_chance = sensing.calculate_discovery_chance(player.force, planet_name)
		local display_chance = math.min(discovery_chance * 100, 100)

		planet_frame.add({
			type = "label",
			caption = { "deep-space-sensing.discovery-chance", string.format("%.4f", display_chance) },
		})

		-- Check minimum strength requirement
		local meets_min, current_strength, required_strength = sensing.check_minimum_strength(player.force, planet_name)

		if required_strength > 0 then
			local strength_label = planet_frame.add({
				type = "label",
				caption = {
					"deep-space-sensing.strength-requirement",
					string.format("%.2f", current_strength),
					string.format("%.2f", required_strength),
				},
			})
			-- Color code: green if met, red if not met
			if meets_min then
				strength_label.style.font_color = { 0.3, 0.9, 0.3 } -- Green
			else
				strength_label.style.font_color = { 0.9, 0.3, 0.3 } -- Red
			end
		end

		-- Scan button (only enabled if satellites exist AND minimum strength met)
		if current_target == planet_name then
			planet_frame.add({
				type = "button",
				name = GUI_PREFIX .. "_stop_scan",
				caption = { "deep-space-sensing.stop-scanning" },
				style = "red_back_button",
			})
		else
			local can_scan = force_has_satellites and meets_min
			local scan_button = planet_frame.add({
				type = "button",
				name = GUI_PREFIX .. "_start_scan_" .. planet_name,
				caption = { "deep-space-sensing.start-scanning" },
				enabled = can_scan,
			})
			if not force_has_satellites then
				scan_button.tooltip = { "deep-space-sensing.launch-satellites-to-scan" }
			elseif not meets_min then
				scan_button.tooltip = {
					"deep-space-sensing.strength-requirement",
					string.format("%.1f", current_strength),
					string.format("%.1f", required_strength),
				}
			end
		end
	end
end

--- Refreshes the planet list in the GUI
--- @param player LuaPlayer The player whose GUI to refresh
function gui.refresh_content(player)
	local sensing = deep_space_sensing

	local frame = player.gui.screen[FRAME_NAME]
	if not frame then
		return
	end

	local content_flow = frame[CONTENT_PANE_NAME]
	if not content_flow then
		return
	end

	local network_panel = content_flow["network_panel"]
	local research_panel = content_flow["research_panel"]

	if not network_panel or not research_panel then
		return
	end

	network_panel.clear()
	research_panel.clear()

	-- Get discoverable planets from deep space sensing
	local discoverable_planets = sensing.get_discoverable_planets()

	if
		not player.force.technologies[constants.UNLOCK_TECHNOLOGY]
		or not player.force.technologies[constants.UNLOCK_TECHNOLOGY].researched
	then
		network_panel.add({
			type = "label",
			caption = { "deep-space-sensing.tech-required" },
		})
		return
	end

	-- Get current target
	local current_target = sensing.get_discovery_target(player.force)

	-- Left panel: Network status and satellite list
	show_network_status(network_panel, player, current_target)

	network_panel.add({
		type = "line",
		direction = "horizontal",
	}).style.top_margin = 8

	show_satellite_list(network_panel, player, current_target)

	-- Right panel: Research targets
	-- Build sorted list of planets by order field
	local sorted_planets = {}
	for planet_name, planet_config in pairs(discoverable_planets) do
		table.insert(sorted_planets, { name = planet_name, config = planet_config })
	end
	table.sort(sorted_planets, function(a, b)
		return (a.config.order or "z") < (b.config.order or "z")
	end)

	-- List discoverable planets
	for _, planet_entry in ipairs(sorted_planets) do
		create_planet_entry(research_panel, player, planet_entry.name, planet_entry.config, current_target)
	end
end

--- Destroys the planetary discovery GUI
--- @param player LuaPlayer The player whose GUI to destroy
function gui.destroy_gui(player)
	local frame = player.gui.screen[FRAME_NAME]
	if frame and frame.valid then
		frame.destroy()
	end
	-- Clear element cache
	element_cache[player.index] = nil
end

--- Toggles the planetary discovery GUI
--- @param player LuaPlayer The player to toggle for
function gui.toggle_gui(player)
	if player.gui.screen[FRAME_NAME] then
		gui.destroy_gui(player)
	else
		gui.create_gui(player)
	end
end

--- Handler for GUI click events
--- @param event EventData The GUI click event
function gui.on_gui_click(event)
	if not event.element or not event.element.valid then
		return
	end

	local sensing = deep_space_sensing
	local player = game.players[event.player_index]
	local element_name = event.element.name

	-- Close button
	if element_name == GUI_PREFIX .. "_close" then
		gui.destroy_gui(player)
		return
	end

	-- Stop scanning button
	if element_name == GUI_PREFIX .. "_stop_scan" then
		sensing.set_discovery_target(player.force, nil)
		player.print({ "deep-space-sensing.scanning-stopped" })
		gui.refresh_content(player)
		return
	end

	-- Start scanning button
	local start_prefix = GUI_PREFIX .. "_start_scan_"
	if element_name:sub(1, #start_prefix) == start_prefix then
		local planet_name = element_name:sub(#start_prefix + 1)

		sensing.set_discovery_target(player.force, planet_name)

		-- Use display name in the message
		local display_name = sensing.get_display_name(planet_name)
		player.print({ "deep-space-sensing.now-scanning-for", display_name })
		gui.refresh_content(player)
		return
	end
end

--- Handler for GUI closed events
--- @param event EventData The GUI closed event
function gui.on_gui_closed(event)
	if not event.element or not event.element.valid then
		return
	end
	if event.element.name == FRAME_NAME then
		gui.destroy_gui(game.players[event.player_index])
	end
end

--- Refresh all open planetary discovery GUIs
function gui.refresh_all_guis()
	for _, player in pairs(game.players) do
		if player.gui.screen[FRAME_NAME] then
			gui.refresh_content(player)
		end
	end
end

--- Updates progress bars WITHOUT rebuilding the GUI
--- This allows button clicks to work properly
function gui.update_progress_bars()
	local sensing = deep_space_sensing

	for _, player in pairs(game.players) do
		local frame = player.gui.screen[FRAME_NAME]
		if not frame or not frame.valid then
			element_cache[player.index] = nil
			goto continue
		end

		-- Only update if this force is actively scanning
		local current_target = sensing.get_discovery_target(player.force)
		if not current_target then
			goto continue
		end

		-- Use cached references if available and valid
		local cache = element_cache[player.index]
		if cache and cache.progress_bar and cache.progress_bar.valid and cache.countdown and cache.countdown.valid then
			cache.progress_bar.value = sensing.get_scan_progress(player.force)
			cache.countdown.caption = string.format("%ds", sensing.get_seconds_until_scan(player.force))
		end

		::continue::
	end
end

--- Registers the refresh callback with the sensing module
--- Called after the module is fully loaded
function gui.register_refresh_callback()
	deep_space_sensing.register_refresh_callback(gui.refresh_all_guis)
end

return gui
