; chart5.asm - digit rows, map addresses, pixels (see chart.asm), over dead game code
; 9B02-9B49 (the dashboard icons, 9B01 RET); segment 2
        module  chart5
        include "elite.inc"
        include "ovl.def"
        org     $9B02
        xdef    fbits, maddr, xpix

; fbits: A = digit, E = row -> A = its 3 bits in bits 2-0
fbits:  push    hl
        push    de
        ld      l,a
        add     a,a
        add     a,a
        add     a,l                     ; digit * 5 + row
        add     a,e
        ld      e,a
        ld      d,0
        ld      hl,font
        add     hl,de
        ld      a,(hl)
        pop     de
        pop     hl
        ret

; maddr: A = map row -> HL = its line in column 0 (map in segment 1)
maddr:  push    af
        rrca
        rrca
        rrca
        and     $1F
        ld      h,a
        ld      a,(CR_HI)
        add     a,h
        ld      h,a
        pop     af
        and     7
        ld      l,a
        ret

; xpix: XOR pixel x = A in map row (CX_I)
xpix:   push    bc
        push    hl
        ld      b,a
        ld      a,(CX_I)
        call    maddr
        ld      a,b
        and     $F8
        or      l
        ld      l,a
        ld      a,b
        and     7
        ld      b,a
        ld      a,$80
        jr      z,xp_2
xp_1:   rrca
        djnz    xp_1
xp_2:   xor     (hl)
        ld      (hl),a
        pop     hl
        pop     bc
        ret

