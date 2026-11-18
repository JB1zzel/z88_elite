Elite for the Cambridge Z88
===========================

The ZX Spectrum Elite (Torus / Firebird, 1985) running its own Z80 code on an
expanded Z88, with a Z88 front end: 3D view, scanner and charts in a 256 x 64
map (240 x 64 on OZ 4 and earlier, which show no wider map: 8 pixels are lost
at either side), instruments and all text in OZ windows, keyboard read
directly in flight, effects on the Z88 speaker.

Card: elite.epr, 128K (works in OZvm and KLive). Needs an expanded Z88 with
48K of free RAM (three free 16K banks), OZ 3.0 or later (tested on OZ 3.0,
4.7 and 5). The application is "Elite" in the Index (#E).

Keys (the Spectrum's; LEFT SHIFT = CAPS SHIFT, RIGHT SHIFT = SYMBOL SHIFT)
  Flight      S/X climb/dive, N/M roll, SPACE faster, RIGHT SHIFT slower
              1-4 front/rear/left/right view (docked: 1 launches)
  Weapons     A or 0 laser, T target missile, F fire it, U unarm,
              E ECM, W energy bomb, Q escape pod, C docking computer
              TAB forces an encounter (added for this version)
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
