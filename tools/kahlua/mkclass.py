"""Write KT.class, a tiny Java main that runs one Lua file in the game's own Kahlua VM.

No javac is installed, so the class file is assembled by hand. KT builds the
environment like LuaManager.init (J2SEPlatform.newEnvironment, which also loads
stdlib.lua from the working directory), compiles the script and prints the
result of pcall. Game globals (require, getText, ZombRand, Events) are missing.

  python3 tools/kahlua/mkclass.py /tmp/kt/KT.class
  G=~/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid
  env -C "$G" "$G/jre64/bin/java" -cp /tmp/kt:"$G/projectzomboid.jar" KT "$PWD/tools/kahlua/t1.lua"

Re-run mkclass.py after a game update: KT uses KahluaThread(Platform, KahluaTable),
the field debugOwnerThread and pcall(Object, Object[]).
"""
import struct, sys
cp = [None]; idx = {}
def add(key, data):
    if key in idx: return idx[key]
    cp.append(data); idx[key] = len(cp)-1; return idx[key]
def utf(s):
    b = s.encode('utf-8'); return add(('u',s), b'\x01'+struct.pack('>H',len(b))+b)
def cls(n): return add(('c',n), b'\x07'+struct.pack('>H',utf(n)))
def string(s): return add(('s',s), b'\x08'+struct.pack('>H',utf(s)))
def nat(n,d): return add(('nt',n,d), b'\x0c'+struct.pack('>HH',utf(n),utf(d)))
def mref(c,n,d): return add(('m',c,n,d), b'\x0a'+struct.pack('>HH',cls(c),nat(n,d)))
def fref(c,n,d): return add(('f',c,n,d), b'\x09'+struct.pack('>HH',cls(c),nat(n,d)))
P='se/krka/kahlua/j2se/J2SEPlatform'; KT='se/krka/kahlua/vm/KahluaTable'; TH='se/krka/kahlua/vm/KahluaThread'
LC='se/krka/kahlua/luaj/compiler/LuaCompiler'
this=cls('KT'); sup=cls('java/lang/Object'); mname=utf('main'); mdesc=utf('([Ljava/lang/String;)V'); codeattr=utf('Code')
utf8s=string('UTF-8'); tname=string('t')
def u2(i): return struct.pack('>H', i)
c = b''
c += b'\xbb'+u2(cls(P))+b'\x59'+b'\xb7'+u2(mref(P,'<init>','()V'))+b'\x4c'
c += b'\x2b'+b'\xb6'+u2(mref(P,'newEnvironment','()L'+KT+';'))+b'\x4d'
c += b'\xbb'+u2(cls('java/lang/String'))+b'\x59'+b'\x2a\x03\x32\x03'+b'\xbd'+u2(cls('java/lang/String'))
c += b'\xb8'+u2(mref('java/nio/file/Paths','get','(Ljava/lang/String;[Ljava/lang/String;)Ljava/nio/file/Path;'))
c += b'\xb8'+u2(mref('java/nio/file/Files','readAllBytes','(Ljava/nio/file/Path;)[B'))
c += b'\x13'+u2(utf8s)+b'\xb7'+u2(mref('java/lang/String','<init>','([BLjava/lang/String;)V'))+b'\x4e'
c += b'\x2d'+b'\x13'+u2(tname)+b'\x2c'+b'\xb8'+u2(mref(LC,'loadstring','(Ljava/lang/String;Ljava/lang/String;L'+KT+';)Lse/krka/kahlua/vm/LuaClosure;'))+b'\x3a\x04'
c += b'\xbb'+u2(cls(TH))+b'\x59\x2b\x2c'+b'\xb7'+u2(mref(TH,'<init>','(Lse/krka/kahlua/vm/Platform;L'+KT+';)V'))+b'\x3a\x05'
c += b'\x19\x05'+b'\xb8'+u2(mref('java/lang/Thread','currentThread','()Ljava/lang/Thread;'))+b'\xb5'+u2(fref(TH,'debugOwnerThread','Ljava/lang/Thread;'))
c += b'\xb2'+u2(fref('java/lang/System','out','Ljava/io/PrintStream;'))+b'\x19\x05\x19\x04'
c += b'\x03\xbd'+u2(cls('java/lang/Object'))+b'\xb6'+u2(mref(TH,'pcall','(Ljava/lang/Object;[Ljava/lang/Object;)[Ljava/lang/Object;'))
c += b'\xb8'+u2(mref('java/util/Arrays','toString','([Ljava/lang/Object;)Ljava/lang/String;'))
c += b'\xb6'+u2(mref('java/io/PrintStream','println','(Ljava/lang/String;)V'))+b'\xb1'
code = struct.pack('>HHI',8,6,len(c))+c+b'\x00\x00\x00\x00'
out = b'\xca\xfe\xba\xbe'+struct.pack('>HH',0,52)+u2(len(cp))+b''.join(cp[1:])
out += struct.pack('>HHHH',0x21,this,sup,0)+u2(0)+u2(1)
out += struct.pack('>HHHH',0x09,mname,mdesc,1)+u2(codeattr)+struct.pack('>I',len(code))+code+u2(0)
open(sys.argv[1],'wb').write(out)
