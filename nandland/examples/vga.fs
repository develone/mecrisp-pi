\ -----------------------------------------------------------------------------
\   VGA signal generator for Nandland Go board
\   GPL3, Matthias Koch, Summer 2016
\   Colourful bitmap demo
\ -----------------------------------------------------------------------------

\ Pin constants
512 constant HSYNC
1024 constant VSYNC

\ Resolution timing constants
800 constant TOTAL_COLS
525 constant TOTAL_ROWS
640 constant ACTIVE_COLS
480 constant ACTIVE_ROWS

: nextirq ( cycles -- ) \ Trigger the next interrupt u cycles after the last one.
  ticks  \ Read current tick
  -       \ Subtract the cycles already elapsed
  4 -      \ Correction for the cycles neccessary to do this
  negate    \ Timer counts up to zero to trigger the interrupt
  $4000 io!  \ Prepare timer for the next irq
;

0 variable signal \ Signal which needs to be generated in time on the next interrupt
0 variable row     \ To count rows

\ Variables for a very small procedural graphics example: Colourful 16x16 Bitmap
create bitmap
\ 16 16 * cells allot  \ For an empty buffer...
8 base !  \ Nicely gives Blue-Green-Red values.
                                                                                                 \ Row
007 , 752 , 070 , 752 , 700 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \  0
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \  1
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \  2
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \  3
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \  4
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \  5
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \  6
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \  7
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \  8
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \  9
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \ 10
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \ 11
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \ 12
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \ 13
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 ,   \ 14
752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 752 , 770 ,   \ 15

decimal

: nop [ $6000 , ] ; \ Delay one cycle, will be inlined.

\ Interrupt handling is split into two handlers which are called in turn.

: vga-irq-active ( -- )
  signal @ $70 io! \ Write out prepared sync signals. Timing critical !

  \ Draw graphics here !
  row @ 80 336 within \ Rows are fixed because the row numbers are used as offset into the bitmap !
  if
    begin 100 ticks u< until       \ Move a bit into the scanline. You can change this value.
    row @ 80 - $FF0 and 2* bitmap + \ Row start address in bitmap buffer.
    \ Write out 16 pixels with the same count of cycles.
    ( pixeladdr ) 16 swap
    begin
      dup 2 + swap @ $10 io!
      swap 1 - swap over 0 =
    until
    drop drop
    nop nop  \ Adjust timing for the last pixel so that all have equal width
    0 $10 io! \ Back to black
  then

  \ Next row, if possible
  row @
    1 + dup TOTAL_ROWS <> and
    dup ACTIVE_ROWS u< VSYNC and signal !
  row !

  [ here ] 0 $0002 ! \ Address of the second handler will be inserted here as soon as the address is known.
  ACTIVE_COLS nextirq
;

: vga-irq-sync ( -- )
  signal @ $70 io!  \ Write out prepared sync signals. Timing critical !
  row @ ACTIVE_ROWS u< VSYNC and HSYNC or signal !
  ['] vga-irq-active 2/ $0002 !
  TOTAL_COLS ACTIVE_COLS - nextirq
;

' vga-irq-sync 2/ swap +! \ Insert the address of the second handler into the first

: demo ( -- )
  ['] vga-irq-active 2/ $0002 ! eint \ Start the interrupt chain
  3000 ms \ Show initial test pattern for a while
  begin
    2000 ms   \ Just a busy loop... As the interrupt handlers use a lions share of CPU time, it will be much longer.
    16 16 * 0 do random bitmap i cells + ! loop   \ Random is also quite slow under those circumstances...
  key? until
  dint \ Graphics off.
;

demo
