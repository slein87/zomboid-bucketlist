#!/usr/bin/env python3
"""Read-only dumper for projectzomboid.jar class files (javap-like, no JDK needed).

Usage: pzjar.py [jar] [outdir]
Defaults: the Steam install of the game and .cache/jardump in the repo root.
Writes:
  classes.txt   one block per class: header, public fields, public methods with
                parameter names (from LocalVariableTable when present)
  globals.txt   Lua global functions from LuaManager$GlobalObject (@LuaMethod name)
  exposed.txt   classes referenced by LuaManager$Exposer (exposed to Lua)
  strings.txt   identifier-like string literals: literal<TAB>class.method
  events.txt    string literals of LuaEventManager (event names)
"""
import re
import struct
import sys
import zipfile
from pathlib import Path

PRIMS = {'B': 'byte', 'C': 'char', 'D': 'double', 'F': 'float', 'I': 'int',
         'J': 'long', 'S': 'short', 'Z': 'boolean', 'V': 'void'}

# Bytecode instruction lengths (opcode -> total length), variable ones handled apart.
OPLEN = {}
for op in range(256):
    OPLEN[op] = 1
for op in (0x10, 0x12, 0x15, 0x16, 0x17, 0x18, 0x19, 0x36, 0x37, 0x38, 0x39, 0x3a, 0xa9, 0xbc):
    OPLEN[op] = 2
for op in (0x11, 0x13, 0x14, 0x84, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f, 0xa0, 0xa1, 0xa2,
           0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xbb,
           0xbd, 0xc0, 0xc1, 0xc6, 0xc7):
    OPLEN[op] = 3
OPLEN[0xc5] = 4
for op in (0xb9, 0xba, 0xc8, 0xc9):
    OPLEN[op] = 5


def parse_type(desc, i=0):
    dims = 0
    while desc[i] == '[':
        dims += 1
        i += 1
    c = desc[i]
    if c == 'L':
        j = desc.index(';', i)
        name = desc[i + 1:j].replace('/', '.')
        i = j + 1
    else:
        name = PRIMS[c]
        i += 1
    return name + '[]' * dims, i


def parse_method_desc(desc):
    params = []
    i = 1
    while desc[i] != ')':
        t, i = parse_type(desc, i)
        params.append(t)
    ret, _ = parse_type(desc, i + 1)
    return params, ret


def short(t):
    # java.lang.String -> String, zombie.iso.IsoObject -> IsoObject (keep inner $)
    base = t.split('[')[0]
    return base.rsplit('.', 1)[-1] + t[len(base):]


class ClassFile:
    def __init__(self, data):
        self.d = data
        self.p = 0
        assert self.u4() == 0xCAFEBABE
        self.u2()
        self.u2()
        n = self.u2()
        self.cp = [None] * n
        i = 1
        while i < n:
            tag = self.u1()
            if tag == 1:
                ln = self.u2()
                raw = self.d[self.p:self.p + ln]
                self.p += ln
                self.cp[i] = ('utf8', raw.decode('utf-8', errors='replace'))
            elif tag in (3, 4):
                self.cp[i] = ('num', self.u4())
            elif tag in (5, 6):
                self.p += 8
                self.cp[i] = ('wide', None)
                i += 1
            elif tag in (7, 8, 16, 19, 20):
                self.cp[i] = ({7: 'class', 8: 'string', 16: 'mtype', 19: 'module', 20: 'package'}[tag], self.u2())
            elif tag in (9, 10, 11, 12, 17, 18):
                self.cp[i] = ({9: 'field', 10: 'mref', 11: 'imref', 12: 'nat', 17: 'dyn', 18: 'indy'}[tag],
                              (self.u2(), self.u2()))
            elif tag == 15:
                self.cp[i] = ('mh', (self.u1(), self.u2()))
            else:
                raise ValueError('bad cp tag %d' % tag)
            i += 1
        self.access = self.u2()
        self.name = self.cls(self.u2())
        sup = self.u2()
        self.super = self.cls(sup) if sup else None
        self.interfaces = [self.cls(self.u2()) for _ in range(self.u2())]
        self.fields = [self.member() for _ in range(self.u2())]
        self.methods = [self.member() for _ in range(self.u2())]

    def u1(self):
        v = self.d[self.p]
        self.p += 1
        return v

    def u2(self):
        v = struct.unpack_from('>H', self.d, self.p)[0]
        self.p += 2
        return v

    def u4(self):
        v = struct.unpack_from('>I', self.d, self.p)[0]
        self.p += 4
        return v

    def utf(self, i):
        return self.cp[i][1]

    def cls(self, i):
        return self.utf(self.cp[i][1]).replace('/', '.')

    def member(self):
        acc = self.u2()
        name = self.utf(self.u2())
        desc = self.utf(self.u2())
        attrs = {}
        for _ in range(self.u2()):
            an = self.utf(self.u2())
            ln = self.u4()
            attrs[an] = self.d[self.p:self.p + ln]
            self.p += ln
        return {'acc': acc, 'name': name, 'desc': desc, 'attrs': attrs}

    # --- annotations -------------------------------------------------------
    def annotations(self, raw):
        out = []
        q = [0]

        def r2():
            v = struct.unpack_from('>H', raw, q[0])[0]
            q[0] += 2
            return v

        def r1():
            v = raw[q[0]]
            q[0] += 1
            return v

        def elem():
            tag = chr(r1())
            if tag in 'BCDFIJSZs':
                idx = r2()
                e = self.cp[idx]
                return e[1] if e and e[0] == 'utf8' else e
            if tag == 'e':
                r2()
                return self.utf(r2())
            if tag == 'c':
                return self.utf(r2())
            if tag == '@':
                return ann()
            if tag == '[':
                return [elem() for _ in range(r2())]
            raise ValueError(tag)

        def ann():
            t = self.utf(r2())
            pairs = {}
            for _ in range(r2()):
                k = self.utf(r2())
                pairs[k] = elem()
            return (t, pairs)

        for _ in range(r2()):
            out.append(ann())
        return out

    # --- code: parameter names and string literals ---------------------------
    def code_info(self, m):
        raw = m['attrs'].get('Code')
        if raw is None:
            return None, []
        code_len = struct.unpack_from('>I', raw, 4)[0]
        code = raw[8:8 + code_len]
        q = 8 + code_len
        exc = struct.unpack_from('>H', raw, q)[0]
        q += 2 + exc * 8
        nattr = struct.unpack_from('>H', raw, q)[0]
        q += 2
        lvt = {}
        for _ in range(nattr):
            an = self.utf(struct.unpack_from('>H', raw, q)[0])
            ln = struct.unpack_from('>I', raw, q + 2)[0]
            body = raw[q + 6:q + 6 + ln]
            q += 6 + ln
            if an == 'LocalVariableTable':
                cnt = struct.unpack_from('>H', body, 0)[0]
                for k in range(cnt):
                    sp, _l, ni, _di, idx = struct.unpack_from('>HHHHH', body, 2 + k * 10)
                    if sp == 0 and idx not in lvt:
                        lvt[idx] = self.utf(ni)
        strings = []
        i = 0
        try:
            while i < len(code):
                op = code[i]
                if op == 0x12:
                    e = self.cp[code[i + 1]]
                    if e and e[0] == 'string':
                        strings.append(self.utf(e[1]))
                elif op == 0x13:
                    e = self.cp[struct.unpack_from('>H', code, i + 1)[0]]
                    if e and e[0] == 'string':
                        strings.append(self.utf(e[1]))
                if op == 0xaa:  # tableswitch
                    j = (i + 4) & ~3
                    lo, hi = struct.unpack_from('>ii', code, j + 4)
                    i = j + 12 + (hi - lo + 1) * 4
                elif op == 0xab:  # lookupswitch
                    j = (i + 4) & ~3
                    n = struct.unpack_from('>i', code, j + 4)[0]
                    i = j + 8 + n * 8
                elif op == 0xc4:  # wide
                    i += 6 if code[i + 1] == 0x84 else 4
                else:
                    i += OPLEN[op]
        except (IndexError, struct.error):
            pass
        return lvt, strings


ACC_PUBLIC, ACC_STATIC = 0x0001, 0x0008
IDENT = re.compile(r'^[A-Za-z_][A-Za-z0-9_.:/ -]{1,80}$')


def method_sig(cf, m, lvt):
    params, ret = parse_method_desc(m['desc'])
    static = bool(m['acc'] & ACC_STATIC)
    slot = 0 if static else 1
    parts = []
    for t in params:
        nm = (lvt or {}).get(slot)
        parts.append(short(t) + (' ' + nm if nm else ''))
        slot += 2 if t in ('long', 'double') else 1
    name = m['name']
    if name == '<init>':
        name = 'new'
    return ('static ' if static else '') + short(ret) + ' ' + name + '(' + ', '.join(parts) + ')'


def main():
    jar = sys.argv[1] if len(sys.argv) > 1 else str(Path.home() / '.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/projectzomboid.jar')
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent.parent / '.cache' / 'jardump'
    out.mkdir(parents=True, exist_ok=True)
    z = zipfile.ZipFile(jar)
    names = sorted(n for n in z.namelist() if n.endswith('.class')
                   and (n.startswith('zombie/') or n.startswith('se/krka/')))
    fc = open(out / 'classes.txt', 'w')
    fs = open(out / 'strings.txt', 'w')
    globs, exposed, events = [], [], []
    for n in names:
        try:
            cf = ClassFile(z.read(n))
        except Exception as e:  # keep going on odd classes
            fc.write('# PARSE ERROR %s: %s\n' % (n, e))
            continue
        hdr = 'class ' + cf.name + (' extends ' + cf.super if cf.super else '')
        if cf.interfaces:
            hdr += ' implements ' + ', '.join(cf.interfaces)
        fc.write(hdr + '\n')
        for f in cf.fields:
            if f['acc'] & ACC_PUBLIC:
                t, _ = parse_type(f['desc'])
                fc.write('  field %s%s %s\n' % ('static ' if f['acc'] & ACC_STATIC else '', short(t), f['name']))
        for m in cf.methods:
            lvt, strs = cf.code_info(m)
            for s in strs:
                if IDENT.match(s):
                    fs.write('%s\t%s.%s\n' % (s, cf.name, m['name']))
            if cf.name == 'zombie.Lua.LuaEventManager':
                events.extend(strs)
            if not (m['acc'] & ACC_PUBLIC) or m['name'] == '<clinit>':
                continue
            sig = method_sig(cf, m, lvt)
            fc.write('  ' + sig + '\n')
            if cf.name == 'zombie.Lua.LuaManager$GlobalObject':
                luaname = None
                raw = m['attrs'].get('RuntimeVisibleAnnotations')
                if raw:
                    for t, pairs in cf.annotations(raw):
                        if t.endswith('LuaMethod;') and 'name' in pairs:
                            luaname = pairs['name']
                if luaname:
                    globs.append('%s\t%s' % (luaname, sig))
        if cf.name == 'zombie.Lua.LuaManager$Exposer':
            for e in cf.cp:
                if e and e[0] == 'class':
                    exposed.append(cf.utf(e[1]).replace('/', '.'))
    fc.close()
    fs.close()
    (out / 'globals.txt').write_text('\n'.join(sorted(globs)) + '\n')
    (out / 'exposed.txt').write_text('\n'.join(sorted(set(exposed))) + '\n')
    (out / 'events.txt').write_text('\n'.join(sorted(set(events))) + '\n')


if __name__ == '__main__':
    main()
