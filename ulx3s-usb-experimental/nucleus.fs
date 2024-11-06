
  include ../common-forth/nucleus-16kb-dualport.fs

\ -----------------------------------------------------------------------------
\  SPI flash memory access
\ -----------------------------------------------------------------------------

\ SPI Flash tools and loader

header idle
: idle
    d# 1 h# 20F0 io!
;

: spixbit
    dup 0< d# 2 and        \ extract MS bit
    dup h# 20F0 io!         \ lower SCK, update MOSI
    d# 4 + h# 20F0 io!       \ raise SCK
    2*                        \ next bit
    h# 20F0 io@ d# 1 and +     \ read MISO, accumulate
;

header spix
: spix
    d# 8 lshift
    spixbit spixbit spixbit spixbit
    spixbit spixbit spixbit spixbit
;

header >spi
: >spi      spix drop ;

header spi>
: spi>      d# 0 spix ;


header load
: load ( sector -- )

  idle

  h# AB >spi  \ Release from Deep Power Down Mode
  h# 00 >spi
  h# 00 >spi
  h# 00 >spi
  h# 00 >spi   \ Read Signature

  idle

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

  init @ ?dup if execute then \ The freshly loaded image might have init set

  quit
;

\ -----------------------------------------------------------------------------
\  Boot here
\ -----------------------------------------------------------------------------

: main
    dint     \ Disable interrupts
    welcome   \ Emit welcome message

    h# 2020 io@
    if
      quit \ Bypass loading if any button is pressed during Reset
    else
      d# 30 load \ Try to load image from sector 30 if available. Bitstream is in sectors 0 to 29.
    then
;

meta
    link @ t' forth tw!
    there  t' dp tw!
target
