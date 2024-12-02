# SPI and Clocks

The strength of the Pico-Ice family is the ability to tightly
integrate the two chips.  But for that they have to communicate.  The
devil is in the details. So first this article discusses SPI
interfaces, and then the clocks problems.

SPI is very much an industry standard for interchip communication.
All the FLASH chips use it. Lots of other applications as well.  There
is single bit per clock cycle SPI, dual bit spi, quad spi and quad
double data rate (DDR). DDR uses both the positive and negative clock
edges.  But both sides of an SPI connection need to be synchronized to
the same clock domain.

The RP chips have three different types of SPI.

**QSPI** (RP2040 data sheet, section 4.10) It assumes that it is
talking to a flash chip.  So it is master only.  Good for sending
info, and getting a response, but not for receiving data from an FPGA
master. Also it is hard wired to the RP FLASH.  Looking at the
Schematic, it does not talk to the Pico-Ice FPGA.

**ARM SPI**.  (RP2040 data sheet, section 4.4) There are two of these.
• Master or Slave modes
• 8 deep Tx and Rx FIFOs
• Interrupt generation to service FIFOs or indicate error conditions
• Can be driven from DMA
• Programmable clock rate
• Programmable data size 4-16 bits.

The ARM processor understands that this could be in a different clock
domain.  It can be in the same clock domain as the FPGA.  That keeps
life simple. Really I should say doable. 

And here is how to use it from MicroPython.
https://www.digikey.com/en/maker/projects/raspberry-pi-pico-rp2040-spi-example-with-micropython-and-cc/9706ea0cf3784ee98e35ff49188ee045

**PIO based SPI**.  It is possible to do SPI using the PIOs.  But the
PIO's are in the same clock domain as the ARM processor's sys_clk.
They use a clock enable signal to slow processing.   Even if you
trigger a transition with a chip Select command, that does not allign
the phase of the communication channels!

Here is the official PIO SPI repository. 
https://github.com/raspberrypi/pico-examples/blob/master/pio/spi/spi.pio

Surprisingly little pio ASM.  More code to set up. 
There may also be quad or even quad DDR (double data rate) out there
somewhere on the internet.  And if not it can be written. 

## Clock Domain Crossings (CDC)

CDC is always tricky.

The processors run in one clock domain, the RP2040 GPIO port for the
FPGA clock is driven by one divider.  The RP2040 SPI clock is driven
by another divider.  The dividers have an integer counter to divide
down the frequency.  In the expected event that they are different,
say is at say 10, and the other is at 20, the two clocks will be out
of phase.  They have to be driven by the same clock and in phase, or
the signal can be metastable.  So what is the solution?

The simplest way to have a single clock is to just have a PIO clock
signal drive the FPGA and communications.  That is fine for small FPGA
circuits at low frequency, but it is not the best solution.  The PIO
signal has jitter. Clocks need dedicated hardware.  The RP2040 has 4
GPIO ports designed for publishing clock signals, and the ICE40 UP5K
also has ports designed for receiving clock signals. Best to use the
hardware designed for clocks. 

Shared Clock

There are multiple ways for the SPI and the FPGA to share a clock. 

They could both be driven by the RP2040 internal oscillator but that has a
poorly controlled frequency.  It would mess up any UART.

They could both be driven by the board's dedicated OSCILLATOR.  12
Mhz? (Or is it 24 Mhz, with this chip?
https://abracon.com/parametric/oscillators/ASDMB-24.000MHZ-LC-T )

They could both be driven by the system PLL. The docs say: "If clk_sys
never needs to exceed 48MHz then one PLL can be used (to drive both
the USB and the sys_clk) and the divider in the clk_sys clock
generator can then be used to scale the clk_sys frequency"
to the needs of the FPGA and SPI.  

They could both be driven by the FPGA's PLL.  It can be fed into the
RP2040's SPI blocks over a specfic GPIO pin. It can use either
CLKSRC_GPIN0
CLKSRC_GPIN1

From the attached image, it looks like GPIO0 and GPIO1 are connected
to the fpgA. Not clear if those pins on the FPGA can be used to output
a clock signal.

The documentation says: "For example, at the maximum SSPCLK (clk_peri)
frequency on RP2040 of 133MHz, the maximum peak bit rate in master
mode is 62.5 Mbps... In slave mode, the same
maximum SSPCLK frequency of 133MHz can achieve a peak bit rate of 133
/ 12 = ~11.083Mbps. "

So if we are using a 12Mhz clock for SPI, then sending is at 6Mhz, and
receiving is at 1 Mhz.  Receiving also has a 3 clock delay.

From the RP2040 datasheet: "In the slave mode of operation, the
SSPCLKIN signal from the external master is double-synchronized and
then delayed to detect an edge. It takes three SSPCLKs to detect an
edge on SSPCLKIN. SSPTXD has less setup time to the falling edge of
SSPCLKIN on which the master is sampling the line."  I think that must
mean that the RP SPI peripheral works by over-sampling 😦

Personally I like the idea of initially using the external oscillator, then
later the more complex solution of using the FPGA's PLL, if it is connected
correctly.

Of course we still have the issue of how to control all of this from a
language other than C.  Initially I thought that the place to start is
with updating the pico-ice-sdk.

##RP2040 SPI <-> FPGA

In order to provide for reliable SPI communication between the two
chips they need to be in the same clock domain.  Sadly [NextPRN does
not handle multiple clock domains
](https://github.com/YosysHQ/nextpnr/issues/390).

Some quick discord and web searches indicate that the lattice tools do
not do much better. I could be wrong. 

So another user and I would like to put part of the RP2040 in the same clock domain as the FPGA.  

I would like to put the ARM SPI and the FPGA into the 12 Mhz crystal
Oscillator clock domain.

He would like to put the ARM, USB, and FPGA into the 48MHz USB DLL
clock domain.

I have been reading through the pico-ice-sdk.  It is based on a
different model from what I need. The funcion ice_fpga_init(freq_mhz)
uses the function clock_gpio_init() The src for the FPGA is the USB
PLL, divided down to 12 Mhz.
The USB PLL is based on the oscillator.

I would want a 
> ice_fpga_init(External_Oscillator_or_USB_DLL). 
No freq_mhz.  I want it to use an undivided clock based on:
> clock_configure_undivided().  

In pricipal it should not be so hard to
change, but since it is called from so many places, I am a bit scared
to mess with it.  On the other hand I do not want to fork the
pico-ice-sdk either.

Same thing for the spi clock clk_peri.  I want to do
> clock_configure_undivided().  

And we would like to be able to use
either the 12Mhz from the external oscillator or 48Mhz from the USB PLL,

So modifying the Pico ICE SDK or forking it both seem overly complex.

## MicroPython

In princpal not that hard to modify MicroPython.

And here is [the one line to configure the clk_peri in microPython on RP chips]
(https://github.com/micropython/micropython/blob/master/ports/rp2/clocks_extra.c).

>   // CLK PERI = clk_sys. Used as reference clock for UART and SPI serial.
>     clock_configure(clk_peri,
>         0,
>         CLOCKS_CLK_PERI_CTRL_AUXSRC_VALUE_CLK_SYS,
>         SYS_CLK_KHZ * KHZ,
>         SYS_CLK_KHZ * KHZ);

Much much easier than messing with the pico-ice-sdk. 







