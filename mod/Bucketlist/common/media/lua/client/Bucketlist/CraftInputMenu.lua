-- Right-click on a single input of the crafting window: add it to the list or
-- take it off again, next to the button that adds everything missing.
-- ISWidgetInput has no right-click handler of its own; it inherits the empty
-- ones of ISUIElement, so the wrappers below replace nothing. Clicks on a
-- child (icon, label) reach the widget as "outside" calls, which vanilla
-- sorts out with isMouseOver for left clicks
-- (Entity/ISUI/CraftRecipe/ISWidgetInput.lua:303). The
-- build menu uses the same widget and gets the menu too.
require "Entity/ISUI/CraftRecipe/ISWidgetInput"
local Core = require "Bucketlist/Core"
local Game = require "Bucketlist/Game"
local Store = require "Bucketlist/Store"
local Text = require "Bucketlist/Text"
local Recipe = require "Bucketlist/Recipe"
local Hooks = require "Bucketlist/Hooks"

local CraftInputMenu = {}

-- One click can arrive through both callbacks; the second one is dropped.
local REPEAT_MS = 100

function CraftInputMenu.onAdd(player, wish)
    Core.try("CraftInputMenu.onAdd", Recipe.addWish, player, wish)
end

function CraftInputMenu.onRemove(player, wish)
    Core.try("CraftInputMenu.onRemove", Recipe.removeWish, player, wish)
end

-- Builds the menu for a widget, or returns nil when there is nothing to
-- offer: output widgets, inputs that are no listable item, read-only lists.
function CraftInputMenu.open(widget)
    if widget.displayAsOutput or widget.inputScript == nil or widget.logic == nil then
        return nil
    end
    local player = widget.player
    if player == nil or not instanceof(player, "IsoPlayer") then
        return nil
    end
    local data, writable = Store.get(player)
    if not writable then
        return nil
    end
    local wish = Recipe.inputWish(widget.logic, widget.inputScript, player)
    if wish == nil then
        return nil
    end
    local context = ISContextMenu.get(player:getPlayerNum(), getMouseX(), getMouseY())
    if Recipe.isListed(data, wish) then
        context:addOption(Text.get("ContextMenu_Bucketlist_Remove"), player, CraftInputMenu.onRemove, wish)
    else
        context:addOption(Text.get("ContextMenu_Bucketlist_Add"), player, CraftInputMenu.onAdd, wish)
    end
    return context
end

local function click(widget)
    local now = Game.nowMs()
    if widget.bucketlistMenuAt ~= nil and now - widget.bucketlistMenuAt < REPEAT_MS then
        return
    end
    widget.bucketlistMenuAt = now
    CraftInputMenu.open(widget)
end

local function clickOutside(widget)
    if widget:isMouseOver() then
        click(widget)
    end
end

Hooks.after(ISWidgetInput, "onRightMouseUp", "CraftInputMenu.click", click)
Hooks.after(ISWidgetInput, "onRightMouseUpOutside", "CraftInputMenu.clickOutside", clickOutside)

Bucketlist.CraftInputMenu = CraftInputMenu
return CraftInputMenu
