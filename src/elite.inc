; elite.inc - constants shared by the glue modules (addresses of variables and of
; the game's own routines and data)
defc V_DUSTN  = $3F24           ; stardust specks (16, the Spectrum's, or 8; set at start)
defc V_DSK    = $3F25           ; the ] key, last seen
defc V_K9     = $3F27           ; $FC09 (direction keys) as the frame's one key scan left it
defc FE_PREV  = $3F26           ; TAB, last seen (fast2.asm: the encounter key)
defc V_BANKS  = $3F00           ; RAM banks for segments 1, 2, 3
defc V_MAPB   = $3F03           ; map memory bank
defc V_MAPA   = $3F04           ; map address in segment 2
defc V_TLAST  = $3F06           ; last TIM0 value
defc V_TACC   = $3F07           ; 5 ms steps not yet counted as a frame
defc V_TMP    = $3F08           ; scratch word
defc V_FRAMES = $3F0A           ; 20 ms frames counted (debug)
defc V_HALTS  = $3F0C           ; z_halt calls (debug)
defc V_WAIT   = $3F0E           ; 1 = z_halt (wait for a frame), 0 = z_blit
defc V_BUSY   = $3F0F           ; 1 while the frame work runs (no nesting)
defc V_TAP    = $3F1C           ; typed key from OZ: half-row<<5 | bit
defc V_TAPN   = $3F1D           ; key scans left to hold it
defc V_INC    = $3EC5           ; drawn frames (instruments every 2nd)
defc V_LTIM   = $3F1E           ; TIM0 at the last latch sample
defc V_LATCH  = $3F38
defc V_LATCH2 = $3F40           ; the previous scan's latch           ; 8 bytes: keys seen down since the last scan
defc V_KEYS   = $3F10
defc V_ZXROWS = $3F30           ; 8 Spectrum half-rows, active low           ; 8 bytes: Z88 matrix, 1 = pressed, by column
defc V_VAGE   = $3F1B           ; frames since the last view frame
defc V_RAGE   = $3F1A           ; frames since the map was last redrawn
defc V_BLITS  = $3F18           ; view copies (debug: frames drawn)
defc G_START   = $D07F          ; after the Lenslok check
defc G_KEYSCAN = $FD69          ; keyboard scan (interrupt handler part 1)
defc G_RATES   = $FE01          ; roll/pitch/speed accumulators (part 2)
defc G_SOUND   = $7125          ; sound queue (part 3)
defc VBUF    = $C000
defc VW      = 168
defc VH      = 64
defc LX0     = $3E70                    ; line end points, Z88 pixels, signed 16-bit
defc LY0     = $3E72
defc LX1     = $3E74
defc LY1     = $3E76
defc LDX     = $3E78
defc LDY     = $3E7A
defc LSX     = $3E7C
defc LSY     = $3E7E
defc LERR    = $3E80
defc LSEEN   = $3E82                    ; slow line: has been inside the view
defc CCX     = $3E84                    ; circle centre (signed 16)
defc CCY     = $3E86
defc CRX     = $3E88                    ; circle radii (Z88 pixels)
defc CRY     = $3E89
defc CY      = $3E8A                    ; current row (signed 16)
defc CYEND   = $3E8C
defc CMODE   = $3E8E                    ; 0 outline, 1 filled
defc HXA     = $3E90                    ; span ends (signed 16)
defc HXB     = $3E92
defc HY      = $3E94
defc SAVSP   = $3E96
defc MASKT   = $3EB0                    ; 8 pixel masks $80..$01
defc SXT     = $C800                    ; x*21/32 for x = 0..255
defc ZSEL    = $C900
defc VC_N     = $3EA3
defc SC_DIRTY = $3EA2
defc ROWH     = $3EAC                   ; circle: buffer page of the current row
defc ROWL     = $3EAD                   ; circle: line within the cell (y AND 7)
defc SC_RM    = $3EAE                   ; scanner char rows touched by blips this frame
defc SC_RMOLD = $3EAF                   ; ... and last frame (bit n = char row n)
defc SC_ALL   = $3EB8
defc SC_CPY   = $3EB9
defc SR_C     = $3EBA                   ; rows still to copy (shifted per row)                   ; 1 = new background: copy the whole panel
defc TT_VIEW  = $3EA4                   ; view whose title is recorded ($FF = none)
defc TT_REC   = $3EA5                   ; 1 while recording
defc TT_PTR   = $3EA6                   ; record pointer
defc TT_CUR   = $3EA8                   ; text cursor after the title
defc TT_END   = $3EAA                   ; end of the record
defc TT_BUF   = $CD00                   ; recorded XORs: address (2), value (1), 255 bytes                   ; frames the scanner panel still needs copying
defc SC_X    = 212                      ; scanner centre in map pixels
defc SC_Y    = 32                    ; half-row selector -> row index (or $FF)
defc CWTAB   = $CC00                    ; 128 bytes, page aligned
defc MW_RX   = $3E9E                    ; radii the table was made for
defc MW_RY   = $3E9F
defc G_HL    = $3E98
defc G_ROWS  = $3E9A                    ; 4 squeezed rows
defc G_SH    = $3EA0                    ; glyph shift (x' AND 7)
defc CDY     = $3EA1                    ; circle: signed row offset cy - y
defc SQFONT  = $CA00                    ; 96 x 4 bytes
defc IN_SHAD  = $CB80                   ; 13 x 7 cell shadows ($FF = unknown)
defc IN_MISS  = $CBE0                   ; missile count shown ($FF = unknown)
defc IN_COMP  = $CBE1                   ; compass h, v, behind shown
defc IN_COND  = $CBE4                   ; condition letter shown
defc IN_FCAP  = $CBE5                   ; frame cap shown (+1; 0 = not yet)
defc IN_DOCK  = $CBE6                   ; docking setting shown
defc IN_CBUF  = $CC80                   ; compass canvas: 16 words
defc IN_VAL   = $CBF0                   ; 13 bar values last shown ($FF = unknown)
defc OUTBUF   = $3F48                   ; output string (S0: GN_Sop reads local memory)
defc OUTEND   = $3FF0
defc IN_PTR   = $3EBC                   ; output pointer
defc OUT_WIN  = $3EBE                   ; window the buffer is for ('1' or '3')
defc OUT_SEL  = (OUTBUF+4)%256          ; pointer low byte after the window select
defc TX_SHAD  = $CD00                   ; 24 rows x 31 columns
defc TX_MODE  = $3EC3                   ; 1 = window 3 holds a text screen
defc TX_CLR   = $3EBF                   ; 1 = the game cleared its screen: clear ours too
defc TX_LX    = $3EC0                   ; where the OZ cursor was left (x, y in window)
defc TX_LY    = $3EC1
defc TX_BACK  = $3EC2                   ; 1 = back to the flight layout at the next frame
defc TX_VIEW  = $70E3
defc TI_ON    = $3EC6                   ; 1 = the title screen text is being printed
defc TI_MODE  = $3EC7                   ; 1 = window 1 holds the title text (no instruments)
defc TI_KIND  = $3EC8                   ; which title text (1 = load commander?, 2 = press space)
defc V_PUR    = $3ECA                   ; 1 = purge OZ's keyboard buffer at the next frame work (OS_Pur)
defc VN_SHOWN = $3ECB                   ; flight view whose name is shown ($FF = none)
defc MSG_ANY  = $3ECC                   ; flight text printed this frame
defc MSG_SANY = $3ECD                   ; flight text on show
defc MSG_NOW  = $CCA0                   ; flight text lines this frame: 2 x 23 cells
defc MSG_SHN  = $CCCE                   ; ... and as shown in window 1
defc MSG_W    = 23                      ; cells per line (window 1, columns 28-50)
defc CH_MODE  = $3ECF                   ; 1 = window 1 holds a chart's text (no instruments)
; charts (chart.asm, overlaid on the dead beeper player at $9551)
defc V_CAP    = $3EF7                   ; frame cap setting 0-4: 20, 25/s, off, 12.5, 16.7/s (= cycles it)
defc V_FT     = $3EFC
defc V_STRICT = $3EFD                   ; strict docking (the BBC's approach cone): 0 off, 1 on
defc V_DKK    = $3EFE
defc CLIM     = $3EFF                   ; circle: a row whose half-width is more than this
                                        ; has both its ends outside the view                   ; the = key, last seen                   ; TIM0 (5 ms steps) when the last frame started
defc V_CAPK   = $3EFB                   ; the = key as last seen (only a new press counts)
defc R_MAPB   = $3EF8                   ; the map itself (V_MAPB/V_MAPA: where to draw)
defc R_MAPA   = $3EF9
defc OV_CROSS  = $E531                  ; the chart cursor, XORed into the map (chart2.asm)
defc OV_LIST   = $E534                  ; the numbered systems into window 1 (chart2.asm)
defc OV_COND   = $E537                  ; the condition letter (chart2.asm)
defc CH_VIEW  = $3EF0                   ; chart.asm: TX_VIEW, kept while the map is in segment 1
defc LB_HI    = $3EF1                   ; short-range chart: the system under the cursor ($FF none)
defc LB_BI    = $3EF2                   ; (lhi work: best so far, and its distance)
defc LB_BS    = $3EF3
defc LB_GX    = $3EF5                   ; the galaxy x, y of the system being named
defc LB_GY    = $3EF6
defc CH_CNT   = $3ED4                   ; chart renders still to do (something new drawn)
defc CH_SAFE  = $3ED5                   ; chart: render calls since the last render
defc CX_N     = $3ED6                   ; crosshairs on the chart (XORed into the map)
defc CX_TAB   = $3ED7                   ; ... x, y, arm each, up to 4
defc LB_N     = $3EE3                   ; short-range chart: systems named so far
defc LB_ROW   = $3EE4                   ; ... row and column of the last character
defc LB_COL   = $3EE5
defc LB_DIRTY = $3EE6                   ; ... the list in window 1 wants printing
defc CR_HI    = $3EE7                   ; chart.asm work: the map's high address byte
defc CX_X     = $3EE8
defc CX_Y     = $3EE9
defc CX_H     = $3EEA
defc CX_PM    = $3EEB
defc CX_I     = $3EEC
defc CX_TMP   = $3EED                   ; (3 bytes)
defc LB_TAB   = TX_SHAD+3*31            ; systems: row, column, name (10), galaxy x, y;
defc LB_SZ    = 14                      ; the shadow's rows 3-18 are not used while a
defc LB_MAX   = 32                      ; chart is up
defc SND_N    = $3ED1                   ; sound: frames left of the effect playing
defc SND_P    = $3ED2                   ; sound: its pattern (word, bit 0 = next frame)
defc CM_ON    = $3ECE                   ; 1 = the disk menu (D90A) is up: its text is a text screen
