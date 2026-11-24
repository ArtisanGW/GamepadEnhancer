-- The addon's events: settings on load, and changes held back in combat after it.
local addonName, Enhancer = ...

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        Enhancer.SavedSettings.Get()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Enhancer.CombatQueue.Flush()
    end
end)
