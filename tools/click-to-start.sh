#!/usr/bin/env bash
# Clicks "Click to Start" after loading, for headless runs where nobody can.
# The game polls the mouse once per frame (GameLoadingState.update reads
# Mouse.isButtonDown), so a quick click falls between two polls; the button is
# held for half a second instead.
#   tools/click-to-start.sh <console.txt> <start-epoch>
set -u
LOG=$1
START=$2
for _ in $(seq 1 240); do
    sleep 5
    [[ -f "$LOG" ]] || continue
    (( $(stat -c %Y "$LOG") >= START )) || continue
    grep -q 'exit zombie.gameStates.GameLoadingState' "$LOG" && exit 0
    grep -q 'game loading took' "$LOG" || continue
    PID=$(pgrep -x ProjectZomboid6 | head -1)
    [[ -n "$PID" ]] || continue
    DISP=$(tr '\0' '\n' < "/proc/$PID/environ" | sed -n 's/^DISPLAY=//p')
    DISPLAY=$DISP xdotool mousemove 960 540 mousedown 1 sleep 0.6 mouseup 1
done
exit 1
