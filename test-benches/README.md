CDC and SPI

The strength of the Pico-Ice family is the ability to tightly
integrate the two chips.  But for that they have to communicate.  And
for that one has to deal with clocks. And clock domain crossings.
(CDC)

The simplest way is to just have a PIO clock signal drive the FPGA.
That is fine for small FPGA circuits at low frequency, but it is not
the best solution.  The PIO signal has jitter. Clocks need dedicated
hardware.  The RP2040 has 4 GPIO ports designed for publishing clock
signals, and the ICE40 UP5K also has ports designed for receiving
clock signals. Best to use them. .

CDC Solutions.

CDC is always tricky.  The RP2040 GPIO port for the FPGA clock is
driven by one divider.  The RP2040 SPI clock is driven by another divider.
They have an integer counter to divide down the frequency.  In the
likely event that one is at 10, and the other is at 20, the two clocks
will be out of phase.  They have to be driven by the same clock.

They could be driven by the RP2040 internal oscillator but that has a
poorly controlled frequency.  It would mess up any UART.

They could be driven by the board's dedicated OSCILLATOR.  12 Mhz. (Or
is it 24 Mhz, with this chip?
https://abracon.com/parametric/oscillators/ASDMB-24.000MHZ-LC-T )

They could be driven by the FPGA's PLL.  It can be fed into the RP2040's SPI
blocks over a specfic GPIO pin.

IF you set the USB PLL at 96Mhz, twice the required 48Mhz frequncy of
the USB, then that can drive the USB, and the ARM cores, leaving the
RP2040 PLL free to drive the rest of the system at any fequency.

Personally I like the idea of initially using the external oscillator, then
the FPGA PLL. 


The RP chips have three different types of SPI.

**QSPI** (RP2040 data sheet, section 4.10) It assumes that it is
talking to a flash chip.  So it is master only.  Good for sending
info,not for receiving it from an FPGA master. Also it is hard wired
to the RP FLASH.   I believe that it does not talk to the Pico-Ice FPGA.

**ARM SPI**.  (RP2040 data sheet, section 4.4) There are two of these.

• Master or Slave modes
• 8 deep Tx and Rx FIFOs
• Interrupt generation to service FIFOs or indicate error conditions
• Can be driven from DMA
• Programmable clock rate
• Programmable data size 4-16 bits.

Reportedly this has the best clock domain crossing to the CPU cores.
It can be in the same clock domain as the FPGA.  That keeps life simple. 

And here is how to use it from MicroPython.
https://www.digikey.com/en/maker/projects/raspberry-pi-pico-rp2040-spi-example-with-micropython-and-cc/9706ea0cf3784ee98e35ff49188ee045

**PIO based SPI**.  It is possible to do SPI using the PIOs.
Here is the official code.
https://github.com/raspberrypi/pico-examples/blob/master/pio/spi/spi.pio
But reportedly the CDC is not as good here. 

Surprisingly little pio ASM.  More code to set up. 
There may also be quad or even quadd DDR (double data rate) out there
somewhere on the internet.  And if not it can be written. 





