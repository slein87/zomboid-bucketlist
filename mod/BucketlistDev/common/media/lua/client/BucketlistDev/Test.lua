-- Development helper, not part of Bucketlist. "tools/start-game.sh --test <name>"
-- leaves "test <name>" as request; once the game is up and the player exists,
-- this file runs the cases of TestCases.lua frame by frame. The log gets one
-- "[BucketlistTest] PASS|FAIL" line per check and "[BucketlistTest] DONE n/m".
require "BucketlistDev/Request"
require "BucketlistDev/TestCases"

local PREFIX = "[BucketlistTest]"
-- Frames to wait for the player, then quiet frames before the first step.
local READY_TIMEOUT = 3600
local QUIET_TICKS = 120

local pending = nil
local seq = nil

local function say(text)
    print(PREFIX .. " " .. text)
end

local function pump()
    if not seq then
        Events.OnTick.Remove(pump)
        return
    end
    seq:tick()
    if seq:isFinished() then
        seq = nil
        Events.OnTick.Remove(pump)
    end
end

local function abort(reason)
    say("FAIL run start " .. reason)
    say("DONE 0/1")
end

local function start()
    local name = pending.name
    pending = nil
    if isClient() or isServer() then
        abort("the test script runs in single player only")
        return
    end
    local built, why = BucketlistDev.TestCases.build(name)
    if not built then
        abort(why)
        return
    end
    seq = built
    Events.OnTick.Add(pump)
end

local function bootstrap()
    pending.ticks = pending.ticks + 1
    if not pending.readyAt then
        if getPlayer() ~= nil and Bucketlist ~= nil and Bucketlist.Store ~= nil then
            pending.readyAt = pending.ticks
        elseif pending.ticks >= READY_TIMEOUT then
            Events.OnTick.Remove(bootstrap)
            abort("player or Bucketlist not ready after " .. pending.ticks .. " ticks")
            pending = nil
        end
        return
    end
    if pending.ticks - pending.readyAt < QUIET_TICKS then
        return
    end
    Events.OnTick.Remove(bootstrap)
    start()
end

Events.OnGameStart.Add(function()
    local name = BucketlistDev.takeRequestArg("test")
    if not name then
        return
    end
    say("START " .. name)
    pending = { name = name, ticks = 0 }
    Events.OnTick.Add(bootstrap)
end)
