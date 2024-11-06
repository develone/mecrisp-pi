
  include ../common-forth/nucleus-16kb-quickstore.fs

\ -----------------------------------------------------------------------------
\  SPI flash memory access
\ -----------------------------------------------------------------------------

\ SPI Flash tools and loader

header idle
: idle
    d# 1 d# 8 io!
;

: spixbit
    dup 0< d# 2 and        \ extract MS bit
    dup d# 8 io!            \ lower SCK, update MOSI
    d# 4 + d# 8 io!          \ raise SCK
    2*                        \ next bit
    h# 2000 io@ d# 4 and +     \ read MISO, accumulate
;

header spix
: spix
    d# 8 lshift
    spixbit spixbit spixbit spixbit
    spixbit spixbit spixbit spixbit
    2/ 2/
;

header >spi
: >spi      spix drop ;

header spi>
: spi>      d# 0 spix ;


header load
: load ( sector -- )

  h# 03 >spi \ Read command
        >spi  \ Sector number
  h# 00 >spi   \ Address high
  h# 00 >spi    \ Address low

  spi> spi> d# 8 lshift or

  dup h# FFFF <> \ Execution starts at address 0, there always will be a valid opcode.
  if d# 0 !       \ $FFFF denotes an empty sector that should not be loaded.

    d# 2
    begin
      spi> spi> d# 8 lshift or over !
      d# 2 +
      dup h# 4000 =
    until

  then

  drop
  idle

  init @i ?dup if execute then \ The freshly loaded image might have init set

  quit
;

\ -----------------------------------------------------------------------------
\  Boot here
\ -----------------------------------------------------------------------------

: main
    dint     \ Disable interrupts
    welcome   \ Emit welcome message

    d# 6 load \ Try to load image from sector 3 if available. Bitstream is in sectors 0, 1, 2.
    \ quit
;

meta
    link @ t' forth tw!
    there  t' dp tw!
target
