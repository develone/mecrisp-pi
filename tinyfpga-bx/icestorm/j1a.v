
`default_nettype none

`include "../common-verilog/j1-universal-16kb-quickstore.v"

`include "../common-verilog/usb_cdc/usb_cdc.v"
`include "../common-verilog/usb_cdc/bulk_endp.v"
`include "../common-verilog/usb_cdc/ctrl_endp.v"
`include "../common-verilog/usb_cdc/phy_rx.v"
`include "../common-verilog/usb_cdc/phy_tx.v"
`include "../common-verilog/usb_cdc/sie.v"

module top(
          input oscillator,

          inout  usb_dp, // USB pins
          inout  usb_dn,
          output usb_dp_pu,

          // LED
          output LED,

          // Flash SPI
          output SCLK,    // Flash SCK
          input  MISO,     // Flash MISO
          output MOSI,    // Flash MOSI
          output SS,    // Flash CS

          // General purpose 16bit port
          inout PORTA0,
          inout PORTA1,
          inout PORTA2,
          inout PORTA3,
          inout PORTA4,
          inout PORTA5,
          inout PORTA6,
          inout PORTA7,
          inout PORTA8,
          inout PORTA9,
          inout PORTA10,
          inout PORTA11,
          inout PORTA12,
          inout PORTA13,
          inout PORTA14,
          inout PORTA15,

);


  // ######   Clock   #########################################

  reg clk;

  always @(posedge clk_usb)
    clk <= ~clk;      // clk at 24 MHz

  wire clk_usb ;       // 48 MHz

  //PLL configuration
  wire locked;

  // Use an icepll generated pll
  pll pll48( .clock_in(oscillator), .clock_out(clk_usb), .locked( locked ) );

  // ######   Reset logic   ###################################

   // Generate reset signal
  reg [5:0] reset_cnt = 0;
  wire reset = ~reset_cnt[5];
  always @(posedge clk)
      if ( locked )
          reset_cnt <= reset_cnt + reset;


  // ######   Bus    ##########################################

  wire io_rd, io_wr;
  wire [15:0] io_addr;
  wire [15:0] io_dout;
  wire [15:0] io_din;

  reg interrupt = 0;

  // ######   LED         #####################################

  reg [25:0] ledcnt;

  always @(posedge clk)
    ledcnt <= ledcnt +1;

  assign LED = ledcnt[25];


  // ######   PROCESSOR   #####################################

  j1 _j1(
    .clk(clk),
    .resetq(~reset),

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

    // ######   Cycles   ########################################

   reg [15:0] cycles;

   always @(posedge clk) cycles <= cycles + 1;


 // ######   USB-CDC terminal   ##############################

  assign usb_dp_pu = ~reset;

  wire usb_p_tx;
  wire usb_n_tx;
  wire usb_p_rx;
  wire usb_n_rx;
  wire usb_tx_en;

   SB_IO #(
       .PIN_TYPE(6'b 1010_01), // PIN_OUTPUT_TRISTATE - PIN_INPUT
       .PULLUP(1'b 0)
   ) iobuf_usbp (
       .PACKAGE_PIN(usb_dp),
       .OUTPUT_ENABLE(usb_tx_en),
       .D_OUT_0(usb_p_tx),
       .D_IN_0(usb_p_rx)
   );

   SB_IO #(
       .PIN_TYPE(6'b 1010_01), // PIN_OUTPUT_TRISTATE - PIN_INPUT
       .PULLUP(1'b 0)
   ) iobuf_usbn (
       .PACKAGE_PIN(usb_dn),
       .OUTPUT_ENABLE(usb_tx_en),
       .D_OUT_0(usb_n_tx),
       .D_IN_0(usb_n_rx)
   );


  usb_cdc #(.VENDORID(16'h0483), .PRODUCTID(16'h5740), .BIT_SAMPLES(4), .USE_APP_CLK(1), .APP_CLK_RATIO(4)) _terminal
  (
    // Part running on 48 MHz:

    .clk_i(clk_usb),
    .tx_en_o(usb_tx_en),
    .tx_dp_o(usb_p_tx),
    .tx_dn_o(usb_n_tx),
    .rx_dp_i(usb_p_rx),
    .rx_dn_i(usb_n_rx),

    // Part running on 24 MHz:

    .app_clk_i(clk),
    .rstn_i(~reset),

    .out_data_o(terminal_data),
    .out_valid_o(terminal_valid),
    .out_ready_i(terminal_rd),

    .in_data_i(io_dout[7:0]),
    .in_ready_o(terminal_ready),
    .in_valid_i(terminal_wr)
  );

  wire terminal_valid, terminal_ready;
  wire [7:0] terminal_data;
  wire terminal_wr = io_wr & io_addr[12];
  wire terminal_rd = io_rd & io_addr[12];

  /// ######   PORTA   ###########################################

  reg  [15:0] porta_dir;   // 1:output, 0:input
  reg  [15:0] porta_out;
  wire [15:0] porta_in;

  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa0  (.PACKAGE_PIN(PORTA0),  .D_OUT_0(porta_out[0]),  .D_IN_0(porta_in[0]),  .OUTPUT_ENABLE(porta_dir[0]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa1  (.PACKAGE_PIN(PORTA1),  .D_OUT_0(porta_out[1]),  .D_IN_0(porta_in[1]),  .OUTPUT_ENABLE(porta_dir[1]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa2  (.PACKAGE_PIN(PORTA2),  .D_OUT_0(porta_out[2]),  .D_IN_0(porta_in[2]),  .OUTPUT_ENABLE(porta_dir[2]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa3  (.PACKAGE_PIN(PORTA3),  .D_OUT_0(porta_out[3]),  .D_IN_0(porta_in[3]),  .OUTPUT_ENABLE(porta_dir[3]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa4  (.PACKAGE_PIN(PORTA4),  .D_OUT_0(porta_out[4]),  .D_IN_0(porta_in[4]),  .OUTPUT_ENABLE(porta_dir[4]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa5  (.PACKAGE_PIN(PORTA5),  .D_OUT_0(porta_out[5]),  .D_IN_0(porta_in[5]),  .OUTPUT_ENABLE(porta_dir[5]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa6  (.PACKAGE_PIN(PORTA6),  .D_OUT_0(porta_out[6]),  .D_IN_0(porta_in[6]),  .OUTPUT_ENABLE(porta_dir[6]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa7  (.PACKAGE_PIN(PORTA7),  .D_OUT_0(porta_out[7]),  .D_IN_0(porta_in[7]),  .OUTPUT_ENABLE(porta_dir[7]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa8  (.PACKAGE_PIN(PORTA8),  .D_OUT_0(porta_out[8]),  .D_IN_0(porta_in[8]),  .OUTPUT_ENABLE(porta_dir[8]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa9  (.PACKAGE_PIN(PORTA9),  .D_OUT_0(porta_out[9]),  .D_IN_0(porta_in[9]),  .OUTPUT_ENABLE(porta_dir[9]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa10 (.PACKAGE_PIN(PORTA10), .D_OUT_0(porta_out[10]), .D_IN_0(porta_in[10]), .OUTPUT_ENABLE(porta_dir[10]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa11 (.PACKAGE_PIN(PORTA11), .D_OUT_0(porta_out[11]), .D_IN_0(porta_in[11]), .OUTPUT_ENABLE(porta_dir[11]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa12 (.PACKAGE_PIN(PORTA12), .D_OUT_0(porta_out[12]), .D_IN_0(porta_in[12]), .OUTPUT_ENABLE(porta_dir[12]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa13 (.PACKAGE_PIN(PORTA13), .D_OUT_0(porta_out[13]), .D_IN_0(porta_in[13]), .OUTPUT_ENABLE(porta_dir[13]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa14 (.PACKAGE_PIN(PORTA14), .D_OUT_0(porta_out[14]), .D_IN_0(porta_in[14]), .OUTPUT_ENABLE(porta_dir[14]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa15 (.PACKAGE_PIN(PORTA15), .D_OUT_0(porta_out[15]), .D_IN_0(porta_in[15]), .OUTPUT_ENABLE(porta_dir[15]));


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

  /*        bit READ (into FPGA)    WRITE

      0001  0   porta_in
      0002  1   porta_out       porta_out
      0004  2   porta_dir       porta_dir
      0008  3   spi             spi

      1000  12  UART RX         UART TX
      2000  13  spi,uart
      4000  14  ticks           clear ticks
      8000  15  cycles
  */


  assign io_din =
    (io_addr[ 0] ?         porta_in                                                 : 16'd0) |
    (io_addr[ 1] ?         porta_out                                                : 16'd0) |
    (io_addr[ 2] ?         porta_dir                                                : 16'd0) |
    (io_addr[ 3] ? { 13'd0, SCLK, MOSI, SS}                                         : 16'd0) |

    (io_addr[12] ? { 8'd0, terminal_data}                                           : 16'd0) |
    (io_addr[13] ? {10'd0, random, 2'd0, MISO, terminal_valid, terminal_ready}      : 16'd0) |
    (io_addr[14] ?         ticks                                                    : 16'd0) |
    (io_addr[15] ?         cycles                                                   : 16'd0) ;


  // Very few gates needed: Simply trigger warmboot by any IO access to $8000 / $8001 / $8002 / $8003.
  // SB_WARMBOOT _sb_warmboot ( .BOOT(io_wr & io_addr[15]), .S1(io_addr[1]), .S0(io_addr[0]) );

  always @(posedge clk) begin
    // No ports for now
    if (io_wr & io_addr[1])  porta_out <= io_dout;
    if (io_wr & io_addr[2])  porta_dir <= io_dout;
    if (io_wr & io_addr[3])  {SCLK, MOSI, SS} <= io_dout[2:0];
  end

endmodule // top
