--- Deep Space Sensing Data Stage
--- Loads the API for other mods to register their locations.

require("lib.api")  -- Exports deep_space_sensing_api global

-- Load prototypes
require("prototypes.item-groups")
require("prototypes.item")
require("prototypes.recipe")
require("prototypes.technology")
require("prototypes.tips-and-tricks")
