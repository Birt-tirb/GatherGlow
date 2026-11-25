local addonName, addon = ...

local settingsLayout

local function RefreshSettings()
    if settingsLayout and SettingsPanel:GetCurrentLayout() == settingsLayout then
        SettingsInbound.RepairDisplay()
    end
end

local function ApplyEnabled(enabled)
    addon.SetGlowEnabled(enabled)
    addon.SetFishingEnabled(enabled)
    RefreshSettings()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, argument)
    if event == "CVAR_UPDATE" then
        if argument:lower() == "nameplateshowenemies" then
            RefreshSettings()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        ApplyEnabled(addon.db.enabled)
        return
    end

    if argument ~= addonName then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")
    if type(GatherGlowDB) ~= "table" then
        GatherGlowDB = {}
    end
    if type(GatherGlowDB.enabled) ~= "boolean" then
        GatherGlowDB.enabled = true
    end
    addon.db = GatherGlowDB
    for _, definition in ipairs(addon.IconSettings) do
        if not definition.byID[addon.db[definition.key]] then
            addon.db[definition.key] = "default"
        end
    end

    local category, layout = Settings.RegisterVerticalLayoutCategory("GatherGlow")
    settingsLayout = layout
    local setting = Settings.RegisterAddOnSetting(
        category, "GATHERGLOW_ENABLED", "enabled", addon.db,
        Settings.VarType.Boolean, "Enable GatherGlow", true
    )
    setting:SetValueChangedCallback(function(_, enabled)
        ApplyEnabled(enabled)
    end)
    local enableInitializer = Settings.CreateCheckbox(category, setting,
        "Show gathering markers and fishing pins and play herb and ore chimes. Skinning needs Enemy Unit Nameplate enabled.")
    for _, definition in ipairs(addon.IconSettings) do
        local iconSetting = Settings.RegisterAddOnSetting(
            category, "GATHERGLOW_" .. definition.kind:upper() .. "_ICON", definition.key,
            addon.db, Settings.VarType.String, definition.label, "default"
        )
        iconSetting:SetValueChangedCallback(function()
            addon.RefreshGlow()
        end)
        local function GetOptions()
            local options = Settings.CreateControlTextContainer()
            for _, option in ipairs(definition.options) do
                options:Add(option.id, "|T" .. option.texture .. ":16:16|t " .. option.label)
            end
            return options:GetData()
        end
        local initializer = Settings.CreateDropdown(category, iconSetting, GetOptions, definition.tooltip)
        initializer:SetParentInitializer(enableInitializer, function()
            return addon.db.enabled
        end)
    end
    local warning = CreateSettingsListSectionHeaderInitializer(
        "|cffffd100Skinning markers need Enemy Unit Nameplate|r",
        "Enable Enemy Unit Nameplate under Esc > Options > Gameplay > Nameplates so WoW can show corpse markers."
    )
    warning:AddShownPredicate(function()
        return addon.db.enabled and C_CVar.GetCVarBool("nameplateShowEnemies") == false
    end)
    layout:AddInitializer(warning)
    Settings.RegisterAddOnCategory(category)

    self:RegisterEvent("CVAR_UPDATE")
    self:RegisterEvent("PLAYER_LOGIN")
end)
