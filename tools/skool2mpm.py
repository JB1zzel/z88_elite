"""skool2mpm.py elite.skool out.asm [--z88]
Turn the SkoolKit disassembly into mpm source at the original addresses ($4000-$FFFF).
Without --z88 it is the exact Spectrum image (checked byte for byte against the snapshot).
With --z88 it applies the same-length Z88 patches listed below; they call the glue and the
fast routines by name (glue.def, fast.def, fast2.def from mpm -g, included by the output)."""
import re, sys, bisect
src = open(sys.argv[1], encoding='utf-8').read().splitlines()
Z88 = '--z88' in sys.argv
line_re = re.compile(r'^([bcstuwi* ])\$([0-9A-F]{4}) (.*)$')

# --- glue jump table (glue.asm) ----------------------------------------------------------
# entries are named jt_<routine> in glue.asm (XDEF), and glue.def (mpm -g) gives
# their addresses; the patched game source includes it
G = dict(halt='JT_Z_HALT', st_bit7hl='JT_ST_BIT7HL', st_ldafc0d='JT_ST_LDAFC0D',
         st_ldc4='JT_ST_LDC4', st_kemp='JT_ST_KEMP', st_74de='JT_ST_74DE',
         st_djnz='JT_ST_DJNZ', st_c632='JT_ST_C632', pa22aa='JT_PA22AA', pa22b0='JT_PA22B0',
         pa22b1='JT_PA22B1', zxin='JT_ZXIN', beep='JT_BEEP', blit='JT_Z_BLIT')

# multi-byte patches: address -> (bytes replaced, [instructions])
PATCH = {
    0x78C7: (5, ['CALL S_DUST', 'NOP', 'NOP']),                           # stardust count: 16, or 8 (the ] key; snd.asm)
    0xF51F: (25, ['DEFM "PRESS ANY KEY TO SAVE   ",$00']),                  # message 2 (was START TAPE, THEN PRESS ANY KEY): same length,
    0xF538: (13, ['DEFM "NO SUCH FILE",$00']),                                # message 3 (was TAPE LOADING ERROR): the tokens after stay put
    0x7391: (3, ['CALL CM_TITLE']),                                     # title Y: the commander block filled first (snd.asm)
    0xB58F: (6, ['JP DK_CHECK', 'NOP', 'NOP', 'NOP']),                  # docked: strict docking's cone check first (dock.asm)
    0x95B0: (4, ['CALL S_AND', 'NOP']),                                 # the game's own sound code (9527-96BE), in place: each
    0x95F8: (4, ['CALL S_ON', 'NOP']),                                  # OUT ($FE),A and the instruction before it -> the Z88
    0x95FF: (3, ['CALL S_OFF']),                                        # speaker (Blink COM SBIT; snd.asm)
    0x9631: (3, ['CALL S_BE']),
    0x9637: (3, ['CALL S_BE']),
    0x7352: (4, ['CALL S_ON', 'NOP']),                                  # freeze menu error beep, the same way
    0x735A: (3, ['CALL S_OFF']),
    0x7506: (3, ['CALL $8390']),                                        # dashboard bars (84D9): drawn as UDGs, so CALL a RET -
    0x94BD: (3, ['CALL $8390']),                                        # 8446-8618 holds the chart code (chart.asm, chart4.asm)
    0x70C4: (5, ['CALL %s' % G['halt'], 'RET', 'NOP']),          # skip attribute fill
    0x7231: (3, ['CALL %s' % G['st_bit7hl']]),
    0x72AC: (4, ['CALL %s' % G['st_ldafc0d'], 'NOP']),
    0x72B3: (4, ['CALL %s' % G['st_ldafc0d'], 'NOP']),
    0xDA25: (4, ['CALL %s' % G['st_ldafc0d'], 'NOP']),
    0x7349: (3, ['CALL %s' % G['st_ldc4']]),
    0x73D5: (3, ['CALL %s' % G['st_kemp']]),
    0x74DE: (4, ['JP %s' % G['st_74de'], 'NOP']),
    0x756B: (3, ['CALL %s' % G['st_djnz']]),
    0xE360: (3, ['CALL %s' % G['st_djnz']]),
    0xE43E: (3, ['CALL %s' % G['st_djnz']]),
    0xC632: (5, ['CALL %s' % G['st_c632'], 'NOP', 'NOP']),
    0xFD78: (4, ['CALL %s' % G['zxin'], 'NOP']),                 # IN A,(C) / AND $1F
    0xFC28: (2, ['XOR A', 'NOP']),
    0x8080: (3, ['JP JT_Z_CLEAR']),                                      # clear 3D area
    0x7D0F: (3, ['JP JT_Z_STAR']),                                      # stardust address
    0xA83C: (3, ['JP JT_Z_PLOT']),                                      # plot pixel
    0x86E9: (3, ['CALL JT_Z_CIRC']),                                    # circle
    0xD543: (3, ['CALL JT_HK_GLYPH']),                                    # text into the view
    0x9788: (3, ['JP JT_Z_BLIP']),                                      # scanner blip
    0x9B01: (1, ['RET']),                                           # dashboard icons (drawn as UDGs instead)
    0x8390: (1, ['RET']),                                           # dashboard compass (UDGs instead)
    0xDA98: (3, ['CALL JT_Z_TITLE']),                                    # view title cache
    0xDAAB: (3, ['CALL JT_Z_TITLE_END']),                                    # view title cache end                                    # circle
    0xAB73: (3, ['CALL JT_HK_VERTEX']),                                    # key latch sample
    0xD4F2: (3, ['CALL JT_HK_CHAR']),                                    # key latch sample
    0x7FBE: (3, ['JP %s' % G['blit']]),                         # view copy + frame work                                  # Kempston: nothing
    0x8142: (3, ['NOP', 'NOP', 'NOP']),                                 # screen actions: stay on the OZ stack (S0), not $D000
    0xD7F1: (2, ['DEFW JT_TX_CLSJ']),                                        # text control code: clear screen -> tx_clsj
    0xED78: (3, ['CALL $7FC1']),                                        # a chart name's system: keep its position (chart6.asm, ldgx)
    0xE52E: (3, ['JP $E531']),                                          # chart crosshairs: XORed into the map (chart2.asm, E531-E6AC, then chart.asm)
    0x737B: (3, ['CALL JT_TI_7426']),                                       # title text (load commander?) -> window 1
    0x73C6: (3, ['CALL JT_TI_7430']),                                       # title text (press space) -> window 1
    0xD90A: (3, ['CALL JT_CM_ENTER']),                                 # disk menu: its text is a text screen
    0xD954: (3, ['CALL JT_CM_LOAD']),                                  # load commander from an OZ file
    0xD99C: (3, ['CALL JT_CM_SAVE']),                                  # save commander to an OZ file
    0xE37D: (3, ['JPB', 'JT_TX_BAND']),                                      # lower text-line fill: also blanks the OZ text
    0xE2F0: (3, ['CALL JT_TX_ERASE']),                                 # typed-character erase: also in the OZ text
    0x990C: (3, ['RET', 'NOP', 'NOP']),                                 # Spectrum scanner background copy ($5B00 <-> screen): the Z88 scanner is drawn by the glue
    0x818C: (2, ['NOP', 'NOP']),                                       # control panel save ($5000 -> $C000): $C000 is the Z88 view buffer, its scanner panel would be wiped
    0xD088: (2, ['NOP', 'NOP']),                                       # start-up copy of the panel image $C800 -> $C000: $C000 is the view buffer, $C800 a table (garbage in the scanner panel)
}
# fast.asm / fast2.asm (assembled first by build.sh into dead line-drawing code at
# $B047-$B434): their entry points come by name from fast.def / fast2.def
if Z88:
    PATCH[0xB044] = (0xB2F0 - 0xB044, ['JP JT_Z_LINE', 'DEFS %d' % (0xB2F0 - 0xB047)])   # line: glue; rest: fast.asm
    for _a, _n in ((0xAFA8, 'FDIV_HL_A_DE'), (0xAC8B, 'FDIV_AC8B'), (0x7CD5, 'FDIV_COORD'), (0x7CFB, 'FDIV_7CFB'), (0xD45F, 'FTOK')):
        PATCH[_a] = (3, ['JPB', _n])            # JP as bytes (old rows inside it keep labels)
    PATCH[0x9CFD] = (4, ['CALL FENC', 'NOP'])   # TAB: forced encounter (fast2.asm)
def rule(ins):
    """single-instruction replacements of the same length, or None"""
    u = ins.upper()
    if u == 'EI': return ['NOP']
    if u in ('IM 1', 'IM 2'): return ['NOP', 'NOP']
    if u == 'OUT ($FE),A': return ['NOP', 'NOP']
    m = re.match(r'^(CALL|JP) \$(0556|0562|04C6|0802|22AA|22B0|22B1|03B5|0D6B|1601|22DF)$', u)
    if m:
        op, a = m.groups()
        if a in ('0556', '0562', '04C6', '0802'): return ['AND A', 'NOP', 'NOP']   # tape: fail
        if a in ('0D6B', '1601', '22DF'): return ['NOP', 'NOP', 'NOP']             # Lenslok only
        tgt = {'22AA': 'pa22aa', '22B0': 'pa22b0', '22B1': 'pa22b1', '03B5': 'beep'}[a]
        return ['%s %s' % (op, G[tgt])]
    if u in ('CALL $D61D', 'JP $D61D'):
        return [u.split()[0] + ' JT_TX_CLSJ']
    m = re.match(r'^LD A,\(\$FC0([89A-F])\)$', u)
    if m:
        return ['CALL JT_RD_FC0%s' % m.group(1)]
    if u == 'HALT':
        raise SystemExit('unpatched HALT')
    if re.match(r'^IN A,\(C\)$', u):
        raise SystemExit('unpatched IN')
    return None

rows = []
for l in src:
    m = line_re.match(l)
    if m and m.group(1) != 'i':
        rows.append((int(m.group(2), 16), m.group(3)))
addrs = [a for a, _ in rows]
def ref(a):
    if a < 0x4000: return '$%04X' % a
    if Z88 and 0xB047 <= a < 0xB2F0: return '$%04X' % a    # (dead code into fast.asm's space)
    i = bisect.bisect_right(addrs, a) - 1
    b = addrs[i]
    return 'L_%04X' % b if b == a else 'L_%04X+%d' % (b, a - b)

out = ['; generated by skool2mpm.py from elite.skool%s - do not edit' % (' (Z88 patches)' if Z88 else ''),
       '        org $4000']
if Z88:
    out[1:1] = ['        include "glue.def"', '        include "fast.def"', '        include "fast2.def"', '        include "snd.def"', '        include "dock.def"']
skip_to = 0
deflabels = []
pad_from = None
patched = []
expect = None
for addr, rest in rows:
    if addr < skip_to:
        continue
    if pad_from is not None:
        if addr > pad_from:                  # patch ended inside an instruction: NOP to here
            out.append('        defb    ' + ','.join(['0'] * (addr - pad_from)))
        pad_from = None
    if rest.lstrip().upper().startswith('DEFM'):
        q = False; cut = len(rest)
        for k, ch in enumerate(rest):
            if ch == '"': q = not q
            if ch == ';' and not q: cut = k; break
        ins = rest[:cut].strip()
    else:
        ins = rest.split(';', 1)[0].strip()
    if ins.startswith('LD IX,$6159+$09'):
        pass
    ins = re.sub(r'^((?:JR|DJNZ|JP|CALL)\b[^$]*)\$([0-9A-F]{4})$', lambda mm: mm.group(1) + ref(int(mm.group(2), 16)), ins)
    if Z88 and addr in PATCH and PATCH[addr][1][0] == 'JPB':
        n, (_, tgt) = PATCH[addr]
        bs = ['$C3', '%s %% 256' % tgt, '%s / 256' % tgt]
        for k in range(3):
            lab = '.L_%04X ' % (addr + k) if (k == 0 or addr + k in addrs) else '        '
            out.append('%s defb    %s' % (lab, bs[k]))
        skip_to = addr + n; pad_from = addr + n; patched.append((addr, n))
        continue
    if Z88 and addr in PATCH:
        n, new = PATCH[addr]
        out.append('.L_%04X  %s' % (addr, new[0]))
        out += ['        %s' % x for x in new[1:]]
        skip_to = addr + n
        pad_from = addr + n
        patched.append((addr, n))
        continue
    if Z88:
        raw = re.sub(r'L_([0-9A-F]{4})\b(?!\+)', r'$\1', ins).upper()
        r = rule(raw)
        if r:
            out.append('.L_%04X  %s' % (addr, r[0]))
            out += ['        %s' % x for x in r[1:]]
            patched.append((addr, None))
            continue
    out.append('.L_%04X  %s' % (addr, ins))
out.append('; end')
open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
if Z88:
    open(sys.argv[2] + '.patches', 'w').write('\n'.join('%04X %s' % (a, n or 0) for a, n in patched) + '\n')
    print(len(patched), 'patch sites')
