-- Visible texts come from the translation files only. Lua sources stay ASCII,
-- because Kahlua garbles other characters in string literals (docs/API.md,
-- section 10); sentences take their numbers and names through %1, %2.
require "Bucketlist/Core"

local Text = {}

-- getText throws on a nil key, so a bad key yields a
-- visible marker instead of breaking the menu that asked for the text.
function Text.get(key, ...)
    if type(key) ~= "string" then
        return "?"
    end
    return getText(key, ...)
end

Bucketlist.Text = Text
return Text
