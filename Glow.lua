local _, addon = ...

local interactUnit = "softinteract"
local refreshInterval = 0.15
local flareTexture = "Interface\\Cooldown\\star4"
local glowStyles = {
    herb = {
        color = { 0.30, 1.00, 0.35 },
        offset = -12,
    },
    ore = {
        color = { 0.36, 0.84, 1.00 },
        offset = -12,
    },
    skinning = {
        color = { 1.00, 0.62, 0.17 },
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
local activePlate, activeKind, activeInRange
local sessionSettings = {}
local corpsePlateWanted

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
    corpsePlateWanted = nil
    RestoreSetting(objectSetting)
    RestoreSetting(arcSetting)
    RestoreSetting(inRangeSetting)
    RestoreSetting(objectRangeSetting)
    RestoreSetting(rangeSetting)
    RestoreSetting(interactSetting)
end

local function IsKnownTrue(value)
    return not issecretvalue(value) and value == true
end

local cursorFileKinds = {}
local function RegisterCursorFile(fileID, kind)
    if not issecretvalue(fileID) and type(fileID) == "number" and fileID > 0 then
        cursorFileKinds[fileID] = kind
    end
end

-- Native cursor textures can expose a file ID even when no atlas name is readable.
local cursorNames = {
    GatherHerbs = "herb",
    Mine = "ore",
    Skin = "skinning",
    SkinAlliance = "skinning",
    SkinHorde = "skinning",
}
for name, kind in pairs(cursorNames) do
    for _, prefix in ipairs({ "", "Unable" }) do
        local cursorName = prefix .. name
        RegisterCursorFile(GetFileIDFromPath("Interface\\Cursor\\" .. cursorName .. ".blp"), kind)
        local atlasSuffix = cursorName:lower() .. "_32"
        for _, atlasPrefix in ipairs({ "cursor_", "crosshair_" }) do
            local info = C_Texture.GetAtlasInfo(atlasPrefix .. atlasSuffix)
            if info then
                RegisterCursorFile(info.file, kind)
            end
        end
    end
end

local function StopFlash()
    burst:Stop()
    flash:Hide()
end

local function UpdateGlowRange(unit)
    local reportedRange = UnitIsInInteractRange(unit)
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
    if issecretvalue(name) then
        return
    end
    if type(name) == "number" then
        return cursorFileKinds[name]
    end
    if type(name) ~= "string" then
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

local function ReadCursorKind(texture)
    return CursorKind(texture:GetAtlas()) or CursorKind(texture:GetTexture())
        or CursorKind(texture:GetTextureFileID())
end

local function GetAccessiblePlate(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if plate and not plate:IsForbidden() then
        return plate
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
    local plate = GetAccessiblePlate(interactUnit)
    if plate then
        return plate, interactUnit
    end
end

local function IsCorpse(unit)
    if IsKnownTrue(UnitIsDead(unit)) then
        local isPlayer = UnitIsPlayer(unit)
        return not issecretvalue(isPlayer) and isPlayer == false
    end
end

local function UpdateCorpsePlate(corpse)
    if corpsePlateWanted == corpse or InCombatLockdown() then
        return
    end
    if corpse then
        -- Request the corpse's plate before trying to find its frame.
        ApplySetting(corpseSetting)
    else
        RestoreSetting(corpseSetting)
        if SavedSettings()[corpseSetting] then
            return
        end
    end
    corpsePlateWanted = corpse
end

local function HasSkinnableTooltip(unit)
    local data = C_TooltipInfo.GetUnit(unit)
    if issecretvalue(data) or not data then
        return
    end
    local lines = data.lines
    if issecretvalue(lines) or not lines then
        return
    end
    for _, line in ipairs(lines) do
        if not issecretvalue(line) then
            local text = line.leftText
            if not issecretvalue(text) and type(text) == "string" then
                text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                if text == UNIT_SKINNABLE_LEATHER or text == UNIT_SKINNABLE then
                    local guid = UnitGUID(unit)
                    return issecretvalue(guid) or not guid or not IsKnownTrue(CanLootUnit(guid))
                end
            end
        end
    end
end

local function GetKind(plate, unit)
    local unitFrame = plate.UnitFrame
    local icon = unitFrame and unitFrame.SoftTargetFrame and unitFrame.SoftTargetFrame.Icon
    if icon and not icon:IsForbidden() and IsKnownTrue(icon:IsShown()) then
        local kind = ReadCursorKind(icon)
        if kind then
            return kind
        end
    end
    if IsKnownTrue(SetUnitCursorTexture(cursor, unit, nil, true)) then
        return ReadCursorKind(cursor)
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
    center:SetTexture(addon.GetIconTexture(kind))
    if plate == activePlate and kind == activeKind then
        return
    end
    activePlate, activeKind, activeInRange = plate, kind, nil
    local style = glowStyles[kind]
    halo:SetVertexColor(unpack(style.color))
    glow:SetParent(plate)
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", plate, "BOTTOM", 0, style.offset)
    glow:Show()
end

function addon.RefreshGlow()
    if not enabled or not inWorld then
        return
    end

    local corpse = IsCorpse(interactUnit) == true
    UpdateCorpsePlate(corpse)

    local plate, unit = GetInteractPlate()
    if plate then
        local kind = GetKind(plate, unit)
        if corpse and kind ~= "skinning" and HasSkinnableTooltip(unit) then
            kind = "skinning"
        end
        if (kind == "skinning" and corpse)
            or ((kind == "herb" or kind == "ore") and IsKnownTrue(UnitIsGameObject(unit))) then
            ShowGlow(plate, kind)
            UpdateGlowRange(interactUnit)
            UpdateGatheringChime(plate, kind, unit)
            return
        end
    end

    -- Use the selected corpse's own visible nameplate when soft targeting
    -- doesn't supply a gathering marker.
    if IsCorpse("target") then
        local targetPlate = GetAccessiblePlate("target")
        if targetPlate and HasSkinnableTooltip("target") then
            ShowGlow(targetPlate, "skinning")
            UpdateGlowRange("target")
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
        corpsePlateWanted = nil
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
        UpdateCorpsePlate(false)
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
        if enabled and inWorld then
            UpdateCorpsePlate(IsCorpse(interactUnit) == true)
        end
    end
end)
