
`default_nettype none

/* verilator lint_off DECLFILENAME */
/* verilator lint_off UNUSED */

`include "../common-verilog/j1-universal-16kb.v"
`include "../common-verilog/spi-out.v"
`include "../common-verilog/spi-in.v"

module j1a(
           input wire clk,
           input wire resetq,

           output wire uart0_wr,
           output wire uart0_rd,
           output wire [7:0] uart_w,

           input wire uart0_busy,
           input wire uart0_valid,
           input wire [7:0] uart0_data

);

  // ######   Clock   #########################################


  // ######   Reset logic   ###################################


  // ######   Bus    ##########################################

  wire io_rd, io_wr;
  wire [15:0] io_addr;
  wire [15:0] io_dout;
  wire [15:0] io_din;

  reg interrupt = 0;

  // ######   PROCESSOR   #####################################

  j1 _j1(
    .clk(clk),
    .resetq(resetq),

    .io_rd(io_rd),
    .io_wr(io_wr),
    .io_dout(io_dout),
    .io_din(io_din),
    .io_addr(io_addr),

    .interrupt_request(interrupt)
  );

  // ######   TICKS   #########################################
/*
  reg [15:0] ticks;

  wire [16:0] ticks_plus_1 = ticks + 1;

  always @(posedge clk)
    if (io_wr & io_addr[14])
      ticks <= io_dout;
    else
      ticks <= ticks_plus_1[15:0];

  always @(posedge clk) // Generate interrupt on ticks overflow
    interrupt <= ticks_plus_1[16];
*/
   

  // ######   UART   ##########################################

  assign uart0_wr = io_wr & io_addr[12];
  assign uart0_rd = io_rd & io_addr[12];

  assign uart_w = io_dout[7:0];

  // ######   IO PORTS   ######################################

  /*        bit READ            WRITE

      0001   1  spi_in          spi_out
      1000  12  UART RX         UART TX
      2000  13  misc.in
      4000  14  ticks           clear ticks

  */

  assign io_din =
    (io_addr[0] ? dataIn : 16'd0) |
//    (io_addr[ 0] ?         porta_in                                          //       : 16'd0) |
    (io_addr[12] ? { 8'd0, uart0_data}                                              : 16'd0) |
    (io_addr[13] ? {14'd0, uart0_valid, !uart0_busy}                                : 16'd0) 
;
 
//      |
//    (io_addr[14] ?         ticks                                             //       : 16'd0) ;
     

  // ######   SPI   ##########################################
   wire	       masterChipSelectN;
   wire        writeSPI;
   wire	       MOSI;
   wire [15:0] dataIn;
   
   assign writeSPI =  io_wr & io_addr[0];
   
   wire	       isWrite;
   assign isWrite = (io_addr == 16'h0001);
   
 
SpiOut spiOut (
              .clock(clk),
	      .masterChipSelectN(masterChipSelectN),
	      .data(io_dout),
              .writeSPI(writeSPI), 
	      .MOSI(MOSI));

SpiIn spiIn (
      .clock(clk),
      .MOSI(MOSI),
      .slaveChipSelectN(masterChipSelectN),
      .interrupt(interrupt),
      .data(dataIn));
 
endmodule
