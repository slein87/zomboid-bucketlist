-- Texts and icons for entries, shared by the window, the tooltip and the
-- craft button. Names are looked up in the current language every time and
-- never stored.
require "Bucketlist/Core"
local Game = require "Bucketlist/Game"
local Text = require "Bucketlist/Text"
local Rows = require "Bucketlist/Rows"

local Labels = {}

local GROUP_NAMES_SHOWN = 3

-- Name of an entry and whether its item exists. A group lists the first
-- alternatives; the game has no translated names for tags.
function Labels.entryName(key, entry)
    if entry ~= nil and entry.kind == "group" then
        local alts = entry.group.alts
        local names = {}
        for i = 1, math.min(#alts, GROUP_NAMES_SHOWN) do
            names[#names + 1] = (Game.itemName(alts[i].type))
        end
        local text = table.concat(names, Text.get("IGUI_Bucketlist_Separator"))
        if #alts > GROUP_NAMES_SHOWN then
            text = Text.get("IGUI_Bucketlist_GroupMore", text, #alts - GROUP_NAMES_SHOWN)
        end
        return Text.get("IGUI_Bucketlist_GroupName", text), true
    end
    return Game.itemName(key)
end

-- Script item for the icon: the item itself, or the first alternative of a
-- group that still exists.
function Labels.entryIcon(key, entry)
    if entry ~= nil and entry.kind == "group" then
        local alts = entry.group.alts
        for i = 1, #alts do
            local scriptItem = Game.scriptItem(alts[i].type)
            if scriptItem ~= nil then
                return scriptItem
            end
        end
        return nil
    end
    return Game.scriptItem(key)
end

-- "Right-click, Recipe: Rope, Adjusted +4"
function Labels.sources(parts)
    local texts = {}
    for i = 1, #parts do
        local part = parts[i]
        if part.key == Rows.CRAFT then
            local name = Game.recipeName(part.recipeId)
            if part.tool then
                texts[#texts + 1] = Text.get("IGUI_Bucketlist_Source_CraftTool", name)
            else
                texts[#texts + 1] = Text.get(part.key, name)
            end
        elseif part.key == Rows.MANUAL then
            texts[#texts + 1] = Text.get(part.key, part.arg)
        else
            texts[#texts + 1] = Text.get(part.key)
        end
    end
    return table.concat(texts, Text.get("IGUI_Bucketlist_Separator"))
end

Bucketlist.Labels = Labels
return Labels
