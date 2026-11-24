-- Whether your target is in range of a spell on the controller's action bars.
-- Read from the game's range event (ACTION_RANGE_CHECK_UPDATE), the same signal
-- behind the red range dots on the buttons; the game turns the check on for
-- every shown bar button (ActionButton.lua:403). Asking C_ActionBar.IsActionInRange
-- directly said Maul was in range from any distance (seen in game, 2026-11-24).
local _, Enhancer = ...

local SpellRange = {
    inRangeBySlot = {},   -- action slot -> true while the game says the target is in range
}
Enhancer.SpellRange = SpellRange

-- Spells with no range (forms like Bear Form, self buffs) count as in range at
-- any distance, so they don't say anything about the target: skipped.
local function isSpellWithoutRange(action)
    if not (GetActionInfo and C_Spell and C_Spell.SpellHasRange) then return false end
    local actionType, spellID = GetActionInfo(action)
    if actionType ~= "spell" or not spellID then return false end
    local succeeded, hasRange = pcall(C_Spell.SpellHasRange, spellID)
    return succeeded and hasRange == false
end

-- What the range event last said for this action slot.
function SpellRange.SlotInRange(action)
    return type(action) == "number" and SpellRange.inRangeBySlot[action] == true and not isSpellWithoutRange(action)
end

-- True when a target exists and a button of a shown bar has an action that reaches it.
function SpellRange.TargetInRange()
    if not UnitExists("target") then return false end
    for _, button in ipairs(Enhancer.BarHalves.AllButtons()) do
        if button:IsVisible() and SpellRange.SlotInRange(button.action) then return true end
    end
    return false
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("ACTION_RANGE_CHECK_UPDATE")
listener:RegisterEvent("PLAYER_TARGET_CHANGED")
listener:SetScript("OnEvent", function(_, event, slot, isInRange, checksRange)
    if event == "PLAYER_TARGET_CHANGED" then
        SpellRange.inRangeBySlot = {}   -- the game sends fresh answers for the new target
    elseif type(slot) == "number" then
        SpellRange.inRangeBySlot[slot] = (checksRange and isInRange) and true or nil
    end
end)
