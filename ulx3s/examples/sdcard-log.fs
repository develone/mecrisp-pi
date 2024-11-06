
\ -------------------------------------------------------------
\   Log in der SD-Karte
\ -------------------------------------------------------------

\ Von hinten aus den ersten freien Block auf der SD-Karte finden.

\ Idee:
\ Prüfe die Mitte zwischen 0 und Ende auf Freiheit.
\ Falls Frei: Vordere Hälfte. Falls Unfrei: Hintere Hälfte.

0. 2variable log-position
0. 2variable suche-anfang
0. 2variable suche-ende

: block-leer? ( d-block# -- ? )
  sd-read
  $FF
  512 0 do
    sd.buf i + c@ and
  loop
  $FF =
;

: log-init ( -- )
  sd-init

  0.      suche-anfang 2!
  sd-size suche-ende   2!

  begin
    suche-anfang 2@   \ 2dup ud.
    suche-ende   2@   \ 2dup ud. cr
    d<>
  while
    suche-ende 2@ suche-anfang 2@ d- dshr suche-anfang 2@ d+

     \ ." Leerprobe: " 2dup ud. cr

    2dup block-leer?
    if
      suche-ende 2!
    else
      1. d+             \ Dieser Block war ja gerade belegt.
      suche-anfang 2!
    then
  repeat

  suche-anfang 2@ log-position 2!

  ." Schreibposition des Logs: "
  log-position 2@ .x .x
  cr
;

512 buffer: log.buf

: log-full ( -- ? ) sd-size log-position 2@ d= ;

: log-add ( -- )
  log-full
  if
    ." Log voll."
  else
    log.buf sd.buf 512 move
    log-position 2@ sd-write
    log-position 2@ 1. d+ log-position 2!
  then
;
