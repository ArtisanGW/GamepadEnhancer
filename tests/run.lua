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
    if line:match("%.lua%s*$") and not line:match("^#") then TOC_FILES[#TOC_FILES + 1] = line:match("^%s*(.-)%s*$") end
end

local game
local function boot(saved)
    game = { combat = false, errors = {} }
    _G.GamepadEnhancerDB = saved
    _G.InCombatLockdown = function() return game.combat end
    _G.geterrorhandler = function() return function(message) game.errors[#game.errors + 1] = message end end
    _G.CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(_, handler) self.onEvent = handler end
        game.eventFrame = frame
        return frame
    end
    _G.SlashCmdList = {}
    local addonTable = {}
    for _, fileName in ipairs(TOC_FILES) do assert(loadfile(fileName))("GamepadEnhancer", addonTable) end
    return addonTable
end
local function fire(event, ...) game.eventFrame.onEvent(game.eventFrame, event, ...) end

test("settings are created on load", function()
    boot(nil)
    fire("ADDON_LOADED", "GamepadEnhancer")
    expectEqual(_G.GamepadEnhancerDB.version, 1)
end)

test("a change asked for in combat runs when combat ends", function()
    local addon = boot(nil)
    local ran = 0
    game.combat = true
    expectEqual(addon.CombatQueue.Run("change", function() ran = ran + 1 end), false)
    expectEqual(ran, 0, "waits in combat")
    game.combat = false
    fire("PLAYER_REGEN_ENABLED")
    expectEqual(ran, 1, "ran after combat")
end)

test("an error in a waiting change goes to the error handler", function()
    local addon = boot(nil)
    game.combat = true
    addon.CombatQueue.Run("broken", function() error("boom") end)
    game.combat = false
    fire("PLAYER_REGEN_ENABLED")
    expectEqual(#game.errors, 1)
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
