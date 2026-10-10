#!/usr/bin/env python3
"""Check the Bucketlist translation files before every game test.

  python3 -I tools/i18n_check.py

A malformed translation file (BOM, duplicate key, non-string value, missing
'{') throws while the game loads its texts and can abort the game start.
This script is stricter than the game on purpose.

Per file:  strict JSON object, string values only, no duplicate keys, UTF-8
           without BOM, LF line ends, no dashes or typographic look-alikes.
Per key:   the prefix matches the file (IGUI_ in IG_UI.json, UI_ in UI.json,
           ContextMenu_ in ContextMenu.json, Tooltip_ in Tooltip.json) and is
           followed by "Bucketlist_".
Languages: only the codes of docs/DECISIONS.md D13, EN is required, every
           language has exactly the keys of EN, the same placeholders as EN
           (%1 to %9, %% for a percent sign, no other %), no empty values,
           no language.json. Mod.json holds name and description only,
           without any % (it is never formatted).
Lua:       every Bucketlist key used in the mod's Lua files exists in EN, a
           Text.get(...) call passes at least as many arguments as the text
           has placeholders, and Lua sources are pure ASCII (Kahlua garbles
           other characters, docs/API.md section 10).
Exit code 1 on any error.
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MOD = REPO / 'mod' / 'Bucketlist' / 'common'
TRANSLATE = MOD / 'media' / 'lua' / 'shared' / 'Translate'
LUA = MOD / 'media' / 'lua'

LANGUAGES = ['EN', 'DE', 'FR', 'ES', 'PTBR', 'IT', 'PL', 'RU', 'UA', 'TR', 'CN', 'CH', 'JP', 'KO']
PREFIX = {'IG_UI.json': 'IGUI_', 'UI.json': 'UI_', 'ContextMenu.json': 'ContextMenu_', 'Tooltip.json': 'Tooltip_'}
MOD_JSON = 'Mod.json'
MOD_JSON_KEYS = {'name', 'description'}
LOOKALIKES = {
    '–': 'en dash', '—': 'em dash', '‘': 'left single quote', '’': 'right single quote',
    '“': 'left double quote', '”': 'right double quote', '﻿': 'BOM', ' ': 'no-break space',
}
PLACEHOLDER = re.compile(r'%(%|[1-9])')
KEY_IN_LUA = re.compile(r'"((?:IGUI|UI|ContextMenu|Tooltip)_Bucketlist_[A-Za-z0-9_]+)"')
TEXT_CALL = re.compile(r'Text\.get\(\s*"([A-Za-z0-9_]+)"')

errors = []


def error(where, text):
    errors.append('%s: %s' % (where, text))


def rel(path):
    return str(path.relative_to(REPO))


def load_json(path):
    raw = path.read_bytes()
    where = rel(path)
    if raw.startswith(b'\xef\xbb\xbf'):
        error(where, 'starts with a UTF-8 BOM')
        return None
    if b'\r' in raw:
        error(where, 'contains CR; use LF line ends')
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError as exc:
        error(where, 'not valid UTF-8: %s' % exc)
        return None
    seen = []

    def pairs(items):
        keys = [k for k, _ in items]
        for k in keys:
            if keys.count(k) > 1 and k not in seen:
                seen.append(k)
        return dict(items)

    try:
        data = json.loads(text, object_pairs_hook=pairs)
    except ValueError as exc:
        error(where, 'invalid JSON: %s' % exc)
        return None
    for k in seen:
        error(where, 'duplicate key %s' % k)
    if not isinstance(data, dict):
        error(where, 'root is not an object')
        return None
    for key, value in data.items():
        if not isinstance(value, str):
            error(where, '%s: value is not a string' % key)
    for ch, name in LOOKALIKES.items():
        if ch in text:
            error(where, 'contains %s (U+%04X)' % (name, ord(ch)))
    return data


def placeholders(value):
    found = set()
    i = 0
    while True:
        i = value.find('%', i)
        if i < 0:
            return found
        m = PLACEHOLDER.match(value, i)
        if not m:
            raise ValueError('single %% at position %d' % i)
        if m.group(1) != '%':
            found.add(m.group(1))
        i = m.end()


def check_languages():
    if not TRANSLATE.is_dir():
        error(rel(TRANSLATE), 'missing')
        return {}
    tables = {}
    for lang_dir in sorted(p for p in TRANSLATE.iterdir()):
        lang = lang_dir.name
        if not lang_dir.is_dir():
            error(rel(lang_dir), 'unexpected file in Translate')
            continue
        if lang not in LANGUAGES:
            error(rel(lang_dir), 'unknown language code (allowed: %s)' % ' '.join(LANGUAGES))
            continue
        for path in sorted(lang_dir.iterdir()):
            name = path.name
            where = rel(path)
            if name == 'language.json':
                error(where, 'do not ship language.json, it redefines the vanilla language')
                continue
            if name != MOD_JSON and name not in PREFIX:
                error(where, 'unknown file; the game reads only fixed category names')
                continue
            data = load_json(path)
            if data is None:
                continue
            if name == MOD_JSON:
                extra = set(data) - MOD_JSON_KEYS
                if extra:
                    error(where, 'Mod.json allows only name and description, found %s' % sorted(extra))
                for key, value in data.items():
                    if isinstance(value, str) and '%' in value:
                        error(where, '%s: no %% in Mod.json, it is shown unformatted' % key)
                tables.setdefault(lang, {})[name] = data
                continue
            prefix = PREFIX[name] + 'Bucketlist_'
            for key, value in data.items():
                if not key.startswith(prefix):
                    error(where, '%s: key must start with %s' % (key, prefix))
                if isinstance(value, str):
                    if value.strip() == '':
                        error(where, '%s: empty value' % key)
                    try:
                        placeholders(value)
                    except ValueError as exc:
                        error(where, '%s: %s' % (key, exc))
            tables.setdefault(lang, {})[name] = data
    if 'EN' not in tables:
        error(rel(TRANSLATE), 'EN is missing')
    return tables


def compare_with_en(tables):
    en = tables.get('EN', {})
    for lang, files in sorted(tables.items()):
        if lang == 'EN':
            continue
        for name in sorted(set(en) | set(files)):
            where = '%s/%s/%s' % (rel(TRANSLATE), lang, name)
            if name not in files:
                error(where, 'missing (EN has it)')
                continue
            if name not in en:
                error(where, 'EN has no such file')
                continue
            ek, lk = set(en[name]), set(files[name])
            for key in sorted(ek - lk):
                error(where, 'missing key %s' % key)
            for key in sorted(lk - ek):
                error(where, 'key not in EN: %s' % key)
            if name == MOD_JSON:
                continue
            for key in sorted(ek & lk):
                ev, lv = en[name][key], files[name][key]
                if not isinstance(ev, str) or not isinstance(lv, str):
                    continue
                try:
                    if placeholders(ev) != placeholders(lv):
                        error(where, '%s: placeholders %s, EN has %s' % (key, sorted(placeholders(lv)), sorted(placeholders(ev))))
                except ValueError:
                    pass  # already reported per file


def count_args(text, start):
    """Number of arguments after the key in a call whose '(' is before start."""
    depth, args, i, in_str = 1, 0, start, None
    while i < len(text):
        c = text[i]
        if in_str:
            if c == '\\':
                i += 1
            elif c == in_str:
                in_str = None
        elif c in '"\'':
            in_str = c
        elif c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
            if depth == 0:
                return args
        elif c == ',' and depth == 1:
            args += 1
        i += 1
    return None


def check_lua(tables):
    en_keys = {}
    for name, data in tables.get('EN', {}).items():
        if name != MOD_JSON:
            for key, value in data.items():
                en_keys[key] = value
    used = 0
    for path in sorted(LUA.rglob('*.lua')):
        raw = path.read_bytes()
        where = rel(path)
        bad = [i for i, b in enumerate(raw) if b > 0x7f]
        if bad:
            line = raw[:bad[0]].count(b'\n') + 1
            error(where, 'non-ASCII byte at line %d; visible texts belong in the translation files' % line)
        text = raw.decode('utf-8', errors='replace')
        for m in KEY_IN_LUA.finditer(text):
            used += 1
            if m.group(1) not in en_keys:
                error(where, 'key %s is not in the EN files' % m.group(1))
        for m in TEXT_CALL.finditer(text):
            key = m.group(1)
            if key not in en_keys:
                continue
            nargs = count_args(text, m.end())
            try:
                wanted = max([int(n) for n in placeholders(en_keys[key])] or [0])
            except ValueError:
                continue
            if nargs is not None and nargs < wanted:
                line = text[:m.start()].count('\n') + 1
                error('%s:%d' % (where, line), '%s needs %d argument(s), the call passes %d' % (key, wanted, nargs))
    return used


def main():
    tables = check_languages()
    compare_with_en(tables)
    used = check_lua(tables)
    keys = sum(len(d) for n, d in tables.get('EN', {}).items() if n != MOD_JSON)
    for line in errors:
        print(line)
    print('%d languages, %d EN keys, %d key uses in Lua, %d errors' % (len(tables), keys, used, len(errors)))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
