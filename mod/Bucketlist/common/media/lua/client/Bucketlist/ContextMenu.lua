-- Right-click option for items. Inventory and loot windows, hotbar, hand slots
-- and bag buttons all build their menu in ISInventoryPaneContextMenu.createMenu,
-- which fires OnFillInventoryObjectContextMenu at its end. One handler covers
-- all of them; no vanilla function is replaced.
local Core = require "Bucketlist/Core"
local Model = require "Bucketlist/Model"
local Game = require "Bucketlist/Game"
local Store = require "Bucketlist/Store"
local Text = require "Bucketlist/Text"

local ContextMenu = {}

local function listable(types)
    local list = {}
    for i = 1, #types do
        if Model.canList(types[i]) then
            list[#list + 1] = types[i]
        end
    end
    return list
end

-- Menu targets are the player index and plain full-type strings, never item
-- objects: items may be moved or used up before the click.
local function add(playerNum, types)
    local player = Game.player(playerNum)
    local data, writable = Store.get(player)
    if not writable then
        return
    end
    local now = Game.now()
    local added = 0
    for i = 1, #types do
        if not Model.hasEntry(data, types[i])
            and Model.addSource(data, types[i], { type = Model.CONTEXT_MENU, amount = 1 }, now) then
            added = added + 1
        end
    end
    if added > 0 then
        Store.changed(player)
        Core.debug("added " .. added .. ", list has " .. Model.count(data))
    end
end

local function remove(playerNum, types)
    local player = Game.player(playerNum)
    local data, writable = Store.get(player)
    if not writable then
        return
    end
    local removed = 0
    for i = 1, #types do
        if Model.removeEntry(data, types[i]) then
            removed = removed + 1
        end
    end
    if removed > 0 then
        Store.changed(player)
        Core.debug("removed " .. removed .. ", list has " .. Model.count(data))
    end
end

function ContextMenu.onAdd(playerNum, types)
    Core.try("ContextMenu.onAdd", add, playerNum, types)
end

function ContextMenu.onRemove(playerNum, types)
    Core.try("ContextMenu.onRemove", remove, playerNum, types)
end

-- One option at the end of the menu: "add" for the types not yet listed, or
-- "remove" when every selected type is listed already (DECISIONS D6).
function ContextMenu.fill(playerNum, context, items)
    local player = Game.player(playerNum)
    if player == nil or context == nil then
        return
    end
    local data, writable = Store.get(player)
    if not writable then
        return
    end
    local types = listable(Game.selectionTypes(items))
    if #types == 0 then
        return
    end
    local listed, missing = Model.split(data, types)
    if #missing > 0 then
        local label = Text.get("ContextMenu_Bucketlist_Add")
        if #missing > 1 then
            label = Text.get("ContextMenu_Bucketlist_AddCount", #missing)
        end
        context:addOption(label, playerNum, ContextMenu.onAdd, missing)
    else
        local label = Text.get("ContextMenu_Bucketlist_Remove")
        if #listed > 1 then
            label = Text.get("ContextMenu_Bucketlist_RemoveCount", #listed)
        end
        context:addOption(label, playerNum, ContextMenu.onRemove, listed)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    Core.try("ContextMenu.fill", ContextMenu.fill, playerNum, context, items)
end)

Bucketlist.ContextMenu = ContextMenu
return ContextMenu
