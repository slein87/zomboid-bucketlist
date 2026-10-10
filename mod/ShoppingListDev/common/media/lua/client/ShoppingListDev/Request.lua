-- Development helper, not part of ShoppingList. tools/start-game.sh leaves a request
-- ("continue", "continue-test <name>" or "test <name>") in Lua/ShoppingListDev.txt of the dev user
-- folder; each consumer takes its own request and clears the file so it runs
-- only once.
ShoppingListDev = ShoppingListDev or {}

local REQUEST_FILE = "ShoppingListDev.txt"

function ShoppingListDev.peekRequest()
    local reader = getFileReader(REQUEST_FILE, false)
    if not reader then
        return nil
    end
    local request = reader:readLine()
    reader:close()
    return request
end

function ShoppingListDev.clearRequest()
    local writer = getFileWriter(REQUEST_FILE, true, false)
    writer:write("")
    writer:close()
end

-- Returns true and clears the file if the pending request is the given one.
function ShoppingListDev.takeRequest(name)
    if ShoppingListDev.peekRequest() ~= name then
        return false
    end
    ShoppingListDev.clearRequest()
    return true
end

-- For requests with an argument ("test context"): returns the argument and clears
-- the file if the pending request is that name plus one word.
function ShoppingListDev.takeRequestArg(name)
    local request = ShoppingListDev.peekRequest()
    if type(request) ~= "string" then
        return nil
    end
    local arg = string.match(request, "^%s*" .. name .. "%s+(%S+)%s*$")
    if arg == nil then
        return nil
    end
    ShoppingListDev.clearRequest()
    return arg
end

-- Replaces the pending request, for chains like "continue-test persist" that
-- hand the next step to the following game start.
function ShoppingListDev.setRequest(text)
    local writer = getFileWriter(REQUEST_FILE, true, false)
    writer:write(text)
    writer:close()
end
