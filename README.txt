Elite for the Cambridge Z88
===========================

The ZX Spectrum Elite (Torus / Firebird, 1985) running its own Z80 code on an
expanded Z88, with a Z88 front end: 3D view, scanner and charts in a 256 x 64
map, instruments and all text in OZ windows, keyboard read
directly in flight, and the game's own sound on the Z88 speaker.

Card: elite.epr, 128K (works in OZvm and KLive). Needs an expanded Z88 with
64K of free RAM (four free 16K banks), OZ 3.0 or later (tested on OZ 3.0,
4.7 and 5). The application is "Elite" in the Index (#E). On a non-expanded
Z88 it says so and returns to the Index.
RAM application (no card needed): copy elite.app with elite.ap0-elite.ap3 into one
directory on the Z88 (OZ 4.6 or later, or the Installer popdown), mark elite.app in
the Filer and press INDEX; on OZ 5 elite-oz5.app alone does the same (compressed).
Installed, Elite takes 64K of RAM for itself and still copies the game into three
more banks to run, plus one for the sound (128K in all; the card version needs
only the 64K).  It finds its
game banks wherever the install put them.
Sound: the Spectrum's own sound code (the launch, laser, hits, explosions, the
missile-lock and freeze-menu beeps), unchanged except that it drives the Z88's
speaker bit instead of the Spectrum beeper.  It runs from a fourth RAM bank,
switched into segment 3 for each sound (src/sndp.asm, generated from the game by
tools/mksndp.py).  Pitch is about 6% lower than the Spectrum's (3.28 MHz against
3.5 MHz) apart from the two ROM beeps, which are timed to match.
The expanded check and the map routine (opengraphics, in src/glue.asm) are
Gunther Strube's, from Cosmic Payback, kept as he wrote them.

Keys (the Spectrum's; LEFT SHIFT = CAPS SHIFT, RIGHT SHIFT = SYMBOL SHIFT)
  Flight      S/X climb/dive, N/M roll, SPACE faster, RIGHT SHIFT slower
              1-4 front/rear/left/right view (docked: 1 launches)
  Weapons     A or 0 laser, T target missile, F fire it, U unarm,
              E ECM, W energy bomb, Q escape pod, C docking computer
              TAB forces an encounter (added for this version)
  Speed cap   - (minus) cycles the frame cap: 20 (default), 25, off, 12.5, 16.7
              frames a second; shown in flight under the messages.  On a
              fast emulator (OZvm at x5) it keeps combat at an even speed
              while each frame is drawn cleanly; a real Z88 is seldom faster
              than the cap - added for this version
  Condition   in flight, the box under the compass: G nothing about,
              A other ships about, R danger (hostile ship, or 2 energy
              banks empty) - added for this version
  Jumps       H hyperspace to the chart's selected system,
              G+H galactic hyperdrive
  Screens     I galactic chart, O short-range chart, P data on system,
              K market prices, L status, ENTER inventory
              docked: 2 buy, 3 sell, 4 equip
  Charts      N/M/S/X cursor, B home, D nearest system, R find by name;
              short-range chart: numbered systems, names listed on the left
              (under the cursor highlighted, * = within jump range)
  Freeze      LEFT SHIFT, then SPACE continue, 1 new game,
              S sound on, Q sound off (B D R Y K: control options)
  Commanders  docked, RIGHT SHIFT: 1 load, 2 save (<name>.elt), 3 back
  Leaving     INDEX suspends; ESC does not quit (KILL from the Index)

The same text is in the application's MENU/HELP.

Building: ./build.sh (mpm 2.2+, z88card 2.1+, Python 3, and the elite-skoolkit
elite.skool; paths at the top of build.sh).
