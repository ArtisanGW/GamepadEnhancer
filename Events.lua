-- The addon's events: settings on load, the gap once the controller's bars exist,
-- and changes held back in combat after it.
local addonName, Enhancer = ...

local BARS_ADDON_NAME = "Blizzard_GamepadActionBars"
local eventFrame = CreateFrame("Frame")
local hookedRoot = false

-- Re-applies the gap when the controller's bars show (after a switch to the
-- controller UI) and after the game restyles a button (post-hooks only).
local function hookBarsRoot()
    local root = _G.GamepadMainActionBarFrame
    local styleUtility = _G.GamepadActionBarStyleUtil
    if hookedRoot or type(root) ~= "table" or root:IsForbidden() or type(styleUtility) ~= "table" then return end
    hookedRoot = true
    root:HookScript("OnShow", function() Enhancer.Gap.Apply() end)
    hooksecurefunc(styleUtility, "ApplyExtraButtonStyles", function(button) Enhancer.Gap.AfterGameRestyle(button) end)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == addonName then
            Enhancer.SavedSettings.Get()
            local succeeded, message = pcall(Enhancer.SettingsPage.Register)
            if not succeeded then geterrorhandler()(message) end
        end
        if name == addonName or name == BARS_ADDON_NAME then hookBarsRoot() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        hookBarsRoot()
        Enhancer.Gap.Apply()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Enhancer.CombatQueue.Flush()
    end
end)
