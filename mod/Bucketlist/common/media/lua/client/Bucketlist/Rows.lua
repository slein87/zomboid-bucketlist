-- Rows of the management window: which entries show, in which order, and the
-- pieces their texts are made of. No game calls in here; names and counts are
-- handed in as functions, so tests/run.lua covers all of it with Lua 5.1.
local Model = require "Bucketlist/Model"

local Rows = {}

-- Text keys of the source parts; the window turns parts into text with getText.
Rows.CONTEXT = "IGUI_Bucketlist_Source_ContextMenu"
Rows.CRAFT = "IGUI_Bucketlist_Source_Craft"
Rows.MANUAL = "IGUI_Bucketlist_Source_Manual"

-- "+4" or "-2"; string.format keeps whole numbers free of a trailing ".0".
function Rows.signed(n)
    local value = tonumber(n) or 0
    if value > 0 then
        return "+" .. string.format("%d", value)
    end
    return string.format("%d", value)
end

-- Where an entry comes from, in a fixed order: right-click, recipes by id,
-- the manual correction last.
function Rows.sourceParts(entry)
    local parts, crafts = {}, {}
    local manual = 0
    for i = 1, #entry.sources do
        local source = entry.sources[i]
        if source.type == Model.CONTEXT_MENU then
            parts[#parts + 1] = { key = Rows.CONTEXT }
        elseif source.type == Model.CRAFT_MENU then
            crafts[#crafts + 1] = { key = Rows.CRAFT, recipeId = source.recipeId, amount = source.amount, tool = source.tool == true }
        elseif source.type == Model.MANUAL then
            manual = manual + (tonumber(source.amount) or 0)
        end
    end
    table.sort(crafts, function(a, b)
        return tostring(a.recipeId) < tostring(b.recipeId)
    end)
    for i = 1, #crafts do
        parts[#parts + 1] = crafts[i]
    end
    if manual ~= 0 then
        parts[#parts + 1] = { key = Rows.MANUAL, arg = Rows.signed(manual) }
    end
    return parts
end

-- Open entries first, then done ones; inside each group by name, the key
-- breaks ties so the order never depends on the sort algorithm (table.sort is
-- unstable in Kahlua).
function Rows.less(a, b)
    if a.done ~= b.done then
        return not a.done
    end
    if a.sortName ~= b.sortName then
        return a.sortName < b.sortName
    end
    return a.key < b.key
end

-- nameOf(key, entry) -> name, available; countOf(key) -> amount carried.
function Rows.build(data, nameOf, countOf, hideDone)
    local rows = {}
    local keys = Model.keys(data)
    for i = 1, #keys do
        local key = keys[i]
        local entry = data.entries[key]
        local name, available = nameOf(key, entry)
        name = tostring(name or key)
        local have = tonumber(countOf(key)) or 0
        local wanted = Model.wanted(entry)
        local done = have >= wanted
        if not (hideDone and done) then
            rows[#rows + 1] = {
                key = key,
                name = name,
                sortName = string.lower(name),
                available = available == true,
                have = have,
                wanted = wanted,
                done = done,
                note = entry.note or "",
                parts = Rows.sourceParts(entry),
            }
        end
    end
    table.sort(rows, Rows.less)
    return rows
end

-- Same keys in the same order: the window can update rows in place instead of
-- rebuilding the list.
function Rows.sameOrder(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i].key ~= b[i].key then
            return false
        end
    end
    return true
end

-- Player text goes into rich-text tooltips, where "<...>" would act as a
-- command.
function Rows.escape(text)
    local s = string.gsub(tostring(text or ""), "<", "&lt;")
    s = string.gsub(s, ">", "&gt;")
    return s
end

-- One line, for the second row line: line breaks become spaces.
function Rows.flatten(text)
    local s = string.gsub(tostring(text or ""), "%s+", " ")
    return s
end

-- Splits text into lines of at most width characters at blanks; longer words
-- are cut. Line breaks in the text start a new line. Tooltips do not wrap on
-- their own (ISScrollingListBox sets maxLineWidth 1000).
function Rows.wrap(text, width)
    local lines = {}
    local source = tostring(text or "") .. "\n"
    for paragraph in string.gmatch(source, "([^\n]*)\n") do
        local line = ""
        for word in string.gmatch(paragraph, "%S+") do
            while string.len(word) > width do
                if line ~= "" then
                    lines[#lines + 1] = line
                    line = ""
                end
                lines[#lines + 1] = string.sub(word, 1, width)
                word = string.sub(word, width + 1)
            end
            if line == "" then
                line = word
            elseif string.len(line) + 1 + string.len(word) <= width then
                line = line .. " " .. word
            else
                lines[#lines + 1] = line
                line = word
            end
        end
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    return lines
end

return Rows
