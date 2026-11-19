#!/bin/bash
# build.sh - Elite Z88 card image (elite.epr, 128K)
set -e
cd "$(dirname "$0")/src"
D=${DEVKIT:-/home/claude/in/devkit/z88-devkit}
M=${MPM:-$D/bin/mpm}                                              # mpm 2.2+ (REPT)
Z=${Z88CARD:-$D/bin/z88card}                                       # z88card 2.2 with -ramapp
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
$M -I$D/def -b -g -m ovl3.asm                              # small glue routines (9852-988D)
test $(stat -c%s ovl3.bin) -le $((0x988E-0x9852)) || { echo "ovl3.asm too big: $(stat -c%s ovl3.bin)"; exit 1; }
for m in chart6:0x7FC1:0x8042 chart3:0x8083:0x80D1 chart5:0x9B02:0x9B4A chart4:0x85A2:0x85E0 dock:0x85E0:0x8619 chart:0x8446:0x85A2; do
  IFS=: read n a e <<< "$m"                                # the charts, over dead game code
  $M -I$D/def -b -g -m $n.asm
  test $(stat -c%s $n.bin) -le $((e-a)) || { echo "$n.asm too big: $(stat -c%s $n.bin) (room $((e-a)))"; exit 1; }
done
$M -I$D/def -b -g -m snd.asm                               # speaker helpers, beeper, condition scan (978B-982D)
test $(stat -c%s snd.bin) -le $((0x982E-0x978B)) || { echo "snd.asm too big"; exit 1; }
$M -I$D/def -b -g -m ovl4.asm                              # (7D12-7D54)
test $(stat -c%s ovl4.bin) -le $((0x7D55-0x7D12)) || { echo "ovl4.asm too big: $(stat -c%s ovl4.bin)"; exit 1; }
$M -I$D/def -b -g -oglue.bin @glue.prj                 # glue modules -> glue.def (jt_*)
G=$(stat -c%s glue.bin); test $G -le $((0x3E00-0x2000)) || { echo "glue too big: $G (variables at \$3E00)"; exit 1; }
for m in chart2:0xE531:0xE6AD; do
  IFS=: read n a e <<< "$m"                                # the charts, over dead game code
  $M -I$D/def -b -g -m $n.asm
  test $(stat -c%s $n.bin) -le $((e-a)) || { echo "$n.asm too big: $(stat -c%s $n.bin) (room $((e-a)))"; exit 1; }
done
python3 -I ../tools/skool2mpm.py "$S" elite_z88.asm --z88 >/dev/null
$M -b elite_z88.asm
$M -I$D/def -b app.asm
test $(stat -c%s elite_z88.bin) = 49152
test $(stat -c%s app.bin) = 16384
dd if=fast.bin of=elite_z88.bin bs=1 seek=$((0xB047-0x4000)) conv=notrunc status=none
dd if=fast2.bin of=elite_z88.bin bs=1 seek=$((0xB349-0x4000)) conv=notrunc status=none
dd if=ovl.bin of=elite_z88.bin bs=1 seek=$((0x8391-0x4000)) conv=notrunc status=none
python3 -I ../tools/mksqfont.py elite_z88.bin sq5.inc 0xCA00    # the squeezed font, ready made
for m in snd:0x978B ovl3:0x9852 ovl4:0x7D12 chart6:0x7FC1 chart:0x8446 chart2:0xE531 chart3:0x8083 chart4:0x85A2 dock:0x85E0 chart5:0x9B02; do
  IFS=: read n a <<< "$m"
  dd if=$n.bin of=elite_z88.bin bs=1 seek=$((a-0x4000)) conv=notrunc status=none
done
# each game bank's signature, in code the game never runs (app.asm finds the banks by it:
# on a card they are the three below the application, in a RAM install anywhere)
printf 'EZ\x88\x01' | dd of=elite_z88.bin bs=1 seek=$((0x70C9-0x4000)) conv=notrunc status=none
printf 'EZ\x88\x02' | dd of=elite_z88.bin bs=1 seek=$((0xA83F-0x4000)) conv=notrunc status=none
printf 'EZ\x88\x03' | dd of=elite_z88.bin bs=1 seek=$((0xC000-0x4000)) conv=notrunc status=none
# the 48K image as three 16K banks, each loaded at the address it is used at (z88card
# records one address per load, for the RAM application header)
dd if=elite_z88.bin of=game1.bin bs=16384 skip=0 count=1 status=none
dd if=elite_z88.bin of=game2.bin bs=16384 skip=1 count=1 status=none
dd if=elite_z88.bin of=game3.bin bs=16384 skip=2 count=1 status=none
# 128K card (KLive wants a real EPROM size): game in banks $3C-$3E, application bank $3F,
# plus the RAM application (z88card -ramapp, Nov 2026): elite.app + elite.ap0-ap3 (legacy
# Installer / OZ 4.6+) and elite-oz5.app (OZ 5, compressed)
$Z -ramapp -sz 128 ../elite.epr game1.bin 3c4000 game2.bin 3d8000 game3.bin 3ec000 app.bin 3fc000 >/dev/null
echo "elite.epr: $(stat -c%s ../elite.epr) bytes; glue $(stat -c%s glue.bin) bytes; RAM app: $(ls ../elite.app ../elite.ap? ../elite-oz5.app | wc -l) files"
