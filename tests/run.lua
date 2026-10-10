-- Runs the pure-logic tests with plain Lua 5.1, outside the game:
--   lua5.1 tests/run.lua
-- Globals that Kahlua lacks are removed before any module loads, so code that
-- would break in the game breaks here too (docs/API.md, Kahlua section).

local TESTS = {
    "test_model", "test_rows", "test_paint", "test_inputs",
}

local base = (arg and arg[0] or ""):match("^(.*)tests/run%.lua$") or ""
package.path = base .. "mod/Bucketlist/common/media/lua/client/?.lua;" .. package.path

local loadfile, pcall, print, tostring, exit = loadfile, pcall, print, tostring, os.exit
-- Kept for T.readFile and T.listFiles only; the modules under test never see io.
local ioOpen, ioPopen = io.open, io.popen

local KAHLUA_MISSING = {
    "next", "xpcall", "load", "dofile", "loadfile", "module", "gcinfo", "newproxy", "io", "debug",
}
for i = 1, #KAHLUA_MISSING do
    _G[KAHLUA_MISSING[i]] = nil
end
math.random, math.randomseed = nil, nil
table.getn, table.maxn, table.setn = nil, nil, nil
string.gfind, string.dump = nil, nil
os.clock, os.getenv, os.execute, os.exit, os.remove, os.rename, os.tmpname = nil, nil, nil, nil, nil, nil, nil

-- Tiny assertion helper handed to every test.
local T = {}

local function show(v)
    if type(v) == "string" then
        return '"' .. v .. '"'
    end
    return tostring(v)
end

function T.eq(actual, expected, what)
    if actual ~= expected then
        error((what or "value") .. ": expected " .. show(expected) .. ", got " .. show(actual), 0)
    end
end

function T.ok(value, what)
    if not value then
        error((what or "condition") .. " is not true", 0)
    end
end

function T.same(a, b, path)
    path = path or "value"
    if type(a) ~= "table" or type(b) ~= "table" then
        T.eq(a, b, path)
        return
    end
    for k, v in pairs(a) do
        T.same(v, b[k], path .. "." .. tostring(k))
    end
    for k, v in pairs(b) do
        if a[k] == nil then
            T.eq(nil, v, path .. "." .. tostring(k))
        end
    end
end

function T.fails(fn, what)
    local ok = pcall(fn)
    if ok then
        error((what or "call") .. " did not fail", 0)
    end
end

-- For tests that compare data with translation files and sources. Paths are
-- relative to the repo root.
function T.readFile(path)
    local file = ioOpen(base .. path, "r")
    if not file then
        error("cannot read " .. path, 0)
    end
    local text = file:read("*a")
    file:close()
    return text
end

-- Sorted repo-relative paths of the files below dir whose names end in suffix.
function T.listFiles(dir, suffix)
    local pipe = ioPopen('find "' .. base .. dir .. '" -type f -name "*' .. suffix .. '" | LC_ALL=C sort')
    if not pipe then
        error("cannot list " .. dir, 0)
    end
    local list = {}
    for line in pipe:lines() do
        list[#list + 1] = line:sub(#base + 1)
    end
    pipe:close()
    if #list == 0 then
        error("no " .. suffix .. " files below " .. dir, 0)
    end
    return list
end

local passed, failed = 0, 0
for i = 1, #TESTS do
    local chunk, err = loadfile(base .. "tests/" .. TESTS[i] .. ".lua")
    if not chunk then
        print("LOAD ERROR " .. TESTS[i] .. ": " .. err)
        failed = failed + 1
    else
        local cases = chunk()
        local names = {}
        for name in pairs(cases) do
            names[#names + 1] = name
        end
        table.sort(names)
        for j = 1, #names do
            local ok, msg = pcall(cases[names[j]], T)
            if ok then
                passed = passed + 1
                print("ok   " .. TESTS[i] .. ": " .. names[j])
            else
                failed = failed + 1
                print("FAIL " .. TESTS[i] .. ": " .. names[j] .. ": " .. tostring(msg))
            end
        end
    end
end

print(passed .. " passed, " .. failed .. " failed")
exit(failed == 0 and 0 or 1)
