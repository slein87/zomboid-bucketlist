-- Box under the item tooltip for listed items: carried and wanted amount,
-- sources, note. Java builds the tooltip itself and offers no Lua hook inside
-- it, so the box is drawn after ISToolTipInv:render, like Skill Recovery
-- Journal does. Java does not clip drawing at
-- the panel border.
require "ISUI/ISToolTipInv"
local Game = require "ShoppingList/Game"
local Text = require "ShoppingList/Text"
local Rows = require "ShoppingList/Rows"
local Labels = require "ShoppingList/Labels"
local Tracker = require "ShoppingList/Tracker"
local Hooks = require "ShoppingList/Hooks"

local Tooltip = {}

local PAD = 5
local MAX_ENTRIES = 2
local NOTE_WRAP = 50
local NOTE_LINES = 3

-- The tooltip knows its character when the inventory set it; other
-- callers leave it empty, then player 0 is the best guess.
local function playerNumOf(tip)
    local character = tip.tooltip and tip.tooltip:getCharacter()
    if character ~= nil and instanceof(character, "IsoPlayer") then
        return character:getPlayerNum()
    end
    return 0
end

-- Lines for an item: { text, done } each. Plain text, drawn with drawText, so
-- player notes need no escaping here.
function Tooltip.linesFor(item, playerNum)
    local lines = {}
    if item == nil or not instanceof(item, "InventoryItem") then
        return lines
    end
    local state = Tracker.state(playerNum)
    if state == nil then
        return lines
    end
    local keys = Tracker.keysFor(state, item:getFullType())
    for i = 1, math.min(#keys, MAX_ENTRIES) do
        local key = keys[i]
        local entry = state.data.entries[key]
        if entry ~= nil then
            local done = not state.open[key]
            if entry.kind == "group" then
                lines[#lines + 1] = { text = (Labels.entryName(key, entry)), done = done }
            end
            lines[#lines + 1] = { text = Text.get("Tooltip_ShoppingList_Amount", state.have[key], state.wanted[key]), done = done }
            lines[#lines + 1] = { text = Text.get("Tooltip_ShoppingList_Sources", Labels.sources(Rows.sourceParts(entry))) }
            if entry.note ~= nil and entry.note ~= "" then
                local noteLines = Rows.wrap(entry.note, NOTE_WRAP)
                for n = 1, math.min(#noteLines, NOTE_LINES) do
                    local text = noteLines[n]
                    if n == NOTE_LINES and #noteLines > NOTE_LINES then
                        text = text .. " ..."
                    end
                    if n == 1 then
                        text = Text.get("Tooltip_ShoppingList_Note", text)
                    end
                    lines[#lines + 1] = { text = text }
                end
            end
        end
    end
    return lines
end

local function drawBox(tip, result)
    -- false means another wrapper drew nothing (KATTAJ1 Clothes Core).
    if result == false or not instanceof(tip.item, "InventoryItem") then
        return
    end
    local lines = Tooltip.linesFor(tip.item, playerNumOf(tip))
    if #lines == 0 then
        return
    end
    local font = tip.tooltip:getFont()
    local textManager = getTextManager()
    local lineHgt = textManager:getFontHeight(font)
    local width = tip.width
    for i = 1, #lines do
        width = math.max(width, textManager:MeasureStringX(font, lines[i].text) + PAD * 2)
    end
    local height = #lines * lineHgt + PAD * 2
    -- Below the panel, or above when anchored at the bottom (controller), when
    -- the screen ends, or for the bound journal of Skill Recovery
    -- Journal, which draws its own box below the tooltip.
    local y = tip.height
    if (not tip.followMouse and tip.anchorBottomLeft) or tip:getAbsoluteY() + tip.height + height > getCore():getScreenHeight()
        or tip.item:getType() == "SkillRecoveryBoundJournal" then
        y = -height
    end
    -- Vanilla keeps only the tooltip itself on screen; a wider box moves left.
    local x = 0
    local over = tip:getAbsoluteX() + width - getCore():getScreenWidth()
    if over > 0 then
        x = -math.min(over, tip:getAbsoluteX())
    end
    local bg, border = tip.backgroundColor, tip.borderColor
    tip:drawRect(x, y, width, height, math.min(1, bg.a + 0.4), bg.r, bg.g, bg.b)
    tip:drawRectBorder(x, y, width, height, border.a, border.r, border.g, border.b)
    local gr, gg, gb = Game.goodColor()
    for i = 1, #lines do
        local r, g, b = 1, 1, 1
        if lines[i].done then
            r, g, b = gr, gg, gb
        end
        tip:drawText(lines[i].text, x + PAD, y + PAD + (i - 1) * lineHgt, r, g, b, 1, font)
    end
end

Hooks.after(ISToolTipInv, "render", "Tooltip.box", drawBox)

ShoppingList.Tooltip = Tooltip
return Tooltip
