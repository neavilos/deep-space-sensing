-- Tips and Tricks entries for Deep Space Sensing

data:extend({
    -- Deep Space Sensing category
    {
        type = "tips-and-tricks-item-category",
        name = "deep-space-sensing",
        order = "z-[deep-space-sensing]"
    },

    -- Deep Space Sensing overview - shows when the technology is researched
    {
        type = "tips-and-tricks-item",
        name = "deep-space-sensing-overview",
        tag = "[item=deep-space-sensing-observation-satellite]",
        category = "deep-space-sensing",
        order = "a",
        trigger = {
            type = "research",
            technology = "deep-space-sensing"
        },
    },

    -- Orbital Capacity - shows after viewing the overview
    {
        type = "tips-and-tricks-item",
        name = "deep-space-sensing-capacity",
        tag = "[img=utility/warning_icon]",
        category = "deep-space-sensing",
        order = "b",
        indent = 1,
        trigger = {
            type = "dependencies-met",
        },
        dependencies = {"deep-space-sensing-overview"},
    },

    -- Research Upgrades - shows after viewing capacity
    {
        type = "tips-and-tricks-item",
        name = "deep-space-sensing-upgrades",
        tag = "[item=space-science-pack]",
        category = "deep-space-sensing",
        order = "c",
        indent = 1,
        trigger = {
            type = "dependencies-met",
        },
        dependencies = {"deep-space-sensing-capacity"},
    },
})
