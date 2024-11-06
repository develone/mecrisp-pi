
\ -------------------------------------------------------------
\   A convenient buffer dump tool
\ -------------------------------------------------------------

: u.4 ( u -- ) 0 <# # # # # #> type ;
: u.2 ( u -- ) 0 <# # # #> type ;

0 variable dump-offset

: dump16 ( addr -- ) \ Print 16 bytes memory
  base @ >r hex
  \ $F bic
  dup dump-offset @ - .x ." :  "


  16 0 do
    dup i + c@ u.2 space \ Print data with 2 digits
        i $F and 7 = if 2 spaces then
  loop

  ."  | "

  16 0 do
    dup i + c@   dup 32 u>= over 127 u< and if emit else drop [char] . emit then
        i $F and 7 = if 2 spaces then
      loop

  drop

  ."  |" cr
  r> base !
;

: dumpbuf ( addr len -- ) \ Print a memory region
  over dump-offset !
  cr
  \ over 15 and if 16 + then \ One more line if not aligned on 16
  begin
    swap ( len addr )
    dup dump16
    16 + ( len addr+16 )
    swap 16 - ( addr+16 len-16 )
    dup 1 <
  until
  2drop
;

\ -------------------------------------------------------------
\   Warteroutinen und kleine Helferlein
\ -------------------------------------------------------------

: us ( u -- ) now 48 * delay ; \ For 48 MHz

: buffer: ( u -- ) create allot 0 foldable ;

\ -------------------------------------------------------------
\   Leitungen für die SPI-Schnittstelle definieren
\ -------------------------------------------------------------

$2050       constant SD-IN

$2060       constant SD-OUT
$2060 $1 +  constant SD-OUT-CLR
$2060 $2 +  constant SD-OUT-SET
$2060 $3 +  constant SD-OUT-XOR

: miso ( -- 0|1) SD-IN io@ 1 and ;

: sclk-high   2 SD-OUT-SET io! ;
: sclk-low    2 SD-OUT-CLR io! ;

: mosi-high   1 SD-OUT-SET io! ;
: mosi-low    1 SD-OUT-CLR io! ;

: -spi ( -- ) 4 SD-OUT-SET io! ; \ deselect SPI
: +spi ( -- ) 4 SD-OUT-CLR io! ; \ select SPI

: spi-init ( -- )
  -spi sclk-low mosi-high \ Reset state: /CS and DI=MOSI high, Clock low.
;

\ : card-detect? ( -- ? ) SD-IN io@ 2 and 0= ;

\ -------------------------------------------------------------
\   Kommunikation über die SPI-Leitungen
\ -------------------------------------------------------------

: >spi> ( c -- c )  \ bit-banged SPI, 8 bits
  8 0 do
    dup $80 and if mosi-high else mosi-low then
    sclk-high
    2* miso or
    sclk-low
  loop

  $FF and ;

\ Single byte transfers

: spi> ( -- c ) $FF >spi> ;  \ read byte from SPI
: >spi ( c -- ) >spi> drop ;  \ write byte to SPI

\ -------------------------------------------------------------
\   Kommunikation mit der SD-Karte
\ -------------------------------------------------------------

0 variable crc

: (sd-cmd) ( arg-low arg-high cmd -- u )
  2 us
  +spi

         $40 or >spi \ Command
  dup 8 rshift >spi \ Argument, 32 Bits, 31-24
               >spi \ 23-16
  dup  8 rshift >spi \ 15-8
                >spi \ 7-0
          crc @ >spi \ CRC-Feld, welches bei SPI-Schnittstelle nur für den ersten Befehl gebraucht und sonst ignoriert wird.

  begin $FF >spi> dup $80 and while drop repeat \ Auf die Antwort von der SD-Karte warten
;

: sd-cmd ( arg-low arg-high cmd -- u ) (sd-cmd) -spi ;

512 buffer: sd.buf

: sd-copy ( f n -- )
  swap
  begin $FE <> while $FF >spi> repeat
  0 do
    $FF >spi> sd.buf i + c!
  loop
  $FF dup >spi >spi
;

: sd-cmd-r3-r7 ( arg-low arg-high cmd -- u r-low r-high )
  (sd-cmd)

  spi> 8 lshift spi> or
  spi> 8 lshift spi> or
  swap

  -spi
;

: sd-cmd-r2 ( arg-low arg-high cmd -- u ) \ 17-Bytes lange Antwort, die ersten 16 davon im Puffer zuückgeben.
  (sd-cmd)
  16 sd-copy
  -spi
;

\ -------------------------------------------------------------
\   Größe der Karte bestimmen
\ -------------------------------------------------------------

0. 2variable #sd-blocks

: read-sd-size ( -- )  \ Return card size in 512-byte blocks

  0. 9 sd-cmd-r2 \ Send CSD

  \ 16-Bit-Low
  sd.buf 8 + c@ 8 lshift
  sd.buf 9 + c@ or

  \ 16-Bit-High
  sd.buf 7 + c@

  1. d+ 10 0 do d2* loop

  #sd-blocks 2! \ Zahl der Blöcke speichern
;

: sd-size ( -- u-low u-high ) #sd-blocks 2@ ;

\ -------------------------------------------------------------
\   Initialisierung
\ -------------------------------------------------------------

: sd-init ( -- )
  spi-init
  100 ms

  \ card-detect? not if ." Keine SD-Karte eingesteckt !" cr exit then

  10 0 do $FF >spi loop \ Mindestens 74 Taktpulse mit /CS high

  begin
    $95 crc ! 0. 0 sd-cmd  \ CMD0 go idle
  $01 = until

  1 crc !
  0. 59 sd-cmd drop \ CRC off

  ." SD-Card type: "
  $87 crc ! $1AA. 8 sd-cmd-r3-r7 .x .x dup .x 1 =

  if \ Ver 2.00 or later SD Memory Card

    begin
              0. 55 sd-cmd drop \ Es folgt einer der ACMD-Kommandos
      $40000000. 41 sd-cmd       \ ACMD41, mit HCS=1, da wir hier hohe Kapazitäten unterstützen
    0= until

    0. 58 sd-cmd-r3-r7 ." OCR: " .x .x .x \ Read OCR register. Das ist ein R3-Antworttyp, aber die haben die gleiche Länge.

    512. 16 sd-cmd ?dup if ." Wrong block size: " .x then \ Blockgröße auf 512 Bytes setzen

    read-sd-size

  else
    ." Ver 1.X SD Memory Card or not SD Memory Card" cr
    exit
  then

  ." with " sd-size .x .x
  ." blocks initialised." cr
;

\ -------------------------------------------------------------
\   Identifikation anzeigen
\ -------------------------------------------------------------

: show-sd-size ( -- )
  0. 9 sd-cmd-r2 \ Send CSD
  sd.buf 16 dumpbuf
;

: show-sd-id ( -- )
  0. 10 sd-cmd-r2 \ Send CID
  sd.buf 16 dumpbuf
;

\ -------------------------------------------------------------
\   Block lesen und schreiben
\ -------------------------------------------------------------

: sd-read ( block-low block-high -- ) \ Einen 512-Byte-Block von der SD-Karte lesen
  17 (sd-cmd) \ Single block read
  512 sd-copy
  -spi
;

: sd-write ( block-low block-high -- ) \ Einen 512-Byte-Block auf die SD-Karte schreiben
  24 (sd-cmd) drop \ Single block write
  $FE >spi \ DATA_START_BLOCK

  512 0 do
    sd.buf i + c@ >spi
  loop

  spi> drop spi> drop
  begin spi> $FF = until \ Warte, bis Busy-Flag verschwindet
  -spi
;

\ -------------------------------------------------------------
\   Alles löschen
\ -------------------------------------------------------------

: sd-erase ( -- )
             0. 32  sd-cmd  .x \ Startblock fürs Löschen
  sd-size 1. d- 33  sd-cmd  .x \   Endblock

        0. 38 (sd-cmd) .x \ Löschen ausführen
  begin spi> $FF = until \ Warte, bis Busy-Flag verschwindet
  -spi
;

\ -------------------------------------------------------------
\   Ausprobieren
\ -------------------------------------------------------------

\ sd-init
: sd-view ( u -- ) sd-read sd.buf 512 dumpbuf ;
