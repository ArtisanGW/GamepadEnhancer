-- The addon's events: settings on load, the fade out of combat (and on a
-- trigger or bumper), and changes held back in combat after it.
local addonName, Enhancer = ...

local eventFrame = CreateFrame("Frame")
local hookedRoot = false
local hookedModifiers = false

-- The fade again when the controller's bars show (after a switch to the controller UI).
local function hookBarsRoot()
    local root = _G.GamepadMainActionBarFrame
    if hookedRoot or type(root) ~= "table" or root:IsForbidden() then return end
    hookedRoot = true
    root:HookScript("OnShow", function()
        Enhancer.OutOfCombatFade.Apply()
        Enhancer.ShoulderFade.Apply()
    end)
end

-- The fade right away when a trigger or bumper is pressed or let go (post-hooks
-- on the game's handlers of those bindings, Blizzard_Gamepad's HoldBindings.lua).
local function hookModifiers()
    local gamepadMode = _G.GamepadMode
    if hookedModifiers or type(gamepadMode) ~= "table" or not gamepadMode.OnTargetModifierChanged then return end
    hookedModifiers = true
    local function update() Enhancer.OutOfCombatFade.Update() end
    hooksecurefunc(gamepadMode, "OnCrossBarModifierChanged", update)
    hooksecurefunc(gamepadMode, "OnTargetModifierChanged", update)
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
        hookModifiers()
    elseif event == "PLAYER_ENTERING_WORLD" then
        hookBarsRoot()
        hookModifiers()
        Enhancer.OutOfCombatFade.Apply()
        Enhancer.ShoulderFade.Apply()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- A fight starts: everything back (combat lockdown starts right after this event).
        Enhancer.OutOfCombatFade.Restore()
        Enhancer.ShoulderFade.Restore()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Enhancer.CombatQueue.Flush()
        Enhancer.OutOfCombatFade.Apply()
        Enhancer.ShoulderFade.Apply()
    end
end)
