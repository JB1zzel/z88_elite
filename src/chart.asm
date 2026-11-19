; chart.asm - the charts on the Z88 map (mpm modules chart*.asm, assembled after the
; glue and overlaid on dead game code by build.sh)
;
; The game draws a chart on the Spectrum screen ($4000, in segment 1); ch_render squeezes
; the chart area (rows 24 on) into the 64 rows of the map: galactic 2:1, short-range
; 143 rows into 64.  The short-range chart's names are not drawn by the game: text.asm
; keeps them in a table (LB_TAB) and each system gets its number, drawn in a small font
; next to its star; the names are listed with their numbers in window 1 (ch_list).
; The chart cursor is not drawn on the Spectrum screen either: ch_cross XORs it straight
; into the map (and keeps a list, so a render can put it back), so moving it costs
; nothing - the chart is only rendered again when the game draws something new.
;
; The charts on the Z88 map are spread over dead game code, by segment: the code that
; writes the map runs in segment 2 (the map goes into segment 1 or 3):
;   chart.asm   9551-96BE (the beeper player)      render, cursor drawing, map binding
;   chart3.asm  8083-80D0 (after the 3D clear JP)  row mapping
;   chart4.asm  84DA-8522 (dashboard bars)         numbers
;   chart5.asm  9B02-9B49 (dashboard icons)        digit rows, map addresses, pixels
;   ovl.asm     8391-8444 (dashboard compass)      the digit font (with other glue data)
;   chart2.asm  E531-E6AC (the game's crosshair)   segment 3: the cursor list, the list
;                                                  of systems in window 1 (no map access)
;   chart6.asm  7FC1-8041 (the old screen copy)    segment 1: distances, range, the system
;                                                  under the cursor (no map access)
        module  chart
        include "macros.def"
        include "memory.def"
        include "elite.inc"
        include "chart3.def"
        include "chart4.def"
        include "chart5.def"
        include "ovl3.def"
        org     $9551
        xdef    cx_draw, ch_render

; zxaddr: A = Spectrum pixel row -> HL = its first byte
zxaddr: ld      l,a
        and     7
        ld      h,a
        ld      a,l
        and     $C0
        rrca
        rrca
        rrca
        or      h
        or      $40
        ld      h,a
        ld      a,l
        and     $38
        rlca
        rlca
        ld      l,a
        ret

; ch_render: the whole chart into the map, then the numbers and the cursor(s)
ch_render:
        ld      a,(TX_VIEW)
        ld      (CH_VIEW),a
        ld      c,3
        call    mbind
        push    bc
        xor     a                       ; A = map row
cr_row: push    af
        ld      d,a                     ; DE = map line: CR_HI + m/8, m & 7
        rrca
        rrca
        rrca
        and     $1F
        ld      e,a
        ld      a,(CR_HI)
        add     a,e
        ld      e,d
        ld      d,a
        ld      a,e
        and     7
        ld      e,a
        push    de
        pop     ix                      ; IX = destination
        pop     af
        push    af
        inc     a                       ; rows to OR: first(m + 1) - first(m)
        call    yfirst
        ld      (CX_I),a
        pop     af
        push    af
        call    yfirst
        ld      b,a                     ; B = row
        ld      a,(CX_I)
        sub     b
        ld      c,a                     ; C = how many
        xor     a                       ; first: copy, then OR
cr_src: push    bc
        push    af
        ld      a,b
        call    zxaddr
        push    ix
        pop     de
        pop     af
        push    af
        ld      b,32
        and     a
        jr      nz,cr_or
cr_cp:  ld      a,(hl)
        ld      (de),a
        inc     l
        ld      a,e
        add     a,8
        ld      e,a
        djnz    cr_cp
        jr      cr_nx
cr_or:  ld      a,(de)
        or      (hl)
        ld      (de),a
        inc     l
        ld      a,e
        add     a,8
        ld      e,a
        djnz    cr_or
cr_nx:  pop     af
        pop     bc
        inc     b
        inc     a
        dec     c
        jr      nz,cr_src
        pop     af
        inc     a
        cp      64
        jr      c,cr_row
        pop     bc
        ld      c,3
        oz      Os_Mpb           ; game bank 3 back
        ld      c,1                     ; the numbers and the cursors: map in segment 1
        call    mbind
        push    bc
        ld      a,(LB_N)                ; numbers
        and     a
        jr      z,cr_cx
        ld      hl,LB_TAB
        ld      b,a
        ld      c,1                     ; C = number
cr_lb:  push    bc
        push    hl
        ld      a,(hl)                  ; row -> map row of the glyph's top
        add     a,a
        add     a,a
        add     a,a
        push    hl
        call    mrow
        pop     hl
        jr      c,cr_ln
        ld      (CX_I),a
        inc     hl
        ld      a,(hl)                  ; column -> byte column
        add     a,a
        add     a,a
        add     a,a
        ld      (CX_PM),a
        call    dnum
cr_ln:  pop     hl
        ld      de,LB_SZ
        add     hl,de
        pop     bc
        inc     c
        djnz    cr_lb
cr_cx:  ld      a,(CX_N)                ; cursors
        and     a
        jr      z,cr_x
        ld      b,a
        ld      hl,CX_TAB
cr_c1:  push    bc
        push    hl
        call    cx_draw
        pop     hl
        inc     hl
        inc     hl
        inc     hl
        pop     bc
        djnz    cr_c1
cr_x:   pop     bc
        ld      c,1
        oz      Os_Mpb           ; game bank 1 back
        ret

; cx_draw: HL = x, y, arm: XOR a "+" into the map (in segment 1): the bar across at
; row y, the bar down at column x, each arm/2 to either side
cx_draw:
        ld      a,(hl)
        ld      (CX_X),a
        inc     hl
        ld      a,(hl)
        ld      (CX_Y),a
        inc     hl
        ld      a,(hl)
        srl     a
        ld      (CX_H),a
        ld      a,(CX_Y)                ; across
        call    mrow
        jr      c,cd_dn
        ld      (CX_I),a
        ld      a,(CX_H)
        ld      b,a
        ld      a,(CX_X)
        sub     b
        jr      nc,cd_a1
        xor     a
cd_a1:  ld      c,a                     ; C = from
        ld      a,(CX_X)
        add     a,b
        jr      nc,cd_a2
        ld      a,255
cd_a2:  sub     c
        inc     a
        ld      b,a                     ; B = pixels (256 -> 0: all)
cd_al:  ld      a,c
        call    xpix
        inc     c
        djnz    cd_al
cd_dn:  ld      a,(CX_H)                ; down: rows y-arm/2 .. y+arm/2 within the
        ld      b,a                     ; chart's rows ($E52C-$E52D), one pixel in
        ld      a,(CX_Y)                ; each map row they cover
        sub     b
        jr      nc,cd_d1
        xor     a
cd_d1:  ld      c,a                     ; C = top
        ld      a,($E52C)
        cp      c
        jr      c,cd_d2
        ld      c,a
cd_d2:  ld      a,(CX_Y)
        add     a,b
        ld      b,a                     ; B = bottom
        ld      a,($E52D)
        jr      c,cd_d3
        cp      b
        jr      nc,cd_d4
cd_d3:  ld      b,a
cd_d4:  ld      a,b                     ; (the chart's top is row 24 or below)
        cp      c
        ret     c
        push    bc
        call    mrow
        pop     bc
        jr      nc,cd_d5
        ld      a,63
cd_d5:  ld      (CX_PM),a               ; last map row
        ld      a,c
        call    mrow
        jr      nc,cd_d6
        xor     a
cd_d6:  ld      (CX_I),a
cd_dl:  ld      a,(CX_X)
        call    xpix
        ld      a,(CX_I)
        ld      hl,CX_PM
        cp      (hl)
        ret     nc
        inc     a
        ld      (CX_I),a
        jr      cd_dl

