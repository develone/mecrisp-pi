
\ A small example how to use the LEDs and buttons on the breakaway section

$0401 constant P3IN
$0402 constant P3OUT
$0404 constant P3DIR

\ Bits on Port 3:

\ 0   1  Led West
\ 1   2  Led East
\ 2   4  Led South
\ 3   8    Button 2
\ 4  16  Led Middle
\ 5  32  Led North
\ 6  64    Button 1
\ 7 128    Button 3

: inout ( -- )

  %00110111 P3DIR io! \ Set LEDs as outputs, buttons as inputs

  begin
    P3IN io@ \ Read buttons
    64 8 128 or or and \ Mask the button bits

    case
      64 of  1 2 or P3OUT io! endof \ West and East
       8 of 32 4 or P3OUT io! endof \ North and South
     128 of 32 4 1 2 or or or P3OUT io! endof \ All four directions

      16 P3OUT io!  \ Default: Red LED in the middle
    endcase

  key? until

  0 P3DIR io! \ All pins as inputs
;


: blinky ( -- )

  %00110111 P3DIR io! \ Set LEDs as outputs, buttons as inputs

  begin
    1 P3OUT io! 200 ms
   32 P3OUT io! 200 ms
    2 P3OUT io! 200 ms
    4 P3OUT io! 200 ms
  key? until

  0 P3DIR io! \ All pins as inputs
;
