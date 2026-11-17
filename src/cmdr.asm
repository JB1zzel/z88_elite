; cmdr.asm - commander save and load as OZ files (mpm module, linked by glue.prj)
;
; The game's own disk menu (D90A: 1 load, 2 save, 3 cancel), its name prompt, name check
; and messages are kept; only the two ROM tape calls are replaced:
;   load (CALL $0562 at D954): read the 102-byte block $D054-$D0B9 from a file named after
;       the commander name typed at the prompt ($DED0);
;   save (CALL $04C6 at D99C): write the block to a file named after the commander ($D054).
; File name: the name (up to 10 characters, up to a space or NUL) + ".elt", in the current
; directory; an empty name loads "JAMESON.elt".  Carry set = done, as the ROM routines.
; OZ wants its buffers in segment 0, so the block goes through CM_BUF here.
        module cmdr
        include "stdio.def"
        include "fileio.def"
        include "error.def"
        include "elite.inc"
        xdef    cm_enter, cm_load, cm_save
        xref    tx_clsj

defc CM_LEN = $66                       ; the game's tape block: $D054-$D0B9

; cm_enter: the disk menu's "clear screen" (D90A): its text is a text screen
cm_enter:
        ld      a,1
        ld      (CM_ON),a
        jp      tx_clsj

; cm_load: block <- file "<name at $DED0>.elt"
cm_load:
        ld      hl,$DED0
        call    cm_name
        ld      a,OP_IN
        call    cm_open
        ret     nc                      ; (carry clear: failed)
        ld      bc,CM_LEN
        ld      hl,0
        ld      de,CM_BUF
        oz      OS_Mv
        push    af
        push    bc
        oz      GN_Cl
        pop     bc
        pop     af
        jr      c,cm_fail
        ld      a,b                     ; all of it?
        or      c
        jr      nz,cm_fail
        ld      hl,CM_BUF               ; into the game's block
        ld      de,$D054
        ld      bc,CM_LEN
        ldir
        jr      cm_ok

; cm_save: file "<name at $D054>.elt" <- block
cm_save:
        ld      hl,$D054
        call    cm_name
        ld      hl,$D054
        ld      de,CM_BUF
        ld      bc,CM_LEN
        ldir
        ld      a,OP_OUT
        call    cm_open
        ret     nc
        ld      bc,CM_LEN
        ld      hl,CM_BUF
        ld      de,0
        oz      OS_Mv
        push    af
        oz      GN_Cl
        pop     af
        jr      c,cm_fail
cm_ok:  call    cm_di
        scf
        ret
cm_fail:
        call    cm_di
        or      a
        ret

; cm_open: open CM_FN with access mode A (interrupts on for OZ).  Carry set = open (IX);
; carry clear = failed, interrupts as the game had them.
cm_open:
        push    af
        ld      a,i                     ; remember the interrupt state (P/V)
        push    af
        pop     hl
        ld      (CM_IFF),hl
        pop     af
        ei
        ld      b,0
        ld      hl,CM_FN
        ld      de,CM_EXP
        ld      c,CM_EXPL
        oz      GN_Opf
        jr      c,cm_fail
        scf
        ret

; cm_di: back to the game's interrupt state
cm_di:  push    af
        push    hl
        ld      hl,(CM_IFF)
        push    hl
        pop     af
        di
        jp      po,cm_d1
        ei
cm_d1:  pop     hl
        pop     af
        ret

; cm_name: CM_FN = name at HL (to a space or NUL, at most 10) + ".elt"
cm_name:
        ld      de,CM_FN
        ld      b,10
cn_lp:  ld      a,(hl)
        cp      ' '+1
        jr      c,cn_end
        ld      (de),a
        inc     hl
        inc     de
        djnz    cn_lp
cn_end: ld      a,e                     ; nothing typed: JAMESON
        cp      CM_FN%256
        jr      nz,cn_ext
        ld      hl,cm_defn
cn_def: ld      a,(hl)
        and     a
        jr      z,cn_ext
        ld      (de),a
        inc     hl
        inc     de
        jr      cn_def
cn_ext: ld      hl,cm_ext
        ld      bc,5
        ldir
        ret

cm_defn: defm   "JAMESON", 0
cm_ext:  defm   ".elt", 0

defc CM_EXPL = 40
CM_IFF: defw    0
CM_FN:  defs    16
CM_EXP: defs    CM_EXPL
CM_BUF: defs    CM_LEN
