
\ #######   MEMORY   ##########################################

: unused
    $4000 here -
;

\ #######   IO   ##############################################

\  ------------------------------------------------------------
\    Useful Low-Level IO definitions
\  ------------------------------------------------------------
\
\     Addr  Bit READ            WRITE
\
\     0001  0   Port A in
\     0002  1   Port A out      Port A out
\     0004  2   Port A dir      Port A dir
\     0008  3   misc.out        misc.out
\
\     0010  4   Port B in
\     0020  5   Port B out      Port B out
\     0040  6   Port B dir      Port B dir
\     0080  7
\
\     0100  8   Port C in
\     0200  9   Port C out      Port C out
\     0400  10  Port C dir      Port C dir
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
\    0008    3  IrDA-TXD        IrDA-RXD
\    0010    4  IrDA-Sleep      RTS
\    0020    5  CTS             Random
\    0040    6  Red LED
\    0080    7  Red LED
\    0100    8  Red LED
\    0200    9  Red LED
\    0400   10  Red LED
\    0800   11  Red LED
\    1000   12  Red LED
\    2000   13  Red LED
\    4000   14
\    8000   15
\

: ms   ( u -- ) 0 do 4800 0 do loop loop ; \ 10 cycles per loop run. 1 ms * 48 MHz / 10
: leds ( x -- ) 6 lshift 8 io@ $3f and or 8 io! ;

: now   ( -- ) 0 $4000 io! ;
: ticks ( -- u ) $4000 io@ ;
: delay ( u -- ) begin dup ticks u< until drop ;

: randombit ( -- 0 | 1 ) $2000 io@ $20 and 5 rshift ;
: random ( -- x ) 0  16 0 do 2* randombit or 100 0 do loop loop ;


\ #######   Flash   ###########################################

\ Save memory image to SPI Flash

: waitspi ( -- )
  begin
    $70 >spi \ Read Flag status register
    spi> $80 and
    idle
  until
;

: spiwe ( -- )
    $06 >spi \ Write enable
    idle
;

: erase ( sector -- )
  dup 2 u> if \ Never overwrite bitstream !
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
  dup 2 u> if \ Never overwrite bitstream !

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

      dup $4000 =
    until
    2drop

  else drop then \ Bitstream protection
;
