-- Moves a part's alpha to a new value over the fade time the player set
-- (0 = at once). One driver frame runs only while something is fading.
-- SetAlpha is allowed in combat, so a fade-in at the start of a fight runs too.
local _, Enhancer = ...

local Fader = {
    fades = setmetatable({}, { __mode = "k" }),   -- part -> { from, to, elapsed, duration }
}
Enhancer.Fader = Fader

local driver = CreateFrame("Frame")
driver:Hide()

function Fader.Duration()
    return math.max(0, tonumber(Enhancer.SavedSettings.Get().fadeSeconds) or 0)
end

-- The alpha a part is heading to (its alpha now when it isn't fading).
function Fader.Target(part)
    local fade = Fader.fades[part]
    if fade then return fade.to end
    return part:GetAlpha()
end

function Fader.IsBusy()
    return next(Fader.fades) ~= nil
end

function Fader.To(part, alpha)
    local duration = Fader.Duration()
    if duration <= 0 then
        Fader.fades[part] = nil
        part:SetAlpha(alpha)
        return
    end
    if Fader.Target(part) == alpha then return end
    Fader.fades[part] = { from = part:GetAlpha(), to = alpha, elapsed = 0, duration = duration }
    driver:Show()
end

driver:SetScript("OnUpdate", function(_, elapsed)
    for part, fade in pairs(Fader.fades) do
        fade.elapsed = fade.elapsed + elapsed
        local progress = math.min(1, fade.elapsed / fade.duration)
        if not part:IsForbidden() then part:SetAlpha(fade.from + (fade.to - fade.from) * progress) end
        if progress >= 1 then Fader.fades[part] = nil end
    end
    if not Fader.IsBusy() then driver:Hide() end
end)
