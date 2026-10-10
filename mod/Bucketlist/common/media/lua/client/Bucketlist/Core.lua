-- Namespace and logging. Bucketlist is the only global the mod creates
-- (docs/DECISIONS.md D3); every module also returns its own table for require.
Bucketlist = Bucketlist or {}

local Core = {}

Core.MOD_ID = "Bucketlist"
Core.VERSION = "1.0.0"

local PREFIX = "[Bucketlist] "
local reported = {}

function Core.log(text)
    print(PREFIX .. tostring(text))
end

function Core.isDebug()
    local core = getCore()
    return core ~= nil and core:getDebug() == true
end

function Core.debug(text)
    if Core.isDebug() then
        Core.log(text)
    end
end

-- Runs fn in pcall. A failing handler is reported once per name instead of on
-- every call, and the vanilla code around it carries on (DECISIONS D16).
function Core.try(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not reported[name] then
        reported[name] = true
        Core.log("error in " .. tostring(name) .. ": " .. tostring(err))
    end
    return ok
end

Bucketlist.Core = Core
return Core
