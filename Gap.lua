-- Widens the gap between each bar's left and right buttons: the left half moves
-- left by half the gap and the right half moves right by the other half, so the
-- bar stays centered. A gap of 0 is the game's own layout.
local _, Enhancer = ...

local Gap = {
    MINIMUM = 0,
    MAXIMUM = 400,
    STEP = 2,
}
Enhancer.Gap = Gap

local function placeAllBars()
    local shiftX = (tonumber(Enhancer.SavedSettings.Get().gap) or 0) / 2
    -- Nothing moved yet and no gap asked for: leave the game's frames untouched.
    if shiftX == 0 and not Gap.moved then return end
    Gap.moved = shiftX ~= 0
    for _, bar in ipairs(Enhancer.BarHalves.FindBars()) do
        Enhancer.BarHalves.PlaceHalf(bar.Left, -shiftX)
        Enhancer.BarHalves.PlaceHalf(bar.Right, shiftX)
    end
end

-- Applies the saved gap now, or after combat.
function Gap.Apply()
    Enhancer.CombatQueue.Run("gap", placeAllBars)
end
