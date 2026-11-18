# modularize.py - one-off: split the glue (glue.asm + included view/instr/text.asm) into
# mpm modules: shared constants -> elite.inc, cross-module labels -> XDEF / XREF.
import re, sys
D = sys.argv[1]
MODS = ['glue', 'view', 'instr', 'text']
src = {m: open('%s/%s.asm' % (D, m)).read().split('\n') for m in MODS}
ident = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
def code(ln):
    out = ''; q = None
    for ch in ln:
        if q:
            if ch == q: q = None
            continue
        if ch in '"\'':
            q = ch; continue
        if ch == ';': break
        out += ch
    return out
defs = {}; consts = []; cnames = set()
for m in MODS:
    keep = []
    for ln in src[m]:
        s = ln.strip()
        if re.match(r'^defc\b', s, re.I):
            n = ident.findall(s[4:])[0].lower()
            if n not in cnames:
                cnames.add(n); consts.append(ln.strip() if ln.startswith(' ') else ln)
            continue
        if re.match(r'^\s*include\s+"(view|instr|text)\.asm"', ln):
            continue
        keep.append(ln)
        mm = re.match(r'^\.?([A-Za-z_][A-Za-z0-9_]*):?(\s|$)', ln)
        if mm and (ln.startswith('.') or re.match(r'^[A-Za-z_][A-Za-z0-9_]*:', ln)):
            defs.setdefault(m, set()).add(mm.group(1).lower())
    src[m] = keep
owner = {l: m for m in MODS for l in defs.get(m, ())}
xref = {m: set() for m in MODS}; xdef = {m: set() for m in MODS}
for m in MODS:
    for ln in src[m]:
        c = code(ln)
        c = re.sub(r'^\.?[A-Za-z_][A-Za-z0-9_]*:', '', c)
        for t in ident.findall(c):
            t = t.lower()
            if t in owner and owner[t] != m:
                xref[m].add(t); xdef[owner[t]].add(t)
open('%s/elite.inc' % D, 'w').write('; elite.inc - constants shared by the glue modules (addresses of variables and of\n; the game\'s own routines and data)\n' + '\n'.join(consts) + '\n')
OZDEFS = ['stdio.def', 'map.def', 'memory.def', 'error.def', 'director.def']
for m in MODS:
    out = []; head_done = False
    lines = src[m]
    hdr = ['        module %s' % m]
    if m != 'glue':
        hdr += ['        include "%s"' % d for d in OZDEFS]
    hdr += ['        include "elite.inc"']
    for nm in sorted(xdef[m]): hdr.append('        xdef    %s' % nm)
    for nm in sorted(xref[m]): hdr.append('        xref    %s' % nm)
    if m == 'glue':
        for ln in lines:
            if re.match(r'^\s*module\s+glue', ln):
                continue
            if not head_done and re.match(r'^\s*org\s', ln, re.I):
                out += hdr[1:] if False else []
                out.append(ln); head_done = True
                continue
            out.append(ln)
        # module line + includes go before the OZ includes at the top
        i = next(k for k, ln in enumerate(out) if re.match(r'^\s*include\s+"stdio.def"', ln))
        out[i:i] = ['        module glue']
        j = next(k for k, ln in enumerate(out) if re.match(r'^\s*org\s', ln, re.I))
        out[j+1:j+1] = hdr[1:]
    else:
        # keep the leading comment block, then the header
        k = 0                                   # after the opening comment block
        while k < len(lines) and lines[k].startswith(';'):
            k += 1
        out = lines[:k] + hdr + [''] + lines[k:]
    open('%s/%s.asm' % (D, m), 'w').write('\n'.join(out).rstrip('\n') + '\n')
    print(m, 'xdef', len(xdef[m]), 'xref', len(xref[m]))
open('%s/glue.prj' % D, 'w').write('\n'.join('%s.asm' % m for m in MODS) + '\n')
