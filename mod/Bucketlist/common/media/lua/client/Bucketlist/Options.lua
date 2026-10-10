-- Mod options page "Bucketlist" (game options, tab MODS) and the hotkey that
-- toggles the window. Options must be registered while the file loads, before
-- the main menu builds its options; values are read at
-- the moment they are needed, never cached.
require "Bucketlist/Core"
local Core = require "Bucketlist/Core"

local Options = {}

-- Default key K: the only letter the game's default bindings leave free, and
-- in the same place on QWERTY, QWERTZ and AZERTY (docs/DECISIONS.md D11).
Options.DEFAULT_KEY = Keyboard.KEY_K

-- Highlight colour: amber by default, apart from vanilla white (selection),
-- red (cannot drop), cyan (controller) and the rarity colours of Item Rarity UI.
Options.DEFAULT_COLOR = { r = 1.0, g = 0.75, b = 0.15 }

local page = nil
local keyOption = nil
local colorOption = nil

if PZAPI and PZAPI.ModOptions then
    page = PZAPI.ModOptions:create(Core.MOD_ID, "UI_Bucketlist_Options_Title")
    -- The key binding needs its name already translated: MainOptions matches
    -- the raw name when the player rebinds the key.
    keyOption = page:addKeyBind("toggleWindow", getText("UI_Bucketlist_Options_Hotkey"), Options.DEFAULT_KEY,
        getText("UI_Bucketlist_Options_Hotkey_Tooltip"))
    -- Other option names are keys; MainOptions translates them.
    local c = Options.DEFAULT_COLOR
    colorOption = page:addColorPicker("highlightColor", "UI_Bucketlist_Options_Color", c.r, c.g, c.b, 1,
        "UI_Bucketlist_Options_Color_Tooltip")
end

Options.page = page

-- Current key code, 0 when unbound.
function Options.toggleKey()
    if keyOption ~= nil then
        return keyOption:getValue() or 0
    end
    return Options.DEFAULT_KEY
end

-- Current highlight colour as r, g, b from 0 to 1. The picker hands out its
-- colour table, which MainOptions may replace; read it fresh every time and
-- never change it.
function Options.highlightColor()
    local c = colorOption and colorOption:getValue()
    if type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
        return c.r, c.g, c.b
    end
    c = Options.DEFAULT_COLOR
    return c.r, c.g, c.b
end

-- For the dev tests: bind the key without the options screen.
function Options.setToggleKey(key)
    if keyOption ~= nil then
        keyOption:setValue(key)
    end
end

-- OnKeyPressed fires when the key is released; Java skips Lua key events
-- while a text field has focus.
Events.OnKeyPressed.Add(function(key)
    Core.try("Options.onKey", function()
        local wanted = Options.toggleKey()
        if wanted == nil or wanted == 0 or key ~= wanted then
            return
        end
        local player = getSpecificPlayer(0)
        if player == nil or player:isDead() or Bucketlist.Window == nil then
            return
        end
        -- The in-game menu hides all game UI; vanilla hotkeys check the same
        -- (ISUI/ISPostDeathUI.lua:234). No game speed test: the window may
        -- open while the game is paused.
        if MainScreen.instance ~= nil and MainScreen.instance:isVisible() then
            return
        end
        Bucketlist.Window.toggle(0)
    end)
end)

Bucketlist.Options = Options
return Options
