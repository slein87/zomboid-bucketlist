-- Wrappers around vanilla UI functions: the original is kept and always runs
-- first and exactly once, its return value is passed on, our part runs in
-- pcall afterwards (docs/DECISIONS.md D16). A mod that later replaces such a
-- function without calling the previous one would drop our part silently, so
-- OnGameStart wraps again where needed; a guard on the object keeps our part
-- from running twice if we end up inside the chain twice.
local Core = require "ShoppingList/Core"

local Hooks = {}

local installed = {}

-- The guard holds the time our wrapper was entered on this object. A nested
-- call within the same call stack sees a fresh guard and only runs the
-- original. If the original throws, the guard stays behind; it counts as stale
-- after GUARD_MS, so our part comes back with the next frame.
local GUARD_MS = 100

local function makeWrapper(name, original, after, guard)
    return function(self, ...)
        local now = getTimestampMs()
        local active = self[guard]
        if active ~= nil and now - active < GUARD_MS then
            return original(self, ...)
        end
        self[guard] = now
        local result = original(self, ...)
        self[guard] = nil
        Core.try(name, after, self, result, ...)
        return result
    end
end

-- after(self, result, ...) runs after the original with its arguments.
function Hooks.after(class, method, name, after)
    local original = class[method]
    if type(original) ~= "function" then
        Core.log("cannot hook " .. name .. ": function missing")
        return false
    end
    local guard = "shoppingListIn_" .. method
    local wrapper = makeWrapper(name, original, after, guard)
    class[method] = wrapper
    installed[#installed + 1] = { class = class, method = method, name = name, after = after, wrapper = wrapper }
    return true
end

-- Wraps again every function that no longer points at our wrapper.
function Hooks.verify()
    local count = #installed
    for i = 1, count do
        local hook = installed[i]
        if hook.class[hook.method] ~= hook.wrapper then
            local current = hook.class[hook.method]
            if type(current) == "function" then
                hook.wrapper = makeWrapper(hook.name, current, hook.after, "shoppingListIn_" .. hook.method)
                hook.class[hook.method] = hook.wrapper
                Core.log(hook.name .. " was replaced by another mod, wrapped again")
            end
        end
    end
end

Events.OnGameStart.Add(function()
    Core.try("Hooks.verify", Hooks.verify)
end)

ShoppingList.Hooks = Hooks
return Hooks
