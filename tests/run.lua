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
    function frame:GetParent() return self.parent end
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(index) local point = self.points[index or 1]; if point then return unpack(point, 1, 5) end end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.setPointCalls = self.setPointCalls + 1; self.points[#self.points + 1] = { ... } end
    function frame:HookScript(scriptName, handler) self.scripts[scriptName] = handler end
    function frame:SetScript(scriptName, handler) self.scripts[scriptName] = handler end
    function frame:RegisterEvent(event) self.events[event] = true end
    if parent then parent.children[#parent.children + 1] = frame; frame.parent = parent end
    game.frames[#game.frames + 1] = frame
    return frame
end

-- A bar like GamepadActionBarTemplate: .Left and .Right halves, each button
-- anchored to the bar's center at the game's x (left -50, right +50).
local GAME_X = { [-1] = -50, [1] = 50 }
local function newBar(parent)
    local bar = newFrame(parent)
    bar.Left, bar.Right = newFrame(bar), newFrame(bar)
    bar.buttons = {}
    for side, half in pairs({ [-1] = bar.Left, [1] = bar.Right }) do
        local button = newFrame(half)
        half.ActionButton1 = button
        button.gameX = GAME_X[side]
        button:SetPoint("CENTER", bar, "CENTER", button.gameX, 0)
        button.setPointCalls = 0
        bar.buttons[side] = button
    end
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
    _G.hooksecurefunc = function(owner, methodName, hook)
        local original = owner[methodName]
        owner[methodName] = function(...) local results = { original(...) }; hook(...); return unpack(results) end
    end
    local root = newFrame(nil)
    root.PageUnit = newFrame(root)
    game.bar = newBar(root.PageUnit)
    game.left, game.right = game.bar.buttons[-1], game.bar.buttons[1]
    _G.GamepadMainActionBarFrame = root
    -- The game's restyle: the button back at its own place.
    _G.GamepadActionBarStyleUtil = { ApplyExtraButtonStyles = function(button)
        button:ClearAllPoints(); button:SetPoint("CENTER", game.bar, "CENTER", button.gameX, 0)
    end }
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
local function gameRestyle(button) _G.GamepadActionBarStyleUtil.ApplyExtraButtonStyles(button) end

test("defaults leave the game's buttons untouched", function()
    startGame(nil)
    expectEqual(_G.GamepadEnhancerDB.gap, 0, "default gap")
    gameRestyle(game.left)
    expectEqual(game.left.setPointCalls, 1, "only the game's own move")
    expectEqual(x(game.left), -50)
end)

test("a saved gap splits the halves, centered", function()
    startGame({ gap = 200 })
    expectEqual(x(game.left), -150, "left half")
    expectEqual(x(game.right), 150, "right half")
    expectEqual(select(2, game.left:GetPoint(1)), game.bar, "still anchored to the bar")
end)

test("after the game restyles a button it is split again at once", function()
    startGame({ gap = 100 })
    gameRestyle(game.right)
    expectEqual(x(game.right), 100)
end)

test("changing the gap starts from the game's place", function()
    local addon = startGame({ gap = 100 })
    _G.GamepadEnhancerDB.gap = 40
    addon.Gap.Apply()
    expectEqual(x(game.left), -70)
    _G.GamepadEnhancerDB.gap = 0
    addon.Gap.Apply()
    expectEqual(x(game.left), -50, "back to the game's place")
end)

test("in combat the game's place stays until the fight ends", function()
    startGame({ gap = 60 })
    game.combat = true
    gameRestyle(game.left)
    expectEqual(x(game.left), -50, "not moved in combat")
    game.combat = false
    fire("PLAYER_REGEN_ENABLED")
    expectEqual(x(game.left), -80, "split again after combat")
    expectEqual(x(game.right), 80, "the other half kept its split")
end)

test("buttons outside a bar's halves are left alone", function()
    startGame({ gap = 60 })
    local other = newFrame(newFrame(nil))
    other:SetPoint("CENTER", nil, "CENTER", 5, 0)
    other.gameX = 5
    gameRestyle(other)
    expectEqual(x(other), 5)
end)

test("the game's float rounding doesn't add the gap twice", function()
    local addon = startGame({ gap = 100 })
    -- As in game: GetPoint gives back the stored x slightly off (32-bit float).
    local point, relativeTo, relativePoint, storedX, y = game.left:GetPoint(1)
    game.left.points[1] = { point, relativeTo, relativePoint, storedX + 0.00002, y }
    addon.Gap.Apply()
    expectEqual(math.floor(x(game.left) + 0.5), -100, "still one gap from the game's place")
end)

test("/gpe reset puts the game's layout back", function()
    startGame({ gap = 80 })
    _G.print = function() end
    _G.SlashCmdList.GAMEPADENHANCER("reset")
    _G.print = print
    expectEqual(_G.GamepadEnhancerDB.gap, 0)
    expectEqual(x(game.right), 50)
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
