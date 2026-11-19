; snd.asm - the condition box's ship scan (mpm module, linked by glue.prj).  The game's
; own sound code now plays on the Z88 speaker from the sound bank (sndp.asm, generated
; by tools/mksndp.py); the 3200 Hz tone effects that were here are gone.
        module snd
        org     $978B                   ; dead game code: the Spectrum blip plot after
                                        ; 9788 JP JT_Z_BLIP (978B-982D); segment 2
        include "elite.inc"
        xdef    snd_cond

; snd_cond (kept here for room): the condition from the ship slots 1-7 ($27 bytes from
; $6048; in use: energy $22 nonzero; cargo, boulders, pods: $26 bit 3) -> A = 'G' none,
; 'A' ships about, 'R' a hostile one (spawned hostile: $26 bit 6)
snd_cond:
        ld      ix,$6048+$27
        ld      de,$27
        ld      bc,$0700+'G'
sc_lp:  ld      a,(ix+$22)
        and     a
        jr      z,sc_nx
        bit     3,(ix+$26)
        jr      nz,sc_nx
        bit     6,(ix+$26)
        ld      a,'R'
        ret     nz
        ld      c,'A'
sc_nx:  add     ix,de
        djnz    sc_lp
        ld      a,c
        ret
