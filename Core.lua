local addonName, addon = ...

local function ApplyEnabled(enabled)
    addon.SetGlowEnabled(enabled)
    addon.SetFishingEnabled(enabled)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        ApplyEnabled(addon.db.enabled)
        return
    end

    if loadedAddon ~= addonName then
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

    local category = Settings.RegisterVerticalLayoutCategory("GatherGlow")
    local setting = Settings.RegisterAddOnSetting(
        category, "GATHERGLOW_ENABLED", "enabled", addon.db,
        Settings.VarType.Boolean, "Enable GatherGlow", true
    )
    setting:SetValueChangedCallback(function(_, enabled)
        ApplyEnabled(enabled)
    end)
    Settings.CreateCheckbox(category, setting,
        "Show gathering markers and fishing pins and play herb and ore chimes. Skinning needs Enemy Unit Nameplate enabled.")
    Settings.RegisterAddOnCategory(category)

    self:RegisterEvent("PLAYER_LOGIN")
end)
