-- /gpe (or /gamepadenhancer) opens the settings; /gpe reset puts the game's layout back;
-- /gpe debug runs the in-game probe (development builds).
local _, Enhancer = ...

SLASH_GAMEPADENHANCER1 = "/gpe"
SLASH_GAMEPADENHANCER2 = "/gamepadenhancer"
SlashCmdList.GAMEPADENHANCER = function(message)
    local command = tostring(message or ""):lower():match("^%s*(%S*)")
    if command == "debug" and Enhancer.Debug then return Enhancer.Debug.Command() end
    if command == "reset" then
        Enhancer.SavedSettings.Get().gap = Enhancer.SavedSettings.DEFAULTS.gap
        Enhancer.Gap.Apply()
        print("Gamepad Enhancer: back to the game's layout.")
        return
    end
    Enhancer.SettingsPage.Open()
end
