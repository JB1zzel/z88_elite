; snd.asm - sound effects on the Z88's speaker (mpm module, linked by glue.prj)
;
; The Spectrum game makes its effects by toggling the beeper in timed loops (in the
; frame interrupt, or blocking for the longer ones), which on the Z88 only burns time.
; Here every effect is the Blink's own 3200 Hz tone (COM register, SRUN) switched on
; and off once per 20 ms frame following a short pattern - no loops, no cost.
; The game's sound switch is kept: bit 7 of $FC0E (freeze the game, then S on, Q off).
        module snd
        org     $978B                   ; dead game code: the Spectrum blip plot after
                                        ; 9788 JP JT_Z_BLIP (978B-982D); segment 2
        include "blink.def"
        include "elite.inc"
        include "ovl.def"               ; data kept in dead game code (ovl.asm)
        xdef    snd_tick, snd_off, beep, snd_blk, snd_err

; per-frame (from the frame work): the next frame of the effect playing, else start the
; highest-priority one the game queued in $7128 (lowest bit first, as the game does)
snd_tick:
        ld      a,($FC0E)
        rla
        jr      nc,st_q                 ; sound off: silence, forget the queue
        ld      a,(SND_N)
        and     a
        jr      nz,st_play
        call    snd_off
        ld      a,($7128)
        and     a
        ret     z
        ld      c,a
        dec     a                       ; clear the lowest set bit (it is being served)
        and     c
        ld      ($7128),a
        ld      hl,sndtab-3
st_b:   inc     hl                      ; HL = that bit's entry
        inc     hl
        inc     hl
        rr      c
        jr      nc,st_b
        ld      a,(hl)                  ; frames
        inc     hl
        ld      e,(hl)                  ; pattern (bit 0 first)
        inc     hl
        ld      d,(hl)
; snd_go: A = frames, DE = pattern; plays this frame's step now
snd_go: ld      (SND_P),de
st_play:
        dec     a
        ld      (SND_N),a
        ld      hl,(SND_P)
        srl     h
        rr      l
        ld      (SND_P),hl
        jr      nc,snd_off
snd_on: ld      a,(BLSC_COM)            ; SRUN = 1, SBIT = 0: the 3200 Hz tone
        and     $FF-BM_COMSBIT
        or      BM_COMSRUN
        jr      sc_w
st_q:   xor     a
        ld      ($7128),a
        ld      (SND_N),a
snd_off:
        ld      a,(BLSC_COM)
        bit     BB_COMSRUN,a
        ret     z
        and     $FF-BM_COMSRUN-BM_COMSBIT
sc_w:   ld      (BLSC_COM),a            ; (OZ's copy first, then the register)
        out     (BL_COM),a
        ret

; beep: the ROM BEEPER calls (short beeps, missile lock)
beep:   ld      a,($FC0E)
        rla
        ret     nc
        ld      a,2
        ld      de,$0003
        jr      snd_go

; snd_blk: replaces LD A,($FC0E) at the blocking effects (9527, 9532, 953D, 9548:
; launch, arrival ...): start a longer tone and return to their caller at once
snd_blk:
        pop     hl                      ; (not back into the Spectrum player)
        ld      a,($FC0E)
        rla
        ret     nc
        ld      a,10
        ld      de,$01EF
        jr      snd_go

; snd_err: replaces the freeze menu's error beep (7344)
snd_err:
        ld      a,6
        ld      de,$0015
        jr      snd_go

