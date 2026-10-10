-- The list of each player lives in the player's own mod data under one key
-- (docs/DECISIONS.md D4, D5). Changes go straight into that table; nothing
-- waits for OnSave, which comes after the player is already saved.
local Core = require "ShoppingList/Core"
local Model = require "ShoppingList/Model"
local Game = require "ShoppingList/Game"

local Store = {}

Store.KEY = "ShoppingList"
-- Key of versions 1.0.x, when the mod was called Bucketlist.
Store.OLD_KEY = "Bucketlist"

local warnedNewer = false

-- Stored list tables already checked, with their writable flag. A new
-- character or a list replaced over the network is a new table and is checked
-- again; the model's write functions keep a checked table valid. Checking on
-- every call would walk all entries every frame (highlight, tooltip, window).
local checked = {}
local checkedCount = 0

local function remember(data, writable)
    if checkedCount >= 16 then
        checked = {}
        checkedCount = 0
    end
    if checked[data] == nil then
        checkedCount = checkedCount + 1
    end
    checked[data] = writable
end

-- Returns the list of a player and whether it may be written. A missing or
-- damaged list is created or repaired in place; a list saved by a newer
-- ShoppingList is handed out read-only and never written.
function Store.get(player)
    local modData = Game.modData(player)
    if modData == nil then
        return nil, false
    end
    if Model.adoptOldKey(modData, Store.KEY, Store.OLD_KEY) then
        Core.log("list taken over from the old key " .. Store.OLD_KEY)
        Game.transmit(player)
    end
    local stored = modData[Store.KEY]
    if type(stored) == "table" and checked[stored] ~= nil then
        return stored, checked[stored]
    end
    local data, status = Model.migrate(stored)
    if status == "newer" then
        if not warnedNewer then
            warnedNewer = true
            Core.log("list was saved by a newer ShoppingList (schema " .. tostring(data.schema) .. "), read only")
        end
        remember(data, false)
        return data, false
    end
    if status ~= "ok" then
        modData[Store.KEY] = data
        if status == "repaired" then
            Core.log("list repaired, broken entries dropped")
        end
    end
    remember(data, true)
    return data, true
end

-- Call after every change. The list already sits in the mod data, so this
-- only has to reach the server in multiplayer.
function Store.changed(player)
    Game.transmit(player)
end

ShoppingList.Store = Store
return Store
