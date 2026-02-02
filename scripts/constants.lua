--- Deep Space Sensing Constants
--- Shared constants for the deep space sensing system.
---
--- @module deep_space_sensing.constants

local constants = {}

--- Scan interval in seconds between discovery attempts
constants.SCAN_INTERVAL_SECONDS = 60

--- Default configuration for discoverable planets (from settings)
constants.DEFAULT_PLANET_CONFIG = {
	hardness = settings.startup["deep-space-sensing-default-hardness"].value,
	base_contribution_scale = settings.startup["deep-space-sensing-default-base-contribution-scale"].value,
	decay_scale = settings.startup["deep-space-sensing-default-decay-scale"].value,
	minimum_strength = settings.startup["deep-space-sensing-default-minimum-strength"].value,
}

--- Global multiplier applied to all hardness values
constants.GLOBAL_HARDNESS_MULTIPLIER = settings.startup["deep-space-sensing-global-hardness-multiplier"].value

--- Default contribution calculation config (from settings)
constants.DEFAULT_CONTRIBUTION_CONFIG = {
	base_scale = settings.startup["deep-space-sensing-default-base-contribution-scale"].value,
	decay_scale = settings.startup["deep-space-sensing-default-decay-scale"].value,
	orbital_capacity = settings.startup["deep-space-sensing-default-orbital-capacity"].value,
	attrition_rate = settings.startup["deep-space-sensing-default-attrition-rate"].value,
}

--- Overflow scale: controls how quickly over-capacity satellites lose effectiveness
constants.OVERFLOW_SCALE = 50

--- Attrition scale: controls how quickly attrition ramps up near capacity
constants.ATTRITION_SCALE = 20

--- Storage keys used in global storage
constants.STORAGE_KEYS = {
	ORBITAL_SATELLITES = "deep_space_orbital_observation_satellites",
	CONTRIBUTION_PROBABILITIES = "deep_space_orbital_satellite_contribution_probabilities",
	DISCOVERY_TARGETS = "deep_space_discovery_targets",
	NEXT_SCAN_TICK = "deep_space_next_scan_tick",
}

--- Technology name that unlocks deep space sensing
constants.UNLOCK_TECHNOLOGY = "deep-space-sensing"

--- GUI element names
constants.GUI = {
	BUTTON_NAME = "planetary_discovery_button",
	FRAME_NAME = "planetary_discovery_frame",
	CONTENT_PANE_NAME = "planetary_discovery_content",
	PREFIX = "planetary_discovery",
}

--- Item name for the observation satellite
constants.OBSERVATION_SATELLITE_ITEM = "deep-space-sensing-observation-satellite"

--- Quality strength multipliers for satellites
--- Higher quality satellites contribute more to discovery chance
--- Indexed by quality level (0-4) for stability across mods
constants.QUALITY_STRENGTH = {
	[0] = 1.0, -- normal
	[1] = 1.3, -- uncommon
	[2] = 1.6, -- rare
	[3] = 1.9, -- epic
	[4] = 2.5, -- legendary
}

return constants
