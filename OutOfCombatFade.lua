-- Out of combat, hides the controller's action bar frame except its two shoulder
-- icons (the targeting icons at the top), or shows it faded while your target is
-- in range of one of its spells. In a fight it all comes back.
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

-- The opacity out of combat: the faded look in range of a spell, else hidden.
function OutOfCombatFade.TargetAlpha()
    if Enhancer.SpellRange.TargetInRange() then
        return (tonumber(Enhancer.SavedSettings.Get().fadedOpacity) or 0) / 100
    end
    return 0
end

-- Sets every part to alpha (out of combat only; the original alpha is kept to put back).
function OutOfCombatFade.SetAlpha(alpha)
    if InCombatLockdown() then return end
    OutOfCombatFade.currentAlpha = alpha
    for _, part in ipairs(OutOfCombatFade.Parts()) do
        if not part:IsForbidden() then
            if OutOfCombatFade.originalAlphas[part] == nil then OutOfCombatFade.originalAlphas[part] = Enhancer.Fader.Target(part) end
            Enhancer.Fader.To(part, alpha)
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
end

-- Hidden, faded or back, to match the setting, combat and range.
function OutOfCombatFade.Apply()
    if OutOfCombatFade.IsOn() and not InCombatLockdown() then
        OutOfCombatFade.SetAlpha(OutOfCombatFade.TargetAlpha())
    else
        OutOfCombatFade.Restore()
    end
end

-- Range changes as you move: checked a few times a second while it's on and
-- out of combat; only a change touches the frames.
local checker = CreateFrame("Frame")
local sinceCheck = 0
checker:SetScript("OnUpdate", function(_, elapsed)
    sinceCheck = sinceCheck + elapsed
    if sinceCheck < OutOfCombatFade.CHECK_EVERY then return end
    sinceCheck = 0
    if not OutOfCombatFade.IsOn() or InCombatLockdown() then return end
    if OutOfCombatFade.TargetAlpha() ~= OutOfCombatFade.currentAlpha then OutOfCombatFade.Apply() end
end)
