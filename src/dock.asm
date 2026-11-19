; dock.asm - strict docking (mpm module): the BBC's cone check, as an option (the =
; key; off, the Spectrum's checks alone, by default).  B58F (docked, after the
; Spectrum's checks: the station is friendly, ahead, facing us within its angle)
; jumps here.  Strict: the station must also be within about 21 degrees of straight
; ahead, |x| and |y| at most 3/8 z (a square cone: 21-28 degrees), else the
; Spectrum's bounce (B595: a bump and damage).  IX = the station: x, y, z at
; +0/+1, +3/+4, +6/+7, each below $B4 here (the contact test), so no carries.
; The BBC's roll check (the slot level) is not used.
        module  dock
        org     $85E0                   ; dead game code: the dashboard bars (84D9,
                                        ; CALLs to it go to a RET), after chart4
        include "elite.inc"
        xdef    dk_check

dk_check:
        ld      a,(V_STRICT)
        and     a
        jr      z,dk_ok
        ld      l,(ix+6)
        ld      h,(ix+7)
        srl     h
        rr      l
        srl     h
        rr      l               ; z/4
        ld      d,h
        ld      e,l
        srl     d
        rr      e               ; z/8
        add     hl,de           ; 3/8 z (no carry)
        ld      e,(ix+0)
        ld      d,(ix+1)
        push    hl
        sbc     hl,de
        pop     hl
        jp      c,$B595         ; too far off to the side
        ld      e,(ix+3)
        ld      d,(ix+4)
        sbc     hl,de
        jp      c,$B595         ; too far above or below
dk_ok:  ld      a,1             ; docked (B58F)
        ld      ($9C9A),a
        ret
