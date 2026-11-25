-- /gpen debug: in-game check (development builds only, left out of the release).
-- Turns "Hide bars out of combat" on (With a target 40%, In range 70%, unless
-- set) and samples what the player sees, in four states the player walks through:
--   hidden   : out of combat, no target          -> every part at alpha 0
--   target   : out of combat, target out of range -> every part at "With a target"
--   in range : out of combat, a bar spell reaches  -> every part at "In range"
--   fight    : in combat                           -> every part back to its alpha
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
    TEST_IN_RANGE_OPACITY = 70,
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
        if not (texture and texture:IsVisible() and pageUnit:GetEffectiveAlpha() > 0) then
            if #results.wrongDetails < 40 then
                results.wrongDetails[#results.wrongDetails + 1] = string.format("shoulder %s: not visible (shown %s, page unit alpha %.2f)",
                    key, tostring(texture and texture:IsShown()), pageUnit:GetEffectiveAlpha())
            end
            return false
        end
        local want = wantedAlpha or results.shoulderAlphasBefore[key]
        if math.abs(texture:GetAlpha() - want) > Debug.TOLERANCE then
            if #results.wrongDetails < 40 then
                results.wrongDetails[#results.wrongDetails + 1] = string.format("shoulder %s: alpha %.2f, wanted %.2f, shown %s, fade heads to %.2f",
                    key, texture:GetAlpha(), want, tostring(texture:IsShown()), Enhancer.Fader.Target(texture))
            end
            return false
        end
    end
    return true
end

-- One sample: the state, and whether every part has the alpha that state needs.
local function sample(opacity)
    if Enhancer.Fader.IsBusy() then return "fading" end
    if Enhancer.OutOfCombatFade.TriggerHeld() then return "trigger" end   -- not one of the four states
    if not InCombatLockdown() and Enhancer.OutOfCombatFade.TargetAlpha() ~= Enhancer.OutOfCombatFade.currentAlpha then
        return "changing"   -- the range check (every 0.2 s) hasn't caught up yet
    end
    local state, expected
    if InCombatLockdown() then
        state = "fight"
    elseif not UnitExists("target") then
        state, expected = "hidden", 0
    elseif Enhancer.SpellRange.TargetInRange() then
        state, expected = "in range", opacity.inRange / 100
    else
        state, expected = "target", opacity.target / 100
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
    local previous = type(_G.GamepadEnhancerDebugDB) == "table" and _G.GamepadEnhancerDebugDB or {}
    _G.GamepadEnhancerDebugDB = { recording = previous.recording, startedAt = date("%Y-%m-%d %H:%M:%S"), checks = {}, blocked = {}, wrongDetails = {},
        states = { hidden = newCounts(), target = newCounts(), ["in range"] = newCounts(), fight = newCounts() } }
    results = _G.GamepadEnhancerDebugDB
    local settings = Enhancer.SavedSettings.Get()
    local savedOn, savedOpacity, savedInRange, savedShoulder = settings.hideOutOfCombat, settings.fadedOpacity, settings.inRangeOpacity, settings.shoulderOpacity
    Enhancer.ShoulderFade.Restore()
    local pageUnit = _G.GamepadMainActionBarFrame.PageUnit
    results.shoulderAlphasBefore = {}
    for _, key in ipairs({ "LeftShoulderBackground", "RightShoulderBackground" }) do
        results.shoulderAlphasBefore[key] = pageUnit[key] and Enhancer.Fader.Target(pageUnit[key]) or 1
    end
    results.shoulderOpacity = (savedShoulder < 100) and savedShoulder or Debug.TEST_SHOULDER_OPACITY
    settings.shoulderOpacity = results.shoulderOpacity
    local opacity = {
        target = (savedOpacity > 0) and savedOpacity or Debug.TEST_OPACITY,
        inRange = (savedInRange > 0) and savedInRange or Debug.TEST_IN_RANGE_OPACITY,
    }
    -- Each part's alpha with the addon off: what a fight must bring back.
    Enhancer.OutOfCombatFade.Restore()
    results.alphasBefore = {}
    for _, part in ipairs(Enhancer.OutOfCombatFade.Parts()) do results.alphasBefore[part] = Enhancer.Fader.Target(part) end
    settings.hideOutOfCombat, settings.fadedOpacity, settings.inRangeOpacity = true, opacity.target, opacity.inRange
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
        for _, name in ipairs({ "hidden", "target", "in range", "fight" }) do
            local counts = results.states[name]
            if counts.right + counts.wrong < Debug.SAMPLES_NEEDED then need[#need + 1] = name end
        end
        timer:SetText(string.format("GPE check (%d s): now %s; still needed: %s\nhidden = no target, target = out of range, in range = a bar spell reaches it, fight = in combat",
            deadline - GetTime(), state, table.concat(need, ", ")))
        if (done() and not InCombatLockdown()) or GetTime() > deadline then
            running:SetScript("OnUpdate", nil)
            running:UnregisterAllEvents()
            timer:SetText("")
            settings.hideOutOfCombat, settings.fadedOpacity, settings.inRangeOpacity, settings.shoulderOpacity = savedOn, savedOpacity, savedInRange, savedShoulder
            Enhancer.OutOfCombatFade.Apply()
            Enhancer.ShoulderFade.Apply()
            results.alphasBefore = nil   -- frames can't be saved
            for _, name in ipairs({ "hidden", "target", "in range", "fight" }) do
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
    print("Gamepad Enhancer check: walk through hidden, target, in range and fight (see the top left).")
end

-- /gpen debug lt: 60 s recording of every alpha change on the controller bars,
-- for "LT/RT hides the buttons". Each line: time, combat, then the alphas.
function Debug.RecordTriggers()
    if running then print("Gamepad Enhancer check: already running.") return end
    local root = _G.GamepadMainActionBarFrame
    if type(_G.GamepadEnhancerDebugDB) ~= "table" then _G.GamepadEnhancerDebugDB = {} end
    _G.GamepadEnhancerDebugDB.recording = {}
    local recording = _G.GamepadEnhancerDebugDB.recording
    local settings = Enhancer.SavedSettings.Get()
    recording[1] = string.format("settings: hide %s, with a target %s, in range %s, shoulders %s, fade %s s, triggers %s, trigger fade %s s, trigger opacity %s",
        tostring(settings.hideOutOfCombat), tostring(settings.fadedOpacity), tostring(settings.inRangeOpacity), tostring(settings.shoulderOpacity), tostring(settings.fadeSeconds),
        tostring(settings.showOnTriggers), tostring(settings.triggerFadeSeconds), tostring(settings.triggerOpacity))
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

-- /gpen debug range: 30 s log of the game's range answers for each shown bar
-- spell (for "Maul makes In range wrong"): asked / from the range event / has a
-- range. A line only when something changed.
function Debug.RecordRange()
    if running then print("Gamepad Enhancer check: already running.") return end
    if type(_G.GamepadEnhancerDebugDB) ~= "table" then _G.GamepadEnhancerDebugDB = {} end
    local log = {}
    _G.GamepadEnhancerDebugDB.rangeLog = log
    local function spellName(spellID)
        if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
        return tostring(spellID)
    end
    local function snapshot()
        local parts = { UnitExists("target") and ("target " .. tostring(UnitName("target"))) or "no target",
            "within 10 yd " .. tostring(Enhancer.SpellRange.TargetNear()),
            "addon says " .. (Enhancer.SpellRange.TargetInRange() and "IN RANGE" or "out") }
        for _, button in ipairs(Enhancer.BarHalves.AllButtons()) do
            if button:IsVisible() and type(button.action) == "number" then
                local actionType, id = GetActionInfo(button.action)
                if actionType then
                    local inRange = tostring(C_ActionBar.IsActionInRange(button.action, "target"))
                        .. "/ev:" .. tostring(Enhancer.SpellRange.inRangeBySlot[button.action] == true)
                    local hasRange = "-"
                    if actionType == "spell" and C_Spell and C_Spell.SpellHasRange then
                        hasRange = tostring(C_Spell.SpellHasRange(id))
                        local spellInRange = C_Spell.IsSpellInRange and C_Spell.IsSpellInRange(id, "target")
                        local info = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
                        hasRange = string.format("%s/sp:%s/yd:%s-%s", hasRange, tostring(spellInRange),
                            tostring(info and info.minRange), tostring(info and info.maxRange))
                    end
                    parts[#parts + 1] = string.format("%s=%s/r:%s", actionType == "spell" and (tostring(spellName(id)) .. "#" .. tostring(id)) or actionType .. tostring(id),
                        tostring(inRange), hasRange)
                end
            end
        end
        return table.concat(parts, " | ")
    end
    running = CreateFrame("Frame")
    local timer = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timer:SetPoint("TOPLEFT", 20, -20)
    local started, sinceSample, last = GetTime(), 0, nil
    running:SetScript("OnUpdate", function(_, elapsed)
        sinceSample = sinceSample + elapsed
        if sinceSample < 0.25 then return end
        sinceSample = 0
        local now = snapshot()
        if now ~= last and #log < 300 then
            log[#log + 1] = string.format("%.1f %s", GetTime() - started, now)
            last = now
        end
        local left = 30 - (GetTime() - started)
        timer:SetText(string.format("GPE range log (%d s): in bear form, target a mob far away, then walk up to it", left))
        if left <= 0 then
            running:SetScript("OnUpdate", nil)
            running = nil
            timer:SetText("")
            showReloadBox("Gamepad Enhancer range log done.\n\nReload to save it.")
        end
    end)
end

function Debug.Command(argument)
    if argument == "lt" then return Debug.RecordTriggers() end
    if argument == "range" then return Debug.RecordRange() end
    Debug.Start()
end
