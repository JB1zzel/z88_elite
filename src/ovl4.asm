; ovl4.asm - a glue routine kept in dead game code 7D12-7D54 (the Spectrum stardust
; plot, 7D0F JP JT_Z_STAR; never reached); segment 1 (no map access), assembled before
; the glue (-> ovl4.def)
        module  ovl4
        include "elite.inc"
        include "chart6.def"
        org     $7D12
        xdef    inr

; inr: C if system IX is within jump range (4 * sqrt(distance) <= fuel, $DFF2), and
; not the present system
inr:    ld      a,($D099)
        ld      b,a
        ld      a,($D097)
        ld      c,a
        call    ldist
        ld      a,h
        or      l
        ret     z
        push    hl
        ld      a,($D082)               ; s < (fuel / 4 + 1)^2
        srl     a
        srl     a
        inc     a
        call    lsq
        pop     de
        ex      de,hl
        or      a
        sbc     hl,de
        ret

