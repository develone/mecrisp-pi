`timescale 1ns/100ps  // 1 ns time unit, 100 ps resolution
`default_nettype none // Makes it easier to detect typos !

module BB(inout B, input I, input T, output O);
  assign B = T ? 1'bz : I;
  assign O = B;
endmodule

module BBPU(inout B, input I, input T, output O);
  assign B = T ? 1'bz : I;
  assign O = B;
endmodule

module USRMCLK(input USRMCLKTS, input USRMCLKI);
endmodule

module TRELLIS_SLICE(input A0, B0, C0, D0, output F0);
parameter LUT0_INITVAL = 0;
endmodule


module test;
   reg resetq = 0;
   reg clk;
   always #20.0 clk = !clk; // Roughly 25 MHz


   top blinky(
     .clk_25mhz(clk),
     .btn(7'd127),
     .adc_miso(1'b0)
   );

   /***************************************************************************/
   // Test sequence
   /***************************************************************************/

   integer i;
   initial begin
     $dumpfile("ulx3s.vcd");    // create a VCD waveform dump
     $dumpvars(0, blinky);      // dump variable changes in the testbench
                               // and all modules under it


     clk = 0;
     resetq = 0;
     @(negedge clk);
     resetq = 1;

     for (i = 0; i < 10000; i = i + 1) begin
       @(negedge clk);
     end

     $finish();
   end
endmodule
