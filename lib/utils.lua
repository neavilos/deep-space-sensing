--- Deep Space Sensing Data-Stage Utilities
--- Shared utility functions for data stage processing.
---
--- @module deep_space_sensing.utils

local utils = {}

--- Creates a hidden custom_tooltip_field entry
--- @param name string The field name (prefixed with dss_)
--- @param value any The value (will be converted to string)
--- @return table field The tooltip field table
function utils.tooltip_field(name, value)
	return {
		name = name,
		value = tostring(value),
		show_in_tooltip = false,
		show_in_factoriopedia = false,
	}
end

--- Adds multiple tooltip fields to a prototype
--- @param prototype table The prototype to add fields to
--- @param fields table Key-value pairs of field names to values
function utils.add_tooltip_fields(prototype, fields)
	prototype.custom_tooltip_fields = prototype.custom_tooltip_fields or {}
	for name, value in pairs(fields) do
		table.insert(prototype.custom_tooltip_fields, utils.tooltip_field(name, value))
	end
end

--- Parses the opted-in locations from settings and API registrations
--- @return table opted_in_locations Set of location names that are opted in
function utils.get_opted_in_locations()
	local opted_in_locations = {}

	-- Read from API registrations
	if deep_space_sensing_api and deep_space_sensing_api._registered_locations then
		for _, location in ipairs(deep_space_sensing_api._registered_locations) do
			opted_in_locations[location] = true
		end
	end

	-- Read from settings
	local setting_value = settings.startup["deep-space-sensing-locations"].value
	if setting_value and setting_value ~= "" then
		for location in string.gmatch(setting_value, "[^,]+") do
			location = location:match("^%s*(.-)%s*$") -- Trim whitespace
			if location ~= "" then
				opted_in_locations[location] = true
			end
		end
	end

	return opted_in_locations
end

--- Gets a space-location or planet prototype by name
--- @param location_name string The location name
--- @return table|nil prototype The prototype or nil if not found
function utils.get_location_prototype(location_name)
	return data.raw["space-location"][location_name] or data.raw.planet[location_name]
end

--- Ensures a technology has a specific prerequisite
--- @param tech table The technology prototype
--- @param prereq string The prerequisite to add
function utils.ensure_prerequisite(tech, prereq)
	tech.prerequisites = tech.prerequisites or {}
	for _, existing in ipairs(tech.prerequisites) do
		if existing == prereq then return end
	end
	table.insert(tech.prerequisites, prereq)
end

return utils
