-- GamepadEnhancer against a small fake game: frames with anchors, combat, events.
-- From GamepadEnhancer:  luajit tests/run.lua
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
local function newFrame(parent)
    local frame = { children = {}, points = {}, setPointCalls = 0, scripts = {}, events = {} }
    function frame:GetChildren() return unpack(self.children) end
    function frame:IsForbidden() return false end
    function frame:GetPoint(index) local point = self.points[index or 1]; if point then return unpack(point, 1, 5) end end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.setPointCalls = self.setPointCalls + 1; self.points[#self.points + 1] = { ... } end
    function frame:HookScript(scriptName, handler) self.scripts[scriptName] = handler end
    function frame:SetScript(scriptName, handler) self.scripts[scriptName] = handler end
    function frame:RegisterEvent(event) self.events[event] = true end
    if parent then parent.children[#parent.children + 1] = frame end
    game.frames[#game.frames + 1] = frame
    return frame
end

-- A bar like GamepadActionBarTemplate: .Left anchored LEFT, .Right anchored RIGHT.
local function newBar(parent)
    local bar = newFrame(parent)
    bar.Left = newFrame(bar); bar.Left.ActionButton1 = newFrame(bar.Left); bar.Left:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.Right = newFrame(bar); bar.Right.ActionButton1 = newFrame(bar.Right); bar.Right:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    bar.Left.setPointCalls, bar.Right.setPointCalls = 0, 0
    return bar
end

local function boot(saved)
    game = { frames = {}, combat = false, errors = {} }
    _G.GamepadEnhancerDB = saved
    _G.InCombatLockdown = function() return game.combat end
    _G.geterrorhandler = function() return function(message) game.errors[#game.errors + 1] = message end end
    _G.CreateFrame = function() return newFrame(nil) end
    _G.Settings = nil
    _G.SlashCmdList = {}
    local root = newFrame(nil)
    local pageUnit = newFrame(root)
    game.topBar, game.bottomBar = newBar(pageUnit), newBar(pageUnit)
    _G.GamepadMainActionBarFrame = root
    local addonTable = {}
    for _, fileName in ipairs(TOC_FILES) do assert(loadfile(fileName))("GamepadEnhancer", addonTable) end
    game.eventFrame = game.frames[#game.frames]   -- Events.lua loads last and makes the event frame
    game.addon = addonTable
    return addonTable
end

local function fire(event, ...)
    for _, frame in ipairs(game.frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end

local function startGame(saved)
    local addon = boot(saved)
    fire("ADDON_LOADED", "GamepadEnhancer")
    fire("PLAYER_ENTERING_WORLD")
    return addon
end

test("defaults leave the game's bars untouched", function()
    startGame(nil)
    expectEqual(_G.GamepadEnhancerDB.gap, 0, "default gap")
    expectEqual(game.topBar.Left.setPointCalls, 0, "left half")
    expectEqual(game.topBar.Right.setPointCalls, 0, "right half")
end)

test("a saved gap moves every bar's halves apart, centered", function()
    startGame({ gap = 200 })
    for _, bar in ipairs({ game.topBar, game.bottomBar }) do
        local point, relativeTo, relativePoint, x = bar.Left:GetPoint(1)
        expectEqual(point, "LEFT"); expectEqual(relativeTo, bar); expectEqual(relativePoint, "LEFT")
        expectEqual(x, -100, "left half")
        expectEqual(select(4, bar.Right:GetPoint(1)), 100, "right half")
    end
end)

test("changing the gap starts from the game's anchor each time", function()
    local addon = startGame({ gap = 100 })
    _G.GamepadEnhancerDB.gap = 40
    addon.Gap.Apply()
    expectEqual(select(4, game.topBar.Left:GetPoint(1)), -20)
    _G.GamepadEnhancerDB.gap = 0
    addon.Gap.Apply()
    expectEqual(select(4, game.topBar.Left:GetPoint(1)), 0, "back to the game's place")
end)

test("in combat the gap waits until combat ends", function()
    local addon = startGame(nil)
    game.combat = true
    _G.GamepadEnhancerDB.gap = 60
    addon.Gap.Apply()
    expectEqual(game.topBar.Left.setPointCalls, 0, "nothing moved in combat")
    game.combat = false
    fire("PLAYER_REGEN_ENABLED")
    expectEqual(select(4, game.topBar.Left:GetPoint(1)), -30, "moved after combat")
end)

test("the bars showing again re-apply the gap", function()
    startGame({ gap = 50 })
    game.topBar.Left:ClearAllPoints(); game.topBar.Left:SetPoint("LEFT", game.topBar, "LEFT", 0, 0)
    _G.GamepadMainActionBarFrame.scripts.OnShow()
    expectEqual(select(4, game.topBar.Left:GetPoint(1)), -25)
end)

test("/gpe reset puts the game's layout back", function()
    startGame({ gap = 80 })
    _G.print = function() end
    _G.SlashCmdList.GAMEPADENHANCER("reset")
    _G.print = print
    expectEqual(_G.GamepadEnhancerDB.gap, 0)
    expectEqual(select(4, game.topBar.Right:GetPoint(1)), 0)
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
