-- The management window: one row per entry with icon, name, carried and wanted
-- amount, sources and note; buttons change the amount, edit the note and
-- delete; a tick box hides done entries. Built like the vanilla zone window
-- (ISUI/ISDesignationZonePanel.lua) and derived from the same base class, so
-- no vanilla function is touched.
require "ISUI/ISCollapsableWindowJoypad"
local Core = require "Bucketlist/Core"
local Model = require "Bucketlist/Model"
local Game = require "Bucketlist/Game"
local Store = require "Bucketlist/Store"
local Text = require "Bucketlist/Text"
local Rows = require "Bucketlist/Rows"
local Labels = require "Bucketlist/Labels"
local Tracker = require "Bucketlist/Tracker"
local Options = require "Bucketlist/Options"

local FONT = UIFont.Small
local FONT_HGT = getTextManager():getFontHeight(FONT)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT + 6
local PAD = 3
local ROW_HGT = PAD + FONT_HGT + 2 + FONT_HGT + PAD
local ICON = math.min(32, ROW_HGT - 2 * PAD)
local REFRESH_MS = 500
local CONFIRM_MS = 3000
local NOTE_WRAP = 60
local LAYOUT_NAME = "bucketlist"
local WIDTH, HEIGHT = 460, 440

local Window = ISCollapsableWindowJoypad:derive("BucketlistWindow")

-- One window per local player; version 1 has one for player 0, who owns
-- keyboard, mouse and the sidebar (docs/DECISIONS.md D12).
local windows = {}

function Window:new(x, y, width, height, playerNum)
    local o = ISCollapsableWindowJoypad.new(self, x, y, width, height)
    o.playerNum = playerNum
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
    o.buttonBorderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    o.minimumWidth = 380
    o.minimumHeight = 240
    o:setResizable(true)
    o:setTitle(Text.get("IGUI_Bucketlist_Title"))
    -- ESC and the hotkey close the window (ISUI/Crafting/ISHandcraftWindow.lua).
    o:setWantKeyEvents(true)
    o.shownRows = {}
    o.shownRev = -1
    o.nextRefresh = 0
    o.confirmKey = nil
    o.confirmUntil = 0
    o.writable = true
    return o
end

local function textWidth(text)
    return getTextManager():MeasureStringX(FONT, text)
end

-- Cuts a text to a pixel width and marks the cut. Measured the same way the
-- text is drawn; WrapText with a line limit let some long lines run past the
-- edge, where they were clipped in the middle of a letter.
local function fit(text, width)
    if textWidth(text) <= width then
        return text
    end
    local low, high = 0, string.len(text)
    while low < high do
        local mid = math.floor((low + high + 1) / 2)
        if textWidth(string.sub(text, 1, mid) .. "...") <= width then
            low = mid
        else
            high = mid - 1
        end
    end
    return string.sub(text, 1, low) .. "..."
end

function Window:makeButton(x, y, width, title, internal)
    local button = ISButton:new(x, y, width, BUTTON_HGT, title, self, Window.onButton)
    button.internal = internal
    button:initialise()
    button:instantiate()
    -- Own table per button: ISButton:setEnable keeps and rewrites the border
    -- colour in place (ISUI/ISButton.lua:416).
    local c = self.buttonBorderColor
    button.borderColor = { r = c.r, g = c.g, b = c.b, a = c.a }
    button:setAnchorTop(false)
    button:setAnchorBottom(true)
    self:addChild(button)
    return button
end

-- Children follow the window when it is resized: the list grows, buttons and
-- tick box stay at the bottom.
function Window:initialise()
    ISCollapsableWindowJoypad.initialise(self)
    local x = UI_BORDER_SPACING + 1
    local top = self:titleBarHeight() + UI_BORDER_SPACING

    -- The tick box sets its own height from its option (ISUI/ISTickBox.lua:227).
    self.tick = ISTickBox:new(x, 0, 200, BUTTON_HGT, "", self, Window.onTick)
    self.tick:initialise()
    self.tick:addOption(Text.get("IGUI_Bucketlist_HideDone"))
    self.tick:setWidthToFit()
    local tickY = self.height - self:resizeWidgetHeight() - UI_BORDER_SPACING - self.tick:getHeight()
    local buttonsY = tickY - UI_BORDER_SPACING - BUTTON_HGT

    self.list = ISScrollingListBox:new(x, top, self.width - x * 2, buttonsY - UI_BORDER_SPACING - top)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list.selected = 0
    self.list.joypadParent = self
    self.list.font = FONT
    self.list.drawBorder = true
    self.list.doDrawItem = Window.drawRow
    self.list:setAnchorRight(true)
    self.list:setAnchorBottom(true)
    -- Right-click on a row opens its menu; vanilla sets onRightMouseUp on the
    -- instance the same way (ISUI/ISEquippedItem.lua:720).
    self.list.onRightMouseUp = function(list, x, y)
        Core.try("Window.rowMenu", self.rowMenu, self, list, x, y)
        return true
    end
    self:addChild(self.list)

    local amountTitle = Text.get("IGUI_Bucketlist_SetAmount")
    local noteTitle = Text.get("IGUI_Bucketlist_EditNote")
    local deleteTitle = Text.get("IGUI_Bucketlist_Delete")
    local confirmTitle = Text.get("IGUI_Bucketlist_DeleteConfirm")
    local amountW = textWidth(amountTitle) + 20
    local noteW = textWidth(noteTitle) + 20
    local deleteW = math.max(textWidth(deleteTitle), textWidth(confirmTitle)) + 20
    self.btnAmount = self:makeButton(x, buttonsY, amountW, amountTitle, "AMOUNT")
    self.btnNote = self:makeButton(self.btnAmount:getRight() + UI_BORDER_SPACING, buttonsY, noteW, noteTitle, "NOTE")
    self.btnDelete = self:makeButton(self.btnNote:getRight() + UI_BORDER_SPACING, buttonsY, deleteW, deleteTitle, "DELETE")
    self.deleteTitle = deleteTitle
    self.confirmTitle = confirmTitle
    self.minimumWidth = math.max(self.minimumWidth, self.btnDelete:getRight() + x)
    if self.width < self.minimumWidth then
        self:setWidth(self.minimumWidth)
    end

    self.tick:setY(tickY)
    self.tick:setAnchorTop(false)
    self.tick:setAnchorBottom(true)
    self:addChild(self.tick)
end

-- Draws one row on the list (self is the list). Only visible rows draw, as in
-- the vanilla doDrawItem (ISUI/ISScrollingListBox.lua:304).
function Window.drawRow(list, y, item, alt)
    local h = item.height or list.itemheight
    local scroll = list:getYScroll()
    if y + scroll + h < 0 or y + scroll >= list.height then
        return y + h
    end
    local row = item.item
    local w = list:getWidth()
    if list.selected == item.index then
        list:drawRect(0, y, w, h - 1, 0.3, 0.7, 0.35, 0.15)
    elseif list.mouseoverselected == item.index and list:isMouseOver() and not list:isMouseOverScrollBar() then
        list:drawRect(0, y, w, h - 1, 0.1, 1, 1, 1)
    end
    list:drawRectBorder(0, y, w, h, 0.5, list.borderColor.r, list.borderColor.g, list.borderColor.b)

    local x = PAD + 2
    if row.scriptItem ~= nil then
        local alpha = 1
        if not row.available then
            alpha = 0.5
        end
        ISInventoryItem.renderScriptItemIcon(list, row.scriptItem, x, y + (h - ICON) / 2, alpha, ICON, ICON)
    end
    local textX = x + ICON + 8

    -- Same scroll bar test as ISScrollingListBox:updateTooltip.
    local right = w - PAD - 4
    if list.vscroll and list.vscroll:getHeight() < list:getScrollHeight() then
        right = right - list.vscroll:getWidth()
    end

    local amountW = textWidth(row.amountText)
    local r, g, b = 0.9, 0.9, 0.9
    if row.done then
        r, g, b = Game.goodColor()
    end
    list:drawTextRight(row.amountText, right, y + PAD, r, g, b, 1, FONT)

    local nameW = right - amountW - 10 - textX
    if row.cacheWidth ~= nameW then
        row.cacheWidth = nameW
        row.nameShown = fit(row.name, math.max(20, nameW))
        row.detailShown = fit(row.detail, math.max(20, right - textX))
    end
    local nameShade = 0.95
    if row.done or not row.available then
        nameShade = 0.6
    end
    list:drawText(row.nameShown, textX, y + PAD, nameShade, nameShade, nameShade, 1, FONT)
    list:drawText(row.detailShown, textX, y + PAD + FONT_HGT + 2, 0.65, 0.65, 0.65, 1, FONT)
    return y + h
end

function Window:tooltipText(row, sources)
    local lines = { Rows.escape(row.name) }
    if not row.available then
        lines[#lines + 1] = Text.get("IGUI_Bucketlist_TipUnavailable")
    end
    lines[#lines + 1] = Text.get("IGUI_Bucketlist_TipAmount", row.have, row.wanted)
    lines[#lines + 1] = Text.get("IGUI_Bucketlist_TipSources", Rows.escape(sources))
    if row.note ~= "" then
        local noteLines = Rows.wrap(row.note, NOTE_WRAP)
        for i = 1, #noteLines do
            if i == 1 then
                lines[#lines + 1] = Text.get("IGUI_Bucketlist_TipNote", Rows.escape(noteLines[i]))
            else
                lines[#lines + 1] = Rows.escape(noteLines[i])
            end
        end
    end
    return table.concat(lines, " <LINE> ")
end

function Window:currentList()
    local player = Game.player(self.playerNum)
    if player == nil then
        return nil, nil, false
    end
    local data, writable = Store.get(player)
    return player, data, writable
end

-- Rebuilds the rows when the list changed, otherwise recounts every
-- REFRESH_MS. Rows keep their order while nothing moves, so scrolling and the
-- selection stay put.
function Window:refresh(force)
    local player, data, writable = self:currentList()
    if data == nil then
        return
    end
    local now = Game.nowMs()
    if not force and data.rev == self.shownRev and now < self.nextRefresh then
        return
    end
    self.writable = writable
    local state = Tracker.state(self.playerNum)
    if state == nil then
        return
    end
    local rows = Rows.build(data, Labels.entryName, function(key)
        return state.have[key] or 0
    end, Model.isHideDone(data))
    for i = 1, #rows do
        local row = rows[i]
        local sources = Labels.sources(row.parts)
        row.scriptItem = Labels.entryIcon(row.key, data.entries[row.key])
        row.amountText = Text.get("IGUI_Bucketlist_Amount", row.have, row.wanted)
        if row.note ~= "" then
            row.detail = Text.get("IGUI_Bucketlist_RowDetail", sources, Rows.flatten(row.note))
        else
            row.detail = sources
        end
        row.tooltip = self:tooltipText(row, sources)
    end
    if Rows.sameOrder(self.shownRows, rows) then
        for i = 1, #rows do
            local item = self.list.items[i]
            if item then
                item.item = rows[i]
                item.text = rows[i].name
                item.tooltip = rows[i].tooltip
            end
        end
    else
        local selected = self:selectedRow()
        local selectedKey = selected and selected.key
        self.list:clear()
        local index = 0
        for i = 1, #rows do
            self.list:addItem(rows[i].name, rows[i], rows[i].tooltip)
            if rows[i].key == selectedKey then
                index = i
            end
        end
        self.list.selected = index
    end
    self.shownRows = rows
    self.shownRev = data.rev
    self.nextRefresh = now + REFRESH_MS
    self.tick:setSelected(1, Model.isHideDone(data))
end

function Window:selectedRow()
    local item = self.list.items[self.list.selected]
    if item == nil then
        return nil
    end
    return item.item
end

function Window:cancelConfirm()
    self.confirmKey = nil
    self.btnDelete:setTitle(self.deleteTitle)
end

function Window:updateButtons()
    local row = self:selectedRow()
    local enabled = row ~= nil and self.writable
    self.btnAmount:setEnable(enabled)
    self.btnNote:setEnable(enabled)
    self.btnDelete:setEnable(enabled)
    if self.confirmKey ~= nil and (row == nil or row.key ~= self.confirmKey or Game.nowMs() > self.confirmUntil) then
        self:cancelConfirm()
    end
end

function Window:prerender()
    ISCollapsableWindowJoypad.prerender(self)
    Core.try("Window.refresh", self.refresh, self, false)
    Core.try("Window.updateButtons", self.updateButtons, self)
end

function Window:render()
    ISCollapsableWindowJoypad.render(self)
    if self.isCollapsed then
        return
    end
    local lines = {}
    if not self.writable then
        lines[#lines + 1] = Text.get("IGUI_Bucketlist_ReadOnly")
    elseif #self.list.items == 0 and #self.shownRows == 0 then
        local _, data = self:currentList()
        if data ~= nil and Model.count(data) > 0 then
            lines[#lines + 1] = Text.get("IGUI_Bucketlist_AllHidden")
        else
            lines[#lines + 1] = Text.get("IGUI_Bucketlist_Empty")
            lines[#lines + 1] = Text.get("IGUI_Bucketlist_EmptyHint")
        end
    end
    local centre = self.list.x + self.list.width / 2
    -- Long hints wrap instead of being cut: WrapText returns the lines joined
    -- by line breaks (Entity/ISUI/CraftRecipe/ISWidgetInput.lua:130).
    local y = self.list.y + 20
    for i = 1, #lines do
        local wrapped = getTextManager():WrapText(FONT, lines[i], self.list.width - 20)
        for line in string.gmatch(wrapped, "[^\n]+") do
            self:drawTextCentre(line, centre, y, 0.8, 0.8, 0.8, 1, FONT)
            y = y + FONT_HGT + 2
        end
        y = y + 4
    end
end

function Window:onButton(button)
    Core.try("Window.onButton", function()
        local row = self:selectedRow()
        if row == nil or not self.writable then
            return
        end
        if button.internal == "AMOUNT" then
            self:askAmount(row)
        elseif button.internal == "NOTE" then
            self:askNote(row)
        elseif button.internal == "DELETE" then
            self:deleteClicked(row)
        end
    end)
end

-- Two clicks within CONFIRM_MS delete; ISModalDialog is avoided because it
-- sets the game speed to 1 and so ends a pause.
function Window:deleteClicked(row)
    local now = Game.nowMs()
    if self.confirmKey == row.key and now <= self.confirmUntil then
        local player, data, writable = self:currentList()
        if writable and Model.removeEntry(data, row.key) then
            Store.changed(player)
        end
        self:cancelConfirm()
        self:refresh(true)
        return
    end
    self.confirmKey = row.key
    self.confirmUntil = now + CONFIRM_MS
    self.btnDelete:setTitle(self.confirmTitle)
end

function Window.validAmount(target, text)
    local n = tonumber(text)
    return n ~= nil and n >= 1 and n == math.floor(n)
end

function Window:askAmount(row)
    local box = ISTextBox:new(0, 0, 280, 180, Text.get("IGUI_Bucketlist_SetAmountPrompt", row.name),
        string.format("%d", row.wanted), self, Window.onAmountDialog, self.playerNum, row.key)
    box:initialise()
    box:setOnlyNumbers(true)
    box:setValidateFunction(self, Window.validAmount)
    box.maxChars = 5
    box:addToUIManager()
    self.dialog = box
end

function Window:onAmountDialog(button, key)
    Core.try("Window.onAmountDialog", function()
        if button.internal ~= "OK" then
            return
        end
        local n = tonumber(button.parent.entry:getText())
        if not Window.validAmount(nil, n) then
            return
        end
        local player, data, writable = self:currentList()
        if writable and Model.setWanted(data, key, n, Game.now()) then
            Store.changed(player)
        end
        self:refresh(true)
    end)
end

-- Multiple lines need setMultipleLine and setNumberOfLines before initialise
-- (ISUI/ISTextBox.lua:88, 96); maxChars greys out OK above the limit. The
-- line limit is set as a field: placed at the mouse, the dialog already has a
-- plain UIElement behind it, and ISTextBox:setMaxLines would call setMaxLines
-- on that (ISUI/ISTextBox.lua:100); initialise hands the field to the entry
-- (line 24).
function Window:askNote(row)
    local box = ISTextBox:new(0, 0, 420, 240, Text.get("IGUI_Bucketlist_EditNotePrompt", row.name),
        row.note, self, Window.onNoteDialog, self.playerNum, row.key)
    box:setMultipleLine(true)
    box:setNumberOfLines(4)
    box.maxLines = 4
    box:initialise()
    box.maxChars = Model.MAX_NOTE
    box:addToUIManager()
    self.dialog = box
end

function Window:onNoteDialog(button, key)
    Core.try("Window.onNoteDialog", function()
        if button.internal ~= "OK" then
            return
        end
        local player, data, writable = self:currentList()
        if writable and Model.setNote(data, key, button.parent.entry:getText()) then
            Store.changed(player)
        end
        self:refresh(true)
    end)
end

function Window:onTick(index, selected)
    Core.try("Window.onTick", function()
        local player, data, writable = self:currentList()
        if writable and Model.setHideDone(data, selected) then
            Store.changed(player)
        end
        self:refresh(true)
    end)
end

local function sourceLabel(source)
    if source.type == Model.CRAFT_MENU then
        local name = Game.recipeName(source.recipeId)
        if source.tool then
            return Text.get("IGUI_Bucketlist_Source_CraftTool", name)
        end
        return Text.get(Rows.CRAFT, name)
    elseif source.type == Model.MANUAL then
        return Text.get(Rows.MANUAL, Rows.signed(source.amount))
    end
    return Text.get(Rows.CONTEXT)
end

-- Menu of a row: amount, note, open each recipe, remove single sources.
-- Removing a source lowers the wanted amount by exactly its share; without a
-- source left besides the manual correction the entry goes (DECISIONS D4).
function Window:rowMenu(list, x, y)
    local index = list:rowAt(x, y)
    if index < 1 or index > #list.items then
        return
    end
    list.selected = index
    local row = list.items[index].item
    local player, data, writable = self:currentList()
    if not writable then
        return
    end
    local entry = data.entries[row.key]
    if entry == nil then
        return
    end
    local context = ISContextMenu.get(self.playerNum, getMouseX(), getMouseY())
    context:addOption(Text.get("IGUI_Bucketlist_SetAmount"), self, Window.askAmount, row)
    context:addOption(Text.get("IGUI_Bucketlist_EditNote"), self, Window.askNote, row)
    for i = 1, #entry.sources do
        local source = entry.sources[i]
        if source.type == Model.CRAFT_MENU and Game.recipe(source.recipeId) ~= nil then
            context:addOption(Text.get("IGUI_Bucketlist_OpenRecipe", Game.recipeName(source.recipeId)), self,
                Window.openRecipe, source.recipeId)
        end
    end
    for i = 1, #entry.sources do
        local source = entry.sources[i]
        context:addOption(Text.get("IGUI_Bucketlist_RemoveSource", sourceLabel(source)), self,
            Window.removeSourceChosen, row.key, source.type, source.recipeId)
    end
end

function Window:removeSourceChosen(key, sourceType, recipeId)
    Core.try("Window.removeSource", function()
        local player, data, writable = self:currentList()
        if writable and Model.removeSource(data, key, sourceType, recipeId) then
            Store.changed(player)
        end
        self:refresh(true)
    end)
end

-- Opens the crafting window on the recipe, the way vanilla does it from the
-- context menu (ISUI/ISInventoryPaneContextMenu.lua).
function Window:openRecipe(recipeId)
    Core.try("Window.openRecipe", function()
        local recipe = Game.recipe(recipeId)
        local player = Game.player(self.playerNum)
        if recipe ~= nil and player ~= nil then
            ISEntityUI.OpenHandcraftWindow(player, nil, "*", false, recipe)
        end
    end)
end

function Window:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE or (key ~= 0 and key == Options.toggleKey())
end

function Window:onKeyRelease(key)
    if self:getIsVisible() and self:isKeyConsumed(key) then
        self:close()
    end
end

-- Hidden windows leave the UI manager so they do not update in the background
-- (ISUI/ISDesignationZonePanel.lua:288).
function Window:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if self.confirmKey ~= nil then
        self:cancelConfirm()
    end
end

function Window:open()
    self:setVisible(true)
    self:addToUIManager()
    self:bringToTop()
    self:refresh(true)
end

-- Module functions ------------------------------------------------------------

local Api = {}

function Api.get(playerNum)
    if playerNum ~= 0 then
        return nil
    end
    local window = windows[playerNum]
    if window == nil and Game.player(playerNum) ~= nil then
        local x = getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - WIDTH) / 2
        local y = getPlayerScreenTop(playerNum) + (getPlayerScreenHeight(playerNum) - HEIGHT) / 2
        window = Window:new(x, y, WIDTH, HEIGHT, playerNum)
        window:initialise()
        windows[playerNum] = window
        -- Restores position and size from layout.ini, like the inventory
        -- (ISUI/PlayerData/ISPlayerDataObject.lua:151).
        ISLayoutManager.RegisterWindow(LAYOUT_NAME, Window, window)
    end
    return window
end

function Api.isOpen(playerNum)
    local window = windows[playerNum]
    return window ~= nil and window:getIsVisible()
end

function Api.toggle(playerNum)
    local window = Api.get(playerNum)
    if window == nil then
        return
    end
    if window:getIsVisible() then
        window:close()
    else
        window:open()
    end
end

function Api.close(playerNum)
    local window = windows[playerNum]
    if window ~= nil then
        window:close()
    end
end

function Api.discard(playerNum)
    Api.close(playerNum)
    windows[playerNum] = nil
end

function Api.closeAll()
    for playerNum in pairs(windows) do
        Api.close(playerNum)
    end
end

Api.Class = Window

Bucketlist.Window = Api
return Api
