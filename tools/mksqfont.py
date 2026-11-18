#!/usr/bin/env python3
"""Put the squeezed font (SQFONT, $CA00: 96 x 4 bytes) straight into the game image.
SQFONT[i] = sq5[font[2i] | font[2i+1]], font = the Spectrum font at $5D70 (96 x 8 bytes),
sq5 = src/sq5.inc (8 pixels -> 5).  (Was sq_font in view.asm, run at start-up.)"""
import re, sys
img, sq5inc, sqaddr = sys.argv[1], sys.argv[2], int(sys.argv[3], 0)
sq5 = [int(x, 16) for x in re.findall(r'\$([0-9A-Fa-f]{2})', open(sq5inc).read())]
assert len(sq5) == 256
d = bytearray(open(img, 'rb').read())
base = 0x4000
font = d[0x5D70 - base:0x5D70 - base + 768]
out = bytes(sq5[font[2 * i] | font[2 * i + 1]] for i in range(384))
d[sqaddr - base:sqaddr - base + 384] = out
open(img, 'wb').write(d)
