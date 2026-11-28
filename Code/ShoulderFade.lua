-- Out of combat, shows the controller's two shoulder icons (the targeting icons
-- at the top of its action bars) at their own opacity; in a fight they come back.
-- They are textures of the page unit (LeftShoulderBackground and the others below,
-- MainActionBarFrame.xml:18-49 in the game's Blizzard_GamepadActionBars). Alpha
-- on textures only: nothing protected is touched.
local _, Enhancer = ...

local ShoulderFade = {
    TEXTURE_KEYS = {
        "LeftShoulderBackground", "RightShoulderBackground",
        "LeftShoulderIcon", "RightShoulderIcon",
        "LeftShoulderHighlight", "RightShoulderHighlight",
    },
    originalAlphas = setmetatable({}, { __mode = "k" }),   -- texture -> its alpha before
}
Enhancer.ShoulderFade = ShoulderFade

function ShoulderFade.Textures()
    local textures = {}
    local root = _G.GamepadMainActionBarFrame
    local pageUnit = type(root) == "table" and root.PageUnit
    if type(pageUnit) ~= "table" or pageUnit:IsForbidden() then return textures end
    for _, key in ipairs(ShoulderFade.TEXTURE_KEYS) do
        if type(pageUnit[key]) == "table" then textures[#textures + 1] = pageUnit[key] end
    end
    return textures
end

-- The opacity out of combat, 0 to 1 (1 = the game's look).
function ShoulderFade.Opacity()
    return (tonumber(Enhancer.SavedSettings.Get().shoulderOpacity) or 100) / 100
end

function ShoulderFade.SetAlpha(alpha)
    for _, texture in ipairs(ShoulderFade.Textures()) do
        if ShoulderFade.originalAlphas[texture] == nil then ShoulderFade.originalAlphas[texture] = Enhancer.Fader.Target(texture) end
        Enhancer.Fader.To(texture, alpha)
    end
end

function ShoulderFade.Restore()
    for texture, alpha in pairs(ShoulderFade.originalAlphas) do Enhancer.Fader.To(texture, alpha) end
    ShoulderFade.originalAlphas = setmetatable({}, { __mode = "k" })
end

-- Faded out of combat when set below 100%, else as the game has them.
function ShoulderFade.Apply()
    if ShoulderFade.Opacity() < 1 and not InCombatLockdown() then
        ShoulderFade.SetAlpha(ShoulderFade.Opacity())
    else
        ShoulderFade.Restore()
    end
end
