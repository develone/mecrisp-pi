
: ramtester ( -- )

  ." Fill with own address" cr

  $FFFF 0 do  \ Fill each location with its own address
    i $800 io!  \ Set low memory address
    i $80  io!  \ Set content to address
  loop

  ." Read back location" cr

  $FFFF 0 do  \ Does it read back correctly ?
    i $800 io!  \ Set low memory address
      $80  io@ i <> if ." Location error: " i .x $80 io@ .x
                                            i $80 io@ xor .x cr then
  loop

;
 
