-- Splits each controller action bar into its two halves: the left half's buttons
-- move left by half the gap and the right half's right by the other half, so the
-- bar stays centered. A gap of 0 is the game's own layout.
--
-- The game puts a button back in its place on every restyle (a press, LT/RT).
-- Out of combat a post-hook moves it out again at once. In combat the buttons are
-- protected and can't be moved by an addon (checked in game with /gpe debug), so
-- they stay where the game puts them until the fight ends.
local _, Enhancer = ...

local Gap = {
    MINIMUM = 0,
    MAXIMUM = 400,
    STEP = 2,
    moved = setmetatable({}, { __mode = "k" }),   -- button -> { x = x we set, shift = shift in it }
    -- The game stores anchor offsets as 32-bit floats: what GetPoint gives back
    -- differs from what was set by up to about 0.00002 (seen in game).
    SAME_X_TOLERANCE = 0.01,
}
Enhancer.Gap = Gap

-- Whether x is (still) where we put the button.
function Gap.IsWhereWePutIt(button, x)
    local moved = Gap.moved[button]
    return moved ~= nil and x ~= nil and math.abs(x - moved.x) < Gap.SAME_X_TOLERANCE
end

local function currentShift(button)
    local side = Enhancer.BarHalves.Side(button)
    if not side then return 0 end
    return side * (tonumber(Enhancer.SavedSettings.Get().gap) or 0) / 2
end

-- Moves one button by the gap, from the game's place for it.
function Gap.PlaceButton(button)
    if InCombatLockdown() or button:IsForbidden() then return end
    local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
    if not point then return end
    local moved = Gap.moved[button]
    local gameX = x
    if Gap.IsWhereWePutIt(button, x) then gameX = x - moved.shift end   -- still where we put it
    local shift = currentShift(button)
    if shift == 0 and not moved then return end   -- leave the game's frames untouched
    local newX = gameX + shift
    if newX ~= x then
        button:ClearAllPoints()
        button:SetPoint(point, relativeTo, relativePoint, newX, y)
    end
    Gap.moved[button] = (shift ~= 0) and { x = newX, shift = shift } or nil
end

local function placeAllButtons()
    for _, button in ipairs(Enhancer.BarHalves.AllButtons()) do Gap.PlaceButton(button) end
end

-- Applies the saved gap to every button now, or after combat.
function Gap.Apply()
    Enhancer.CombatQueue.Run("gap", placeAllButtons)
end

-- Post-hook on the game's restyle of one button (Events.lua).
function Gap.AfterGameRestyle(button)
    if Enhancer.BarHalves.Side(button) then
        if InCombatLockdown() then Enhancer.CombatQueue.Run("gap", placeAllButtons) else Gap.PlaceButton(button) end
    end
end
