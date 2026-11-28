-- Out of combat, hides the controller's action bar frame except its two shoulder
-- icons (the targeting icons at the top), shows it faded while you have a target
-- (or hold a trigger or bumper, when that's on), and less faded while that target
-- is in range of one of its spells. In a fight it all comes back.
--
-- The shoulder icons are textures of the page unit itself (LeftShoulderBackground,
-- RightShoulderBackground and their icons, MainActionBarFrame.xml in the game's
-- Blizzard_GamepadActionBars), so fading the page unit's child frames and the
-- main frame's other parts leaves them shown. Alpha, not Hide(): the buttons keep
-- working and their bindings still fire. The page unit's own alpha is the game's
-- (PageUnit.lua:727) and isn't touched.
local _, Enhancer = ...

local OutOfCombatFade = {
    CHECK_EVERY = 0.2,   -- seconds between range checks out of combat
    originalAlphas = setmetatable({}, { __mode = "k" }),   -- faded part -> its alpha before
}
Enhancer.OutOfCombatFade = OutOfCombatFade

-- Every part to fade: the page unit's child frames, and the main frame's other
-- child frames and textures.
function OutOfCombatFade.Parts()
    local parts = {}
    local root = _G.GamepadMainActionBarFrame
    if type(root) ~= "table" or root:IsForbidden() then return parts end
    local pageUnit = root.PageUnit
    for _, child in ipairs({ root:GetChildren() }) do
        if child ~= pageUnit then parts[#parts + 1] = child end
    end
    for _, region in ipairs({ root:GetRegions() }) do parts[#parts + 1] = region end
    if type(pageUnit) == "table" and not pageUnit:IsForbidden() then
        for _, child in ipairs({ pageUnit:GetChildren() }) do parts[#parts + 1] = child end
    end
    return parts
end

function OutOfCombatFade.IsOn()
    return Enhancer.SavedSettings.Get().hideOutOfCombat == true
end

-- True while "Show on triggers" is on and a trigger or bumper is held.
function OutOfCombatFade.TriggerHeld()
    return Enhancer.SavedSettings.Get().showOnTriggers == true and Enhancer.TriggerOrBumper.IsHeld() == true
end

function OutOfCombatFade.TriggerFadeSeconds()
    return math.max(0, tonumber(Enhancer.SavedSettings.Get().triggerFadeSeconds) or 0)
end

-- The opacity out of combat: the "in range" look when a bar spell reaches the
-- target, the "with a target" look with one out of range or while a trigger is
-- held, else hidden.
function OutOfCombatFade.TargetAlpha()
    local settings = Enhancer.SavedSettings.Get()
    if Enhancer.SpellRange.TargetInRange() then return (tonumber(settings.inRangeOpacity) or 0) / 100 end
    if UnitExists("target") or OutOfCombatFade.TriggerHeld() then return (tonumber(settings.fadedOpacity) or 0) / 100 end
    return 0
end

-- Sets every part to alpha over duration (nil: the fade time), out of combat
-- only; the original alpha is kept to put back.
function OutOfCombatFade.SetAlpha(alpha, duration)
    if InCombatLockdown() then return end
    OutOfCombatFade.currentAlpha = alpha
    for _, part in ipairs(OutOfCombatFade.Parts()) do
        if not part:IsForbidden() then
            if OutOfCombatFade.originalAlphas[part] == nil then OutOfCombatFade.originalAlphas[part] = Enhancer.Fader.Target(part) end
            Enhancer.Fader.To(part, alpha, duration)
        end
    end
end

-- Puts every faded part back as it was.
function OutOfCombatFade.Restore()
    for part, alpha in pairs(OutOfCombatFade.originalAlphas) do
        if not part:IsForbidden() then Enhancer.Fader.To(part, alpha) end
    end
    OutOfCombatFade.originalAlphas = setmetatable({}, { __mode = "k" })
    OutOfCombatFade.currentAlpha = nil
    OutOfCombatFade.triggerWasHeld = nil
end

-- Hidden, faded or back, to match the setting, combat, range and triggers. A
-- trigger pulled or let go fades over the trigger fade time.
function OutOfCombatFade.Apply()
    if OutOfCombatFade.IsOn() and not InCombatLockdown() then
        local triggerHeld = OutOfCombatFade.TriggerHeld()
        local duration
        if OutOfCombatFade.triggerWasHeld ~= nil and triggerHeld ~= OutOfCombatFade.triggerWasHeld then
            duration = OutOfCombatFade.TriggerFadeSeconds()
        end
        OutOfCombatFade.triggerWasHeld = triggerHeld
        OutOfCombatFade.SetAlpha(OutOfCombatFade.TargetAlpha(), duration)
    else
        OutOfCombatFade.Restore()
    end
end

-- Applies the opacity again only if it changed, while it's on and out of combat.
function OutOfCombatFade.Update()
    if not OutOfCombatFade.IsOn() or InCombatLockdown() then return end
    if OutOfCombatFade.TargetAlpha() ~= OutOfCombatFade.currentAlpha
        or OutOfCombatFade.TriggerHeld() ~= OutOfCombatFade.triggerWasHeld then
        OutOfCombatFade.Apply()
    end
end

-- Range changes as you move: checked a few times a second.
local checker = CreateFrame("Frame")
local sinceCheck = 0
checker:SetScript("OnUpdate", function(_, elapsed)
    sinceCheck = sinceCheck + elapsed
    if sinceCheck < OutOfCombatFade.CHECK_EVERY then return end
    sinceCheck = 0
    OutOfCombatFade.Update()
end)
