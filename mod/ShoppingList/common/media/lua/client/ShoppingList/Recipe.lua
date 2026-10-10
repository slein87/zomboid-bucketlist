-- Missing inputs of the recipe shown in the crafting window, turned into
-- list entries with the recipe as source. "Missing" is what the window marks
-- red (logic:isInputSatisfied), which also counts containers and the floor
-- nearby.
require "ShoppingList/Core"
local Model = require "ShoppingList/Model"
local Game = require "ShoppingList/Game"
local Store = require "ShoppingList/Store"
local Inputs = require "ShoppingList/Inputs"

local Recipe = {}

-- One wish per missing input, or nil when the input is not an item we can
-- list: automation-only, fluids and energy, and "[*]" (any item). With
-- force the input is wished for even when the window shows it as satisfied:
-- that is the right-click on a single input (DECISIONS D34).
function Recipe.wishFor(logic, recipe, input, player, recipeId, force)
    if input:isAutomationOnly() or input:getResourceType() ~= ResourceType.Item or input:isAcceptsAnyItem() then
        return nil
    end
    if not force and logic:isInputSatisfied(input) then
        return nil
    end
    local list = input:getPossibleInputItems()
    if list == nil or list:size() == 0 then
        return nil
    end
    local alts = {}
    for i = 0, list:size() - 1 do
        local scriptItem = list:get(i)
        local fullType = scriptItem:getFullName()
        alts[#alts + 1] = { type = fullType, amount = input:getAmount(fullType), scriptItem = scriptItem }
    end
    -- A container input with a fluid stays red while only the fluid is
    -- missing; a fitting container that is carried already stays off.
    if not force and input:hasConsumeFromItem() then
        for i = 1, #alts do
            if Game.countOf(player, alts[i].type) > 0 then
                return nil
            end
        end
    end
    local tool = input:isKeep() or input:isTool()
    -- Uses-based inputs (flour, tape) count uses, not pieces; one piece is the
    -- honest wish (DECISIONS D9).
    local uses = input:isUsesPartialItem(alts[1].scriptItem)
    if #alts == 1 then
        local amount = Inputs.wantedUnits(alts[1].amount)
        if uses then
            amount = 1
        end
        return { kind = "item", key = alts[1].type, amount = amount, tool = tool, recipeId = recipeId }
    end
    local unit = input:getAmount()
    if uses then
        for i = 1, #alts do
            alts[i].amount = 1
        end
        unit = 1
    end
    local group, cut = Inputs.makeGroup(alts, unit, input:isExclusive())
    if cut then
        ShoppingList.Core.debug("recipe " .. tostring(recipeId) .. ": alternatives cut at " .. Model.MAX_ALTS)
    end
    local key = Inputs.groupKey(input:getOriginalLine(), input:isExclusive(), recipeId, recipe:getIndexForIO(input))
    return { kind = "group", key = key, group = group, amount = Inputs.wantedUnits(unit), tool = tool, recipeId = recipeId }
end

function Recipe.missing(logic, player)
    local wishes = {}
    local recipe = logic and logic:getRecipe()
    if recipe == nil then
        return wishes, nil
    end
    local recipeId = recipe:getScriptObjectFullType()
    local inputs = recipe:getInputs()
    for i = 0, inputs:size() - 1 do
        local wish = Recipe.wishFor(logic, recipe, inputs:get(i), player, recipeId)
        if wish ~= nil then
            wishes[#wishes + 1] = wish
        end
    end
    return wishes, recipeId
end

-- Stores one wish as a craft source of its recipe; a second call replaces the
-- recipe's share instead of doubling it (DECISIONS D4).
function Recipe.store(data, wish, now)
    local source = { type = Model.CRAFT_MENU, recipeId = wish.recipeId, amount = wish.amount, tool = wish.tool }
    if wish.kind == "group" then
        return Model.addGroupSource(data, wish.key, wish.group, source, now)
    end
    return Model.addSource(data, wish.key, source, now)
end

-- Puts every missing input on the list of the panel's player; a second click
-- replaces the recipe's share instead of doubling it (DECISIONS D4). Returns
-- how many inputs are now on the list for this recipe.
function Recipe.addMissing(player, logic)
    local data, writable = Store.get(player)
    if not writable then
        return 0
    end
    local wishes = Recipe.missing(logic, player)
    local now = Game.now()
    local stored = 0
    for i = 1, #wishes do
        if Recipe.store(data, wishes[i], now) ~= nil then
            stored = stored + 1
        end
    end
    if stored > 0 then
        Store.changed(player)
    end
    return stored
end

-- The wish for one input of the logic's recipe, satisfied or not, or nil when
-- the input cannot be listed.
function Recipe.inputWish(logic, input, player)
    local recipe = logic and logic:getRecipe()
    if recipe == nil or input == nil then
        return nil
    end
    return Recipe.wishFor(logic, recipe, input, player, recipe:getScriptObjectFullType(), true)
end

-- True when the wish's entry already has a craft source of its recipe.
function Recipe.isListed(data, wish)
    local entry = Model.getEntry(data, wish.key)
    if entry == nil then
        return false
    end
    for i = 1, #entry.sources do
        if entry.sources[i].type == Model.CRAFT_MENU and entry.sources[i].recipeId == wish.recipeId then
            return true
        end
    end
    return false
end

function Recipe.addWish(player, wish)
    local data, writable = Store.get(player)
    if not writable or Recipe.store(data, wish, Game.now()) == nil then
        return false
    end
    Store.changed(player)
    return true
end

-- Takes back the recipe's share only; other sources keep the entry alive.
function Recipe.removeWish(player, wish)
    local data, writable = Store.get(player)
    if not writable or not Model.removeSource(data, wish.key, Model.CRAFT_MENU, wish.recipeId) then
        return false
    end
    Store.changed(player)
    return true
end

ShoppingList.Recipe = Recipe
return Recipe
