
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

  // ######   UART   ##########################################

  assign uart0_wr = io_wr & io_addr[12];
  assign uart0_rd = io_rd & io_addr[12];

  assign uart_w = io_dout[7:0];

 
endmodule
