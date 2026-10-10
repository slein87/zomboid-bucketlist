-- Development helper, not part of Bucketlist. A step queue for the in-game test
-- script: every frame the current step runs once, until it reports that it is
-- finished or its timeout runs out. Coroutines would read nicer, but they are
-- unreliable in Kahlua, so the script is a queue of small steps that
-- may insert further steps behind themselves. No game calls in here; the
-- printer is handed in, which keeps the file runnable in plain Lua.
BucketlistDev = BucketlistDev or {}

local Seq = {}
Seq.__index = Seq

local PREFIX = "[BucketlistTest]"

-- One token per field, so "PASS context add.single ..." stays easy to grep.
local function word(value)
    local text = string.gsub(tostring(value or "-"), "%s+", "_")
    if text == "" then
        return "-"
    end
    return text
end

local function oneLine(value)
    return (string.gsub(tostring(value or ""), "[\r\n]+", " "))
end

function Seq.new(printer)
    local seq = setmetatable({}, Seq)
    seq.printer = printer or print
    seq.queue = {}
    seq.pos = 1
    seq.passed = 0
    seq.total = 0
    seq.finished = false
    seq.onDone = nil
    return seq
end

function Seq:line(text)
    self.printer(PREFIX .. " " .. oneLine(text))
end

function Seq:report(status, test, step, detail)
    local text = status .. " " .. word(test) .. " " .. word(step)
    if detail ~= nil and detail ~= "" then
        text = text .. " " .. oneLine(detail)
    end
    self:line(text)
end

function Seq:pass(test, step, detail)
    self.total = self.total + 1
    self.passed = self.passed + 1
    self:report("PASS", test, step, detail)
    return true
end

function Seq:fail(test, step, detail)
    self.total = self.total + 1
    self:report("FAIL", test, step, detail)
    return false
end

function Seq:check(ok, test, step, detail)
    if ok then
        return self:pass(test, step, detail)
    end
    return self:fail(test, step, detail)
end

function Seq:info(text)
    self:line("INFO " .. oneLine(text))
end

function Seq:summary()
    return "DONE " .. self.passed .. "/" .. self.total
end

function Seq:add(step)
    self.queue[#self.queue + 1] = step
    return step
end

-- Steps inserted by the running step run right after it, in list order.
function Seq:insert(steps)
    local at = self.pos + 1
    for i = 1, #steps do
        table.insert(self.queue, at + i - 1, steps[i])
    end
end

function Seq:isFinished()
    return self.finished
end

local function finishStep(seq)
    seq.pos = seq.pos + 1
end

-- A step is { name, run = fn(step, seq) -> true when finished, every?, timeout?,
-- onTimeout?, scope?, always? }. A step whose scope is aborted is skipped unless
-- it is marked always, so one failed objective ends its quest, not the run.
function Seq:tick()
    if self.finished then
        return
    end
    local step = self.queue[self.pos]
    if step == nil then
        self.finished = true
        if self.onDone then
            self.onDone(self)
        end
        return
    end
    local scope = step.scope
    if scope and scope.aborted and not step.always then
        finishStep(self)
        return
    end
    step.ticks = (step.ticks or 0) + 1
    local timedOut = step.timeout ~= nil and step.ticks >= step.timeout
    local every = step.every or 1
    if not timedOut and (step.ticks - 1) % every ~= 0 then
        return
    end
    local ok, result = pcall(step.run, step, self)
    if not ok then
        self:fail(scope and scope.test or "run", step.name or "step", "error " .. tostring(result))
        if scope then
            scope.aborted = true
        end
        finishStep(self)
        return
    end
    if result then
        finishStep(self)
        return
    end
    if timedOut then
        if step.onTimeout then
            local okTimeout, err = pcall(step.onTimeout, step, self)
            if not okTimeout then
                self:fail(scope and scope.test or "run", step.name or "step", "error " .. tostring(err))
                if scope then
                    scope.aborted = true
                end
            end
        else
            self:fail(scope and scope.test or "run", step.name or "step", "timeout after " .. step.ticks .. " ticks")
            if scope then
                scope.aborted = true
            end
        end
        finishStep(self)
    end
end

-- Builders for the common shapes. All take the scope first so a builder can
-- never produce a step that outlives its failed quest by accident.
function Seq.action(scope, name, fn)
    return {
        name = name, scope = scope,
        run = function(step, seq)
            fn(step, seq)
            return true
        end,
    }
end

function Seq.wait(scope, ticks)
    return {
        name = "wait", scope = scope,
        run = function(step)
            return step.ticks >= ticks
        end,
    }
end

-- cond(step, seq) -> true when met; onTimeout defaults to a FAIL that aborts
-- the scope.
function Seq.waitFor(scope, name, cond, timeout, every, onTimeout)
    return {
        name = name, scope = scope, timeout = timeout, every = every or 10, onTimeout = onTimeout,
        run = cond,
    }
end

BucketlistDev.TestSeq = Seq
return Seq
