  // ######   Ticks   #########################################
  // This is the code to have a timer.

// You also have to add this line to shared.v 
//      |
//    (io_addr[14] ?         ticks                                             //       : 16'd0) ;
     


  reg [15:0] ticks;

  wire [16:0] ticks_plus_1 = ticks + 1;

  always @(posedge clk)
    if (io_wr & io_addr[14])
      ticks <= io_dout;
    else
      ticks <= ticks_plus_1;

  always @(posedge clk) // Generate interrupt on ticks overflow
    interrupt <= ticks_plus_1[16];
