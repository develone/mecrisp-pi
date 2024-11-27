`include "../common-verilog/preamble.h"

module SpiIn(input wire        clock,
	      input wire        MOSI,
	      input wire        slaveChipSelectN,
	      output reg       interrupt,
	      output reg [15:0] data);

   reg [3:0]		  state;
   reg [15:0]		  shifter;

   initial shifter = 0;
   initial state = 0;
   
  always @ (posedge clock)
      if (slaveChipSelectN)
             begin
             state <= 0;
    	     shifter[15:0] <= 0;
             end
      else
	begin
         shifter[15:0] <= {shifter[14:0], MOSI};	 	   
         state <= state + 1;  //It loops to 0 at 15.
         end // else: !if(!slaveChipSelectN)
       
//When you get to shifting the last bit
//Save the data, and fire the interrupt
//The data will be saved for at least 16 clock cycles.   	   
always @(posedge clock)
    if (state == 4'd15)
      begin
      interrupt <= 1;
      data[15:0] <= {shifter[14:0],MOSI};
      end
    else 
      interrupt <=0;
	   
endmodule
