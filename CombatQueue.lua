-- Changes to the controller's bars can't be made in combat: their buttons are
-- protected. A change asked for in combat waits here and runs when combat ends.
local _, Enhancer = ...

local CombatQueue = { waiting = {} }
Enhancer.CombatQueue = CombatQueue

-- Runs changeFunction now, or after combat. Each name keeps only its latest change.
function CombatQueue.Run(name, changeFunction)
    if InCombatLockdown() then
        CombatQueue.waiting[name] = changeFunction
        return false
    end
    changeFunction()
    return true
end

-- Called on PLAYER_REGEN_ENABLED (Events.lua).
function CombatQueue.Flush()
    local waiting = CombatQueue.waiting
    CombatQueue.waiting = {}
    for _, changeFunction in pairs(waiting) do
        local succeeded, message = pcall(changeFunction)
        if not succeeded then geterrorhandler()(message) end
    end
end
