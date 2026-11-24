-- The player's settings, kept in GamepadEnhancerDB (saved per account).
-- A missing value takes its default; defaults match the game's own layout.
local _, Enhancer = ...

local SavedSettings = {
    VERSION = 1,
    DEFAULTS = {
        hideOutOfCombat = false,   -- the game shows its bars all the time
        shoulderOpacity = 100,     -- % opacity of the shoulder icons out of combat (100 = the game's)
        fadedOpacity = 20,
        fadeSeconds = 0.3,         -- seconds a fade in or out takes         -- % opacity out of combat while a spell is in range
    },
}
Enhancer.SavedSettings = SavedSettings

-- The settings table, filled with defaults for anything missing.
function SavedSettings.Get()
    local settings = _G.GamepadEnhancerDB
    if type(settings) ~= "table" then
        settings = {}
        _G.GamepadEnhancerDB = settings
    end
    for key, value in pairs(SavedSettings.DEFAULTS) do
        if settings[key] == nil then settings[key] = value end
    end
    settings.version = SavedSettings.VERSION
    return settings
end
