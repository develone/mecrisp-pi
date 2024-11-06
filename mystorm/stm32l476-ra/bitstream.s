@
@    Mecrisp-Stellaris - A native code Forth implementation for ARM-Cortex M microcontrollers
@    Copyright (C) 2013  Matthias Koch
@
@    This program is free software: you can redistribute it and/or modify
@    it under the terms of the GNU General Public License as published by
@    the Free Software Foundation, either version 3 of the License, or
@    (at your option) any later version.
@
@    This program is distributed in the hope that it will be useful,
@    but WITHOUT ANY WARRANTY; without even the implied warranty of
@    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
@    GNU General Public License for more details.
@
@    You should have received a copy of the GNU General Public License
@    along with this program.  If not, see <http://www.gnu.org/licenses/>.
@

@ Bitstream specials for booting an iCE40 HX4K FPGA through SPI lines

  .p2align 2        @ Align to 4-even locations

  .equ bitstreambinary, .
  .incbin "../hx8k/j1a0.bin"
  @ .incbin "../LED.bin"
  .equ bitstreambinarylength, . - bitstreambinary

  .p2align 2        @ Align to 4-even locations

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "bitstream"
bitstream:  @ ( -- addr len ) Bitstream image
@ -----------------------------------------------------------------------------
  pushdatos
  ldr tos, =bitstreambinary
  pushdatos
  ldr tos, =bitstreambinarylength
  bx lr

  .ltorg
