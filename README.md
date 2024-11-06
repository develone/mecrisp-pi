Welcome to Mecrisp-ice. This is a family of 16, 32 and 64 bit forth
processors based on the J1 stack machine. It supports the following
boards.

blackice2 hx8k-32bit tinyfpga-bx
fomu icebreaker ulx3s
fomu-ledcomm mch2022 ulx3s-usb-experimental
hx1k mystorm
hx8k nandland

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

If you have any questions, please post them on our discussion board.
https://sourceforge.net/p/mecrisp/discussion/general/
