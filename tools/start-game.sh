#!/usr/bin/env bash
# Starts Project Zomboid for a Bucketlist test run: debug mode, own user folder
# (.cache/zomboid, so the normal ~/Zomboid with its saves and mod list stays
# untouched), only Bucketlist and BucketlistDev active.
#
#   tools/start-game.sh                 straight into a fresh test world
#   tools/start-game.sh --continue      straight into the latest test save
#   tools/start-game.sh --test context  fresh test world, then the right-click checks
#   tools/start-game.sh --test window   fresh test world, then the window checks
#   tools/start-game.sh --test highlight  fresh test world, then highlight and tooltip
#   tools/start-game.sh --test craft    fresh test world, then the crafting window button
#   tools/start-game.sh --test all      context and window, then save and quit, load
#                                       the save again and check everything survived
#   tools/start-game.sh --test persist  latest test save (of an "all" run), then the
#                                       persistence checks
#   tools/start-game.sh --log           follow the Bucketlist lines of the running game
#   tools/start-game.sh --stop          end the dev game (and its headless display)
#
# Results are the "[BucketlistTest]" lines in .cache/zomboid/console.txt, each
# run ending in "DONE n/m".
#
# The author plays Project Zomboid on the same machine. The script refuses to start
# while any Project Zomboid runs, and --stop only ends processes whose command
# line names the dev folder (docs/DECISIONS.md D15).
#
# Put --lang <CODE> in front of a mode to set the game language of the dev
# folder first (EN, DE, FR, ...), for example: tools/start-game.sh --lang FR --test tour
#
# Put --headless in front of a mode to run the game in an invisible gamescope
# display instead of a window; "Click to Start" is then clicked by
# tools/click-to-start.sh. Example: tools/start-game.sh --headless --test all
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
DEV="$REPO/.cache/zomboid"
APP_ID=108600

GAME_LANG=
if [[ "${1:-}" == "--lang" ]]; then
    GAME_LANG="${2:-}"
    if [[ ! "$GAME_LANG" =~ ^[A-Z]{2,5}$ ]]; then
        echo "Usage: $0 --lang <CODE> ..., for example --lang FR" >&2
        exit 1
    fi
    shift 2
fi

HEADLESS=0
if [[ "${1:-}" == "--headless" ]]; then
    HEADLESS=1
    shift
fi

MODE=new
TEST_NAME=
case "${1:-}" in
    --stop)
        for pid in $(pgrep -x ProjectZomboid6); do
            if tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q -- "-cachedir=$DEV"; then
                kill "$pid"
            fi
        done
        # Match the process name exactly: pkill -f would also hit any shell whose
        # command line merely contains the words.
        for pid in $(pgrep -x gamescope); do
            if tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q -- "--backend headless"; then
                kill "$pid"
            fi
        done
        exit 0 ;;
    "") ;;
    --log)
        exec tail -n +1 -F "$DEV/console.txt" | grep --line-buffered -E 'Bucketlist|STACK TRACE|attempted index|KahluaException' ;;
    --test)
        MODE=test
        TEST_NAME="${2:-}"
        # Same list as Cases.NAMES in BucketlistDev/TestCases.lua.
        case "$TEST_NAME" in
            context|window|highlight|craft|tour|options|all) ;;
            persist)
                MODE=resume
                if [[ ! -s "$DEV/latestSave.ini" ]]; then
                    echo "No test save yet, run --test context or --test all first." >&2
                    exit 1
                fi ;;
            *)
                echo "Usage: $0 --test context|window|highlight|craft|tour|options|persist|all" >&2
                exit 1 ;;
        esac ;;
    --continue)
        MODE=continue
        if [[ ! -s "$DEV/latestSave.ini" ]]; then
            echo "No test save yet, start without --continue first." >&2
            exit 1
        fi ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1 ;;
esac

# The kernel keeps 15 characters of the process name: ProjectZomboid64 -> ProjectZomboid6.
if pgrep -x ProjectZomboid6 >/dev/null; then
    echo "Project Zomboid is already running (maybe a normal session). Not starting." >&2
    exit 1
fi
if ! pgrep -x steam >/dev/null; then
    echo "Steam is not running, start it first." >&2
    exit 1
fi

# Translation files with a format error abort the game start.
python3 -I "$REPO/tools/i18n_check.py" >/dev/null || {
    echo "tools/i18n_check.py reports errors, fix them first." >&2
    exit 1
}

mkdir -p "$DEV/mods"
ln -sfn "$REPO/mod/Bucketlist" "$DEV/mods/Bucketlist"
ln -sfn "$REPO/mod/BucketlistDev" "$DEV/mods/BucketlistDev"

# Without this marker the game empties default.txt on start (B42 mod reset).
echo "If this file does not exist, default.txt will be reset to empty (no mods active)." \
    > "$DEV/mods/reset-mods-42_00.txt"

cat > "$DEV/mods/default.txt" <<'EOF'
VERSION = 1,

mods
{
    mod = Bucketlist,
    mod = BucketlistDev,
}

maps
{
}
EOF

# Graphics, language and key bindings as in the normal game, copied once.
if [[ ! -f "$DEV/options.ini" && -f "$HOME/Zomboid/options.ini" ]]; then
    cp "$HOME/Zomboid/options.ini" "$DEV/options.ini"
fi
# Test runs must not pause when the window has no focus (headless never has it).
# Only the copy in the dev folder changes.
if [[ -f "$DEV/options.ini" ]]; then
    sed -i 's/^focusloss=.*/focusloss=false/' "$DEV/options.ini"
    if [[ -n "$GAME_LANG" ]]; then
        sed -i "s/^language=.*/language=$GAME_LANG/" "$DEV/options.ini"
    fi
fi

# A fresh world comes from the force-launched BucketlistDev scenario, which
# turns the option off after launching; continuing comes from a request file
# that BucketlistDev/Continue.lua reads and clears on the main menu.
FORCE=false
[[ "$MODE" == new || "$MODE" == test ]] && FORCE=true
OPTS="$DEV/debug-options.ini"
touch "$OPTS"
if grep -q '^DebugScenario.ForceLaunch=' "$OPTS"; then
    sed -i "s/^DebugScenario.ForceLaunch=.*/DebugScenario.ForceLaunch=$FORCE/" "$OPTS"
else
    echo "DebugScenario.ForceLaunch=$FORCE" >> "$OPTS"
fi
mkdir -p "$DEV/Lua"
case "$MODE" in
    continue) echo "continue" > "$DEV/Lua/BucketlistDev.txt" ;;
    resume)   echo "resume $TEST_NAME" > "$DEV/Lua/BucketlistDev.txt" ;;
    test)     echo "test $TEST_NAME" > "$DEV/Lua/BucketlistDev.txt" ;;
    *)        : > "$DEV/Lua/BucketlistDev.txt" ;;
esac

if [[ "$HEADLESS" == 1 ]]; then
    # Direct start without the Steam client; Steam must run for the game to find it.
    GAME="$HOME/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid.sh"
    setsid -f gamescope --backend headless -W 1920 -H 1080 -r 60 -- "$GAME" -debug "-cachedir=$DEV" \
        >"$REPO/.cache/gamescope.log" 2>&1 </dev/null
    setsid -f "$REPO/tools/click-to-start.sh" "$DEV/console.txt" "$(date +%s)" >/dev/null 2>&1 </dev/null
else
    # Steam adds these arguments after the launch options set in the Steam client.
    setsid -f steam -applaunch "$APP_ID" -debug "-cachedir=$DEV" >/dev/null 2>&1 </dev/null
fi
echo "Starting Project Zomboid ($MODE${TEST_NAME:+ $TEST_NAME}) with user folder $DEV"
echo "Log: $DEV/console.txt (follow with: tools/start-game.sh --log)"
if [[ -n "$TEST_NAME" ]]; then
    echo "Test results: grep -F '[BucketlistTest]' \"$DEV/console.txt\""
fi
