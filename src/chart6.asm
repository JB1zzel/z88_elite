; chart6.asm - the short-range chart's distances (see chart.asm), over dead game code
; 7FC1-8041 (the Spectrum back-buffer copy, after 7FBE JP blit); segment 1, so nothing
; here touches the map (which goes into segment 1 for the numbers and the cursor)
        module  chart6
        include "elite.inc"
        org     $7FC1
        xdef    ldist, lsq, lhi

; ldgx (7FC1): replaces CALL $ECFD at ED78 (a system's name on the short-range chart):
; keep its galaxy position for the name's entry (the name generator changes the seed)
ldgx:   call    $ECFD
        ld      a,($DEC3)
        ld      (LB_GX),a
        ld      a,($DEC1)
        ld      (LB_GY),a
        ret

; ldist: IX = system, B = x, C = y (galaxy) -> HL = dx^2 + (dy/2)^2 (the game's
; distance measure, $DFCE)
ldist:  ld      a,(ix+12)
        sub     b
        jr      nc,ld_1
        neg
ld_1:   call    lsq
        push    hl
        ld      a,(ix+13)
        sub     c
        jr      nc,ld_2
        neg
ld_2:   srl     a
        call    lsq
        pop     de
        add     hl,de
        ret
lsq:    ld      l,a                     ; HL = A^2 (the game's squares, $BE00/$BF00)
        ld      h,$BE
        ld      e,(hl)
        inc     h
        ld      d,(hl)
        ex      de,hl
        ret

; lhi: the system under the cursor (the nearest, within 2) into LB_HI; the list is
; printed again when it changes
lhi:    ld      hl,5
        ld      (LB_BS),hl
        ld      a,$FF
        ld      (LB_BI),a
        ld      ix,LB_TAB
        xor     a
lh_l:   ld      hl,LB_N
        cp      (hl)
        jr      nc,lh_x
        push    af
        ld      a,($D0BB)
        ld      b,a
        ld      a,($D0BC)
        ld      c,a
        call    ldist
        ld      de,(LB_BS)
        or      a
        sbc     hl,de
        add     hl,de
        jr      nc,lh_n
        ld      (LB_BS),hl
        pop     af
        push    af
        ld      (LB_BI),a
lh_n:   ld      de,LB_SZ
        add     ix,de
        pop     af
        inc     a
        jr      lh_l
lh_x:   ld      a,(LB_BI)
        ld      hl,LB_HI
        cp      (hl)
        ret     z
        ld      (hl),a
        ld      a,1
        ld      (LB_DIRTY),a
        ret
