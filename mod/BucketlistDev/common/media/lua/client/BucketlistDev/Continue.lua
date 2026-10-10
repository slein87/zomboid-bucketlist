-- Development helper, not part of Bucketlist. Loads the latest save from the
-- main menu with the same call as the menu entry "Continue"
-- (OptionScreens/MainScreen.lua), for two requests:
--   "continue"       just load (tools/start-game.sh --continue)
--   "resume <test>"  load, then run the test <test> once the game is up; the
--                    persistence test uses this after a save and quit
require "BucketlistDev/Request"

-- The main menu panel may not exist yet when OnMainMenuEnter reaches us, so the
-- load waits for the first menu tick that has it.
local function continueWhenMenuReady()
    if not MainScreen.instance or not MainScreen.latestSaveWorld then
        return
    end
    Events.OnFETick.Remove(continueWhenMenuReady)
    print("[BucketlistDev] continuing " .. tostring(MainScreen.latestSaveGameMode) .. "/" .. tostring(MainScreen.latestSaveWorld))
    MainScreen.continueLatestSave(MainScreen.latestSaveGameMode, MainScreen.latestSaveWorld)
end

-- Taking the request clears it, so the main menu stays put after the next
-- save and quit.
Events.OnMainMenuEnter.Add(function()
    if BucketlistDev.takeRequest("continue") then
        Events.OnFETick.Add(continueWhenMenuReady)
        return
    end
    local test = BucketlistDev.takeRequestArg("resume")
    if test then
        BucketlistDev.setRequest("test " .. test)
        Events.OnFETick.Add(continueWhenMenuReady)
    end
end)
