; ovl3.asm - small glue routines kept in dead game code 9852-988D (the end of the
; Spectrum blip plot, 9788 JP JT_Z_BLIP; never reached); segment 2, assembled before the
; glue (-> ovl3.def)
        module  ovl3
        include "elite.inc"
        org     $9852
        xdef    ch_isrow, ch_wrow

; Chart text.  ch_isrow: A = Spectrum row; Z if text on that row of the chart now up is
; chart text (title rows 0-2; below the chart: galactic rows 19-23, short-range 21-23).
ch_isrow:
        cp      3
        jr      c,ci_y
        ld      b,a
        ld      a,(TX_VIEW)
        cp      7
        ld      a,b
        jr      nz,ci_s
        cp      19
        jr      nc,ci_y
        jr      ci_n
ci_s:   cp      21
        jr      nc,ci_y
ci_n:   or      1
        ret
ci_y:   xor     a
        ret

; ch_wrow: A = Spectrum row of chart text -> window 1 row (title 0, the rest 3-7)
ch_wrow:
        cp      3
        jr      nc,cw_1
        xor     a                       ; (rows 1-4: the short-range chart's systems)
        ret
cw_1:   sub     16
        cp      3
        ret     nc
        ld      a,3
        ret

