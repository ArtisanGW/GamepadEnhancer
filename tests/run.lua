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
    function frame:GetNumPoints() return #self.points end
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

-- A page unit like GamepadActionBarPageUnitTemplate: side anchors at -195 / +195.
local function newPageUnit(parent)
    local pageUnit = newFrame(parent)
    pageUnit.LeftCenteredAnchor = newFrame(pageUnit); pageUnit.LeftCenteredAnchor:SetPoint("CENTER", nil, nil, -195, 0)
    pageUnit.RightCenteredAnchor = newFrame(pageUnit); pageUnit.RightCenteredAnchor:SetPoint("CENTER", nil, nil, 195, 0)
    pageUnit.LeftCenteredAnchor.setPointCalls, pageUnit.RightCenteredAnchor.setPointCalls = 0, 0
    pageUnit.compact = false
    function pageUnit:ShouldUseCompactLayout() return self.compact end
    function pageUnit:RefreshCompactLayout()   -- as the game: its own places back
        for anchor, x in pairs({ [self.LeftCenteredAnchor] = -195, [self.RightCenteredAnchor] = 195 }) do
            anchor:ClearAllPoints(); anchor:SetPoint("CENTER", nil, nil, x, 0)
        end
    end
    return pageUnit
end

local function boot(saved)
    game = { frames = {}, combat = false, errors = {} }
    _G.GamepadEnhancerDB = saved
    _G.InCombatLockdown = function() return game.combat end
    _G.geterrorhandler = function() return function(message) game.errors[#game.errors + 1] = message end end
    _G.CreateFrame = function() return newFrame(nil) end
    _G.Settings = nil
    _G.SlashCmdList = {}
    _G.hooksecurefunc = function(owner, methodName, hook)
        local original = owner[methodName]
        owner[methodName] = function(...) local results = { original(...) }; hook(...); return unpack(results) end
    end
    local root = newFrame(nil)
    root.PageUnit = newPageUnit(root)
    game.left, game.right = root.PageUnit.LeftCenteredAnchor, root.PageUnit.RightCenteredAnchor
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

local function x(frame) return select(4, frame:GetPoint(1)) end

test("defaults leave the game's bars untouched", function()
    startGame(nil)
    expectEqual(_G.GamepadEnhancerDB.gap, 0, "default gap")
    expectEqual(game.left.setPointCalls, 0, "left bar")
    expectEqual(game.right.setPointCalls, 0, "right bar")
end)

test("a saved gap moves the side bars apart, centered", function()
    startGame({ gap = 200 })
    expectEqual(x(game.left), -295, "left bar")
    expectEqual(x(game.right), 295, "right bar")
    expectEqual((game.left:GetPoint(1)), "CENTER", "same anchor point")
end)

test("changing the gap starts from the game's place each time", function()
    local addon = startGame({ gap = 100 })
    _G.GamepadEnhancerDB.gap = 40
    addon.Gap.Apply()
    expectEqual(x(game.left), -215)
    _G.GamepadEnhancerDB.gap = 0
    addon.Gap.Apply()
    expectEqual(x(game.left), -195, "back to the game's place")
end)

test("in combat the gap waits until combat ends", function()
    local addon = startGame(nil)
    game.combat = true
    _G.GamepadEnhancerDB.gap = 60
    addon.Gap.Apply()
    expectEqual(game.left.setPointCalls, 0, "nothing moved in combat")
    game.combat = false
    fire("PLAYER_REGEN_ENABLED")
    expectEqual(x(game.left), -225, "moved after combat")
end)

test("the game laying its bars out again keeps the gap", function()
    startGame({ gap = 50 })
    _G.GamepadMainActionBarFrame.PageUnit:RefreshCompactLayout()
    expectEqual(x(game.right), 220)
end)

test("the compact layout is left to the game", function()
    startGame({ gap = 50 })
    local pageUnit = _G.GamepadMainActionBarFrame.PageUnit
    pageUnit.compact = true
    local calls = game.left.setPointCalls
    _G.GamepadMainActionBarFrame.scripts.OnShow()
    expectEqual(game.left.setPointCalls, calls, "not moved in compact layout")
end)

test("/gpe reset puts the game's layout back", function()
    startGame({ gap = 80 })
    _G.print = function() end
    _G.SlashCmdList.GAMEPADENHANCER("reset")
    _G.print = print
    expectEqual(_G.GamepadEnhancerDB.gap, 0)
    expectEqual(x(game.right), 195)
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
