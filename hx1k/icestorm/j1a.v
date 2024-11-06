
`default_nettype none

`define cfg_divider 208  // 48 MHz / 230400

`include "../common-verilog/uart.v"
`include "../common-verilog/j1-universal-8kb.v"

module top(input oscillator,

           output D1,
           output D2,
           output D3,
           output D4,
           output D5,

           output TXD,        // UART TX
           input  RXD,        // UART RX

           output CTS,        // UART CTS - PIO3_05
           input  RTS,        // UART RTS - PIO3_06

           output PIOS_00,    // Flash SCK
           input PIOS_01,     // Flash MISO
           output PIOS_02,    // Flash MOSI
           output PIOS_03,    // Flash CS

           inout PIO1_02,    // PMOD 1
           inout PIO1_03,    // PMOD 2
           inout PIO1_04,    // PMOD 3
           inout PIO1_05,    // PMOD 4
           inout PIO1_06,    // PMOD 5
           inout PIO1_07,    // PMOD 6
           inout PIO1_08,    // PMOD 7
           inout PIO1_09,    // PMOD 8

           output PIO1_18,    // IR TXD
           input  PIO1_19,    // IR RXD
           output PIO1_20,    // IR SD

           inout PIO0_02,    // Header 1
           inout PIO0_03,    // Header 2
           inout PIO0_04,    // Header 3
           inout PIO0_05,    // Header 4
           inout PIO0_06,    // Header 5
           inout PIO0_07,    // Header 6
           inout PIO0_08,    // Header 7
           inout PIO0_09,    // Header 8

           inout PIO2_10,    // Header 1
           inout PIO2_11,    // Header 2
           inout PIO2_12,    // Header 3
           inout PIO2_13,    // Header 4
           inout PIO2_14,    // Header 5
           inout PIO2_15,    // Header 6
           inout PIO2_16,    // Header 7
           inout PIO2_17,    // Header 8

           input reset_button,
);


  // ######   Clock   #########################################

  wire clk;

  SB_PLL40_CORE #(.FEEDBACK_PATH("SIMPLE"),
                  .PLLOUT_SELECT("GENCLK"),
                  .DIVR(4'b0000),
                  .DIVF(7'd3),
                  .DIVQ(3'b000),
                  .FILTER_RANGE(3'b001),
                 ) uut (
                         .REFERENCECLK(oscillator),
                         .PLLOUTCORE(clk),
                         //.PLLOUTGLOBAL(clk),
                         //.LOCK(D5),
                         .RESETB(1'b1),
                         .BYPASS(1'b0)
                        );

  // ######   Reset logic   ###################################

  reg [3:0] reset_cnt = 0;
  wire resetq = &reset_cnt;

  always @(posedge clk) begin
    if (reset_button) reset_cnt <= reset_cnt + !resetq;
    else              reset_cnt <= 0;
  end

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

  reg [15:0] ticks;

  wire [16:0] ticks_plus_1 = ticks + 1;

  always @(posedge clk)
    if (io_wr & io_addr[14])
      ticks <= io_dout;
    else
      ticks <= ticks_plus_1;

  always @(posedge clk) // Generate interrupt on ticks overflow
    interrupt <= ticks_plus_1[16];

  // ######   PMOD   ##########################################

  reg [7:0] pmod_dir;   // 1:output, 0:input
  reg [7:0] pmod_out;
  wire [7:0] pmod_in;

  SB_IO #(.PIN_TYPE(6'b1010_01)) io0 (.PACKAGE_PIN(PIO1_02), .D_OUT_0(pmod_out[0]), .D_IN_0(pmod_in[0]), .OUTPUT_ENABLE(pmod_dir[0]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) io1 (.PACKAGE_PIN(PIO1_03), .D_OUT_0(pmod_out[1]), .D_IN_0(pmod_in[1]), .OUTPUT_ENABLE(pmod_dir[1]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) io2 (.PACKAGE_PIN(PIO1_04), .D_OUT_0(pmod_out[2]), .D_IN_0(pmod_in[2]), .OUTPUT_ENABLE(pmod_dir[2]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) io3 (.PACKAGE_PIN(PIO1_05), .D_OUT_0(pmod_out[3]), .D_IN_0(pmod_in[3]), .OUTPUT_ENABLE(pmod_dir[3]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) io4 (.PACKAGE_PIN(PIO1_06), .D_OUT_0(pmod_out[4]), .D_IN_0(pmod_in[4]), .OUTPUT_ENABLE(pmod_dir[4]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) io5 (.PACKAGE_PIN(PIO1_07), .D_OUT_0(pmod_out[5]), .D_IN_0(pmod_in[5]), .OUTPUT_ENABLE(pmod_dir[5]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) io6 (.PACKAGE_PIN(PIO1_08), .D_OUT_0(pmod_out[6]), .D_IN_0(pmod_in[6]), .OUTPUT_ENABLE(pmod_dir[6]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) io7 (.PACKAGE_PIN(PIO1_09), .D_OUT_0(pmod_out[7]), .D_IN_0(pmod_in[7]), .OUTPUT_ENABLE(pmod_dir[7]));

  // ######   Header   ##########################################
  // PIO0  2-9
  // PIO2  10-17

  reg [7:0] header1_dir;   // 1:output, 0:input
  reg [7:0] header1_out;
  wire [7:0] header1_in;

  SB_IO #(.PIN_TYPE(6'b1010_01)) gio0 (.PACKAGE_PIN(PIO0_02), .D_OUT_0(header1_out[0]), .D_IN_0(header1_in[0]), .OUTPUT_ENABLE(header1_dir[0]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) gio1 (.PACKAGE_PIN(PIO0_03), .D_OUT_0(header1_out[1]), .D_IN_0(header1_in[1]), .OUTPUT_ENABLE(header1_dir[1]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) gio2 (.PACKAGE_PIN(PIO0_04), .D_OUT_0(header1_out[2]), .D_IN_0(header1_in[2]), .OUTPUT_ENABLE(header1_dir[2]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) gio3 (.PACKAGE_PIN(PIO0_05), .D_OUT_0(header1_out[3]), .D_IN_0(header1_in[3]), .OUTPUT_ENABLE(header1_dir[3]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) gio4 (.PACKAGE_PIN(PIO0_06), .D_OUT_0(header1_out[4]), .D_IN_0(header1_in[4]), .OUTPUT_ENABLE(header1_dir[4]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) gio5 (.PACKAGE_PIN(PIO0_07), .D_OUT_0(header1_out[5]), .D_IN_0(header1_in[5]), .OUTPUT_ENABLE(header1_dir[5]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) gio6 (.PACKAGE_PIN(PIO0_08), .D_OUT_0(header1_out[6]), .D_IN_0(header1_in[6]), .OUTPUT_ENABLE(header1_dir[6]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) gio7 (.PACKAGE_PIN(PIO0_09), .D_OUT_0(header1_out[7]), .D_IN_0(header1_in[7]), .OUTPUT_ENABLE(header1_dir[7]));

  reg [7:0] header2_dir;   // 1:output, 0:input
  reg [7:0] header2_out;
  wire [7:0] header2_in;

  SB_IO #(.PIN_TYPE(6'b1010_01)) hio0 (.PACKAGE_PIN(PIO2_10), .D_OUT_0(header2_out[0]), .D_IN_0(header2_in[0]), .OUTPUT_ENABLE(header2_dir[0]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) hio1 (.PACKAGE_PIN(PIO2_11), .D_OUT_0(header2_out[1]), .D_IN_0(header2_in[1]), .OUTPUT_ENABLE(header2_dir[1]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) hio2 (.PACKAGE_PIN(PIO2_12), .D_OUT_0(header2_out[2]), .D_IN_0(header2_in[2]), .OUTPUT_ENABLE(header2_dir[2]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) hio3 (.PACKAGE_PIN(PIO2_13), .D_OUT_0(header2_out[3]), .D_IN_0(header2_in[3]), .OUTPUT_ENABLE(header2_dir[3]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) hio4 (.PACKAGE_PIN(PIO2_14), .D_OUT_0(header2_out[4]), .D_IN_0(header2_in[4]), .OUTPUT_ENABLE(header2_dir[4]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) hio5 (.PACKAGE_PIN(PIO2_15), .D_OUT_0(header2_out[5]), .D_IN_0(header2_in[5]), .OUTPUT_ENABLE(header2_dir[5]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) hio6 (.PACKAGE_PIN(PIO2_16), .D_OUT_0(header2_out[6]), .D_IN_0(header2_in[6]), .OUTPUT_ENABLE(header2_dir[6]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) hio7 (.PACKAGE_PIN(PIO2_17), .D_OUT_0(header2_out[7]), .D_IN_0(header2_in[7]), .OUTPUT_ENABLE(header2_dir[7]));

  // ######   UART   ##########################################

  wire uart0_valid, uart0_busy;
  wire [7:0] uart0_data;
  wire uart0_wr = io_wr & io_addr[12];
  wire uart0_rd = io_rd & io_addr[12];

  buart _uart0 (
     .clk(clk),
     .resetq(resetq),
     .rx(RXD),
     .tx(TXD),
     .rd(uart0_rd),
     .wr(uart0_wr),
     .valid(uart0_valid),
     .busy(uart0_busy),
     .tx_data(io_dout[7:0]),
     .rx_data(uart0_data));

  // ######   LEDS & PIOS   ###################################

  reg [5:0] PIOS;
  assign {CTS, PIO1_20, PIO1_18, PIOS_00, PIOS_02, PIOS_03} = PIOS;
  reg [4:0] LEDS;
  assign {D1,D2,D3,D4,D5} = LEDS;

  // ######   RING OSCILLATOR   ###############################

  wire [1:0] buffers_in, buffers_out;
  assign buffers_in = {buffers_out[0:0], ~buffers_out[1]};
  SB_LUT4 #(
          .LUT_INIT(16'd2)
  ) buffers [1:0] (
          .O(buffers_out),
          .I0(buffers_in),
          .I1(1'b0),
          .I2(1'b0),
          .I3(1'b0)
  );

  wire random = ~buffers_out[1];

  // ######   IO PORTS   ######################################

  /*        bit READ            WRITE

      0001  0   PMOD in
      0002  1   PMOD out        PMOD out
      0004  2   PMOD dir        PMOD dir
      0008  3   misc.out        misc.out

      0010  4   header 1 in
      0020  5   header 1 out    header 1 out
      0040  6   header 1 dir    header 1 dir
      0080  7

      0100  8   header 2 in
      0200  9   header 2 out    header 2 out
      0400  10  header 2 dir    header 2 dir
      0800  11

      1000  12  UART RX         UART TX
      2000  13  misc.in
      4000  14  ticks           clear ticks
      8000  15
  */

  assign io_din =

    (io_addr[ 0] ? { 8'd0, pmod_in}                                                 : 16'd0) |
    (io_addr[ 1] ? { 8'd0, pmod_out}                                                : 16'd0) |
    (io_addr[ 2] ? { 8'd0, pmod_dir}                                                : 16'd0) |
    (io_addr[ 3] ? { 5'd0, LEDS, PIOS}                                              : 16'd0) |

    (io_addr[ 4] ? { 8'd0, header1_in}                                              : 16'd0) |
    (io_addr[ 5] ? { 8'd0, header1_out}                                             : 16'd0) |
    (io_addr[ 6] ? { 8'd0, header1_dir}                                             : 16'd0) |


    (io_addr[ 8] ? { 8'd0, header2_in}                                              : 16'd0) |
    (io_addr[ 9] ? { 8'd0, header2_out}                                             : 16'd0) |
    (io_addr[10] ? { 8'd0, header2_dir}                                             : 16'd0) |


    (io_addr[12] ? { 8'd0, uart0_data}                                              : 16'd0) |
    (io_addr[13] ? {10'd0, random, RTS, PIO1_19, PIOS_01, uart0_valid, !uart0_busy} : 16'd0) |
    (io_addr[14] ?         ticks                                                    : 16'd0) ;

  // Very few gates needed: Simply trigger warmboot by any IO access to $8000 / $8001 / $8002 / $8003.
  // SB_WARMBOOT _sb_warmboot ( .BOOT(io_wr & io_addr[15]), .S1(io_addr[1]), .S0(io_addr[0]) );

  always @(posedge clk) begin

    if (io_wr & io_addr[1])  pmod_out <= io_dout[7:0];
    if (io_wr & io_addr[2])  pmod_dir <= io_dout[7:0];
    if (io_wr & io_addr[3])  {LEDS, PIOS} <= io_dout[10:0];

    if (io_wr & io_addr[5])  header1_out <= io_dout[7:0];
    if (io_wr & io_addr[6])  header1_dir <= io_dout[7:0];

    if (io_wr & io_addr[9])  header2_out <= io_dout[7:0];
    if (io_wr & io_addr[10]) header2_dir <= io_dout[7:0];

  end

endmodule // top
