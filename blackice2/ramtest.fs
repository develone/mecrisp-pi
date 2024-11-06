\ SRAM checker

: ramtest-addr16 ( -- )
  cr cr
  ." High memory address: " $8000 io@ .x cr

  ." Data Bus" cr

  $FFFF 0 do
    i $800 io!  \ Set low memory address

    16 0 do     \ Try all 16 data lines
      1 i lshift $80 io! \ Write to SRAM and read value back.
                 $80 io@ 1 i lshift <> if ." Data error: " j .x ." : " 1 i lshift .x $80 io@ .x
                                                                       1 i lshift $80 io@ xor .x cr then
    loop

  loop

  ." Fill with own address" cr

  $FFFF 0 do  \ Fill each location with its own address
    i $800 io!  \ Set low memory address
    i $80  io!  \ Set content to address
  loop

  ." Address bus" cr

  $16 0 do  \ Does it read back correctly ?
    1 i lshift $800 io!  \ Set low memory address
      $80  io@ 1 i lshift <> if ." Addr error: " 1 i lshift .x $80 io@ .x
                                                 1 i lshift $80 io@ xor .x cr then
  loop

  ." Read back location" cr

  $FFFF 0 do  \ Does it read back correctly ?
    i $800 io!  \ Set low memory address
      $80  io@ i <> if ." Location error: " i .x $80 io@ .x
                                            i $80 io@ xor .x cr then
  loop
;

: ramtest ( -- )
  0 $8000 io! ramtest-addr16
  1 $8000 io! ramtest-addr16
  2 $8000 io! ramtest-addr16
  3 $8000 io! ramtest-addr16
  4 $8000 io! ramtest-addr16
  5 $8000 io! ramtest-addr16
  6 $8000 io! ramtest-addr16
  7 $8000 io! ramtest-addr16
;
