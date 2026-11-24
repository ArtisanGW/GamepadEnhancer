-- Whether your target is in range of a spell on the controller's action bars:
-- the game's own range check for each bar button's action slot
-- (C_ActionBar.IsActionInRange, nil when there's no target to check).
local _, Enhancer = ...

local SpellRange = {}
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

local function actionInRange(action)
    if type(action) ~= "number" or not C_ActionBar or not C_ActionBar.IsActionInRange then return false end
    if isSpellWithoutRange(action) then return false end
    local succeeded, inRange = pcall(C_ActionBar.IsActionInRange, action, "target")
    return succeeded and inRange == true
end

-- True when a target exists and a button of a shown bar has an action that reaches it.
function SpellRange.TargetInRange()
    if not UnitExists("target") then return false end
    for _, button in ipairs(Enhancer.BarHalves.AllButtons()) do
        if button:IsVisible() and actionInRange(button.action) then return true end
    end
    return false
end
