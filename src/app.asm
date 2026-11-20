; app.asm - Elite for the Cambridge Z88: application bank (boot code, glue copy, DOR).
; Card layout (128K): banks $38-$3B empty ($FF), banks $3C/$3D/$3E = the patched Spectrum game ($4000/$8000/$C000),
; bank $3F = this bank.  Needs an expanded Z88 (three free 16K RAM banks).
        module eliteapp
        include "stdio.def"
        include "fileio.def"
        include "time.def"
        include "dor.def"
        include "macros.def"
        include "error.def"
        include "director.def"
        include "memory.def"
        include "map.def"
        include "elite.inc"             ; variables shared with the glue (V_BANKS ...)
        include "glue.def"              ; glue entry points (mpm -g)

        org $C000

defc V_CARD   = $3F20           ; card bank of this application bank
defc V_SRC    = $3F21           ; the three game banks found (3 bytes)
defc V_LOG    = $3F28           ; boot log (debug)
defc REQPAGES = 32              ; $2000-$3FFF
defc SAFEDATA = 0

app_entrypoint:
        ld      a,SC_DIS
        oz      Os_Esc
        ld      hl,$3E00        ; the front end's variables start cleared: OZ does not
        ld      de,$3E01        ; clear application RAM, so after a KILL a new start
        ld      bc,$01FF        ; would find the old instance's state (in flight)
        ld      (hl),0
        ldir
        ld      a,8             ; stardust: 8 specks to start with (] gives the
        ld      ($3F24),a       ; Spectrum's 16; V_DUSTN)
        ld      a,2             ; docking: the BBC's rules to start with (=: normal,
        ld      (V_STRICT),a    ; strict, BBC)
        ld      hl,glue_bin     ; glue code into application RAM
        ld      de,$2000
        ld      bc,glue_end-glue_bin
        ldir
        xor     a
        ld      b,a
        ld      hl,JT_Z_ERRHAN
        oz      Os_Erh
        ld      hl,applname
        oz      Dc_Nam

        ld      ix,-1           ; an expanded Z88? (Gunther Strube's check, as in Cosmic
        ld      a,FA_EOF        ; Payback: OS_Frm FA_EOF on handle -1 gives Fz = 1 on an
        oz      OS_Frm          ; expanded machine)
        jr      z,expanded
        ld      hl,msg_unexp
        call    PUTS            ; (glue, already in RAM)
        ld      bc,500
        oz      OS_Dly          ; 5 s to read it
        xor     a
        oz      OS_Bye
expanded:

        ld      c,MS_S3         ; which card bank are we?
        oz      Os_Mgb
        ld      a,b
        ld      (V_CARD),a

; --- three whole RAM banks: one memory pool each, 64 x 256 bytes ---------------------------
; A pool without MM_EXC/MM_MUL takes its memory from one bank, the most free one, at most
; 16K (MM_EXC, exclusive free banks, is OZ 5 only).  64 pages must all come from that
; one bank, so the pool owns it whole; in which order the pages come does not matter.
        ld      de,V_BANKS
        ld      a,3
bk_lp:  push    af
        push    de
        ld      a,MM_S1
        ld      bc,0
        oz      Os_Mop                  ; IX = the pool
        pop     de
        jp      c,no_mem2
        ld      c,64
bk_pg:  push    bc
        push    de
        ld      bc,256
        oz      Os_Mal                  ; BHL = a page (HL in segment 1)
        ld      a,b
        pop     de
        pop     bc
        jp      c,no_mem2
        ex      af,af'
        ld      a,c
        cp      64
        jr      nz,bk_same
        ex      af,af'                  ; the first: this pool's bank
        ld      (de),a
        jr      bk_nx
bk_same:
        ex      af,af'
        ex      de,hl                   ; (HL = V_BANKS entry; DE = the page)
        cp      (hl)
        ex      de,hl
        jp      nz,no_mem2              ; another bank: not one whole free bank
bk_nx:  dec     c
        jr      nz,bk_pg
        inc     de
        pop     af
        dec     a
        jr      nz,bk_lp

; --- find the game's three banks -----------------------------------------------------------
; On a card they are the three below this one.  Installed as a RAM application they can be
; anywhere: each carries a signature (build.sh) in code the game never runs, so any bank
; that has it will do.  The working copies lose theirs (below), so an old copy left in RAM
; from an earlier session is never taken for the game.
        ld      ix,V_SRC
        ld      iy,sig_tab
        ld      d,0             ; D = game bank 0-2
fb_lp:  ld      a,(V_CARD)      ; the card's own: this bank - 3 + D
        sub     3
        add     a,d
        call    fb_test
        jr      z,fb_got
        ld      a,$FF           ; else every bank, from the top
fb_scan:
        push    af
        call    fb_test
        jr      z,fb_got2
        pop     af
        dec     a
        cp      $1F
        jr      nz,fb_scan
        jp      no_game
fb_got2:
        pop     af
fb_got: ld      (ix+0),a
        inc     ix
        ld      bc,6
        add     iy,bc
        inc     d
        ld      a,d
        cp      3
        jr      nz,fb_lp

; --- copy the game into the RAM banks ------------------------------------------------------
        ld      hl,V_BANKS
        ld      ix,V_SRC
        ld      d,3
cp_lp:  push    de
        push    hl
        ld      b,(ix+0)
        inc     ix
        ld      c,1
        oz      Os_Mpb          ; game bank -> segment 1
        ld      b,(hl)
        ld      c,2
        oz      Os_Mpb          ; RAM bank -> segment 2
        ld      hl,$4000
        ld      de,$8000
        ld      bc,$4000
        ldir
        pop     hl
        pop     de
        inc     hl
        dec     d
        jr      nz,cp_lp

        ld      hl,V_BANKS      ; the working copies' signatures wiped
        ld      iy,sig_tab
        ld      d,3
ws_lp:  ld      b,(hl)
        ld      c,1
        push    hl
        oz      Os_Mpb
        ld      l,(iy+0)
        ld      h,(iy+1)
        ld      (hl),0
        pop     hl
        inc     hl
        ld      bc,6
        add     iy,bc
        dec     d
        jr      nz,ws_lp

        ld      a,1
        ld      (TI_MODE),a        ; (no instruments yet: the title comes first)
        call    JT_Z_REDRAW        ; windows and map
        call    intro              ; the loading picture scrolls up the map
        ld      a,(V_BANKS)
        ld      b,a
        ld      c,1
        oz      Os_Mpb
        ld      a,(V_BANKS+1)
        ld      b,a
        ld      c,2
        oz      Os_Mpb
        jp      JT_Z_START         ; glue binds segment 3 and starts the game

; intro: the Spectrum's loading picture, which the tape image leaves in the Spectrum's
; screen memory (game bank 1, $4000-$5AFF; the game clears it when it starts), scrolled
; up through the map from below and off the top, two lines a step, a step every 45 ms
; (by TIM0: drawing one takes about 34 ms on a Z88, so the pace is the same on a faster
; emulator): 128 steps, about six seconds.  Light colours (green, cyan, yellow, white) are
; the picture, dark pixels on the Z88; the Torus and Firebird logos are left out.
defc FR_S = $3F08                       ; V_TMP: the top line shown (signed)
defc FR_T = $3F28                       ; V_LOG: TIM0 at the last step
intro:  ld      a,(V_BANKS)
        ld      b,a
        ld      c,1
        oz      Os_Mpb                  ; game bank 1 (the picture) -> segment 1
        ld      de,$5800                ; each attribute cell: pixel = ink or paper,
in_cv:  ld      a,(de)                  ; light or dark: out = (b AND m1) XOR m2,
        ld      b,a                     ; m1 = ink light XOR paper light, m2 = paper light
        and     7
        cp      4
        sbc     a,a
        cpl
        ld      c,a                     ; ink light: $FF
        ld      a,b
        rrca
        rrca
        rrca
        and     7
        cp      4
        sbc     a,a
        cpl                             ; paper light: $FF
        ld      b,a
        xor     c
        ld      c,b                     ; C = m2
        ld      b,a                     ; B = m1
        ld      a,d                     ; the cell's top line
        and     3
        add     a,a
        add     a,a
        add     a,a
        or      $40
        ld      h,a
        ld      l,e
        rept    8
        ld      a,(hl)
        and     b
        xor     c
        ld      (hl),a
        inc     h
        endr
        inc     de
        ld      a,d
        cp      $5B
        jr      nz,in_cv
        ld      c,0                     ; the Torus logo (x 187-255, lines 5-85) and the
in_bt:  ld      a,c                     ; Firebird logo (x 193-255, lines 168-191) out
        cp      91
        jr      c,in_b1
        cp      168
        jr      c,in_bn
        call    in_la
        ld      a,l
        or      24
        ld      l,a
        jr      in_b2
in_b1:  call    in_la
        ld      a,l
        or      23
        ld      l,a
        ld      a,(hl)
        and     $E0
        ld      (hl),a
        inc     l
in_b2:  ld      b,8
        xor     a
in_b3:  ld      (hl),a
        inc     l
        ld      a,l
        and     31
        jr      z,in_bn
        xor     a
        djnz    in_b3
in_bn:  inc     c
        ld      a,c
        cp      192
        jr      nz,in_bt
        ld      a,(R_MAPB)
        ld      b,a
        ld      c,2
        oz      Os_Mpb                  ; the map -> segment 2
        ld      hl,-64              ; (-64 + 2n reaches 192)
        ld      (FR_S),hl
        in      a,($D0)
        ld      (FR_T),a
in_st:  ld      hl,FR_T                 ; a step every 45 ms (drawing one takes 34)
in_wt:  in      a,($D0)
        sub     (hl)
        jr      nc,in_w2
        add     a,200
in_w2:  cp      9
        jr      c,in_wt
        in      a,($D0)
        ld      (hl),a
        ld      c,0                     ; map line i = 0..63: picture line FR_S + i
in_ln:  ld      hl,(R_MAPA)
        ld      a,c
        rrca
        rrca
        rrca
        and     7
        add     a,h
        ld      h,a
        ld      a,c
        and     7
        add     a,l
        ld      l,a
        ex      de,hl                   ; DE = the map: 8 bytes a cell, cells 8 apart
        ld      hl,(FR_S)
        ld      b,0
        add     hl,bc
        ld      b,32
        bit     7,h
        jr      nz,in_bl
        ld      a,h
        or      a
        jr      nz,in_bl
        ld      a,l
        cp      192
        jr      nc,in_bl
        call    in_la
in_cp:  ld      a,(hl)
        inc     l
        ld      (de),a
        ld      a,e
        add     a,8
        ld      e,a
        djnz    in_cp
        jr      in_nx
in_bl:  xor     a
        ld      (de),a
        ld      a,e
        add     a,8
        ld      e,a
        djnz    in_bl
in_nx:  inc     c
        ld      a,c
        cp      64
        jr      nz,in_ln
        ld      hl,(FR_S)
        inc     hl
        inc     hl
        ld      (FR_S),hl
        ld      de,192
        or      a
        sbc     hl,de
        jr      nz,in_st
        ret
; in_la: HL = the Spectrum screen address of line A (x = 0)
in_la:  ld      l,a
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
        add     a,a
        add     a,a
        ld      l,a
        ret

no_mem2:
        pop     af
no_mem: ld      hl,msg_mem
        call    PUTS            ; (glue, already in RAM)
wait:   oz      Os_In
        jr      wait

; fb_test: A = bank: Z if it holds game bank D's signature (IY -> its sig_tab entry).
; Binds the bank into segment 1.  Keeps A, D, IX, IY.
fb_test:
        push    af
        push    de
        ld      b,a
        ld      c,1
        oz      Os_Mpb
        ld      l,(iy+0)        ; HL = the signature's address in segment 1
        ld      h,(iy+1)
        push    iy
        pop     de
        inc     de
        inc     de              ; DE -> the 4 signature bytes
        ld      b,4
ft_lp:  ld      a,(de)
        cp      (hl)
        jr      nz,ft_x
        inc     de
        inc     hl
        djnz    ft_lp
ft_x:   pop     de
        pop     bc              ; (B = the bank; flags from the compare)
        ld      a,b
        ret

; the game banks' signatures (build.sh writes them): address in segment 1, 4 bytes
sig_tab:
        defw    $70C9           ; game bank 0 ($4000-$7FFF): dead code at $70C9
        defb    'E','Z',$88,1
        defw    $683F           ; game bank 1 ($8000-$BFFF): dead code at $A83F
        defb    'E','Z',$88,2
        defw    $4000           ; game bank 2 ($C000-$FFFF): VBUF at $C000
        defb    'E','Z',$88,3

no_game:
        ld      hl,msg_game
        call    PUTS
        jp      wait

msg_game:
        defb    1,'7','#','1',32,32,32+90,32+8,128,1,'2','C','1'
        defm    "Elite: the game's banks were not found (card or RAM install).",0
msg_mem:
        defb    1,'7','#','1',32,32,32+90,32+8,128,1,'2','C','1'
        defm    "Elite needs an expanded Z88: not enough free RAM (48K).",0
msg_unexp:
        defb    1,'7','#','1',32,32,32+90,32+8,128,1,'2','C','1'
        defm    "Sorry, Elite cannot run on a non-expanded Z88.",0

applname:
        defm    "Elite",0

glue_bin:
        binary  "glue.bin"
glue_end:

defc BANK_APPL = $3F

application_dor_entrypoint:
        jp      app_entrypoint
        scf
        ret

in_dor:
        dorappl ("Elite", 'E', AT_Bad|AT_Ones|AT_Draw, AT2_Cl,  \
                 application_dor_entrypoint,               \
                 0, 0, 0, BANK_APPL,                       \
                 REQPAGES, 0, 0, SAFEDATA,                 \
                 [in_topics, BANK_APPL],                   \
                 [in_commands, BANK_APPL],                 \
                 [in_help, BANK_APPL],                     \
                 ,                                         \
                 BANK_APPL)
; each topic owns the next group of in_commands (groups end with defb 1).  OZ does not
; wrap help text: lines are broken ($7F) at 63 characters, at most 7 lines a page.
in_topics:
        defb    0
        mthtpc  ["Info"], TPCF_INFO|TPCF_HELP, (hlp_info-in_help)
        mthtpc  ["Options"]
        mthtpc  ["Keys"], TPCF_HELP, (hlp_keys-in_help)
        mthtpc  ["Credits"], TPCF_HELP, (hlp_cred-in_help)
        defb    0

in_commands:
        defb    0
        mthcmd  (0, , ["The game"],      CMDF_HELP, (hlp_game-in_help))
        mthcmd  (0, , ["The screen"],    CMDF_HELP, (hlp_scr-in_help))
        mthcmd  (0, , ["Leaving"],       CMDF_HELP, (hlp_leave-in_help))
        defb    1
        mthcmd  ($C0, , ["Docking: BBC rules"])          ; the glue's zh_opt acts on these
        mthcmd  ($C1, , ["Docking: strict"])
        mthcmd  ($C2, , ["Docking: Spectrum"])
        mthcmd  ($C3, , ["Stars: 8"],               CMDF_COLUMN)
        mthcmd  ($C4, , ["Stars: 16 (Spectrum)"])
        mthcmd  ($C5, , ["Frame cap: off"],         CMDF_COLUMN)
        mthcmd  ($C6, , ["Frame cap: 6 a second"])
        mthcmd  ($C7, , ["Frame cap: 8 a second"])
        mthcmd  ($C8, , ["Frame cap: 12.5 a second"])
        defb    1
        mthcmd  (0, , ["Flying"],        CMDF_HELP, (hlp_fly-in_help))
        mthcmd  (0, , ["Weapons"],       CMDF_HELP, (hlp_weap-in_help))
        mthcmd  (0, , ["Jumps"],         CMDF_HELP, (hlp_jump-in_help))
        mthcmd  (0, , ["Screens"],       CMDF_HELP, (hlp_screens-in_help))
        mthcmd  (0, , ["Charts"],        CMDF_HELP, (hlp_chart-in_help))
        mthcmd  (0, , ["Freeze"],        CMDF_HELP, (hlp_freeze-in_help))
        mthcmd  (0, , ["Saving"],        CMDF_HELP, (hlp_save-in_help))
        defb    1
        mthcmd  (0, , ["Elite"],         CMDF_HELP, (hlp_elite-in_help))
        mthcmd  (0, , ["This version"],  CMDF_HELP, (hlp_port-in_help))
        defb    1
        defb    0

in_help:                                ; a page holds 6 lines (below OZ's title row); kept to
                                        ; 60 characters a line
        defm    "The ZX Spectrum Elite for the expanded Z88: the original Z80", $7F
        defm    "game code runs here, with its graphics and text redrawn for", $7F
        defm    "the Z88 screen.", $7F
        defm    $7F
        defm    "The MENU topics have the keys.", 0

hlp_info:
        defm    "The game, the screen, and leaving it.", 0
hlp_keys:
        defm    "The Spectrum keys, as in the original. LEFT SHIFT is the", $7F
        defm    "Spectrum's CAPS SHIFT and RIGHT SHIFT its SYMBOL SHIFT.", 0
hlp_cred:
        defm    "Who wrote what.", 0

hlp_game:
        defm    "You start docked at Lave with a Cobra Mk III, 100 credits", $7F
        defm    "and a pulse laser. Trade, fight pirates and police, buy", $7F
        defm    "equipment, and rise from Harmless to Elite in 8 galaxies. In", $7F
        defm    "flight the box under the compass shows the condition: G", $7F
        defm    "nothing about, A other ships about, R danger (a hostile", $7F
        defm    "ship, or two energy banks empty).", 0
hlp_scr:
        defm    "The map on the right holds the 3D view and the scanner, or a", $7F
        defm    "chart. On the left are the instruments (fuel, shields,", $7F
        defm    "temperatures, speed, roll and dive, energy banks, missiles,", $7F
        defm    "compass), the view's name and the flight messages. Text", $7F
        defm    "screens such as Status and Market Prices fill the whole", $7F
        defm    "width.", 0
hlp_leave:
        defm    "INDEX suspends the game and it carries on where you left it.", $7F
        defm    "ESC does not quit; to end the game, KILL it from the Index.", 0

hlp_fly:
        defm    "S and X climb and dive, N and M roll. SPACE speeds up and", $7F
        defm    "RIGHT SHIFT slows down. 1-4 show the front, rear, left and", $7F
        defm    "right views. Docked, 1 launches. The Options menu sets the", $7F
        defm    "docking rules (BBC, the default; strict; the Spectrum's),", $7F
        defm    "the stars (8, the default, or the Spectrum's 16) and a frame", $7F
        defm    "cap (off, the default; 6, 8 or 12.5 a second for emulators).", 0
hlp_weap:
        defm    "A (or 0) fires the laser. T targets a missile, F fires it", $7F
        defm    "and U unarms it. E sets off the ECM, W the energy bomb, Q", $7F
        defm    "launches the escape pod and C switches on the docking", $7F
        defm    "computer: each only once fitted. TAB brings an enemy in at", $7F
        defm    "once (added for this version, for practice).", 0
hlp_jump:
        defm    "Pick a system on a chart, then press H in flight: the", $7F
        defm    "countdown starts and the jump follows if you have the fuel.", $7F
        defm    "With a galactic hyperdrive fitted, G and H together take you", $7F
        defm    "to the next galaxy.", 0
hlp_screens:
        defm    "I galactic chart, O short-range chart, P data on the system,", $7F
        defm    "K market prices, L status, ENTER inventory. Docked: 2 buys", $7F
        defm    "cargo, 3 sells cargo, 4 equips the ship.", 0
hlp_chart:
        defm    "N, M, S and X move the cursor, B puts it back on your", $7F
        defm    "system, D gives the distance to the nearest system and R", $7F
        defm    "finds a system by name. On the short-range chart each system", $7F
        defm    "has a number; the names are listed on the left, the one", $7F
        defm    "under the cursor highlighted and a * after those within jump", $7F
        defm    "range.", 0

hlp_freeze:
        defm    "LEFT SHIFT freezes the game. Then SPACE carries on and 1", $7F
        defm    "starts a new game. S turns the sound on and Q turns it off.", $7F
        defm    "B, D, R, Y and K set the Spectrum's joystick and keyboard", $7F
        defm    "options.", 0
hlp_save:
        defm    "Docked, RIGHT SHIFT opens the commander menu: 1 loads, 2", $7F
        defm    "saves, 3 goes back. A commander is saved as a file named", $7F
        defm    "after him, with .elt added (JAMESON.elt for the default", $7F
        defm    "name).", 0

hlp_elite:
        defm    "Elite by Ian Bell and David Braben (1984). The ZX Spectrum", $7F
        defm    "version by Torus, published by Firebird in 1985. This card", $7F
        defm    "runs that version's Z80 code, taken from the elite-skoolkit", $7F
        defm    "disassembly.", 0
hlp_port:
        defm    "The Z88 front end draws the 3D view, scanner, charts and", $7F
        defm    "instruments natively, puts all text in OZ windows, reads the", $7F
        defm    "keyboard directly in flight, and plays the game's own sound", $7F
        defm    "on the Z88's speaker. The Lenslok check is gone. Needs an", $7F
        defm    "expanded Z88 with 48K of free RAM, and OZ 3.0 or later.", $7F
        defm    "In flight - = and ] also step the frame cap, docking, stars.", 0
end_of_code:
        defs    $3FC0-end_of_code
        doraplf [in_dor & $3FFF, BANK_APPL]
        defs    $FFF8-$FFD3
        defb    $60,$61,$60,$C8         ; card id
        defb    8                       ; card size in banks (128K)
        defb    $7C                     ; sub type: $7C = 128K (or larger) EPROM
        defm    "OZ"
