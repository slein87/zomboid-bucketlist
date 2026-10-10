-- Rows of the management window: order, filter, source parts, text helpers.
local Model = require "ShoppingList/Model"
local Rows = require "ShoppingList/Rows"

local NOW = 1760000000

local NAMES = {
    ["Base.Nails"] = "Nails",
    ["Base.Hammer"] = "Hammer",
    ["Base.Plank"] = "plank",
    ["Base.Axe"] = "Axe",
}

local function nameOf(fullType)
    local name = NAMES[fullType]
    if name then
        return name, true
    end
    return fullType, false
end

local function counts(map)
    return function(fullType)
        return map[fullType] or 0
    end
end

local function ctx()
    return { type = Model.CONTEXT_MENU, amount = 1 }
end

local function listWith(keys)
    local data = Model.newList()
    for i = 1, #keys do
        Model.addSource(data, keys[i], ctx(), NOW)
    end
    return data
end

local function keysOf(rows)
    local list = {}
    for i = 1, #rows do
        list[i] = rows[i].key
    end
    return list
end

local cases = {}

function cases.open_rows_come_first_then_by_name(T)
    local data = listWith({ "Base.Nails", "Base.Hammer", "Base.Plank", "Base.Axe" })
    -- Hammer and Axe are done (wanted 1, carried 1 or more)
    local rows = Rows.build(data, nameOf, counts({ ["Base.Hammer"] = 1, ["Base.Axe"] = 3 }), false)
    T.same(keysOf(rows), { "Base.Nails", "Base.Plank", "Base.Axe", "Base.Hammer" }, "order")
    T.eq(rows[1].done, false, "nails open")
    T.eq(rows[3].done, true, "axe done")
    T.eq(rows[2].sortName, "plank", "lower-case sort name")
end

function cases.hide_done_filters_done_rows(T)
    local data = listWith({ "Base.Nails", "Base.Hammer" })
    local rows = Rows.build(data, nameOf, counts({ ["Base.Hammer"] = 1 }), true)
    T.same(keysOf(rows), { "Base.Nails" }, "only open")
end

function cases.row_fields(T)
    local data = listWith({ "Base.Nails" })
    Model.setWanted(data, "Base.Nails", 5, NOW)
    Model.setNote(data, "Base.Nails", "for the shed")
    local row = Rows.build(data, nameOf, counts({ ["Base.Nails"] = 2 }), false)[1]
    T.eq(row.name, "Nails", "name")
    T.eq(row.available, true, "available")
    T.eq(row.have, 2, "have")
    T.eq(row.wanted, 5, "wanted")
    T.eq(row.done, false, "done")
    T.eq(row.note, "for the shed", "note")
end

function cases.unknown_item_keeps_full_type_as_name(T)
    local data = listWith({ "OldMod.Thing" })
    local row = Rows.build(data, nameOf, counts({}), false)[1]
    T.eq(row.name, "OldMod.Thing", "name")
    T.eq(row.available, false, "not available")
end

function cases.equal_names_sort_by_key(T)
    local data = listWith({ "Base.Bucket", "Base.BucketEmpty" })
    local function sameName()
        return "Bucket", true
    end
    local rows = Rows.build(data, sameName, counts({}), false)
    T.same(keysOf(rows), { "Base.Bucket", "Base.BucketEmpty" }, "tie broken by key")
end

function cases.source_parts_order_and_manual_delta(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", { type = Model.CRAFT_MENU, recipeId = "Base.MakeB", amount = 6 }, NOW)
    Model.addSource(data, "Base.Nails", ctx(), NOW)
    Model.addSource(data, "Base.Nails", { type = Model.CRAFT_MENU, recipeId = "Base.MakeA", amount = 4, tool = true }, NOW)
    Model.setWanted(data, "Base.Nails", 20, NOW)
    local parts = Rows.sourceParts(Model.getEntry(data, "Base.Nails"))
    T.eq(#parts, 4, "four parts")
    T.eq(parts[1].key, Rows.CONTEXT, "right-click first")
    T.eq(parts[2].recipeId, "Base.MakeA", "recipes by id")
    T.eq(parts[2].tool, true, "tool flag")
    T.eq(parts[3].recipeId, "Base.MakeB", "second recipe")
    T.eq(parts[4].key, Rows.MANUAL, "manual last")
    T.eq(parts[4].arg, "+9", "delta: 20 - (1 + 6 + max tool 4)")
end

function cases.no_manual_part_without_delta(T)
    local data = listWith({ "Base.Nails" })
    local parts = Rows.sourceParts(Model.getEntry(data, "Base.Nails"))
    T.eq(#parts, 1, "only right-click")
end

function cases.signed_numbers(T)
    T.eq(Rows.signed(4), "+4", "positive")
    T.eq(Rows.signed(-2), "-2", "negative")
    T.eq(Rows.signed(0), "0", "zero")
    T.eq(Rows.signed(3.0), "+3", "whole double")
end

function cases.same_order(T)
    local a = { { key = "A" }, { key = "B" } }
    T.ok(Rows.sameOrder(a, { { key = "A" }, { key = "B" } }), "same")
    T.ok(not Rows.sameOrder(a, { { key = "B" }, { key = "A" } }), "swapped")
    T.ok(not Rows.sameOrder(a, { { key = "A" } }), "shorter")
end

function cases.escape_and_flatten(T)
    T.eq(Rows.escape("<RGB:1,0,0>red"), "&lt;RGB:1,0,0&gt;red", "escaped")
    T.eq(Rows.flatten("two\nlines  here"), "two lines here", "flattened")
end

function cases.wrap_splits_at_blanks_and_breaks(T)
    T.same(Rows.wrap("one two three four", 9), { "one two", "three", "four" }, "words")
    T.same(Rows.wrap("first\nsecond line", 20), { "first", "second line" }, "line break")
    T.same(Rows.wrap("abcdefghij", 4), { "abcd", "efgh", "ij" }, "long word cut")
    T.same(Rows.wrap("", 10), {}, "empty")
    T.same(Rows.wrap("a\n\nb", 10), { "a", "b" }, "empty line skipped")
end

return cases
