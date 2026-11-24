-- /gpe debug: in-game check (development builds only, left out of the release).
-- Turns "Hide bars out of combat" on (faded look 40% unless set) and samples
-- what the player sees, in three states the player walks through:
--   hidden : out of combat, no target in range -> every part at alpha 0
--   faded  : out of combat, target in range     -> every part at the faded alpha
--   fight  : in combat                           -> every part back to its alpha
-- and that the two shoulder icons are at their own opacity out of combat (50%
-- unless set) and as the game had them in a fight, with no blocked actions. Ends once
-- each state has 20 samples (or after 3 minutes) with a Reload box; the findings
-- go to GamepadEnhancerDebugDB and the settings are put back.
local _, Enhancer = ...

local Debug = {
    SAMPLE_EVERY = 0.25,
    SAMPLES_NEEDED = 20,
    TIMEOUT = 180,
    TEST_OPACITY = 40,
    TEST_SHOULDER_OPACITY = 50,
    TOLERANCE = 0.01,
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

-- The shoulder icons: at the opacity this state needs (nil = shown as the game had them).
local function shouldersRight(wantedAlpha)
    local pageUnit = _G.GamepadMainActionBarFrame and _G.GamepadMainActionBarFrame.PageUnit
    if not pageUnit then return false end
    for _, key in ipairs({ "LeftShoulderBackground", "RightShoulderBackground" }) do
        local texture = pageUnit[key]
        if not (texture and texture:IsVisible() and pageUnit:GetEffectiveAlpha() > 0) then return false end
        local want = wantedAlpha or results.shoulderAlphasBefore[key]
        if math.abs(texture:GetAlpha() - want) > Debug.TOLERANCE then return false end
    end
    return true
end

-- One sample: the state, and whether every part has the alpha that state needs.
local function sample(opacity)
    if Enhancer.Fader.IsBusy() then return "fading" end
    if not InCombatLockdown() and Enhancer.OutOfCombatFade.TargetAlpha() ~= Enhancer.OutOfCombatFade.currentAlpha then
        return "changing"   -- the range check (every 0.2 s) hasn't caught up yet
    end
    local state, expected
    if InCombatLockdown() then
        state = "fight"
    elseif Enhancer.SpellRange.TargetInRange() then
        state, expected = "faded", opacity / 100
    else
        state, expected = "hidden", 0
    end
    local counts = results.states[state]
    local allRight = true
    for _, part in ipairs(Enhancer.OutOfCombatFade.Parts()) do
        local want = expected
        if state == "fight" then want = results.alphasBefore[part] or 1 end
        if math.abs(part:GetAlpha() - want) > Debug.TOLERANCE then
            allRight = false
            if #results.wrongDetails < 20 then
                results.wrongDetails[#results.wrongDetails + 1] = string.format("%s: %s alpha %.2f, wanted %.2f",
                    state, tostring(part.GetName and part:GetName() or part:GetObjectType()), part:GetAlpha(), want)
            end
        end
    end
    if allRight then counts.right = counts.right + 1 else counts.wrong = counts.wrong + 1 end
    if shouldersRight(state ~= "fight" and results.shoulderOpacity / 100 or nil) then counts.shouldersShown = counts.shouldersShown + 1 end
    return state
end

local function done()
    for _, counts in pairs(results.states) do
        if counts.right + counts.wrong < Debug.SAMPLES_NEEDED then return false end
    end
    return true
end

function Debug.Start()
    if running then print("Gamepad Enhancer check: already running.") return end
    if InCombatLockdown() then print("Gamepad Enhancer check: start it out of combat.") return end
    local function newCounts() return { right = 0, wrong = 0, shouldersShown = 0 } end
    _G.GamepadEnhancerDebugDB = { startedAt = date("%Y-%m-%d %H:%M:%S"), checks = {}, blocked = {}, wrongDetails = {},
        states = { hidden = newCounts(), faded = newCounts(), fight = newCounts() } }
    results = _G.GamepadEnhancerDebugDB
    local settings = Enhancer.SavedSettings.Get()
    local savedOn, savedOpacity, savedShoulder = settings.hideOutOfCombat, settings.fadedOpacity, settings.shoulderOpacity
    Enhancer.ShoulderFade.Restore()
    local pageUnit = _G.GamepadMainActionBarFrame.PageUnit
    results.shoulderAlphasBefore = {}
    for _, key in ipairs({ "LeftShoulderBackground", "RightShoulderBackground" }) do
        results.shoulderAlphasBefore[key] = pageUnit[key] and pageUnit[key]:GetAlpha() or 1
    end
    results.shoulderOpacity = (savedShoulder < 100) and savedShoulder or Debug.TEST_SHOULDER_OPACITY
    settings.shoulderOpacity = results.shoulderOpacity
    local opacity = (savedOpacity > 0) and savedOpacity or Debug.TEST_OPACITY
    -- Each part's alpha with the addon off: what a fight must bring back.
    Enhancer.OutOfCombatFade.Restore()
    results.alphasBefore = {}
    for _, part in ipairs(Enhancer.OutOfCombatFade.Parts()) do results.alphasBefore[part] = part:GetAlpha() end
    settings.hideOutOfCombat, settings.fadedOpacity = true, opacity
    Enhancer.OutOfCombatFade.Apply()
    Enhancer.ShoulderFade.Apply()
    record("shoulder icons found", #Enhancer.ShoulderFade.Textures() == 6, #Enhancer.ShoulderFade.Textures() .. " textures")
    record("parts found to fade", #Enhancer.OutOfCombatFade.Parts() > 0, #Enhancer.OutOfCombatFade.Parts() .. " parts")
    local rangeAnswers = 0
    for _, button in ipairs(Enhancer.BarHalves.AllButtons()) do
        if type(button.action) == "number" then rangeAnswers = rangeAnswers + 1 end
    end
    record("bar buttons with an action", rangeAnswers > 0, rangeAnswers .. " buttons")

    running = CreateFrame("Frame")
    running:RegisterEvent("ADDON_ACTION_BLOCKED")
    running:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    running:SetScript("OnEvent", function(_, event, addonName, functionName)
        results.blocked[#results.blocked + 1] = event .. " " .. tostring(addonName) .. " " .. tostring(functionName)
    end)
    local timer = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timer:SetPoint("TOPLEFT", 20, -20)
    local deadline, sinceSample = GetTime() + Debug.TIMEOUT, 0
    running:SetScript("OnUpdate", function(_, elapsed)
        sinceSample = sinceSample + elapsed
        if sinceSample < Debug.SAMPLE_EVERY then return end
        sinceSample = 0
        local state = sample(opacity)
        local need = {}
        for _, name in ipairs({ "hidden", "faded", "fight" }) do
            local counts = results.states[name]
            if counts.right + counts.wrong < Debug.SAMPLES_NEEDED then need[#need + 1] = name end
        end
        timer:SetText(string.format("GPE check (%d s): now %s; still needed: %s\nhidden = no target in range, faded = target in range, fight = in combat",
            deadline - GetTime(), state, table.concat(need, ", ")))
        if (done() and not InCombatLockdown()) or GetTime() > deadline then
            running:SetScript("OnUpdate", nil)
            running:UnregisterAllEvents()
            timer:SetText("")
            settings.hideOutOfCombat, settings.fadedOpacity, settings.shoulderOpacity = savedOn, savedOpacity, savedShoulder
            Enhancer.OutOfCombatFade.Apply()
            Enhancer.ShoulderFade.Apply()
            results.alphasBefore = nil   -- frames can't be saved
            for _, name in ipairs({ "hidden", "faded", "fight" }) do
                local counts = results.states[name]
                local total = counts.right + counts.wrong
                record(name .. ": every part at the right alpha", total > 0 and counts.wrong == 0, counts.right .. "/" .. total .. " samples")
                record(name .. ": shoulder icons at their opacity", total > 0 and counts.shouldersShown == total, counts.shouldersShown .. "/" .. total .. " samples")
            end
            record("no blocked actions", #results.blocked == 0, #results.blocked .. " blocked")
            local passed, failed = 0, 0
            for _, check in ipairs(results.checks) do if check.passed then passed = passed + 1 else failed = failed + 1 end end
            showReloadBox(string.format("Gamepad Enhancer check: %d passed, %d failed.\n\nReload to save the findings.", passed, failed))
        end
    end)
    print("Gamepad Enhancer check: walk through hidden, faded and fight (see the top left).")
end

-- /gpe debug lt: 60 s recording of every alpha change on the controller bars,
-- for "LT/RT hides the buttons". Each line: time, combat, then the alphas.
function Debug.RecordTriggers()
    if running then print("Gamepad Enhancer check: already running.") return end
    local root = _G.GamepadMainActionBarFrame
    _G.GamepadEnhancerDebugDB = { startedAt = date("%Y-%m-%d %H:%M:%S"), recording = {} }
    local recording = _G.GamepadEnhancerDebugDB.recording
    local settings = Enhancer.SavedSettings.Get()
    recording[1] = string.format("settings: hide %s, faded %s, shoulders %s, fade %s s",
        tostring(settings.hideOutOfCombat), tostring(settings.fadedOpacity), tostring(settings.shoulderOpacity), tostring(settings.fadeSeconds))
    local function snapshot()
        local lines = { InCombatLockdown() and "COMBAT" or "out",
            string.format("root %.2f page %.2f", root:GetEffectiveAlpha(), root.PageUnit:GetAlpha()) }
        for _, part in ipairs(Enhancer.OutOfCombatFade.Parts()) do
            local name = part.GetName and part:GetName() or "?"
            lines[#lines + 1] = string.format("%s %.2f%s", (name or "?"):gsub("GamepadMainActionBarFramePageUnit", ""),
                part:GetAlpha(), Enhancer.OutOfCombatFade.originalAlphas[part] and "*" or "")
        end
        local bars = {}
        for _, button in ipairs(Enhancer.BarHalves.AllButtons()) do
            local bar = button:GetParent() and button:GetParent():GetParent()
            if bar and not bars[bar] and bar:IsShown() then
                bars[bar] = true
                lines[#lines + 1] = string.format("%s eff %.2f", (bar:GetName() or "?"):gsub("GamepadMainActionBarFramePageUnit", ""), bar:GetEffectiveAlpha())
            end
        end
        lines[#lines + 1] = "fader " .. (Enhancer.Fader.IsBusy() and "busy" or "idle")
        return table.concat(lines, " | ")
    end
    running = CreateFrame("Frame")
    local timer = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timer:SetPoint("TOPLEFT", 20, -20)
    local started, sinceSample, last = GetTime(), 0, nil
    running:SetScript("OnUpdate", function(_, elapsed)
        sinceSample = sinceSample + elapsed
        if sinceSample < 0.1 then return end
        sinceSample = 0
        local now = snapshot()
        if now ~= last and #recording < 400 then
            recording[#recording + 1] = string.format("%.1f %s", GetTime() - started, now)
            last = now
        end
        local left = 60 - (GetTime() - started)
        timer:SetText(string.format("GPE recording (%d s): press LT and RT, in and out of combat", left))
        if left <= 0 then
            running:SetScript("OnUpdate", nil)
            timer:SetText("")
            showReloadBox("Gamepad Enhancer recording done.\n\nReload to save it.")
        end
    end)
end

function Debug.Command(argument)
    if argument == "lt" then return Debug.RecordTriggers() end
    Debug.Start()
end
