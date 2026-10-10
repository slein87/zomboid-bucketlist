-- Button in the left sidebar under the vanilla buttons, toggling the window.
-- ISEquippedItem:initialise builds the sidebar (only player 0 gets buttons)
-- and runs again whenever the player changes the sidebar size, so a wrapper
-- that calls the original first and then adds our button covers every
-- rebuild. No vanilla function is replaced.
require "ISUI/ISEquippedItem"
local Core = require "ShoppingList/Core"
local Text = require "ShoppingList/Text"
local Options = require "ShoppingList/Options"

local Sidebar = {}

local SIZES = { 48, 64, 80, 96, 128 }
local textures = {}

-- Vanilla ships one picture per sidebar size (media/ui/Sidebar/<size>/); ours
-- follow the same sizes and names carry the mod prefix, because getTexture
-- looks pictures up by file name first.
local function texture(state, width)
    local size = SIZES[1]
    for i = 1, #SIZES do
        if SIZES[i] <= width then
            size = SIZES[i]
        end
    end
    local path = "media/ui/ShoppingList/ShoppingList_Sidebar_" .. state .. "_" .. size .. ".png"
    if textures[path] == nil then
        textures[path] = getTexture(path)
    end
    return textures[path]
end

function Sidebar.tooltip()
    local key = Options.toggleKey()
    if key ~= nil and key ~= 0 then
        return Text.get("IGUI_ShoppingList_SidebarTooltipKey", Keyboard.getKeyName(key))
    end
    return Text.get("IGUI_ShoppingList_SidebarTooltip")
end

local function onClick(equipped, button)
    Core.try("Sidebar.onClick", function()
        if ShoppingList.Window ~= nil then
            ShoppingList.Window.toggle(equipped.chr:getPlayerNum())
        end
    end)
end

-- Image follows the window, the tooltip follows the key binding.
local function buttonPrerender(button)
    Core.try("Sidebar.prerender", function()
        local open = ShoppingList.Window ~= nil and ShoppingList.Window.isOpen(0)
        if open then
            button:setImage(button.shoppingListOn)
        else
            button:setImage(button.shoppingListOff)
        end
        local key = Options.toggleKey()
        if button.shoppingListTooltipEntry ~= nil and button.shoppingListKey ~= key then
            button.shoppingListKey = key
            button.shoppingListTooltipEntry.displayString = Sidebar.tooltip()
        end
    end)
    ISButton.prerender(button)
end

function Sidebar.addButton(equipped)
    if equipped.invBtn == nil or equipped.shoppingListBtn ~= nil then
        return
    end
    -- Below the lowest button, so buttons of other mods are not covered; the
    -- 15 px gap is the vanilla UI_BORDER_SPACING + 5.
    local bottom = 0
    for _, child in pairs(equipped:getChildren()) do
        if child.Type == "ISButton" then
            bottom = math.max(bottom, child:getBottom())
        end
    end
    local width = equipped.invBtn:getWidth()
    local height = equipped.invBtn:getHeight()
    local button = ISButton:new(0, bottom + 15, width, height, "", equipped, onClick)
    button.internal = "SHOPPINGLIST"
    button.shoppingListOn = texture("On", width)
    button.shoppingListOff = texture("Off", width)
    button:setImage(button.shoppingListOff)
    button:initialise()
    button:instantiate()
    button:setDisplayBackground(false)
    button:ignoreWidthChange()
    button:ignoreHeightChange()
    button.prerender = buttonPrerender
    equipped:addChild(button)
    equipped:addMouseOverToolTipItem(button, Sidebar.tooltip())
    local list = equipped.mouseOverList
    if list ~= nil and list[#list] ~= nil and list[#list].object == button then
        button.shoppingListTooltipEntry = list[#list]
        button.shoppingListKey = Options.toggleKey()
    end
    equipped.shoppingListBtn = button
    -- shrinkWrap counts only children of Type "ISButton", which a plain
    -- ISButton is (ISUI/ISEquippedItem.lua:972).
    equipped:shrinkWrap()
end

local original = ISEquippedItem.initialise

function ISEquippedItem:initialise(...)
    local result = original(self, ...)
    Core.try("Sidebar.addButton", Sidebar.addButton, self)
    return result
end

ShoppingList.Sidebar = Sidebar
return Sidebar
