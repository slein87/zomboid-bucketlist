-- Rules of the data model, docs/DECISIONS.md D4.
local Model = require "Bucketlist/Model"

local NOW = 1760000000

local function ctx(amount)
    return { type = Model.CONTEXT_MENU, amount = amount or 1 }
end

local function craft(recipeId, amount, tool)
    return { type = Model.CRAFT_MENU, recipeId = recipeId, amount = amount, tool = tool }
end

local cases = {}

function cases.new_list_is_empty_and_current(T)
    local data = Model.newList()
    T.eq(data.schema, Model.SCHEMA, "schema")
    T.eq(data.rev, 0, "rev")
    T.eq(Model.count(data), 0, "count")
    T.ok(Model.isWritable(data), "writable")
end

function cases.full_type_rules(T)
    T.ok(Model.isFullType("Base.Nails"), "Base.Nails")
    T.ok(Model.isFullType("SomeMod.Axe_Big"), "mod item")
    T.ok(not Model.isFullType("Nails"), "no module")
    T.ok(not Model.isFullType(".Nails"), "empty module")
    T.ok(not Model.isFullType("Base."), "empty type")
    T.ok(not Model.isFullType("Base. Nails"), "blank")
    T.ok(not Model.isFullType(nil), "nil")
    T.ok(not Model.isFullType(12), "number")
    T.ok(Model.isMoveable("Moveables.furniture_seating_01_0"), "moveable")
    T.ok(not Model.canList("Moveables.furniture_seating_01_0"), "moveable not listable")
    T.ok(Model.canList("Base.Hammer"), "hammer listable")
end

function cases.context_menu_adds_entry_with_amount_one(T)
    local data = Model.newList()
    local entry, created = Model.addSource(data, "Base.Nails", ctx(), NOW)
    T.ok(entry, "entry")
    T.eq(created, true, "created")
    T.eq(entry.fullType, "Base.Nails", "fullType")
    T.eq(entry.kind, "item", "kind")
    T.eq(entry.note, "", "note")
    T.eq(entry.addedAt, NOW, "addedAt")
    T.eq(#entry.sources, 1, "sources")
    T.eq(entry.sources[1].type, Model.CONTEXT_MENU, "source type")
    T.eq(Model.wanted(entry), 1, "wanted")
    T.eq(data.rev, 1, "rev")
end

function cases.second_context_add_replaces_instead_of_doubling(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", ctx(), NOW)
    local entry, created = Model.addSource(data, "Base.Nails", ctx(), NOW + 5)
    T.eq(created, false, "created")
    T.eq(#entry.sources, 1, "sources")
    T.eq(entry.sources[1].addedAt, NOW, "first addedAt kept")
    T.eq(Model.wanted(entry), 1, "wanted")
end

function cases.craft_sources_add_up_per_recipe(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", craft("Base.MakeA", 4), NOW)
    local entry = Model.addSource(data, "Base.Nails", craft("Base.MakeB", 6), NOW)
    T.eq(#entry.sources, 2, "sources")
    T.eq(Model.wanted(entry), 10, "sum of recipes")
    -- the same recipe again replaces its share
    Model.addSource(data, "Base.Nails", craft("Base.MakeA", 2), NOW)
    T.eq(#entry.sources, 2, "still two sources")
    T.eq(Model.wanted(entry), 8, "replaced share")
end

function cases.tools_count_once_at_their_largest_amount(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Hammer", craft("Base.MakeA", 1, true), NOW)
    Model.addSource(data, "Base.Hammer", craft("Base.MakeB", 1, true), NOW)
    local entry = Model.addSource(data, "Base.Hammer", craft("Base.MakeC", 2, true), NOW)
    T.eq(Model.wanted(entry), 2, "max of tools")
    -- a consumed source adds on top of the tool share
    Model.addSource(data, "Base.Hammer", ctx(), NOW)
    T.eq(Model.wanted(entry), 3, "tool max plus consumed")
end

function cases.manual_correction_sets_the_wanted_amount(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", craft("Base.MakeA", 4), NOW)
    local entry = Model.addSource(data, "Base.Nails", craft("Base.MakeB", 6), NOW)
    T.ok(Model.setWanted(data, "Base.Nails", 25, NOW), "set 25")
    T.eq(Model.wanted(entry), 25, "wanted 25")
    T.eq(Model.manualAmount(entry), 15, "manual delta")
    -- removing a recipe lowers the amount by exactly its share
    Model.removeSource(data, "Base.Nails", Model.CRAFT_MENU, "Base.MakeB")
    T.eq(Model.wanted(entry), 19, "lowered by 6")
end

function cases.manual_correction_can_lower_and_disappears_at_zero(T)
    local data = Model.newList()
    local entry = Model.addSource(data, "Base.Nails", craft("Base.MakeA", 10), NOW)
    Model.setWanted(data, "Base.Nails", 4, NOW)
    T.eq(Model.manualAmount(entry), -6, "negative delta")
    T.eq(Model.wanted(entry), 4, "wanted 4")
    Model.setWanted(data, "Base.Nails", 10, NOW)
    T.eq(#entry.sources, 1, "manual source gone at delta 0")
    T.eq(Model.wanted(entry), 10, "back to base")
end

function cases.wanted_never_drops_below_one(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", craft("Base.MakeA", 10), NOW)
    local entry = Model.addSource(data, "Base.Nails", craft("Base.MakeB", 2), NOW)
    Model.setWanted(data, "Base.Nails", 3, NOW)
    Model.removeSource(data, "Base.Nails", Model.CRAFT_MENU, "Base.MakeA")
    T.eq(Model.baseAmount(entry) + Model.manualAmount(entry), -7, "raw sum")
    T.eq(Model.wanted(entry), 1, "clamped")
end

function cases.set_wanted_rejects_bad_values(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", ctx(), NOW)
    T.eq(Model.setWanted(data, "Base.Nails", 0, NOW), false, "zero")
    T.eq(Model.setWanted(data, "Base.Nails", "x", NOW), false, "text")
    T.eq(Model.setWanted(data, "Base.Missing", 3, NOW), false, "unknown entry")
    T.eq(Model.setWanted(data, "Base.Nails", 2.6, NOW), true, "rounded")
    T.eq(Model.wanted(Model.getEntry(data, "Base.Nails")), 3, "rounded to 3")
end

function cases.entry_lives_while_a_real_source_is_left(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", ctx(), NOW)
    Model.addSource(data, "Base.Nails", craft("Base.MakeA", 4), NOW)
    Model.setWanted(data, "Base.Nails", 9, NOW)
    local removed, gone = Model.removeSource(data, "Base.Nails", Model.CONTEXT_MENU)
    T.eq(removed, true, "removed")
    T.eq(gone, false, "craft source keeps it")
    removed, gone = Model.removeSource(data, "Base.Nails", Model.CRAFT_MENU, "Base.MakeA")
    T.eq(removed, true, "removed craft")
    T.eq(gone, true, "manual alone does not keep it")
    T.eq(Model.hasEntry(data, "Base.Nails"), false, "entry gone")
end

function cases.remove_unknown_source_changes_nothing(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", ctx(), NOW)
    local rev = data.rev
    local removed = Model.removeSource(data, "Base.Nails", Model.CRAFT_MENU, "Base.Nope")
    T.eq(removed, false, "nothing removed")
    T.eq(data.rev, rev, "rev unchanged")
end

function cases.remove_entry_and_rev(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", ctx(), NOW)
    Model.addSource(data, "Base.Hammer", ctx(), NOW)
    T.eq(data.rev, 2, "rev after two adds")
    T.eq(Model.removeEntry(data, "Base.Nails"), true, "removed")
    T.eq(Model.removeEntry(data, "Base.Nails"), false, "already gone")
    T.eq(data.rev, 3, "rev counts only real changes")
    T.eq(Model.count(data), 1, "one left")
end

function cases.add_rejects_bad_input(T)
    local data = Model.newList()
    T.eq(Model.addSource(data, "Nails", ctx(), NOW), nil, "no module")
    T.eq(Model.addSource(data, "Moveables.chair_1", ctx(), NOW), nil, "moveable")
    T.eq(Model.addSource(data, "Base.Nails", ctx(0), NOW), nil, "amount 0")
    T.eq(Model.addSource(data, "Base.Nails", { type = Model.MANUAL, amount = 3 }, NOW), nil, "manual is not added this way")
    T.eq(Model.addSource(data, "Base.Nails", craft(nil, 2), NOW), nil, "craft without recipe")
    T.eq(Model.count(data), 0, "nothing stored")
    T.eq(data.rev, 0, "rev untouched")
end

function cases.split_keeps_order(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Hammer", ctx(), NOW)
    local listed, missing = Model.split(data, { "Base.Nails", "Base.Hammer", "Base.Plank" })
    T.same(listed, { "Base.Hammer" }, "listed")
    T.same(missing, { "Base.Nails", "Base.Plank" }, "missing")
end

function cases.keys_are_sorted(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Plank", ctx(), NOW)
    Model.addSource(data, "Base.Hammer", ctx(), NOW)
    Model.addSource(data, "Base.Nails", ctx(), NOW)
    T.same(Model.keys(data), { "Base.Hammer", "Base.Nails", "Base.Plank" }, "keys")
end

function cases.note_is_trimmed_and_capped(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", ctx(), NOW)
    T.ok(Model.setNote(data, "Base.Nails", "  for the shed  "), "set")
    T.eq(Model.getEntry(data, "Base.Nails").note, "for the shed", "trimmed")
    Model.setNote(data, "Base.Nails", string.rep("x", 250))
    T.eq(string.len(Model.getEntry(data, "Base.Nails").note), Model.MAX_NOTE, "capped")
    T.eq(Model.setNote(data, "Base.Missing", "x"), false, "unknown entry")
end

function cases.is_done_compares_with_wanted(T)
    local data = Model.newList()
    local entry = Model.addSource(data, "Base.Nails", craft("Base.MakeA", 4), NOW)
    T.eq(Model.isDone(entry, 3), false, "3 of 4")
    T.eq(Model.isDone(entry, 4), true, "4 of 4")
    T.eq(Model.isDone(entry, nil), false, "nothing")
end

function cases.migrate_makes_new_list_from_nothing(T)
    local data, status = Model.migrate(nil)
    T.eq(status, "new", "nil")
    T.eq(Model.count(data), 0, "empty")
    data, status = Model.migrate("garbage")
    T.eq(status, "new", "string")
    data, status = Model.migrate({ entries = {} })
    T.eq(status, "new", "no schema")
end

function cases.migrate_keeps_current_data(T)
    local data = Model.newList()
    Model.addSource(data, "Base.Nails", ctx(), NOW)
    local again, status = Model.migrate(data)
    T.eq(status, "ok", "status")
    T.ok(again == data, "same table")
    T.eq(Model.count(again), 1, "entry kept")
end

function cases.migrate_repairs_broken_fields(T)
    local stored = {
        schema = 1,
        entries = {
            ["Base.Nails"] = { fullType = "Base.Nails", sources = { { type = Model.CONTEXT_MENU, amount = 1 } } },
            ["Base.Broken"] = { fullType = "Base.Broken" },
            [7] = { sources = {} },
        },
    }
    local data, status = Model.migrate(stored)
    T.eq(status, "repaired", "status")
    T.eq(data.rev, 0, "rev added")
    T.eq(Model.count(data), 1, "broken entries dropped")
    local entry = Model.getEntry(data, "Base.Nails")
    T.eq(entry.note, "", "note added")
    T.eq(entry.kind, "item", "kind added")
end

function cases.newer_schema_is_read_only(T)
    local stored = { schema = Model.SCHEMA + 1, rev = 9, entries = { ["Base.Nails"] = { sources = {} } } }
    local data, status = Model.migrate(stored)
    T.eq(status, "newer", "status")
    T.ok(data == stored, "returned as is")
    T.eq(Model.isWritable(data), false, "not writable")
    T.eq(Model.addSource(data, "Base.Hammer", ctx(), NOW), nil, "no add")
    T.eq(Model.removeEntry(data, "Base.Nails"), false, "no remove")
    T.eq(Model.setWanted(data, "Base.Nails", 3, NOW), false, "no setWanted")
    T.eq(data.rev, 9, "rev untouched")
    T.eq(data.schema, Model.SCHEMA + 1, "schema untouched")
end

function cases.hide_done_setting(T)
    local data = Model.newList()
    T.eq(Model.isHideDone(data), false, "off by default")
    T.eq(Model.setHideDone(data, true), true, "switched on")
    T.eq(Model.isHideDone(data), true, "on")
    T.eq(data.rev, 1, "rev counts the change")
    T.eq(Model.setHideDone(data, true), false, "no change")
    T.eq(data.rev, 1, "rev unchanged")
    local stored = { schema = 1, rev = 0, entries = {}, hideDone = "yes" }
    local repaired, status = Model.migrate(stored)
    T.eq(status, "repaired", "bad value repaired")
    T.eq(repaired.hideDone, nil, "bad value dropped")
end

local function group(alts, exclusive)
    return { kind = "group", group = { alts = alts, exclusive = exclusive }, sources = {}, note = "" }
end

function cases.member_types(T)
    T.same(Model.memberTypes("Base.Nails", { kind = "item", sources = {} }), { "Base.Nails" }, "item")
    local entry = group({ { type = "Base.Log", scale = 1 }, { type = "Base.Plank", scale = 3 } })
    T.same(Model.memberTypes("grp:x", entry), { "Base.Log", "Base.Plank" }, "group")
    T.ok(Model.isGroupKey("grp:[Base.Log;Base.Plank]"), "group key")
    T.ok(not Model.isGroupKey("Base.Log"), "item key")
end

function cases.measure_items_and_groups(T)
    local counts = { ["Base.Nails"] = 7, ["Base.Log"] = 1, ["Base.Plank"] = 7 }
    local function countOf(fullType)
        return counts[fullType] or 0
    end
    T.eq(Model.measure("Base.Nails", { kind = "item", sources = {} }, countOf), 7, "item")
    -- 1 log (1 per unit) plus 7 planks (3 per unit) = 1 + 2.33 units
    local mixed = group({ { type = "Base.Log", scale = 1 }, { type = "Base.Plank", scale = 3 } }, false)
    T.eq(Model.measure("grp:a", mixed, countOf), 3, "mixed alternatives add up")
    local exclusive = group({ { type = "Base.Log", scale = 1 }, { type = "Base.Plank", scale = 3 } }, true)
    T.eq(Model.measure("grp:b", exclusive, countOf), 2, "exclusive takes the best one")
end

function cases.migrate_drops_broken_groups(T)
    local stored = {
        schema = 1, rev = 0,
        entries = {
            ["grp:ok"] = { kind = "group", group = { alts = { { type = "Base.Log", scale = 1 } } }, sources = { { type = "craft_menu", recipeId = "Base.R", amount = 1 } }, note = "" },
            ["grp:bad"] = { kind = "group", group = { alts = {} }, sources = {}, note = "" },
            ["grp:worse"] = { kind = "group", sources = {}, note = "" },
        },
    }
    local data, status = Model.migrate(stored)
    T.eq(status, "repaired", "status")
    T.ok(Model.hasEntry(data, "grp:ok"), "valid group kept")
    T.ok(not Model.hasEntry(data, "grp:bad"), "empty group dropped")
    T.ok(not Model.hasEntry(data, "grp:worse"), "group without alternatives dropped")
end

return cases
