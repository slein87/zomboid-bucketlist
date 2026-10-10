-- The ShoppingList data model: entries, sources and the rules that turn sources
-- into a wanted amount. No game calls in here (the caller hands in timestamps),
-- so tests/run.lua can exercise every rule with plain Lua 5.1.
--
-- Stored shape (player mod data, key "ShoppingList"), docs/DECISIONS.md D4:
--   { schema = 1, rev = <changes so far>, hideDone = <bool>, entries = { [fullType] = entry } }
--   entry  = { kind = "item", fullType = "Base.Nails", note = "", addedAt = <s>,
--              sources = { source, ... } }
--   source = { type = "context_menu" | "craft_menu" | "manual", amount = <int>,
--              recipeId = <craft_menu only>, tool = <craft_menu only>, addedAt = <s> }
-- Only strings, numbers, booleans and tables, because the game drops anything
-- else when it saves mod data.

local Model = {}

Model.SCHEMA = 1
Model.MAX_NOTE = 200

Model.CONTEXT_MENU = "context_menu"
Model.CRAFT_MENU = "craft_menu"
Model.MANUAL = "manual"

local function toInt(value)
    local n = tonumber(value)
    if n == nil then
        return nil
    end
    if n >= 0 then
        return math.floor(n + 0.5)
    end
    return -math.floor(-n + 0.5)
end

function Model.newList()
    return { schema = Model.SCHEMA, rev = 0, entries = {} }
end

-- "Module.Type" with something on both sides of the first dot and no blanks.
-- Strings without a dot make getItemNameFromFullType throw,
-- and type names without a module would count same-named types of other
-- modules, so they never become entries.
function Model.isFullType(value)
    return type(value) == "string" and string.find(value, "^[^%.%s]+%.[^%s]+$") ~= nil
end

-- Furniture items carry "Moveables.<sprite>" without a script item of that
-- name, so name and icon cannot be resolved. Version 1 leaves them out.
function Model.isMoveable(fullType)
    return type(fullType) == "string" and string.sub(fullType, 1, 10) == "Moveables."
end

function Model.canList(fullType)
    return Model.isFullType(fullType) and not Model.isMoveable(fullType) and not Model.isGroupKey(fullType)
end

-- Moves a list stored under an earlier key to the current one and returns
-- whether it did. A list under the current key always wins, and the old one
-- is then left alone (DECISIONS D36).
function Model.adoptOldKey(modData, key, oldKey)
    if modData[key] == nil and type(modData[oldKey]) == "table" then
        modData[key] = modData[oldKey]
        modData[oldKey] = nil
        return true
    end
    return false
end

-- Checks and repairs stored data. Returns the table to use and a status:
--   "new"      nothing usable was stored, a fresh list was made
--   "ok"       stored data is current
--   "repaired" stored data had broken fields that were dropped or fixed
--   "newer"    written by a newer ShoppingList; read it, never write it, so an
--              older mod version cannot destroy newer data (DECISIONS D5)
function Model.migrate(data)
    if type(data) ~= "table" then
        return Model.newList(), "new"
    end
    local schema = tonumber(data.schema)
    if schema == nil then
        return Model.newList(), "new"
    end
    if schema > Model.SCHEMA then
        return data, "newer"
    end
    local repaired = false
    if type(data.entries) ~= "table" then
        data.entries = {}
        repaired = true
    end
    if type(data.rev) ~= "number" then
        data.rev = 0
        repaired = true
    end
    local broken = {}
    for key, entry in pairs(data.entries) do
        if type(key) ~= "string" or type(entry) ~= "table" or type(entry.sources) ~= "table"
            or (entry.kind == "group" and not Model.validGroup(entry.group)) then
            broken[#broken + 1] = key
        else
            if type(entry.note) ~= "string" then
                entry.note = ""
                repaired = true
            end
            if entry.kind == nil then
                entry.kind = "item"
                repaired = true
            end
        end
    end
    for i = 1, #broken do
        data.entries[broken[i]] = nil
        repaired = true
    end
    if data.hideDone ~= nil and type(data.hideDone) ~= "boolean" then
        data.hideDone = nil
        repaired = true
    end
    data.schema = Model.SCHEMA
    if repaired then
        return data, "repaired"
    end
    return data, "ok"
end

-- Group entries come from craft inputs with alternatives. Their key starts
-- with "grp:"; entry.group holds the alternatives with the pieces each needs
-- per unit of the input, and whether only one alternative may be used.
Model.GROUP_PREFIX = "grp:"
Model.MAX_ALTS = 100

function Model.isGroupKey(key)
    return type(key) == "string" and string.sub(key, 1, string.len(Model.GROUP_PREFIX)) == Model.GROUP_PREFIX
end

local function validGroup(group)
    if type(group) ~= "table" or type(group.alts) ~= "table" or #group.alts < 1 then
        return false
    end
    for i = 1, #group.alts do
        local alt = group.alts[i]
        if type(alt) ~= "table" or not Model.isFullType(alt.type) then
            return false
        end
    end
    return true
end

Model.validGroup = validGroup

-- Full types an entry counts for: its own type, or every alternative.
function Model.memberTypes(key, entry)
    if entry.kind == "group" then
        local list = {}
        local alts = (type(entry.group) == "table" and entry.group.alts) or {}
        for i = 1, #alts do
            list[#list + 1] = alts[i].type
        end
        return list
    end
    return { key }
end

-- Carried amount of an entry; countOf(fullType) returns pieces carried. A
-- group counts in units of its craft input: an alternative that needs N pieces
-- per unit adds count / N, an exclusive group takes the best single
-- alternative.
function Model.measure(key, entry, countOf)
    if entry.kind ~= "group" then
        return tonumber(countOf(key)) or 0
    end
    local alts = (type(entry.group) == "table" and entry.group.alts) or {}
    local total, best = 0, 0
    for i = 1, #alts do
        local scale = tonumber(alts[i].scale) or 1
        if scale <= 0 then
            scale = 1
        end
        local units = (tonumber(countOf(alts[i].type)) or 0) / scale
        total = total + units
        if units > best then
            best = units
        end
    end
    local units = total
    if entry.group.exclusive then
        units = best
    end
    return math.floor(units + 0.000001)
end

function Model.isWritable(data)
    return type(data) == "table" and tonumber(data.schema) == Model.SCHEMA
end

local function touch(data)
    data.rev = (tonumber(data.rev) or 0) + 1
end

function Model.getEntry(data, key)
    return data.entries[key]
end

function Model.hasEntry(data, key)
    return data.entries[key] ~= nil
end

function Model.count(data)
    local n = 0
    for _ in pairs(data.entries) do
        n = n + 1
    end
    return n
end

-- Entry keys sorted, so callers get the same order on every run (pairs order
-- is insertion order in Kahlua but not in plain Lua).
function Model.keys(data)
    local list = {}
    for key in pairs(data.entries) do
        list[#list + 1] = key
    end
    table.sort(list)
    return list
end

-- Two sources are the same if type and recipe match: one context menu source
-- per entry, one craft source per recipe, one manual correction (DECISIONS D4).
local function sameSource(a, b)
    if a.type ~= b.type then
        return false
    end
    if a.type == Model.CRAFT_MENU then
        return a.recipeId == b.recipeId
    end
    return true
end

local function findSource(entry, probe)
    for i = 1, #entry.sources do
        if sameSource(entry.sources[i], probe) then
            return i
        end
    end
    return nil
end

local function hasRealSource(entry)
    for i = 1, #entry.sources do
        if entry.sources[i].type ~= Model.MANUAL then
            return true
        end
    end
    return false
end

-- Wanted amount without the manual correction: consumed sources add up, tool
-- sources count once at their largest amount, because a tool is not used up
-- (three recipes that keep a hammer need one hammer).
function Model.baseAmount(entry)
    local sum, tool = 0, 0
    for i = 1, #entry.sources do
        local source = entry.sources[i]
        local amount = toInt(source.amount) or 0
        if source.type == Model.MANUAL then
            -- applied in Model.wanted
        elseif source.tool then
            if amount > tool then
                tool = amount
            end
        else
            sum = sum + amount
        end
    end
    return sum + tool
end

function Model.manualAmount(entry)
    for i = 1, #entry.sources do
        if entry.sources[i].type == Model.MANUAL then
            return toInt(entry.sources[i].amount) or 0
        end
    end
    return 0
end

function Model.wanted(entry)
    local n = Model.baseAmount(entry) + Model.manualAmount(entry)
    if n < 1 then
        return 1
    end
    return n
end

function Model.isDone(entry, have)
    return (tonumber(have) or 0) >= Model.wanted(entry)
end

local function checkSource(source)
    if type(source) ~= "table" or (source.type ~= Model.CONTEXT_MENU and source.type ~= Model.CRAFT_MENU) then
        return nil, "bad source"
    end
    local amount = toInt(source.amount)
    if amount == nil or amount < 1 then
        return nil, "bad amount"
    end
    if source.type == Model.CRAFT_MENU and type(source.recipeId) ~= "string" then
        return nil, "bad recipe"
    end
    return amount
end

local function storeSource(data, entry, source, amount, now)
    local stored = { type = source.type, amount = amount, addedAt = now }
    if source.type == Model.CRAFT_MENU then
        stored.recipeId = source.recipeId
        stored.tool = source.tool == true
    end
    local at = findSource(entry, stored)
    if at then
        stored.addedAt = entry.sources[at].addedAt or now
        entry.sources[at] = stored
    else
        entry.sources[#entry.sources + 1] = stored
    end
    touch(data)
end

-- Adds or replaces a source. Creates the entry for a full type if needed.
-- Returns the entry and whether it was created, or nil and a reason.
function Model.addSource(data, key, source, now)
    if not Model.isWritable(data) then
        return nil, "read-only"
    end
    local amount, why = checkSource(source)
    if amount == nil then
        return nil, why
    end
    local entry = data.entries[key]
    local created = false
    if entry == nil then
        if not Model.canList(key) then
            return nil, "bad key"
        end
        entry = { kind = "item", fullType = key, note = "", addedAt = now, sources = {} }
        data.entries[key] = entry
        created = true
    elseif entry.kind == "group" then
        return nil, "bad key"
    end
    storeSource(data, entry, source, amount, now)
    return entry, created
end

-- Same for a group entry; group = { alts = { { type, scale } }, exclusive }.
-- An existing group keeps its alternatives.
function Model.addGroupSource(data, key, group, source, now)
    if not Model.isWritable(data) then
        return nil, "read-only"
    end
    if not Model.isGroupKey(key) or not validGroup(group) then
        return nil, "bad group"
    end
    local amount, why = checkSource(source)
    if amount == nil then
        return nil, why
    end
    local entry = data.entries[key]
    local created = false
    if entry == nil then
        local alts = {}
        for i = 1, math.min(#group.alts, Model.MAX_ALTS) do
            alts[#alts + 1] = { type = group.alts[i].type, scale = tonumber(group.alts[i].scale) or 1 }
        end
        entry = { kind = "group", group = { alts = alts, exclusive = group.exclusive == true }, note = "", addedAt = now, sources = {} }
        data.entries[key] = entry
        created = true
    elseif entry.kind ~= "group" then
        return nil, "bad key"
    end
    storeSource(data, entry, source, amount, now)
    return entry, created
end

-- Removes one source. Without any source left except the manual correction
-- the entry goes too. Returns removed, entryRemoved.
function Model.removeSource(data, key, sourceType, recipeId)
    if not Model.isWritable(data) then
        return false, false
    end
    local entry = data.entries[key]
    if entry == nil then
        return false, false
    end
    local at = findSource(entry, { type = sourceType, recipeId = recipeId })
    if at == nil then
        return false, false
    end
    table.remove(entry.sources, at)
    local entryRemoved = false
    if not hasRealSource(entry) then
        data.entries[key] = nil
        entryRemoved = true
    end
    touch(data)
    return true, entryRemoved
end

function Model.removeEntry(data, key)
    if not Model.isWritable(data) or data.entries[key] == nil then
        return false
    end
    data.entries[key] = nil
    touch(data)
    return true
end

-- Sets the wanted amount by storing the difference to the other sources as
-- the manual correction (DECISIONS D4, rule 2).
function Model.setWanted(data, key, wanted, now)
    if not Model.isWritable(data) then
        return false
    end
    local entry = data.entries[key]
    local n = toInt(wanted)
    if entry == nil or n == nil or n < 1 then
        return false
    end
    local delta = n - Model.baseAmount(entry)
    local at = findSource(entry, { type = Model.MANUAL })
    if delta == 0 then
        if at then
            table.remove(entry.sources, at)
        end
    elseif at then
        entry.sources[at].amount = delta
        entry.sources[at].addedAt = now
    else
        entry.sources[#entry.sources + 1] = { type = Model.MANUAL, amount = delta, addedAt = now }
    end
    touch(data)
    return true
end

function Model.setNote(data, key, text)
    if not Model.isWritable(data) then
        return false
    end
    local entry = data.entries[key]
    if entry == nil then
        return false
    end
    local note = tostring(text or "")
    note = string.gsub(note, "^%s+", "")
    note = string.gsub(note, "%s+$", "")
    if string.len(note) > Model.MAX_NOTE then
        note = string.sub(note, 1, Model.MAX_NOTE)
    end
    entry.note = note
    touch(data)
    return true
end

-- Window setting kept with the list, so it follows the character.
function Model.isHideDone(data)
    return data.hideDone == true
end

function Model.setHideDone(data, value)
    if not Model.isWritable(data) then
        return false
    end
    local wanted = value == true
    if Model.isHideDone(data) == wanted then
        return false
    end
    data.hideDone = wanted
    touch(data)
    return true
end

-- Splits full types into listed and not yet listed ones, keeping their order.
function Model.split(data, keys)
    local listed, missing = {}, {}
    for i = 1, #keys do
        if data.entries[keys[i]] ~= nil then
            listed[#listed + 1] = keys[i]
        else
            missing[#missing + 1] = keys[i]
        end
    end
    return listed, missing
end

return Model
