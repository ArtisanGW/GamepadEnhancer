-- /gpe (or /gamepadenhancer) opens the settings; /gpe debug runs the in-game
-- check (development builds).
local _, Enhancer = ...

SLASH_GAMEPADENHANCER1 = "/gpe"
SLASH_GAMEPADENHANCER2 = "/gamepadenhancer"
SlashCmdList.GAMEPADENHANCER = function(message)
    local command, argument = tostring(message or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if command == "debug" and Enhancer.Debug then return Enhancer.Debug.Command(argument) end
    Enhancer.SettingsPage.Open()
end
