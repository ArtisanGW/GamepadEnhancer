-- Which half of a controller action bar a button is on. Each bar
-- (GamepadActionBarTemplate in the game's Blizzard_GamepadActionBars) has a
-- .Left and a .Right frame holding its buttons; the game places every button
-- against the center of the whole bar (ActionBarStyles.lua:221), each time it
-- restyles it: on a press, and when LT/RT switch the active bar.
local _, Enhancer = ...

local BarHalves = {
    LEFT = -1,
    RIGHT = 1,
    sides = setmetatable({}, { __mode = "k" }),   -- button -> LEFT, RIGHT or false
}
Enhancer.BarHalves = BarHalves

-- LEFT, RIGHT, or nil for a button that isn't in a bar's half.
function BarHalves.Side(button)
    local side = BarHalves.sides[button]
    if side == nil then
        side = false
        local half = button:GetParent()
        local bar = half and half:GetParent()
        if bar and not bar:IsForbidden() then
            if bar.Left == half then side = BarHalves.LEFT elseif bar.Right == half then side = BarHalves.RIGHT end
        end
        BarHalves.sides[button] = side
    end
    return side or nil
end

-- Every button in the halves of the bars under the controller's main action bar frame.
function BarHalves.AllButtons()
    local buttons = {}
    local function visit(frame)
        if frame:IsForbidden() then return end
        for _, half in ipairs({ frame.Left, frame.Right }) do
            if type(half) == "table" and half.ActionButton1 then
                for _, child in ipairs({ half:GetChildren() }) do
                    if BarHalves.Side(child) and child.GetPoint and child:GetNumPoints() > 0 then buttons[#buttons + 1] = child end
                end
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do visit(child) end
    end
    local root = _G.GamepadMainActionBarFrame
    if type(root) == "table" and root.GetChildren then visit(root) end
    return buttons
end
