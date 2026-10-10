-- Development helper, not part of Bucketlist. In debug mode the main menu
-- starts a debug scenario marked forceLaunch at once when the debug option
-- DebugScenario.ForceLaunch is on (DebugUIs/DebugScenarios.lua).
-- tools/start-game.sh turns the option on in the dev user
-- folder, so a test run lands in a fresh world without a click.

if debugScenarios == nil then
    debugScenarios = {}
end

debugScenarios.BucketlistDev = {
    name = "Bucketlist dev",
    world = "Muldraugh, KY",
    forceLaunch = true,
    -- A spot in Muldraugh; any open tile works,
    -- the tests only need the player and the player's inventory.
    startLoc = { x = 10176, y = 9149, z = 0 },
    setSandbox = function()
        -- The save records the "currentGame" mod list and scenarios do not set
        -- it; without this a test save would load without Bucketlist.
        ActiveMods.getById("currentGame"):copyFrom(ActiveMods.getById("default"))
        -- No zombies, no respawn: the tests run undisturbed.
        SandboxVars.Zombies = 5
        SandboxVars.ZombieConfig = SandboxVars.ZombieConfig or {}
        SandboxVars.ZombieConfig.PopulationMultiplier = 0.0
        SandboxVars.ZombieRespawn = 4
        SandboxVars.ZombieConfig.RespawnHours = 0.0
        SandboxVars.ZombieConfig.RespawnUnseenHours = 0.0
        SandboxVars.ZombieConfig.RespawnMultiplier = 0.0
        -- Back in the main menu (after save and quit) the scenario must not
        -- start a new world again, or the save could never be loaded.
        getDebugOptions():setBoolean("DebugScenario.ForceLaunch", false)
    end,
}
