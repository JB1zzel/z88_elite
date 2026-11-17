; memtest - can an OZ 5 application get whole RAM banks for segments 1-3?
        module memtest
        include "stdio.def"
        include "dor.def"
        include "macros.def"
        include "error.def"
        include "director.def"
        include "map.def"
        include "memory.def"

        org $C000

defc V_SIG  = $2000             ; "MEMTST"
defc V_LOG  = $2008             ; mop: AF, IX ; big mal: AF, B, HL
defc V_N    = $2018             ; count of 256-byte allocs ok
defc V_ERR  = $2019             ; AF of first failing alloc
defc V_TAB  = $2100             ; per alloc: B, H, L
defc REQPAGES = 4
defc SAFEDATA = 0

app_entrypoint:
        ld      a,SC_DIS
        oz      Os_Esc
        xor     a
        ld      b,a
        ld      hl,errhan
        oz      Os_Erh
        ld      hl,sig
        ld      de,V_SIG
        ld      bc,6
        ldir
        xor     a
        ld      (V_N),a

        ld      a,MM_S1|MM_EXC
        ld      bc,0
        oz      Os_Mop
        push    af
        pop     hl
        ld      (V_LOG+0),hl
        ld      (V_LOG+2),ix
        jp      c,done
        ; try one 16K allocation
        ld      bc,$4000
        oz      Os_Mal
        push    af
        pop     de
        ld      (V_LOG+4),de
        ld      a,b
        ld      (V_LOG+6),a
        ld      (V_LOG+7),hl
        ; then 256-byte allocations, up to 80
        ld      de,V_TAB
        ld      a,80
loop:   push    af
        push    de
        ld      bc,256
        oz      Os_Mal
        pop     de
        jr      c,fail
        ld      a,b
        ld      (de),a
        inc     de
        ld      a,h
        ld      (de),a
        inc     de
        ld      a,l
        ld      (de),a
        inc     de
        ld      hl,V_N
        inc     (hl)
        pop     af
        dec     a
        jr      nz,loop
        jr      done
fail:   push    af
        pop     hl
        ld      (V_ERR),hl
        pop     af
done:   ld      hl,msg
        call    puts_oz
wait:   ld      bc,0
        oz      Os_Tin
        jr      wait

errhan: ret     z
        cp      RC_Quit
        jr      nz,eh1
        xor     a
        oz      Os_Bye
eh1:    xor     a
        ret

puts_oz:
        ld      a,(hl)
        and     a
        ret     z
        push    hl
        oz      Os_Out
        pop     hl
        inc     hl
        jr      puts_oz

sig:    defm    "MEMTST"
msg:    defb    1,'7','#','1',32,32,32+60,32+8,128,1,'2','C','1'
        defm    "memtest done",0

defc BANK_APPL = $3F
application_dor_entrypoint:
        jp      app_entrypoint
        scf
        ret
in_dor:
        dorappl ("MemTest", 'Y', AT_Bad|AT_Draw, AT2_Cl,  \
                 application_dor_entrypoint,               \
                 0, 0, 0, BANK_APPL,                       \
                 REQPAGES, 0, 0, SAFEDATA,                 \
                 [in_topics, BANK_APPL],                   \
                 [in_commands, BANK_APPL],                 \
                 [in_help, BANK_APPL],                     \
                 ,                                         \
                 BANK_APPL)
in_topics:
        defb    0
        defb    0
in_commands:
        defb    0
        defb    0
in_help:
        defm    "Memory test", 0
end_of_code:
        defs    $3FC0-end_of_code
        doraplf [in_dor & $3FFF, BANK_APPL]
        defs    $FFF8-$FFD3
        defb    $60,$61,$60,$C8
        defb    1
        defb    0
        defm    "OZ"
