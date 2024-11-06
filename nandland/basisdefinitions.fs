
\ #######   MEMORY   ##########################################

: unused
    $2000 here -
;

\ #######   IO   ##############################################

\  ------------------------------------------------------------
\    Useful Low-Level IO definitions
\  ------------------------------------------------------------
\
\     Addr  Bit READ            WRITE
\
\     0001  0   PMOD in
\     0002  1   PMOD out        PMOD out
\     0004  2   PMOD dir        PMOD dir
\     0008  3   misc.out        misc.out
\
\     0010  4
\     0020  5
\     0040  6
\     0080  7   Segments        Segments
\
\     0100  8
\     0200  9
\     0400  10
\     0800  11
\
\     1000  12  UART RX         UART TX
\     2000  13  misc.in
\     4000  14  ticks           set ticks
\     8000  15
\
\
\ Contents of misc.out and misc.in:
\
\  Bitmask Bit  misc.out        misc.in
\
\    0001    0  SPI CS          UART Ready to Transmit
\    0002    1  SPI MOSI        UART Character received
\    0004    2  SPI SCK         SPI MISO
\    0008    3  Red LED 1       Random
\    0010    4  Red LED 2       S1
\    0020    5  Red LED 3       S2
\    0040    6  Red LED 4       S3
\

: ms   ( u -- ) 0 do 2273 0 do loop loop ; \ 11 cycles per loop run. 1 ms * 25 MHz / 11 = 2272.7
: leds ( x -- ) 3 lshift 8 io@ 7 and or 8 io! ;

: now   ( -- ) 0 $4000 io! ;
: ticks ( -- u ) $4000 io@ ;
: delay ( u -- ) begin dup ticks u< until drop ;

: randombit ( -- 0 | 1 ) $2000 io@ 8 and 3 rshift ;
: random ( -- x ) 0  16 0 do 2* randombit or 100 0 do loop loop ;


\ #######   Flash   ###########################################

\ Save memory image to SPI Flash

\ Four sectors only on Nandland Go:
\ 0: Bitstream
\ 1: Autoload
\ 2:  Free
\ 3:  Free

: waitspi ( -- )
  begin
    $05 >spi \ Read Flag status register
    spi> $01 and 0= \ WIP: Write in Progress.
    idle
  until
;

: spiwe ( -- )
    $06 >spi \ Write enable
    idle
;

: erase ( sector -- )
  3 and  \ Four sectors available only
  ?dup if \ Never overwrite bitstream !
    spiwe
     $D8 >spi \ Sector erase
  dup 2/ >spi  \ Sector number
7 lshift >spi   \ Address high
     $00 >spi    \ Address low
    idle
    waitspi
  then
;

: save ( sector -- )
  3 and  \ Four sectors available only
  ?dup if \ Never overwrite bitstream !

    dup erase

    0      \ 8 kb in 128 byte pages
    begin ( sector address )
      spiwe

      $02 >spi \ Page program, 128 Bytes

      over 2/                         >spi  \ Sector number
      over 7 lshift over 8 rshift or  >spi   \ Address high
      dup                             >spi    \ Address low

      begin
        dup c@ >spi
        1+
        dup $7F and 0=
      until

      idle
      waitspi

      dup $2000 =
    until
    2drop

  then \ Bitstream protection
;
