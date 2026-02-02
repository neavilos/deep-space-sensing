# Deep Space Sensing

A Factorio mod that enables satellite-based discovery of distant space locations.

## Overview

This mod automatically converts technologies with `unlock-space-location` effects into scripted research that requires launching observation satellites and scanning deep space. Space locations and planets must be registered for this conversion to occur.

## For Mod Users

Once installed, technologies that unlock space locations will require satellite-based discovery instead of traditional science pack research. Launch observation satellites into orbit and use the Planetary Discovery interface (button in top bar) to select targets and track progress.

### How It Works

The discovery system uses the following mechanics:

**1. Satellite Strength:**

When you launch an observation satellite, its quality determines its strength:
- Normal: 1.0
- Uncommon: 1.25
- Rare: 1.5
- Epic: 2.0
- Legendary: 2.5

**2. Per-Planet Contribution:**

Each planet's total satellite strength contributes to discovering a target based on distance and both observer and target properties:
```
contribution_from_planet = base_contribution_scale × e^(-distance / observer_decay) × e^(-distance / target_decay)
```
Where:
- `distance` = Euclidean distance between observer planet and target on the star map (based on the space-location's magnitude and orientation, literally interpreting Factorio's stationary orbits)
- `observer_decay` = Observer planet's `decay_scale` (how well its satellites observe distant objects)
- `target_decay` = Target's `decay_scale` (how obscure/faint the target is)
- Signal degrades from BOTH observer limitations AND target properties
- With both decay=25 at distance=50: contribution ≈ 1.8% of base (vs 13.5% with single decay)

**3. Total Network Strength:**
```
total_strength = Σ (strength_on_planet × contribution_from_planet)
```

Where `strength_on_planet` is the sum of all quality-adjusted satellite strengths orbiting that planet.

**4. Minimum Strength Requirement:**

Before scanning can begin, the effective network strength (calculated above) must meet the target's `minimum_strength` requirement. This is the same distance-adjusted calculation, meaning satellites closer to the target count more toward meeting the requirement.

**5. Discovery Chance Per Scan:**
```
discovery_chance = total_strength × efficiency_bonus × e^(-hardness × global_multiplier)
```

Where:
- `hardness` = Per-location difficulty exponent (higher = harder)
- `global_multiplier` = Global hardness multiplier setting (default 1.0)
- Exponential decay means hardness=4 is ~1.8% discovery rate per unit strength

Scans occur every 60 seconds. Each scan has `discovery_chance` probability of success.

**6. Orbital Capacity:**

Each planet has a maximum orbital capacity for satellites. Satellites over capacity contribute with exponential decay:
```
effective_count = capacity + overflow × e^(-overflow / 50)
```
Where `overflow = satellite_count - capacity`. This means massive overfilling provides diminishing returns.

**7. Satellite Attrition:**

Satellites at or above capacity can be destroyed each minute due to orbital crowding:
- **Below capacity:** No attrition
- **At capacity:** Base attrition rate applies
- **Over capacity:** Attrition ramps up exponentially

The GUI shows capacity status with color coding:
- **White text:** Safe (below capacity)
- **Orange text:** Attrition active (at or above capacity)

Hover over planet entries to see exact attrition percentages.

**8. Infinite Research Technologies:**

Three infinite research technologies improve your satellite network:

- **Observation Satellite Efficiency:** +10% contribution per level (requires cryogenic science)
- **Orbital Capacity Upgrade:** +10% capacity per level (requires deep-space-sensing)
- **Satellite Durability:** +10% durability per level, reducing attrition (requires deep-space-sensing)

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
            "Launch [item=observation-satellite] and scan for ",
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
    "Launch [item=observation-satellite] and scan for ",
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
