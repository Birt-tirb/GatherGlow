local addonName, addon = ...

local interactUnit = "softinteract"
local refreshInterval = 0.15
local flareTexture = "Interface\\Cooldown\\star4"
local textureDirectory = "Interface\\AddOns\\" .. addonName .. "\\"
local glowStyles = {
    herb = {
        color = { 0.30, 1.00, 0.35 },
        coreTexture = textureDirectory .. "HerbLeaf.tga",
        offset = -12,
    },
    ore = {
        color = { 0.36, 0.84, 1.00 },
        coreTexture = textureDirectory .. "OreCrystal.tga",
        offset = -12,
    },
    skinning = {
        color = { 1.00, 0.62, 0.17 },
        coreTexture = textureDirectory .. "SkinningHide.tga",
        offset = -24,
    },
}
-- WoW's built-in alert sounds. Corpses have no cue.
local gatheringChimes = {
    herb = 316447, -- Chime Ascending
    ore = 316528, -- Anvil Strike
}
local encounterGrace = 25
local chimeEncounters = {}

local interactSetting = "softTargetInteract"
local objectSetting = "SoftTargetIconGameObject"
local corpseSetting = "SoftTargetNameplateInteract"
local rangeSetting = "SoftTargetInteractRange"
local objectRangeSetting = "nameplateGameObjectMaxDistance"
local inRangeSetting = "SoftTargetInteractOnlyInRange"
local arcSetting = "SoftTargetInteractArc"
local requiredValues = {
    [interactSetting] = tostring(Enum.SoftTargetEnableFlags.Any),
    [objectSetting] = "1",
    [corpseSetting] = "1",
    [rangeSetting] = "60",
    [objectRangeSetting] = "60",
    [inRangeSetting] = "0",
    [arcSetting] = "2",
}
local minimumSettings = { [rangeSetting] = true, [objectRangeSetting] = true, [arcSetting] = true }
local legacyApplied = { [arcSetting] = 1, [rangeSetting] = 30 }

local events = CreateFrame("Frame")
local cursor = events:CreateTexture()
cursor:Hide()

local glow = CreateFrame("Frame", nil, UIParent)
glow:SetSize(72, 72)
glow:EnableMouse(false)
glow:Hide()

local halo = glow:CreateTexture(nil, "ARTWORK")
halo:SetAllPoints()
halo:SetTexture(flareTexture)
halo:SetBlendMode("ADD")

local center = glow:CreateTexture(nil, "OVERLAY", nil, 2)
center:SetPoint("CENTER")
center:SetSize(44, 44)
center:SetBlendMode("BLEND")
center:SetAlpha(0.9)

local pulse = halo:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(0.40)
fade:SetToAlpha(0.85)
fade:SetDuration(0.85)
fade:SetSmoothing("IN_OUT")

local flash = glow:CreateTexture(nil, "OVERLAY", nil, 1)
flash:SetPoint("CENTER")
flash:SetSize(84, 84)
flash:SetTexture(flareTexture)
flash:SetBlendMode("ADD")
flash:Hide()

local burst = flash:CreateAnimationGroup()
local burstFade = burst:CreateAnimation("Alpha")
burstFade:SetFromAlpha(1)
burstFade:SetToAlpha(0)
burstFade:SetDuration(0.28)
burst:SetScript("OnFinished", function() flash:Hide() end)

local enabled
local inWorld = true
local showingCorpsePlate
local activePlate, activeKind, activeInRange
local sessionSettings = {}

local function SavedSettings()
    if not addon.db then
        return sessionSettings
    end
    if type(addon.db.glowCVars) ~= "table" then
        addon.db.glowCVars = {}
    end
    return addon.db.glowCVars
end

local function OriginalSetting(name, saved, current)
    if type(saved) == "string" then
        -- Older releases stored only the original value.
        local oldApplied = legacyApplied[name] or tonumber(requiredValues[name])
        return current == oldApplied and saved or nil
    end
    if type(saved) == "table" and type(saved.original) == "string" and current == saved.applied then
        return saved.original
    end
end

local function ApplySetting(name)
    local desired = requiredValues[name]
    local current = C_CVar.GetCVar(name)
    local currentNumber = tonumber(current)
    local desiredNumber = tonumber(desired)
    if not currentNumber or currentNumber == desiredNumber then
        return
    end
    if minimumSettings[name] and currentNumber > desiredNumber then
        return
    end
    local settings = SavedSettings()
    local saved = settings[name]
    local original = OriginalSetting(name, saved, currentNumber)
    local change = { original = original or current, applied = desiredNumber }
    settings[name] = change
    C_CVar.SetCVar(name, desired)
    local applied = C_CVar.GetCVar(name)
    local appliedNumber = tonumber(applied)
    if appliedNumber and appliedNumber ~= currentNumber then
        -- The client may clamp the request. Restore against what it actually accepted.
        change.applied = appliedNumber
    else
        settings[name] = original and appliedNumber == currentNumber and saved or nil
    end
end

local function RestoreSetting(name)
    local settings = SavedSettings()
    local saved = settings[name]
    settings[name] = nil
    local current = C_CVar.GetCVar(name)
    local currentNumber = tonumber(current)
    local original = OriginalSetting(name, saved, currentNumber)
    if original then
        C_CVar.SetCVar(name, original)
        local restored = C_CVar.GetCVar(name)
        if tonumber(restored) == currentNumber then
            settings[name] = saved
        end
    end
end

local function RestoreSettings()
    RestoreSetting(corpseSetting)
    RestoreSetting(objectSetting)
    RestoreSetting(arcSetting)
    RestoreSetting(inRangeSetting)
    RestoreSetting(objectRangeSetting)
    RestoreSetting(rangeSetting)
    RestoreSetting(interactSetting)
    showingCorpsePlate = nil
end

local function IsKnownTrue(value)
    return not issecretvalue(value) and value == true
end

local function StopFlash()
    burst:Stop()
    flash:Hide()
end

local function UpdateGlowRange()
    local reportedRange = UnitIsInInteractRange(interactUnit)
    local inRange
    if issecretvalue(reportedRange) then
        -- Keep the last readable state so an opaque update cannot re-arm the flash.
        inRange = activeInRange or false
    else
        inRange = reportedRange == true
    end
    if activeInRange == inRange then
        return
    end

    activeInRange = inRange
    StopFlash()
    if inRange then
        pulse:Stop()
        halo:SetAlpha(0.9)
        flash:Show()
        burst:Play()
    else
        halo:SetAlpha(1)
        pulse:Play()
    end
end

local function CursorKind(name)
    if issecretvalue(name) or type(name) ~= "string" then
        return
    end
    name = string.lower(name)
    if name:find("herb", 1, true) then
        return "herb"
    elseif name:find("mine", 1, true) or name:find("mining", 1, true) then
        return "ore"
    elseif name:find("skin", 1, true) then
        return "skinning"
    end
end

local function GetInteractPlate()
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        if not plate:IsForbidden() then
            local unit = plate.GetUnit and plate:GetUnit() or plate.unitToken
            if not issecretvalue(unit) and unit and IsKnownTrue(UnitIsUnit(unit, interactUnit)) then
                return plate, unit
            end
        end
    end
end

local function GetKind(plate, unit)
    local unitFrame = plate.UnitFrame
    local icon = unitFrame and unitFrame.SoftTargetFrame and unitFrame.SoftTargetFrame.Icon
    if icon and not icon:IsForbidden() and icon:IsShown() then
        local kind = CursorKind(icon:GetAtlas()) or CursorKind(icon:GetTexture())
        if kind then
            return kind
        end
    end
    if IsKnownTrue(SetUnitCursorTexture(cursor, unit, nil, true, true)) then
        return CursorKind(cursor:GetAtlas()) or CursorKind(cursor:GetTexture())
    end
end

local function ClearGlow()
    if activePlate then
        activePlate, activeKind, activeInRange = nil, nil, nil
        StopFlash()
        pulse:Stop()
        glow:Hide()
        glow:ClearAllPoints()
        glow:SetParent(UIParent)
    end
end

local function UpdateGatheringChime(plate, kind, unit)
    local sound = gatheringChimes[kind]
    if not sound then
        return
    end

    local guid = UnitGUID(unit)
    if issecretvalue(guid) then
        guid = nil
    end
    local encounter = guid and chimeEncounters[guid]
    local previousPlate = chimeEncounters[plate]
    -- Reuse the record if the same plate toggles between readable and opaque
    -- identity, but never match two different readable GUIDs.
    if not encounter and previousPlate and previousPlate.kind == kind
        and (not guid or not previousPlate.guid) then
        encounter = previousPlate
    end

    local now = GetTime()
    if not encounter or now - encounter.lastSeen >= encounterGrace then
        for key, previous in pairs(chimeEncounters) do
            if now - previous.lastSeen >= encounterGrace then
                chimeEncounters[key] = nil
            end
        end
        encounter = { kind = kind }
    end
    encounter.lastSeen = now
    chimeEncounters[plate] = encounter
    if guid then
        encounter.guid = guid
        chimeEncounters[guid] = encounter
    end

    -- Combat delays the current cue. Nothing is queued for targets we lose.
    if not encounter.chimed and not InCombatLockdown() then
        encounter.chimed = true
        C_Sound.PlaySoundWithOptions({ soundKitID = sound })
    end
end

local function ShowGlow(plate, kind)
    if plate == activePlate and kind == activeKind then
        return
    end
    activePlate, activeKind, activeInRange = plate, kind, nil
    local style = glowStyles[kind]
    halo:SetVertexColor(unpack(style.color))
    center:SetTexture(style.coreTexture)
    glow:SetParent(plate)
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", plate, "BOTTOM", 0, style.offset)
    glow:Show()
end

function addon.RefreshGlow()
    if not enabled or not inWorld then
        return
    end

    local corpse = false
    if IsKnownTrue(UnitIsDead(interactUnit)) then
        local isPlayer = UnitIsPlayer(interactUnit)
        corpse = not issecretvalue(isPlayer) and isPlayer == false
    end

    if not InCombatLockdown() and corpse ~= showingCorpsePlate then
        -- The client needs this setting to expose a plate on the current corpse.
        -- Only ask for it while the Interact Key is pointing at one.
        showingCorpsePlate = corpse
        if corpse then
            ApplySetting(corpseSetting)
        else
            RestoreSetting(corpseSetting)
        end
    end

    local plate, unit = GetInteractPlate()
    if plate then
        local kind = GetKind(plate, unit)
        if (kind == "skinning" and corpse)
            or ((kind == "herb" or kind == "ore") and IsKnownTrue(UnitIsGameObject(unit))) then
            ShowGlow(plate, kind)
            UpdateGlowRange()
            UpdateGatheringChime(plate, kind, unit)
            return
        end
    end
    ClearGlow()
end

local setupPending
local function Configure()
    setupPending = InCombatLockdown()
    if setupPending then
        return
    end
    if enabled then
        -- Ask for earlier detection and WoW's widest targeting angle. The client still
        -- decides how far away each object can be picked as an interact target.
        ApplySetting(rangeSetting)
        ApplySetting(objectRangeSetting)
        ApplySetting(inRangeSetting)
        ApplySetting(arcSetting)
        ApplySetting(interactSetting)
        ApplySetting(objectSetting)
    else
        RestoreSettings()
    end
end

function addon.SetGlowEnabled(value)
    value = value == true
    if enabled == value then
        return
    end
    enabled = value
    Configure()

    if enabled then
        local elapsed = 0
        events:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed >= refreshInterval then
                elapsed = 0
                addon.RefreshGlow()
            end
        end)
        addon.RefreshGlow()
    else
        events:SetScript("OnUpdate", nil)
        chimeEncounters = {}
        ClearGlow()
    end
end

events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then
        if enabled ~= nil and not InCombatLockdown() then
            RestoreSettings()
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        inWorld = false
        chimeEncounters = {}
        ClearGlow()
    elseif event == "PLAYER_ENTERING_WORLD" then
        inWorld = true
        addon.RefreshGlow()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if setupPending then
            Configure()
        end
        addon.RefreshGlow()
    else
        ClearGlow()
    end
end)
