-- Pure helpers for craft inputs: the key of a group entry and the group shape
-- stored in it. No game calls; tests/run.lua covers them with Lua 5.1.
local Model = require "ShoppingList/Model"

local Inputs = {}

-- The item source of a craft input line:
--   "item 1 tags[base:hammer] mode:keep,"        -> "tags[base:hammer]"
--   "item 2 [Base.Log;3:Base.LargeBranch] flags[IsExclusive]" -> "[Base.Log;3:Base.LargeBranch]"
-- The amount may be "variable[1:4]"; none of the tokens contains blanks.
function Inputs.sourceOf(line)
    if type(line) ~= "string" then
        return nil
    end
    local kind, rest = string.match(line, "^%s*(%S+)%s+(.+)$")
    if kind ~= "item" or rest == nil then
        return nil
    end
    local amount, rest2 = string.match(rest, "^(%S+)%s+(.+)$")
    if amount == nil or rest2 == nil then
        return nil
    end
    local source = string.match(rest2, "^(%S+)")
    if source == nil then
        return nil
    end
    source = string.gsub(source, ",+$", "")
    if source == "" or source == "[*]" then
        return nil
    end
    return source
end

-- Same source text means the same alternatives with the same pieces per unit,
-- so "a hammer" from thirty recipes stays one entry. Exclusive inputs accept
-- one alternative only and count differently, hence their own key. Without a
-- readable line the key falls back to recipe and input index.
function Inputs.groupKey(line, exclusive, recipeId, index)
    local source = Inputs.sourceOf(line)
    if source ~= nil then
        local key = Model.GROUP_PREFIX .. source
        if exclusive then
            key = key .. "!"
        end
        return key
    end
    return Model.GROUP_PREFIX .. tostring(recipeId) .. "#" .. tostring(index)
end

-- Wanted units of an input amount: whole and at least 1.
function Inputs.wantedUnits(amount)
    local n = math.ceil(tonumber(amount) or 1)
    if n < 1 then
        return 1
    end
    return n
end

-- alts: { type = fullType, amount = pieces needed } per alternative; unit is
-- the input amount. Lists with differing "N:Item" amounts set the input
-- amount to 1, so each alternative's own amount counts. Returns the
-- group and whether alternatives were cut at Model.MAX_ALTS.
function Inputs.makeGroup(alts, unit, exclusive)
    local base = tonumber(unit) or 1
    if base <= 0 then
        base = 1
    end
    local group = { alts = {}, exclusive = exclusive == true }
    local seen = {}
    local cut = false
    for i = 1, #alts do
        local alt = alts[i]
        if Model.isFullType(alt.type) and not seen[alt.type] then
            if #group.alts >= Model.MAX_ALTS then
                cut = true
            else
                seen[alt.type] = true
                local amount = tonumber(alt.amount) or base
                if amount <= 0 then
                    amount = base
                end
                group.alts[#group.alts + 1] = { type = alt.type, scale = amount / base }
            end
        end
    end
    return group, cut
end

return Inputs
