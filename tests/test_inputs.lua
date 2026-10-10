-- Craft input helpers and group entries.
local Model = require "ShoppingList/Model"
local Inputs = require "ShoppingList/Inputs"

local NOW = 1760000000

local cases = {}

function cases.source_of_lines(T)
    T.eq(Inputs.sourceOf("item 1 tags[base:hammer] mode:keep,"), "tags[base:hammer]", "tag tool")
    T.eq(Inputs.sourceOf("item 2 [Base.Log;3:Base.LargeBranch;6:Base.Plank] flags[IsExclusive]"),
        "[Base.Log;3:Base.LargeBranch;6:Base.Plank]", "list with amounts")
    T.eq(Inputs.sourceOf("  item variable[1:4] [Base.Twine;Base.Rope],"), "[Base.Twine;Base.Rope]", "variable amount")
    T.eq(Inputs.sourceOf("item 1 [*]"), nil, "any item has no group")
    T.eq(Inputs.sourceOf("-fluid 1.0 [Water]"), nil, "fluid line")
    T.eq(Inputs.sourceOf(nil), nil, "nil")
    T.eq(Inputs.sourceOf("item 1"), nil, "no source")
end

function cases.group_keys(T)
    T.eq(Inputs.groupKey("item 1 tags[base:hammer] mode:keep", false, "Base.A", 0), "grp:tags[base:hammer]", "tag key")
    T.eq(Inputs.groupKey("item 1 tags[base:hammer] mode:keep", false, "Base.B", 3), "grp:tags[base:hammer]", "same key from another recipe")
    T.eq(Inputs.groupKey("item 2 [Base.Log;Base.Plank]", true, "Base.A", 1), "grp:[Base.Log;Base.Plank]!", "exclusive")
    T.eq(Inputs.groupKey("garbage", false, "Base.A", 4), "grp:Base.A#4", "fallback")
    T.ok(Model.isGroupKey(Inputs.groupKey("garbage", false, "Base.A", 4)), "fallback is a group key")
end

function cases.wanted_units(T)
    T.eq(Inputs.wantedUnits(2), 2, "whole")
    T.eq(Inputs.wantedUnits(0.5), 1, "fraction rounds up")
    T.eq(Inputs.wantedUnits(0), 1, "at least 1")
    T.eq(Inputs.wantedUnits(nil), 1, "nil")
end

function cases.make_group_scales_by_unit(T)
    local group, cut = Inputs.makeGroup({
        { type = "Base.Log", amount = 2 },
        { type = "Base.LargeBranch", amount = 3 },
        { type = "Base.Plank", amount = 6 },
        { type = "Base.Plank", amount = 6 },
        { type = "Nails", amount = 1 },
    }, 1, true)
    T.eq(cut, false, "nothing cut")
    T.eq(#group.alts, 3, "duplicates and bad types dropped")
    T.eq(group.alts[1].scale, 2, "log: 2 per unit")
    T.eq(group.alts[3].scale, 6, "plank: 6 per unit")
    T.eq(group.exclusive, true, "exclusive")
    local even = Inputs.makeGroup({ { type = "Base.A", amount = 4 }, { type = "Base.B", amount = 4 } }, 4, false)
    T.eq(even.alts[1].scale, 1, "same amounts: one piece per unit")
end

function cases.make_group_caps_alternatives(T)
    local alts = {}
    for i = 1, Model.MAX_ALTS + 5 do
        alts[i] = { type = "Base.Item" .. i, amount = 1 }
    end
    local group, cut = Inputs.makeGroup(alts, 1, false)
    T.eq(#group.alts, Model.MAX_ALTS, "capped")
    T.eq(cut, true, "reported")
end

function cases.group_entry_from_two_recipes(T)
    local data = Model.newList()
    local group = Inputs.makeGroup({ { type = "Base.Hammer", amount = 1 }, { type = "Base.HammerStone", amount = 1 } }, 1, false)
    local key = "grp:tags[base:hammer]"
    local entry, created = Model.addGroupSource(data, key, group, { type = Model.CRAFT_MENU, recipeId = "Base.A", amount = 1, tool = true }, NOW)
    T.ok(entry ~= nil and created, "created")
    T.eq(entry.kind, "group", "kind")
    Model.addGroupSource(data, key, group, { type = Model.CRAFT_MENU, recipeId = "Base.B", amount = 1, tool = true }, NOW)
    T.eq(#entry.sources, 2, "two recipe sources")
    T.eq(Model.wanted(entry), 1, "tool needed once")
    T.same(Model.memberTypes(key, entry), { "Base.Hammer", "Base.HammerStone" }, "members")
    local function countOf(fullType)
        return fullType == "Base.HammerStone" and 1 or 0
    end
    T.ok(Model.isDone(entry, Model.measure(key, entry, countOf)), "one stone hammer is enough")
end

function cases.group_and_item_keys_do_not_mix(T)
    local data = Model.newList()
    local group = Inputs.makeGroup({ { type = "Base.A", amount = 1 } }, 1, false)
    T.eq(Model.addGroupSource(data, "Base.A", group, { type = Model.CRAFT_MENU, recipeId = "Base.R", amount = 1 }, NOW), nil, "item key refused")
    T.eq(Model.addSource(data, "grp:x", { type = Model.CONTEXT_MENU, amount = 1 }, NOW), nil, "group key refused for items")
    T.eq(Model.addSource(data, "grp:[Base.Log;Base.Plank]", { type = Model.CONTEXT_MENU, amount = 1 }, NOW), nil, "dotted group key refused for items")
    T.eq(Model.addGroupSource(data, "grp:x", { alts = {} }, { type = Model.CRAFT_MENU, recipeId = "Base.R", amount = 1 }, NOW), nil, "empty group refused")
end

return cases
