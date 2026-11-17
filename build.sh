#!/bin/bash
# build.sh - Elite Z88 card image (elite.epr, 128K)
set -e
cd "$(dirname "$0")/src"
D=${DEVKIT:-/home/claude/in/devkit/z88-devkit}
M=${MPM:-$D/bin/mpm}                                              # mpm 2.2+ (REPT)
Z=${Z88CARD:-$D/bin/z88card}                                       # z88card 2.1+
S=${SKOOL:-/home/claude/in/elite/elite-skoolkit-master/src/elite.skool}
python3 -I ../tools/skool2mpm.py "$S" elite_ref.asm >/dev/null     # the unmodified game (genfast reads its tokens)
$M -b elite_ref.asm
python3 -I ../tools/genfast.py
$M -b -g -m fast.asm                                       # -> fast.def (entry points)
$M -b -g -m fast2.asm                                      # -> fast2.def
test $(stat -c%s fast.bin) -le $((0xB2F0-0xB047))
test $(stat -c%s fast2.bin) -le $((0xB435-0xB349))
$M -b -g -m ovl.asm                                        # -> ovl.def (glue data in dead code)
test $(stat -c%s ovl.bin) -le $((0x8445-0x8391))
$M -I$D/def -b -g -oglue.bin @glue.prj                 # glue modules -> glue.def (jt_*)
G=$(stat -c%s glue.bin); test $G -le $((0x3E00-0x2000)) || { echo "glue too big: $G (variables at \$3E00)"; exit 1; }
python3 -I ../tools/skool2mpm.py "$S" elite_z88.asm --z88 >/dev/null
$M -b elite_z88.asm
$M -I$D/def -b app.asm
test $(stat -c%s elite_z88.bin) = 49152
test $(stat -c%s app.bin) = 16384
dd if=fast.bin of=elite_z88.bin bs=1 seek=$((0xB047-0x4000)) conv=notrunc status=none
dd if=fast2.bin of=elite_z88.bin bs=1 seek=$((0xB349-0x4000)) conv=notrunc status=none
dd if=ovl.bin of=elite_z88.bin bs=1 seek=$((0x8391-0x4000)) conv=notrunc status=none
# 128K card (KLive wants a real EPROM size): game in banks $3C-$3E, application bank $3F.
# 128K card: the 48K game image in banks $3C-$3E, the application bank on top
# (needs z88card 2.2: 2.1 loaded nothing from a binary larger than 16K)
$Z -sz 128 ../elite.epr elite_z88.bin 3c0000 app.bin 3f0000 >/dev/null
echo "elite.epr: $(stat -c%s ../elite.epr) bytes; glue $(stat -c%s glue.bin) bytes"
