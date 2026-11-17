# prof.py PROFILE  - T-states per routine (game: skool entry points; glue: map labels)
import sys, re, bisect
SK='/home/claude/in/elite/elite-skoolkit-master/src/elite.skool'
MAP='/home/claude/work/elite/src/glue.map'
ent={}
lab=None
for ln in open(SK, encoding='latin1'):
    if ln.startswith('@label='): lab=ln[7:].strip(); continue
    m=re.match(r'^c\$([0-9A-F]{4})', ln)
    if m:
        ent[int(m.group(1),16)]=lab or ('c'+m.group(1)); lab=None
    elif re.match(r'^[bwtsiu]\$', ln): lab=None
for ln in open(MAP):
    m=re.match(r'^(\w+)\s+=\s+([0-9A-F]+), L', ln)
    if m:
        a=int(m.group(2),16)
        if 0x2000<=a<0x3E00: ent.setdefault(a, 'g:'+m.group(1).lower())
keys=sorted(ent)
tot={}; T=0
for ln in open(sys.argv[1]):
    k,v=ln.split(); k=int(k,16); v=int(v); T+=v
    if k>=65536: name='OZ seg%d'%(k-65536)
    else:
        i=bisect.bisect_right(keys,k)-1
        name=ent[keys[i]] if i>=0 else '?'
        if 0x2000<=k<0x3E00 and not name.startswith('g:'): name='g:?'
    tot[name]=tot.get(name,0)+v
for n,v in sorted(tot.items(), key=lambda x:-x[1])[:int(sys.argv[2]) if len(sys.argv)>2 else 30]:
    print('%5.1f%%  %s'%(100*v/T,n))
