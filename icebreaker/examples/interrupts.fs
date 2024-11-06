
\ An example for using the ticks counter overflow interrupt on Mecrisp-Ice

\ Interrupt frequency = 24 MHz / 2^16 = 366.21 Hz.

0 variable seconds
0 variable prescaler

: interrupt ( -- )
  1 prescaler +!
  prescaler @ 366 u>=
  if
    0 prescaler !
    1 seconds +!
      seconds @ leds
  then
;

' interrupt 1 rshift $0002 ! \ Generate JMP opcode for vector location
eint

: s seconds @ u. ;
