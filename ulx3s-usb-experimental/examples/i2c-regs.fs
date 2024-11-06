\ -------------------------------------------------------------
\ I2C Register primitives

: i2c-reg! ( data register address -- )
  i2c-start
  2*  i2c-tx not if ."  I2C device not connected." cr quit then  \ Transmit address
  i2c-tx drop \ Transmit register
  i2c-tx drop \ Transmit data
  i2c-stop
;

: i2c-first-reg@ ( register address -- data )
  2*  tuck ( address register address )
  i2c-start
  i2c-tx not if ."  I2C device not connected." cr quit then  \ Transmit address
  i2c-tx drop \ Transmit register
  i2c-start
  1 or \ Set Read bit in address
  i2c-tx drop
  true i2c-rx
;

: i2c-next-reg@ ( -- data )  true i2c-rx ;
: i2c-last-reg@ ( -- data ) false i2c-rx i2c-stop ;


: i2c-reg@ ( register address -- data )
  2*  tuck ( address register address )
  i2c-start
  i2c-tx not if ."  I2C device not connected." cr quit then  \ Transmit address
  i2c-tx drop \ Transmit register
  i2c-start
  1 or \ Set Read bit in address
  i2c-tx drop
  false i2c-rx
  i2c-stop
;

