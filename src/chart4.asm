; chart4.asm - the systems' numbers on the map (see chart.asm), over dead game code
; 84DA-8522 (the dashboard bars, 84D9 RET); segment 2
        module  chart4
        include "elite.inc"
        include "chart5.def"
        org     $84DA
        xdef    dnum

; dnum: number C at map row (CX_I), byte column (CX_PM) * 8, 5 rows (map in segment 1)
dnum:   ld      a,c                     ; tens, units
        ld      b,-1
dn_10:  inc     b
        sub     10
        jr      nc,dn_10
        add     a,10
        ld      c,a                     ; C = units, B = tens
        ld      e,0                     ; E = font row
dn_r:   ld      a,c
        call    fbits                   ; units
        ld      d,a
        ld      a,b
        and     a
        ld      a,d
        jr      nz,dn_2
        rrca                            ; alone: bits 7-5
        rrca
        rrca
        jr      dn_w
dn_2:   ld      a,b                     ; tens in bits 7-5, units in bits 3-1
        call    fbits
        rrca
        rrca
        rrca
        sla     d
        or      d
dn_w:   ld      d,a
        ld      a,(CX_I)
        add     a,e
        cp      64
        ret     nc
        call    maddr
        ld      a,(CX_PM)
        or      l
        ld      l,a
        ld      (hl),d
        inc     e
        ld      a,e
        cp      5
        jr      c,dn_r
        ret

