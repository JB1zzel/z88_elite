; ovl3.asm - small glue and chart routines kept in dead game code 9852-988D (the end of the
; Spectrum blip plot, 9788 JP JT_Z_BLIP; never reached); segment 2, assembled before the
; glue (-> ovl3.def)
        module  ovl3
        include "elite.inc"
        org     $9852
        xdef    ch_isrow, mbind

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

; bind the map into segment C (1 or 3): CR_HI = its high address byte; B = old bank
mbind:  ld      a,c
        rrca
        rrca
        ld      e,a                     ; segment * $40
        ld      a,(V_MAPA+1)
        and     $3F
        or      e
        ld      (CR_HI),a
        ld      a,(V_MAPB)
        ld      b,a
        call    MPB
        ret

