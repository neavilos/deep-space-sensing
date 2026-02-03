# Deep Space Sensing

A Factorio mod that enables satellite-based discovery of distant space locations.

## Overview

This mod automatically converts technologies with `unlock-space-location` effects into scripted research that requires launching observation satellites and scanning deep space. Space locations and planets must be registered for this conversion to occur.

## For Mod Users

Once installed, technologies that unlock space locations will require satellite-based discovery instead of traditional science pack research. Launch observation satellites into orbit and use the Planetary Discovery interface (button in top bar) to select targets and track progress.

### Using the GUI

Open the Planetary Discovery interface from the top bar button to see:

**Network Status Panel (Left):**
- Current scan progress and next scan timer
- Research upgrade bonuses (Efficiency, Capacity, Synchronization)
- Satellite network by planet:
  - Planet icon and name
  - Total strength and satellite count
  - Capacity status (e.g., "150/500 cap")
  - Contribution to current target ("→ X effective")
  - Color coding: white = safe, orange = attrition active
  - Hover for attrition percentage when at/above capacity

**Research Targets Panel (Right):**
- Available targets with icons and names
- Discovery chance percentage
- Minimum strength requirement
- Current scanning target highlighted
- Prerequisite techs must be researched first

### How It Works

The discovery system uses the following mechanics:

**1. Satellite Strength:**

When you launch an observation satellite, its quality determines its strength:
- Normal: 1.0
- Uncommon: 1.25
- Rare: 1.5
- Epic: 2.0
- Legendary: 2.5

**2. Orbital Capacity:**

Each planet has a maximum orbital capacity for satellites. Satellites over capacity contribute with diminishing returns:
- If `satellite_count ≤ capacity`: all satellites contribute fully
- If `satellite_count > capacity`: let `overflow = satellite_count - capacity`, then:
```
effective_count = capacity + overflow × e^(-overflow / 50)
```

This means massive overfilling provides little benefit beyond capacity.

**3. Per-Planet Contribution:**

Each planet's satellites contribute to discovering a target based on distance. The calculation has two parts:

First, calculate the distance decay factor:
```
distance_factor = e^(-distance / observer_decay) × e^(-distance / target_decay)
```

Then multiply by the observer's base scale:
```
contribution_from_planet = base_contribution_scale × distance_factor
```

**Parameters:**
- `base_contribution_scale` = Observer planet's base sensing capability
- `observer_decay` = How far this planet's satellites can effectively observe (higher = longer range)
- `target_decay` = How visible/detectable the target is (higher = easier to spot)
- `distance` = Distance between observer and target on the star map

**GUI Display:** The network panel shows each planet's total strength multiplied by `distance_factor` as "→ X effective" - this is how much of that planet's network strength actually reaches the target.

Example: With decay=25 for both planets at distance=50, distance_factor ≈ 0.018 (only 1.8% of strength reaches the target).


**4. Total Network Strength:**
```
total_strength = Σ (effective_count_on_planet × contribution_from_planet)
```

Where `effective_count_on_planet` is the capacity-adjusted sum of quality-weighted satellite strengths orbiting that planet.

**5. Minimum Strength Requirement:**

Before scanning can begin, the effective network strength (calculated above) must meet the target's `minimum_strength` requirement. This is the same distance-adjusted calculation, meaning satellites closer to the target count more toward meeting the requirement.

**6. Discovery Chance Per Scan:**
```
discovery_chance = total_strength × efficiency_bonus × e^(-hardness × global_multiplier)
```

Where:
- `hardness` = Per-location difficulty exponent (higher = harder)
- `global_multiplier` = Global hardness multiplier setting (default 1.0)
- Exponential decay means hardness=4 is ~1.8% discovery rate per unit strength

Scans occur every 60 seconds. Each scan has `discovery_chance` probability of success.

**7. Satellite Attrition:**

Satellites at or above capacity can be destroyed each minute due to orbital crowding:
- **Below capacity:** No attrition
- **At capacity:** Base attrition rate applies
- **Over capacity:** Attrition ramps up exponentially

The GUI shows capacity status with color coding and displays attrition percentage when at or above capacity:
- **White text:** Safe (below capacity)
- **Orange text:** Attrition active (at or above capacity, hover for details)

**8. Infinite Research Technologies:**

Three infinite research technologies improve your satellite network:

- **Observation Satellite Efficiency:** +10% contribution per level (requires cryogenic science)
- **Orbital Capacity Upgrade:** +10% capacity per level (requires electromagnetic science)
- **Orbital Synchronization:** +10% durability per level, reducing attrition (requires cryogenic science)

## For Mod Developers

### Adding Deep Space Sensing to Your Locations

To make a space location discoverable via deep space sensing:

**1. Add properties to your space-location prototype:**

```lua
{
    type = "space-location", -- or "planet"
    name = "your-planet",
    -- ... other space-location properties ...
    deep_space_sensing_properties = {
        base_contribution_scale = 0.01,
        decay_scale = 25,
        orbital_capacity = 500,
        attrition_rate = 0.001,
    },
}
```

**2. Add parameters to the discovery technology:**

```lua
{
    type = "technology",
    name = "planet-discovery-your-planet",
    effects = {
        {
            type = "unlock-space-location",
            space_location = "your-space-location"
        }
    },
    deep_space_sensing_parameters = {
        hardness = 6.0,
        minimum_strength = 1800.0,
        order = "d-a",
        trigger_description = {
            "",
            "Launch [item=deep-space-sensing-observation-satellite] and scan for ",
            "[planet=your-planet]",
            " via Deep Space Sensing.",
        }
    },
}
```

**3. Register the location in your `data.lua`:**

```lua
if deep_space_sensing_api then
    deep_space_sensing_api.register_location("your-planet")
end
```

All parameters are optional - defaults will be used if not specified.

### Space-Location Properties Reference

These properties control both observation capability (when launching from here) AND detectability (when being discovered):

**`base_contribution_scale`** (number, optional, default: `0.003`)  
Scale factor for satellites at this location. Affects how much each satellite contributes before distance decay.

**`decay_scale`** (number, optional, default: `15`)  
Dual purpose:
- **As observer:** Controls how quickly satellite effectiveness drops off with distance for observations FROM this location
- **As target:** Controls how obscure/faint this location is when being discovered
- Higher values = slower decay (better observation range OR easier to detect)
- The formula uses BOTH observer and target decay scales multiplicatively

**`orbital_capacity`** (number, optional, default: `500`)  
Maximum number of satellites that can orbit at full effectiveness. Satellites over capacity contribute with exponential decay and face increased attrition.

**`attrition_rate`** (number, optional, default: `0.001`)  
Base probability per satellite per minute of being destroyed. Attrition increases exponentially when approaching or exceeding orbital capacity.
- Harsh environments (e.g., asteroid fields): higher values like `0.005`
- Stable orbits: lower values like `0.001`

**Note:** The display name is automatically read from the space-location's `localised_name` property, and the icon is read from `starmap_icon` or `icon`.

### Technology Parameters Reference

These define research-specific requirements:

**`hardness`** (number, optional, default: `1.0`)  
Exponential difficulty factor. Discovery uses `e^(-hardness × global_multiplier)`.

Hardness scale reference:
| Hardness | e^(-h) | Effect |
|----------|--------|--------|
| 0 | 100% | Trivial (no penalty) |
| 2 | 13.5% | Easy |
| 4 | 1.8% | Medium |
| 5 | 0.67% | Hard |
| 6 | 0.25% | Very Hard |
| 8 | 0.034% | Extreme |

Example values:
- Inner planets: `hardness = 4.0`, `minimum_strength = 1.0`
- Outer planets: `hardness = 5.0`, `minimum_strength = 2.0`
- Endgame locations: `hardness = 6.0`, `minimum_strength = 5.0`

**`minimum_strength`** (number, optional, default: `0.0`)  
The minimum effective network strength (distance-adjusted) required before research can begin. The scan button will be disabled until this threshold is reached. Uses the same contribution calculation as discovery chance, so satellites closer to the target count more toward the requirement.

With default base_contribution_scale of 0.01, satellite strength toward a target is approximately:
- 100 satellites at distance 0: 100 × 0.01 = 1.0 effective
- 100 satellites at typical inner planet distance: ~0.3-0.5 effective (after decay)

Example minimum_strength values:
- Inner planets: `1.0 - 2.0`
- Outer planets: `2.0 - 5.0`
- Endgame locations: `5.0+`

**`order`** (string, optional, default: `"z"`)  
Factorio-style ordering string that controls the position in the GUI list. Uses alphabetical sorting.
- Examples: `"a-a"` (first), `"b-c"` (between b-b and b-d), `"z-z"` (last)

**`trigger_description`** (LocalisedString, optional)  
Description shown in the technology tree for the research trigger.
```lua
trigger_description = {
    "",
    "Launch [item=deep-space-sensing-observation-satellite] and scan for ",
    "[planet=your-planet]",
    " via Deep Space Sensing.",
}
```

### User Configuration

Users can edit which locations use satellite discovery in Settings → Startup → "Deep Space Sensing Locations" (comma-separated list).

## Debug Commands

```lua
/c remote.call("deep-space-sensing", "debug_distances", "planet-name")
/c remote.call("deep-space-sensing", "debug_contributions")
/c remote.call("deep-space-sensing", "add_satellites", "nauvis", 1000)
/c remote.call("deep-space-sensing", "rebuild_sensing")
```

## TODO

- **Migrate to ModData:** Replace `custom_tooltip_fields` with ModData for passing configuration from data stage to control stage. This is a cleaner approach for inter-stage data transfer.

- **Separate satellite count from strength:** Currently satellite count and quality-weighted strength are conflated. These should be tracked separately so that:
  - Orbital capacity and attrition are based on raw satellite count
  - Network strength contributions are based on quality-weighted strength
  
  This would allow 100 legendary satellites to count as 100 for capacity purposes but contribute 250 strength.
