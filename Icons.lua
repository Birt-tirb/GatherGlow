local addonName, addon = ...

local textureDirectory = "Interface\\AddOns\\" .. addonName .. "\\"

addon.IconSettings = {
    {
        kind = "herb", key = "herbIcon", label = "Herb icon",
        tooltip = "Choose the icon used for herb markers.",
        options = {
            { id = "default", label = "GatherGlow leaf", texture = textureDirectory .. "HerbLeaf.tga" },
            { id = "profession", label = "Herbalism", texture = 136246 },
            { id = "resource", label = "Herb", texture = 134187 },
        },
    },
    {
        kind = "ore", key = "oreIcon", label = "Ore icon",
        tooltip = "Choose the icon used for mining markers.",
        options = {
            { id = "default", label = "GatherGlow crystal", texture = textureDirectory .. "OreCrystal.tga" },
            { id = "profession", label = "Mining", texture = 136248 },
            { id = "resource", label = "Copper ore", texture = 134566 },
        },
    },
    {
        kind = "skinning", key = "skinningIcon", label = "Skinning icon",
        tooltip = "Choose the icon used for skinnable corpse markers.",
        options = {
            { id = "default", label = "GatherGlow hide", texture = textureDirectory .. "SkinningHide.tga" },
            { id = "profession", label = "Skinning", texture = 134366 },
            { id = "resource", label = "Leather scraps", texture = 134250 },
        },
    },
    {
        kind = "fishing", key = "fishingIcon", label = "Fishing icon",
        tooltip = "Choose the icon used for fishing pins on the minimap.",
        options = {
            { id = "default", label = "GatherGlow fish", texture = textureDirectory .. "FishingPoolFish.tga" },
            { id = "profession", label = "Fishing", texture = 136245 },
            { id = "resource", label = "Fish", texture = 133888 },
        },
    },
}

local settingsByKind = {}
for _, definition in ipairs(addon.IconSettings) do
    definition.byID = {}
    for _, option in ipairs(definition.options) do
        definition.byID[option.id] = option
    end
    settingsByKind[definition.kind] = definition
end

function addon.GetIconTexture(kind)
    local definition = settingsByKind[kind]
    if not definition then
        return
    end
    local choice = addon.db and definition.byID[addon.db[definition.key]]
    return (choice or definition.byID.default).texture
end
