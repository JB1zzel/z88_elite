/* fasttest.c - run each original routine and its fast.asm version on the same inputs,
   compare every register and flag.  Usage: fasttest elite_ref.bin fast.bin */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "Z80.h"
static byte M[65536];
void WrZ80(word A, byte V){ M[A]=V; }
byte RdZ80(word A){ return M[A]; }
void OutZ80(word P, byte V){}
byte InZ80(word P){ return 0xFF; }
void PatchZ80(Z80 *R){}
word LoopZ80(Z80 *R){ return INT_QUIT; }
static Z80 R; static word g_stop=0;
typedef struct { word af,bc,de,hl; long t; } St;
static St run(word pc, word af, word bc, word de, word hl){
  memset(&R,0,sizeof R); ResetZ80(&R);
  R.AF.W=af; R.BC.W=bc; R.DE.W=de; R.HL.W=hl; R.SP.W=0xFFF0; M[0xFFF0]=0; M[0xFFF1]=0;
  R.PC.W=pc; R.IFF=0; long t=0;
  while(R.PC.W && R.PC.W!=g_stop){ t+=1-ExecZ80(&R,1); if(t>100000){printf("runaway %04X\n",pc);exit(1);} }
  St s={R.AF.W,R.BC.W,R.DE.W,R.HL.W,t}; return s;
}
static long n, bad, to, tf;
static void cmp(const char*nm, word po, word pf, word af, word bc, word de, word hl){
  St a=run(po,af,bc,de,hl), b=run(pf,af,bc,de,hl); n++; to+=a.t; tf+=b.t;
  if(((a.af^b.af)&0xFFD7)||a.bc!=b.bc||a.de!=b.de||a.hl!=b.hl){
    if(bad++<10) printf("%s MISMATCH in AF%04X BC%04X DE%04X HL%04X: orig %04X %04X %04X %04X fast %04X %04X %04X %04X\n",
      nm,af,bc,de,hl,a.af,a.bc,a.de,a.hl,b.af,b.bc,b.de,b.hl);
  }
}
static void report(const char*nm){ printf("%-12s %ld cases, %ld mismatches, T orig %.1f fast %.1f (%.0f%%)\n",nm,n,bad,(double)to/n,(double)tf/n,100.0*tf/to); n=bad=to=tf=0; }
static unsigned long long rs=88172645463325252ULL;
static unsigned rnd(){ rs^=rs<<13; rs^=rs>>7; rs^=rs<<17; return (unsigned)rs; }
int main(int c, char**v){
  FILE*f=fopen(v[1],"rb"); fread(M+0x4000,1,49152,f); fclose(f);
  static byte fb[1024]; f=fopen(v[2],"rb"); int k=fread(fb,1,1024,f); fclose(f);
  /* mpm binary: from org, check */
  memcpy(M+0xB047,fb,k);
  word FHL=strtoul(v[3],0,16), F8=strtoul(v[4],0,16), FC=strtoul(v[5],0,16), FD=strtoul(v[6],0,16);
  /* div_hl_a_de: random + structured */
  for(long i=0;i<4000000;i++){ unsigned r=rnd(), q=rnd();
    word hl=r&0xFFFF, de=r>>16; byte a=q;
    if(i&1) hl%= (de?de:1);            /* the usual case: HL < DE */
    if((i&7)==2) de|=0x8000;
    cmp("div_hl_a_de",0xAFA8,FHL,(a<<8)|(q>>8&0xFF),0x1234,de,hl); }
  report("div_hl_a_de");
  /* AC8B: A, E, B exhaustive, C=$FE */
  for(unsigned a=0;a<256;a++) for(unsigned e=0;e<256;e++) for(unsigned b=0;b<256;b++)
    cmp("ac8b",0xAC8B,F8,(a<<8)|0x55,(b<<8)|0xFE,0x3300|e,0x4455);
  report("ac8b");
  /* 7CD5: A, L, B exhaustive, D preset */
  for(unsigned a=0;a<256;a++) for(unsigned l=0;l<256;l++) for(unsigned b=0;b<256;b++)
    cmp("div_coord",0x7CD5,FC,(a<<8)|0xAA,(b<<8)|0x77,0x9900|(a^b),0x6600|l);
  report("div_coord");
  for(unsigned a=0;a<256;a++) for(unsigned b=0;b<256;b++) for(unsigned fl=0;fl<2;fl++)
    cmp("7cfb",0x7CFB,FD,(a<<8)|(fl?0xFF:0),(b<<8)|0x11,0x2222,0x3333);
  report("7cfb");
  if(c>7){ /* token search: stop when the print loop is reached */
    static byte f2[512]; f=fopen(v[7],"rb"); int k2=fread(f2,1,512,f); fclose(f); memcpy(M+0xB349,f2,k2);
    word FT=strtoul(v[8],0,16); g_stop=0xD48E;
    for(unsigned a=0;a<256;a++) for(unsigned x=0;x<4;x++)
      cmp("token",0xD45F,FT,(a<<8)|(x*0x41),0x1111*x+0x0F0F,0x2200|(x*7),0x5A5A);
    report("token");
  }
  return 0;
}
