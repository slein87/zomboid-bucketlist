-- Button "Missing ingredients to Shopping List" under the craft controls of the
-- crafting window and of workbenches. ISCraftRecipePanel rebuilds its table in
-- createDynamicChildren on every recipe change, so a wrapper that runs after
-- the original adds one more table row each time.
-- The build menu has its own panel classes and gets no button in version 1.
require "Entity/ISUI/CraftRecipe/ISCraftRecipePanel"
local Core = require "ShoppingList/Core"
local Game = require "ShoppingList/Game"
local Text = require "ShoppingList/Text"
local Recipe = require "ShoppingList/Recipe"
local Hooks = require "ShoppingList/Hooks"

local CraftButton = {}

local BUTTON_HGT = getTextManager():getFontHeight(UIFont.Small) + 6
local FEEDBACK_MS = 2500

-- Active only while something is missing and no craft runs; missing skills,
-- light or recipe knowledge are no missing ingredients.
local function buttonPrerender(button)
    Core.try("CraftButton.prerender", function()
        local logic = button.target and button.target.logic
        local enable = logic ~= nil and logic:getRecipe() ~= nil
            and not logic:areAllInputItemsSatisfied() and not logic:isCraftActionInProgress()
        button:setEnable(enable)
        if button.shoppingListFeedbackUntil ~= nil and Game.nowMs() > button.shoppingListFeedbackUntil then
            button.shoppingListFeedbackUntil = nil
            button:setTitle(button.shoppingListTitle)
        end
    end)
    ISButton.prerender(button)
end

-- The panel knows its player; in splitscreen that is not getPlayer().
function CraftButton.onClick(panel, button)
    Core.try("CraftButton.onClick", function()
        local stored = Recipe.addMissing(panel.player, panel.logic)
        if stored > 0 then
            button:setTitle(Text.get("IGUI_ShoppingList_CraftAdded", stored))
        else
            button:setTitle(Text.get("IGUI_ShoppingList_CraftNothing"))
        end
        button.shoppingListFeedbackUntil = Game.nowMs() + FEEDBACK_MS
    end)
end

local function addButton(panel)
    if panel.rootTable == nil or panel.logic == nil or panel.logic:getRecipe() == nil or panel.player == nil then
        return
    end
    local title = Text.get("IGUI_ShoppingList_CraftAdd")
    -- Built like the vanilla craft button (ISWidgetHandCraftControl.lua:77).
    local button = ISXuiSkin.build(panel.xuiSkin, "S_NeedsAStyle", ISButton, 0, 0, 0, BUTTON_HGT, title)
    button.font = UIFont.Small
    button.target = panel
    button.onclick = CraftButton.onClick
    button.shoppingListTitle = title
    button:initialise()
    button:instantiate()
    button.prerender = buttonPrerender
    local row = panel.rootTable:addRow()
    panel.rootTable:setElement(0, row:index(), button)
    panel.shoppingListButton = button
    panel:xuiRecalculateLayout()
end

Hooks.after(ISCraftRecipePanel, "createDynamicChildren", "CraftButton.add", addButton)

ShoppingList.CraftButton = CraftButton
return CraftButton
