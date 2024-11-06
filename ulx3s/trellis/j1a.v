
`default_nettype none

`include "trellis/uart-fifo.v"
`include "../common-verilog/j1-universal-16kb-dualport.v"
`include "../common-verilog/omsp_sync_cell.v"
`include "../common-verilog/ringoscillator-ecp5.v"
`include "trellis/adcfifo.v"

module top(

  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,

  output wifi_gpio0,
  output wifi_en,

  inout [27:0] gp,
  inout [27:0] gn,

  output flash_csn,
  // output flash_clk, // This is a special pin on ECP5 and requires using the USRMCLK macro.
  output flash_mosi,   // IO0
  input  flash_miso,   // IO1
  output flash_wpn,    // IO2
  output flash_holdn,  // IO3

  output reg adc_sclk,
  output reg adc_csn,
  output reg adc_mosi,
  input  adc_miso,

  output sd_cmd,
  output sd_clk,
  output sd_d3,
  input  sd_d0,

  output [3:0] audio_l,
  output [3:0] audio_r,
  output [3:0] audio_v,

  inout oled_clk,
  inout oled_mosi,
  inout oled_resn,
  inout oled_dc,
  inout oled_csn,

  output ftdi_rxd, // UART TX
  input  ftdi_txd // UART RX

);

  // output SDCARD_CMD_D,    // MOSI in SPI Mode
  // input  SDCARD_DAT0,     // MISO in SPI Mode
  // input  SDCARD_DAT1,     //  NC
  // input  SDCARD_DAT2,     //  NC
  // output SDCARD_DAT3,     //  CS  in SPI Mode
  // output SDCARD_SCLK,     // SCLK in SPI Mode

  // ######   Clock   #########################################

  wire clk = clk_25mhz;

  // Tie GPIO0 high, keep board from rebooting
  assign wifi_gpio0 = 1;

  // Cut off wifi_en
  assign wifi_en = 0;

  // ######   Reset logic   ###################################

  reg [7:0] reset_cnt = 0;
  wire resetq = &reset_cnt;

  always @(posedge clk) begin
    if (btn[0])       reset_cnt <= reset_cnt + !resetq;
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

  wire irq_ticks = ticks_plus_1[16]; // Generate interrupt on ticks overflow

  // ######   CYCLES   #########################################

  reg [15:0] cycles;
  always @(posedge clk) cycles <= cycles + 1;

  // ######   PORTA   ###########################################

  reg  [15:0] porta_dir;   // 1:output, 0:input
  reg  [15:0] porta_out;
  wire [15:0] porta_in_async;

  BB ioa0  (.B(gp[ 0]), .I(porta_out[ 0]), .O(porta_in_async[ 0]), .T(~porta_dir[ 0]));
  BB ioa1  (.B(gp[ 1]), .I(porta_out[ 1]), .O(porta_in_async[ 1]), .T(~porta_dir[ 1]));
  BB ioa2  (.B(gp[ 2]), .I(porta_out[ 2]), .O(porta_in_async[ 2]), .T(~porta_dir[ 2]));
  BB ioa3  (.B(gp[ 3]), .I(porta_out[ 3]), .O(porta_in_async[ 3]), .T(~porta_dir[ 3]));
  BB ioa4  (.B(gp[ 4]), .I(porta_out[ 4]), .O(porta_in_async[ 4]), .T(~porta_dir[ 4]));
  BB ioa5  (.B(gp[ 5]), .I(porta_out[ 5]), .O(porta_in_async[ 5]), .T(~porta_dir[ 5]));
  BB ioa6  (.B(gp[ 6]), .I(porta_out[ 6]), .O(porta_in_async[ 6]), .T(~porta_dir[ 6]));
  BB ioa7  (.B(gp[ 7]), .I(porta_out[ 7]), .O(porta_in_async[ 7]), .T(~porta_dir[ 7]));
  BB ioa8  (.B(gp[ 8]), .I(porta_out[ 8]), .O(porta_in_async[ 8]), .T(~porta_dir[ 8]));
  BB ioa9  (.B(gp[ 9]), .I(porta_out[ 9]), .O(porta_in_async[ 9]), .T(~porta_dir[ 9]));
  BB ioa10 (.B(gp[10]), .I(porta_out[10]), .O(porta_in_async[10]), .T(~porta_dir[10]));
  BB ioa11 (.B(gp[11]), .I(porta_out[11]), .O(porta_in_async[11]), .T(~porta_dir[11]));
  BB ioa12 (.B(gp[12]), .I(porta_out[12]), .O(porta_in_async[12]), .T(~porta_dir[12]));
  BB ioa13 (.B(gp[13]), .I(porta_out[13]), .O(porta_in_async[13]), .T(~porta_dir[13]));

  assign porta_in_async[15:14] = btn[2:1];

  // Synchronised input

  wire [15:0] porta_in;

  omsp_sync_cell porta_synchronisers [15:0] ( .data_in(porta_in_async), .data_out(porta_in), .clk(clk), .rst(!resetq) );

  reg [15:0] porta_ifg;
  reg [15:0] porta_ies;
  reg [15:0] porta_ie;

  // Delayed input

  reg [15:0] porta_in_delay;
  always @(posedge clk) porta_in_delay <= porta_in;

  // Edge detection

  wire [15:0] porta_in_re =  porta_in & ~porta_in_delay;  // Rising Edge
  wire [15:0] porta_in_fe = ~porta_in &  porta_in_delay;  // Falling Edge

  // Set interrupt flags

  wire [15:0] porta_ifg_set = (porta_ies & porta_in_fe) | (~porta_ies & porta_in_re);
  wire irq_porta = |(porta_ie & porta_ifg);


  // ######   PORTB   ###########################################

  reg  [15:0] portb_dir;   // 1:output, 0:input
  reg  [15:0] portb_out;
  wire [15:0] portb_in_async;

  BB iob0  (.B(gn[ 0]), .I(portb_out[ 0]), .O(portb_in_async[ 0]), .T(~portb_dir[ 0]));
  BB iob1  (.B(gn[ 1]), .I(portb_out[ 1]), .O(portb_in_async[ 1]), .T(~portb_dir[ 1]));
  BB iob2  (.B(gn[ 2]), .I(portb_out[ 2]), .O(portb_in_async[ 2]), .T(~portb_dir[ 2]));
  BB iob3  (.B(gn[ 3]), .I(portb_out[ 3]), .O(portb_in_async[ 3]), .T(~portb_dir[ 3]));
  BB iob4  (.B(gn[ 4]), .I(portb_out[ 4]), .O(portb_in_async[ 4]), .T(~portb_dir[ 4]));
  BB iob5  (.B(gn[ 5]), .I(portb_out[ 5]), .O(portb_in_async[ 5]), .T(~portb_dir[ 5]));
  BB iob6  (.B(gn[ 6]), .I(portb_out[ 6]), .O(portb_in_async[ 6]), .T(~portb_dir[ 6]));
  BB iob7  (.B(gn[ 7]), .I(portb_out[ 7]), .O(portb_in_async[ 7]), .T(~portb_dir[ 7]));
  BB iob8  (.B(gn[ 8]), .I(portb_out[ 8]), .O(portb_in_async[ 8]), .T(~portb_dir[ 8]));
  BB iob9  (.B(gn[ 9]), .I(portb_out[ 9]), .O(portb_in_async[ 9]), .T(~portb_dir[ 9]));
  BB iob10 (.B(gn[10]), .I(portb_out[10]), .O(portb_in_async[10]), .T(~portb_dir[10]));
  BB iob11 (.B(gn[11]), .I(portb_out[11]), .O(portb_in_async[11]), .T(~portb_dir[11]));
  BB iob12 (.B(gn[12]), .I(portb_out[12]), .O(portb_in_async[12]), .T(~portb_dir[12]));
  BB iob13 (.B(gn[13]), .I(portb_out[13]), .O(portb_in_async[13]), .T(~portb_dir[13]));

  assign portb_in_async[15:14] = btn[4:3];

  // Synchronised input

  wire [15:0] portb_in;

  omsp_sync_cell portb_synchronisers [15:0] ( .data_in(portb_in_async), .data_out(portb_in), .clk(clk), .rst(!resetq) );

  reg [15:0] portb_ifg;
  reg [15:0] portb_ies;
  reg [15:0] portb_ie;

  // Delayed input

  reg [15:0] portb_in_delay;
  always @(posedge clk) portb_in_delay <= portb_in;

  // Edge detection

  wire [15:0] portb_in_re =  portb_in & ~portb_in_delay;  // Rising Edge
  wire [15:0] portb_in_fe = ~portb_in &  portb_in_delay;  // Falling Edge

  // Set interrupt flags

  wire [15:0] portb_ifg_set = (portb_ies & portb_in_fe) | (~portb_ies & portb_in_re);
  wire irq_portb = |(portb_ie & portb_ifg);

  // ######   PORTC   ###########################################

  reg  [15:0] portc_dir;   // 1:output, 0:input
  reg  [15:0] portc_out;
  wire [15:0] portc_in_async;

  BB ioc0  (.B(gn[14]), .I(portc_out[ 0]), .O(portc_in_async[ 0]), .T(~portc_dir[ 0]));
  BB ioc1  (.B(gn[15]), .I(portc_out[ 1]), .O(portc_in_async[ 1]), .T(~portc_dir[ 1]));
  BB ioc2  (.B(gn[16]), .I(portc_out[ 2]), .O(portc_in_async[ 2]), .T(~portc_dir[ 2]));
  BB ioc3  (.B(gn[17]), .I(portc_out[ 3]), .O(portc_in_async[ 3]), .T(~portc_dir[ 3]));
  BB ioc4  (.B(gn[18]), .I(portc_out[ 4]), .O(portc_in_async[ 4]), .T(~portc_dir[ 4]));
  BB ioc5  (.B(gn[19]), .I(portc_out[ 5]), .O(portc_in_async[ 5]), .T(~portc_dir[ 5]));
  BB ioc6  (.B(gn[20]), .I(portc_out[ 6]), .O(portc_in_async[ 6]), .T(~portc_dir[ 6]));
  BB ioc7  (.B(gn[21]), .I(portc_out[ 7]), .O(portc_in_async[ 7]), .T(~portc_dir[ 7]));
  BB ioc8  (.B(gn[22]), .I(portc_out[ 8]), .O(portc_in_async[ 8]), .T(~portc_dir[ 8]));
  BB ioc9  (.B(gn[23]), .I(portc_out[ 9]), .O(portc_in_async[ 9]), .T(~portc_dir[ 9]));
  BB ioc10 (.B(gn[24]), .I(portc_out[10]), .O(portc_in_async[10]), .T(~portc_dir[10]));
  BB ioc11 (.B(gn[25]), .I(portc_out[11]), .O(portc_in_async[11]), .T(~portc_dir[11]));
  BB ioc12 (.B(gn[26]), .I(portc_out[12]), .O(portc_in_async[12]), .T(~portc_dir[12]));
  BB ioc13 (.B(gn[27]), .I(portc_out[13]), .O(portc_in_async[13]), .T(~portc_dir[13]));

  assign portc_in_async[15:14] = btn[6:5];

  // Synchronised input

  wire [15:0] portc_in;

  omsp_sync_cell portc_synchronisers [15:0] ( .data_in(portc_in_async), .data_out(portc_in), .clk(clk), .rst(!resetq) );

  reg [15:0] portc_ifg;
  reg [15:0] portc_ies;
  reg [15:0] portc_ie;

  // Delayed input

  reg [15:0] portc_in_delay;
  always @(posedge clk) portc_in_delay <= portc_in;

  // Edge detection

  wire [15:0] portc_in_re =  portc_in & ~portc_in_delay;  // Rising Edge
  wire [15:0] portc_in_fe = ~portc_in &  portc_in_delay;  // Falling Edge

  // Set interrupt flags

  wire [15:0] portc_ifg_set = (portc_ies & portc_in_fe) | (~portc_ies & portc_in_re);
  wire irq_portc = |(portc_ie & portc_ifg);

  // ######   PORTD   ###########################################

  reg  [15:0] portd_dir;   // 1:output, 0:input
  reg  [15:0] portd_out;
  wire [15:0] portd_in_async;


  BB iod0  (.B(gp[14]), .I(portd_out[ 0]), .O(portd_in_async[ 0]), .T(~portd_dir[ 0]));
  BB iod1  (.B(gp[15]), .I(portd_out[ 1]), .O(portd_in_async[ 1]), .T(~portd_dir[ 1]));
  BB iod2  (.B(gp[16]), .I(portd_out[ 2]), .O(portd_in_async[ 2]), .T(~portd_dir[ 2]));
  BB iod3  (.B(gp[17]), .I(portd_out[ 3]), .O(portd_in_async[ 3]), .T(~portd_dir[ 3]));
  BB iod4  (.B(gp[18]), .I(portd_out[ 4]), .O(portd_in_async[ 4]), .T(~portd_dir[ 4]));
  BB iod5  (.B(gp[19]), .I(portd_out[ 5]), .O(portd_in_async[ 5]), .T(~portd_dir[ 5]));
  BB iod6  (.B(gp[20]), .I(portd_out[ 6]), .O(portd_in_async[ 6]), .T(~portd_dir[ 6]));
  BB iod7  (.B(gp[21]), .I(portd_out[ 7]), .O(portd_in_async[ 7]), .T(~portd_dir[ 7]));
  BB iod8  (.B(gp[22]), .I(portd_out[ 8]), .O(portd_in_async[ 8]), .T(~portd_dir[ 8]));
  BB iod9  (.B(gp[23]), .I(portd_out[ 9]), .O(portd_in_async[ 9]), .T(~portd_dir[ 9]));
  BB iod10 (.B(gp[24]), .I(portd_out[10]), .O(portd_in_async[10]), .T(~portd_dir[10]));
  BB iod11 (.B(gp[25]), .I(portd_out[11]), .O(portd_in_async[11]), .T(~portd_dir[11]));
  BB iod12 (.B(gp[26]), .I(portd_out[12]), .O(portd_in_async[12]), .T(~portd_dir[12]));
  BB iod13 (.B(gp[27]), .I(portd_out[13]), .O(portd_in_async[13]), .T(~portd_dir[13]));

  assign portd_in_async[15:14] = 0;

  // Synchronised input

  wire [15:0] portd_in;

  omsp_sync_cell portd_synchronisers [15:0] ( .data_in(portd_in_async), .data_out(portd_in), .clk(clk), .rst(!resetq) );

  reg [15:0] portd_ifg;
  reg [15:0] portd_ies;
  reg [15:0] portd_ie;

  // Delayed input

  reg [15:0] portd_in_delay;
  always @(posedge clk) portd_in_delay <= portd_in;

  // Edge detection

  wire [15:0] portd_in_re =  portd_in & ~portd_in_delay;  // Rising Edge
  wire [15:0] portd_in_fe = ~portd_in &  portd_in_delay;  // Falling Edge

  // Set interrupt flags

  wire [15:0] portd_ifg_set = (portd_ies & portd_in_fe) | (~portd_ies & portd_in_re);
  wire irq_portd = |(portd_ie & portd_ifg);


  // ######   OLED   ##########################################

  wire [4:0] oled_in;
  reg  [4:0] oled_out;
  reg  [4:0] oled_dir;   // 1:output, 0:input

  BBPU oled0  (.B(oled_clk  ), .I(oled_out[ 0]), .O(oled_in[ 0]), .T(~oled_dir[ 0]));
  BBPU oled1  (.B(oled_mosi ), .I(oled_out[ 1]), .O(oled_in[ 1]), .T(~oled_dir[ 1]));
  BBPU oled2  (.B(oled_resn ), .I(oled_out[ 2]), .O(oled_in[ 2]), .T(~oled_dir[ 2]));
  BBPU oled3  (.B(oled_dc   ), .I(oled_out[ 3]), .O(oled_in[ 3]), .T(~oled_dir[ 3]));
  BBPU oled4  (.B(oled_csn  ), .I(oled_out[ 4]), .O(oled_in[ 4]), .T(~oled_dir[ 4]));

  // ######   SPI Flash   #####################################

  wire flash_in = flash_miso;
  reg [2:0] flash_out;

  wire flash_clk;
  assign {flash_clk, flash_mosi, flash_csn} = flash_out;

  // A special macro is necessary to access the clock wire of the SPI flash memory chip
  wire untristate = 0;
  USRMCLK mclk (.USRMCLKTS(untristate), .USRMCLKI(flash_clk));

  assign flash_wpn   = 1;
  assign flash_holdn = 1;

  // ######   ADC   ###########################################

  // wire      adc_in = adc_miso;
  // reg [2:0] adc_out;
  // assign {adc_csn, adc_sclk, adc_mosi} = adc_out;

  // adc_sclk is specified for a maximum frequency of 16 MHz.

  reg [6:0] wandlungszyklus = 0; // Läuft von 0*4 bis 32*4-1 = 127.

  reg [11:0] wandel = 0;

  localparam wandlung_filterbits = 0; // 0 for raw data, more for exponential moving average
  reg [15 + wandlung_filterbits :0] wandelfilter;  wire [15:0] wandelergebnis = wandelfilter[15 + wandlung_filterbits : wandlung_filterbits];

  reg [3:0] adc_channel;

  // + 0 : Fallende Flanke
  // + 1 : Genau in der Mitte vom  Low-Teil des Taktes
  // + 2 : Steigende Flanke
  // + 3 : Genau in der Mitte vom High-Teil des Taktes
  // CS soll fallen, während CLK high ist.
  always @(posedge clk) begin

    if (!resetq) wandlungszyklus <= 0;
    else         wandlungszyklus <= wandlungszyklus < 25*4-1 ? wandlungszyklus + 1 : 0;

    adc_sclk <= wandlungszyklus[1];

    if (wandlungszyklus ==  0 * 4 + 3) begin  adc_mosi <= 0; adc_csn <= 0; adc_channel <= adc_out; end
    if (wandlungszyklus ==  1 * 4 + 3) begin  adc_mosi <= 0;                                       end
    if (wandlungszyklus ==  2 * 4 + 3) begin  adc_mosi <= 0;              wandel[11] <= adc_miso;  end
    if (wandlungszyklus ==  3 * 4 + 3) begin  adc_mosi <= 0;              wandel[10] <= adc_miso;  end
    if (wandlungszyklus ==  4 * 4 + 3) begin  adc_mosi <= 1;              wandel[ 9] <= adc_miso;  end
    if (wandlungszyklus ==  5 * 4 + 3) begin  adc_mosi <= adc_channel[3]; wandel[ 8] <= adc_miso;  end
    if (wandlungszyklus ==  6 * 4 + 3) begin  adc_mosi <= adc_channel[2]; wandel[ 7] <= adc_miso;  end
    if (wandlungszyklus ==  7 * 4 + 3) begin  adc_mosi <= adc_channel[1]; wandel[ 6] <= adc_miso;  end
    if (wandlungszyklus ==  8 * 4 + 3) begin  adc_mosi <= adc_channel[0]; wandel[ 5] <= adc_miso;  end
    if (wandlungszyklus ==  9 * 4 + 3) begin  adc_mosi <= 0;              wandel[ 4] <= adc_miso;  end
    if (wandlungszyklus == 10 * 4 + 3) begin  adc_mosi <= 0;              wandel[ 3] <= adc_miso;  end
    if (wandlungszyklus == 11 * 4 + 3) begin  adc_mosi <= 0;              wandel[ 2] <= adc_miso;  end
    if (wandlungszyklus == 12 * 4 + 3) begin  adc_mosi <= 0;              wandel[ 1] <= adc_miso;  end
    if (wandlungszyklus == 13 * 4 + 3) begin  adc_mosi <= 0;              wandel[ 0] <= adc_miso;  end
    if (wandlungszyklus == 14 * 4 + 3) begin  adc_mosi <= 1;                                       end
    if (wandlungszyklus == 15 * 4 + 3) begin  adc_mosi <= 0;                                       end
    if (wandlungszyklus == 16 * 4 + 3) begin  adc_mosi <= 0; adc_csn <= 1;
                                              wandelfilter <= (wandelfilter - (wandelfilter >> wandlung_filterbits)) + wandel;
                                       end
  end

  wire [15:0] adc_in = wandelergebnis;
  reg  [15:0] adc_out = 0;

  // ######   ADC-FIFO   ########################################

  wire fifo_store = wandlungszyklus == 16 * 4 + 3;

  wire adc_valid; wire [15:0] adc_fifo;

  adcfifo _fifo_I0 (
    .clk(clk),
    .resetq(resetq),
    .wr(fifo_store),
    .rd(io_rd & io_addr[13] & (io_addr[7:4] == 12)),
    .store_data(wandelergebnis),
    .fetch_data(adc_fifo),
    .valid(adc_valid)
  );

  // ######   SD-Karte   ########################################

  wire       sd_in = sd_d0; // MISO
  reg  [2:0] sd_out;

  assign {sd_d3, sd_clk, sd_cmd} = sd_out[2:0]; // CS, SCLK, MOSI

  // ######   Analog out   ####################################

  reg [11:0] analog_out;

  assign audio_l = analog_out[3:0];
  assign audio_r = analog_out[7:4];
  assign audio_v = analog_out[11:8];

  // ######   UART   ##########################################

  wire uart0_valid, uart0_busy;
  wire [7:0] uart0_data;
  wire uart0_wr = io_wr & io_addr[12];
  wire uart0_rd = io_rd & io_addr[12];

  buart  #(
     .FREQ_MHZ(25),
     .BAUDS(115200)
  ) _uart0 (
     .clk(clk),
     .resetq(resetq),
     .rx(ftdi_txd),
     .tx(ftdi_rxd),
     .rd(uart0_rd),
     .wr(uart0_wr),
     .valid(uart0_valid),
     .busy(uart0_busy),
     .tx_data(io_dout[7:0]),
     .rx_data(uart0_data));

  // ######   LEDS   ##########################################

  reg [15:0] LEDS;
  assign led = LEDS[7:0];

  // ######   RING OSCILLATOR   ###############################

  wire random;
  ring_osc #( .NUM_LUTS(1) ) chaos ( .osc_out(random), .resetq(resetq) );

  // ######   Interrupts   ####################################

  reg [15:0] interrupt_enable = 16'hFF00;

  wire [7:0] volatile_irqs;   // Interrupts which keep activated in peripherals
  reg  [7:0] sticky_irqs = 0; // For one shot interrupts which need to be preserved
  wire [7:0] set_sticky_irqs;

  assign volatile_irqs = {3'd0, irq_ticks, irq_portd, irq_portc, irq_portb, irq_porta};
  assign set_sticky_irqs = {7'd0, irq_ticks};

  always @(posedge clk) interrupt <= (|(volatile_irqs & interrupt_enable[15:8])) | (|(sticky_irqs & interrupt_enable[7:0]));

  // ######   IO PORTS   ######################################

  /*        Bit READ            WRITE

    + ...0                      Write as usual
    + ...1                      _C_lear bits
    + ...2                      _S_et bits
    + ...3                      _T_oggle bits

      0004  2   IN                          Input
      0008  3   OUT             OUT (cst)   Output
      0010  4   DIR             DIR (cst)   Direction
      0020  5   IFG             IFG (cst)   Interrupt Flag
      0040  6   IES             IES (cst)   Interrupt Edge Select
      0080  7   IE              IE  (cst)   Interrupt Enable

      0100  8   --- PORTA --->
      0200  9   --- PORTB --->
      0400  10  --- PORTC --->
      0800  11  --- PORTD --->

      Combine GPIO address bits freely ! For example, you can write all outputs at once by writing to $0F08.

      Traditional registers:

      1000      UART RX         UART TX
      2000      UART Status
      2010      LEDs            LEDs (cst)
      2020      Buttons
      4000      Ticks           Set Ticks
      8004      IRQ Cause       IRQ Cause  (cst)  Especially useful +1: Clear pending sticky IRQs
      8008      IRQ Enable      IRQ Enable (cst)

  */

  assign io_din =

    (io_addr[ 8] & io_addr[ 2] ? porta_in                                           : 16'd0) |
    (io_addr[ 9] & io_addr[ 2] ? portb_in                                           : 16'd0) |
    (io_addr[10] & io_addr[ 2] ? portc_in                                           : 16'd0) |
    (io_addr[11] & io_addr[ 2] ? portd_in                                           : 16'd0) |

    (io_addr[ 8] & io_addr[ 3] ? porta_out                                          : 16'd0) |
    (io_addr[ 9] & io_addr[ 3] ? portb_out                                          : 16'd0) |
    (io_addr[10] & io_addr[ 3] ? portc_out                                          : 16'd0) |
    (io_addr[11] & io_addr[ 3] ? portd_out                                          : 16'd0) |

    (io_addr[ 8] & io_addr[ 4] ? porta_dir                                          : 16'd0) |
    (io_addr[ 9] & io_addr[ 4] ? portb_dir                                          : 16'd0) |
    (io_addr[10] & io_addr[ 4] ? portc_dir                                          : 16'd0) |
    (io_addr[11] & io_addr[ 4] ? portd_dir                                          : 16'd0) |

    (io_addr[ 8] & io_addr[ 5] ? porta_ifg                                          : 16'd0) |
    (io_addr[ 9] & io_addr[ 5] ? portb_ifg                                          : 16'd0) |
    (io_addr[10] & io_addr[ 5] ? portc_ifg                                          : 16'd0) |
    (io_addr[11] & io_addr[ 5] ? portd_ifg                                          : 16'd0) |

    (io_addr[ 8] & io_addr[ 6] ? porta_ies                                          : 16'd0) |
    (io_addr[ 9] & io_addr[ 6] ? portb_ies                                          : 16'd0) |
    (io_addr[10] & io_addr[ 6] ? portc_ies                                          : 16'd0) |
    (io_addr[11] & io_addr[ 6] ? portd_ies                                          : 16'd0) |

    (io_addr[ 8] & io_addr[ 7] ? porta_ie                                           : 16'd0) |
    (io_addr[ 9] & io_addr[ 7] ? portb_ie                                           : 16'd0) |
    (io_addr[10] & io_addr[ 7] ? portc_ie                                           : 16'd0) |
    (io_addr[11] & io_addr[ 7] ? portd_ie                                           : 16'd0) |

    (io_addr[12] ? { 8'd0, uart0_data}                                              : 16'd0) |

    (io_addr[13] & (io_addr[7:4] ==  0) ? {random, uart0_valid, !uart0_busy}        : 16'd0) |
    (io_addr[13] & (io_addr[7:4] ==  1) ? LEDS                                      : 16'd0) |
    (io_addr[13] & (io_addr[7:4] ==  2) ? btn[6:1]                                  : 16'd0) |
    (io_addr[13] & (io_addr[7:4] ==  3) ? adc_in                                    : 16'd0) |
    (io_addr[13] & (io_addr[7:4] ==  4) ? adc_out                                   : 16'd0) |
    (io_addr[13] & (io_addr[7:4] ==  5) ? sd_in                                     : 16'd0) |
    (io_addr[13] & (io_addr[7:4] ==  6) ? sd_out                                    : 16'd0) |
    (io_addr[13] & (io_addr[7:4] ==  7) ? analog_out                                : 16'd0) |
    (io_addr[13] & (io_addr[7:4] ==  8) ? oled_in                                   : 16'd0) |
    (io_addr[13] & (io_addr[7:4] ==  9) ? oled_out                                  : 16'd0) |
    (io_addr[13] & (io_addr[7:4] == 10) ? oled_dir                                  : 16'd0) |

    (io_addr[13] & (io_addr[7:4] == 11) ? adc_valid                                 : 16'd0) |
    (io_addr[13] & (io_addr[7:4] == 12) ? adc_fifo                                  : 16'd0) |

    (io_addr[13] & (io_addr[7:4] == 15) ? flash_in                                  : 16'd0) |

    (io_addr[14] ?         ticks                                                    : 16'd0) |

    (io_addr[15] & ~io_addr[ 3] & ~io_addr[ 2] ? cycles                             : 16'd0) |
    (io_addr[15] & io_addr[ 2] ? { volatile_irqs, sticky_irqs }                     : 16'd0) |
    (io_addr[15] & io_addr[ 3] ? interrupt_enable                                   : 16'd0) ;


  always @(posedge clk) begin

    if (io_wr & io_addr[ 8] & io_addr[3] & (io_addr[1:0] == 0))  porta_out  <=               io_dout;
    if (io_wr & io_addr[ 8] & io_addr[3] & (io_addr[1:0] == 1))  porta_out  <=  porta_out & ~io_dout; // Clear
    if (io_wr & io_addr[ 8] & io_addr[3] & (io_addr[1:0] == 2))  porta_out  <=  porta_out |  io_dout; // Set
    if (io_wr & io_addr[ 8] & io_addr[3] & (io_addr[1:0] == 3))  porta_out  <=  porta_out ^  io_dout; // Invert

    if (io_wr & io_addr[ 9] & io_addr[3] & (io_addr[1:0] == 0))  portb_out  <=               io_dout;
    if (io_wr & io_addr[ 9] & io_addr[3] & (io_addr[1:0] == 1))  portb_out  <=  portb_out & ~io_dout; // Clear
    if (io_wr & io_addr[ 9] & io_addr[3] & (io_addr[1:0] == 2))  portb_out  <=  portb_out |  io_dout; // Set
    if (io_wr & io_addr[ 9] & io_addr[3] & (io_addr[1:0] == 3))  portb_out  <=  portb_out ^  io_dout; // Invert

    if (io_wr & io_addr[10] & io_addr[3] & (io_addr[1:0] == 0))  portc_out  <=               io_dout;
    if (io_wr & io_addr[10] & io_addr[3] & (io_addr[1:0] == 1))  portc_out  <=  portc_out & ~io_dout; // Clear
    if (io_wr & io_addr[10] & io_addr[3] & (io_addr[1:0] == 2))  portc_out  <=  portc_out |  io_dout; // Set
    if (io_wr & io_addr[10] & io_addr[3] & (io_addr[1:0] == 3))  portc_out  <=  portc_out ^  io_dout; // Invert

    if (io_wr & io_addr[11] & io_addr[3] & (io_addr[1:0] == 0))  portd_out  <=               io_dout;
    if (io_wr & io_addr[11] & io_addr[3] & (io_addr[1:0] == 1))  portd_out  <=  portd_out & ~io_dout; // Clear
    if (io_wr & io_addr[11] & io_addr[3] & (io_addr[1:0] == 2))  portd_out  <=  portd_out |  io_dout; // Set
    if (io_wr & io_addr[11] & io_addr[3] & (io_addr[1:0] == 3))  portd_out  <=  portd_out ^  io_dout; // Invert


    if (io_wr & io_addr[ 8] & io_addr[4] & (io_addr[1:0] == 0))  porta_dir  <=               io_dout;
    if (io_wr & io_addr[ 8] & io_addr[4] & (io_addr[1:0] == 1))  porta_dir  <=  porta_dir & ~io_dout; // Clear
    if (io_wr & io_addr[ 8] & io_addr[4] & (io_addr[1:0] == 2))  porta_dir  <=  porta_dir |  io_dout; // Set
    if (io_wr & io_addr[ 8] & io_addr[4] & (io_addr[1:0] == 3))  porta_dir  <=  porta_dir ^  io_dout; // Invert

    if (io_wr & io_addr[ 9] & io_addr[4] & (io_addr[1:0] == 0))  portb_dir  <=               io_dout;
    if (io_wr & io_addr[ 9] & io_addr[4] & (io_addr[1:0] == 1))  portb_dir  <=  portb_dir & ~io_dout; // Clear
    if (io_wr & io_addr[ 9] & io_addr[4] & (io_addr[1:0] == 2))  portb_dir  <=  portb_dir |  io_dout; // Set
    if (io_wr & io_addr[ 9] & io_addr[4] & (io_addr[1:0] == 3))  portb_dir  <=  portb_dir ^  io_dout; // Invert

    if (io_wr & io_addr[10] & io_addr[4] & (io_addr[1:0] == 0))  portc_dir  <=               io_dout;
    if (io_wr & io_addr[10] & io_addr[4] & (io_addr[1:0] == 1))  portc_dir  <=  portc_dir & ~io_dout; // Clear
    if (io_wr & io_addr[10] & io_addr[4] & (io_addr[1:0] == 2))  portc_dir  <=  portc_dir |  io_dout; // Set
    if (io_wr & io_addr[10] & io_addr[4] & (io_addr[1:0] == 3))  portc_dir  <=  portc_dir ^  io_dout; // Invert

    if (io_wr & io_addr[11] & io_addr[4] & (io_addr[1:0] == 0))  portd_dir  <=               io_dout;
    if (io_wr & io_addr[11] & io_addr[4] & (io_addr[1:0] == 1))  portd_dir  <=  portd_dir & ~io_dout; // Clear
    if (io_wr & io_addr[11] & io_addr[4] & (io_addr[1:0] == 2))  portd_dir  <=  portd_dir |  io_dout; // Set
    if (io_wr & io_addr[11] & io_addr[4] & (io_addr[1:0] == 3))  portd_dir  <=  portd_dir ^  io_dout; // Invert


    if (io_wr & io_addr[ 8] & io_addr[5])
    begin
      casez (io_addr[1:0])
        2'd0: porta_ifg <= (             io_dout) | porta_ifg_set;
        2'd1: porta_ifg <= (porta_ifg & ~io_dout) | porta_ifg_set; // Clear
        2'd2: porta_ifg <= (porta_ifg |  io_dout) | porta_ifg_set; // Set
        2'd3: porta_ifg <= (porta_ifg ^  io_dout) | porta_ifg_set; // Invert
      endcase
    end
    else porta_ifg <= (porta_ifg | porta_ifg_set);

    if (io_wr & io_addr[ 9] & io_addr[5])
    begin
      casez (io_addr[1:0])
        2'd0: portb_ifg <= (             io_dout) | portb_ifg_set;
        2'd1: portb_ifg <= (portb_ifg & ~io_dout) | portb_ifg_set; // Clear
        2'd2: portb_ifg <= (portb_ifg |  io_dout) | portb_ifg_set; // Set
        2'd3: portb_ifg <= (portb_ifg ^  io_dout) | portb_ifg_set; // Invert
      endcase
    end
    else portb_ifg <= (portb_ifg | portb_ifg_set);

    if (io_wr & io_addr[10] & io_addr[5])
    begin
      casez (io_addr[1:0])
        2'd0: portc_ifg <= (             io_dout) | portc_ifg_set;
        2'd1: portc_ifg <= (portc_ifg & ~io_dout) | portc_ifg_set; // Clear
        2'd2: portc_ifg <= (portc_ifg |  io_dout) | portc_ifg_set; // Set
        2'd3: portc_ifg <= (portc_ifg ^  io_dout) | portc_ifg_set; // Invert
      endcase
    end
    else portc_ifg <= (portc_ifg | portc_ifg_set);

    if (io_wr & io_addr[11] & io_addr[5])
    begin
      casez (io_addr[1:0])
        2'd0: portd_ifg <= (             io_dout) | portd_ifg_set;
        2'd1: portd_ifg <= (portd_ifg & ~io_dout) | portd_ifg_set; // Clear
        2'd2: portd_ifg <= (portd_ifg |  io_dout) | portd_ifg_set; // Set
        2'd3: portd_ifg <= (portd_ifg ^  io_dout) | portd_ifg_set; // Invert
      endcase
    end
    else portd_ifg <= (portd_ifg | portd_ifg_set);


    if (io_wr & io_addr[ 8] & io_addr[6] & (io_addr[1:0] == 0))  porta_ies  <=               io_dout;
    if (io_wr & io_addr[ 8] & io_addr[6] & (io_addr[1:0] == 1))  porta_ies  <=  porta_ies & ~io_dout; // Clear
    if (io_wr & io_addr[ 8] & io_addr[6] & (io_addr[1:0] == 2))  porta_ies  <=  porta_ies |  io_dout; // Set
    if (io_wr & io_addr[ 8] & io_addr[6] & (io_addr[1:0] == 3))  porta_ies  <=  porta_ies ^  io_dout; // Invert

    if (io_wr & io_addr[ 9] & io_addr[6] & (io_addr[1:0] == 0))  portb_ies  <=               io_dout;
    if (io_wr & io_addr[ 9] & io_addr[6] & (io_addr[1:0] == 1))  portb_ies  <=  portb_ies & ~io_dout; // Clear
    if (io_wr & io_addr[ 9] & io_addr[6] & (io_addr[1:0] == 2))  portb_ies  <=  portb_ies |  io_dout; // Set
    if (io_wr & io_addr[ 9] & io_addr[6] & (io_addr[1:0] == 3))  portb_ies  <=  portb_ies ^  io_dout; // Invert

    if (io_wr & io_addr[10] & io_addr[6] & (io_addr[1:0] == 0))  portc_ies  <=               io_dout;
    if (io_wr & io_addr[10] & io_addr[6] & (io_addr[1:0] == 1))  portc_ies  <=  portc_ies & ~io_dout; // Clear
    if (io_wr & io_addr[10] & io_addr[6] & (io_addr[1:0] == 2))  portc_ies  <=  portc_ies |  io_dout; // Set
    if (io_wr & io_addr[10] & io_addr[6] & (io_addr[1:0] == 3))  portc_ies  <=  portc_ies ^  io_dout; // Invert

    if (io_wr & io_addr[11] & io_addr[6] & (io_addr[1:0] == 0))  portd_ies  <=               io_dout;
    if (io_wr & io_addr[11] & io_addr[6] & (io_addr[1:0] == 1))  portd_ies  <=  portd_ies & ~io_dout; // Clear
    if (io_wr & io_addr[11] & io_addr[6] & (io_addr[1:0] == 2))  portd_ies  <=  portd_ies |  io_dout; // Set
    if (io_wr & io_addr[11] & io_addr[6] & (io_addr[1:0] == 3))  portd_ies  <=  portd_ies ^  io_dout; // Invert


    if (io_wr & io_addr[ 8] & io_addr[7] & (io_addr[1:0] == 0))  porta_ie   <=               io_dout;
    if (io_wr & io_addr[ 8] & io_addr[7] & (io_addr[1:0] == 1))  porta_ie   <=  porta_ie  & ~io_dout; // Clear
    if (io_wr & io_addr[ 8] & io_addr[7] & (io_addr[1:0] == 2))  porta_ie   <=  porta_ie  |  io_dout; // Set
    if (io_wr & io_addr[ 8] & io_addr[7] & (io_addr[1:0] == 3))  porta_ie   <=  porta_ie  ^  io_dout; // Invert

    if (io_wr & io_addr[ 9] & io_addr[7] & (io_addr[1:0] == 0))  portb_ie   <=               io_dout;
    if (io_wr & io_addr[ 9] & io_addr[7] & (io_addr[1:0] == 1))  portb_ie   <=  portb_ie  & ~io_dout; // Clear
    if (io_wr & io_addr[ 9] & io_addr[7] & (io_addr[1:0] == 2))  portb_ie   <=  portb_ie  |  io_dout; // Set
    if (io_wr & io_addr[ 9] & io_addr[7] & (io_addr[1:0] == 3))  portb_ie   <=  portb_ie  ^  io_dout; // Invert

    if (io_wr & io_addr[10] & io_addr[7] & (io_addr[1:0] == 0))  portc_ie   <=               io_dout;
    if (io_wr & io_addr[10] & io_addr[7] & (io_addr[1:0] == 1))  portc_ie   <=  portc_ie  & ~io_dout; // Clear
    if (io_wr & io_addr[10] & io_addr[7] & (io_addr[1:0] == 2))  portc_ie   <=  portc_ie  |  io_dout; // Set
    if (io_wr & io_addr[10] & io_addr[7] & (io_addr[1:0] == 3))  portc_ie   <=  portc_ie  ^  io_dout; // Invert

    if (io_wr & io_addr[11] & io_addr[7] & (io_addr[1:0] == 0))  portd_ie   <=               io_dout;
    if (io_wr & io_addr[11] & io_addr[7] & (io_addr[1:0] == 1))  portd_ie   <=  portd_ie  & ~io_dout; // Clear
    if (io_wr & io_addr[11] & io_addr[7] & (io_addr[1:0] == 2))  portd_ie   <=  portd_ie  |  io_dout; // Set
    if (io_wr & io_addr[11] & io_addr[7] & (io_addr[1:0] == 3))  portd_ie   <=  portd_ie  ^  io_dout; // Invert


    if (io_wr & io_addr[13] & (io_addr[7:4] ==  1) & (io_addr[1:0] == 0))  LEDS  <=           io_dout;
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  1) & (io_addr[1:0] == 1))  LEDS  <=  LEDS  & ~io_dout; // Clear
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  1) & (io_addr[1:0] == 2))  LEDS  <=  LEDS  |  io_dout; // Set
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  1) & (io_addr[1:0] == 3))  LEDS  <=  LEDS  ^  io_dout; // Invert

    if (io_wr & io_addr[13] & (io_addr[7:4] ==  4) & (io_addr[1:0] == 0))  adc_out  <=              io_dout;
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  4) & (io_addr[1:0] == 1))  adc_out  <=  adc_out  & ~io_dout; // Clear
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  4) & (io_addr[1:0] == 2))  adc_out  <=  adc_out  |  io_dout; // Set
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  4) & (io_addr[1:0] == 3))  adc_out  <=  adc_out  ^  io_dout; // Invert

    if (io_wr & io_addr[13] & (io_addr[7:4] ==  6) & (io_addr[1:0] == 0))  sd_out  <=             io_dout;
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  6) & (io_addr[1:0] == 1))  sd_out  <=  sd_out  & ~io_dout; // Clear
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  6) & (io_addr[1:0] == 2))  sd_out  <=  sd_out  |  io_dout; // Set
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  6) & (io_addr[1:0] == 3))  sd_out  <=  sd_out  ^  io_dout; // Invert

    if (io_wr & io_addr[13] & (io_addr[7:4] ==  7) & (io_addr[1:0] == 0))  analog_out  <=                 io_dout;
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  7) & (io_addr[1:0] == 1))  analog_out  <=  analog_out  & ~io_dout; // Clear
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  7) & (io_addr[1:0] == 2))  analog_out  <=  analog_out  |  io_dout; // Set
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  7) & (io_addr[1:0] == 3))  analog_out  <=  analog_out  ^  io_dout; // Invert

    if (io_wr & io_addr[13] & (io_addr[7:4] ==  9) & (io_addr[1:0] == 0))  oled_out  <=               io_dout;
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  9) & (io_addr[1:0] == 1))  oled_out  <=  oled_out  & ~io_dout; // Clear
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  9) & (io_addr[1:0] == 2))  oled_out  <=  oled_out  |  io_dout; // Set
    if (io_wr & io_addr[13] & (io_addr[7:4] ==  9) & (io_addr[1:0] == 3))  oled_out  <=  oled_out  ^  io_dout; // Invert

    if (io_wr & io_addr[13] & (io_addr[7:4] == 10) & (io_addr[1:0] == 0))  oled_dir  <=               io_dout;
    if (io_wr & io_addr[13] & (io_addr[7:4] == 10) & (io_addr[1:0] == 1))  oled_dir  <=  oled_dir  & ~io_dout; // Clear
    if (io_wr & io_addr[13] & (io_addr[7:4] == 10) & (io_addr[1:0] == 2))  oled_dir  <=  oled_dir  |  io_dout; // Set
    if (io_wr & io_addr[13] & (io_addr[7:4] == 10) & (io_addr[1:0] == 3))  oled_dir  <=  oled_dir  ^  io_dout; // Invert

    if (io_wr & io_addr[13] & (io_addr[7:4] == 15)) flash_out <= io_dout;

    if (io_wr & io_addr[15] & io_addr[2])
    begin
      casez (io_addr[1:0])
        2'd0: sticky_irqs <= (               io_dout[7:0]) | set_sticky_irqs;
        2'd1: sticky_irqs <= (sticky_irqs & ~io_dout[7:0]) | set_sticky_irqs; // Clear
        2'd2: sticky_irqs <= (sticky_irqs |  io_dout[7:0]) | set_sticky_irqs; // Set
        2'd3: sticky_irqs <= (sticky_irqs ^  io_dout[7:0]) | set_sticky_irqs; // Invert
      endcase
    end
    else sticky_irqs <= (sticky_irqs | set_sticky_irqs);


    if (io_wr & io_addr[15] & io_addr[3] & (io_addr[1:0] == 0))  interrupt_enable  <=                       io_dout;
    if (io_wr & io_addr[15] & io_addr[3] & (io_addr[1:0] == 1))  interrupt_enable  <=  interrupt_enable  & ~io_dout; // Clear
    if (io_wr & io_addr[15] & io_addr[3] & (io_addr[1:0] == 2))  interrupt_enable  <=  interrupt_enable  |  io_dout; // Set
    if (io_wr & io_addr[15] & io_addr[3] & (io_addr[1:0] == 3))  interrupt_enable  <=  interrupt_enable  ^  io_dout; // Invert

  end

endmodule // top
