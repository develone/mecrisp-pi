
\ -------------------------------------------------------------
\   Pin interrupt example
\ -------------------------------------------------------------

$0101 constant P1IN    \ Input
$0102 constant P1OUT   \ Output
$0104 constant P1DIR   \ Direction
$0110 constant P1IFG   \ Interrupt Flag
$0120 constant P1IES   \ Interrupt Edge Select
$0140 constant P1IE    \ Interrupt Enable

$0201 constant P2IN
$0202 constant P2OUT
$0204 constant P2DIR
$0210 constant P2IFG
$0220 constant P2IES
$0240 constant P2IE

$0401 constant P3IN
$0402 constant P3OUT
$0404 constant P3DIR
$0410 constant P3IFG
$0420 constant P3IES
$0440 constant P3IE

$8001 constant IRQ-CAUSE
$8002 constant IRQ-ENABLE

\ Bits on Port 3:

\ 0   1  Led West
\ 1   2  Led East
\ 2   4  Led South
\ 3   8    Button 2
\ 4  16  Led Middle
\ 5  32  Led North
\ 6  64    Button 1
\ 7 128    Button 3

\ -------------------------------------------------------------

\ Ticks interrupt frequency = 24 MHz / 2^16 = 366.21 Hz.

0 variable seconds
0 variable prescaler

: interrupt ( -- )

  IRQ-CAUSE io@

  dup $0001 and \ Sticky timer interrupt
  if
    $0001 $8001 io! \ Clear the sticky interrupt cause bit

    1 prescaler +!
    prescaler @ 366 u>=
    if
      0 prescaler !
      1 seconds +!
        seconds @ leds
    then
  then

  $0400 and \ Port 3 interrupt
  if
    P3IFG io@ \ Which pin triggered this ?

    dup  64 and if      1 2 or       P3OUT io! then  \ West and East
    dup   8 and if 32 4     or       P3OUT io! then  \ North and South
        128 and if 32 4 1 2 or or or P3OUT io! then  \ All four directions

    0 P3IFG io! \ Clear all pending pin interrupts on port 3
  then
;

\ -------------------------------------------------------------

: blinky ( -- )

  %00110111 P3DIR io! \ Set LEDs as outputs, buttons as inputs

  \ Interrupts on rising edge on P3.3, P3.6 and P3.7
  0 P3IES io! \ Interrupt Edge Select
  128 64 8 or or P3IE io! \ Interrupt Enable

  \ Enable interrupts for port 3 and sticky timer
  $0401 IRQ-ENABLE io!

  ['] interrupt 1 rshift $0002 ! \ Generate JMP opcode for vector location
  eint
;

\ -------------------------------------------------------------

blinky

