-- The player's settings, kept in GamepadEnhancerDB (saved per account).
-- A missing value takes its default (the author's own settings).
local _, Enhancer = ...

local SavedSettings = {
    VERSION = 1,
    DEFAULTS = {
        hideOutOfCombat = true,    -- hide the bars out of combat
        shoulderOpacity = 60,      -- % opacity of the shoulder icons out of combat (100 = the game's)
        fadedOpacity = 40,         -- % opacity out of combat with a target out of range
        inRangeOpacity = 70,       -- % opacity out of combat with the target in range of a bar spell
        showOnTriggers = true,     -- a held trigger or bumper shows the bars
        triggerFadeSeconds = 0.1,  -- seconds the bars take to show or hide on a trigger or bumper
        triggerOpacity = 40,       -- % opacity out of combat while a trigger or bumper is held
        fadeSeconds = 2,           -- seconds a fade in or out takes
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
