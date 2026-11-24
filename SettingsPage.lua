-- The settings page in Options > AddOns, with the game's Settings API.
local _, Enhancer = ...

local SettingsPage = {}
Enhancer.SettingsPage = SettingsPage

local function percentLabel(value)
    return math.floor((tonumber(value) or 0) + 0.5) .. "%"
end

local function sliderOptions(minimum, maximum, step, formatLabel)
    local options = Settings.CreateSliderOptions(minimum, maximum, step)
    local rightLabel = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
        and MinimalSliderWithSteppersMixin.Label.Right
    if rightLabel and options.SetLabelFormatter then options:SetLabelFormatter(rightLabel, formatLabel) end
    return options
end

function SettingsPage.Register()
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
    local settings = Enhancer.SavedSettings.Get()
    local category = Settings.RegisterVerticalLayoutCategory("Gamepad Enhancer")
    SettingsPage.category = category

    local variableName = "GamepadEnhancer_hideOutOfCombat"
    local setting = Settings.RegisterAddOnSetting(category, variableName, "hideOutOfCombat", settings,
        Settings.VarType.Boolean, "Hide bars out of combat", Enhancer.SavedSettings.DEFAULTS.hideOutOfCombat)
    Settings.SetOnValueChangedCallback(variableName, function() Enhancer.OutOfCombatFade.Apply() end)
    Settings.CreateCheckbox(category, setting,
        "Hides the controller's action bars when you're not fighting.\n\n"
        .. "The two shoulder icons stay. The bars show faded while your target is in range of one of their spells, "
        .. "and come back fully when a fight starts.")

    local opacityName = "GamepadEnhancer_fadedOpacity"
    local opacitySetting = Settings.RegisterAddOnSetting(category, opacityName, "fadedOpacity", settings,
        Settings.VarType.Number, "Faded look", Enhancer.SavedSettings.DEFAULTS.fadedOpacity)
    Settings.SetOnValueChangedCallback(opacityName, function() Enhancer.OutOfCombatFade.Apply() end)
    Settings.CreateSlider(category, opacitySetting, sliderOptions(0, 100, 1, percentLabel),
        "How visible the bars are out of combat while your target is in range.\n\n"
        .. "0% keeps them hidden.")

    Settings.RegisterAddOnCategory(category)
end

function SettingsPage.Open()
    if SettingsPage.category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(SettingsPage.category:GetID())
    end
end
