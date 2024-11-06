
\ #######   MEMORY   ##########################################

: unused
    $3C00 here -
;

\ #######   IO   ##############################################

\  ------------------------------------------------------------
\    Useful Low-Level IO definitions
\  ------------------------------------------------------------
\
\    Addr  Bit READ            WRITE
\
\    0001  0   Port A in
\    0002  1   Port A out      Port A out
\    0004  2   Port A dir      Port A dir
\    0008  3   misc.out        misc.out
\
\    0010  4   Port B in
\    0020  5   Port B out      Port B out
\    0040  6   Port B dir      Port B dir
\    0080  7   SRAM read       SRAM write
\
\    0100  8   Port C in
\    0200  9   Port C out      Port C out
\    0400  10  Port C dir      Port C dir
\    0800  11  SRAM addr       SRAM addr
\
\    1000  12  UART RX         UART TX
\    2000  13  misc.in
\    4000  14  ticks           set ticks
\    8000  15
\
\
\ Contents of misc.out and misc.in:
\
\  Bitmask Bit  misc.out        misc.in
\
\    0001    0  SPI CS          UART Ready to Transmit
\    0002    1  SPI MOSI        UART Character received
\    0004    2  SPI SCK         SPI MISO
\    0008    3  Red LED         Random
\    0010    4  Green LED
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

: ms   ( u -- ) 0 do 2400 0 do loop loop ; \ 10 cycles per loop run. 1 ms * 24 MHz / 10
: leds ( x -- ) 3 lshift 8 io@ 7 and or 8 io! ;

: now   ( -- ) 0 $4000 io! ;
: ticks ( -- u ) $4000 io@ ;
: delay ( u -- ) begin dup ticks u< until drop ;

: nextirq ( cycles -- ) \ Trigger the next interrupt u cycles after the last one.
  $4000 io@  \ Read current tick
  -           \ Subtract the cycles already elapsed
  8 -          \ Correction for the cycles neccessary to do this
  invert        \ Timer counts up to zero to trigger the interrupt
  $4000 io!      \ Prepare timer for the next irq
;

: randombit ( -- 0 | 1 ) $2000 io@ 3 rshift 1 and ;
: random ( -- x ) 0  16 0 do 2* randombit or 100 0 do loop loop ;

: sram@ ( addr -- x ) $800 io! $80 io@ ;
: sram! ( x addr -- ) $800 io! $80 io! ;


\ #######   Flash   ###########################################

\ Save memory image to SPI Flash

: waitspi ( -- )
  begin
    $05 >spi \ Read status register 1
    spi> not 1 and
    idle
  until
;

: spiwe ( -- )
    $06 >spi \ Write enable
    idle
;

: erase ( sector -- )
  dup 1 u> if \ Never overwrite bitstream in sector 0 and 1.
    idle
    spiwe
    $D8 >spi \ Sector erase
        >spi  \ Sector number
    $00 >spi   \ Address high
    $00 >spi    \ Address low
    idle
    waitspi
  else drop then
;

: save ( sector -- )
  dup 1 u> if \ Never overwrite bitstream in sector 0 and 1.

    dup erase
    0      \ 8 kb in 256 byte pages
    begin
      spiwe

      $02 >spi \ Page program, 256 Bytes
     over >spi  \ Sector number
     dup
 8 rshift >spi   \ Address high
      $00 >spi    \ Address low

      begin
        dup c@ >spi
        1+
        dup $FF and 0=
      until

      idle
      waitspi

      dup $3C00 =
    until
    2drop

  else drop then \ Bitstream protection
;
