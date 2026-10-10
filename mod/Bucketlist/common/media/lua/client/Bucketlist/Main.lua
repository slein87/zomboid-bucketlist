-- Wires the modules into the Bucketlist namespace and the player lifecycle.
-- Client files already run in the main menu, before any player exists, so all
-- player work waits for the events below.
local Core = require "Bucketlist/Core"
local Model = require "Bucketlist/Model"
local Rows = require "Bucketlist/Rows"
local Game = require "Bucketlist/Game"
local Store = require "Bucketlist/Store"
require "Bucketlist/Text"
require "Bucketlist/ContextMenu"
require "Bucketlist/Options"
require "Bucketlist/Tracker"
require "Bucketlist/Labels"
local Window = require "Bucketlist/Window"
require "Bucketlist/Sidebar"
require "Bucketlist/Highlight"
require "Bucketlist/Tooltip"
require "Bucketlist/Recipe"
require "Bucketlist/CraftButton"
require "Bucketlist/CraftInputMenu"

-- Model, Rows, Paint and Inputs stay free of game globals for the offline
-- tests, so they are attached here instead of in their own files.
Bucketlist.Model = Model
Bucketlist.Rows = Rows
Bucketlist.Paint = require "Bucketlist/Paint"
Bucketlist.Inputs = require "Bucketlist/Inputs"

Events.OnGameStart.Add(function()
    Core.try("OnGameStart", function()
        Core.log("version " .. Core.VERSION .. " on game " .. Game.version())
    end)
end)

-- Creates or repairs the list of each local player once the player exists.
-- No transmit here: the player may not stand on a square yet, and
-- transmitModData does nothing without one. The first
-- real change sends the list. The window of player 0 is built now, so the
-- game can restore its saved position and size.
Events.OnCreatePlayer.Add(function(playerNum, player)
    Core.try("OnCreatePlayer", function()
        local data, writable = Store.get(player)
        if data ~= nil then
            local suffix = ""
            if not writable then
                suffix = ", read only"
            end
            Core.log("player " .. tostring(playerNum) .. ": " .. Model.count(data) .. " entries" .. suffix)
        end
        Window.discard(playerNum)
        Window.get(playerNum)
    end)
end)

-- A dead character's list stays with that character; the window goes, so the
-- next character never shows the old list.
Events.OnPlayerDeath.Add(function(player)
    Core.try("OnPlayerDeath", function()
        if player ~= nil then
            Window.discard(player:getPlayerNum())
        end
    end)
end)

-- Fires twice when leaving the game; closing twice is harmless.
Events.OnPostSave.Add(function()
    Core.try("OnPostSave", Window.closeAll)
end)
