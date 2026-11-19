; app.asm - Elite for the Cambridge Z88: application bank (boot code, glue copy, DOR).
; Card layout (128K): banks $38-$3B empty ($FF), banks $3C/$3D/$3E = the patched Spectrum game ($4000/$8000/$C000),
; bank $3F = this bank.  Needs an expanded Z88 (three free 16K RAM banks).
        module eliteapp
        include "stdio.def"
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

; --- copy the game from the card into the RAM banks --------------------------------------
        ld      hl,V_BANKS
        ld      a,(V_CARD)
        sub     3
        ld      e,a             ; E = card bank of the next 16K
        ld      d,3
cp_lp:  push    de
        push    hl
        ld      b,e
        ld      c,1
        oz      Os_Mpb          ; card bank -> segment 1
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
        inc     e
        dec     d
        jr      nz,cp_lp

        ld      a,1
        ld      (TI_MODE),a        ; (no instruments yet: the title comes first)
        call    JT_Z_REDRAW        ; windows and map
        ld      a,(V_BANKS)
        ld      b,a
        ld      c,1
        oz      Os_Mpb
        ld      a,(V_BANKS+1)
        ld      b,a
        ld      c,2
        oz      Os_Mpb
        jp      JT_Z_START         ; glue binds segment 3 and starts the game

no_mem2:
        pop     af
no_mem: ld      hl,msg_mem
        ld      b,0
pm:     ld      a,(hl)
        and     a
        jr      z,wait
        push    hl
        oz      Os_Out
        pop     hl
        inc     hl
        jr      pm
wait:   oz      Os_In
        jr      wait

msg_mem:
        defb    1,'7','#','1',32,32,32+90,32+8,128,1,'2','C','1'
        defm    "Elite needs an expanded Z88: not enough free RAM (48K).",0

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
        mthtpc  ["Keys"], TPCF_HELP, (hlp_keys-in_help)
        mthtpc  ["Credits"], TPCF_HELP, (hlp_cred-in_help)
        defb    0

in_commands:
        defb    0
        mthcmd  (0, , ["The game"],      CMDF_HELP, (hlp_game-in_help))
        mthcmd  (0, , ["The screen"],    CMDF_HELP, (hlp_scr-in_help))
        mthcmd  (0, , ["Leaving"],       CMDF_HELP, (hlp_leave-in_help))
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

in_help:                                ; a help page holds 7 lines of 63 characters
        defm    "ELITE", $7F
        defm    $7F
        defm    "The ZX Spectrum Elite for the expanded Z88: the original Z80", $7F
        defm    "game code runs here, with its graphics and text redrawn for the", $7F
        defm    "Z88 screen.", $7F
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
        defm    "You start docked at Lave with a Cobra Mk III, 100 credits and a", $7F
        defm    "pulse laser. Trade between systems, fight pirates and police,", $7F
        defm    "buy better equipment, and work your way up from Harmless to", $7F
        defm    "Elite across eight galaxies.", $7F
        defm    "In flight the box under the compass shows the condition: G", $7F
        defm    "nothing about, A other ships about, R danger (a hostile ship,", $7F
        defm    "or two energy banks empty).", 0
hlp_scr:
        defm    "The map on the right holds the 3D view and the scanner, or a", $7F
        defm    "chart. On the left are the instruments (fuel, shields,", $7F
        defm    "temperatures, speed, roll and dive, energy banks, missiles,", $7F
        defm    "compass), the view's name and the flight messages. Text screens", $7F
        defm    "such as Status and Market Prices fill the whole width.", 0
hlp_leave:
        defm    "INDEX suspends the game and it carries on where you left it.", $7F
        defm    "ESC does not quit; to end the game, KILL it from the Index.", 0

hlp_fly:
        defm    "S and X climb and dive, N and M roll. SPACE speeds up and RIGHT", $7F
        defm    "SHIFT slows down. 1, 2, 3 and 4 show the front, rear, left and", $7F
        defm    "right views. Docked, 1 launches.", 0
hlp_weap:
        defm    "A (or 0) fires the laser. T targets a missile, F fires it and U", $7F
        defm    "unarms it. E sets off the ECM, W the energy bomb, Q launches", $7F
        defm    "the escape pod and C switches on the docking computer: each", $7F
        defm    "only once fitted.", $7F
        defm    $7F
        defm    "TAB brings an enemy in at once (added for this version, for", $7F
        defm    "practice).", 0
hlp_jump:
        defm    "Pick a system on a chart, then press H in flight: the countdown", $7F
        defm    "starts and the jump follows if you have the fuel. With a", $7F
        defm    "galactic hyperdrive fitted, G and H together take you to the", $7F
        defm    "next galaxy.", 0
hlp_screens:
        defm    "I galactic chart, O short-range chart, P data on the system, K", $7F
        defm    "market prices, L status, ENTER inventory. Docked: 2 buys cargo,", $7F
        defm    "3 sells cargo, 4 equips the ship.", 0
hlp_chart:
        defm    "N, M, S and X move the cursor, B puts it back on your system, D", $7F
        defm    "gives the distance to the nearest system and R finds a system", $7F
        defm    "by name. On the short-range chart each system has a number; the", $7F
        defm    "names are listed on the left, the one under the cursor", $7F
        defm    "highlighted and a * after those within jump range.", 0

hlp_freeze:
        defm    "LEFT SHIFT freezes the game. Then SPACE carries on and 1 starts", $7F
        defm    "a new game. S turns the sound on and Q turns it off. B, D, R, Y", $7F
        defm    "and K set the Spectrum's joystick and keyboard options.", 0
hlp_save:
        defm    "Docked, RIGHT SHIFT opens the commander menu: 1 loads, 2 saves,", $7F
        defm    "3 goes back. A commander is saved as a file named after him,", $7F
        defm    "with .elt added (JAMESON.elt for the default name).", 0

hlp_elite:
        defm    "Elite by Ian Bell and David Braben (1984). The ZX Spectrum", $7F
        defm    "version by Torus, published by Firebird in 1985. This card runs", $7F
        defm    "that version's Z80 code, taken from the elite-skoolkit", $7F
        defm    "disassembly.", 0
hlp_port:
        defm    "The Z88 front end draws the 3D view, scanner, charts and", $7F
        defm    "instruments natively, puts all text in OZ windows, reads the", $7F
        defm    "keyboard directly in flight, and plays the effects on the Z88's", $7F
        defm    "speaker. The Lenslok check is gone. Needs an expanded Z88 with", $7F
        defm    "48K of free RAM, and OZ 3.0 or later.", 0
end_of_code:
        defs    $3FC0-end_of_code
        doraplf [in_dor & $3FFF, BANK_APPL]
        defs    $FFF8-$FFD3
        defb    $60,$61,$60,$C8         ; card id
        defb    8                       ; card size in banks (128K)
        defb    $7C                     ; sub type: $7C = 128K (or larger) EPROM
        defm    "OZ"
