-- The settings page in Options > AddOns, with the game's Settings API.
local _, Enhancer = ...

local SettingsPage = {}
Enhancer.SettingsPage = SettingsPage

local function pixelsLabel(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if value == 0 then return "Off" end
    return value .. " px"
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

    local variableName = "GamepadEnhancer_gap"
    local setting = Settings.RegisterAddOnSetting(category, variableName, "gap", settings, Settings.VarType.Number,
        "Gap between halves", Enhancer.SavedSettings.DEFAULTS.gap)
    Settings.SetOnValueChangedCallback(variableName, function() Enhancer.Gap.Apply() end)
    Settings.CreateSlider(category, setting,
        sliderOptions(Enhancer.Gap.MINIMUM, Enhancer.Gap.MAXIMUM, Enhancer.Gap.STEP, pixelsLabel),
        "Moves each action bar's left and right buttons apart.\n\n"
        .. "The bar stays centered. Off is the game's own layout. "
        .. "In a fight the game puts the buttons back; the gap returns when it ends.")

    Settings.RegisterAddOnCategory(category)
end

function SettingsPage.Open()
    if SettingsPage.category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(SettingsPage.category:GetID())
    end
end
