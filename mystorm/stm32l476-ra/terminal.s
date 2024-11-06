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

@ Terminalroutinen
@ Terminal code and initialisations.
@ Porting: Rewrite this !

  .equ GPIOA_BASE      ,   0x48000000
  .equ GPIOA_MODER     ,   GPIOA_BASE + 0x00
  .equ GPIOA_OTYPER    ,   GPIOA_BASE + 0x04
  .equ GPIOA_OSPEEDR   ,   GPIOA_BASE + 0x08
  .equ GPIOA_PUPDR     ,   GPIOA_BASE + 0x0C
  .equ GPIOA_IDR       ,   GPIOA_BASE + 0x10
  .equ GPIOA_ODR       ,   GPIOA_BASE + 0x14
  .equ GPIOA_BSRR      ,   GPIOA_BASE + 0x18
  .equ GPIOA_LCKR      ,   GPIOA_BASE + 0x1C
  .equ GPIOA_AFRL      ,   GPIOA_BASE + 0x20
  .equ GPIOA_AFRH      ,   GPIOA_BASE + 0x24
  .equ GPIOA_BRR       ,   GPIOA_BASE + 0x28
  .equ GPIOA_ASCR      ,   GPIOA_BASE + 0x2C

  .equ RCC_BASE        ,   0x40021000
  .equ RCC_AHB1ENR     ,   RCC_BASE + 0x48
  .equ RCC_AHB2ENR     ,   RCC_BASE + 0x4C @ GPIOA  - b3
  .equ RCC_APB1ENR1    ,   RCC_BASE + 0x58 @ UART4  - b19
  .equ RCC_APB2ENR     ,   RCC_BASE + 0x60 @ USART1 - b14

        @ Mystorm board uses USART1 on PA9 and PA10 for main communication and UART4 on PA0 (TX) and PA1 (RX) for communication with the FPGA.

        .equ USART1_BASE     ,   0x40013800

        .equ USART1_CR1      ,   USART1_BASE + 0x00
        .equ USART1_CR2      ,   USART1_BASE + 0x04
        .equ USART1_CR3      ,   USART1_BASE + 0x08
        .equ USART1_BRR      ,   USART1_BASE + 0x0C
        .equ USART1_GTPR     ,   USART1_BASE + 0x10
        .equ USART1_RTOR     ,   USART1_BASE + 0x14
        .equ USART1_RQR      ,   USART1_BASE + 0x18
        .equ USART1_ISR      ,   USART1_BASE + 0x1C
        .equ USART1_ICR      ,   USART1_BASE + 0x20
        .equ USART1_RDR      ,   USART1_BASE + 0x24
        .equ USART1_TDR      ,   USART1_BASE + 0x28


        .equ UART4_BASE     ,   0x40004C00

        .equ UART4_CR1      ,   UART4_BASE + 0x00
        .equ UART4_CR2      ,   UART4_BASE + 0x04
        .equ UART4_CR3      ,   UART4_BASE + 0x08
        .equ UART4_BRR      ,   UART4_BASE + 0x0C
        .equ UART4_GTPR     ,   UART4_BASE + 0x10
        .equ UART4_RTOR     ,   UART4_BASE + 0x14
        .equ UART4_RQR      ,   UART4_BASE + 0x18
        .equ UART4_ISR      ,   UART4_BASE + 0x1C
        .equ UART4_ICR      ,   UART4_BASE + 0x20
        .equ UART4_RDR      ,   UART4_BASE + 0x24
        .equ UART4_TDR      ,   UART4_BASE + 0x28

        @ Flags for USART_ISR register:
          .equ RXNE            ,   BIT5
          .equ TC              ,   BIT6
          .equ TXE             ,   BIT7

@ -----------------------------------------------------------------------------
uart_init: @ ( -- ) A few bits are different
@ -----------------------------------------------------------------------------

  @ Enable all GPIO peripheral clock
  ldr r1, = RCC_AHB2ENR
  ldr r0, = BIT7+BIT6+BIT5+BIT4+BIT3+BIT2+BIT1+BIT0 @ $0 is Reset value
  str r0, [r1]

  @ Enable the USART1 peripheral clock
  ldr r1, = RCC_APB2ENR
  ldr r0, = BIT14
  str r0, [r1]

  @ Enable the UART4 peripheral clock
  ldr r1, = RCC_APB1ENR1
  ldr r0, = BIT19
  str r0, [r1]

  @ Set PORTA pins 0, 1, 9 and 10 in alternate function mode for communication
  ldr r1, = GPIOA_MODER
  ldr r0, = 0x6BEBFFFA @ ABFF FFFF is Reset value for Port A... Alternate function: %10.   Also: Led on PA15 %01 Output.
  str r0, [r1]

  @ Set alternate function 7 to enable USART pins
  ldr r1, = GPIOA_AFRL
  ldr r0, = 0x00000088   @ Alternate function 8 for PA0 and PA1
  str r0, [r1]

  ldr r1, = GPIOA_AFRH
  ldr r0, = 0x00000770   @ Alternate function 7 for PA9 and PA10
  str r0, [r1]

  @ Configure BRR by deviding the bus clock with the baud rate
  ldr r1, = USART1_BRR
  movs r0, #(4000000 + (115200/2)) / 115200  @ 115200 bps, ein ganz kleines bisschen langsamer...
  str r0, [r1]
  ldr r1, = UART4_BRR
  str r0, [r1]

  @ Disable overrun detection before UE to avoid USART blocking on overflow
  ldr r1, =USART1_CR3
  ldr r0, =BIT12 @ USART_CR3_OVRDIS
  str r0, [r1]
  ldr r1, =UART4_CR3
  str r0, [r1]

  @ Enable the USART, TX, and RX circuit
  ldr r1, =USART1_CR1
  ldr r0, =BIT3+BIT2+BIT0 @ USART_CR1_UE | USART_CR1_TE | USART_CR1_RE
  str r0, [r1]
  ldr r1, =UART4_CR1
  str r0, [r1]

  bx lr

.ifdef turbo
@ change baudrate for 48 MHz mode
@ -----------------------------------------------------------------------------
serial_115200_48MHZ: @ set USART1 baudrate to 115200 baud at 48 MHz
@ -----------------------------------------------------------------------------
    ldr r0, =USART1_BRR
    ldr r1, =(48000000 + 115200 / 2) / 115200
    str r1, [r0]
    ldr r0, =UART4_BRR
    str r1, [r0]
    bx  lr
.endif  @ .ifdef turbo

@ Following code is the same as for STM32F051
.include "../common/terminalhooks.s"

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "serial-emit"
serial_emit: @ ( c -- ) Emit one character
@ -----------------------------------------------------------------------------
   push {lr}

1: bl serial_qemit
   cmp tos, #0
   drop
   beq 1b

   ldr r2, =USART1_TDR
   strb tos, [r2]         @ Output the character
   drop

   pop {pc}

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "serial-key"
serial_key: @ ( -- c ) Receive one character
@ -----------------------------------------------------------------------------
   push {lr}

1: bl serial_qkey
   cmp tos, #0
   drop
   beq 1b

   pushdatos
   ldr r2, =USART1_RDR
   ldrb tos, [r2]         @ Fetch the character

   pop {pc}

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "serial-emit?"
serial_qemit:  @ ( -- ? ) Ready to send a character ?
@ -----------------------------------------------------------------------------
   push {lr}
   bl pause

   pushdaconst 0  @ False Flag
   ldr r0, =USART1_ISR
   ldr r1, [r0]     @ Fetch status
   movs r0, #TXE
   ands r1, r0
   beq 1f
     mvns tos, tos @ True Flag
1: pop {pc}

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "serial-key?"
serial_qkey:  @ ( -- ? ) Is there a key press ?
@ -----------------------------------------------------------------------------
   push {lr}
   bl pause

   pushdaconst 0  @ False Flag
   ldr r0, =USART1_ISR
   ldr r1, [r0]     @ Fetch status
   movs r0, #RXNE
   ands r1, r0
   beq 1f
   mvns tos, tos @ True Flag
1: pop {pc}


@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "bridge-emit"
bridge_emit: @ ( c -- ) Emit one character
@ -----------------------------------------------------------------------------
   push {lr}

1: bl bridge_qemit
   cmp tos, #0
   drop
   beq 1b

   ldr r2, =UART4_TDR
   strb tos, [r2]         @ Output the character
   drop

   pop {pc}

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "bridge-key"
bridge_key: @ ( -- c ) Receive one character
@ -----------------------------------------------------------------------------
   push {lr}

1: bl bridge_qkey
   cmp tos, #0
   drop
   beq 1b

   pushdatos
   ldr r2, =UART4_RDR
   ldrb tos, [r2]         @ Fetch the character

   pop {pc}

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "bridge-emit?"
bridge_qemit:  @ ( -- ? ) Ready to send a character ?
@ -----------------------------------------------------------------------------
   push {lr}
   bl pause

   pushdaconst 0  @ False Flag
   ldr r0, =UART4_ISR
   ldr r1, [r0]     @ Fetch status
   movs r0, #TXE
   ands r1, r0
   beq 1f
     mvns tos, tos @ True Flag
1: pop {pc}

@ -----------------------------------------------------------------------------
  Wortbirne Flag_visible, "bridge-key?"
bridge_qkey:  @ ( -- ? ) Is there a key press ?
@ -----------------------------------------------------------------------------
   push {lr}
   bl pause

   pushdaconst 0  @ False Flag
   ldr r0, =UART4_ISR
   ldr r1, [r0]     @ Fetch status
   movs r0, #RXNE
   ands r1, r0
   beq 1f
   mvns tos, tos @ True Flag
1: pop {pc}

  .ltorg @ Hier werden viele spezielle Hardwarestellenkonstanten gebraucht, schreibe sie gleich !
