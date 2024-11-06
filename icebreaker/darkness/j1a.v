
`default_nettype none

`define cfg_divider       208  // 24 MHz / 115200 = 208.33

`include "../common-verilog/uart-fifo.v"
`include "../common-verilog/j1-universal-16kb-quickstore.v"
`include "../common-verilog/omsp_sync_cell.v"

module top(input oscillator,

           output D1,
           output D2,

           output TXD,        // UART TX
           input  RXD,        // UART RX

           output flash_csb,
           output flash_clk,
           output flash_io0,  // MOSI
           input  flash_io1,  // MISO
           output flash_io2,
           output flash_io3,

           inout PORTA0,
           inout PORTA1,
           inout PORTA2,
           inout PORTA3,
           inout PORTA4,
           inout PORTA5,
           inout PORTA6,
           inout PORTA7,

           inout PORTB0,
           inout PORTB1,
           inout PORTB2,
           inout PORTB3,
           inout PORTB4,
           inout PORTB5,
           inout PORTB6,
           inout PORTB7,

           inout PORTC0,
           inout PORTC1,
           inout PORTC2,
           inout PORTC3,
           inout PORTC4,
           inout PORTC5,
           inout PORTC6,
           inout PORTC7,

           input reset_button,
);

  // ######   Clock   #########################################

  wire clk;

  SB_PLL40_PAD  #(.FEEDBACK_PATH("SIMPLE"),
                  .PLLOUT_SELECT("GENCLK"),
                  .DIVR(0),
                  .DIVF(63),
                  .DIVQ(5),
                  .FILTER_RANGE(1),
                 ) pll (
                         .PACKAGEPIN(oscillator),
                         .PLLOUTCORE(clk),
                         .RESETB(1'b1),
                         .BYPASS(1'b0)
                        );

  // ######   Reset logic   ###################################

  reg [5:0] reset_cnt = 0;
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

  // ######   TICKS   #########################################

  reg [15:0] ticks;

  wire [16:0] ticks_plus_1 = ticks + 1;

  always @(posedge clk)
    if (io_wr & io_addr[14])
      ticks <= io_dout;
    else
      ticks <= ticks_plus_1;

  wire irq_ticks = ticks_plus_1[16]; // Generate interrupt on ticks overflow

  // ######   PORTA   ###########################################

  reg  [7:0] porta_dir;   // 1:output, 0:input
  reg  [7:0] porta_out;
  wire [7:0] porta_in_async;

  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa0  (.PACKAGE_PIN(PORTA0),  .D_OUT_0(porta_out[0]),  .D_IN_0(porta_in_async[0]),  .OUTPUT_ENABLE(porta_dir[0]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa1  (.PACKAGE_PIN(PORTA1),  .D_OUT_0(porta_out[1]),  .D_IN_0(porta_in_async[1]),  .OUTPUT_ENABLE(porta_dir[1]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa2  (.PACKAGE_PIN(PORTA2),  .D_OUT_0(porta_out[2]),  .D_IN_0(porta_in_async[2]),  .OUTPUT_ENABLE(porta_dir[2]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa3  (.PACKAGE_PIN(PORTA3),  .D_OUT_0(porta_out[3]),  .D_IN_0(porta_in_async[3]),  .OUTPUT_ENABLE(porta_dir[3]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa4  (.PACKAGE_PIN(PORTA4),  .D_OUT_0(porta_out[4]),  .D_IN_0(porta_in_async[4]),  .OUTPUT_ENABLE(porta_dir[4]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa5  (.PACKAGE_PIN(PORTA5),  .D_OUT_0(porta_out[5]),  .D_IN_0(porta_in_async[5]),  .OUTPUT_ENABLE(porta_dir[5]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa6  (.PACKAGE_PIN(PORTA6),  .D_OUT_0(porta_out[6]),  .D_IN_0(porta_in_async[6]),  .OUTPUT_ENABLE(porta_dir[6]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioa7  (.PACKAGE_PIN(PORTA7),  .D_OUT_0(porta_out[7]),  .D_IN_0(porta_in_async[7]),  .OUTPUT_ENABLE(porta_dir[7]));

  // Synchronised input

  wire [7:0] porta_in;

  omsp_sync_cell porta_synchronisers [7:0] ( .data_in(porta_in_async), .data_out(porta_in), .clk(clk), .rst(!resetq) );

  reg [7:0] porta_ifg;
  reg [7:0] porta_ies;
  reg [7:0] porta_ie;

  // Delayed input

  reg [7:0] porta_in_delay;
  always @(posedge clk) porta_in_delay <= porta_in;

  // Edge detection

  wire [7:0] porta_in_re =  porta_in & ~porta_in_delay;  // Rising Edge
  wire [7:0] porta_in_fe = ~porta_in &  porta_in_delay;  // Falling Edge

  // Set interrupt flags

  wire [7:0] porta_ifg_set = (porta_ies & porta_in_fe) | (~porta_ies & porta_in_re);
  wire irq_porta = |(porta_ie & porta_ifg);

//   // ######   PORTB   ###########################################
//
//   reg  [7:0] portb_dir;   // 1:output, 0:input
//   reg  [7:0] portb_out;
//   wire [7:0] portb_in_async;
//
//   SB_IO #(.PIN_TYPE(6'b1010_01)) iob0  (.PACKAGE_PIN(PORTB0),  .D_OUT_0(portb_out[0]),  .D_IN_0(portb_in_async[0]),  .OUTPUT_ENABLE(portb_dir[0]));
//   SB_IO #(.PIN_TYPE(6'b1010_01)) iob1  (.PACKAGE_PIN(PORTB1),  .D_OUT_0(portb_out[1]),  .D_IN_0(portb_in_async[1]),  .OUTPUT_ENABLE(portb_dir[1]));
//   SB_IO #(.PIN_TYPE(6'b1010_01)) iob2  (.PACKAGE_PIN(PORTB2),  .D_OUT_0(portb_out[2]),  .D_IN_0(portb_in_async[2]),  .OUTPUT_ENABLE(portb_dir[2]));
//   SB_IO #(.PIN_TYPE(6'b1010_01)) iob3  (.PACKAGE_PIN(PORTB3),  .D_OUT_0(portb_out[3]),  .D_IN_0(portb_in_async[3]),  .OUTPUT_ENABLE(portb_dir[3]));
//   SB_IO #(.PIN_TYPE(6'b1010_01)) iob4  (.PACKAGE_PIN(PORTB4),  .D_OUT_0(portb_out[4]),  .D_IN_0(portb_in_async[4]),  .OUTPUT_ENABLE(portb_dir[4]));
//   SB_IO #(.PIN_TYPE(6'b1010_01)) iob5  (.PACKAGE_PIN(PORTB5),  .D_OUT_0(portb_out[5]),  .D_IN_0(portb_in_async[5]),  .OUTPUT_ENABLE(portb_dir[5]));
//   SB_IO #(.PIN_TYPE(6'b1010_01)) iob6  (.PACKAGE_PIN(PORTB6),  .D_OUT_0(portb_out[6]),  .D_IN_0(portb_in_async[6]),  .OUTPUT_ENABLE(portb_dir[6]));
//   SB_IO #(.PIN_TYPE(6'b1010_01)) iob7  (.PACKAGE_PIN(PORTB7),  .D_OUT_0(portb_out[7]),  .D_IN_0(portb_in_async[7]),  .OUTPUT_ENABLE(portb_dir[7]));
//
//   // Synchronised input
//
//   wire [7:0] portb_in;
//
//   omsp_sync_cell portb_synchronisers [7:0] ( .data_in(portb_in_async), .data_out(portb_in), .clk(clk), .rst(!resetq) );
//
//   reg [7:0] portb_ifg;
//   reg [7:0] portb_ies;
//   reg [7:0] portb_ie;
//
//   // Delayed input
//
//   reg [7:0] portb_in_delay;
//   always @(posedge clk) portb_in_delay <= portb_in;
//
//   // Edge detection
//
//   wire [7:0] portb_in_re =  portb_in & ~portb_in_delay;  // Rising Edge
//   wire [7:0] portb_in_fe = ~portb_in &  portb_in_delay;  // Falling Edge
//
//   // Set interrupt flags
//
//   wire [7:0] portb_ifg_set = (portb_ies & portb_in_fe) | (~portb_ies & portb_in_re);
//   wire irq_portb = |(portb_ie & portb_ifg);
//
  // ######   PORTC   ###########################################

  reg  [7:0] portc_dir;   // 1:output, 0:input
  reg  [7:0] portc_out;
  wire [7:0] portc_in_async;

  SB_IO #(.PIN_TYPE(6'b1010_01)) ioc0  (.PACKAGE_PIN(PORTC0),  .D_OUT_0(portc_out[0]),  .D_IN_0(portc_in_async[0]),  .OUTPUT_ENABLE(portc_dir[0]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioc1  (.PACKAGE_PIN(PORTC1),  .D_OUT_0(portc_out[1]),  .D_IN_0(portc_in_async[1]),  .OUTPUT_ENABLE(portc_dir[1]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioc2  (.PACKAGE_PIN(PORTC2),  .D_OUT_0(portc_out[2]),  .D_IN_0(portc_in_async[2]),  .OUTPUT_ENABLE(portc_dir[2]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioc3  (.PACKAGE_PIN(PORTC3),  .D_OUT_0(portc_out[3]),  .D_IN_0(portc_in_async[3]),  .OUTPUT_ENABLE(portc_dir[3]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioc4  (.PACKAGE_PIN(PORTC4),  .D_OUT_0(portc_out[4]),  .D_IN_0(portc_in_async[4]),  .OUTPUT_ENABLE(portc_dir[4]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioc5  (.PACKAGE_PIN(PORTC5),  .D_OUT_0(portc_out[5]),  .D_IN_0(portc_in_async[5]),  .OUTPUT_ENABLE(portc_dir[5]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioc6  (.PACKAGE_PIN(PORTC6),  .D_OUT_0(portc_out[6]),  .D_IN_0(portc_in_async[6]),  .OUTPUT_ENABLE(portc_dir[6]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) ioc7  (.PACKAGE_PIN(PORTC7),  .D_OUT_0(portc_out[7]),  .D_IN_0(portc_in_async[7]),  .OUTPUT_ENABLE(portc_dir[7]));

  // Synchronised input

  wire [7:0] portc_in;

  omsp_sync_cell portc_synchronisers [7:0] ( .data_in(portc_in_async), .data_out(portc_in), .clk(clk), .rst(!resetq) );

  reg [7:0] portc_ifg;
  reg [7:0] portc_ies;
  reg [7:0] portc_ie;

  // Delayed input

  reg [7:0] portc_in_delay;
  always @(posedge clk) portc_in_delay <= portc_in;

  // Edge detection

  wire [7:0] portc_in_re =  portc_in & ~portc_in_delay;  // Rising Edge
  wire [7:0] portc_in_fe = ~portc_in &  portc_in_delay;  // Falling Edge

  // Set interrupt flags

  wire [7:0] portc_ifg_set = (portc_ies & portc_in_fe) | (~portc_ies & portc_in_re);
  wire irq_portc = |(portc_ie & portc_ifg);

  // ######   SRAM   ############################################

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

  wire flash_dangling_high = 1;
  assign flash_io2 = flash_dangling_high;
  assign flash_io3 = flash_dangling_high;

  reg [2:0] PIOS;
  assign {flash_clk, flash_io0, flash_csb} = PIOS;
  reg [1:0] LEDS;
  // Active low LEDs
  assign D1 = ~LEDS[0];
  assign D2 = ~LEDS[1];

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

  // ######   Interrupts   ####################################

  reg [15:0] interrupt_enable = 16'hFF00;

  wire [7:0] volatile_irqs;   // Interrupts which keep activated in peripherals
  reg  [7:0] sticky_irqs = 0; // For one shot interrupts which need to be preserved
  wire [7:0] set_sticky_irqs;

  assign volatile_irqs = {4'd0, irq_ticks, irq_portc, 1'b0, irq_porta};
  assign set_sticky_irqs = {7'd0, irq_ticks};

  always @(posedge clk) interrupt <= (|(volatile_irqs & interrupt_enable[15:8])) | (|(sticky_irqs & interrupt_enable[7:0]));



  // *********************************************************************************************************************

  // ######   Leuchtdiodenmesszelle   ###############################

  wire [1:0] led01_in;
  reg  [1:0] led01_out;
  reg  [2:0] led01_dir;  // 3: Timer löschen | 2: Timer zählt | 1: Kathode | 0: Anode

  reg [31:0] led01_timer;
  SB_IO #(.PIN_TYPE(6'b1010_01)) dunkel1a  (.PACKAGE_PIN(PORTB4),  .D_OUT_0(led01_out[0]),  .D_IN_0(led01_in[0]),  .OUTPUT_ENABLE(led01_dir[0]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) dunkel1k  (.PACKAGE_PIN(PORTB0),  .D_OUT_0(led01_out[1]),  .D_IN_0(led01_in[1]),  .OUTPUT_ENABLE(led01_dir[1]));

  // ######   Dunkelmeter   ###################################

  // Idee zum Ausprobieren: "Timersteuerbits": Löschen, Timer zählt. Dann gibt es keine elektrischen Störungen beim Stoppen !
  // Spieß umdrehen: Timer zählen runter und stoppen bei Null oder zählen hoch und stoppen bei einem festen Wert ?
  // Alles in einen Steuerregister vereinigen ? Dann kann ich schneller schalten !

  // Jetzt erstmal raufzählen und bei Bedarf löschen. Erster Versuch !

  always @(posedge clk) begin

    if (io_wr & (io_addr == 16'h8012)) led01_out <= io_dout[1:0];

    if (io_wr & (io_addr == 16'h8013))
    begin
      led01_dir <= io_dout[2:0];
      if (io_dout[3]) led01_timer <= 0; // Timer-Löschbit
    end
    else led01_timer <= led01_timer + (~led01_in[0] & led01_dir[2]); // Zähle, solange die Anode low und der Timer aktiv ist.
 // else led01_timer <= led01_timer + (led01_in[1] & led01_dir[2]); // Zähle, solange die Kathode high und der Timer aktiv ist.

  end

  // *********************************************************************************************************************


  // ######   Leuchtdiodenmesszelle   ###############################

  wire [1:0] led02_in;
  reg  [1:0] led02_out;
  reg  [2:0] led02_dir;  // 3: Timer löschen | 2: Timer zählt | 1: Kathode | 0: Anode

  reg [31:0] led02_timer;
  SB_IO #(.PIN_TYPE(6'b1010_01)) dunkel2a  (.PACKAGE_PIN(PORTB5),  .D_OUT_0(led02_out[0]),  .D_IN_0(led02_in[0]),  .OUTPUT_ENABLE(led02_dir[0]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) dunkel2k  (.PACKAGE_PIN(PORTB1),  .D_OUT_0(led02_out[1]),  .D_IN_0(led02_in[1]),  .OUTPUT_ENABLE(led02_dir[1]));

  // ######   Dunkelmeter   ###################################

  // Idee zum Ausprobieren: "Timersteuerbits": Löschen, Timer zählt. Dann gibt es keine elektrischen Störungen beim Stoppen !
  // Spieß umdrehen: Timer zählen runter und stoppen bei Null oder zählen hoch und stoppen bei einem festen Wert ?
  // Alles in einen Steuerregister vereinigen ? Dann kann ich schneller schalten !

  // Jetzt erstmal raufzählen und bei Bedarf löschen. Erster Versuch !

  always @(posedge clk) begin

    if (io_wr & (io_addr == 16'h8022)) led02_out <= io_dout[1:0];

    if (io_wr & (io_addr == 16'h8023))
    begin
      led02_dir <= io_dout[2:0];
      if (io_dout[3]) led02_timer <= 0; // Timer-Löschbit
    end
    else led02_timer <= led02_timer + (~led02_in[0] & led02_dir[2]); // Zähle, solange die Anode low und der Timer aktiv ist.
 // else led02_timer <= led02_timer + (led02_in[1] & led02_dir[2]); // Zähle, solange die Kathode high und der Timer aktiv ist.

  end

  // *********************************************************************************************************************

  // ######   Leuchtdiodenmesszelle   ###############################

  wire [1:0] led03_in;
  reg  [1:0] led03_out;
  reg  [2:0] led03_dir;  // 3: Timer löschen | 2: Timer zählt | 1: Kathode | 0: Anode

  reg [31:0] led03_timer;
  SB_IO #(.PIN_TYPE(6'b1010_01)) dunkel3a  (.PACKAGE_PIN(PORTB6),  .D_OUT_0(led03_out[0]),  .D_IN_0(led03_in[0]),  .OUTPUT_ENABLE(led03_dir[0]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) dunkel3k  (.PACKAGE_PIN(PORTB2),  .D_OUT_0(led03_out[1]),  .D_IN_0(led03_in[1]),  .OUTPUT_ENABLE(led03_dir[1]));

  // ######   Dunkelmeter   ###################################

  // Idee zum Ausprobieren: "Timersteuerbits": Löschen, Timer zählt. Dann gibt es keine elektrischen Störungen beim Stoppen !
  // Spieß umdrehen: Timer zählen runter und stoppen bei Null oder zählen hoch und stoppen bei einem festen Wert ?
  // Alles in einen Steuerregister vereinigen ? Dann kann ich schneller schalten !

  // Jetzt erstmal raufzählen und bei Bedarf löschen. Erster Versuch !

  always @(posedge clk) begin

    if (io_wr & (io_addr == 16'h8032)) led03_out <= io_dout[1:0];

    if (io_wr & (io_addr == 16'h8033))
    begin
      led03_dir <= io_dout[2:0];
      if (io_dout[3]) led03_timer <= 0; // Timer-Löschbit
    end
    else led03_timer <= led03_timer + (~led03_in[0] & led03_dir[2]); // Zähle, solange die Anode low und der Timer aktiv ist.
 // else led03_timer <= led03_timer + (led03_in[1] & led03_dir[2]); // Zähle, solange die Kathode high und der Timer aktiv ist.

  end

  // *********************************************************************************************************************

  // ######   Leuchtdiodenmesszelle   ###############################

  wire [1:0] led04_in;
  reg  [1:0] led04_out;
  reg  [2:0] led04_dir;  // 3: Timer löschen | 2: Timer zählt | 1: Kathode | 0: Anode

  reg [31:0] led04_timer;
  SB_IO #(.PIN_TYPE(6'b1010_01)) dunkel4a  (.PACKAGE_PIN(PORTB7),  .D_OUT_0(led04_out[0]),  .D_IN_0(led04_in[0]),  .OUTPUT_ENABLE(led04_dir[0]));
  SB_IO #(.PIN_TYPE(6'b1010_01)) dunkel4k  (.PACKAGE_PIN(PORTB3),  .D_OUT_0(led04_out[1]),  .D_IN_0(led04_in[1]),  .OUTPUT_ENABLE(led04_dir[1]));

  // ######   Dunkelmeter   ###################################

  // Idee zum Ausprobieren: "Timersteuerbits": Löschen, Timer zählt. Dann gibt es keine elektrischen Störungen beim Stoppen !
  // Spieß umdrehen: Timer zählen runter und stoppen bei Null oder zählen hoch und stoppen bei einem festen Wert ?
  // Alles in einen Steuerregister vereinigen ? Dann kann ich schneller schalten !

  // Jetzt erstmal raufzählen und bei Bedarf löschen. Erster Versuch !

  always @(posedge clk) begin

    if (io_wr & (io_addr == 16'h8042)) led04_out <= io_dout[1:0];

    if (io_wr & (io_addr == 16'h8043))
    begin
      led04_dir <= io_dout[2:0];
      if (io_dout[3]) led04_timer <= 0; // Timer-Löschbit
    end
    else led04_timer <= led04_timer + (~led04_in[0] & led04_dir[2]); // Zähle, solange die Anode low und der Timer aktiv ist.
 // else led04_timer <= led04_timer + (led04_in[1] & led04_dir[2]); // Zähle, solange die Kathode high und der Timer aktiv ist.

  end

  // *********************************************************************************************************************


  // ######   IO PORTS   ######################################

  /*        Bit READ            WRITE

      0001  0   IN                          Input
      0002  1   OUT             OUT         Output
      0004  2   DIR             DIR         Direction

      0010  4   IFG             IFG         Interrupt Flag
      0020  5   IES             IES         Interrupt Edge Select
      0040  6   IE              IE          Interrupt Enable

      0100  8   --- PORTA --->
      0200  9   --- PORTB --->
      0400  10  --- PORTC --->

      Combine GPIO address bits freely ! For example, you can set all outputs at once by writing to $0702.

      Traditional registers:

      0008  3   misc.out        misc.out
      0080  7   SRAM read       SRAM write
      0800  11  SRAM addr       SRAM addr

      1000  12  UART RX         UART TX
      2000  13  misc.in
      4000  14  Ticks           Set Ticks

      8001  15  IRQ Cause       Clear pending sticky IRQs
      8002  15  IRQ Enable      IRQ Enable

  */

  assign io_din =

    (io_addr[ 8] & io_addr[ 0] ? {8'd0, porta_in }                                  : 16'd0) |
    //(io_addr[ 9] & io_addr[ 0] ? {8'd0, portb_in }                                  : 16'd0) |
    (io_addr[10] & io_addr[ 0] ? {8'd0, portc_in }                                  : 16'd0) |

    (io_addr[ 8] & io_addr[ 1] ? {8'd0, porta_out }                                 : 16'd0) |
    //(io_addr[ 9] & io_addr[ 1] ? {8'd0, portb_out }                                 : 16'd0) |
    (io_addr[10] & io_addr[ 1] ? {8'd0, portc_out }                                 : 16'd0) |

    (io_addr[ 8] & io_addr[ 2] ? {8'd0, porta_dir }                                 : 16'd0) |
    //(io_addr[ 9] & io_addr[ 2] ? {8'd0, portb_dir }                                 : 16'd0) |
    (io_addr[10] & io_addr[ 2] ? {8'd0, portc_dir }                                 : 16'd0) |

    (io_addr[ 8] & io_addr[ 4] ? {8'd0, porta_ifg }                                 : 16'd0) |
    //(io_addr[ 9] & io_addr[ 4] ? {8'd0, portb_ifg }                                 : 16'd0) |
    (io_addr[10] & io_addr[ 4] ? {8'd0, portc_ifg }                                 : 16'd0) |

    (io_addr[ 8] & io_addr[ 5] ? {8'd0, porta_ies }                                 : 16'd0) |
    //(io_addr[ 9] & io_addr[ 5] ? {8'd0, portb_ies }                                 : 16'd0) |
    (io_addr[10] & io_addr[ 5] ? {8'd0, portc_ies }                                 : 16'd0) |

    (io_addr[ 8] & io_addr[ 6] ? {8'd0, porta_ie }                                  : 16'd0) |
    //(io_addr[ 9] & io_addr[ 6] ? {8'd0, portb_ie }                                  : 16'd0) |
    (io_addr[10] & io_addr[ 6] ? {8'd0, portc_ie }                                  : 16'd0) |


    (io_addr[ 3] ? {11'd0, LEDS, PIOS}                                              : 16'd0) |
    (io_addr[ 7] ?         sram_in                                                  : 16'd0) |
    (io_addr[11] ?         sram_addr                                                : 16'd0) |

    (io_addr[12] ? { 8'd0, uart0_data}                                              : 16'd0) |
    (io_addr[13] ? {12'd0, random, flash_io1, uart0_valid, !uart0_busy}             : 16'd0) |
    (io_addr[14] ?         ticks                                                    : 16'd0) |


    (io_addr == 16'h8011 ? led01_in             : 16'd0) |
    (io_addr == 16'h8012 ? led01_out            : 16'd0) |
    (io_addr == 16'h8013 ? led01_dir            : 16'd0) |
    (io_addr == 16'h8014 ? led01_timer[15:0]    : 16'd0) |
    (io_addr == 16'h8015 ? led01_timer[31:16]   : 16'd0) |

    (io_addr == 16'h8021 ? led02_in             : 16'd0) |
    (io_addr == 16'h8022 ? led02_out            : 16'd0) |
    (io_addr == 16'h8023 ? led02_dir            : 16'd0) |
    (io_addr == 16'h8024 ? led02_timer[15:0]    : 16'd0) |
    (io_addr == 16'h8025 ? led02_timer[31:16]   : 16'd0) |

    (io_addr == 16'h8031 ? led03_in             : 16'd0) |
    (io_addr == 16'h8032 ? led03_out            : 16'd0) |
    (io_addr == 16'h8033 ? led03_dir            : 16'd0) |
    (io_addr == 16'h8034 ? led03_timer[15:0]    : 16'd0) |
    (io_addr == 16'h8035 ? led03_timer[31:16]   : 16'd0) |

    (io_addr == 16'h8041 ? led04_in             : 16'd0) |
    (io_addr == 16'h8042 ? led04_out            : 16'd0) |
    (io_addr == 16'h8043 ? led04_dir            : 16'd0) |
    (io_addr == 16'h8044 ? led04_timer[15:0]    : 16'd0) |
    (io_addr == 16'h8045 ? led04_timer[31:16]   : 16'd0) |

    (io_addr == 16'h8001 ? { volatile_irqs, sticky_irqs }                           : 16'd0) |
    (io_addr == 16'h8002 ? interrupt_enable                                         : 16'd0) ;


  always @(posedge clk) begin

    if (io_wr & io_addr[ 8] & io_addr[1])  porta_out <= io_dout[7:0];
    //if (io_wr & io_addr[ 9] & io_addr[1])  portb_out <= io_dout[7:0];
    if (io_wr & io_addr[10] & io_addr[1])  portc_out <= io_dout[7:0];

    if (io_wr & io_addr[ 8] & io_addr[2])  porta_dir <= io_dout[7:0];
    //if (io_wr & io_addr[ 9] & io_addr[2])  portb_dir <= io_dout[7:0];
    if (io_wr & io_addr[10] & io_addr[2])  portc_dir <= io_dout[7:0];

    if (io_wr & io_addr[ 8] & io_addr[4])  porta_ifg <= (io_dout[7:0] | porta_ifg_set); else porta_ifg <= (porta_ifg | porta_ifg_set);
    //if (io_wr & io_addr[ 9] & io_addr[4])  portb_ifg <= (io_dout[7:0] | portb_ifg_set); else portb_ifg <= (portb_ifg | portb_ifg_set);
    if (io_wr & io_addr[10] & io_addr[4])  portc_ifg <= (io_dout[7:0] | portc_ifg_set); else portc_ifg <= (portc_ifg | portc_ifg_set);

    if (io_wr & io_addr[ 8] & io_addr[5])  porta_ies <= io_dout[7:0];
    //if (io_wr & io_addr[ 9] & io_addr[5])  portb_ies <= io_dout[7:0];
    if (io_wr & io_addr[10] & io_addr[5])  portc_ies <= io_dout[7:0];

    if (io_wr & io_addr[ 8] & io_addr[6])  porta_ie  <= io_dout[7:0];
    //if (io_wr & io_addr[ 9] & io_addr[6])  portb_ie  <= io_dout[7:0];
    if (io_wr & io_addr[10] & io_addr[6])  portc_ie  <= io_dout[7:0];

    if (io_wr & io_addr[3])  {LEDS, PIOS} <= io_dout[4:0];
    if (io_wr & io_addr[11]) sram_addr <= io_dout;

    if (io_wr & io_addr == 16'h8001) sticky_irqs <= ( (sticky_irqs & ~io_dout[7:0]) | set_sticky_irqs); else sticky_irqs <= (sticky_irqs | set_sticky_irqs);
    if (io_wr & io_addr == 16'h8002) interrupt_enable <= io_dout;
  end

endmodule // top

  // Very few gates needed: Simply trigger warmboot by any IO access to $8000 / $8001 / $8002 / $8003.
  // SB_WARMBOOT _sb_warmboot ( .BOOT(io_wr & io_addr[15]), .S1(io_addr[1]), .S0(io_addr[0]) );
