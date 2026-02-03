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

-- Create "Waiting for GCD" text on the overlay
overlay.waitingText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
overlay.waitingText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
overlay.waitingText:SetText("Waiting for GCD...")
overlay.waitingText:Hide()

-- Create the cancel form button with proper secure setup
local cancelButton = CreateFrame("Button", addonName .. "CancelButton", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
cancelButton:SetSize(140, 32)
cancelButton:SetText("Cancel Form")
cancelButton:RegisterForClicks("AnyUp")
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

-- Index to spell name mapping by class
local formIndexToSpellByClass = {
    ["DRUID"] = {
        [1] = "Bear Form",
        [2] = "Aquatic Form",
        [3] = "Cat Form",
        [4] = "Travel Form",
        [5] = "Moonkin Form",
        [6] = "Tree of Life",
        [27] = "Swift Flight Form",
        [29] = "Flight Form",
        [31] = "Dire Bear Form",
    },
    ["SHAMAN"] = {
        [1] = "Ghost Wolf",
    },
}

-- Get form spell name for current class and form index
local function GetFormSpellName()
    local formIndex = GetShapeshiftForm()
    if not formIndex or formIndex == 0 then
        return nil
    end
    
    local _, class = UnitClass("player")
    local classTable = formIndexToSpellByClass[class]
    
    if classTable and classTable[formIndex] then
        return classTable[formIndex]
    end
    
    -- Fallback: try GetShapeshiftFormInfo
    local icon, name = GetShapeshiftFormInfo(formIndex)
    if name and type(name) == "string" and name ~= "" and formSpellNames[name] then
        return name
    end
    
    -- Unknown form
    print("|cFFFF0000[ShedBeforeBoarding]|r Unknown form index: " .. formIndex .. " for class: " .. class .. " - please report!")
    return nil
end

-- Get current shapeshift form index (returns nil if not in a form)
local function GetCurrentFormIndex()
    local formIndex = GetShapeshiftForm()
    if not formIndex or formIndex == 0 then
        return nil
    end
    return formIndex
end

-- Flag to prevent immediate re-show after clicking button
local waitingForFormDrop = false

-- Flag to prevent duplicate processing
local pendingUpdate = false

-- Check if we're currently in a shapeshift form
local function IsInForm()
    return GetCurrentFormIndex() ~= nil
end

-- Update button visibility and spell attribute based on shapeshift status
-- waitForGCD: if true, show "Waiting for GCD..." before the button
local function UpdateButtonVisibility(waitForGCD)
    -- Skip if we just clicked the button and form hasn't dropped yet
    if waitingForFormDrop then
        if not IsInForm() then
            -- Form dropped, reset flag
            waitingForFormDrop = false
        else
            return
        end
    end
    
    -- Prevent duplicate rapid calls
    if pendingUpdate then
        return
    end
    
    if TaxiFrame and TaxiFrame:IsShown() and GetCurrentFormIndex() and not InCombatLockdown() then
        -- Mark as pending to prevent duplicate calls
        pendingUpdate = true
        
        -- Get current form spell name and set it
        local spellName = GetFormSpellName()
        
        -- Clear previous attributes first
        cancelButton:SetAttribute("type", nil)
        cancelButton:SetAttribute("spell", nil)
        cancelButton:SetAttribute("macrotext", nil)
        
        if spellName then
            -- Cast the same form spell to toggle it off
            cancelButton:SetAttribute("type", "spell")
            cancelButton:SetAttribute("spell", spellName)
        else
            -- Hide button if we can't determine the form
            pendingUpdate = false
            return
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
        
        if waitForGCD then
            -- Show waiting text while GCD is active
            overlay.waitingText:Show()
            
            -- Wait for GCD (1.5 seconds) before showing the button
            C_Timer.After(1.5, function()
                pendingUpdate = false
                if TaxiFrame and TaxiFrame:IsShown() and IsInForm() and not InCombatLockdown() then
                    overlay.waitingText:Hide()
                    cancelButton:Show()
                else
                    -- Conditions changed, hide everything
                    if not InCombatLockdown() then
                        overlay.waitingText:Hide()
                        overlay:Hide()
                        cancelButton:Hide()
                    end
                end
            end)
        else
            -- No GCD wait needed, show button immediately
            pendingUpdate = false
            cancelButton:Show()
        end
    else
        pendingUpdate = false
        if not InCombatLockdown() then
            overlay.waitingText:Hide()
            overlay:Hide()
            cancelButton:Hide()
        end
    end
end

-- Hide button and overlay after clicking
cancelButton:HookScript("PostClick", function()
    if not InCombatLockdown() then
        waitingForFormDrop = true
        C_Timer.After(0.1, function()
            overlay.waitingText:Hide()
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
                waitingForFormDrop = false
                pendingUpdate = false
                if not InCombatLockdown() then
                    overlay.waitingText:Hide()
                    overlay:Hide()
                    cancelButton:Hide()
                end
            end)
        end
        
        print("|cFF00FF00" .. addonName .. "|r loaded")
    elseif event == "TAXIMAP_OPENED" then
        -- Opening map while already in form - no GCD wait needed
        UpdateButtonVisibility(false)
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        if TaxiFrame and TaxiFrame:IsShown() then
            if not IsInForm() then
                -- Player dropped form (manually or otherwise) - hide UI
                waitingForFormDrop = false
                pendingUpdate = false
                if not InCombatLockdown() then
                    overlay.waitingText:Hide()
                    overlay:Hide()
                    cancelButton:Hide()
                end
            elseif not cancelButton:IsShown() and not pendingUpdate then
                -- Shifted into form while map is open - need to wait for GCD
                -- But only if the button isn't already visible (avoid duplicate GCD waits)
                UpdateButtonVisibility(true)
            end
        end
    end
end)
