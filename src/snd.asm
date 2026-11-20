; snd.asm - the speaker for the game's own sound code, and the condition box's ship
; scan (mpm module).  The game's sound code runs where the Spectrum has it (9527-96BE:
; the blocking effects, the per-frame player at 9579, called 50 times a second by the
; glue); its OUT ($FE),A to the beeper (bit 4) and the instruction before each become a
; CALL here (patched by tools/skool2mpm.py), the Z88 speaker being Blink COM's SBIT
; (bit 6) with the other bits as OZ keeps them (BLSC_COM).  Each call takes about 70 T
; more than the OUT, so the sound is a little lower than on the Spectrum.
        module snd
        org     $978B                   ; dead game code: the Spectrum blip plot after
                                        ; 9788 JP JT_Z_BLIP (978B-982D); segment 2
        include "blink.def"
        include "elite.inc"
        xdef    s_and, s_on, s_off, s_be, beeper, snd_cond, dk_roll, dk_ok

s_and:  and     $18             ; 95B0: AND $18 / OUT ($FE),A
        jr      spk_a
s_on:   ld      a,$10           ; 95F8, 7352: LD A,$30 / OUT ($FE),A
        jr      spk_a
s_off:  xor     a               ; 95FF, 735A: XOR A / OUT ($FE),A
        jr      spk_a
s_be:   ld      b,e             ; 9631, 9637: LD B,E / OUT ($FE),A
spk_a:  and     $10             ; the beeper bit of A to SBIT (A, flags change)
        ld      a,(BLSC_COM)
        res     6,a
        jr      z,spk_w
        set     6,a
spk_w:  out     ($B0),a
        ret

; beeper: the ROM BEEPER ($03B5, called at 9BCC and E1F4) on the Z88 speaker: DE cycles
; of a half cycle of 4 * (HL + 30) T at 3.5 MHz.  The delay loop takes 26 T a turn and
; there are about 70 T around it, so HL >> 3 + HL >> 6 + 2 turns keep the ROM's pitch
; at the Z88's 3.2768 MHz.  AF, BC, DE, HL change.
beeper: di
        push    de
        ld      d,h
        ld      e,l
        ld      b,3
bp_s3:  srl     h
        rr      l
        djnz    bp_s3           ; HL >> 3
        ld      b,6
bp_s6:  srl     d
        rr      e
        djnz    bp_s6           ; DE = HL >> 6
        add     hl,de
        inc     hl
        inc     hl
        pop     de
        ld      a,(BLSC_COM)
        res     6,a
        ld      c,a
bp_cyc: ld      a,c
        set     6,a
        call    bp_half
        ld      a,c
        call    bp_half
        dec     de
        ld      a,d
        or      e
        jr      nz,bp_cyc
        ei
        ret
bp_half:out     ($B0),a
        push    hl
bp_dly: dec     hl
        ld      a,h
        or      l
        jr      nz,bp_dly
        pop     hl
        ret

; dk_roll: the end of the docking check (dock.asm; here for room).  Strict docking
; at its BBC setting (V_STRICT 2) adds the BBC's roll check: the slot within 33.6
; degrees of level (the BBC: |roofv_x_hi| at least 80 of its unit vector's 96), else
; the Spectrum's bounce (B595).  The Spectrum's unit vectors are 127 long (a station
; in the original: roofv 56, 115, 0), so here |roofv_x_hi| (IX+$10) at least 106.
ROLL_MIN equ 106                ; 127 * 80/96 (mpm names ignore case: not DK_ROLL)
dk_roll:ld      a,(V_STRICT)
        cp      2
        jr      c,dk_ok
        ld      a,(ix+$10)
        add     a,a             ; |roofv_x_hi| * 2 (the sign dropped)
        cp      ROLL_MIN*2
        jp      c,$B595         ; the slot too far off level
dk_ok:  ld      a,1             ; docked (B58F)
        ld      ($9C9A),a
        ret

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
