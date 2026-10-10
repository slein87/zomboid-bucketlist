-- Development helper, not part of Bucketlist. The cases behind
-- tools/start-game.sh --test <name>:
--   context  right-click option: build the vanilla item menu the way a click
--            does (ISInventoryPaneContextMenu.createMenu), find our option,
--            select it, check the stored list
--   window   management window: open, rows, names, amounts, both dialogs,
--            hide done, delete with two clicks, sidebar button, hotkey
--   highlight inventory rows of open entries are marked, done ones not;
--            tooltip lines; carried amounts follow the inventory
--   craft    crafting window on Base.CraftRope: our button, missing inputs
--            become group entries with the recipe as source, no doubling
--   tour     no checks worth the name: shows window, highlight, tooltip,
--            dialogs, menus, options one after the other and takes a
--            screenshot of each (Screenshots/ in the user folder)
--   options  opens the pause menu on the mod options page for a screenshot
--   persist  after loading the save of "all": everything is still there
--   all      context, window, highlight and craft, then save and quit, load
--            the save again, then persist
require "BucketlistDev/Request"
require "BucketlistDev/TestSeq"

BucketlistDev = BucketlistDev or {}

local Seq = BucketlistDev.TestSeq
local Cases = {}

Cases.NAMES = { context = true, window = true, highlight = true, craft = true, persist = true, all = true, tour = true, options = true }

local NAILS = "Base.Nails"
local HAMMER = "Base.Hammer"
local PLANK = "Base.Plank"
local NOTE = "for the shed"
local MENU_X, MENU_Y = 300, 300

local function player()
    return getSpecificPlayer(0)
end

local function list()
    return Bucketlist.Store.get(player())
end

local function Model()
    return Bucketlist.Model
end

-- Builds the item menu like a right-click in the inventory window, returns
-- our option (or nil) and closes the menu again.
local function menuOption(items, label)
    local context = ISInventoryPaneContextMenu.createMenu(0, true, items, MENU_X, MENU_Y)
    if context == nil then
        return nil, "no menu (game paused?)"
    end
    local option = context:getOptionFromName(label)
    context:closeAll()
    return option
end

local function choose(option)
    option.onSelect(option.target, option.param1, option.param2)
end

local function sourcesOf(key)
    local entry = Model().getEntry(list(), key)
    if entry == nil then
        return nil
    end
    return entry.sources
end

local function hasContextSource(key)
    local sources = sourcesOf(key)
    if sources == nil then
        return false
    end
    for i = 1, #sources do
        if sources[i].type == Model().CONTEXT_MENU and sources[i].amount == 1 then
            return true
        end
    end
    return false
end

local function onlyContextSource(key)
    local sources = sourcesOf(key)
    return sources ~= nil and #sources == 1 and hasContextSource(key)
end

local function addContextSteps(seq, scope, state)
    local T = "context"
    seq:add(Seq.action(scope, "setup", function(_, s)
        local data, writable = list()
        s:check(data ~= nil and writable, T, "setup.list", "writable " .. tostring(writable))
        Model().removeEntry(data, NAILS)
        Model().removeEntry(data, HAMMER)
        local inv = player():getInventory()
        state.nails = inv:AddItem(NAILS)
        state.hammer = inv:AddItem(HAMMER)
        s:check(state.nails ~= nil and state.hammer ~= nil, T, "setup.items", NAILS .. ", " .. HAMMER)
        state.rev = data.rev
    end))
    seq:add(Seq.action(scope, "add.single", function(_, s)
        local option, why = menuOption({ state.nails }, getText("ContextMenu_Bucketlist_Add"))
        if not s:check(option ~= nil, T, "add.single.option", why or (option and "found" or "missing")) then
            scope.aborted = true
            return
        end
        choose(option)
        s:check(onlyContextSource(NAILS), T, "add.single.stored", "one context_menu source, amount 1")
        s:check(list().rev == state.rev + 1, T, "add.single.rev", "rev " .. tostring(list().rev))
        local stored = player():getModData().Bucketlist
        s:check(stored ~= nil and stored.schema == 1, T, "add.single.moddata", "schema " .. tostring(stored and stored.schema))
    end))
    seq:add(Seq.action(scope, "remove.single", function(_, s)
        local option = menuOption({ state.nails }, getText("ContextMenu_Bucketlist_Remove"))
        if not s:check(option ~= nil, T, "remove.single.option", "found") then
            return
        end
        choose(option)
        s:check(not Model().hasEntry(list(), NAILS), T, "remove.single.gone", NAILS)
    end))
    seq:add(Seq.action(scope, "add.multi", function(_, s)
        local option = menuOption({ state.nails, state.hammer }, getText("ContextMenu_Bucketlist_AddCount", 2))
        if not s:check(option ~= nil, T, "add.multi.option", "label with count 2") then
            return
        end
        choose(option)
        s:check(onlyContextSource(NAILS) and onlyContextSource(HAMMER), T, "add.multi.stored", "both listed once")
    end))
    seq:add(Seq.action(scope, "add.mixed", function(_, s)
        Model().removeEntry(list(), HAMMER)
        local option = menuOption({ state.nails, state.hammer }, getText("ContextMenu_Bucketlist_Add"))
        if not s:check(option ~= nil, T, "add.mixed.option", "plain add for the one missing type") then
            return
        end
        choose(option)
        s:check(onlyContextSource(HAMMER), T, "add.mixed.added", HAMMER)
        s:check(onlyContextSource(NAILS), T, "add.mixed.untouched", NAILS .. " not doubled")
    end))
    seq:add(Seq.action(scope, "remove.offer", function(_, s)
        local option = menuOption({ state.nails, state.hammer }, getText("ContextMenu_Bucketlist_RemoveCount", 2))
        s:check(option ~= nil, T, "remove.offer.option", "remove with count 2 when all are listed")
    end))
end

local function rowOf(window, key)
    local items = window.list.items
    for i = 1, #items do
        if items[i].item.key == key then
            return items[i].item, i
        end
    end
    return nil, nil
end

-- Fills a dialog the way a player would and presses its OK button.
local function confirmDialog(window, text)
    local box = window.dialog
    if box == nil then
        return false
    end
    box.entry:setText(text)
    box:onClick(box.yes)
    return true
end

local function addWindowSteps(seq, scope)
    local T = "window"
    local function W()
        return Bucketlist.Window.get(0)
    end
    seq:add(Seq.action(scope, "setup", function(_, s)
        local data = list()
        local inv = player():getInventory()
        local keys = { NAILS, HAMMER }
        for i = 1, #keys do
            if not Model().hasEntry(data, keys[i]) then
                Model().addSource(data, keys[i], { type = Model().CONTEXT_MENU, amount = 1 }, getTimestamp())
            end
            if inv:getCountTypeRecurse(keys[i]) == 0 then
                inv:AddItem(keys[i])
            end
        end
        Model().setHideDone(data, false)
        Bucketlist.Window.close(0)
        s:check(not Bucketlist.Window.isOpen(0), T, "setup.closed", "window closed before the test")
    end))
    seq:add(Seq.action(scope, "open", function(_, s)
        Bucketlist.Window.toggle(0)
        s:check(Bucketlist.Window.isOpen(0), T, "open.toggle", "toggle opens the window")
        W():refresh(true)
        s:check(#W().list.items == Model().count(list()), T, "open.rows",
            #W().list.items .. " rows for " .. Model().count(list()) .. " entries")
    end))
    seq:add(Seq.action(scope, "row", function(_, s)
        local row = rowOf(W(), NAILS)
        if not s:check(row ~= nil, T, "row.found", NAILS) then
            scope.aborted = true
            return
        end
        s:check(row.available and row.name ~= NAILS and row.scriptItem ~= nil, T, "row.name", "name " .. tostring(row.name))
        local have = player():getInventory():getCountTypeRecurse(NAILS)
        s:check(row.have == have, T, "row.have", "have " .. tostring(row.have) .. ", inventory " .. tostring(have))
        s:check(row.wanted == 1 and row.done == (have >= 1), T, "row.wanted", "wanted " .. tostring(row.wanted))
        s:check(type(row.tooltip) == "string" and row.tooltip ~= "", T, "row.tooltip", "tooltip text")
    end))
    seq:add(Seq.action(scope, "amount", function(_, s)
        local w = W()
        local _, index = rowOf(w, NAILS)
        w.list.selected = index
        w:onButton(w.btnAmount)
        s:check(confirmDialog(w, "5"), T, "amount.dialog", "dialog opened and confirmed")
        local entry = Model().getEntry(list(), NAILS)
        s:check(entry ~= nil and Model().wanted(entry) == 5, T, "amount.stored", "wanted " .. tostring(entry and Model().wanted(entry)))
        s:check(entry ~= nil and Model().manualAmount(entry) == 4, T, "amount.manual", "manual source +4")
    end))
    seq:add(Seq.action(scope, "note", function(_, s)
        local w = W()
        w:refresh(true)
        local _, index = rowOf(w, NAILS)
        w.list.selected = index
        w:onButton(w.btnNote)
        s:check(confirmDialog(w, NOTE), T, "note.dialog", "dialog opened and confirmed")
        local entry = Model().getEntry(list(), NAILS)
        s:check(entry ~= nil and entry.note == NOTE, T, "note.stored", "note " .. tostring(entry and entry.note))
    end))
    seq:add(Seq.action(scope, "hide", function(_, s)
        local w = W()
        w:onTick(1, true)
        s:check(Model().isHideDone(list()), T, "hide.stored", "hideDone on")
        w:refresh(true)
        s:check(rowOf(w, HAMMER) == nil, T, "hide.filtered", "done hammer (1 of 1) hidden")
        s:check(rowOf(w, NAILS) ~= nil, T, "hide.open.kept", "open nails still shown")
    end))
    seq:add(Seq.action(scope, "delete", function(_, s)
        local w = W()
        Model().addSource(list(), PLANK, { type = Model().CONTEXT_MENU, amount = 1 }, getTimestamp())
        w:refresh(true)
        local row, index = rowOf(w, PLANK)
        if not s:check(row ~= nil, T, "delete.row", PLANK) then
            return
        end
        w.list.selected = index
        w:onButton(w.btnDelete)
        s:check(Model().hasEntry(list(), PLANK), T, "delete.first.click", "first click only asks")
        w:onButton(w.btnDelete)
        s:check(not Model().hasEntry(list(), PLANK), T, "delete.second.click", "second click deletes")
    end))
    seq:add(Seq.action(scope, "sidebar", function(_, s)
        local data = getPlayerData(0)
        local button = data and data.equipped and data.equipped.bucketlistBtn
        if not s:check(button ~= nil, T, "sidebar.button", "button in the sidebar") then
            return
        end
        local open = Bucketlist.Window.isOpen(0)
        button.onclick(button.target, button)
        s:check(Bucketlist.Window.isOpen(0) ~= open, T, "sidebar.toggle", "click toggles the window")
        button.onclick(button.target, button)
        s:check(Bucketlist.Window.isOpen(0) == open, T, "sidebar.toggle.back", "second click toggles back")
    end))
    seq:add(Seq.action(scope, "hotkey", function(_, s)
        local key = Bucketlist.Options.toggleKey()
        s:check(key == Keyboard.KEY_K, T, "hotkey.default", "key " .. tostring(key))
        local open = Bucketlist.Window.isOpen(0)
        triggerEvent("OnKeyPressed", key)
        s:check(Bucketlist.Window.isOpen(0) ~= open, T, "hotkey.toggle", "key toggles the window")
        Bucketlist.Window.close(0)
    end))
end

-- Row index of the inventory pane that shows an item of this type.
local function paneRowOf(pane, fullType)
    local items = pane.items or {}
    for i = 1, #items do
        local entry = items[i]
        if instanceof(entry, "InventoryItem") then
            if entry:getFullType() == fullType then
                return i
            end
        elseif type(entry) == "table" and type(entry.items) == "table" then
            for j = 1, #entry.items do
                if entry.items[j]:getFullType() == fullType then
                    return i
                end
            end
        end
    end
    return nil
end

local function contains(list, value)
    for i = 1, #list do
        if list[i] == value then
            return true
        end
    end
    return false
end

local function addHighlightSteps(seq, scope)
    local T = "highlight"
    seq:add(Seq.action(scope, "setup", function(_, s)
        local data = list()
        local inv = player():getInventory()
        local keys = { NAILS, HAMMER }
        for i = 1, #keys do
            if not Model().hasEntry(data, keys[i]) then
                Model().addSource(data, keys[i], { type = Model().CONTEXT_MENU, amount = 1 }, getTimestamp())
            end
            if inv:getCountTypeRecurse(keys[i]) == 0 then
                inv:AddItem(keys[i])
            end
        end
        -- nails open (wanted above carried), hammer done (1 of 1)
        local carried = inv:getCountTypeRecurse(NAILS)
        Model().setWanted(data, NAILS, carried + 4, getTimestamp())
        Model().setWanted(data, HAMMER, 1, getTimestamp())
        -- The mouse player's inventory starts collapsed and only draws its
        -- rows when pinned or hovered (ISUI/PlayerData/ISPlayerDataObject.lua:62).
        local page = getPlayerInventory(0)
        if page ~= nil then
            page:setVisible(true)
            page:setPinned()
        end
        ISInventoryPage.renderDirty = true
        s:check(page ~= nil and page.inventoryPane ~= nil, T, "setup.pane", "inventory pane present")
    end))
    seq:add(Seq.wait(scope, 30))
    seq:add(Seq.action(scope, "tracker", function(_, s)
        local state = Bucketlist.Tracker.state(0)
        local carried = player():getInventory():getCountTypeRecurse(NAILS)
        s:check(state ~= nil and state.have[NAILS] == carried, T, "tracker.have", "have " .. tostring(state and state.have[NAILS]) .. ", inventory " .. carried)
        s:check(state ~= nil and state.open[NAILS] == true, T, "tracker.open", "nails open")
        s:check(state ~= nil and state.open[HAMMER] == false, T, "tracker.done", "hammer done")
        player():getInventory():AddItem(NAILS)
        Bucketlist.Tracker.markDirty(0)
        local after = Bucketlist.Tracker.state(0)
        s:check(after.have[NAILS] == carried + 1, T, "tracker.recount", "recount after the dirty signal")
    end))
    seq:add(Seq.action(scope, "rows", function(_, s)
        local pane = getPlayerInventory(0).inventoryPane
        local marks = Bucketlist.Highlight.marks(pane)
        local nailsRow = paneRowOf(pane, NAILS)
        local hammerRow = paneRowOf(pane, HAMMER)
        local function markOf(row)
            for i = 1, #marks do
                if marks[i].row == row then
                    return marks[i]
                end
            end
            return nil
        end
        local nails = markOf(nailsRow)
        local hammer = markOf(hammerRow)
        s:check(nails ~= nil and nails.open, T, "rows.open", "row " .. tostring(nailsRow) .. " marked as open")
        s:check(hammerRow ~= nil and hammer ~= nil and not hammer.open, T, "rows.done", "done hammer marked faintly")
    end))
    seq:add(Seq.action(scope, "tooltip", function(_, s)
        local item = player():getInventory():getFirstTypeRecurse(NAILS)
        local lines = Bucketlist.Tooltip.linesFor(item, 0)
        local state = Bucketlist.Tracker.state(0)
        local amount = getText("Tooltip_Bucketlist_Amount", state.have[NAILS], state.wanted[NAILS])
        local found = false
        for i = 1, #lines do
            if lines[i].text == amount then
                found = true
            end
        end
        s:check(found, T, "tooltip.amount", amount)
        local none = Bucketlist.Tooltip.linesFor(player():getInventory():AddItem("Base.Pencil"), 0)
        s:check(#none == 0, T, "tooltip.unlisted", "no lines for an unlisted item")
    end))
end

local ROPE = "Base.CraftRope"
local FIBRE = "grp:[Base.Dogbane;Base.HempScutched]"
local KNIFE = "grp:tags[base:sharpknife;base:scissors]"

local function recipePanel()
    local window = ISEntityUI.GetWindowInstance(0, "HandcraftWindow")
    return window, window and window.handCraftPanel and window.handCraftPanel.recipePanel
end

local function craftSource(key)
    local entry = Model().getEntry(list(), key)
    if entry == nil then
        return nil, nil
    end
    for i = 1, #entry.sources do
        if entry.sources[i].type == Model().CRAFT_MENU and entry.sources[i].recipeId == ROPE then
            return entry.sources[i], entry
        end
    end
    return nil, entry
end

local function addCraftSteps(seq, scope)
    local T = "craft"
    seq:add(Seq.action(scope, "setup", function(_, s)
        local data = list()
        Model().removeEntry(data, FIBRE)
        Model().removeEntry(data, KNIFE)
        local recipe = getScriptManager():getCraftRecipe(ROPE)
        if not s:check(recipe ~= nil, T, "setup.recipe", ROPE) then
            scope.aborted = true
            return
        end
        ISEntityUI.OpenHandcraftWindow(player(), nil, "*", false, recipe)
    end))
    seq:add(Seq.wait(scope, 60))
    seq:add(Seq.action(scope, "button", function(_, s)
        local window, panel = recipePanel()
        if not s:check(panel ~= nil, T, "button.panel", "crafting window open") then
            scope.aborted = true
            return
        end
        local recipe = panel.logic and panel.logic:getRecipe()
        s:check(recipe ~= nil and recipe:getScriptObjectFullType() == ROPE, T, "button.recipe", "recipe preselected")
        local button = panel.bucketlistButton
        if not s:check(button ~= nil, T, "button.present", "our button in the recipe panel") then
            scope.aborted = true
            return
        end
        s:check(not panel.logic:areAllInputItemsSatisfied(), T, "button.missing", "the recipe lacks inputs")
        Bucketlist.CraftButton.onClick(panel, button)
        local source, entry = craftSource(FIBRE)
        s:check(source ~= nil and source.amount == 2, T, "button.fibre", "fibre group with 2 for the rope recipe")
        s:check(entry ~= nil and entry.kind == "group" and #entry.group.alts == 2, T, "button.group", "two alternatives")
        s:check(entry ~= nil and Model().wanted(entry) == 2, T, "button.wanted", "wanted 2")
        local knife = craftSource(KNIFE)
        s:check(knife == nil or knife.tool == true, T, "button.tool", "knife group marked as tool when added")
        Bucketlist.CraftButton.onClick(panel, button)
        local again, entry2 = craftSource(FIBRE)
        s:check(again ~= nil and Model().wanted(entry2) == 2 and #entry2.sources == 1, T, "button.idempotent", "second click does not double")
        local state = Bucketlist.Tracker.state(0)
        local keys = Bucketlist.Tracker.keysFor(state, "Base.Dogbane")
        s:check(contains(keys, FIBRE), T, "button.index", "Base.Dogbane counts for the group")
        -- Right-click on the fibre input: listed by the button, so the menu
        -- offers to remove; then add again, and the button must not double.
        local widget, wish = nil, nil
        local widgets = panel.inputs and panel.inputs.inputs or {}
        for i = 1, #widgets do
            local w = Bucketlist.Recipe.inputWish(widgets[i].logic, widgets[i].inputScript, player())
            if w ~= nil and w.key == FIBRE then
                widget, wish = widgets[i], w
            end
        end
        if s:check(widget ~= nil, T, "input.widget", "fibre input widget in the panel") then
            local menu = Bucketlist.CraftInputMenu.open(widget)
            s:check(menu ~= nil and menu:getOptionFromName(getText("ContextMenu_Bucketlist_Remove")) ~= nil, T, "input.offersRemove", "listed input offers remove")
            if menu ~= nil then
                menu:closeAll()
            end
            Bucketlist.CraftInputMenu.onRemove(player(), wish)
            s:check(craftSource(FIBRE) == nil, T, "input.removed", "recipe source gone")
            menu = Bucketlist.CraftInputMenu.open(widget)
            s:check(menu ~= nil and menu:getOptionFromName(getText("ContextMenu_Bucketlist_Add")) ~= nil, T, "input.offersAdd", "unlisted input offers add")
            if menu ~= nil then
                menu:closeAll()
            end
            Bucketlist.CraftInputMenu.onAdd(player(), wish)
            local single, entry3 = craftSource(FIBRE)
            s:check(single ~= nil and single.amount == 2 and entry3.kind == "group", T, "input.added", "fibre group with 2 again")
            widget.bucketlistMenuAt = nil
            widget:onRightMouseUp(0, 0)
            s:check(widget.bucketlistMenuAt ~= nil, T, "input.hook", "right-click reaches our wrapper")
            ISContextMenu.get(0, 0, 0):closeAll()
            Bucketlist.CraftButton.onClick(panel, button)
            local both, entry4 = craftSource(FIBRE)
            s:check(both ~= nil and #entry4.sources == 1 and Model().wanted(entry4) == 2, T, "input.shared", "button and right-click share one source")
        end
        if window ~= nil then
            window:close()
        end
    end))
end

-- Screenshot of the current frame after the UI had time to settle.
local function shot(seq, scope, name)
    seq:add(Seq.wait(scope, 25))
    seq:add(Seq.action(scope, "shot " .. name, function(_, s)
        takeScreenshot("bucketlist-" .. name .. ".png")
        s:info("screenshot " .. name)
    end))
    seq:add(Seq.wait(scope, 10))
end

local function addTourSteps(seq, scope)
    local T = "tour"
    local tip = nil
    local function W()
        return Bucketlist.Window.get(0)
    end
    local function select(key)
        local w = W()
        w:refresh(true)
        local _, index = rowOf(w, key)
        w.list.selected = index
        return w
    end
    seq:add(Seq.action(scope, "setup", function(_, s)
        local data = list()
        local inv = player():getInventory()
        local now = getTimestamp()
        Model().addSource(data, NAILS, { type = Model().CONTEXT_MENU, amount = 1 }, now)
        Model().addSource(data, HAMMER, { type = Model().CONTEXT_MENU, amount = 1 }, now)
        Model().addSource(data, PLANK, { type = Model().CONTEXT_MENU, amount = 1 }, now)
        inv:AddItem(NAILS)
        inv:AddItem(HAMMER)
        inv:AddItem("Base.Pencil")
        Model().setWanted(data, NAILS, inv:getCountTypeRecurse(NAILS) + 4, now)
        Model().setNote(data, NAILS, NOTE .. " <RGB:1,0,0>not red")
        Model().setHideDone(data, false)
        Bucketlist.Store.changed(player())
        -- A plank and nails on the floor, so the loot window has listed rows.
        local square = player():getSquare()
        square:AddWorldInventoryItem(PLANK, 0.5, 0.5, 0)
        square:AddWorldInventoryItem(NAILS, 0.4, 0.4, 0)
        square:AddWorldInventoryItem("Base.Pencil", 0.6, 0.6, 0)
        local page, loot = getPlayerInventory(0), getPlayerLoot(0)
        page:setVisible(true)
        page:setPinned()
        loot:setVisible(true)
        loot:setPinned()
        ISInventoryPage.renderDirty = true
        s:check(Model().count(data) >= 3, T, "setup", Model().count(data) .. " entries")
    end))
    shot(seq, scope, "01-inventory-loot")
    seq:add(Seq.action(scope, "tooltip", function(_, s)
        local pane = getPlayerInventory(0).inventoryPane
        local item = player():getInventory():getFirstTypeRecurse(NAILS)
        -- Built like the pane does on hover (ISUI/ISInventoryPane.lua:858).
        tip = ISToolTipInv:new(item)
        tip:initialise()
        tip:addToUIManager()
        tip:setVisible(true)
        tip:setOwner(pane)
        tip:setCharacter(player())
        tip.followMouse = false
        tip.anchorBottomLeft = { x = pane:getAbsoluteX() + pane.column2, y = pane:getParent():getAbsoluteY() + 200 }
        s:check(#Bucketlist.Tooltip.linesFor(item, 0) > 0, T, "tooltip.lines", "lines for nails")
    end))
    shot(seq, scope, "02-tooltip")
    seq:add(Seq.action(scope, "window", function(_, s)
        if tip ~= nil then
            tip:removeFromUIManager()
            tip:setVisible(false)
        end
        Bucketlist.Window.close(0)
        Bucketlist.Window.toggle(0)
        select(NAILS)
        s:check(Bucketlist.Window.isOpen(0), T, "window.open", "window open")
    end))
    shot(seq, scope, "03-window")
    seq:add(Seq.action(scope, "amount dialog", function()
        local w = select(NAILS)
        w:onButton(w.btnAmount)
    end))
    shot(seq, scope, "04-amount-dialog")
    seq:add(Seq.action(scope, "note dialog", function()
        local w = W()
        if w.dialog ~= nil then
            w.dialog:onClick(w.dialog.no)
        end
        w = select(NAILS)
        w:onButton(w.btnNote)
    end))
    shot(seq, scope, "05-note-dialog")
    seq:add(Seq.action(scope, "delete asks", function()
        local w = W()
        if w.dialog ~= nil then
            w.dialog:onClick(w.dialog.no)
        end
        w = select(PLANK)
        w:onButton(w.btnDelete)
    end))
    shot(seq, scope, "06-delete-asks")
    seq:add(Seq.action(scope, "hide done", function(_, s)
        local w = W()
        w:onTick(1, true)
        w:refresh(true)
        s:check(rowOf(w, HAMMER) == nil, T, "hide", "done hammer hidden")
    end))
    shot(seq, scope, "07-hide-done")
    seq:add(Seq.action(scope, "craft window", function(_, s)
        W():onTick(1, false)
        local recipe = getScriptManager():getCraftRecipe(ROPE)
        ISEntityUI.OpenHandcraftWindow(player(), nil, "*", false, recipe)
    end))
    seq:add(Seq.wait(scope, 60))
    seq:add(Seq.action(scope, "craft button", function(_, s)
        local _, panel = recipePanel()
        if not s:check(panel ~= nil and panel.bucketlistButton ~= nil, T, "craft.panel", "crafting window with our button") then
            return
        end
        Bucketlist.CraftButton.onClick(panel, panel.bucketlistButton)
    end))
    shot(seq, scope, "08-craft-button")
    seq:add(Seq.action(scope, "craft input menu", function(_, s)
        local _, panel = recipePanel()
        local widgets = panel and panel.inputs and panel.inputs.inputs or {}
        local menu = widgets[1] and Bucketlist.CraftInputMenu.open(widgets[1])
        s:check(menu ~= nil, T, "craft.menu", "menu for the first input")
    end))
    shot(seq, scope, "09-craft-input-menu")
    seq:add(Seq.action(scope, "window with recipe sources", function()
        ISContextMenu.get(0, 0, 0):closeAll()
        local window = recipePanel()
        if window ~= nil then
            window:close()
        end
        select(FIBRE)
    end))
    shot(seq, scope, "10-window-groups")
    seq:add(Seq.action(scope, "row menu", function(_, s)
        local w = select(FIBRE)
        local _, index = rowOf(w, FIBRE)
        local y = (index - 1) * w.list.itemheight + 5
        w:rowMenu(w.list, 10, y - w.list:getYScroll())
    end))
    shot(seq, scope, "11-row-menu")
    seq:add(Seq.action(scope, "blue", function(_, s)
        ISContextMenu.get(0, 0, 0):closeAll()
        local option = Bucketlist.Options.page and Bucketlist.Options.page:getOption("highlightColor")
        if s:check(option ~= nil, T, "colour.option", "colour option on the page") then
            option:setValue({ r = 0.2, g = 0.5, b = 1.0, a = 1 })
            local r, g, b = Bucketlist.Options.highlightColor()
            s:check(b == 1.0 and r == 0.2, T, "colour.read", "highlight colour follows the option")
        end
    end))
    shot(seq, scope, "12-blue")
    seq:add(Seq.action(scope, "rebind", function(_, s)
        local option = Bucketlist.Options.page and Bucketlist.Options.page:getOption("highlightColor")
        if option ~= nil then
            local c = Bucketlist.Options.DEFAULT_COLOR
            option:setValue({ r = c.r, g = c.g, b = c.b, a = 1 })
        end
        Bucketlist.Window.close(0)
        Bucketlist.Options.setToggleKey(Keyboard.KEY_F9)
        triggerEvent("OnKeyPressed", Keyboard.KEY_K)
        s:check(not Bucketlist.Window.isOpen(0), T, "rebind.old", "old key does nothing")
        triggerEvent("OnKeyPressed", Keyboard.KEY_F9)
        s:check(Bucketlist.Window.isOpen(0), T, "rebind.new", "new key opens the window")
        Bucketlist.Options.setToggleKey(Keyboard.KEY_K)
    end))
    seq:add(Seq.action(scope, "empty", function(_, s)
        local data = list()
        local keys = Model().keys(data)
        for i = 1, #keys do
            Model().removeEntry(data, keys[i])
        end
        Bucketlist.Store.changed(player())
        W():refresh(true)
        s:check(Model().count(data) == 0, T, "empty", "list emptied")
    end))
    shot(seq, scope, "13-empty")
end

-- The options screen only shows inside the pause menu, and the pause stops
-- OnTick, which this queue runs on. So the step opens the menu the way the
-- escape key does and hands over to a draw-event counter, which takes the
-- screenshot and closes everything again.
local function addOptionsSteps(seq, scope)
    local T = "options"
    seq:add(Seq.action(scope, "open", function(_, s)
        ToggleEscapeMenu(getCore():getKey(KeybindId.MAIN_MENU) ~= 0 and getCore():getKey(KeybindId.MAIN_MENU) or Keyboard.KEY_ESCAPE)
        local options = MainScreen.instance and MainScreen.instance.mainOptions
        if not s:check(options ~= nil and MainScreen.instance:isVisible(), T, "menu", "pause menu open") then
            return
        end
        options:toUI()
        options:setVisible(true)
        MainScreen.instance.bottomPanel:setVisible(false)
        options.tabs:activateView(getText("UI_mainscreen_mods"))
        local frames = 0
        local function onDraw()
            frames = frames + 1
            if frames == 40 then
                takeScreenshot("bucketlist-14-options.png")
            elseif frames == 70 then
                Events.OnPostUIDraw.Remove(onDraw)
                options:close()
                ToggleEscapeMenu(getCore():getKey(KeybindId.MAIN_MENU) ~= 0 and getCore():getKey(KeybindId.MAIN_MENU) or Keyboard.KEY_ESCAPE)
                print("[BucketlistTest] INFO options screenshot taken, menu closed")
            end
        end
        Events.OnPostUIDraw.Add(onDraw)
    end))
    seq:add(Seq.wait(scope, 20))
end

local function addPersistSteps(seq, scope)
    local T = "persist"
    seq:add(Seq.action(scope, "stored", function(_, s)
        local data, writable = list()
        s:check(data ~= nil and writable, T, "list", "writable " .. tostring(writable))
        s:check(hasContextSource(NAILS), T, "stored.nails", NAILS)
        s:check(onlyContextSource(HAMMER), T, "stored.hammer", HAMMER)
        local entry = Model().getEntry(data, NAILS)
        s:check(entry ~= nil and Model().wanted(entry) == 5, T, "stored.wanted", "wanted " .. tostring(entry and Model().wanted(entry)))
        s:check(entry ~= nil and entry.note == NOTE, T, "stored.note", "note " .. tostring(entry and entry.note))
        s:check(Model().isHideDone(data), T, "stored.hideDone", "hideDone on")
        s:check(not Model().hasEntry(data, PLANK), T, "stored.deleted", PLANK .. " stays deleted")
        local fibre = Model().getEntry(data, FIBRE)
        s:check(fibre ~= nil and fibre.kind == "group" and #fibre.group.alts == 2, T, "stored.group", FIBRE)
    end))
end

-- Save and quit like the pause menu entry (OptionScreens/MainScreen.lua,
-- "EXIT" while in game); BucketlistDev/Continue.lua then loads the save and
-- hands "test persist" to the next game start. Runs even after a failed step,
-- so the run always reports its tally.
local function addSaveAndResume(seq, scope)
    local step = Seq.action(scope, "save and quit", function(_, s)
        s:line(s:summary() .. " (before save)")
        s:info("save and quit, then load the save and run persist")
        BucketlistDev.setRequest("resume persist")
        setGameSpeed(1)
        getCore():quit()
    end)
    step.always = true
    seq:add(step)
end

function Cases.build(name)
    if not Cases.NAMES[name] then
        return nil, "unknown test " .. tostring(name)
    end
    local seq = Seq.new(print)
    local state = {}
    local scope = { test = name }
    if name == "context" or name == "all" then
        addContextSteps(seq, scope, state)
    end
    if name == "window" or name == "all" then
        addWindowSteps(seq, { test = name })
    end
    if name == "highlight" or name == "all" then
        addHighlightSteps(seq, { test = name })
    end
    if name == "craft" or name == "all" then
        addCraftSteps(seq, { test = name })
    end
    if name == "tour" then
        addTourSteps(seq, { test = name })
    end
    if name == "options" or name == "tour" then
        addOptionsSteps(seq, { test = name })
    end
    if name == "persist" then
        addPersistSteps(seq, scope)
    end
    if name == "all" then
        addSaveAndResume(seq, scope)
    else
        seq.onDone = function(s)
            s:line(s:summary())
        end
    end
    return seq
end

BucketlistDev.TestCases = Cases
return Cases
