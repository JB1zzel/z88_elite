#!/usr/bin/env python3
"""scanbg.inc (8 rows x 88 bytes) -> scanrle.inc: per-row zero-run RLE.
Each row: literal non-zero bytes, or 0,n for n zero bytes (runs stay within the row).
scanrt: 8 row pointers."""
import re, sys
src, dst = sys.argv[1], sys.argv[2]
d = [int(x, 16) for x in re.findall(r'\$([0-9A-Fa-f]{2})', open(src).read())]
assert len(d) == 8 * 88
out = ['; made by tools/mkscanrle.py from scanbg.inc', 'scanrt:']
out.append('        defw    ' + ','.join('sbr%d' % r for r in range(8)))
for r in range(8):
    row = d[r * 88:(r + 1) * 88]
    enc = []
    i = 0
    while i < 88:
        if row[i] == 0:
            j = i
            while j < 88 and row[j] == 0:
                j += 1
            enc += [0, j - i]
            i = j
        else:
            enc.append(row[i])
            i += 1
    out.append('sbr%d:' % r)
    for k in range(0, len(enc), 16):
        out.append('        defb    ' + ','.join('$%02X' % b for b in enc[k:k + 16]))
open(dst, 'w').write('\n'.join(out) + '\n')
