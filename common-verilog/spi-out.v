`include "../common-verilog/preamble.h"

module SpiOut(input wire clock,
	      output reg  masterChipSelectN,
	      input wire  [15:0] data,
              input wire writeSPI, 
	      output reg  MOSI);
   
   reg [15:0]  shifter;
   reg [4:0]   state;
   reg	       valid;
   reg [15:0]  buffer;

   //Manage the buffer
   always @(posedge clock)	     
           if (writeSPI)
	     begin
	     buffer  <= data;
             valid <= TRUE;
             end
           else
              case (state)
		
		//It is idle, if there is data, the data gets consumed
                5'd00: valid<= FALSE;
		
		//It is done shifting, if there is data,
		//it is consumed. 
	        5'd15: valid <= FALSE;
		
		//Otherwise wait for the shifter to become available. 
	        default: valid <= valid;
              endcase // case (state)

   //Manage the shifter
   always @(posedge clock)
           case(state)
             // 0 is the idle state   	     
             5'd0:    
	       if (valid)
		 begin
		   state <= 1; 
		   masterChipSelectN <=0;
		   shifter[15:0] <= buffer[15:0];
		   end
	     5'd16:
	       begin
	       // if there is more data, load it
	       // and keep going
	       if (valid)
		 begin
                 state <= 1;
		 shifter <= buffer;
                 end
               else //Otherwise stop
		 begin
		 masterChipSelectN <= 1;
		 state<=0;
                 shifter<= 0;
		 end   
	       end
	  default:
	    begin
	    shifter <= {shifter[14:0],1'b0};
            state <= state + 5'b1;
	    end	       
         endcase

   assign MOSI = shifter[15];

   initial state <= 0;
   initial masterChipSelectN <= 1;
   
endmodule
   
