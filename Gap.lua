-- Widens the gap between the controller's left and right action bars: the left
-- bar moves left by half the gap and the right bar right by the other half, so
-- the layout stays centered. A gap of 0 is the game's own layout.
local _, Enhancer = ...

local Gap = {
    MINIMUM = 0,
    MAXIMUM = 400,
    STEP = 2,
}
Enhancer.Gap = Gap

local function placeSideBars()
    local SideBars = Enhancer.SideBars
    local pageUnit = SideBars.PageUnit()
    if not pageUnit or SideBars.UsesCompactLayout(pageUnit) then return end
    local shiftX = (tonumber(Enhancer.SavedSettings.Get().gap) or 0) / 2
    -- Nothing moved yet and no gap asked for: leave the game's frames untouched.
    if shiftX == 0 and not Gap.moved then return end
    Gap.moved = shiftX ~= 0
    local leftAnchor, rightAnchor = SideBars.Anchors(pageUnit)
    SideBars.Place(pageUnit, leftAnchor, -shiftX)
    SideBars.Place(pageUnit, rightAnchor, shiftX)
end

-- Applies the saved gap now, or after combat.
function Gap.Apply()
    Enhancer.CombatQueue.Run("gap", placeSideBars)
end

-- After the game lays its bars out again (compact layout on or off), its own
-- places are back: the gap has to be put on again, even if it's 0.
function Gap.AfterGameLayout()
    Gap.moved = true
    Gap.Apply()
end
