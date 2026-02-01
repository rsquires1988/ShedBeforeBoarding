-- ShedBeforeBoarding
-- No fur allowed in the cabin! Adds a button to cancel shapeshift forms at flight masters.

local addonName = "ShedBeforeBoarding"
local frame = CreateFrame("Frame", addonName .. "Frame")

-- Classes that can have shapeshift forms that block flight paths
local formClasses = {
    ["DRUID"] = true,
    ["SHAMAN"] = true,
}

-- Check if player's class has forms
local function HasForms()
    local _, class = UnitClass("player")
    return formClasses[class]
end

-- Create a dark overlay to grey out the map
local overlay = CreateFrame("Frame", addonName .. "Overlay", UIParent)
overlay:Hide()

overlay.texture = overlay:CreateTexture(nil, "OVERLAY")
overlay.texture:SetAllPoints()
overlay.texture:SetColorTexture(0, 0, 0, 0.7)

-- Create the cancel form button with proper secure setup
local cancelButton = CreateFrame("Button", addonName .. "CancelButton", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
cancelButton:SetSize(140, 32)
cancelButton:SetText("Cancel Form")
cancelButton:RegisterForClicks("AnyUp", "AnyDown")
cancelButton:Hide()

-- Form spell names by class and index
-- These are forms that actually block flight path usage
local formSpellNames = {
    -- Druid forms
    ["Bear Form"] = true,
    ["Dire Bear Form"] = true,
    ["Aquatic Form"] = true,
    ["Cat Form"] = true,
    ["Travel Form"] = true,
    ["Moonkin Form"] = true,
    ["Tree of Life"] = true,
    ["Flight Form"] = true,
    ["Swift Flight Form"] = true,
    -- Shaman forms
    ["Ghost Wolf"] = true,
}

-- Index to spell name mapping (covers all classes)
local formIndexToSpell = {
    -- Druid (these indices are typical but may vary)
    [1] = "Bear Form",
    [2] = "Aquatic Form",
    [3] = "Cat Form",
    [4] = "Travel Form",
    [5] = "Moonkin Form",
    [6] = "Tree of Life",
    [27] = "Swift Flight Form",
    [29] = "Flight Form",
    [31] = "Dire Bear Form",
}

-- Get form spell name - try multiple methods
local function GetFormSpellName()
    local formIndex = GetShapeshiftForm()
    if not formIndex or formIndex == 0 then
        return nil
    end
    
    -- Method 1: Try GetShapeshiftFormInfo (works for Shaman/Priest)
    local icon, name = GetShapeshiftFormInfo(formIndex)
    if name and type(name) == "string" and name ~= "" and formSpellNames[name] then
        return name
    end
    
    -- Method 2: Use lookup table (mainly for Druid)
    local spellName = formIndexToSpell[formIndex]
    if spellName then
        return spellName
    end
    
    -- Method 3: For Shaman with single form
    local _, class = UnitClass("player")
    if class == "SHAMAN" then
        return "Ghost Wolf"
    end
    
    -- Unknown form
    print("|cFFFF0000[" .. addonName .. "]|r Unknown form index: " .. formIndex .. " - please report!")
    return nil
end

-- Update button visibility and spell attribute based on shapeshift status
local function UpdateButtonVisibility()
    if TaxiFrame and TaxiFrame:IsShown() and GetShapeshiftForm() > 0 and not InCombatLockdown() then
        -- Get current form spell name and set it
        local spellName = GetFormSpellName()
        
        -- Clear previous attributes first
        cancelButton:SetAttribute("type", nil)
        cancelButton:SetAttribute("spell", nil)
        cancelButton:SetAttribute("macrotext", nil)
        
        if spellName and type(spellName) == "string" then
            cancelButton:SetAttribute("type", "spell")
            cancelButton:SetAttribute("spell", spellName)
        else
            -- If we can't get the spell name, use macro as fallback
            cancelButton:SetAttribute("type", "macro")
            cancelButton:SetAttribute("macrotext", "/cancelform")
        end
        
        -- Position overlay - use TaxiRouteMap if it exists (the actual map texture area)
        local mapFrame = TaxiRouteMap or TaxiFrame
        overlay:SetParent(mapFrame)
        overlay:SetAllPoints(mapFrame)
        overlay:SetFrameStrata("TOOLTIP")
        overlay:Show()
        
        -- Position button in the center
        cancelButton:ClearAllPoints()
        cancelButton:SetPoint("CENTER", mapFrame, "CENTER", 0, 0)
        cancelButton:SetFrameStrata("TOOLTIP")
        cancelButton:SetFrameLevel(overlay:GetFrameLevel() + 10)
        cancelButton:Show()
    else
        if not InCombatLockdown() then
            overlay:Hide()
            cancelButton:Hide()
        end
    end
end

-- Hide button and overlay after clicking
cancelButton:HookScript("PostClick", function()
    if not InCombatLockdown() then
        C_Timer.After(0.1, function()
            overlay:Hide()
            cancelButton:Hide()
        end)
    end
end)

-- Handle events
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("TAXIMAP_OPENED")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if not HasForms() then
            self:UnregisterAllEvents()
            return
        end
        
        -- Hook TaxiFrame hide to hide our button
        if TaxiFrame then
            TaxiFrame:HookScript("OnHide", function()
                if not InCombatLockdown() then
                    overlay:Hide()
                    cancelButton:Hide()
                end
            end)
        end
        
        print("|cFF00FF00" .. addonName .. "|r loaded")
    elseif event == "TAXIMAP_OPENED" or event == "UPDATE_SHAPESHIFT_FORM" then
        UpdateButtonVisibility()
    end
end)
