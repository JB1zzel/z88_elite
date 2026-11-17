; instr.asm - the Spectrum dashboard as UDG instruments in OZ window 1 (mpm module, linked by glue.prj)
;
; Values come straight from the game: the 13 dashboard bars ($70E8 + 2*n, 0-160), the
; missile count ($D083, 0-4) and the compass offsets ($81A6 across, $81A7 up/down, sign
; in bit 7; $81A8 nonzero = object behind).  Each frame only the character cells whose
; UDG changed are printed, with one GN_Sop call.
;
; Layout (window 1, columns from 0):
;   row:  0 FS [7 cells]   SP [7 cells]   compass (cols 24-25, rows 0-1)
;         1 AS             RL (tick)
;         2 FU             DC (tick)
;         3 CT             1
;         4 LT             2
;         5 AL             3
;         6 MS [4 missiles]   4
        module instr
        include "stdio.def"
        include "map.def"
        include "memory.def"
        include "error.def"
        include "director.def"
        include "elite.inc"
        xref    msg_reset
        xdef    in_reset
        xdef    instr_init
        xdef    instr_update
        xdef    out_byte
        xdef    out_flush
        xdef    out_room
        xdef    out_setwin
        xdef    out_start
        xref    puts



; bar n (1..13): window column, row, style (0 fill, 1 tick)
in_bars:
        defb    3,0,0, 3,1,0, 3,2,0, 3,3,0, 3,4,0, 3,5,0       ; 1-6  FS AS FU CT LT AL
        defb    14,0,0                                          ; 7    SP
        defb    14,3,0, 14,4,0, 14,5,0, 14,6,0                  ; 8-11 energy banks 1-4
        defb    14,1,1, 14,2,1                                  ; 12-13 RL DC (ticks)

in_static:
        defb    1,'2','C','1'                                   ; select and clear window 1
        include "udgdef.inc"
        defb    1,'3','@',32+0,32+0
        defm    "FS"
        defb    1,'3','@',32+0,32+1
        defm    "AS"
        defb    1,'3','@',32+0,32+2
        defm    "FU"
        defb    1,'3','@',32+0,32+3
        defm    "CT"
        defb    1,'3','@',32+0,32+4
        defm    "LT"
        defb    1,'3','@',32+0,32+5
        defm    "AL"
        defb    1,'3','@',32+0,32+6
        defm    "MS"
        defb    1,'3','@',32+11,32+0
        defm    "SP"
        defb    1,'3','@',32+11,32+1
        defm    "RL"
        defb    1,'3','@',32+11,32+2
        defm    "DC"
        defb    1,'3','@',32+11,32+3
        defm    "1"
        defb    1,'3','@',32+11,32+4
        defm    "2"
        defb    1,'3','@',32+11,32+5
        defm    "3"
        defb    1,'3','@',32+11,32+6
        defm    "4"
        defb    1,'3','@',32+24,32+0,1,'2','?','M',1,'2','?','N'     ; compass cells
        defb    1,'3','@',32+24,32+1,1,'2','?','O',1,'2','?','P'
        defb    0

ring:   include "ring.inc"

; instr_init: UDGs, labels; forget everything shown (called after the windows are made)
instr_init:
        ld      hl,in_static
        call    puts
        ; fall into in_reset (harmless while the card is in segment 3 at boot)

; in_reset: forget what is shown, so the next update prints every cell
in_reset:
        call    msg_reset               ; (and the flight text)
        ld      hl,IN_SHAD
        ld      de,IN_SHAD+1
        ld      bc,$64-1
        ld      (hl),$FF
        ldir
        ld      hl,IN_VAL
        ld      b,13
ir_v:   ld      (hl),$FF
        inc     hl
        djnz    ir_v
        ret

; out_byte: A -> output buffer (dropped when full)
out_byte:
        push    hl
        ld      hl,(IN_PTR)
        push    af
        ld      a,l
        cp      OUTEND%256
        jr      nc,ob_full
        pop     af
        ld      (hl),a
        inc     hl
        ld      (IN_PTR),hl
        pop     hl
        ret
ob_full:
        pop     af
        pop     hl
        ret

; out_flush: print what is buffered (if anything), start again.  Keeps the interrupt
; state as it was (the game itself runs with interrupts off).
out_flush:
        push    af
        push    bc
        push    de
        push    hl
        ld      hl,(IN_PTR)
        ld      a,l
        cp      OUT_SEL
        jr      z,of_x
        ld      (hl),0
        ld      a,i                     ; P/V = interrupts enabled
        push    af
        ld      hl,OUTBUF
        oz      GN_Sop
        pop     af
        di
        jp      po,of_x
        ei
of_x:   call    out_start
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; out_start: empty buffer holding just "select window OUT_WIN"
out_start:
        ld      hl,OUTBUF
        ld      (hl),1
        inc     hl
        ld      (hl),'2'
        inc     hl
        ld      (hl),'H'
        inc     hl
        ld      a,(OUT_WIN)
        ld      (hl),a
        inc     hl
        ld      (IN_PTR),hl
        ret

; out_setwin: output to window A from here on (flushing what was for the other one)
out_setwin:
        push    hl
        ld      hl,OUT_WIN
        cp      (hl)
        jr      z,osw_x
        call    out_flush
        ld      (hl),a
        call    out_start
        ld      a,$FF                   ; (the text cursor position is per window)
        ld      (TX_LY),a
        ld      a,(hl)
osw_x:  pop     hl
        ret

; out_room: make sure 12 more bytes fit (flushing if not)
out_room:
        push    af
        ld      a,(IN_PTR)
        cp      OUTEND%256-12
        call    nc,out_flush
        pop     af
        ret

; out_cell: print UDG A at window column D, row E
out_cell:
        call    out_room
        push    af
        ld      a,1
        call    out_byte
        ld      a,'3'
        call    out_byte
        ld      a,'@'
        call    out_byte
        ld      a,d
        add     a,32
        call    out_byte
        ld      a,e
        add     a,32
        call    out_byte
        ld      a,1
        call    out_byte
        ld      a,'2'
        call    out_byte
        ld      a,'?'
        call    out_byte
        pop     af
        jp      out_byte

; instr_update: once per drawn frame (interrupts on)
instr_update:
        ld      a,'1'
        call    out_setwin
        ld      ix,in_bars
        ld      iy,IN_SHAD
        ld      hl,$70E8
        ld      b,13
iu_bar: push    bc
        push    hl
        ld      a,13                    ; unchanged value: nothing to do for this bar
        sub     b
        add     a,IN_VAL%256
        ld      e,a
        ld      d,IN_VAL/256
        ld      a,(de)
        cp      (hl)
        jr      nz,iu_chg
        ld      de,7                    ; skip its 7 cell shadows
        add     iy,de
        jr      iu_next
iu_chg: ld      a,(hl)
        ld      (de),a
        ld      a,(hl)                  ; px = value * 67 / 256 (0..41 for 0..160)
        ld      e,a
        ld      d,0
        ld      l,a
        ld      h,d
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 64v
        add     hl,de
        add     hl,de
        add     hl,de                   ; 67v
        ld      c,h                     ; C = px
        ld      a,(ix+2)                ; roll and pitch (ticks): the value is already
        and     a                       ; a pixel position, 0-42 with 21 at the centre
        jr      z,iu_px
        pop     hl
        push    hl
        ld      a,(hl)
        cp      42
        jr      c,iu_tk
        ld      a,41
iu_tk:  ld      c,a
iu_px:  ld      d,(ix+0)                ; D = column, E = row
        ld      e,(ix+1)
        ld      b,0                     ; B = cell index
iu_cell:
        ld      a,(ix+2)
        and     a
        jr      nz,iu_tick
        ld      a,c                     ; fill: 6 while px lasts, then the rest, then 0
        cp      6
        jr      c,iu_part
        sub     6
        ld      c,a
        ld      a,6
        jr      iu_code
iu_part:
        ld      c,0
        jr      iu_code
iu_tick:
        ld      a,c                     ; tick: in the cell where 0 <= px < 6
        cp      $FF
        jr      z,iu_none
        cp      6
        jr      c,iu_here
        sub     6
        ld      c,a
iu_none:
        xor     a
        jr      iu_code
iu_here:
        add     a,'G'-'@'
        ld      c,$FF
iu_code:
        add     a,'@'
        cp      (iy+0)
        jr      z,iu_same
        ld      (iy+0),a
        push    bc
        call    out_cell
        pop     bc
iu_same:
        inc     iy
        inc     d
        inc     b
        ld      a,b
        cp      7
        jr      c,iu_cell
iu_next:
        inc     ix
        inc     ix
        inc     ix
        pop     hl
        inc     hl
        inc     hl
        pop     bc
        dec     b
        jp      nz,iu_bar
        call    in_missiles
        call    in_compass
        jp      out_flush

; missiles: 4 cells at column 3, row 6.  The last ready missile shows the arm state
; ($D047: 1 = armed 'S', 2 = locked 'T'), as the Spectrum colours its indicator.
in_missiles:
        ld      a,($D083)
        ld      c,a
        add     a,a
        add     a,a
        ld      hl,$D047
        or      (hl)
        ld      hl,IN_MISS
        cp      (hl)
        ret     z
        ld      (hl),a
        ld      d,3
        ld      e,6
        ld      b,4
im_lp:  ld      a,c
        and     a
        ld      a,'R'
        jr      z,im_e
        dec     c
        ld      a,'Q'
        jr      nz,im_e                 ; (not the last ready one)
        push    hl
        ld      hl,$D047
        add     a,(hl)                  ; phase 1 -> 'S', 2 -> 'T' (skipping 'R')
        pop     hl
        cp      'Q'
        jr      z,im_e
        inc     a
im_e:   push    bc
        call    out_cell
        pop     bc
        inc     d
        djnz    im_lp
        ret

; compass: redefine UDGs M N O P (2 x 2 cells, 12 x 16 pixels) when the dot moves
in_compass:
        ld      hl,IN_COMP
        ld      a,($81A6)
        cp      (hl)
        jr      nz,ic_new
        inc     hl
        ld      a,($81A7)
        cp      (hl)
        jr      nz,ic_new
        inc     hl
        ld      a,($81A8)
        cp      (hl)
        ret     z
ic_new: ld      a,($81A6)
        ld      (IN_COMP),a
        ld      a,($81A7)
        ld      (IN_COMP+1),a
        ld      a,($81A8)
        ld      (IN_COMP+2),a
        ld      hl,ring                 ; canvas = ring
        ld      de,IN_CBUF
        ld      bc,32
        ldir
        ld      a,($81A6)               ; x = 5 + h*5/8 (h: sign-magnitude, about 0..8)
        call    ic_scale
        add     a,5
        push    af
        ld      a,($81A7)               ; y = 7 - v*5/8 (positive = up)
        call    ic_scale
        neg
        add     a,7
        ld      b,a
        pop     af
        ld      c,a
        ld      hl,ic_ahead             ; marker: solid 2 x 2 ahead, hollow 3 x 3 behind
        ld      a,(IN_COMP+2)
        and     a
        jr      z,ic_mk
        ld      hl,ic_behind
ic_mk:  ld      a,(hl)
        cp      $80
        jr      z,ic_def
        add     a,c
        push    bc
        ld      c,a
        inc     hl
        ld      a,(hl)
        add     a,b
        ld      b,a
        call    ic_dot
        pop     bc
        inc     hl
        jr      ic_mk
ic_def: ld      a,'M'                   ; cells: M = top left, N = top right,
        ld      d,0                     ; O = bottom left, P = bottom right
        ld      e,6
        call    ic_udg
        ld      a,'N'
        ld      d,0
        ld      e,0
        call    ic_udg
        ld      a,'O'
        ld      d,8
        ld      e,6
        call    ic_udg
        ld      a,'P'
        ld      d,8
        ld      e,0
        jp      ic_udg

ic_ahead:
        defb    0,0, 1,0, 0,1, 1,1, $80
ic_behind:
        defb    -1,-1, 0,-1, 1,-1, -1,0, 1,0, -1,1, 0,1, 1,1, $80

; ic_scale: A = sign-magnitude offset -> signed pixels (magnitude * 5/8, max 5)
ic_scale:
        ld      b,a
        and     $7F
        cp      9
        jr      c,is_1
        ld      a,8
is_1:   ld      c,a
        add     a,a
        add     a,a
        add     a,c                     ; 5m
        rrca
        rrca
        rrca
        and     $1F                     ; /8
        bit     7,b
        ret     z
        neg
        ret

; ic_dot: set canvas pixel (C, B) if inside 12 x 16
ic_dot: ld      a,c
        cp      12
        ret     nc
        ld      a,b
        cp      16
        ret     nc
        push    bc
        push    hl
        ld      l,b
        ld      h,0
        add     hl,hl
        push    de
        ld      de,IN_CBUF
        add     hl,de
        pop     de
        ld      a,11
        sub     c                       ; bit index
        ld      bc,1
        and     a
        jr      z,id_s
id_sh:  sla     c
        rl      b
        dec     a
        jr      nz,id_sh
id_s:   ld      a,(hl)
        or      c
        ld      (hl),a
        inc     hl
        ld      a,(hl)
        or      b
        ld      (hl),a
        pop     hl
        pop     bc
        ret

; ic_udg: define UDG A from canvas rows D..D+7, bits shifted right by E (6 = left half)
ic_udg: call    out_room
        push    af
        ld      a,1
        call    out_byte
        ld      a,138
        call    out_byte
        ld      a,'='
        call    out_byte
        pop     af
        call    out_byte
        ld      b,8
iu_r:   push    bc
        ld      l,d
        ld      h,0
        add     hl,hl
        push    de
        ld      de,IN_CBUF
        add     hl,de
        pop     de
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      a,e
        and     a
        jr      z,iu_r2
iu_rs:  srl     h
        rr      l
        dec     a
        jr      nz,iu_rs
iu_r2:  ld      a,l
        and     $3F
        or      $80
        call    out_byte
        inc     d
        pop     bc
        djnz    iu_r
        ret
