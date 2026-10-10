-- Geometry of the inventory list for the highlight, without game calls.
-- Row i (1-based) of ISInventoryPane starts at (i - 1) * itemHgt + headerHgt in
-- content coordinates; drawRect adds the scroll itself, the visibility test
-- uses (i - 1) * itemHgt + yScroll (ISUI/ISInventoryPane.lua:2287).
local Paint = {}

-- First and last row index that can be seen; last may be below count.
function Paint.visibleRange(yScroll, itemHgt, height, count)
    if itemHgt == nil or itemHgt <= 0 or count == nil or count < 1 then
        return 1, 0
    end
    local first = math.max(1, math.floor(-yScroll / itemHgt) + 1)
    local last = math.min(count, math.floor((height - yScroll) / itemHgt) + 1)
    return first, last
end

-- Top of row i in content coordinates and how many pixels at its top hide
-- under the column header (the header covers screen y below headerHgt).
function Paint.rowTop(i, itemHgt, headerHgt, yScroll)
    local y = (i - 1) * itemHgt + headerHgt
    local cut = math.max(0, headerHgt - (y + yScroll))
    if cut > itemHgt then
        cut = itemHgt
    end
    return y, cut
end

return Paint
