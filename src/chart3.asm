; chart3.asm - chart row mapping (see chart.asm), over dead game code 8083-80D0 (after
; 8080 JP JT_Z_CLEAR); segment 2
        module  chart3
        include "elite.inc"
        org     $8083
        xdef    mrow, yfirst

; mrow: A = Spectrum pixel row -> A = map row, NC; C if it is off the map
mrow:   sub     24
        ret     c
        ld      l,a
        ld      a,(CH_VIEW)             ; (TX_VIEW: segment 1 may hold the map)
        cp      7
        ld      a,l
        jr      nz,mr_s
        srl     a                       ; galactic: 2 rows each
        cp      64
        ccf
        ret
mr_s:   ld      h,0                     ; short-range: (y - 24) * 64 / 143
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,143
        ld      a,$FF
        or      a
mr_l:   inc     a
        sbc     hl,de
        jr      nc,mr_l
        cp      64
        ccf
        ret

; first Spectrum row of map row A: galactic 24 + 2m, short-range 24 + 143m / 64
yfirst: ld      l,a
        ld      a,(CH_VIEW)
        cp      7
        ld      a,l
        jr      nz,yf_s
        add     a,a
        add     a,24
        ret
yf_s:   ld      h,0
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      b,h
        ld      c,l                     ; 16m
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 128m
        add     hl,bc
        or      a
        sbc     hl,de                   ; 143m
        add     hl,hl
        add     hl,hl                   ; H = 143m / 64
        ld      a,h
        add     a,24
        ret

