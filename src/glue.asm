; glue.asm - Z88 side of the Elite port.  Runs from application RAM at $2000-$3FFF
; (segment 0, always bound).  The Spectrum game sits in three RAM banks bound into
; segments 1-3 at its original addresses; it calls in here through the jump table.
;
; Interrupts: the game runs with interrupts off (its EI/IM 2 are patched out); only
; z_halt enables them, with the stack in segment 0, while it waits for the next 20 ms
; frame and calls OZ.  So the game's SP tricks never meet an OZ interrupt.
        module glue
        include "stdio.def"
        include "map.def"
        include "memory.def"
        include "error.def"
        include "director.def"

        org $2000
        include "blink.def"
        include "elite.inc"
        include "ovl.def"
        include "chart.def"             ; (chart.asm, snd.asm are assembled first)
        include "snd.def"
        include "screen.def"
        xdef    jt_z_halt
        xdef    jt_cm_enter, jt_cm_load, jt_cm_save, jt_tx_band, jt_tx_erase
        xref    tx_band, tx_erase
        xdef    jt_spk_off
        xref    cm_enter, cm_load, cm_save
        xdef    jt_st_bit7hl
        xdef    jt_st_ldafc0d
        xdef    jt_st_ldc4
        xdef    jt_st_kemp
        xdef    jt_st_74de
        xdef    jt_st_djnz
        xdef    jt_st_c632
        xdef    jt_pa22aa
        xdef    jt_pa22b0
        xdef    jt_pa22b1
        xdef    jt_zxin
        xdef    jt_beep
        xdef    jt_z_start
        xdef    jt_z_errhan
        xdef    jt_z_redraw
        xdef    jt_z_blit
        xdef    jt_rd_fc08
        xdef    jt_rd_fc09
        xdef    jt_rd_fc0a
        xdef    jt_rd_fc0b
        xdef    jt_rd_fc0c
        xdef    jt_rd_fc0d
        xdef    jt_rd_fc0e
        xdef    jt_rd_fc0f
        xdef    jt_hk_vertex
        xdef    jt_hk_char
        xdef    jt_z_clear
        xdef    jt_z_line
        xdef    jt_z_star
        xdef    jt_z_plot
        xdef    jt_z_circ
        xdef    jt_hk_glyph
        xdef    jt_z_blip
        xdef    jt_z_title
        xdef    jt_z_title_end
        xdef    jt_tx_clsj
        xdef    jt_ti_7426
        xdef    jt_ti_7430
        xdef    puts
        xdef    z_redraw
        xref    msg_update
        xref    hk_glyph
        xref    in_reset
        xref    init_tables
        xref    instr_init
        xref    instr_update
        xref    out_start
        xref    scan_restore
        xref    ti_7426
        xref    ti_7430
        xref    tx_clsj
        xref    tx_frame
        xref    tx_shclr
        xref    view_copy
        xref    z_blip
        xref    z_circ
        xref    z_clear
        xref    z_line
        xref    z_plot
        xref    z_star
        xref    z_title
        xref    z_title_end

; --- fixed variables (written by the boot code in the card bank) ------------------------

; --- game addresses used here -----------------------------------------------------------

; --- fixed entries at $2000 (modules assembled before the glue call these by address) ---

; --- jump table: the game's patches call these by name (jt_*, exported to glue.def) ------
jt_z_halt:
        jp      z_halt          ; HALT
jt_st_bit7hl:
        jp      st_bit7hl       ; HALT / BIT 7,(HL)
jt_st_ldafc0d:
        jp      st_ldafc0d      ; HALT / LD A,($FC0D)
jt_st_ldc4:
        jp      st_ldc4         ; HALT / LD C,4
jt_st_kemp:
        jp      st_kemp         ; HALT / IN A,(C) on the Kempston port
jt_st_74de:
        jp      st_74de         ; HALT / POP BC / DJNZ $74DA
jt_st_djnz:
        jp      st_djnz         ; HALT / DJNZ (to itself)
jt_st_c632:
        jp      st_c632         ; HALT / LD BC,($C78B)
jt_pa22aa:
        jp      pa22aa          ; ROM PIXEL-ADD
jt_pa22b0:
        jp      pa22b0          ; $201B
jt_pa22b1:
        jp      pa22b1          ; $201E
jt_zxin:jp      zxin            ; $2021  Spectrum keyboard port read
jt_beep:jp      beeper          ; $2024  ROM BEEPER (9BCC, E1F4): snd.asm
jt_z_start:
        jp      z_start         ; boot code jumps here
jt_z_errhan:
        jp      z_errhan        ; OZ error handler
jt_z_redraw:
        jp      z_redraw        ; windows + map (also used by boot)
jt_z_blit:
        jp      z_blit          ; replaces the view buffer copy at $7FBE
jt_rd_fc08:
        jp      rd_fc08         ; LD A,($FC08) .. LD A,($FC0F): poll, then read
jt_rd_fc09:
        jp      rd_fc09         ; $2036
jt_rd_fc0a:
        jp      rd_fc0a         ; $2039
jt_rd_fc0b:
        jp      rd_fc0b         ; $203C
jt_rd_fc0c:
        jp      rd_fc0c         ; $203F
jt_rd_fc0d:
        jp      rd_fc0d         ; $2042
jt_rd_fc0e:
        jp      rd_fc0e         ; $2045
jt_rd_fc0f:
        jp      rd_fc0f         ; $2048
jt_hk_vertex:
        jp      hk_vertex       ; rotate_vertex_simple: LD A,($A9C8)
jt_hk_char:
        jp      hk_char         ; print_char: LD HL,$5D70
jt_z_clear:
        jp      z_clear         ; clear 3D area (8080)
jt_z_line:
        jp      z_line          ; draw clipped line (B044)
jt_z_star:
        jp      z_star          ; stardust address (7D0F)
jt_z_plot:
        jp      z_plot          ; plot pixel (A83C)
jt_z_circ:
        jp      z_circ          ; circle (call at 86E9)
jt_hk_glyph:
        jp      hk_glyph        ; print_char's write loop (D543)
jt_z_blip:
        jp      z_blip          ; scanner blip (9788)
jt_z_title:
        jp      z_title         ; view title: LD HL,$010A at DA98
jt_z_title_end:
        jp      z_title_end     ; view title: CALL $DAB4 at DAAB
jt_tx_clsj:
        jp      tx_clsj         ; calls to "clear screen with border" (D61D)
jt_ti_7426:
        jp      ti_7426         ; title loop: CALL $7426 at 737B
jt_ti_7430:
        jp      ti_7430         ; title loop: CALL $7430 at 73C6
jt_cm_enter:
        jp      cm_enter        ; disk menu: CALL $D61D at D90A
jt_cm_load:
        jp      cm_load         ; load commander: CALL $0562 at D954
jt_cm_save:
        jp      cm_save         ; save commander: CALL $04C6 at D99C
jt_tx_band:
        jp      tx_band         ; lower text-line fill: LD B,8 / PUSH BC at E37D
jt_tx_erase:
        jp      tx_erase        ; typed-character erase: XOR A / LD B,8 at E2F0

; --- keyboard sampling hooks in busy game code (see latch_chk)
hk_vertex:
        in      a,($D0)                 ; 5 ms step since the last sample?
hv_cp:  cp      0                       ; (operand = last TIM0, kept by latch_chk)
        call    nz,latch_chk
        ld      a,($A9C8)
        ret
hk_char:
        call    latch_chk
        ld      hl,$5D70
        ret

; --- reads of the interrupt-maintained input bytes: run the frame work first if a frame
; has passed (the Spectrum interrupt would have), so polling loops see new keys.
rd_fc08: call   z_poll
        ld      a,($FC08)
        ret
rd_fc09: call   z_poll
        ld      a,($FC09)
        ret
rd_fc0a: call   z_poll
        ld      a,($FC0A)
        ret
rd_fc0b: call   z_poll
        ld      a,($FC0B)
        ret
rd_fc0c: call   z_poll
        ld      a,($FC0C)
        ret
rd_fc0d: call   z_poll
        ld      a,($FC0D)
        ret
rd_fc0e: call   z_poll
        ld      a,($FC0E)
        ret
rd_fc0f: call   z_poll
        ld      a,($FC0F)
        ret

; --- HALT stubs ---------------------------------------------------------------------------
st_bit7hl:
        call    z_halt
        bit     7,(hl)
        ret
st_ldafc0d:
        call    z_halt
        ld      a,($FC0D)
        ret
st_ldc4:
        call    z_halt
        ld      c,4
        ret
st_kemp:
        call    z_halt
        xor     a               ; no Kempston joystick: nothing pressed
        ret
st_74de:                        ; reached by JP: HALT / POP BC / DJNZ $74DA / (on) $74E2
        call    z_halt
        pop     bc
        dec     b
        jp      nz,$74DA
        jp      $74E2
st_djnz:
        call    z_halt
        djnz    st_djnz
        ret
st_c632:
        call    z_halt
        ld      bc,($C78B)
        ret

; --- Spectrum ROM PIXEL-ADD (same entry points and results) ----------------------------
; In: B = y (0-175, BASIC coordinates at $22AA), C = x.  Out: HL = screen address,
; A = x AND 7.  $22B0: A = y already flipped (B := A).  $22B1: A = B = flipped y.
pa22aa: call    latch_chk
        ld      a,$AF
        sub     b
        ret     c               ; (ROM reports an error; never happens in Elite)
pa22b0: ld      b,a
pa22b1: call    latch_chk
        and     a
        rra
        scf
        rra
        and     a
        rra
        xor     b
        and     $F8
        xor     b
        ld      h,a
        ld      a,c
        rlca
        rlca
        rlca
        xor     b
        and     $C7
        xor     b
        rlca
        rlca
        ld      l,a
        ld      a,c
        and     $07
        ret


; latch_chk: every 5 ms (Blink TIM0 step) while the game draws, OR the keyboard matrix
; into V_LATCH, so a key tapped between frames is still seen by the next scan.
; Called from the pixel-address routines (many times a frame).  Keeps all registers.
latch_chk:
        push    af
        push    bc
        in      a,($D0)
        ld      b,a
        ld      a,(V_LTIM)
        cp      b
        jr      z,lc_x
        ld      a,b
        ld      (V_LTIM),a
        ld      (hv_cp+1),a
        push    hl
        ld      hl,V_LATCH
        ld      a,$FE
lc_l:   ld      b,a
        in      a,($B2)
        cpl
        or      (hl)
        ld      (hl),a
        inc     hl
        ld      a,b
        rlca
        jr      c,lc_l
        pop     hl
lc_x:   pop     bc
        pop     af
        ret

; --- Spectrum keyboard: IN A,(C) with B = half-row selector, then AND $1F ---------------
; The eight half-rows are built once per frame (zx_build, from z_halt); a read just ANDs
; the selected ones.
zxin:   push    hl              ; one half-row (the usual case): table lookup
        ld      h,ZSEL/256
        ld      l,b
        ld      a,(hl)
        cp      8
        jr      nc,zxin_m
        add     a,V_ZXROWS%256
        ld      l,a
        ld      h,V_ZXROWS/256
        ld      a,(hl)
        pop     hl
        ret
zxin_m: pop     hl
        push    bc
        push    hl
        ld      hl,V_ZXROWS
        ld      c,8
        ld      a,$1F
zi_lp:  rrc     b
        jr      c,zi_n
        and     (hl)
zi_n:   inc     hl
        dec     c
        jr      nz,zi_lp
        pop     hl
        pop     bc
        ret

; zx_build: scan the Z88 matrix and make the eight active-low Spectrum half-row bytes
zx_build:
        ld      hl,V_KEYS       ; Z88 matrix, column by column, 1 = pressed
        ld      a,$FE
zb_sc:  push    af
        in      a,($B2)
        cpl
        push    hl
        ld      de,V_LATCH-V_KEYS
        add     hl,de           ; HL -> latch for this column
        or      (hl)            ; keys seen down since the last scan
        ld      e,(hl)
        ld      (hl),0
        ld      d,a
        ld      a,l
        add     a,8             ; -> previous scan's latch (V_LATCH2 = V_LATCH+8)
        ld      l,a
        ld      a,d
        or      (hl)            ; a tap stays down for two scans
        ld      (hl),e
        pop     hl
        ld      (hl),a
        inc     hl
        pop     af
        rlca
        jr      c,zb_sc
        ld      a,(V_KEYS+2)        ; = (bit 7 of row A10 on a Z88 and in OZvm; Z88e.c
        and     $80                 ; has = and - swapped; neither is a Spectrum key):
        ld      hl,V_DKK            ; a new press turns strict docking on or off
        cp      (hl)
        ld      (hl),a
        jr      z,zb_nd
        and     a
        jr      z,zb_nd
        ld      hl,V_STRICT     ; normal, strict, BBC, normal ...
        ld      a,(hl)
        inc     a
        cp      3
        jr      c,zb_sd
        xor     a
zb_sd:  ld      (hl),a
zb_nd:  ld      a,(V_KEYS+3)        ; - (bit 7 of row A11): a new press moves the frame
        and     $80                 ; cap on
        ld      hl,V_CAPK
        cp      (hl)
        ld      (hl),a
        jr      z,zb_nc
        and     a
        jr      z,zb_nc
        ld      a,(V_CAP)           ; next setting: 20, 25/s, off, 12.5, 16.7/s, 20 ...
        inc     a
        cp      5
        jr      c,zb_c2
        xor     a
zb_c2:  ld      (V_CAP),a
zb_nc:  ld      hl,V_KEYS           ; nothing down at all (the usual case): quick
        ld      b,8
        xor     a
zb_any: or      (hl)
        inc     hl
        djnz    zb_any
        and     a
        jr      nz,zb_full
        ld      hl,V_ZXROWS
        ld      b,8
zb_nk:  ld      (hl),$1F
        inc     hl
        djnz    zb_nk
        ret
zb_full:
        ld      ix,zx_map
        ld      de,V_ZXROWS
        ld      b,8
zb_row: ld      c,$1F           ; C = this half-row, active low
        push    bc
        ld      b,1             ; Spectrum bit
zb_key: ld      a,(ix+0)
        add     a,V_KEYS%256
        ld      l,a
        ld      h,V_KEYS/256
        ld      a,(hl)
        and     (ix+1)
        jr      z,zb_no
        ld      a,b
        cpl
        and     c
        ld      c,a
zb_no:  inc     ix
        inc     ix
        sla     b
        bit     5,b
        jr      z,zb_key
        ld      a,c
        pop     bc
        ld      (de),a
        inc     de
        djnz    zb_row
        ld      ix,zx_extra     ; cursor keys onto N M X S
zb_ex:  ld      a,(ix+0)
        cp      $FF
        jr      z,zb_tap
        ld      a,(ix+2)
        add     a,V_KEYS%256
        ld      l,a
        ld      h,V_KEYS/256
        ld      a,(hl)
        and     (ix+3)
        jr      z,zb_en
        ld      a,(ix+0)
        add     a,V_ZXROWS%256
        ld      l,a
        ld      h,V_ZXROWS/256
        ld      a,(ix+1)
        cpl
        and     (hl)
        ld      (hl),a
zb_en:  ld      de,4
        add     ix,de
        jr      zb_ex
zb_tap: ld      hl,V_TAPN       ; a key typed between scans: hold it for a few scans
        ld      a,(hl)
        and     a
        ret     z
        dec     (hl)
        ld      a,(V_TAP)
        ld      c,a
        rlca
        rlca
        rlca
        and     7
        add     a,V_ZXROWS%256
        ld      l,a
        ld      h,V_ZXROWS/256
        ld      a,c
        and     $1F
        cpl
        and     (hl)
        ld      (hl),a
        ret

; tap_key: A = character from OZ -> V_TAP/V_TAPN (letters, digits, space, ENTER)
tap_key:
        cp      13
        ld      c,$C1           ; ENTER: half-row 6, bit 0
        jr      z,tk_set
        cp      ' '
        ld      c,$E1           ; SPACE: half-row 7, bit 0
        jr      z,tk_set
        cp      '0'
        ret     c
        cp      '9'+1
        jr      nc,tk_alpha
        sub     '0'
        ld      hl,tap_dig
        jr      tk_look
tk_alpha:
        and     $DF             ; upper case
        cp      'A'
        ret     c
        cp      'Z'+1
        ret     nc
        sub     'A'
        ld      hl,tap_abc
tk_look:
        add     a,l
        ld      l,a
        jr      nc,tk_h
        inc     h
tk_h:   ld      c,(hl)
tk_set: ld      a,c
        ld      (V_TAP),a
        ld      a,3
        ld      (V_TAPN),a
        ret
tap_abc: defb   $21,$F0,$08,$24,$44,$28,$30,$D0,$A4,$C8,$C4,$C2,$E4,$E8,$A2,$A1,$41,$48,$22,$50,$A8,$10,$42,$04,$B0,$02
tap_dig: defb   $81,$61,$62,$64,$68,$70,$90,$88,$84,$82

; Spectrum half-rows in scan order ($FEFE, $FDFE ... $7FFE), 5 keys each from bit 0:
; (Z88 column, Z88 row bit).  Z88 column n is read with bit n of the select byte low.
zx_map: defb    6,$40, 5,$04, 4,$04, 3,$04, 2,$04      ; CAPS(LSHIFT) Z X C V
        defb    5,$08, 4,$08, 3,$08, 2,$08, 1,$08      ; A S D F G
        defb    5,$10, 4,$10, 3,$10, 2,$10, 1,$10      ; Q W E R T
        defb    5,$20, 4,$20, 3,$20, 2,$20, 1,$20      ; 1 2 3 4 5
        defb    5,$01, 3,$01, 0,$01, 0,$02, 0,$20      ; 0 9 8 7 6
        defb    4,$01, 2,$01, 1,$01, 1,$02, 0,$10      ; P O I U Y
        defb    0,$40, 5,$02, 3,$02, 2,$02, 0,$08      ; ENTER L K J H
        defb    5,$40, 7,$80, 4,$02, 0,$04, 1,$04      ; SPACE SYM(RSHIFT) M N B
; Z88 cursor keys: LEFT = N (roll), RIGHT = M, UP = X (dive), DOWN = S (climb)
zx_extra:
        defb    7,$08, 4,$40                            ; N   <- LEFT
        defb    7,$04, 3,$40                            ; M   <- RIGHT
        defb    0,$04, 1,$40                            ; X   <- UP
        defb    1,$02, 2,$40                            ; S   <- DOWN
        defb    0,$01, 0,$80                            ; CAPS SHIFT + 0 (the Spectrum's
        defb    4,$01, 0,$80                            ; DELETE) <- DEL (row A8, bit 7)
        defb    $FF

; --- frame wait (replaces HALT) -------------------------------------------------------------
; Waits until at least one 20 ms frame has passed since the last call, runs the
; Spectrum interrupt work once per frame passed (at most 4), shows the screen and lets
; OZ in.  Keeps every register.
; z_blit: the game's own buffer copy, then the frame work without waiting (the title
; loop and flight loop do not HALT; on the Spectrum the interrupt simply arrived).
z_blit: push    af
        push    bc
        push    de
        push    hl
        ld      a,(TX_VIEW)     ; a flight-view frame after a text screen: flight
        cp      4               ; layout back (text views also spin a ship: not those)
        jr      nc,zb_tb
        xor     a               ; (and the disk menu is over)
        ld      (CM_ON),a
        ld      a,(TX_MODE)         ; (or a chart's text in window 1)
        ld      hl,CH_MODE
        or      (hl)
        ld      (TX_BACK),a
zb_tb:
        call    view_copy       ; the Z88 view buffer and scanner panel -> the map
        call    scan_restore    ; fresh scanner background for this frame's blips

        xor     a               ; the Spectrum copy left the buffer's top-left byte ($00)
        ld      ($4000),a       ; at $4000; the panel routine (8042) redraws while it is $FF
        ld      hl,(V_BLITS)
        inc     hl
        ld      (V_BLITS),hl
        xor     a
        ld      (V_VAGE),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        push    af
        xor     a
        jr      zh_go

z_poll: push    af              ; nothing can be due if TIM0 has not moved: return at once
        in      a,($D0)
zp_cp:  cp      0               ; (operand = TIM0 at the last full poll)
        jr      z,zp_x
        ld      (zp_cp+1),a
        ld      a,2
        jr      zh_go
zp_x:   pop     af
        ret

z_halt: push    af
        ld      a,1
zh_go:  push    hl
        ld      hl,V_BUSY
        bit     0,(hl)
        pop     hl
        jr      z,zh_go2
        pop     af              ; already inside the frame work (keyboard scan reads)
        ret
zh_go2: ld      (V_WAIT),a
        ld      a,1
        ld      (V_BUSY),a
        pop     af
        push    af
        push    bc
        push    de
        push    hl
        push    ix
        push    iy
        ex      af,af'
        push    af
        ex      af,af'
        exx
        push    bc
        push    de
        push    hl
        exx
        ei
zh_w:   call    tick
        and     a
        jr      nz,zh_got
        ld      a,(V_WAIT)
        dec     a
        jr      z,zh_w          ; z_halt: wait for the frame
        di
        jp      p,zh_out        ; z_poll: nothing to do yet
        jr      zh_draw         ; z_blit: just show the screen
zh_got: di
        cp      5
        jr      c,zh_n
        ld      a,4
zh_n:   ld      b,a
        push    bc
        call    zx_build
        pop     bc
zh_int: push    bc
        call    G_KEYSCAN
        call    G_RATES
        push    de              ; the game's sound player, 50 times a second (the
        push    hl              ; Spectrum's frame interrupt, FF3B: CALL 7125 = JP 9579)
        call    $7125
        pop     hl
        pop     de
        pop     bc
        djnz    zh_int
        ld      a,(V_WAIT)
        and     a
        jr      z,zh_oz         ; z_blit: the view is already copied
        ld      a,(TX_MODE)     ; text screen up: the map is hidden
        and     a
        jr      nz,zh_oz
        ld      a,(V_VAGE)      ; a view drawn in the last 0.5 s: leave the map alone
        cp      25
        jr      c,zh_oz
        ld      a,(V_RAGE)      ; text screens: redraw when 4 frames (80 ms) old
        cp      4
        jr      c,zh_oz
zh_draw:
        xor     a
        ld      (V_RAGE),a
        call    render
zh_oz:
        ei
        ld      a,(V_PUR)       ; back to a menu (title / docked screen): forget the
        and     a               ; keys OZ queued during play
        jr      z,zh_np
        xor     a
        ld      (V_PUR),a
        oz      OS_Pur
zh_np:  call    tx_frame        ; text screens / layout switch, pending output
        ld      a,(TI_MODE)     ; every 2nd drawn frame: the instruments (not over text
        ld      b,a             ; or the title)
        ld      a,(TX_MODE)
        or      b
        ld      b,a
        ld      a,(CH_MODE)
        or      b
        ld      b,a
        ld      a,(V_WAIT)
        or      b
        jr      nz,zh_ni
        call    msg_update      ; flight text: view name, messages
        ld      hl,V_INC
        inc     (hl)
        bit     0,(hl)
        call    z,instr_update
; OZ is only asked for keys when it matters: always on the (docked) text screens, and
; otherwise only while a system key is held - INDEX, SQUARE, DIAMOND, HELP or MENU -
; so it can switch application or show its menus.  The game itself reads the keyboard
; matrix directly (zx_build), which costs nothing like an OZ call per frame.
zh_ni:  ld      a,(V_KEYS+7)    ; column A15: SQUARE bit 6, INDEX bit 4
        and     $50
        ld      b,a
        ld      a,(V_KEYS+6)    ; column A14: HELP bit 7, DIAMOND bit 4, MENU bit 3
        and     $98
        or      b
        jr      z,zh_ns
        call    jt_spk_off      ; (OZ may switch application: leave the speaker off)
        jr      zh_ozk
zh_ns:  ld      a,(TX_MODE)
        and     a
        jr      z,zh_ok
zh_ozk: ld      b,16            ; read OZ's key buffer dry (game keys queued there too)
zh_ozl: push    bc
        ld      bc,0            ; no wait: a held key is seen again next pass
        oz      Os_Tin
        pop     bc
        jr      c,zh_err
        djnz    zh_ozl
        jr      zh_ok
zh_err:
        cp      RC_Draw         ; back from another application: draw ours again
        call    z,z_redraw
zh_ok:  di
zh_out: exx
        pop     hl
        pop     de
        pop     bc
        exx
        ex      af,af'
        pop     af
        ex      af,af'
        pop     iy
        pop     ix
        pop     hl
        pop     de
        pop     bc
        xor     a
        ld      (V_BUSY),a
        pop     af
        ret

; tick: A = whole 20 ms frames since the last call (TIM0 counts 5 ms steps 0-199)
tick:   in      a,($D0)
        ld      hl,V_TLAST
        ld      b,(hl)
        ld      (hl),a
        sub     b
        jr      nc,tk_p
        add     a,200
tk_p:   ld      hl,V_TACC
        add     a,(hl)
        ld      b,0
tk_d:   cp      4
        jr      c,tk_e
        sub     4
        inc     b
        jr      tk_d
tk_e:   ld      (hl),a
        ld      a,(V_RAGE)
        add     a,b
        jr      nc,tk_r
        ld      a,$FF
tk_r:   ld      (V_RAGE),a
        ld      a,(V_VAGE)
        add     a,b
        jr      nc,tk_v
        ld      a,$FF
tk_v:   ld      (V_VAGE),a
        ld      a,b
        ret

; --- show the Spectrum screen's top two thirds (256 x 128) in the 256 x 64 map ---------
; Each map row ORs two Spectrum pixel rows.  The map is bound into segment 2 for the copy
; (the Spectrum screen at $4000 is in segment 1); interrupts are off.
render: ld      a,(TI_ON)       ; a chart: its own window onto the screen
        ld      hl,CM_ON
        or      (hl)
        jr      nz,rn_std
        ld      a,(TX_VIEW)
        cp      7
        jr      z,rn_ch
        cp      8
        jr      nz,rn_std
rn_ch:  ld      hl,CH_SAFE      ; a chart (chart.asm): rendered again only after the
        inc     (hl)            ; game drew something (CH_CNT), and every 2 s anyway
        ld      a,(hl)
        cp      25
        jr      nc,rn_go
        ld      a,(CH_CNT)
        and     a
        ret     z
        dec     a
        ld      (CH_CNT),a
rn_go:  ld      (hl),0
        ld      a,2             ; the map's scanner panel is overwritten: the next view
        ld      (SC_ALL),a      ; copy puts all of it back
        ld      hl,(V_MAPA)     ; the chart drawn in VBUF, then copied whole, so the
        push    hl              ; numbers are never seen erased between the renders
        ld      a,(V_MAPB)      ; while the game draws the chart
        push    af
        ld      a,(V_BANKS+2)
        ld      (V_MAPB),a
        ld      hl,$8000
        ld      (V_MAPA),hl
        call    ch_render
        pop     af
        ld      (V_MAPB),a
        pop     hl
        ld      (V_MAPA),hl
        ld      b,a
        ld      c,2
        oz      Os_Mpb
        push    bc
        ex      de,hl
        ld      hl,VBUF
        ld      bc,256*VH/8
        ldir
        pop     bc
        ld      c,2
        oz      Os_Mpb
        ret
rn_std: ret                     ; anything else: the Spectrum screen is blank (titles and
                                ; text go to OZ windows; the view, scanner and flashes are
                                ; drawn natively), so it is never copied to the map: doing
                                ; so only blanked the map (the title, around a kill)

; --- windows and map ---------------------------------------------------------------------
z_redraw:
        push    af
        push    bc
        push    de
        push    hl
        call    zr_mclr         ; the old map cleared while still hidden (a text screen
        ld      hl,win          ; over it), not shown again before it is cleared
        call    puts
        ld      a,'2'           ; the map: 256 x 64, opened and bound into segment 2 by
        ld      b,MS_S2         ; Gunther Strube's opengraphics (below; works on all OZ)
        ld      hl,256
        call    opengraphics    ; HL = map base in segment 2, B = segment 2's old bank
        push    bc
        ld      c,MS_S2
        oz      Os_Mgb          ; B = the map's bank (now in segment 2)
        ld      a,b
        pop     bc
        push    af
        ld      c,MS_S2
        oz      Os_Mpb          ; segment 2 back as it was
        pop     af
        ld      (R_MAPB),a      ; the map itself
        ld      (V_MAPB),a      ; where the map writers write (the chart: VBUF for a time)
        ld      (R_MAPA),hl
        ld      (V_MAPA),hl
zr_clr: call    zr_mclr         ; clear the map (on a first start its memory holds
                                ; whatever was there before)
        ld      a,2             ; (the whole scanner panel again)
        ld      (SC_ALL),a
        ld      a,(TI_MODE)     ; the instruments, unless window 1 holds other text
        ld      hl,TX_MODE      ; (the title - also at boot - a text screen, a chart)
        or      (hl)
        ld      hl,CH_MODE
        or      (hl)
        call    z,instr_init
zr_x:   pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; zr_mclr: clear the map, once known (R_MAPA)
zr_mclr:
        ld      a,(R_MAPA+1)
        and     a
        ret     z
        ld      a,(R_MAPB)
        ld      b,a
        ld      c,2
        oz      Os_Mpb
        push    bc
        ld      hl,(R_MAPA)
        ld      d,h
        ld      e,l
        inc     de
        ld      bc,256*64/8-1
        ld      (hl),0
        ldir
        pop     bc
        ld      c,2
        oz      Os_Mpb
        ret




; ---------------------------------------------------------------------------------------
;
;    Open graphics window, static size of <Width> x 64 pixels, and bind graphics
;    This generic routine is a drop-in replacement of OS_Map, MP_MEM (OZ 4.2 and later)
;    Works for all OZ ROMs (V2.2 -> modern era)
;
;    The Width specifier defines the map width in modulus 8 pixels,
;    ie. 8, 16, 24, 32, 40, 48, 56, 64 ...
;
;    IN:  
;         A = window ID ('1' to '6')
;         B = MS_Sx mask (for segment 0, 1, 2 or 3)
;         HL = width of map (modulus 8)
;
;    OUT: 
;         HL contains pointer to base of graphics area in segment Sx
;         B = prev bank binding of segment Sx
;         The graphics area is bound into the segment specified
;         by the input B register.
;
;    Registers changed after return:
;         af.cde../ixiy  same
;         ..b...hl/....  different
;
; Design & programming by Gunther Strube hello@bits4fun.net, Copyright (C) 1995-98, 2026
;
.opengraphics
        push af
        push de
        push bc

        push bc
        ld   bc, MP_Gra
        push af
        ld   a,l
        and  @11111000           ; width always in 8 bit size...
        ld   l,a                 ; HL now the map width...
        dec  hl                  ; always one less than actual width...
        pop  af
        oz   OS_Map              ; create map width of 256 pixels
        ld   b,0
        ld   hl,0                ; dummy address
        ld   a,SC_HR0
        oz   OS_Sci              ; get base address of map area (hires0)
        push bc
        push hl
        oz   OS_Sci              ; (and re-write original address)
        pop  hl
        pop  bc
        pop  de
        ld   c,d                 ; MS_Sx segment specifier
        oz   OS_Mpb              ; bind hires0 memory into specified segment, B = old bank binding
        ld   a,h
        and  @00111111
        rrc  d
        rrc  d                   ; convert MS_Sx to MM_Sx
        or   d
        ld   h,a                 ; HL = base address of HIRES0 in segment Sx

        ld   a,b
        pop  bc
        ld   b,a                 ; return old bank binding in Segment Sx
        pop  de
        pop  af
        ret





jt_spk_off:                     ; the speaker off: COM as OZ has it
        push    af
        ld      a,(BLSC_COM)
        out     ($B0),a
        pop     af
        ret

puts:   ld      a,(hl)
        and     a
        ret     z
        push    hl
        oz      Os_Out
        pop     hl
        inc     hl
        jr      puts


; --- start and exit ----------------------------------------------------------------------
z_start:                        ; segments 1 and 2 already hold game banks 1 and 2
        di
        ; keep the stack OZ gave us (segment 0, where OZ expects it)
        ld      a,(V_BANKS+2)
        ld      b,a
        ld      c,3
        oz      Os_Mpb           ; game bank 3 into segment 3 (the card bank leaves)
        in      a,($D0)
        ld      (V_TLAST),a
        xor     a
        ld      (V_TACC),a
        ld      (MW_RX),a
        call    init_tables
        call    in_reset
        ld      a,$FF
        ld      (TT_VIEW),a
        xor     a
        ld      (TT_REC),a
        ld      (SC_RM),a
        ld      (SC_RMOLD),a
        ld      hl,VBUF         ; the view buffer: from the card it holds the Lenslok
        ld      de,VBUF+1       ; code (the scanner panel shows it until restored)
        ld      bc,VH/8*256-1          ; (8 cell rows of 256 bytes)
        ld      (hl),a
        ldir
        ld      hl,$4001        ; the Spectrum screen too: the card image holds the
        ld      de,$4002        ; loading screen, and the map shows it until the
        ld      bc,$1800-2      ; first frames are drawn ($4000 itself is a flag
        ld      (hl),a          ; the game tests at start-up: left alone)
        ldir
        ld      a,2
        ld      (SC_ALL),a
        xor     a
        ld      (TX_MODE),a
        ld      (TX_CLR),a
        ld      (TX_BACK),a
        ld      (TI_ON),a
        ld      (TI_MODE),a
        ld      (TI_KIND),a
        ld      (V_PUR),a
        ld      (CM_ON),a
        ld      (CH_MODE),a
        call    jt_spk_off
        ld      a,'1'
        ld      (OUT_WIN),a
        call    out_start
        call    tx_shclr
        jp      G_START

z_errhan:
        ret     z
        cp      RC_Quit
        jr      z,z_quit
        xor     a
        ret
z_quit: ld      a,'2'           ; the map given back (MP_DEL), then leave
        ld      bc,MP_DEL
        oz      Os_Map
        xor     a
        oz      Os_Bye
; the flight layout (read at boot: kept here, not in ovl.asm): window 1 (instruments, text), window 2 (the map)
win:    defb    1,'7','#','1',32,32,32+51,32+8,128,1,'2','C','1'
        defb    1,'7','#','2',32+51,32,32+43,32+8,128,1,'2','C','2'
        defb    1,'2','H','1',0

glue_end:

