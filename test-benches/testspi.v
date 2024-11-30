`include "../common-verilog/preamble.h"
`include "../common-verilog/spi-out.v"
`include "../common-verilog/spi-in.v"
  
module tb();   
   reg         clock;
   reg [15:0]  dataOut;
   wire [15:0] dataIn;   
   reg         writeSPI;
   wire	       masterChipSelectN;
   wire	       MOSI;
   wire	       MISO;
   wire	       interrupt;
   
   always #10 clock = ~clock; 

SpiOut spiOut (
              .clock(clock),
	      .masterChipSelectN(masterChipSelectN),
	      .data(dataOut),
              .writeSPI(writeSPI), 
	      .MOSI(MOSI));

SpiIn spiIn (
      .clock(clock),
      .MOSI(MOSI),
      .slaveChipSelectN(masterChipSelectN),
      .interrupt(interrupt),
      .data(dataIn));
   
initial begin
   $dumpfile("out.vcd");
   $dumpvars(0, tb);
   $dumpon;
   clock = 0;
   dataOut = 16'b0101_0000_0101_0101;
   $display ("Data Out = ",dataOut);

   #10 writeSPI = 1;
   #10 writeSPI = 0;

   #900 dataOut = 16'b1101_0110_0101_0101;
   $display ("Data Out = ",dataOut);
   #10 writeSPI = 1;
   #10 writeSPI = 0;
   
   #900 dataOut = 16'b0001_0010_0101_0101;
   $display ("Data Out = ",dataOut);
   #10 writeSPI = 1;
   #10 writeSPI = 0;
   
   #3000 $finish;
end
   
//      always @(posedge clock)
//     $display ("%d %b", spiOut.state, spiOut.shifter);
//     $display ("IN:%d %d %b", masterChipSelectN, MOSI,  spiIn.state, spiIn.shifter);
//       $display ("%b %b %d %b %d %b %b", 
//                 dataOut, MOSI, spiOut.state, spiOut.shifter, 
//		 spiIn.state, spiIn.shifter, dataIn);
   
always @(posedge interrupt)
  $display ("Data In = %d \n", dataIn);
   
     
endmodule
