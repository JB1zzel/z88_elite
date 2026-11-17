; text.asm - the game's text screens in OZ windows (mpm module, linked by glue.prj)
;
; The game prints text a character at a time (print_char, D499) at row $D046, column
; $D045, with its plotter in XOR ($A9 at $D548) or opaque mode.  Here, every character
; aimed at the Spectrum screen goes to OZ instead:
;   text views (status, market, data, ...): full-width window 3, the Spectrum's 24
;       rows as three bands side by side (rows 0-7 | 8-15 | 16-23), 31 columns each
;       (column 0 is the border and is dropped);
;   flight views 0-3: dashboard messages on row 7 of the instruments window;
;   charts (views 7 and 8): the chart itself is left to the game (shown in the map);
;       its title and the lines under it go to window 1, centred, in place of the
;       instruments.
; A shadow of the characters shown tells an XOR reprint (= erase) from a new character.
        module text
        include "stdio.def"
        include "map.def"
        include "memory.def"
        include "error.def"
        include "director.def"
        include "elite.inc"
        include "ovl.def"               ; data kept in dead game code (ovl.asm)
        xdef    tx_band, tx_erase
        xdef    msg_put, msg_update, msg_reset
        xdef    ti_7426
        xdef    ti_7430
        xdef    tx_clsj
        xdef    tx_frame
        xdef    tx_route
        xdef    tx_shclr
        xref    instr_update
        xref    out_byte
        xref    out_flush
        xref    out_room
        xref    out_setwin
        xref    out_start
        xref    z_redraw



win3:   defb    1,'7','#','3',32,32,32+94,32+8,128,0

; tx_clsj: replaces calls to "clear screen with border" (D61D)
tx_clsj:
        push    af
        push    bc
        push    de
        push    hl
        ld      a,1
        ld      (TX_CLR),a
        call    tx_shclr
        pop     hl
        pop     de
        pop     bc
        pop     af
        jp      $D61D

tx_shclr:
        ld      hl,TX_SHAD
        ld      de,TX_SHAD+1
        ld      bc,24*31-1
        ld      (hl),' '
        ldir
        ld      a,$FF
        ld      (TX_LY),a
        ret

; tx_route: DE = glyph (Spectrum font at $5D70).  Z = printed here (skip the Spectrum
; plot loop), NZ = leave it to the game.  Keeps DE.
tx_route:
        ld      a,(TI_ON)               ; title text, disk menu: always ours
        ld      b,a
        ld      a,(CM_ON)
        or      b
        jr      nz,tr_go
        ld      a,(TX_VIEW)
        cp      7
        jr      z,tr_cv
        cp      8
        jr      nz,tr_go
tr_cv:  ld      a,($D046)               ; a chart: names on it are the game's, the
        call    ch_isrow                ; title and the lines below are text
        jp      nz,tr_game
tr_go:  push    de
        ex      de,hl                   ; code = (glyph - $5D70) / 8 + 32
        ld      de,-$5D70
        add     hl,de
        ld      a,l
        srl     h
        rra
        srl     h
        rra
        srl     h
        rra
        add     a,32
        cp      '#'                     ; the game's icon (two glyphs): UDGs U, V
        jr      nz,tg_1                 ; (bit 7 = a UDG in the shadow)
        ld      a,$80+'U'
tg_1:   cp      '$'
        jr      nz,tg_2
        ld      a,$80+'V'
tg_2:   ld      c,a                     ; C = character
        ld      a,($D045)
        ld      e,a                     ; E = column
        ld      a,($D046)
        ld      d,a                     ; D = row
tr_rc:  ld      a,d
        cp      24
        jp      nc,tr_done
        ld      a,e
        and     a
        jp      z,tr_done               ; (border column)
        cp      32
        jp      nc,tr_done
        ld      a,(TI_ON)
        and     a
        jr      nz,tr_ti
        ld      a,(CM_ON)               ; the disk menu: a text screen whatever the view
        and     a
        jr      nz,tr_txt
        ld      a,(TX_VIEW)
        cp      7
        jr      z,tr_ch
        cp      8
        jr      z,tr_ch
        cp      4
        jr      c,tr_msg
tr_txt:
        call    tx_enter                ; text view: window 3, bands
        ld      a,d                     ; x = (row / 8) * 31 + column - 1
        and     $18
        rrca
        rrca
        rrca
        ld      b,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        sub     b                       ; *31
        add     a,e
        dec     a
        ld      l,a
        ld      a,d
        and     7
        ld      h,a                     ; (L, H) = (x, y)
        jr      tr_put
tr_ti:  call    ti_enter                ; title: window 1, centred (31 -> 50 columns);
        ld      a,e                     ; rows 0-7 one down, rows 8-23 from the top
        add     a,9
        ld      l,a
        ld      a,d
        cp      8
        jr      nc,tt_lo
        inc     a
        jr      tt_c
tt_lo:  sub     8
tt_c:   cp      8
        jr      c,tt_ok
        ld      a,7
tt_ok:  ld      h,a
        jr      tr_put
tr_ch:  call    ch_enter                ; chart text: window 1, centred like the title
        ld      a,e
        add     a,9
        ld      l,a
        ld      a,d
        call    ch_wrow
        ld      h,a
        jr      tr_put
tr_msg: ld      a,'1'                   ; flight: message line, instruments window row 7
        call    out_setwin
        ld      l,e
        ld      h,7
tr_put: push    hl
        ld      a,d                     ; shadow index = row * 31 + column - 1
        ld      l,a
        ld      h,0
        push    de
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 32 row
        or      a
        sbc     hl,de                   ; 31 row
        pop     de
        ld      a,e
        dec     a
        add     a,l
        ld      l,a
        jr      nc,tp_1
        inc     h
tp_1:   ld      a,TX_SHAD/256
        add     a,h
        ld      h,a                     ; HL = shadow cell
        ld      a,(TI_ON)               ; (the title text is reprinted every frame)
        and     a
        jr      nz,tp_new
        ld      a,($D548)               ; XOR mode and the same character: an erase
        cp      $A9
        jr      nz,tp_new
        ld      a,(hl)
        cp      c
        jr      nz,tp_new
        ld      c,' '
tp_new: ld      a,(hl)
        cp      c
        pop     de                      ; DE = (x, y) as E, D
        jp      z,tr_done               ; already showing
        ld      (hl),c
        call    out_room
        ld      a,(TX_LY)               ; cursor already there (after the last one)?
        cp      d
        jr      nz,tp_pos
        ld      a,(TX_LX)
        cp      e
        jr      z,tp_ch
tp_pos: ld      a,1
        call    out_byte
        ld      a,'3'
        call    out_byte
        ld      a,'@'
        call    out_byte
        ld      a,e
        add     a,32
        call    out_byte
        ld      a,d
        add     a,32
        call    out_byte
tp_ch:  ld      a,c
        bit     7,a
        jr      z,tp_c1
        ld      a,1                     ; a UDG: 1 '2' '?' code
        call    out_byte
        ld      a,'2'
        call    out_byte
        ld      a,'?'
        call    out_byte
        ld      a,c
        and     $7F
tp_c1:  call    out_byte
        ld      a,e
        inc     a
        ld      (TX_LX),a
        ld      a,d
        ld      (TX_LY),a
tr_done:
        pop     de
        xor     a                       ; Z: handled
        ret
tr_game:
        or      1                       ; NZ: the game draws it
        ret

; tx_enter: make sure window 3 shows a text screen; clear it if the game cleared its own
; ti_enter: window 1 becomes the title text (instead of the instruments)
ti_enter:
        ld      a,(TI_MODE)
        and     a
        ret     nz
        ld      (CH_MODE),a             ; (a chart's text is over)
        inc     a
        ld      (TI_MODE),a
        ld      (V_PUR),a               ; (the main menu: drop keys queued in play)
        push    bc
        push    de
        push    hl
        ld      a,'1'
        call    out_setwin
        call    out_room
        ld      a,1                     ; select and clear window 1
        call    out_byte
        ld      a,'2'
        call    out_byte
        ld      a,'C'
        call    out_byte
        ld      a,'1'
        call    out_byte
        call    tx_shclr
        call    msg_reset
        pop     hl
        pop     de
        pop     bc
        ret

; ti_7426 / ti_7430: the title loop's two text calls (load commander? / press space)
ti_7426:
        ld      a,1
        ld      hl,$7426
        jr      ti_c
ti_7430:
        ld      a,2
        ld      hl,$7430
ti_c:   push    hl
        push    af
        xor     a                       ; (the disk menu is over)
        ld      (CM_ON),a
        pop     af
        ld      hl,TI_KIND              ; the other text: start window 1 afresh
        cp      (hl)
        jr      z,ti_1
        ld      (hl),a
        xor     a
        ld      (TI_MODE),a
ti_1:   ld      a,1
        ld      (TI_ON),a
        pop     hl
        call    ti_jp
        xor     a
        ld      (TI_ON),a
        ret
ti_jp:  jp      (hl)

tx_enter:
        push    de
        xor     a                       ; (a text screen: the title is over)
        ld      (TI_MODE),a
        ld      (CH_MODE),a
        ld      a,'3'
        call    out_setwin
        ld      a,(TX_MODE)
        and     a
        jr      nz,te_1
        ld      a,1
        ld      (TX_MODE),a
        ld      (TX_CLR),a
        ld      (V_PUR),a               ; (a docked screen: drop keys queued in flight)
        ld      hl,win3                 ; define window 3 (full width)
te_d:   ld      a,(hl)
        and     a
        jr      z,te_1
        call    out_byte
        inc     hl
        jr      te_d
te_1:   ld      a,(TX_CLR)
        and     a
        jr      z,te_x
        xor     a
        ld      (TX_CLR),a
        call    out_room
        ld      a,1                     ; select and clear window 3
        call    out_byte
        ld      a,'2'
        call    out_byte
        ld      a,'C'
        call    out_byte
        ld      a,'3'
        call    out_byte
        ld      a,$FF
        ld      (TX_LY),a
te_x:   pop     de
        ret

; tx_frame: once per frame, interrupts on: back to the flight layout if a frame of the
; view was drawn (or a chart is up) after a text screen, then send pending output
tx_frame:
        ld      a,(TX_BACK)
        and     a
        jr      nz,tf_back
        ld      a,(TX_MODE)
        and     a
        jr      z,tf_out
        ld      a,(TX_VIEW)
        cp      7
        jr      z,tf_back
        cp      8
        jr      nz,tf_out
tf_back:
        xor     a
        ld      (TX_MODE),a
        ld      (TX_BACK),a
        ld      (TI_MODE),a             ; (the title, if up, is drawn again)
        call    out_flush
        ld      a,'1'
        ld      (OUT_WIN),a
        call    out_start
        ld      a,(TX_VIEW)             ; a chart coming up: its text may already be in
        cp      7                       ; the shadow (the windows are about to be cleared)
        jr      z,tf_ch
        cp      8
        jr      z,tf_ch
        xor     a
        ld      (CH_MODE),a
        call    tx_shclr
        call    z_redraw                ; windows, map, instruments
        call    instr_update            ; (charts don't run the per-frame update)
        jr      tf_sc
tf_ch:  call    z_redraw
        call    ch_repaint
tf_sc:  ld      a,2
        ld      (SC_ALL),a
tf_out: jp      out_flush

; ---------------------------------------------------------------------------------------
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

; ch_wrow: A = Spectrum row of chart text -> window 1 row (title 1, the rest 3-7)
ch_wrow:
        cp      3
        jr      nc,cw_1
        ld      a,1
        ret
cw_1:   sub     16
        cp      3
        ret     nc
        ld      a,3
        ret

; ch_enter: window 1 takes the chart's text (cleared on the first, and after the game
; cleared its screen)
ch_enter:
        ld      a,'1'
        call    out_setwin
        ld      a,(CH_MODE)
        and     a
        jr      z,ce_new
        ld      a,(TX_CLR)
        and     a
        ret     z
ce_new: ld      a,1
        ld      (CH_MODE),a
        xor     a
        ld      (TX_CLR),a
        call    msg_reset               ; (no flight text over it)
ch_cls: call    out_room
        ld      a,1                     ; select and clear window 1
        call    out_byte
        ld      a,'2'
        call    out_byte
        ld      a,'C'
        call    out_byte
        ld      a,'1'
        call    out_byte
        ld      a,$FF
        ld      (TX_LY),a
        ret

; ch_repaint: window 1 cleared, then the chart text rows of the shadow printed again
ch_repaint:
        ld      a,1
        ld      (CH_MODE),a
        xor     a                       ; (the window matches the shadow again)
        ld      (TX_CLR),a
        call    ch_cls
        ld      d,0                     ; D = Spectrum row
cr_row: ld      a,d
        call    ch_isrow
        jr      nz,cr_nx
        call    cr_addr                 ; (rows of blanks: nothing to show; rows 0-2
        ld      b,31                    ; share window row 1)
cr_bl:  ld      a,(hl)
        cp      ' '
        jr      nz,cr_go
        inc     hl
        djnz    cr_bl
        jr      cr_nx
cr_go:  call    out_room
        ld      a,1                     ; cursor to (10, window row)
        call    out_byte
        ld      a,'3'
        call    out_byte
        ld      a,'@'
        call    out_byte
        ld      a,32+10
        call    out_byte
        ld      a,d
        call    ch_wrow
        add     a,32
        call    out_byte
        call    cr_addr
        ld      b,31
cr_c:   ld      a,b                     ; (room for the next few)
        and     7
        call    z,out_room
        ld      a,(hl)
        and     $7F
        call    out_byte
        inc     hl
        djnz    cr_c
cr_nx:  inc     d
        ld      a,d
        cp      24
        jr      c,cr_row
        ld      a,$FF
        ld      (TX_LY),a
        ret
cr_addr:                                ; HL = shadow row D (row * 31)
        ld      l,d
        ld      h,0
        ld      b,h
        ld      c,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        or      a
        sbc     hl,bc
        ld      a,TX_SHAD/256
        add     a,h
        ld      h,a
        ret

; ---------------------------------------------------------------------------------------
; Flight text: the game's in-flight messages (Incoming Missile, Energy Low, bounties,
; Game Over ...) go to the right of window 1 instead of into the view.  The game prints
; them into its buffer every frame (and stops when they expire, or prints on alternate
; frames to flash them), so they are collected per frame and only changed cells are sent.
; Spectrum rows below 12 -> window row 3, rows 12-15 -> row 5; columns 6-28 -> 28-50.
; The view's name goes on row 0 (the game prints it only once, into its title cache).


; msg_put: DE = glyph (Spectrum font at $5D70), at ($D045, $D046)
msg_put:
        ld      a,($D046)
        cp      16
        ret     nc
        ld      b,0
        cp      12
        jr      c,mp_1
        ld      b,MSG_W
mp_1:   ld      a,($D045)
        sub     6
        ret     c
        cp      MSG_W
        ret     nc
        add     a,b
        add     a,MSG_NOW%256
        ld      l,a
        ld      h,MSG_NOW/256
        ex      de,hl                   ; char = (glyph - $5D70) / 8 + 32
        ld      bc,-$5D70
        add     hl,bc
        ld      a,l
        srl     h
        rra
        srl     h
        rra
        srl     h
        rra
        add     a,32
        ex      de,hl
        ld      c,a
        ld      a,($D548)               ; XOR mode over the same character: an erase
        cp      $A9
        jr      nz,mp_2
        ld      a,(hl)
        cp      c
        jr      nz,mp_2
        ld      c,' '
mp_2:   ld      (hl),c
        ld      a,1
        ld      (MSG_ANY),a
        ret

; msg_reset: window 1 was redrawn: nothing of ours on it
msg_reset:
        ld      hl,MSG_NOW
        ld      b,4*MSG_W
mr_1:   ld      (hl),' '
        inc     hl
        djnz    mr_1
        ld      a,$FF
        ld      (VN_SHOWN),a
        xor     a
        ld      (MSG_ANY),a
        ld      (MSG_SANY),a
        ret

; msg_update: once per drawn flight frame (interrupts on): view name, changed text cells
msg_update:
        ld      a,(TX_VIEW)
        cp      4
        ret     nc
        ld      hl,VN_SHOWN
        cp      (hl)
        jr      z,mu_txt
        ld      (hl),a
        ld      l,a                     ; name = vn_txt + view * 10
        add     a,a
        add     a,a
        add     a,l
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,vn_txt
        add     hl,de
        ld      a,'1'
        call    out_setwin
        call    out_room
        ld      de,28*256+0             ; (x, y)
        call    mu_at
        ld      b,10
mu_n:   ld      a,(hl)
        call    out_byte
        inc     hl
        djnz    mu_n
mu_txt: ld      a,(MSG_ANY)
        ld      hl,MSG_SANY
        or      (hl)
        jp      z,out_flush
        ld      a,(MSG_ANY)
        ld      (hl),a
        xor     a
        ld      (MSG_ANY),a
        ld      a,'1'
        call    out_setwin
        ld      hl,MSG_NOW
        ld      de,MSG_SHN
        ld      c,3                     ; window row
mu_line:
        ld      b,0                     ; cell in the line
mu_c:   ld      a,(de)
        cp      (hl)
        jr      z,mu_s
        ld      a,(hl)
        ld      (de),a
        push    de
        push    af
        call    out_room
        ld      a,b
        add     a,28
        ld      d,a
        ld      e,c
        call    mu_at
        pop     af
        call    out_byte
        pop     de
mu_s:   ld      (hl),' '
        inc     hl
        inc     de
        inc     b
        ld      a,b
        cp      MSG_W
        jr      c,mu_c
        inc     c
        inc     c
        ld      a,c
        cp      7
        jr      c,mu_line
        jp      out_flush

; mu_at: cursor to (D, E) in the current window (keeps HL, BC)
mu_at:  ld      a,1
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
        jp      out_byte

; ---------------------------------------------------------------------------------------
; The game also blanks text by writing screen pixels directly (the lower text lines
; before a message, a deleted character while typing a name).  On a text screen those
; cells are blanked in the shadow and the window too, so later XOR prints stay right.

; tx_text: Z if this is a text screen (window 3, as tx_route routes it)
tx_text:
        ld      a,(CM_ON)
        and     a
        jr      nz,tt_yes
        ld      a,(TX_VIEW)
        cp      4
        jr      c,tt_no
        cp      7
        jr      z,tt_no
        cp      8
        jr      z,tt_no
tt_yes: xor     a
        ret
tt_no:  or      1
        ret

; tx_cell: Z if text on row D is ours (a text screen, or a chart's text rows).  Keeps DE HL.
tx_cell:
        call    tx_text
        ret     z
        ld      a,(TX_VIEW)
        cp      7
        jr      z,tc_ch
        cp      8
        ret     nz
tc_ch:  ld      a,d
        jp      ch_isrow

; tx_blank: blank the cell at row D, column E (keeps BC DE HL)
tx_blank:
        push    bc
        push    de
        push    hl
        ld      c,' '
        ld      hl,tbl_r                ; tx_route's frame: return address, then DE
        push    hl                      ; (tr_done pops DE and returns)
        push    de
        jp      tr_rc
tbl_r:  pop     hl
        pop     de
        pop     bc
        ret

; tx_band: replaces 'LD B,8 / PUSH BC' at E37D, the lower text-line fill: HL = first
; byte (row 16 + bits 5-7 of L, column = bits 0-4 of L), 30 columns, A = fill byte.
; Does the game's fill, then blanks the cells if this is a text screen.
tx_band:
        push    af
        push    hl
        ld      a,l
        rlca
        rlca
        rlca
        and     7
        add     a,16
        ld      d,a                     ; D = row
        call    tx_cell
        jr      nz,tb_fill
        ld      a,l
        and     $1F
        ld      e,a                     ; E = first column
        ld      b,30
tb_c:   call    tx_blank
        inc     e
        djnz    tb_c
tb_fill:
        pop     hl
        pop     af
        ld      b,8                     ; the game's fill: 8 lines of 30 bytes
tb_l:   push    bc
        ld      b,30
        push    hl
tb_b:   ld      (hl),a
        inc     hl
        djnz    tb_b
        pop     hl
        inc     h
        pop     bc
        djnz    tb_l
        ret

; tx_erase: replaces 'XOR A / LD B,8' at E2F0 (erase the cell left of the cursor while
; typing; $D045 already stepped back): blank that cell too.  Keeps HL.
tx_erase:
        push    hl
        ld      a,($D046)
        ld      d,a
        call    tx_cell
        jr      nz,te_x2
        ld      a,($D045)
        ld      e,a
        call    tx_blank
te_x2:  pop     hl
        xor     a
        ld      b,8
        ret
