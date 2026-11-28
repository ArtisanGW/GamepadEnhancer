-- Whether a trigger or bumper is held, as the game's controller bars see it
-- (GamepadMode in the game's Blizzard_Gamepad, HoldBindings.lua): the bar
-- switching modifiers (GAMEPADLEFTMOD, GAMEPADRIGHTMOD), one targeting modifier,
-- or both at once (the HUD modifier).
local _, Enhancer = ...

local TriggerOrBumper = {}
Enhancer.TriggerOrBumper = TriggerOrBumper

function TriggerOrBumper.IsHeld()
    local gamepadMode = _G.GamepadMode
    if type(gamepadMode) ~= "table" or not gamepadMode.IsHUDBindingModifierDown then return false end
    return gamepadMode.IsLeftModifierDown() or gamepadMode.IsRightModifierDown()
        or gamepadMode.IsTargetingModifierDown() or gamepadMode.IsHUDBindingModifierDown()
end
