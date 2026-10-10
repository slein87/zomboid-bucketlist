-- Geometry of the inventory highlight.
local Paint = require "Bucketlist/Paint"

local cases = {}

function cases.visible_range_without_scroll(T)
    local first, last = Paint.visibleRange(0, 20, 100, 50)
    T.eq(first, 1, "first")
    T.eq(last, 6, "last row touching the bottom")
end

function cases.visible_range_scrolled(T)
    local first, last = Paint.visibleRange(-45, 20, 100, 50)
    T.eq(first, 3, "rows 1 and 2 are above")
    T.eq(last, 8, "last")
end

function cases.visible_range_short_list(T)
    local first, last = Paint.visibleRange(0, 20, 400, 3)
    T.eq(first, 1, "first")
    T.eq(last, 3, "capped at count")
end

function cases.visible_range_empty(T)
    local first, last = Paint.visibleRange(0, 20, 100, 0)
    T.ok(last < first, "nothing to draw")
end

function cases.row_top_and_header_cut(T)
    local y, cut = Paint.rowTop(1, 20, 15, 0)
    T.eq(y, 15, "first row below the header")
    T.eq(cut, 0, "not hidden")
    y, cut = Paint.rowTop(3, 20, 15, -45)
    T.eq(y, 55, "content y")
    T.eq(cut, 5, "5 px under the header")
    y, cut = Paint.rowTop(1, 20, 15, -100)
    T.eq(cut, 20, "fully hidden")
end

return cases
