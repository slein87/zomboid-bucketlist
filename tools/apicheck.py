#!/usr/bin/env python3
"""Check every citation in docs/API.md against the installed game.

Usage: apicheck.py [docs/API.md]

Table rows are "| Name | Location | Signature | Side | Use | Status |".
Locations in the Location cell are code spans:
  `media/lua/client/Foo.lua:12`        relative to the game install dir
  `WS 2804531012/mods/X/42/foo.lua:12` relative to the Steam workshop dir
  `~/Zomboid/console.txt:3`            relative to the home dir
  `jar zombie.iso.objects.IsoGenerator` class in the jar dump (.cache/jardump,
                                        made by tools/pzjar.py)
For file locations the line must exist; for the first (main) location a part
of the name must also appear within three lines of it. For jar locations the
class must exist and a function name from the Name or Signature cell must be one
of its public methods or a string literal in its bytecode (Kahlua libraries
register their Lua functions by name), or the Java member recorded for the
row in docs/API-belege.json (field beleg_java) must be one of its members.
Rows with status "not found" are skipped. Exit code 1 on any failure,
so a game patch that moves or removes something shows up at once.
"""
import re
import sys
from pathlib import Path

HOME = Path.home()
GAME = HOME / '.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid'
WS = HOME / '.local/share/Steam/steamapps/workshop/content/108600'
DUMP = Path(__file__).resolve().parent.parent / '.cache' / 'jardump'
STOP = {'Events', 'Remove', 'self', 'getInstance', 'function', 'local', 'player', 'Base', 'true', 'false'}
SPAN = re.compile(r'`([^`]+)`')
FILELOC = re.compile(r'^(.+):(\d+)$')


def cells(line):
    # split on pipes that are not escaped as \|
    parts = re.split(r'(?<!\\)\|', line.strip())
    return [p.strip() for p in parts[1:-1]]


def load_dump():
    blocks, cur = {}, None
    path = DUMP / 'classes.txt'
    if not path.exists():
        return None
    for line in open(path):
        if line.startswith('class '):
            cur = line.split()[1]
            blocks[cur] = set()
        elif cur and line.startswith('  '):
            m = re.search(r'(\w+)\(', line)
            if m:
                blocks[cur].add(m.group(1))
            else:
                blocks[cur].add(line.split()[-1])
    return blocks


def load_literals():
    lits = {}
    path = DUMP / 'strings.txt'
    if path.exists():
        for line in open(path):
            lit, _, where = line.rstrip('\n').partition('\t')
            lits.setdefault(where.rsplit('.', 1)[0], set()).add(lit)
    return lits


def resolve(loc):
    if loc.startswith('WS '):
        return WS / loc[3:]
    if loc.startswith('~/'):
        return HOME / loc[2:]
    return GAME / loc


def main():
    api = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / 'docs' / 'API.md'
    blocks = load_dump()
    lits = load_literals()
    belege = {}
    bpath = api.parent / 'API-belege.json'
    if bpath.exists():
        import json
        for e in json.load(open(bpath)):
            m = re.search(r'(\w+)\(', e.get('beleg_java') or '') or re.search(r'(\w+)$', (e.get('beleg_java') or '').strip())
            if m:
                belege.setdefault(re.sub(r'\s+', ' ', e['name'].replace('|', '\\|')).strip(), set()).add(m.group(1))
    rows = bad = 0
    cache = {}
    for no, line in enumerate(open(api), 1):
        if not line.startswith('|'):
            continue
        c = cells(line)
        if len(c) != 6 or c[0] in ('Name', '') or set(c[0]) <= set('-: '):
            continue
        if not c[1] and not c[5]:  # bold capability row inside a table
            continue
        name, where, sig, _side, _use, status = c
        if status.startswith('not found'):
            continue
        rows += 1
        errs = []
        toks = [t for t in re.split(r'[^A-Za-z0-9_]+', ' '.join(SPAN.findall(name)) or name)
                if len(t) >= 4 and t not in STOP]
        locs = SPAN.findall(where)
        if not locs:
            errs.append('no location')
        for k, loc in enumerate(locs):
            if loc.startswith('jar '):
                cls = loc[4:].strip()
                if blocks is None:
                    errs.append('jar dump missing, run tools/pzjar.py first')
                elif cls not in blocks:
                    errs.append('class not in the jar: ' + cls)
                else:
                    meth = set(re.findall(r'(\w+)\s*\(', sig)) | set(re.findall(r'[\w]+', ' '.join(SPAN.findall(name))))
                    meth = {m for m in meth if len(m) >= 3}
                    plain = name.replace('`', '').strip()
                    meth |= belege.get(plain, set())
                    if meth and not any(m in blocks[cls] or m in lits.get(cls, ()) for m in meth):
                        errs.append('no method of %r in %s' % (sorted(meth), cls))
                continue
            m = FILELOC.match(loc)
            if not m:
                errs.append('cannot read location: ' + loc)
                continue
            path, ln = resolve(m.group(1)), int(m.group(2))
            if path not in cache:
                cache[path] = path.read_text(errors='replace').split('\n') if path.is_file() else None
            text = cache[path]
            if text is None:
                errs.append('file missing: ' + loc)
            elif not 1 <= ln <= len(text):
                errs.append('line out of range: %s (file has %d)' % (loc, len(text)))
            elif k == 0 and toks and not any(t in ' '.join(text[max(0, ln - 4):ln + 3]) for t in toks):
                errs.append('name not near %s, found: %r' % (loc, text[ln - 1].strip()[:120]))
        if errs:
            bad += 1
            print('API.md:%d %s' % (no, name))
            for e in errs:
                print('   - ' + e)
    print('%d entries checked, %d with errors' % (rows, bad))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
