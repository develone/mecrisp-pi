
\ -----------------------------------------------------------------------------
\   Blinky with darkness measurement.
\   Connect a clear LED with anode to 0+ and cathode to 1+
\ -----------------------------------------------------------------------------

 1 constant Anode
 2 constant Kathode

: darkness ( -- )

  begin

  Anode Kathode or p1dir io!
  Anode            p1out io!

  100 ms

        Kathode    p1out io!
  3 0 do loop
  Anode            p1dir io!

  begin p1in io@ Kathode and 0= until

  key? until
;
