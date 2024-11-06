
`default_nettype none

`include "../common-verilog/j1-universal-16kb-quickstore.v"

`include "../common-verilog/usb_cdc/usb_cdc.v"
`include "../common-verilog/usb_cdc/bulk_endp.v"
`include "../common-verilog/usb_cdc/ctrl_endp.v"
`include "../common-verilog/usb_cdc/phy_rx.v"
`include "../common-verilog/usb_cdc/phy_tx.v"
`include "../common-verilog/usb_cdc/sie.v"

`include "../common-verilog/ledcommflow.v"

module top (
    input clki, // 48 MHz clock input

    inout pmod_1, // Four user pins
    inout pmod_2,
    inout pmod_3,
    inout pmod_4,

    output rgb0, // LED outputs
    output rgb1,
    output rgb2,

    inout usb_dp, // USB pins
    inout usb_dn,
    output usb_dp_pu
);

  // ######   Clock   #########################################

  reg [1:0] divider;

  always @(posedge clki) divider <= divider + 1;

  wire clk_usb = clki;       // 48 MHz
  wire clk     = divider[1]; // 12 MHz

  // ######   Reset logic   ###################################

  wire button = 1'b1;

  reg [7:0] reset_cnt = 0;
  wire resetq = &reset_cnt;

  always @(posedge clk) begin
    if (button) reset_cnt <= reset_cnt + !resetq;
    else        reset_cnt <= 0;
  end

  // ######   Bus   ###########################################

  wire io_rd, io_wr;
  wire [15:0] io_addr;
  wire [15:0] io_dout;
  wire [15:0] io_din;

  reg interrupt = 0;

  // ######   Processor   #####################################

  j1 #( .MEMWORDS(7680) ) _j1( // 15 kb Memory

    .clk(clk),
    .resetq(resetq),

    .io_rd(io_rd),
    .io_wr(io_wr),
    .io_dout(io_dout),
    .io_din(io_din),
    .io_addr(io_addr),

    .interrupt_request(interrupt)
  );

  // ######   Ticks   #########################################

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

  // reg  [3:0] pmod_dir;   // 1:output, 0:input
  // reg  [3:0] pmod_out;
  // wire [3:0] pmod_in;
  //
  // SB_IO #(.PIN_TYPE(6'b1010_01)) io0 (.PACKAGE_PIN(pmod_1), .D_OUT_0(pmod_out[0]), .D_IN_0(pmod_in[0]), .OUTPUT_ENABLE(pmod_dir[0]));
  // SB_IO #(.PIN_TYPE(6'b1010_01)) io1 (.PACKAGE_PIN(pmod_2), .D_OUT_0(pmod_out[1]), .D_IN_0(pmod_in[1]), .OUTPUT_ENABLE(pmod_dir[1]));
  // SB_IO #(.PIN_TYPE(6'b1010_01)) io2 (.PACKAGE_PIN(pmod_3), .D_OUT_0(pmod_out[2]), .D_IN_0(pmod_in[2]), .OUTPUT_ENABLE(pmod_dir[2]));
  // SB_IO #(.PIN_TYPE(6'b1010_01)) io3 (.PACKAGE_PIN(pmod_4), .D_OUT_0(pmod_out[3]), .D_IN_0(pmod_in[3]), .OUTPUT_ENABLE(pmod_dir[3]));

  // ######   Ledcomm   #######################################

  wire    red_cathode;
  wire yellow_cathode;

  assign pmod_1 = ledcomm_anode_out & ledcomm_yellow;
  SB_IO #(.PIN_TYPE(6'b1010_01)) iol0 (.PACKAGE_PIN(pmod_2), .D_OUT_0(ledcomm_cathode_out), .D_IN_0(yellow_cathode), .OUTPUT_ENABLE(ledcomm_cathode_dir));

  assign pmod_4 = ledcomm_anode_out & ledcomm_red;
  SB_IO #(.PIN_TYPE(6'b1010_01)) iol1 (.PACKAGE_PIN(pmod_3), .D_OUT_0(ledcomm_cathode_out), .D_IN_0(   red_cathode), .OUTPUT_ENABLE(ledcomm_cathode_dir));

  reg ledcomm_darkness = 1;
  reg ledcomm_reset    = 1;
  reg ledcomm_yellow   = 0;
  reg ledcomm_red      = 0;

  reg [15:0] ledcomm_timebase = 16'd2928; // Default: 2928 / 12 MHz = 244 us = 8 / 32768 Hz
  reg [15:0] ledcomm_charging =   16'd12; // Default:   12 / 12 MHz =   1 us

  wire ledcomm_anode_out;
  wire ledcomm_cathode_in = ~( (~red_cathode & ledcomm_red) | (~yellow_cathode & ledcomm_yellow) );
  wire ledcomm_cathode_out;
  wire ledcomm_cathode_dir;

  wire ledcomm_wr = io_wr & io_addr[4];
  wire ledcomm_rd = io_rd & io_addr[4];

  wire [15:0] ledcomm_data;

  wire ledcomm_busy;
  wire ledcomm_valid;
  wire ledcomm_link;

  ledcommflow _ledcomm(

  .Anode_OUT  (ledcomm_anode_out  ),
  .Kathode_IN (ledcomm_cathode_in ),
  .Kathode_OUT(ledcomm_cathode_out),
  .Kathode_DIR(ledcomm_cathode_dir),

  .clk(clk),
  .resetq(resetq & ~ledcomm_reset),

  .wr(ledcomm_wr),
  .rd(ledcomm_rd),
  .tx_data(io_dout),
  .rx_data(ledcomm_data),
  .busy(ledcomm_busy),
  .valid(ledcomm_valid),

  .Verbindungbesteht(ledcomm_link), // Haben wir gerade eine funktionierende Verbindung ?

  .Dunkelheit(ledcomm_darkness),    // Wenn das Bit gesetzt ist, wird im Dunkelen gewartet,
                                    // ansonsten werden helle Synchronisationspulse abgestrahlt.
  .Basiszeit(ledcomm_timebase),     // Zahl der Taktzyklen für eine Basiszeit
  .Ladezeit(ledcomm_charging)       // Zahl der Taktzyklen fürs Laden der Kathode
);

  // ######   SRAM   ##########################################

  reg  [15:0] sram_addr;

  wire sram_wr = io_wr & io_addr[7];

  wire [15:0] sram_in_bank0, sram_in_bank1, sram_in_bank2, sram_in_bank3;

    SB_SPRAM256KA rambank0 (
        .DATAIN(io_dout),
        .ADDRESS(sram_addr[13:0]),
        .MASKWREN(4'b1111),
        .WREN(sram_wr),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(~(sram_addr[15:14] == 2'b00)),
        .POWEROFF(1'b1),
        .DATAOUT(sram_in_bank0)
);

    SB_SPRAM256KA rambank1 (
        .DATAIN(io_dout),
        .ADDRESS(sram_addr[13:0]),
        .MASKWREN(4'b1111),
        .WREN(sram_wr),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(~(sram_addr[15:14] == 2'b01)),
        .POWEROFF(1'b1),
        .DATAOUT(sram_in_bank1)
);

    SB_SPRAM256KA rambank2 (
        .DATAIN(io_dout),
        .ADDRESS(sram_addr[13:0]),
        .MASKWREN(4'b1111),
        .WREN(sram_wr),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(~(sram_addr[15:14] == 2'b10)),
        .POWEROFF(1'b1),
        .DATAOUT(sram_in_bank2)
);

    SB_SPRAM256KA rambank3 (
        .DATAIN(io_dout),
        .ADDRESS(sram_addr[13:0]),
        .MASKWREN(4'b1111),
        .WREN(sram_wr),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(~(sram_addr[15:14] == 2'b11)),
        .POWEROFF(1'b1),
        .DATAOUT(sram_in_bank3)
);

  wire [15:0] sram_in = sram_in_bank3 | sram_in_bank2 | sram_in_bank1 | sram_in_bank0;

  // ######   USB-CDC terminal   ##############################

  assign usb_dp_pu = resetq;

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

    // Part running on 12 MHz:

    .app_clk_i(clk),
    .rstn_i(resetq),

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

  // ######   Blink   #########################################

  // Instantiate iCE40 LED driver hard logic.
  //
  // Note that it's possible to drive the LEDs directly,
  // however that is not current-limited and results in
  // overvolting the red LED.
  //
  // See also:
  // https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/ICE40LEDDriverUsageGuide.ashx?document_id=50668

  reg [2:0] LEDS;

  SB_RGBA_DRV #(
      .CURRENT_MODE("0b1"),       // half current
      .RGB0_CURRENT("0b000011"),  // 4 mA
      .RGB1_CURRENT("0b000011"),  // 4 mA
      .RGB2_CURRENT("0b000011")   // 4 mA
  ) RGBA_DRIVER (
      .CURREN(1'b1),
      .RGBLEDEN(1'b1),
      .RGB1PWM(LEDS[0]),     // Red
      .RGB0PWM(LEDS[1]),     // Green
      .RGB2PWM(LEDS[2]),     // Blue
      .RGB0(rgb0),
      .RGB1(rgb1),
      .RGB2(rgb2)
  );

  // ######   IO Ports   ######################################

  /*        Bit READ            WRITE

    + ...0                      Write as usual
    + ...1                      _C_lear bits
    + ...2                      _S_et bits
    + ...3                      _T_oggle bits

      0008  3   LEDS            LEDS (cst)

      0010  4   Ledcomm RX      Ledcomm TX
      0020  5   Ledcomm Flags   Ledcomm Config
      0040  6
      0080  7   SRAM read       SRAM write

      0100  8   Timebase        Timebase
      0200  9   Charging        Charging
      0400  10
      0800  11  SRAM addr       SRAM addr

      1000  12  UART RX         UART TX
      2000  13  UART Flags
      4000  14  Ticks           Set Ticks
      8000  15
  */

  assign io_din =

    (io_addr[ 3] ? {13'd0, LEDS}                                                    : 16'd0) |

    (io_addr[ 4] ?         ledcomm_data                                             : 16'd0) |
    (io_addr[ 5] ?       { ledcomm_reset, 3'b0,
                           2'b0, ledcomm_yellow, ledcomm_red,
                           3'b0, ledcomm_darkness,
                           1'b0, ledcomm_link, ledcomm_valid, ~ledcomm_busy }       : 16'd0) |

    (io_addr[ 7] ?         sram_in                                                  : 16'd0) |

    (io_addr[ 8] ?         ledcomm_timebase                                         : 16'd0) |
    (io_addr[ 9] ?         ledcomm_charging                                         : 16'd0) |

    (io_addr[11] ?         sram_addr                                                : 16'd0) |

    (io_addr[12] ? { 8'd0, terminal_data}                                           : 16'd0) |
    (io_addr[13] ? {13'd0, random, terminal_valid, terminal_ready}                  : 16'd0) |
    (io_addr[14] ?         ticks                                                    : 16'd0) ;

  always @(posedge clk) begin

    if (io_wr & io_addr[3] & (io_addr[1:0] == 0))  LEDS  <=           io_dout;
    if (io_wr & io_addr[3] & (io_addr[1:0] == 1))  LEDS  <=  LEDS  & ~io_dout; // Clear
    if (io_wr & io_addr[3] & (io_addr[1:0] == 2))  LEDS  <=  LEDS  |  io_dout; // Set
    if (io_wr & io_addr[3] & (io_addr[1:0] == 3))  LEDS  <=  LEDS  ^  io_dout; // Invert

    if (io_wr & io_addr[5]) begin
                              ledcomm_reset    <= io_dout[15];
                              ledcomm_yellow   <= io_dout[9];
                              ledcomm_red      <= io_dout[8];
                              ledcomm_darkness <= io_dout[4];
                            end

    if (io_wr & io_addr[8]) ledcomm_timebase <= io_dout;
    if (io_wr & io_addr[9]) ledcomm_charging <= io_dout;

    if (io_wr & io_addr[11]) sram_addr <= io_dout;
  end

endmodule
