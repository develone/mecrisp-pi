
\ -------------------------------------------------------------
\   Pin interrupt example
\ -------------------------------------------------------------

\ Ticks interrupt frequency = 25 MHz / 2^16 = 381.47 Hz.

0 variable seconds
0 variable prescaler

: interrupt ( -- )

  IRQ-CAUSE io@

  dup $0001 and \ Sticky timer interrupt
  if
    $0001 IRQ-CAUSE 1 + io! \ Clear the sticky interrupt cause bit
                            \ using _C_lear +1, _S_et +2, _T_oggle +3 (cst) capabilities
    1 prescaler +!
    prescaler @ 381 u>=
    if
      0 prescaler !
      1 seconds +!
      1 seconds @ 7 and lshift leds
    then
  then

  $0100 and \ Port 1 interrupt
  if
    P1IFG io@ \ Which pin triggered this ?

    dup 1 14 lshift and if $F0 leds then \ Fire 1
        1 15 lshift and if $0F leds then \ Fire 2

    0 P1IFG io! \ Clear all pending pin interrupts on port 1
  then
;

\ -------------------------------------------------------------

: blinky ( -- )

  \ Interrupts on rising edge on P1.14 and P1.15

  0 P1IES io! \ Interrupt Edge Select
  1 14 lshift 1 15 lshift or P1IE io! \ Interrupt Enable

  \ Enable interrupts for port 1 and sticky timer
  $0101 IRQ-ENABLE io!

  ['] interrupt 1 rshift $0002 ! \ Generate JMP opcode for vector location
  eint
;

\ -------------------------------------------------------------

blinky

