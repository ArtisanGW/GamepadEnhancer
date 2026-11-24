-- Finds the controller's left and right action bars. The game's page unit
-- (GamepadActionBarPageUnitTemplate in Blizzard_GamepadActionBars) holds four
-- bars, each on its own plain anchor frame: Top, Bottom, and LeftCenteredAnchor /
-- RightCenteredAnchor at 195 px left and right of the center. Moving those two
-- anchor frames moves the whole left and right bars. The game moves them again
-- only in its RefreshCompactLayout (an Edit Mode option), which Events.lua hooks.
local _, Enhancer = ...

local SideBars = {
    ROOT_FRAME_NAME = "GamepadMainActionBarFrame",
    originalPoints = setmetatable({}, { __mode = "k" }),   -- anchor frame -> its points, as the game set them
}
Enhancer.SideBars = SideBars

-- The game's page unit, or nil while the controller's bars don't exist.
function SideBars.PageUnit()
    local root = _G[SideBars.ROOT_FRAME_NAME]
    local pageUnit = type(root) == "table" and root.PageUnit or nil
    if type(pageUnit) ~= "table" or pageUnit:IsForbidden() then return nil end
    return pageUnit
end

-- The compact layout stacks every bar in one place: there is no gap to widen.
function SideBars.UsesCompactLayout(pageUnit)
    return type(pageUnit.ShouldUseCompactLayout) == "function" and pageUnit:ShouldUseCompactLayout() == true
end

-- The left and right bars' anchor frames (nil when missing).
function SideBars.Anchors(pageUnit)
    return pageUnit.LeftCenteredAnchor, pageUnit.RightCenteredAnchor
end

-- The anchor frame's points as the game set them: from the game's own copy
-- (pageUnit.anchorPoints, read only) when it has one, else as they stand the
-- first time we see them.
function SideBars.OriginalPoints(pageUnit, anchor)
    local original = SideBars.originalPoints[anchor]
    if original then return original end
    original = {}
    local gamePoints = type(pageUnit.anchorPoints) == "table" and pageUnit.anchorPoints[anchor]
    if type(gamePoints) == "table" and #gamePoints > 0 then
        for i, point in ipairs(gamePoints) do
            original[i] = { point.point, point.relativeTo, point.relativePoint, point.x or 0, point.y or 0 }
        end
    else
        for i = 1, anchor:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = anchor:GetPoint(i)
            original[i] = { point, relativeTo, relativePoint, x or 0, y or 0 }
        end
    end
    SideBars.originalPoints[anchor] = original
    return original
end

-- Puts the anchor frame at its original points, moved sideways by shiftX pixels.
function SideBars.Place(pageUnit, anchor, shiftX)
    if type(anchor) ~= "table" or anchor:IsForbidden() then return end
    local original = SideBars.OriginalPoints(pageUnit, anchor)
    if #original == 0 then return end
    anchor:ClearAllPoints()
    for _, point in ipairs(original) do
        anchor:SetPoint(point[1], point[2], point[3], point[4] + shiftX, point[5])
    end
end
