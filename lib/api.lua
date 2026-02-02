--- Deep Space Sensing Data-Stage API
--- Provides functions for other mods to register their space locations.
---
--- @module deep_space_sensing_api

if not deep_space_sensing_api then
	deep_space_sensing_api = {}
	deep_space_sensing_api._registered_locations = {}
end

--- Register a space location for deep space sensing discovery
--- @param location_name string The name of the space location
function deep_space_sensing_api.register_location(location_name)
	table.insert(deep_space_sensing_api._registered_locations, location_name)
end

return deep_space_sensing_api
