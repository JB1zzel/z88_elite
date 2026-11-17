; view.asm - the 3D view drawn straight into a Z88-layout back buffer (mpm module, linked by glue.prj)
;
; The game still computes its view in Spectrum coordinates (x 0-255, y 0-127, centre
; $7F/$3F, clipped by the game to that rectangle); each drawing primitive is replaced
; here and scales as it draws:   x' = x * 21 / 32  (0-167)     y' = y / 2  (0-63)
; Buffer at $C000 in the OZ map layout (8x8 cells, bit 7 = left pixel), 256 bytes per
; character row, of which the view uses the first 168 (21 cells):
;       byte(x',y') = $C000 + (y'/8)*256 + (x' AND $F8) + (y' AND 7)
; It is copied to the left of the 256-pixel map every frame (the right 88 pixels are
; for the scanner).
        module view
        include "stdio.def"
        include "map.def"
        include "memory.def"
        include "error.def"
        include "director.def"
        include "elite.inc"
        include "ovl.def"               ; data kept in dead game code (ovl.asm)
        xref    msg_put
        xdef    hk_glyph
        xdef    init_tables
        xdef    scan_restore
        xdef    sq_font
        xdef    view_copy
        xdef    z_blip
        xdef    z_circ
        xdef    z_clear
        xdef    z_line
        xdef    z_plot
        xdef    z_star
        xdef    z_title
        xdef    z_title_end
        xref    tx_route




; ---------------------------------------------------------------------------------------
; scale_x: HL = x (signed) -> HL = x*21/32.   scale_y: HL = y -> HL = y/2.   Keep BC DE.
scale_x:
        ld      a,h                     ; 0..255: table
        and     a
        jr      nz,sx_slow
        ld      h,SXT/256
        ld      l,(hl)
        ld      h,a
        ret
sx_slow:
        push    de
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl                   ; 4x
        push    hl
        add     hl,hl
        add     hl,hl                   ; 16x
        add     hl,de                   ; 17x
        pop     de
        add     hl,de                   ; 21x
        sra     h
        rr      l
        sra     h
        rr      l
        sra     h
        rr      l
        sra     h
        rr      l
        sra     h
        rr      l
        pop     de
        ret
scale_y:
        sra     h
        rr      l
        ret

; centre +/- magnitude:  E = centre, A = magnitude, Fz = 1 for +, 0 for -  ->  HL
cpm:    ld      l,e
        ld      h,0
        ld      e,a
        ld      d,0
        jr      nz,cpm_m
        add     hl,de
        ret
cpm_m:  or      a
        sbc     hl,de
        ret

; ---------------------------------------------------------------------------------------
; z_line: replaces the game's clipped line (B044).  H,L = point 1 (x,y magnitudes from the
; centre), D,E = point 2, C = signs (bit 1/3: x left of centre, bit 0/2: y below).
z_line: push    ix
        push    iy
        ld      a,($B435)               ; the game's colour op: OR C ($B1) or XOR C ($A9)
        ld      (zf_op1),a
        ld      (zf_op2),a
        ld      (zs_op),a
        push    de
        push    bc                      ; point 1 x
        ld      a,h
        push    hl
        ld      e,$7F
        bit     1,c
        call    cpm
        call    scale_x
        ld      (LX0),hl
        pop     hl
        pop     bc
        push    bc
        ld      a,l                     ; point 1 y (bit 0 set = below: centre + mag)
        ld      e,$3F
        bit     0,c
        jr      z,zl_y1m
        cp      a                       ; Z = 1 -> plus
        jr      zl_y1
zl_y1m: or      1                       ; Z = 0 -> minus  (A>0 so the OR leaves A)
        ld      a,l
zl_y1:  call    cpm
        call    scale_y
        ld      (LY0),hl
        pop     bc
        pop     de
        push    bc
        ld      a,d                     ; point 2 x
        ld      h,e                     ; keep y in H
        ld      e,$7F
        bit     3,c
        push    hl
        call    cpm
        call    scale_x
        ld      (LX1),hl
        pop     hl
        pop     bc
        ld      a,h                     ; point 2 y
        ld      e,$3F
        bit     2,c
        jr      z,zl_y2m
        cp      a
        jr      zl_y2
zl_y2m: or      1
        ld      a,h
zl_y2:  call    cpm
        call    scale_y
        ld      (LY1),hl
        call    line16
        pop     iy
        pop     ix
        ret

; line16: draw (LX0,LY0)-(LX1,LY1).  Fast 8-bit path when both ends are inside the view.
line16: ld      hl,(LX0)
        ld      a,VW
        call    in_rng
        jp      nc,ln_slow
        ld      hl,(LX1)
        ld      a,VW
        call    in_rng
        jp      nc,ln_slow
        ld      hl,(LY0)
        ld      a,VH
        call    in_rng
        jp      nc,ln_slow
        ld      hl,(LY1)
        ld      a,VH
        call    in_rng
        jp      nc,ln_slow
        ; --- fast path: 8-bit ends, y0 <= y1 ---
        ld      a,(LY0)
        ld      b,a
        ld      a,(LY1)
        cp      b
        jr      nc,lf_ord
        ld      hl,(LX0)                ; swap the ends
        ld      de,(LX1)
        ld      (LX0),de
        ld      (LX1),hl
        ld      hl,(LY0)
        ld      de,(LY1)
        ld      (LY0),de
        ld      (LY1),hl
lf_ord: ld      a,(LY1)
        ld      hl,LY0
        sub     (hl)
        ld      d,a                     ; D = dy
        ld      a,(LX1)
        ld      hl,LX0
        sub     (hl)
        ld      e,a                     ; E = dx (signed)
        ld      bc,$09CB                ; RRC C / ADD A,8 : rightwards
        ld      a,$C6
        jr      nc,lf_r
        ld      a,e
        neg
        ld      e,a                     ; |dx|
        ld      bc,$01CB                ; RLC C / SUB 8 : leftwards
        ld      a,$D6
lf_r:   ld      (zf_xs1),bc
        ld      (zf_xs2),bc
        ld      (zf_xa1),a
        ld      (zf_xa2),a
        ; start address and mask
        ld      a,(LX0)
        ld      c,a
        ld      a,(LY0)
        ld      b,a
        call    pix_addr                ; HL, C = mask
        ld      a,e
        cp      d
        jr      c,lf_ymaj
        ; x-major: dx+1 pixels, err from dx/2, subtract dy, add dx
        ld      a,d
        ld      (zf_sub1+1),a
        ld      a,e
        ld      (zf_add1+1),a
        ld      b,a
        inc     b
        srl     a
        ld      e,a
lfx:    ld      a,(hl)
zf_op1: or      c
        ld      (hl),a
        dec     b
        ret     z
zf_xs1: rrc     c
        jr      nc,lfx1
        ld      a,l
zf_xa1: add     a,8
        ld      l,a
lfx1:   ld      a,e
zf_sub1: sub    0
        ld      e,a
        jr      nc,lfx
zf_add1: add    a,0
        ld      e,a
        inc     l                       ; y down one row
        ld      a,l
        and     7
        jr      nz,lfx
        ld      a,l
        sub     8
        ld      l,a
        inc     h
        jr      lfx
        ; y-major: dy+1 pixels, err from dy/2, subtract dx, add dy
lf_ymaj:
        ld      a,e
        ld      (zf_sub2+1),a
        ld      a,d
        ld      (zf_add2+1),a
        ld      b,a
        inc     b
        srl     a
        ld      e,a
lfy:    ld      a,(hl)
zf_op2: or      c
        ld      (hl),a
        dec     b
        ret     z
        inc     l                       ; y down
        ld      a,l
        and     7
        jr      nz,lfy1
        ld      a,l
        sub     8
        ld      l,a
        inc     h
lfy1:   ld      a,e
zf_sub2: sub    0
        ld      e,a
        jr      nc,lfy
zf_add2: add    a,0
        ld      e,a
zf_xs2: rrc     c
        jr      nc,lfy
        ld      a,l
zf_xa2: add     a,8
        ld      l,a
        jr      lfy

; --- slow path: 16-bit Bresenham, plotting only inside the view ---
ln_slow:
        ; trivial rejects (both ends beyond the same edge)
        ld      hl,(LX0)
        ld      de,(LX1)
        ld      a,h
        and     d
        rla
        ret     c                       ; both x < 0
        ld      bc,VW-1
        call    gt16                    ; HL > BC ?
        jr      nc,ls_1
        ex      de,hl
        call    gt16
        ret     c                       ; both x > 167
ls_1:   ld      hl,(LY0)
        ld      de,(LY1)
        ld      a,h
        and     d
        rla
        ret     c
        ld      bc,VH-1
        call    gt16
        jr      nc,ls_2
        ex      de,hl
        call    gt16
        ret     c
ls_2:   xor     a
        ld      (LSEEN),a
        ld      hl,(LX1)                ; dx, sx
        ld      de,(LX0)
        or      a
        sbc     hl,de
        ld      bc,1
        jp      p,ls_3
        call    neg_hl
        ld      bc,-1
ls_3:   ld      (LDX),hl
        ld      (LSX),bc
        ld      hl,(LY1)                ; dy, sy  (LDY holds -dy for the test below)
        ld      de,(LY0)
        or      a
        sbc     hl,de
        ld      bc,1
        jp      p,ls_4
        call    neg_hl
        ld      bc,-1
ls_4:   ld      (LSY),bc
        call    neg_hl
        ld      (LDY),hl                ; -dy
        ld      de,(LDX)
        add     hl,de
        ld      (LERR),hl               ; err = dx - dy
ls_lp:  ld      hl,(LX0)                ; plot if inside
        ld      a,VW
        call    in_rng
        jr      nc,ls_out
        ld      c,l
        ld      hl,(LY0)
        ld      a,VH
        call    in_rng
        jr      nc,ls_out
        ld      b,l
        call    pix_addr
        ld      a,(hl)
zs_op:  or      c
        ld      (hl),a
        ld      a,1
        ld      (LSEEN),a
        jr      ls_nx
ls_out: ld      a,(LSEEN)               ; left the view after being in it: done
        and     a
        ret     nz
ls_nx:  ld      hl,(LX0)                ; reached the far end?
        ld      de,(LX1)
        or      a
        sbc     hl,de
        jr      nz,ls_st
        ld      hl,(LY0)
        ld      de,(LY1)
        sbc     hl,de
        ret     z
ls_st:  ld      hl,(LERR)
        add     hl,hl                   ; e2
        push    hl
        ld      de,(LDY)                ; e2 > -dy ?
        or      a
        sbc     hl,de
        jr      z,ls_5
        jp      m,ls_5
        ld      hl,(LERR)
        ld      de,(LDY)
        add     hl,de
        ld      (LERR),hl
        ld      hl,(LX0)
        ld      de,(LSX)
        add     hl,de
        ld      (LX0),hl
ls_5:   pop     hl                      ; e2 < dx ?
        ld      de,(LDX)
        or      a
        sbc     hl,de
        jp      p,ls_lp
        ld      hl,(LERR)
        add     hl,de
        ld      (LERR),hl
        ld      hl,(LY0)
        ld      de,(LSY)
        add     hl,de
        ld      (LY0),hl
        jp      ls_lp

; in_rng: Fc = 1 if 0 <= HL < A (A = 1..255).  Keeps HL, BC, DE.
in_rng: inc     h
        dec     h
        jr      nz,ir_no
        ld      h,a
        ld      a,l
        cp      h
        ld      h,0
        ret
ir_no:  or      a
        ret

; gt16: Fc = 1 if HL > BC (signed).  Keeps HL, BC, DE.
gt16:   push    hl
        or      a
        sbc     hl,bc
        jr      z,gt_no
        jp      pe,gt_ov
        jp      m,gt_no
gt_yes: pop     hl
        scf
        ret
gt_ov:  jp      m,gt_yes                ; overflow: sign reversed
        jr      gt_no
gt_no:  pop     hl
        or      a
        ret

neg_hl: xor     a
        sub     l
        ld      l,a
        sbc     a,a
        sub     h
        ld      h,a
        ret

; pix_addr: B = y' (0-63), C = x' (0-167) -> HL = buffer byte, C = mask.  Keeps DE.
pix_addr:
        ld      a,b
        rrca
        rrca
        rrca
        and     7
        add     a,VBUF/256
        ld      h,a
        ld      a,b
        and     7
        ld      l,a
        ld      a,c
        and     $F8
        or      l
        ld      l,a
        ld      a,c
        and     7
        add     a,MASKT%256
        ld      c,a
        ld      b,MASKT/256
        ld      a,(bc)
        ld      c,a
        ret

; ---------------------------------------------------------------------------------------
; z_clear: replaces "clear 3D area and draw a border" (8080)
z_clear:
        ld      (SAVSP),sp
        ld      a,VBUF/256
zc_row: ld      h,a
        ld      l,VW
        ld      sp,hl
        ld      hl,$0101                ; right edge cell (x' = 167)
        push    hl
        push    hl
        push    hl
        push    hl
        ld      hl,0
        ld      b,19
zc_p:   push    hl                      ; 19 x 4 x 2 = 152 bytes of blank
        push    hl
        push    hl
        push    hl
        djnz    zc_p
        ld      hl,$8080                ; left edge cell (x' = 0)
        push    hl
        push    hl
        push    hl
        push    hl
        inc     a
        cp      VBUF/256+8
        jr      nz,zc_row
        ld      sp,(SAVSP)
        ld      hl,VBUF                 ; top and bottom lines
        ld      de,VBUF+$0707
        ld      b,VW/8
        ld      a,$FF
zc_tb:  ld      (hl),a
        ld      (de),a
        ld      a,l
        add     a,8
        ld      l,a
        ld      a,e
        add     a,8
        ld      e,a
        ld      a,$FF
        djnz    zc_tb
        ret

; ---------------------------------------------------------------------------------------
; z_star: replaces the stardust "address and mask" routine (7D0F).
; X = $80 -/+ ($7F77) (bit 7 of $7F7F = left), Y = $3F +/- ($7F79) (bit 6 = below).
; Out: DE = buffer byte, C = mask (off-view particles get a harmless spare byte).
z_star: ld      a,($7F7F)
        ld      b,a
        ld      a,($7F77)
        ld      e,$80
        bit     7,b
        push    bc
        call    cpm
        pop     bc
        call    scale_x
        push    hl
        ld      a,($7F79)
        ld      e,$3F
        bit     6,b
        jr      z,zs_m
        cp      a
        jr      zs_y
zs_m:   ld      e,$3F
        or      1
        ld      a,($7F79)
zs_y:   call    cpm
        call    scale_y
        pop     de                      ; DE = x', HL = y'
        ex      de,hl
        ld      a,VW
        call    in_rng
        jr      nc,zs_off
        ld      c,l
        ex      de,hl
        ld      a,VH
        call    in_rng
        jr      nc,zs_off
        ld      b,l
        call    pix_addr
        ex      de,hl
        ret
zs_off: ld      de,$CFF8                ; outside the view buffer (spare RAM)
        ld      c,0
        ret

; ---------------------------------------------------------------------------------------
; z_plot: replaces "plot pixel" (A83C): B = y, C = x in Spectrum view coordinates
z_plot: ld      l,c
        ld      h,0
        call    scale_x
        ld      a,b
        srl     a
        cp      VH
        ret     nc
        ld      b,a
        ld      a,l
        cp      VW
        ret     nc
        ld      c,a
        call    pix_addr
        ld      a,(hl)
        xor     c                       ; (the game's plot XORs)
        ld      (hl),a
        ret

; ---------------------------------------------------------------------------------------
; z_circ: replaces the call to the circle rasterizer at 86E9.  Charts (the rasterizer
; retargeted: SET 7,H at $89DA turned into NOPs) still use the original; the explosion
; flash retargets it too (to the Spectrum screen) but is drawn here, in the view.
; Centre = ($80 +/- $861B, $40 +/- $861A) (signs: $861C bit 1 = left, bit 0 = below),
; radius $861D.  Drawn as an ellipse rx = r*21/32, ry = r/2, row by row (at most 64 rows).
z_circ: ld      a,($89DA)
        cp      $CB
        jr      z,zc_go
        ld      a,(TX_VIEW)             ; retargeted: on a chart, the original draws
        cp      7                       ; the chart's circle; otherwise it is the
        jp      z,$86EE                 ; explosion flash (8F0D), which the Spectrum
        cp      8                       ; draws straight onto the screen - here into
        jp      z,$86EE                 ; the view, like any other circle
zc_go:
        push    ix
        push    iy
        ld      a,($861C)               ; signs and near-axis bits
        ld      b,a
        ld      a,($861B)               ; column offset; near-axis bit 2 clear = the
        ld      e,a                     ; projection overflowed: offset + 256 (as the
        ld      d,0                     ; original's edge tests treat it)
        bit     2,b
        jr      nz,zc_x1
        inc     d
zc_x1:  ld      hl,$0080
        bit     0,b                     ; bit 0 set: right of centre
        jr      z,zc_x2
        add     hl,de
        jr      zc_x3
zc_x2:  or      a
        sbc     hl,de
zc_x3:  call    scale_x
        ld      (CCX),hl
        ld      a,($861A)               ; row offset; bit 3 clear = offset + 256
        ld      e,a
        ld      d,0
        bit     3,b
        jr      nz,zc_y1
        inc     d
zc_y1:  ld      hl,$0040
        bit     1,b                     ; bit 1 clear: below centre
        jr      nz,zc_y2
        add     hl,de
        jr      zc_y3
zc_y2:  or      a
        sbc     hl,de
zc_y3:  call    scale_y
        ld      (CCY),hl
        ld      a,($861D)
        ld      l,a
        ld      h,0
        call    scale_x
        ld      a,l
        ld      (CRX),a
        ld      a,($861D)
        srl     a
        ld      (CRY),a
        and     a
        jp      z,zcr_x
        xor     a
        ld      (CMODE),a
        call    make_w                  ; CWTAB[dy] = half-width, dy = 0..ry
        ; rows y0 = max(0, cy-ry) .. y1 = min(63, cy+ry), counted in 8 bits
        ld      hl,(CCY)
        ld      a,(CRY)
        ld      e,a
        ld      d,0
        or      a
        sbc     hl,de                   ; cy - ry
        bit     7,h
        jr      z,zq1
        ld      hl,0
zq1:    ld      a,h
        and     a
        jp      nz,zcr_x                ; top below the view
        ld      a,l
        cp      VH
        jp      nc,zcr_x
        ld      (CY),a                  ; y0
        ld      hl,(CCY)
        add     hl,de                   ; cy + ry
        bit     7,h
        jp      nz,zcr_x                ; bottom above the view
        ld      a,h
        and     a
        ld      a,VH-1
        jr      nz,zq2
        ld      a,l
        cp      VH
        jr      c,zq2
        ld      a,VH-1
zq2:    ld      hl,CY
        sub     (hl)
        jp      c,zcr_x
        inc     a
        ld      (CYEND),a               ; rows to do
        ld      hl,(CCY)                ; dy = cy - y0 (|dy| <= ry <= 127)
        ld      e,(hl)
        ld      a,(CY)
        ld      e,a
        ld      d,0
        or      a
        sbc     hl,de
        ld      a,l
        ld      (CDY),a
zr_lp:  ld      a,(CDY)
        bit     7,a
        jr      z,zr_p
        neg
zr_p:   ld      l,a                     ; |dy|
        ld      h,CWTAB/256
        ld      e,(hl)                  ; w
        ld      d,e
        and     a
        jr      z,zr_1
        dec     l
        ld      d,(hl)                  ; inner row's width
zr_1:   ld      a,d
        cp      e
        jr      z,zr_2
        dec     a
zr_2:   ld      d,a                     ; D = outer end, E = w
        ld      a,(CY)                  ; row address parts for span
        ld      b,a
        and     7
        ld      (ROWL),a
        ld      a,b
        rrca
        rrca
        rrca
        and     7
        add     a,VBUF/256
        ld      (ROWH),a
        push    de                      ; right: cx+w .. cx+outer
        ld      c,d
        ld      d,0
        ld      hl,(CCX)
        add     hl,de
        push    hl
        ld      hl,(CCX)
        ld      e,c
        add     hl,de
        ex      de,hl
        pop     hl
        call    span
        pop     de                      ; left: cx-outer .. cx-w
        ld      c,d
        ld      d,0
        ld      hl,(CCX)
        or      a
        sbc     hl,de
        push    hl
        ld      hl,(CCX)
        ld      e,c
        or      a
        sbc     hl,de
        pop     de
        call    span
        ld      hl,CY
        inc     (hl)
        ld      hl,CDY
        dec     (hl)
        ld      hl,CYEND
        dec     (hl)
        jp      nz,zr_lp
zcr_x:  pop     iy
        pop     ix
        ret

; make_w: CWTAB[dy] = rx * sqrt(1 - (dy/ry)^2) for dy = 0..ry.  One division for the
; whole circle (index step = 64*256/ry), then additions and table multiplies.
make_w: ld      a,(CRX)                 ; same radii as last time: table still valid
        ld      hl,MW_RX
        cp      (hl)
        jr      nz,mw_new
        ld      a,(CRY)
        inc     hl
        cp      (hl)
        ret     z
mw_new: ld      a,(CRX)
        ld      (MW_RX),a
        ld      a,(CRY)
        ld      (MW_RY),a
        ld      hl,16384
        ld      a,(CRY)
        ld      c,a
        call    div16_8                 ; HL = step (8.8 fixed point)
        ex      de,hl                   ; DE = step
        ld      hl,0                    ; HL = index accumulator
        ld      ix,CWTAB
        ld      a,(CRY)
        inc     a
        ld      b,a                     ; ry+1 entries
mw_lp:  push    bc
        push    hl
        push    de
        ld      a,h
        cp      65
        jr      c,mw_1
        ld      a,64
mw_1:   ld      e,a
        ld      d,0
        ld      hl,qtab
        add     hl,de
        ld      e,(hl)                  ; T (0..255)
        ld      a,(CRX)
        call    mulq                    ; HL = A * E
        ld      (ix+0),h
        inc     ix
        pop     de
        pop     hl
        add     hl,de
        jr      nc,mw_2
        ld      hl,$FF00                ; (saturate)
mw_2:   pop     bc
        djnz    mw_lp
        ret

; mulq: HL = A * E (8 x 8 bits) with the game's own table of squares (n^2, low bytes at
; $BE00, high at $BF00):  a*b = sq((a+b)/2) - sq(|a-b|/2), + min(a,b) when a+b is odd.
; Keeps BC.
mulq:   push    bc
        ld      b,a                     ; B = a, C = b
        ld      c,e
        add     a,e                     ; (a + b) / 2, carry = a + b odd
        rra
        push    af
        ld      l,a
        ld      h,$BE
        ld      e,(hl)
        inc     h
        ld      d,(hl)
        push    de                      ; sq((a+b)/2)
        ld      a,b
        sub     c
        jr      nc,mq_1
        neg
mq_1:   srl     a                       ; |a - b| / 2
        ld      l,a
        ld      h,$BE
        ld      e,(hl)
        inc     h
        ld      d,(hl)                  ; sq(|a-b|/2)
        pop     hl
        or      a
        sbc     hl,de
        pop     af
        jr      nc,mq_x                 ; even: done
        ld      a,b                     ; odd: + min(a, b)
        cp      c
        jr      c,mq_2
        ld      a,c
mq_2:   add     a,l
        ld      l,a
        jr      nc,mq_x
        inc     h
mq_x:   pop     bc
        ret

; div16_8: HL / C -> HL (quotient), A = remainder.  Keeps DE.
div16_8:
        xor     a
        ld      b,16
dv_l:   add     hl,hl
        rla
        jr      c,dv_s
        cp      c
        jr      c,dv_n
dv_s:   sub     c
        inc     l
dv_n:   djnz    dv_l
        ret

; mul8: HL = A * E.  Keeps BC.
mul8:   ld      hl,0
        ld      d,0
        push    bc
        ld      b,8
ml_l:   add     hl,hl
        rla
        jr      nc,ml_n
        add     hl,de
ml_n:   djnz    ml_l
        pop     bc
        ret

; span: OR pixels HL..DE (signed x', clipped to the view) on the row in ROWH/ROWL.
span:   ld      a,d
        and     a
        jr      z,sp_b1
        ret     m                       ; right end left of the view
        ld      e,VW-1
        jr      sp_b2
sp_b1:  ld      a,e
        cp      VW
        jr      c,sp_b2
        ld      e,VW-1
sp_b2:  ld      a,h
        and     a
        jr      z,sp_a1
        ret     p                       ; left end right of the view
        ld      l,0
        jr      sp_a2
sp_a1:  ld      a,l
        cp      VW
        ret     nc
sp_a2:  ld      a,e
        sub     l
        ret     c
        inc     a
        ld      d,a                     ; count
        ld      a,l                     ; mask = MASKT[x AND 7]
        and     7
        add     a,MASKT%256
        ld      c,a
        ld      b,MASKT/256
        ld      a,(bc)
        ld      c,a
        ld      a,(ROWL)                ; address = (ROWH, (x AND $F8) OR ROWL)
        ld      e,a
        ld      a,l
        and     $F8
        or      e
        ld      l,a
        ld      a,(ROWH)
        ld      h,a
sp_lp:  ld      a,(hl)
        or      c
        ld      (hl),a
        dec     d
        ret     z
        rrc     c
        jr      nc,sp_lp
        ld      a,l
        add     a,8
        ld      l,a
        jr      sp_lp


; ---------------------------------------------------------------------------------------
; view_copy: the view (8 rows x 168 bytes) into the left of the map (map bound in seg. 2)
view_copy:
        ld      a,(V_MAPB)
        ld      b,a
        ld      c,2
        rst     OZ_MPB
        push    bc
        ld      a,(V_VAGE)              ; first view frame after a text screen: the whole
        cp      25                      ; scanner panel again
        jr      c,vc_nv
        ld      a,2
        ld      (SC_ALL),a
vc_nv:  ld      a,(SC_ALL)              ; scanner rows to copy: all for a new background,
        and     a                       ; else rows with blips now or last frame
        ld      a,$FF
        jr      nz,vc_all
        ld      a,(SC_RM)
        ld      hl,SC_RMOLD
        or      (hl)
vc_all: ld      (SC_CPY),a
        ld      de,(V_MAPA)
        ld      hl,VBUF
        ld      a,8
        ld      (VC_N),a
vc_lp:  push    hl
        push    de
        rept    VW                      ; view: 168 x LDI
        ldi
        endr
        ld      a,(SC_CPY)              ; scanner row wanted? (bit 0 = this row)
        rrca
        ld      (SC_CPY),a
        jp      nc,vc_ns
        rept    88                      ; scanner panel row: 88 x LDI
        ldi
        endr
vc_ns:  pop     de
        pop     hl
        inc     h
        inc     d
        ld      a,(VC_N)
        dec     a
        ld      (VC_N),a
        jp      nz,vc_lp
vc_x:   pop     bc
        ld      c,2
        rst     OZ_MPB
        ret

; ---------------------------------------------------------------------------------------
; hk_glyph: replaces POP DE / LD B,8 in print_char (D543).  HL = the character's Spectrum
; screen address.  Text aimed at the view buffer ($Cxxx) is drawn here, squeezed to 5x4
; pixels at the scaled position (column $D045, row $D046), and the Spectrum write loop is
; skipped; anything else goes on to the original loop.
hk_glyph:
        ld      (G_HL),hl
        pop     hl                      ; return address (D546)
        pop     de                      ; glyph pointer
        ld      a,(TI_ON)               ; title text, disk menu: to OZ
        ld      b,a
        ld      a,(CM_ON)
        or      b
        jr      nz,hg_oz
        ld      a,(TX_VIEW)             ; text views (4+, not the charts 7/8): to OZ
        cp      4
        jr      c,hg_fl
        cp      7
        jr      z,hg_ch
        cp      8
        jr      z,hg_ch
hg_oz:  push    hl
        call    tx_route
        pop     hl                      ; skip the Spectrum plot loop
        ld      hl,(G_HL)
        ret
hg_ch:  push    hl                      ; charts: the title and the lines below to OZ,
        push    de                      ; the chart's own names drawn by the game
        call    tx_route
        pop     de
        pop     hl
        jr      nz,hg_addr
        ld      hl,(G_HL)
        ret
hg_fl:  ld      a,(TT_REC)              ; flight views: the view title (cached, not
        and     a                       ; drawn) as before; other text -> window 1
        jr      nz,hg_addr
        ld      a,(G_HL+1)              ; (only text aimed at the view buffer)
        cp      VBUF/256
        jr      c,hg_game0
        push    hl
        call    msg_put
        pop     hl
        ld      hl,(G_HL)
        ret
hg_game0:
        push    hl
        jr      hg_game
hg_addr:
        ld      a,(G_HL+1)
        cp      VBUF/256
        jr      nc,hg_view
        push    hl
hg_game:
        ld      hl,(G_HL)
        ld      b,8
        ret
hg_view:                                ; DE = glyph in the Spectrum font at $5D70
        ld      a,(TT_REC)              ; the view title pass: not drawn
        and     a
        jp      nz,hg_x
        ex      de,hl
        ld      de,-$5D70
        add     hl,de
        srl     h
        rr      l                       ; (glyph - font) / 2 = index * 4
        ld      de,SQFONT
        add     hl,de
        ld      de,G_ROWS
        ld      bc,4
        ldir
        ld      a,($D045)               ; x' = scale(col * 8)
        add     a,a
        add     a,a
        add     a,a
        ld      l,a
        ld      h,0
        call    scale_x
        ld      a,l
        cp      VW
        jr      nc,hg_x
        ld      c,a                     ; C = x'
        and     7
        ld      (G_SH),a
        ld      b,a                     ; shift entry: skip (7 - x' AND 7) of the 7
        ld      a,7                     ; unrolled 'srl a / rr d' pairs (4 bytes each)
        sub     b
        add     a,a
        add     a,a
        ld      (hg_jr+1),a
        ld      a,($D046)               ; y' = row * 4
        add     a,a
        add     a,a
        cp      VH
        jr      nc,hg_x
        ld      b,a
        call    pix_addr                ; HL = first byte
        ld      de,G_ROWS
        ld      b,4
hg_r:   ld      a,(de)
        inc     de
        push    de
        ld      d,0
hg_jr:  jr      hg_s                    ; (offset set per glyph, above)
hg_s:   srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
hg_p:   call    tt_note
        xor     (hl)
        ld      (hl),a
        ld      a,l
        and     $F8
        cp      VW-8
        jr      nc,hg_q                 ; last cell: nothing spills over
        ld      a,l
        add     a,8
        ld      l,a
        ld      a,d
        call    tt_note
        xor     (hl)
        ld      (hl),a
        ld      a,l
        sub     8
        ld      l,a
hg_q:   inc     l                       ; next pixel row (rows 4r..4r+3 share a cell)
        pop     de
        djnz    hg_r
hg_x:   ld      hl,(G_HL)
        ret                             ; back to print_char's caller

sq5:    include "sq5.inc"

; sq_font: squeeze the 96-character Spectrum font (at $5D70) to 5x4 pixel glyphs, once
sq_font:
        ld      hl,$5D70
        ld      de,SQFONT
        ld      bc,96*4
sf_lp:  push    bc
        ld      a,(hl)
        inc     hl
        or      (hl)
        inc     hl
        push    hl
        ld      l,a
        ld      h,0
        ld      bc,sq5
        add     hl,bc
        ld      a,(hl)
        ld      (de),a
        inc     de
        pop     hl
        pop     bc
        dec     bc
        ld      a,b
        or      c
        jr      nz,sf_lp
        ret

; init_tables: scale table, pixel masks, keyboard selector table
init_tables:
        ld      hl,0                    ; SXT[x] = x*21/32
        ld      de,SXT
it_sx:  push    hl
        call    sx_slow
        ld      a,l
        ld      (de),a
        pop     hl
        inc     hl
        inc     e
        jr      nz,it_sx
        ld      hl,MASKT
        ld      a,$80
it_m:   ld      (hl),a
        inc     hl
        rrca
        jr      nc,it_m
        ld      hl,ZSEL                 ; selector with one 0 bit -> half-row index
        ld      b,0
it_z:   ld      (hl),$FF
        inc     l
        djnz    it_z
        ld      a,$FE
        ld      b,0
it_z2:  ld      l,a
        ld      (hl),b
        inc     b
        rlca
        jr      c,it_z2
        ret

; ---------------------------------------------------------------------------------------
; Scanner.  The game draws its scanner (dotted ellipse, view lines) on the Spectrum
; dashboard at about x 70-177, y 144-187, centre (123.5, 165).  The Z88 panel is the right
; 88 pixels of the map: x' = 212 + (x-124)*3/4, y' = 32 + (y-165).
;
; The panel background is a fixed image (scanbg.inc, made by the build), drawn like the
; Spectrum scanner: ellipse, dotted range lines and the field-of-view V.
        include "scanrle.inc"   ; (scanrt: row pointers, zero runs packed)

; z_blip: replaces the Spectrum blip plot at 9788.  From the game's signed offsets
; ($96C0 x, $96C1 y = stalk, $96C2 z = depth) draw the stalk and 3-pixel end mark in the
; panel, then continue the game's per-ship loop at 982E.
z_blip: ld      a,($96C0)               ; x' = 212 + 3/4 * (X - 124), X = 123+m or 124-m
        ld      b,a
        and     $7F
        bit     7,b
        jr      z,zb_xp
        neg                             ; -m
        jr      zb_x
zb_xp:  dec     a                       ; m - 1
zb_x:   ld      l,a                     ; 3/4 d = d - d/4
        sra     a
        sra     a
        neg
        add     a,l
        add     a,SC_X
        ld      c,a                     ; C = x'
        ld      a,($96C2)               ; base y' = 32 -/+ z (positive z is up)
        ld      b,a
        and     $7F
        bit     7,b
        jr      nz,zb_zn
        neg
zb_zn:  add     a,SC_Y
        ld      b,a                     ; B = base y'
        ld      a,($96C1)               ; stalk: |y| rows, up when y is positive
        ld      d,a
        and     $7F
        ld      e,a
        jr      z,zb_mark
        ld      a,$05                   ; DEC B (up)
        bit     7,d
        jr      z,zb_dir
        ld      a,$04                   ; INC B (down)
zb_dir: ld      (zb_step),a
zb_st:  call    pnl_plot
zb_step: dec    b
        dec     e
        jr      nz,zb_st
zb_mark:
        call    pnl_plot                ; end mark: this pixel and two to its left
        dec     c
        call    pnl_plot
        dec     c
        call    pnl_plot
        jp      $982E

; pnl_plot: C = map x (168..255), B = y' (signed byte): OR the pixel if in the panel
pnl_plot:
        ld      a,b
        cp      VH
        ret     nc                      ; (also catches negative y')
        ld      a,c
        cp      VW
        ret     c
        push    bc
        push    de
        ld      a,b                     ; mark this char row as touched
        rrca
        rrca
        rrca
        and     7
        ld      e,a
        ld      a,1
        inc     e
pp_m:   dec     e
        jr      z,pp_mx
        add     a,a
        jr      pp_m
pp_mx:  ld      hl,SC_RM
        or      (hl)
        ld      (hl),a
        call    pix_addr
        ld      a,(hl)
        or      c
        ld      (hl),a
        pop     de
        pop     bc
        ret

; scan_restore: put the scanner background back into the panel (after it has been copied
; to the map: the game draws the blips after its frame copy, for the next one)
scan_restore:
        ld      a,(SC_ALL)              ; rows to restore: all just after a new background,
        cp      2                       ; else this frame's blip rows
        ld      a,$FF
        jr      z,sr_all
        ld      a,(SC_RM)
sr_all: ld      c,a
        ld      a,(SC_RM)               ; this frame's blip rows become last frame's
        ld      (SC_RMOLD),a
        xor     a
        ld      (SC_RM),a
        ld      a,(SC_ALL)              ; count the whole-panel frames down
        and     a
        jr      z,sr_cd
        dec     a
        ld      (SC_ALL),a
sr_cd:
        ld      a,c
        and     a
        ret     z
        ld      de,VBUF+VW              ; row 0 of the panel
        ld      hl,scanrt
        ld      b,8
sr_lp:  rrc     c
        jr      nc,sr_skip
        push    bc
        push    hl
        push    de
        ld      a,(hl)                  ; HL = this row's packed bytes
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      b,88
sr_dec: ld      a,(hl)                  ; a literal byte, or 0,n = n zero bytes
        inc     hl
        and     a
        jr      z,sr_z
        ld      (de),a
        inc     e
        djnz    sr_dec
        jr      sr_end
sr_z:   ld      c,(hl)
        inc     hl
sr_zl:  ld      (de),a
        inc     e
        dec     b
        dec     c
        jr      nz,sr_zl
        inc     b
        dec     b
        jr      nz,sr_dec
sr_end: pop     de
        pop     hl
        pop     bc
sr_skip:
        inc     hl                      ; next row pointer, next panel row
        inc     hl
        inc     d
        djnz    sr_lp
        ret

; ---------------------------------------------------------------------------------------
; View title cache.  Every flight frame the game prints "FRONT VIEW" (etc.) into the
; view buffer at DA98-DAAA.  The first time, the glyph XORs are recorded; afterwards they
; are replayed and the game's printing is skipped.

; tt_note: A = value about to be XORed at (HL): record it while recording.  Keeps all.
tt_note:
        and     a                       ; XOR with 0 changes nothing: not worth a note
        ret     z
        push    af
        ld      a,(TT_REC)
        and     a
        jr      z,tn_x
        ld      a,(TT_PTR)              ; full: give up recording (no cache this time)
        cp      $FD
        jr      c,tn_ok
        xor     a
        ld      (TT_REC),a
        jr      tn_x
tn_ok:  pop     af
        push    af
        push    de
        ld      de,(TT_PTR)
        ex      de,hl
        ld      (hl),e                  ; address
        inc     hl
        ld      (hl),d
        inc     hl
        ld      (hl),a                  ; value
        inc     hl
        ex      de,hl
        ld      (TT_PTR),de
        pop     de
tn_x:   pop     af
        ret

; z_title (replaces LD HL,$010A at DA98): replay a recorded title, or record this one
z_title:
        ld      a,($70E3)
        ld      hl,TT_VIEW
        cp      (hl)
        jr      nz,zt_rec
        jr      zt_done                 ; (the title is not drawn in the view: text later)
        ld      hl,TT_BUF               ; replay
        ld      de,(TT_END)
zt_lp:  ld      a,l
        cp      e
        jr      nz,zt_go
        ld      a,h
        cp      d
        jr      z,zt_done
zt_go:  ld      c,(hl)
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      a,(bc)
        xor     (hl)
        ld      (bc),a
        inc     hl
        jr      zt_lp
zt_done:
        ld      hl,(TT_CUR)
        ld      ($D045),hl
        pop     hl                      ; (return address DA9B)
        jp      $DAAB                   ; on to the message scan
zt_rec: ld      (hl),$FF                ; record: not valid until the end hook
        ld      hl,TT_BUF
        ld      (TT_PTR),hl
        ld      a,1
        ld      (TT_REC),a
        ld      hl,$010A                ; the instruction replaced
        ret

; z_title_end (replaces CALL $DAB4 at DAAB): finish a recording, then the message scan
z_title_end:
        ld      a,(TT_REC)
        and     a
        jp      z,$DAB4
        xor     a
        ld      (TT_REC),a
        ld      hl,(TT_PTR)
        ld      (TT_END),hl
        ld      hl,($D045)
        ld      (TT_CUR),hl
        ld      a,($70E3)
        ld      (TT_VIEW),a
        jp      $DAB4
