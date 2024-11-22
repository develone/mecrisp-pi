Mecrisp-Pi
```diff
-  Not Yet Released.  This contains a synthesizing Pico-Ice
- Mecrisp Ice processor.  Any software on the RP2040 can
- talk to it over Uart.  I am working to add the ability
- to send messages from the ICE40 to MicroPython running on the RP2040. 
 
```


 

Mecrisp Pi is an FPGA co-processor for the RP2040 and RP2350 chips
running on the
[Pico-Ice](https://tinyvision.ai/products/pico-ice-fpga-trainer-board)
and (soon) [Pico2-Ice](https://discord.gg/4X6caMbHCD) circuit boards.
Mecrisp Pi provides the firmware and verilog to connect the two chips.
The ICE40UP5k FPGA can be used to accelerate parallel processes, and
provides another 32 GPIO ports.  The [Mecrisp Ice
Interpreter](https://mecrisp-ice.readthedocs.io/en/latest/api.html)
makes it much easier to debug your hardware designs.  The RP2350
provides DVI output.  4 PMODS ports are available for additional
functionality. For example, a Diligent I2S2 PMOD can provide stereo
audio I/O.

This repository includes:

    ready-to-fly versions of the J1 for many boards Search for your board
    name in this directory change into that directory, read the local README,
    and type "./compile". That will generate the bitstream (also called gateware ) for that board.
    How to download it to your board will depend on the specific board and operating system.

    Verilog definitions for the various processors, as well as additional useful
    modules in ./common-verilog.

    Ready-to-emulate verilator simulators for the different versions in ./verilator*

    Cross compilers for the different versoins, and the definitions of the various instructions sets are located in ./common-crosscompiler.

    An extended version of the Hayes-Forth test suite is located in
    ./testsuite. Documentation is in german.

    Pascal simulators are also in ./common-crosscompiler.

    A easy-to-use starting point for defining your own board can be found in
    ./skeletalstructure and

    A wordlist (will soon be) in ./documentation/glossary.txt

This repository does not yet include the firmware and gateware for sending
data from the FPGA to the RP chip. 

If you have any questions, please post them on our discussion board.
https://sourceforge.net/p/mecrisp/discussion/general/

Or [join the Hana-1 Discord server](https://discord.gg/DY2HZG5g)
