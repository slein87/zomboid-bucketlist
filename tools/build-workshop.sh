#!/usr/bin/env bash
# Assembles the workshop upload folder workshop/Bucketlist/ (workshop.txt,
# preview.png, Contents/mods/Bucketlist). Nothing is uploaded: the upload is
# done by hand from the game's main menu (Workshop) after copying the folder to
# ~/Zomboid/Workshop/Bucketlist.
#
# A staged copy in ~/Zomboid/Workshop loads before ~/Zomboid/mods and hides a
# mod with the same id there, so remove the staged copy
# again after uploading, or the symlink ~/Zomboid/mods/Bucketlist while it is
# staged.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
STAGE="$REPO/workshop/Bucketlist"
TARGET="$STAGE/Contents/mods/Bucketlist"

python3 -I "$REPO/tools/i18n_check.py" >/dev/null || { echo "tools/i18n_check.py reports errors" >&2; exit 1; }
python3 -I "$REPO/tools/kahlua/compile_all.py" | grep -q 'files compile' || { echo "Lua does not compile" >&2; exit 1; }

rm -rf "$STAGE/Contents"
mkdir -p "$TARGET"
cp -a "$REPO/mod/Bucketlist/common" "$TARGET/"

# Checks of the game's uploader (SteamWorkshopItem.validateContents,
# validatePreviewImage): mod.info with id= in common/, no forbidden file
# types, preview 256 or 512 px square and at most 1,024,000 bytes.
grep -q '^id=Bucketlist$' "$TARGET/common/mod.info" || { echo "mod.info without id=Bucketlist" >&2; exit 1; }
if find "$STAGE/Contents" -type f \( -iname '*.exe' -o -iname '*.dll' -o -iname '*.bat' -o -iname '*.app' \
        -o -iname '*.dylib' -o -iname '*.sh' -o -iname '*.so' -o -iname '*.zip' \) | grep -q .; then
    echo "forbidden file type in Contents" >&2
    exit 1
fi
python3 -I - "$STAGE/preview.png" <<'PY'
import struct, sys, os
path = sys.argv[1]
data = open(path, 'rb').read(32)
assert data[:8] == b'\x89PNG\r\n\x1a\n', 'preview.png is not a PNG'
w, h = struct.unpack('>II', data[16:24])
assert w == h and w in (256, 512), 'preview.png must be 256 or 512 px square, is %dx%d' % (w, h)
assert os.path.getsize(path) <= 1024000, 'preview.png larger than 1,024,000 bytes'
PY
echo "Workshop folder ready: $STAGE"
echo "Upload by hand: copy it to ~/Zomboid/Workshop/Bucketlist, then main menu, Workshop."
