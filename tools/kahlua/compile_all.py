#!/usr/bin/env python3
"""Compile every Lua file under mod/ with the game's own Kahlua compiler.

  python3 tools/kahlua/compile_all.py
Prints "all N files compile" or the files that fail with the compiler message.
Builds the KT helper class into .cache/kt on first use (see mkclass.py).
"""
import glob
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.expanduser('~/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid')
KT_DIR = os.path.join(REPO, '.cache', 'kt')


def main():
    os.makedirs(KT_DIR, exist_ok=True)
    kt = os.path.join(KT_DIR, 'KT.class')
    if not os.path.exists(kt):
        subprocess.check_call([sys.executable, '-I', os.path.join(REPO, 'tools', 'kahlua', 'mkclass.py'), kt])
    files = sorted(glob.glob(os.path.join(REPO, 'mod', '**', '*.lua'), recursive=True))
    parts = ['local bad = {}']
    for f in files:
        src = open(f, encoding='utf-8').read()
        if ']==]' in src:
            print('cannot embed', f)
            return 1
        rel = os.path.relpath(f, REPO)
        parts.append('do local fn, err = loadstring([==[%s]==], %r); if not fn then bad[#bad+1] = %r .. ": " .. tostring(err) end end' % (src, rel, rel))
    parts.append('return #bad == 0 and "all %d files compile" or table.concat(bad, " ;; ")' % len(files))
    script = os.path.join(KT_DIR, 'compile_check.lua')
    open(script, 'w', encoding='utf-8').write('\n'.join(parts))
    out = subprocess.run([os.path.join(GAME, 'jre64', 'bin', 'java'), '-cp', KT_DIR + ':' + os.path.join(GAME, 'projectzomboid.jar'),
                          'KT', script], cwd=GAME, capture_output=True, text=True)
    text = (out.stdout + out.stderr).strip()
    print(text.replace(' ;; ', '\n'))
    return 0 if 'files compile' in text else 1


if __name__ == '__main__':
    sys.exit(main())
