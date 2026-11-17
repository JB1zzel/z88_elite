"""z80snap.py SNAP.z80 OUT.bin - write the 48K RAM ($4000-$FFFF) of a .z80 snapshot (v1/v2/v3)."""
import sys
d = open(sys.argv[1], 'rb').read()
def unz(b, end=None):
    o = bytearray(); i = 0
    while i < len(b):
        if end and b[i:i+4] == b'\x00\xed\xed\x00': break
        if b[i] == 0xED and i+1 < len(b) and b[i+1] == 0xED:
            o += bytes([b[i+3]]) * b[i+2]; i += 4
        else:
            o.append(b[i]); i += 1
    return o
pc = d[6] | d[7] << 8
mem = bytearray(0x10000)
if pc:
    mem[0x4000:] = (unz(d[30:], 1) if d[12] & 0x20 else d[30:30+0xC000])[:0xC000]
else:
    hl = d[30] | d[31] << 8; i = 32 + hl
    pages = {8: 0x4000, 4: 0x8000, 5: 0xC000}
    while i < len(d):
        ln = d[i] | d[i+1] << 8; pg = d[i+2]; i += 3
        blk = d[i:i+0x4000] if ln == 0xFFFF else unz(d[i:i+ln])
        i += 0x4000 if ln == 0xFFFF else ln
        if pg in pages: mem[pages[pg]:pages[pg]+0x4000] = blk
open(sys.argv[2], 'wb').write(mem[0x4000:])
