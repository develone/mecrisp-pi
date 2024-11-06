
: unused ( -- u ) $4000 here - ;

: ticks ( -- u ) $4000 io@ ;

: nextirq ( cycles -- ) \ Trigger the next interrupt u cycles after the last one.
  ticks  \ Read current tick
  -       \ Subtract the cycles already elapsed
  4 -      \ Correction for the cycles neccessary to do this
  negate    \ Timer counts up to zero to trigger the interrupt
  $4000 io!  \ Prepare timer for the next irq
;

