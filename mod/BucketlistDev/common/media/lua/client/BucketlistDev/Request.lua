-- Development helper, not part of Bucketlist. tools/start-game.sh leaves a request
-- ("continue", "continue-test <name>" or "test <name>") in Lua/BucketlistDev.txt of the dev user
-- folder; each consumer takes its own request and clears the file so it runs
-- only once.
BucketlistDev = BucketlistDev or {}

local REQUEST_FILE = "BucketlistDev.txt"

function BucketlistDev.peekRequest()
    local reader = getFileReader(REQUEST_FILE, false)
    if not reader then
        return nil
    end
    local request = reader:readLine()
    reader:close()
    return request
end

function BucketlistDev.clearRequest()
    local writer = getFileWriter(REQUEST_FILE, true, false)
    writer:write("")
    writer:close()
end

-- Returns true and clears the file if the pending request is the given one.
function BucketlistDev.takeRequest(name)
    if BucketlistDev.peekRequest() ~= name then
        return false
    end
    BucketlistDev.clearRequest()
    return true
end

-- For requests with an argument ("test context"): returns the argument and clears
-- the file if the pending request is that name plus one word.
function BucketlistDev.takeRequestArg(name)
    local request = BucketlistDev.peekRequest()
    if type(request) ~= "string" then
        return nil
    end
    local arg = string.match(request, "^%s*" .. name .. "%s+(%S+)%s*$")
    if arg == nil then
        return nil
    end
    BucketlistDev.clearRequest()
    return arg
end

-- Replaces the pending request, for chains like "continue-test persist" that
-- hand the next step to the following game start.
function BucketlistDev.setRequest(text)
    local writer = getFileWriter(REQUEST_FILE, true, false)
    writer:write(text)
    writer:close()
end
