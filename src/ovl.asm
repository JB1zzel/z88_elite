; ovl.asm - glue data that lives in dead game code: the Spectrum dashboard compass
; routine ($8390 is patched to RET; $8391-$8444, 180 bytes, is never run or referenced).
; Read only while the game runs (game bank 2 in segment 2) - never at boot, when the
; game image isn't in place yet.
; Assembled on its own (-> ovl.def for the glue) and overlaid by build.sh.
        module  ovl
        org     $8391
        xdef    qtab, vn_txt, sndtab

; quarter circle: qtab[i] = round(255 * sqrt(1 - (i/64)^2)), i = 0..64
qtab:   include "qtab.inc"

; flight view names (window 1, row 0)
vn_txt: defm    "Front View"
        defm    "Rear View "
        defm    "Left View "
        defm    "Right View"

; request bit -> frames, pattern
sndtab: defb    16
        defw    $5555                   ; 0 energy bomb
        defb    2
        defw    $0001                   ; 1 (fire-key gauge)
        defb    6
        defw    $0033                   ; 2 ship launched / spawned
        defb    3
        defw    $0005                   ; 3 laser hits a ship
        defb    1
        defw    $0001                   ; 4 laser fired
        defb    6
        defw    $003B                   ; 5 missile
        defb    10
        defw    $02B5                   ; 6 explosion
        defb    10
        defw    $02B5                   ; 7 (as 6)
