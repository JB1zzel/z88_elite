; chart2.asm - the chart cursor list and the list of systems (see chart.asm), over the
; game's own crosshair drawing (E52E jumps here; E531-E6AC is never reached); segment 3,
; so nothing here touches the map while it is bound into segment 3
        module  chart2
        include "memory.def"
        include "elite.inc"
        include "glue.def"
        include "chart.def"
        include "ovl3.def"
        include "chart6.def"
        include "ovl4.def"
        include "snd.def"
        org     $E531

        jp      ch_cross                ; E52E (the game's crosshair) jumps here
        jp      ch_list                 ; OV_LIST
        jp      ch_cond                 ; OV_COND

; ch_cross: replaces the game's crosshair (E52E) on the charts: XOR it into the map.  A
; crosshair drawn again at the same place is the game erasing it.
ch_cross:
        push    af
        push    bc
        push    de
        push    hl
        push    ix
        ld      a,(TX_VIEW)
        ld      (CH_VIEW),a
        ld      hl,($D051)              ; CX_TMP = x, y, arm
        ld      (CX_TMP),hl
        ld      a,($E52B)
        ld      (CX_TMP+2),a
        call    lhi                     ; (the system under the cursor)
        ld      hl,CX_TAB
        ld      a,(CX_N)
        and     a
        jr      z,cc_add
        ld      b,a
cc_f:   push    hl
        ld      de,CX_TMP
        ld      c,3
cc_c:   ld      a,(de)
        cp      (hl)
        jr      nz,cc_n
        inc     hl
        inc     de
        dec     c
        jr      nz,cc_c
        jr      cc_rm
cc_n:   pop     hl
        inc     hl
        inc     hl
        inc     hl
        djnz    cc_f
cc_add: ld      a,(CX_N)
        cp      4
        jr      nc,cc_go
        inc     a
        ld      (CX_N),a
        ex      de,hl
        ld      hl,CX_TMP
        ld      bc,3
        ldir
        jr      cc_go
cc_rm:  pop     de                      ; DE = this entry: the last one moves in
        ld      a,(CX_N)
        dec     a
        ld      (CX_N),a
        ld      c,a
        add     a,a
        add     a,c
        ld      c,a
        ld      b,0
        ld      hl,CX_TAB
        add     hl,bc
        ld      bc,3
        ldir
cc_go:  ld      c,1
        call    mbind
        push    bc
        ld      hl,CX_TMP
        call    cx_draw
        pop     bc
        ld      c,1
        call    MPB
        call    MFFULL                  ; (a 240-pixel map: VBUF to it)
        pop     ix
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; ch_list: the short-range chart's systems, numbered, in window 1 rows 1-4 (4 x 12):
; the one under the cursor in reverse, a "*" after the name if it is within jump range
ch_list:
        xor     a
        ld      (LB_DIRTY),a
        ld      ix,LB_TAB
        ld      c,0                     ; C = number - 1
cl_row: call    out_room
        ld      a,1                     ; cursor to column 0, row C/4 + 1
        call    out_byte
        ld      a,'3'
        call    out_byte
        ld      a,'@'
        call    out_byte
        ld      a,32
        call    out_byte
        ld      a,c
        rrca
        rrca
        and     $3F
        add     a,33
        call    out_byte
        ld      b,4
cl_ent: push    bc
        call    out_room
        ld      a,(LB_N)
        cp      c
        jr      z,cl_sp
        jr      c,cl_sp
        ld      a,(LB_HI)               ; under the cursor: reverse
        cp      c
        ld      a,'+'
        call    z,cl_rev
        inc     c                       ; number, right aligned in 2
        ld      a,c
        ld      b,'0'-1
cl_10:  inc     b
        sub     10
        jr      nc,cl_10
        add     a,'0'+10
        ld      d,a
        ld      a,b
        cp      '0'
        jr      nz,cl_t
        ld      a,' '
cl_t:   call    out_byte
        ld      a,d
        call    out_byte
        ld      a,' '
        call    out_byte
        push    ix
        pop     hl
        inc     hl
        inc     hl
        ld      b,9                     ; name, then the marker, padded to 9
        call    out_room
cl_n:   ld      a,(hl)
        and     a
        jr      z,cl_m
        call    out_byte
        inc     hl
        djnz    cl_n
cl_m:   pop     de                      ; (E = number - 1)
        push    de
        ld      a,(LB_HI)
        cp      e
        ld      a,'-'
        call    z,cl_rev
        push    bc
        call    out_room
        call    inr
        pop     bc
        ld      a,'*'
        jr      c,cl_p
cl_p1:  ld      a,' '
cl_p:   call    out_byte
        djnz    cl_p1
        call    out_room
        ld      de,LB_SZ
        add     ix,de
        pop     bc
        inc     c
        jr      cl_nx
cl_sp:  ld      b,12                    ; no system: blanks
cl_s1:  ld      a,' '
        call    out_byte
        ld      a,b
        cp      6
        call    z,out_room
        djnz    cl_s1
        pop     bc
        inc     c
cl_nx:  dec     b
        jp      nz,cl_ent
        ld      a,c
        cp      16
        jp      c,cl_row
        ld      a,$FF
        ld      (TX_LY),a
        ret
cl_rev: push    af                      ; reverse on ('+') or off ('-')
        ld      a,1
        call    out_byte
        ld      a,'2'
        call    out_byte
        pop     af
        call    out_byte
        ld      a,'R'
        jp      out_byte


; ch_cond (kept here for room; instr.asm, in flight): the condition letter -> A: 'R' with
; two energy banks (nearly) empty, else from the ship slots (snd_cond)
ch_cond:
        ld      hl,$70F6                ; energy banks 1-4 (bars 8-11)
        ld      bc,$0400
cn_e:   ld      a,(hl)
        cp      16
        jr      nc,cn_f
        inc     c
cn_f:   inc     hl
        inc     hl
        djnz    cn_e
        ld      a,c
        cp      2
        ld      a,'R'
        ret     nc
        jp      SND_COND
