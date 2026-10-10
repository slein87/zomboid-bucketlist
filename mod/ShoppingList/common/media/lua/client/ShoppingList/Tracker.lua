-- Carried amounts per player, cached. Counting walks the whole inventory with
-- all bags, so it runs at most every REFRESH_MS, or at once after a signal
-- that the inventory changed. There is no event for item transfers (in
-- multiplayer they even run on the server), so the timer stays the fallback.
local Core = require "ShoppingList/Core"
local Model = require "ShoppingList/Model"
local Game = require "ShoppingList/Game"
local Store = require "ShoppingList/Store"

local Tracker = {}

local REFRESH_MS = 500
local states = {}

function Tracker.markDirty(playerNum)
    local state = states[playerNum]
    if state ~= nil then
        state.dirty = true
    end
end

function Tracker.markAllDirty()
    for _, state in pairs(states) do
        state.dirty = true
    end
end

-- Which entries an inventory item of a full type counts for. Item entries
-- match their own type; group entries (Phase 4) match each alternative.
local function buildIndex(data)
    local byType = {}
    for key, entry in pairs(data.entries) do
        local members = Model.memberTypes(key, entry)
        for i = 1, #members do
            local list = byType[members[i]]
            if list == nil then
                list = {}
                byType[members[i]] = list
            end
            list[#list + 1] = key
        end
    end
    return byType
end

local function recount(state, player, data)
    local have, wanted, open = {}, {}, {}
    local openCount, count = 0, 0
    for key, entry in pairs(data.entries) do
        local n = Model.measure(key, entry, function(fullType)
            return Game.countOf(player, fullType)
        end)
        have[key] = n
        wanted[key] = Model.wanted(entry)
        open[key] = n < wanted[key]
        count = count + 1
        if open[key] then
            openCount = openCount + 1
        end
    end
    state.have, state.wanted, state.open, state.openCount, state.count = have, wanted, open, openCount, count
end

-- Current state of a player's list: data, have/wanted/open per entry key and
-- the type index. Cheap when nothing changed.
function Tracker.state(playerNum)
    local player = Game.player(playerNum)
    if player == nil then
        return nil
    end
    local data = Store.get(player)
    if data == nil then
        return nil
    end
    local state = states[playerNum]
    if state == nil or state.player ~= player then
        state = { player = player, rev = -1, at = 0, dirty = true }
        states[playerNum] = state
    end
    local now = Game.nowMs()
    if state.rev ~= data.rev or state.data ~= data then
        state.byType = buildIndex(data)
        state.dirty = true
    end
    if state.dirty or now - state.at >= REFRESH_MS then
        recount(state, player, data)
        state.at = now
        state.dirty = false
    end
    state.rev = data.rev
    state.data = data
    return state
end

function Tracker.keysFor(state, fullType)
    if state == nil or fullType == nil then
        return {}
    end
    return state.byType[fullType] or {}
end

-- True when an item of this type still counts toward an open entry.
function Tracker.wants(state, fullType)
    local keys = Tracker.keysFor(state, fullType)
    for i = 1, #keys do
        if state.open[keys[i]] then
            return true
        end
    end
    return false
end

function Tracker.wantsItem(state, item)
    if item == nil or not instanceof(item, "InventoryItem") then
        return false
    end
    return Tracker.wants(state, item:getFullType())
end

-- "open" when an item of this type still counts toward an open entry, "done"
-- when it is listed but enough is carried, nil when it is not listed.
function Tracker.markOf(state, item)
    if item == nil or not instanceof(item, "InventoryItem") then
        return nil
    end
    local keys = Tracker.keysFor(state, item:getFullType())
    if #keys == 0 then
        return nil
    end
    for i = 1, #keys do
        if state.open[keys[i]] then
            return "open"
        end
    end
    return "done"
end

-- Signals that the player's inventory changed. The listeners
-- only set a flag; counting happens when someone asks.
Events.OnRefreshInventoryWindowContainers.Add(function(page, step)
    if step == "end" and page ~= nil and page.onCharacter then
        Tracker.markDirty(page.player)
    end
end)

Events.OnContainerUpdate.Add(function()
    Tracker.markAllDirty()
end)

-- Lua callers pass any character; only local players matter, the same guard
-- as ISCharacterInfoWindow (XpSystem/ISUI/ISCharacterInfoWindow.lua:346).
Events.OnClothingUpdated.Add(function(character)
    Core.try("Tracker.onClothingUpdated", function()
        if character ~= nil and instanceof(character, "IsoPlayer") and character:isLocalPlayer() then
            Tracker.markDirty(character:getPlayerNum())
        end
    end)
end)

ShoppingList.Tracker = Tracker
return Tracker
