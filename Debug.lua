-- /gpe debug: in-game check (development builds only, left out of the release).
-- Out of combat, for 15 s, while the player presses bar buttons and LT/RT: every
-- shown button in a bar's half must sit at the game's place plus the gap.
-- The game's place is read again on each sample from the button's last restyle.
-- Ends with a Reload box; the findings go to GamepadEnhancerDebugDB.
--
-- Earlier finding (2026-11-24, kept in git history: the secure click-wrapper
-- probe): in combat 85% of the game's button moves come from LT/RT bar switching,
-- which no secure handler can follow, so the split is out of combat only.
local _, Enhancer = ...

local Debug = {
    SECONDS = 15,
    TEST_GAP = 100,     -- used when the saved gap is 0
    SAMPLE_EVERY = 0.1,
}
Enhancer.Debug = Debug

local results, running

local function record(name, passed, detail)
    results.checks[#results.checks + 1] = { name = name, passed = passed, detail = detail }
    print(string.format("|cff%s%s|r %s: %s", passed and "33ff33" or "ff3333", passed and "PASS" or "FAIL", name, tostring(detail)))
end

local function showReloadBox(text)
    local box = CreateFrame("Frame", "GamepadEnhancerDebugBox", UIParent)
    box:SetFrameStrata("DIALOG"); box:SetSize(420, 150); box:SetPoint("TOP", 0, -135); box:EnableMouse(true)
    CreateFrame("Frame", nil, box, "DialogBorderTemplate"):SetAllPoints()
    local message = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    message:SetPoint("TOP", 0, -22); message:SetWidth(370); message:SetText(text)
    local reload = CreateFrame("Button", "GamepadEnhancerDebugReload", box, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    reload:SetSize(150, 24); reload:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -6, 18); reload:SetText(RELOADUI or "Reload")
    reload:SetAttribute("type", "macro"); reload:SetAttribute("macrotext", "/reload")
    reload:RegisterForClicks("AnyUp", "AnyDown")
    local later = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    later:SetSize(150, 24); later:SetPoint("BOTTOMLEFT", box, "BOTTOM", 6, 18); later:SetText(LATER or "Later")
    later:SetScript("OnClick", function() box:Hide() end)
end

-- Split: the button is where Gap.lua last put it, with this gap's shift.
-- A button that isn't is recorded once, with what was found.
local function isSplit(button, gap)
    local moved = Enhancer.Gap.moved[button]
    local side = Enhancer.BarHalves.Side(button)
    local point, relativeTo, _, x = button:GetPoint(1)
    local split = moved and side and Enhancer.Gap.IsWhereWePutIt(button, x) and moved.shift == side * gap / 2
    if not split and not results.failures[button] then
        results.failures[button] = true
        local parent = button:GetParent()
        results.failureDetails[#results.failureDetails + 1] = string.format(
            "%s | type %s | side %s | point %s to %s | x %s | moved x %s shift %s | parent %s",
            tostring(button:GetName()), tostring(button:GetObjectType()), tostring(side), tostring(point),
            tostring(relativeTo and relativeTo.GetName and relativeTo:GetName()), tostring(x),
            tostring(moved and moved.x), tostring(moved and moved.shift), tostring(parent and parent:GetName()))
    end
    return split
end

function Debug.Start()
    if running then print("Gamepad Enhancer check: already running.") return end
    if InCombatLockdown() then print("Gamepad Enhancer check: start it out of combat.") return end
    _G.GamepadEnhancerDebugDB = { startedAt = date("%Y-%m-%d %H:%M:%S"), checks = {}, split = 0, unsplit = 0, combatSamples = 0,
        failureDetails = {} }
    results = _G.GamepadEnhancerDebugDB
    results.failures = setmetatable({}, { __mode = "k" })
    local settings = Enhancer.SavedSettings.Get()
    local savedGap = settings.gap
    local gap = (savedGap ~= 0) and savedGap or Debug.TEST_GAP
    settings.gap = gap
    Enhancer.Gap.Apply()
    local buttons = Enhancer.BarHalves.AllButtons()
    record("bar half buttons found", #buttons > 0, #buttons .. " buttons")

    running = CreateFrame("Frame")
    local timer = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timer:SetPoint("TOPLEFT", 20, -20)
    local deadline, sinceSample = GetTime() + Debug.SECONDS, 0
    running:SetScript("OnUpdate", function(_, elapsed)
        local left = deadline - GetTime()
        timer:SetText(string.format("GPE check: press bar buttons and LT/RT (%d s)", left + 1))
        sinceSample = sinceSample + elapsed
        if sinceSample >= Debug.SAMPLE_EVERY then
            sinceSample = 0
            if InCombatLockdown() then
                results.combatSamples = results.combatSamples + 1
            else
                for _, button in ipairs(buttons) do
                    if button:IsVisible() then
                        if isSplit(button, gap) then results.split = results.split + 1 else results.unsplit = results.unsplit + 1 end
                    end
                end
            end
        end
        if left <= 0 then
            running:SetScript("OnUpdate", nil)
            results.failures = nil   -- frames can't be saved
            timer:SetText("")
            settings.gap = savedGap
            Enhancer.Gap.Apply()
            record("buttons split out of combat", results.split > 0 and results.unsplit == 0,
                results.split .. " split / " .. results.unsplit .. " not split (gap " .. gap .. ")")
            if results.combatSamples > 0 then record("check stayed out of combat", false, results.combatSamples .. " samples in combat skipped") end
            local passed, failed = 0, 0
            for _, check in ipairs(results.checks) do if check.passed then passed = passed + 1 else failed = failed + 1 end end
            showReloadBox(string.format("Gamepad Enhancer check: %d passed, %d failed.\n\nReload to save the findings.", passed, failed))
        end
    end)
    print("Gamepad Enhancer check: press bar buttons and LT/RT for 15 s.")
end

function Debug.Command()
    Debug.Start()
end
