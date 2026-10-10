#!/usr/bin/env bash
# Runs the screenshot tour of the dev tests once per language and collects the
# pictures, to look for missing glyphs, cut-off texts and raw keys.
#   tools/lang-tour.sh FR ES RU        the given languages
#   tools/lang-tour.sh                 every language folder of the mod except EN and DE
# Pictures end up in .cache/langshots/<CODE>/. Each run starts the dev game,
# waits for the tour to finish and ends the dev game again; it refuses to start
# while any Project Zomboid runs (see tools/start-game.sh). The language of the
# dev folder is set back to the one it had before.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
DEV="$REPO/.cache/zomboid"
LOG="$DEV/console.txt"
OUT="$REPO/.cache/langshots"
TRANSLATE="$REPO/mod/ShoppingList/common/media/lua/shared/Translate"

if [[ $# -gt 0 ]]; then
    LANGS=("$@")
else
    LANGS=()
    for dir in "$TRANSLATE"/*/; do
        code=$(basename "$dir")
        [[ "$code" == EN || "$code" == DE ]] || LANGS+=("$code")
    done
fi

BEFORE=$(sed -n 's/^language=//p' "$DEV/options.ini" 2>/dev/null | head -1)
restore() {
    if [[ -n "$BEFORE" && -f "$DEV/options.ini" ]]; then
        sed -i "s/^language=.*/language=$BEFORE/" "$DEV/options.ini"
    fi
}
trap restore EXIT

wait_gone() {
    for _ in $(seq 1 40); do
        pgrep -x ProjectZomboid6 >/dev/null || return 0
        sleep 3
    done
    return 1
}

for code in "${LANGS[@]}"; do
    start=$(date +%s)
    "$REPO/tools/start-game.sh" --lang "$code" --test tour >/dev/null
    result="no result"
    for _ in $(seq 1 80); do
        sleep 5
        [[ -f "$LOG" ]] || continue
        (( $(stat -c %Y "$LOG") > start )) || continue
        if grep -q 'ShoppingListTest\] DONE' "$LOG"; then
            result=$(grep -o 'DONE [0-9]*/[0-9]*' "$LOG" | tail -1)
            break
        fi
    done
    sleep 3
    mkdir -p "$OUT/$code"
    find "$DEV/Screenshots" -name 'shoppinglist-*.png' -newermt "@$start" -exec cp {} "$OUT/$code/" \;
    errors=$(grep -c '\[ShoppingList\] error' "$LOG" || true)
    echo "$code: $result, $(ls "$OUT/$code" | wc -l) pictures, $errors errors in the log"
    "$REPO/tools/start-game.sh" --stop >/dev/null 2>&1 || true
    wait_gone || { echo "dev game did not end, stopping" >&2; exit 1; }
done
