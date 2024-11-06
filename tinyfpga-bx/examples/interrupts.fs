
\ An example for using the ticks counter overflow interrupt on Mecrisp-Ice

\ Interrupt frequency = 48 MHz / 2^16 = 737.42 Hz.

0 variable seconds
0 variable prescaler

: interrupt ( -- )
  1 prescaler +!
  prescaler @ 737 u>=
  if
    0 prescaler !
    1 seconds +!
    1 seconds @ 7 and lshift leds
  then
;

' interrupt 1 rshift $0002 ! \ Generate JMP opcode for vector location
eint

: s seconds @ u. ;

\ Additional code from Mathias for exactly timed interrupts..

0. 2variable (ms)

: interrupt ( -- )
  (ms) 2@ 1. d+ (ms) 2!
  cycles/ms nextirq
;

: time ( -- ud )
  begin
    (ms) @        \ High part
    (ms) cell+ @  \  Low part
    over ( high low high )
    (ms) @ ( high low high high* )
    =
  until
  swap
;

' interrupt 1 rshift $0002 ! \ Generate JMP opcode for vector location

eint
