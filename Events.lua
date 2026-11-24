-- The addon's events: settings on load, the fade out of combat, and changes
-- held back in combat after it.
local addonName, Enhancer = ...

local eventFrame = CreateFrame("Frame")
local hookedRoot = false

-- The fade again when the controller's bars show (after a switch to the controller UI).
local function hookBarsRoot()
    local root = _G.GamepadMainActionBarFrame
    if hookedRoot or type(root) ~= "table" or root:IsForbidden() then return end
    hookedRoot = true
    root:HookScript("OnShow", function() Enhancer.OutOfCombatFade.Apply() end)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == addonName then
            Enhancer.SavedSettings.Get()
            local succeeded, message = pcall(Enhancer.SettingsPage.Register)
            if not succeeded then geterrorhandler()(message) end
        end
        hookBarsRoot()
    elseif event == "PLAYER_ENTERING_WORLD" then
        hookBarsRoot()
        Enhancer.OutOfCombatFade.Apply()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- A fight starts: everything back (combat lockdown starts right after this event).
        Enhancer.OutOfCombatFade.Restore()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Enhancer.CombatQueue.Flush()
        Enhancer.OutOfCombatFade.Apply()
    end
end)
