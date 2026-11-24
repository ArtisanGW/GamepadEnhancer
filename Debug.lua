-- /gpe debug: an in-game probe (development builds only, left out of the release).
-- It checks, on the real game, what splitting a controller bar's two halves needs:
--   1. the bar buttons are protected (no addon SetPoint in combat)
--   2. the game anchors each button to the whole bar, not to its half
--   3. a secure click wrapper (SecureHandlerWrapScript) keeps a button split
--      after presses, in combat too, without blocked actions, and spells still cast
-- Each test button's half moves 40 px outward. Fight something (a training dummy),
-- press bar buttons and LT/RT; the probe ends a few seconds after the fight and
-- offers a Reload, which saves the findings (GamepadEnhancerDebugDB) and puts the
-- game's buttons back.
local _, Enhancer = ...

local Debug = {
    SHIFT = 40,                -- px each half moves outward
    WAIT_FOR_COMBAT = 120,     -- seconds to start a fight
    AFTER_COMBAT = 3,          -- seconds after the fight before the results
    SAMPLE_EVERY = 0.1,        -- seconds between position samples in combat
}
Enhancer.Debug = Debug

local probe, results, testButtons, header

local function record(name, passed, detail)
    results.checks[#results.checks + 1] = { name = name, passed = passed, detail = detail }
    print(string.format("|cff%s%s|r %s: %s", passed and "33ff33" or "ff3333", passed and "PASS" or "FAIL", name, tostring(detail)))
end

-- The controller bars' buttons: every bar under the page unit with .Left/.Right halves.
local function collectButtons()
    local buttons = {}
    local pageUnit = Enhancer.SideBars.PageUnit()
    if not pageUnit then return buttons end
    local function visit(frame)
        if frame:IsForbidden() then return end
        local left, right = frame.Left, frame.Right
        if type(left) == "table" and type(right) == "table" and left.ActionButton1 and right.ActionButton1 then
            for i = 1, 4 do
                local leftButton, rightButton = left["ActionButton" .. i], right["ActionButton" .. i]
                if leftButton then buttons[#buttons + 1] = { button = leftButton, bar = frame, shift = -Debug.SHIFT } end
                if rightButton then buttons[#buttons + 1] = { button = rightButton, bar = frame, shift = Debug.SHIFT } end
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do visit(child) end
    end
    visit(pageUnit)
    return buttons
end

-- Out of combat only: moves the button by its shift from where the game put it.
local function shiftNow(entry)
    local button = entry.button
    if InCombatLockdown() then return end
    local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
    if not point or x == button:GetAttribute("gpe-lastx") then return end
    local newX = x + entry.shift
    button:ClearAllPoints()
    button:SetPoint(point, relativeTo, relativePoint, newX, y)
    button:SetAttribute("gpe-lastx", newX)
end

-- Runs in the restricted environment after each click: same move as shiftNow.
local POST_CLICK = [[
    local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
    owner:SetAttribute("gpe-runs", (owner:GetAttribute("gpe-runs") or 0) + 1)
    if not point then
        owner:SetAttribute("gpe-nopoint", (owner:GetAttribute("gpe-nopoint") or 0) + 1)
        return
    end
    if x == self:GetAttribute("gpe-lastx") then return end
    local newX = x + self:GetAttribute("gpe-shift")
    self:ClearAllPoints()
    self:SetPoint(point, relativeTo, relativePoint, newX, y)
    self:SetAttribute("gpe-lastx", newX)
    owner:SetAttribute("gpe-moves", (owner:GetAttribute("gpe-moves") or 0) + 1)
]]

local function staticChecks()
    local protectedCount, anchoredToBar, barsProtected, bars = 0, 0, 0, {}
    for _, entry in ipairs(testButtons) do
        if entry.button:IsProtected() then protectedCount = protectedCount + 1 end
        local _, relativeTo = entry.button:GetPoint(1)
        if relativeTo == entry.bar then anchoredToBar = anchoredToBar + 1 end
        if not bars[entry.bar] then
            bars[entry.bar] = true
            if entry.bar:IsProtected() then barsProtected = barsProtected + 1 end
        end
    end
    local barCount = 0
    for _ in pairs(bars) do barCount = barCount + 1 end
    record("bar buttons found", #testButtons > 0, #testButtons .. " buttons on " .. barCount .. " bars")
    record("buttons are protected", protectedCount == #testButtons, protectedCount .. "/" .. #testButtons)
    record("buttons anchored to the whole bar", anchoredToBar == #testButtons, anchoredToBar .. "/" .. #testButtons)
    record("bars are protected (needed to anchor to them in combat)", barsProtected == barCount, barsProtected .. "/" .. barCount)
end

local function installWrappers()
    header = CreateFrame("Frame", "GamepadEnhancerDebugHeader", UIParent, "SecureHandlerBaseTemplate")
    local wrapped, failures = 0, 0
    for _, entry in ipairs(testButtons) do
        entry.button:SetAttribute("gpe-shift", entry.shift)
        local succeeded = pcall(SecureHandlerWrapScript, entry.button, "OnClick", header, [[ return nil, "split" ]], POST_CLICK)
        if succeeded then wrapped = wrapped + 1 else failures = failures + 1 end
    end
    record("secure click wrappers installed", failures == 0, wrapped .. " wrapped, " .. failures .. " failed")
    -- Out of combat the game's own restyle is followed at once (a plain post-hook).
    if type(GamepadActionBarStyleUtil) ~= "table" then record("game's button styling found", false, "GamepadActionBarStyleUtil missing") return end
    hooksecurefunc(GamepadActionBarStyleUtil, "ApplyExtraButtonStyles", function(button)
        for _, entry in ipairs(testButtons) do
            if entry.button == button then shiftNow(entry) end
        end
    end)
    for _, entry in ipairs(testButtons) do shiftNow(entry) end
end

-- One sample: how many shown test buttons are still split.
local function sample()
    for _, entry in ipairs(testButtons) do
        if entry.button:IsVisible() then
            local x = select(4, entry.button:GetPoint(1))
            if x and x == entry.button:GetAttribute("gpe-lastx") then
                results.combatSplit = results.combatSplit + 1
            else
                results.combatUnsplit = results.combatUnsplit + 1
            end
        end
    end
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

local function finish(reason)
    probe:SetScript("OnUpdate", nil)
    probe:UnregisterAllEvents()
    probe.timer:SetText("")
    results.reason = reason
    results.wrapRuns = header and header:GetAttribute("gpe-runs") or 0
    results.wrapMoves = header and header:GetAttribute("gpe-moves") or 0
    results.wrapNoPoint = header and header:GetAttribute("gpe-nopoint") or 0
    if reason == "combat" then
        local total = results.combatSplit + results.combatUnsplit
        record("wrapper ran on clicks in combat", results.wrapRunsInCombat > 0, results.wrapRunsInCombat .. " runs")
        record("wrapper could read the anchor in combat", results.wrapNoPoint == 0, results.wrapNoPoint .. " runs without a point")
        record("buttons stayed split in combat", total > 0 and results.combatUnsplit == 0,
            results.combatSplit .. " split / " .. results.combatUnsplit .. " unsplit samples")
        record("no blocked actions", #results.blocked == 0, #results.blocked .. " blocked")
        record("spells still cast in combat", results.castsInCombat > 0, results.castsInCombat .. " casts")
    else
        record("a fight happened", false, "no combat within " .. Debug.WAIT_FOR_COMBAT .. " s")
    end
    local passed, failed = 0, 0
    for _, check in ipairs(results.checks) do if check.passed then passed = passed + 1 else failed = failed + 1 end end
    showReloadBox(string.format("Gamepad Enhancer probe: %d passed, %d failed.\n\nReload to save the findings and put the buttons back.", passed, failed))
end

function Debug.Start()
    if InCombatLockdown() then print("Gamepad Enhancer probe: start it out of combat.") return end
    if probe then print("Gamepad Enhancer probe: already ran; reload first.") return end
    _G.GamepadEnhancerDebugDB = { startedAt = date("%Y-%m-%d %H:%M:%S"), checks = {}, blocked = {},
        combatSplit = 0, combatUnsplit = 0, castsInCombat = 0, wrapRunsInCombat = 0 }
    results = _G.GamepadEnhancerDebugDB
    testButtons = collectButtons()
    staticChecks()
    if #testButtons == 0 then showReloadBox("Gamepad Enhancer probe: no controller bars found. Is the controller UI on?") return end
    installWrappers()

    probe = CreateFrame("Frame")
    probe.timer = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    probe.timer:SetPoint("TOPLEFT", 20, -20)
    local phase, deadline, sinceSample, runsAtCombatStart = "waiting", GetTime() + Debug.WAIT_FOR_COMBAT, 0, 0
    probe:RegisterEvent("PLAYER_REGEN_DISABLED")
    probe:RegisterEvent("PLAYER_REGEN_ENABLED")
    probe:RegisterEvent("ADDON_ACTION_BLOCKED")
    probe:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    probe:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    probe:SetScript("OnEvent", function(_, event, addonName, functionName)
        if event == "PLAYER_REGEN_DISABLED" and phase == "waiting" then
            phase = "combat"
            runsAtCombatStart = header:GetAttribute("gpe-runs") or 0
        elseif event == "PLAYER_REGEN_ENABLED" and phase == "combat" then
            results.wrapRunsInCombat = (header:GetAttribute("gpe-runs") or 0) - runsAtCombatStart
            phase, deadline = "after", GetTime() + Debug.AFTER_COMBAT
        elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
            results.blocked[#results.blocked + 1] = event .. " " .. tostring(addonName) .. " " .. tostring(functionName)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" and phase == "combat" then
            results.castsInCombat = results.castsInCombat + 1
        end
    end)
    probe:SetScript("OnUpdate", function(_, elapsed)
        if phase == "waiting" then
            local left = deadline - GetTime()
            probe.timer:SetText(string.format("GPE probe: start a fight, press bar buttons and LT/RT (%d s)", left))
            if left <= 0 then finish("no combat") end
        elseif phase == "combat" then
            probe.timer:SetText("GPE probe: fighting - press bar buttons and LT/RT, then end the fight")
            sinceSample = sinceSample + elapsed
            if sinceSample >= Debug.SAMPLE_EVERY then sinceSample = 0; sample() end
        elseif phase == "after" then
            local left = deadline - GetTime()
            probe.timer:SetText(string.format("GPE probe: done in %d s", left + 1))
            if left <= 0 then finish("combat") end
        end
    end)
    print("Gamepad Enhancer probe: each bar's halves are now 40 px apart. Fight something and press bar buttons and LT/RT.")
end

function Debug.Command()
    Debug.Start()
end
