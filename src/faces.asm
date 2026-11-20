; faces.asm - which faces of a ship can be seen: a faster replacement for the game's
; routine at BCD4 (with BD5F, BD95 and BDB4, used only by it), in its place.
;
; The game rotates every face normal n into the world (R n, nine multiplies a face, at
; AC01) and tests the sign of  R n . (pos + 2 R n / 2^k)  (pos: the ship's position,
; k: the blueprint's normal scale, +$13), negative = visible.  A rotation keeps dot
; products, so the same number is  n . (q + n / 2^(k+1))  with  q = R' pos  (the ship's
; position in its own frame: three dot products once a ship) - as the BBC Micro version
; does it, using |R n|^2 = |n|^2 (127/256)^2, about |n|^2 / 4.  So a face costs three
; multiplies instead of fifteen.  Products are exact (quarter squares from the game's own
; table of squares at $BE00/$BF00, with the odd-sum correction: FMUL8, in view.asm); the game's are rounded,
; so a face almost edge-on may show a frame sooner or later than on the Spectrum.
;
; In: IX = the ship (x, y, z: lo, hi, sign at +0..+8), IY = its blueprint (+5 faces,
; +$10/$11 offset of the face list: 4 bytes a face, n_x n_y n_z magnitudes, then signs
; in bits 7, 6, 5 and a distance limit in bits 0-4; +$13 k).  The orientation, as AC01
; uses it, at $A994: rows x, y, z 6 bytes apart, sidev/roofv/nosev high bytes at +1/+3/+5
; (sign in bit 7).  Out: $A984 + face = 1 visible, 0 not.  IX, IY kept.
        module  faces
        org     $BCD4
        include "glue.def"              ; FMUL8 (in the front end, for room)

; scratch: $A9A6-$A9B7, where AC01 keeps its products; the game's routine overwrote them
; here too (each AC01 call), and the vertex code fills them again before it reads them
defc fv_a0 = $A9A6                      ; the 24-bit sum
defc fv_a1 = $A9A7
defc fv_a2 = $A9A8
defc fv_qv = $A9A9                      ; q: 3 words
defc fv_p  = $A9AF                      ; -> the ship's position component
defc fv_r  = $A9B1                      ; low byte of -> R(i, column)
defc fv_k  = $A9B2                      ; k + 1
defc fv_n  = $A9B3                      ; faces left
defc fv_sg = $A9B4                      ; the face's normal signs, shifting

fv:     push    iy                      ; (IX is not changed)
        ld      a,(iy+$13)
        inc     a
        ld      (fv_k),a                ; k + 1
        ld      e,(iy+$10)
        ld      d,(iy+$11)
        ld      a,(iy+$05)              ; faces
        add     iy,de                   ; IY = the face list
        and     a
        jr      nz,fv_q
        inc     a                       ; no faces: as the game (face 0 "visible")
        ld      ($A984),a
        jr      fv_x
fv_q:   ld      (fv_n),a
; q = R' pos: for each column (side, roof, nose) the dot product with the position
        ld      hl,fv_qv
        ld      a,$95                   ; $A995: sidev_x_hi
fq_c:   ld      (fv_r),a
        push    hl
        call    acc0
        push    ix
        pop     hl
        ld      (fv_p),hl
        call    qterm                   ; x
        call    qterm                   ; y
        call    qterm                   ; z
        pop     hl
        ld      de,(fv_a1)          ; q = acc >> 8 (16 bits, two's complement)
        ld      (hl),e
        inc     hl
        ld      (hl),d
        inc     hl
        ld      a,(fv_r)
        sub     18-2                    ; back to row x, next column
        cp      $9B
        jr      c,fq_c
; the faces
        ld      de,$A984
fv_f:   push    de
        ld      a,(iy+$03)
        and     $1F
        cp      $1F
        jr      z,fv_d
        ld      b,a
        ld      a,($A9B8)               ; the ship's distance class: faces with a
        cp      b                       ; smaller limit are not drawn (as the game)
        jr      c,fv_d
        xor     a
        jr      fv_s
fv_d:   call    acc0
        ld      hl,fv_qv
        ld      a,(iy+$03)
        ld      (fv_sg),a
        ld      a,(iy+$00)
        call    fterm
        ld      a,(iy+$01)
        call    fterm
        ld      a,(iy+$02)
        call    fterm
        ld      a,(fv_a2)
        rlca
        and     1                       ; negative: visible
fv_s:   pop     de
        ld      (de),a
        inc     de
        ld      bc,4
        add     iy,bc
        ld      hl,fv_n
        dec     (hl)
        jr      nz,fv_f
fv_x:   pop     iy
        ret

; qterm: acc += pos_i * R(i, column); fv_p -> pos_i (lo, hi, sign), fv_r: R's low address
qterm:  ld      hl,(fv_p)
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      b,(hl)                  ; sign
        inc     hl
        ld      (fv_p),hl
        ld      a,(fv_r)
        ld      l,a
        add     a,6
        ld      (fv_r),a
        ld      h,$A9
        ld      a,(hl)
        ld      c,a
        res     7,c
        xor     b                       ; sign of the product in bit 7
        jr      smac

; fterm: acc += n_j * (q_j + n_j / 2^(k+1)), n_j = A, its sign the top bit of fv_sg
; (shifted up for the next), HL -> q_j (advanced)
fterm:  ld      c,a                     ; n
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        push    hl
        ld      a,(fv_k)
        ld      b,a
        ld      a,c
ft_sh:  srl     a
        djnz    ft_sh
        ld      l,a                     ; n / 2^(k+1)
        ld      h,0
        ld      a,(fv_sg)
        rla
        ld      (fv_sg),a               ; carry = n's sign
        sbc     a,a
        and     $80
        ld      b,a                     ; B bit 7 = n's sign
        ex      de,hl                   ; HL = q, DE = the small term
        jr      nz,ft_m
        add     hl,de
        jr      ft_w
ft_m:   or      a
        sbc     hl,de
ft_w:   ld      a,b
        bit     7,h
        jr      z,ft_p
        xor     $80                     ; w < 0: |w|, sign flipped
        ex      de,hl
        ld      hl,0
        or      a
        sbc     hl,de
ft_p:   ex      de,hl                   ; DE = |w|
        call    smac
        pop     hl
        ret

; smac: acc (24 bits) += or -= DE * C (bit 7 of A set: minus)
smac:   push    af
        ld      b,e
        call    FMUL8
        push    hl                      ; lo * c
        ld      b,d
        call    FMUL8                    ; hi * c
        pop     de
        ld      a,d
        add     a,l
        ld      l,a
        ld      a,h
        adc     a,0
        ld      h,a                     ; H:L:E = the product
        ld      b,h
        ld      c,l
        pop     af
        rla                             ; carry = minus: the product's complement,
        jr      nc,sm_a                 ; plus the carry, is its negative
        ld      a,e
        cpl
        ld      e,a
        ld      a,c
        cpl
        ld      c,a
        ld      a,b
        cpl
        ld      b,a
        scf
sm_a:   ld      a,e
        ld      hl,fv_a0
        adc     a,(hl)
        ld      (hl),a
        inc     hl
        ld      a,c
        adc     a,(hl)
        ld      (hl),a
        inc     hl
        ld      a,b
        adc     a,(hl)
        ld      (hl),a
        ret

acc0:   ld      hl,fv_a0
        xor     a
        ld      (hl),a
        inc     hl
        ld      (hl),a
        inc     hl
        ld      (hl),a
        ret

fv_end:
