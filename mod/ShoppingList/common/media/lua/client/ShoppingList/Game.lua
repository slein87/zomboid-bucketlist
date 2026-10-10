-- Every call into the game that ShoppingList makes goes through this adapter,
-- so a patch that moves something changes this file only. docs/API.md has the
-- source line for each call.
require "ShoppingList/Core"

local Game = {}

-- Player of a local index; splitscreen-safe, unlike getPlayer().
function Game.player(playerNum)
    if type(playerNum) ~= "number" then
        return nil
    end
    return getSpecificPlayer(playerNum)
end

function Game.modData(player)
    if player == nil then
        return nil
    end
    return player:getModData()
end

-- In multiplayer the server keeps the player record; mod data written on the
-- client reaches it only through transmitModData, the way the vanilla hotbar
-- saves its layout (Hotbar/ISHotbar.lua:670 to 676). Single player saves the
-- mod data with the character on its own.
function Game.transmit(player)
    if player ~= nil and isClient() then
        player:transmitModData()
    end
end

function Game.now()
    return getTimestamp()
end

function Game.nowMs()
    return getTimestampMs()
end

-- Script item of a full type, or nil. The script lookups fall back to the Base
-- module for unknown modules and FindItem then searches all modules by type
-- name, so an entry of a removed mod would otherwise show a same-named Base
-- item. Only an exact match counts.
function Game.scriptItem(fullType)
    if type(fullType) ~= "string" then
        return nil
    end
    local scriptItem = getScriptManager():FindItem(fullType)
    if scriptItem ~= nil and scriptItem:getFullName() == fullType then
        return scriptItem
    end
    return nil
end

-- Display name in the current language and whether the item exists.
function Game.itemName(fullType)
    local scriptItem = Game.scriptItem(fullType)
    if scriptItem ~= nil then
        return scriptItem:getDisplayName(), true
    end
    return tostring(fullType), false
end

-- Pieces in the main inventory including every carried bag; always with the
-- module, or same-named types of other modules would count.
function Game.countOf(player, fullType)
    if player == nil or type(fullType) ~= "string" then
        return 0
    end
    local inventory = player:getInventory()
    if inventory == nil then
        return 0
    end
    return inventory:getCountTypeRecurse(fullType)
end

-- Highlight colours from the game options, adjustable for colour blindness.
function Game.goodColor()
    local color = getCore():getGoodHighlitedColor()
    return color:getR(), color:getG(), color:getB()
end

function Game.badColor()
    local color = getCore():getBadHighlitedColor()
    return color:getR(), color:getG(), color:getB()
end

-- Craft recipe of a stored id ("Module.Name"), or nil. Like item lookups,
-- getCraftRecipe may fall back to Base for an unknown module, so only an exact
-- match counts.
function Game.recipe(recipeId)
    if type(recipeId) ~= "string" then
        return nil
    end
    local recipe = getScriptManager():getCraftRecipe(recipeId)
    if recipe ~= nil and recipe:getScriptObjectFullType() == recipeId then
        return recipe
    end
    return nil
end

-- Recipe name in the current language, or the id if the recipe is gone.
function Game.recipeName(recipeId)
    local recipe = Game.recipe(recipeId)
    if recipe ~= nil then
        return recipe:getTranslationName()
    end
    return tostring(recipeId)
end

function Game.version()
    local core = getCore()
    if core == nil then
        return "?"
    end
    return tostring(core:getVersion())
end

-- Unique full types of a context menu selection, in selection order. The
-- selection mixes single items and collapsed stacks; stacks group by display
-- name, so one row can hold several full types.
function Game.selectionTypes(items)
    local list, seen = {}, {}
    if type(items) ~= "table" then
        return list
    end
    local actual = ISInventoryPane.getActualItems(items)
    for i = 1, #actual do
        local item = actual[i]
        if item ~= nil and instanceof(item, "InventoryItem") then
            local fullType = item:getFullType()
            if fullType ~= nil and not seen[fullType] then
                seen[fullType] = true
                list[#list + 1] = fullType
            end
        end
    end
    return list
end

ShoppingList.Game = Game
return Game
