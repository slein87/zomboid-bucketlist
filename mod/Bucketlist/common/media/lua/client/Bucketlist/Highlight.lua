-- Coloured frame on rows of listed items in the inventory and loot windows.
-- Both windows draw their rows in ISInventoryPane:renderdetails; after the
-- original has drawn, self.items maps row i to a stack table (header row) or
-- an InventoryItem (expanded row). We only add
-- rectangles: text colours stay with vanilla and other mods (Item Rarity UI
-- colours names, vanilla greys out unwanted items).
require "ISUI/ISInventoryPane"
local Core = require "Bucketlist/Core"
local Tracker = require "Bucketlist/Tracker"
local Options = require "Bucketlist/Options"
local Paint = require "Bucketlist/Paint"
local Hooks = require "Bucketlist/Hooks"

local Highlight = {}

-- Open entries (something still missing) get fill and frame; done entries
-- (enough carried) a faint frame only, so listed items stay visible in the
-- inventory without shouting in the loot window (DECISIONS D8).
local OPEN_FILL_ALPHA = 0.15
local OPEN_BORDER_ALPHA = 0.7
local DONE_BORDER_ALPHA = 0.3

-- A header row stands for a stack grouped by display name, which can mix
-- several full types; the first entry of v.items is a dummy copy. Open
-- wins over done.
local function rowMark(state, entry)
    if instanceof(entry, "InventoryItem") then
        return Tracker.markOf(state, entry)
    end
    local found = nil
    if type(entry) == "table" and type(entry.items) == "table" then
        for j = 1, #entry.items do
            local mark = Tracker.markOf(state, entry.items[j])
            if mark == "open" then
                return "open"
            end
            if mark == "done" then
                found = "done"
            end
        end
    end
    return found
end

-- Visible rows to mark as { row = index, open = bool }, for drawing and for
-- the dev tests.
function Highlight.marks(pane)
    local marks = {}
    if type(pane.items) ~= "table" or type(pane.itemHgt) ~= "number" or type(pane.headerHgt) ~= "number" then
        return marks
    end
    local state = Tracker.state(pane.player)
    if state == nil or state.count == 0 then
        return marks
    end
    local yScroll = pane:getYScroll()
    local first, last = Paint.visibleRange(yScroll, pane.itemHgt, pane:getHeight(), #pane.items)
    for i = first, last do
        -- Rows being dragged are drawn in the render pass; vanilla skips them in
        -- this one (ISUI/ISInventoryPane.lua:2273).
        local dragged = pane.dragging ~= nil and pane.dragStarted and pane.selected ~= nil and pane.selected[i] ~= nil
        if not dragged then
            local mark = rowMark(state, pane.items[i])
            if mark ~= nil then
                marks[#marks + 1] = { row = i, open = mark == "open" }
            end
        end
    end
    return marks
end

local function mark(pane, result, doDragged)
    if doDragged then
        return
    end
    local marks = Highlight.marks(pane)
    if #marks == 0 then
        return
    end
    local r, g, b = Options.highlightColor()
    local x = pane.column2 or 0
    local right = pane:getWidth() - 1
    if pane.vscroll and pane.vscroll:getHeight() < pane:getScrollHeight() then
        right = right - pane.vscroll:getWidth()
    end
    local width = right - x
    local yScroll = pane:getYScroll()
    for i = 1, #marks do
        local y, cut = Paint.rowTop(marks[i].row, pane.itemHgt, pane.headerHgt, yScroll)
        local height = pane.itemHgt - cut
        if height > 0 and width > 0 then
            if marks[i].open then
                pane:drawRect(x, y + cut, width, height, OPEN_FILL_ALPHA, r, g, b)
                pane:drawRectBorder(x, y + cut, width, height, OPEN_BORDER_ALPHA, r, g, b)
            else
                pane:drawRectBorder(x, y + cut, width, height, DONE_BORDER_ALPHA, r, g, b)
            end
        end
    end
end

Hooks.after(ISInventoryPane, "renderdetails", "Highlight.mark", mark)

Bucketlist.Highlight = Highlight
return Highlight
