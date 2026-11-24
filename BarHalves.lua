-- Finds the left and right halves of the controller's action bars. Each bar
-- (GamepadActionBarTemplate in the game's Blizzard_GamepadActionBars) has a
-- .Left and a .Right frame holding 4 buttons each. The game places its buttons
-- inside these halves on every press, but never moves the halves themselves, so
-- moving a half moves its buttons for good.
local _, Enhancer = ...

local BarHalves = {
    ROOT_FRAME_NAME = "GamepadMainActionBarFrame",
    originalPoints = setmetatable({}, { __mode = "k" }),   -- half -> its first anchor, as the game set it
}
Enhancer.BarHalves = BarHalves

local function isBarHalf(frame)
    return type(frame) == "table" and type(frame.ActionButton1) == "table"
end

local function isBar(frame)
    return isBarHalf(frame.Left) and isBarHalf(frame.Right)
end

local function collectBars(frame, bars)
    if frame:IsForbidden() then return end
    if isBar(frame) then bars[#bars + 1] = frame end
    for _, child in ipairs({ frame:GetChildren() }) do collectBars(child, bars) end
end

-- Every bar under the controller's main action bar frame (none while it doesn't exist).
function BarHalves.FindBars()
    local bars = {}
    local root = _G[BarHalves.ROOT_FRAME_NAME]
    if type(root) == "table" and root.GetChildren then collectBars(root, bars) end
    return bars
end

-- The half's anchor as the game set it, saved the first time we see it.
function BarHalves.OriginalPoint(half)
    local original = BarHalves.originalPoints[half]
    if not original then
        local point, relativeTo, relativePoint, x, y = half:GetPoint(1)
        original = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x or 0, y = y or 0 }
        BarHalves.originalPoints[half] = original
    end
    return original
end

-- Puts the half at its original anchor, moved sideways by shiftX pixels.
function BarHalves.PlaceHalf(half, shiftX)
    if half:IsForbidden() then return end
    local original = BarHalves.OriginalPoint(half)
    if not original.point then return end
    half:ClearAllPoints()
    half:SetPoint(original.point, original.relativeTo, original.relativePoint, original.x + shiftX, original.y)
end
