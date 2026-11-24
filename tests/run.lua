-- GamepadEnhancer against a small fake game. From GamepadEnhancer:  luajit tests/run.lua
local print = print
local failed, passed = 0, 0
local function test(name, testBody)
    local succeeded, message = xpcall(testBody, debug.traceback)
    if succeeded then passed = passed + 1 else failed = failed + 1; print("FAIL " .. name .. "\n" .. message) end
end
local function expectEqual(actual, expected, message)
    if actual ~= expected then error((message or "") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local TOC_FILES = {}
for line in io.lines("GamepadEnhancer.toc") do
    if line:match("%.lua%s*$") and not line:match("^#") and not line:match("Debug%.lua") then
        TOC_FILES[#TOC_FILES + 1] = line:match("^%s*(.-)%s*$")
    end
end

local game
local function newFrame(parent)
    local frame = { parent = parent, children = {}, regions = {}, alpha = 1, events = {}, scripts = {} }
    if parent then parent.children[#parent.children + 1] = frame end
    function frame:GetParent() return self.parent end
    function frame:GetChildren() return unpack(self.children) end
    function frame:GetRegions() return unpack(self.regions) end
    function frame:IsForbidden() return false end
    function frame:IsVisible() return true end
    function frame:GetAlpha() return self.alpha end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:GetNumPoints() return 1 end
    function frame:GetPoint() return "CENTER", self.parent, "CENTER", 0, 0 end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(script, handler) self.scripts[script] = handler end
    function frame:HookScript(script, handler) self.scripts[script] = handler end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    return frame
end

local function boot(saved)
    saved = saved or {}
    if saved.fadeSeconds == nil then saved.fadeSeconds = 0 end   -- at once, unless a test fades
    game = { combat = false, errors = {}, frames = {}, target = false, inRange = {} }
    _G.GamepadEnhancerDB = saved
    _G.InCombatLockdown = function() return game.combat end
    _G.geterrorhandler = function() return function(message) game.errors[#game.errors + 1] = message end end
    _G.UnitExists = function() return game.target end
    _G.CreateFrame = function() local frame = newFrame(nil); game.frames[#game.frames + 1] = frame; return frame end
    _G.SlashCmdList = {}
    _G.Settings = nil
    -- The controller's bars: the main frame with a decoration, the page unit
    -- (holding the shoulder textures) and one bar with a left and right half.
    local root = newFrame(nil)
    root.regions[1] = newFrame(nil)
    local pageUnit = newFrame(root)
    pageUnit.LeftShoulderBackground = newFrame(nil)
    pageUnit.regions[1] = pageUnit.LeftShoulderBackground
    root.PageUnit = pageUnit
    local bar = newFrame(pageUnit)
    bar.Left, bar.Right = newFrame(bar), newFrame(bar)
    local button = newFrame(bar.Left); button.action = 1; bar.Left.ActionButton1 = button
    _G.GamepadMainActionBarFrame = root
    game.root, game.pageUnit, game.bar, game.decoration = root, pageUnit, bar, root.regions[1]
    local addonTable = {}
    for _, fileName in ipairs(TOC_FILES) do assert(loadfile(fileName))("GamepadEnhancer", addonTable) end
    game.eventFrame = game.frames[#game.frames]
    game.fadeDriver = game.frames[1]
    return addonTable
end
local function fire(event, ...) game.eventFrame.scripts.OnEvent(game.eventFrame, event, ...) end
-- The game's range event for action slot 1 (sent to every frame that listens).
local function rangeEvent(isInRange)
    for _, frame in ipairs(game.frames) do
        if frame.events.ACTION_RANGE_CHECK_UPDATE then frame.scripts.OnEvent(frame, "ACTION_RANGE_CHECK_UPDATE", 1, isInRange, true) end
    end
end

test("off by default: nothing faded", function()
    boot(nil)
    fire("ADDON_LOADED", "GamepadEnhancer"); fire("PLAYER_ENTERING_WORLD")
    expectEqual(game.bar.alpha, 1); expectEqual(game.decoration.alpha, 1)
end)

test("on: hidden out of combat, shoulder icons stay", function()
    boot({ hideOutOfCombat = true })
    fire("ADDON_LOADED", "GamepadEnhancer"); fire("PLAYER_ENTERING_WORLD")
    expectEqual(game.bar.alpha, 0, "bar"); expectEqual(game.decoration.alpha, 0, "decoration")
    expectEqual(game.pageUnit.alpha, 1, "page unit"); expectEqual(game.pageUnit.LeftShoulderBackground.alpha, 1, "shoulder")
end)

test("a target: 20%; in range of a bar spell: 50% (defaults)", function()
    local addon = boot({ hideOutOfCombat = true })
    fire("ADDON_LOADED", "GamepadEnhancer")
    game.target = true
    addon.OutOfCombatFade.Apply()
    expectEqual(game.bar.alpha, 0.2, "target out of range")
    rangeEvent(true)
    addon.OutOfCombatFade.Apply()
    expectEqual(game.bar.alpha, 0.5, "in range")
    rangeEvent(false)
    addon.OutOfCombatFade.Apply()
    expectEqual(game.bar.alpha, 0.2, "out of range again")
    game.target = false
    addon.OutOfCombatFade.Apply()
    expectEqual(game.bar.alpha, 0, "no target")
end)

test("a fight brings everything back, its end hides it again", function()
    boot({ hideOutOfCombat = true })
    fire("ADDON_LOADED", "GamepadEnhancer"); fire("PLAYER_ENTERING_WORLD")
    fire("PLAYER_REGEN_DISABLED"); game.combat = true
    expectEqual(game.bar.alpha, 1, "in combat")
    game.combat = false; fire("PLAYER_REGEN_ENABLED")
    expectEqual(game.bar.alpha, 0, "after combat")
end)

test("turning it off puts the game's alpha back", function()
    local addon = boot({ hideOutOfCombat = true })
    game.decoration.alpha = 0.7
    fire("ADDON_LOADED", "GamepadEnhancer"); fire("PLAYER_ENTERING_WORLD")
    _G.GamepadEnhancerDB.hideOutOfCombat = false
    addon.OutOfCombatFade.Apply()
    expectEqual(game.decoration.alpha, 0.7)
end)

test("shoulder icons: own opacity out of combat, full in a fight", function()
    boot({ shoulderOpacity = 30 })
    fire("ADDON_LOADED", "GamepadEnhancer"); fire("PLAYER_ENTERING_WORLD")
    local shoulder = game.pageUnit.LeftShoulderBackground
    expectEqual(shoulder.alpha, 0.3, "out of combat")
    expectEqual(game.bar.alpha, 1, "rest of the bars untouched")
    fire("PLAYER_REGEN_DISABLED"); game.combat = true
    expectEqual(shoulder.alpha, 1, "in combat")
    game.combat = false; fire("PLAYER_REGEN_ENABLED")
    expectEqual(shoulder.alpha, 0.3, "after combat")
end)

test("shoulder icons at 100%: left as the game has them", function()
    boot(nil)
    game.pageUnit.LeftShoulderBackground.alpha = 0.9
    fire("ADDON_LOADED", "GamepadEnhancer"); fire("PLAYER_ENTERING_WORLD")
    expectEqual(game.pageUnit.LeftShoulderBackground.alpha, 0.9)
end)

test("a spell with no range (a form) doesn't count as in range", function()
    local addon = boot({ hideOutOfCombat = true })
    _G.GetActionInfo = function() return "spell", 5487 end
    _G.C_Spell = { SpellHasRange = function() return false end }
    fire("ADDON_LOADED", "GamepadEnhancer")
    game.target = true
    rangeEvent(true)
    addon.OutOfCombatFade.Apply()
    expectEqual(game.bar.alpha, 0.2, "the 'with a target' look, not 'in range'")
    _G.GetActionInfo, _G.C_Spell = nil, nil
end)

test("fade time: alpha moves over the time set", function()
    boot({ hideOutOfCombat = true, fadeSeconds = 1 })
    fire("ADDON_LOADED", "GamepadEnhancer"); fire("PLAYER_ENTERING_WORLD")
    local tick = function(seconds) game.fadeDriver.scripts.OnUpdate(game.fadeDriver, seconds) end
    expectEqual(game.bar.alpha, 1, "starts where it was")
    tick(0.5); expectEqual(game.bar.alpha, 0.5, "halfway")
    tick(0.5); expectEqual(game.bar.alpha, 0, "done")
    expectEqual(game.fadeDriver.shown, false, "driver stops")
    fire("PLAYER_REGEN_DISABLED"); game.combat = true
    tick(0.25); expectEqual(game.bar.alpha, 0.25, "fades in during a fight")
    tick(1); expectEqual(game.bar.alpha, 1, "fully back")
end)

test("a change asked for in combat runs when combat ends; errors go to the handler", function()
    local addon = boot(nil)
    local ran = 0
    game.combat = true
    addon.CombatQueue.Run("change", function() ran = ran + 1 end)
    addon.CombatQueue.Run("broken", function() error("boom") end)
    expectEqual(ran, 0, "waits in combat")
    game.combat = false; fire("PLAYER_REGEN_ENABLED")
    expectEqual(ran, 1); expectEqual(#game.errors, 1)
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
