
\ #######   MEMORY   ##########################################

: unused
    $4000 here -
;

\ #######   IO   ##############################################

\  ------------------------------------------------------------
\    Useful Low-Level IO definitions
\  ------------------------------------------------------------
\
\    Addr  Bit READ            WRITE
\
\    0001  0   Port A IN
\    0002  1   Port A OUT      Port A OUT
\    0004  2   Port A DIR      Port A DIR
\    0008  3   misc.out        misc.out
\
\    0010  4   Port B IN
\    0020  5   Port B OUT      Port B OUT
\    0040  6   Port B DIR      Port B DIR
\    0080  7   SRAM read       SRAM write
\
\    0100  8   Port C IN
\    0200  9   Port C OUT      Port C OUT
\    0400  10  Port C DIR      Port C DIR
\    0800  11  SRAM addr low   SRAM addr low
\
\    1000  12  UART RX         UART TX
\    2000  13  misc.in
\    4000  14  ticks           set ticks
\    8000  15  SRAM addr high  SRAM addr high
\
\
\ Contents of misc.out and misc.in:
\
\  Bitmask Bit  misc.out        misc.in
\
\    0001    0  Red LED 1       UART Ready to Transmit
\    0002    1  Yellow LED 2    UART Character received
\    0004    2  Green LED 3     Random
\    0008    3  Blue LED 4
\    0010    4
\    0020    5
\    0040    6
\    0080    7
\    0100    8
\    0200    9
\    0400   10
\    0800   11
\    1000   12
\    2000   13
\    4000   14
\    8000   15
\

: ms   ( u -- ) 0 do 2500 0 do loop loop ; \ 10 cycles per loop run. 1 ms * 25 MHz / 10
: leds ( x -- ) 8 io! ;

: now   ( -- ) 0 $4000 io! ;
: ticks ( -- u ) $4000 io@ ;
: delay ( u -- ) begin dup ticks u< until drop ;

: randombit ( -- 0 | 1 ) $2000 io@ 4 and 2/ 2/ ;
: random ( -- x ) 0  16 0 do 2* randombit or 100 0 do loop loop ;
