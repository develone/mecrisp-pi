
`default_nettype none // Simplifies finding typos

module top(
  input oscillator,

  output D1,
  output D2,
  output PORTC0,  // 0   1  Led West
  output PORTC1,  // 1   2  Led East
  output PORTC2,  // 2   4  Led South
  input  PORTC3,  // 3   8    Button 2
  output PORTC4,  // 4  16  Led Middle
  output PORTC5,  // 5  32  Led North
  input  PORTC6,  // 6  64    Button 1
  input  PORTC7   // 7 128    Button 3
);

  wire clk = oscillator; // Directly use the oscillator, no fancy PLL config

  // ----------------------------------------------------------
  //   Simple gray counter blinky
  // ----------------------------------------------------------

  reg [31:0] counter;

  always @(posedge clk) counter <= counter + 1;

  assign {PORTC5, PORTC4, PORTC2, PORTC1, PORTC0} = counter[27:23] ^ counter[27:24];

  // ----------------------------------------------------------
  //   Advanced fading blinky
  // ----------------------------------------------------------

  // Predivider to select blink frequency

  reg [5:0] prediv = 0;
  always @(posedge clk) prediv <= prediv + 1;

  // Minsky circle algorithm

  reg [20:0] sine   = 0;
  reg [20:0] cosine = 1 << 19;

  always @(posedge clk)
  if (prediv == 0)
  begin
    cosine = $signed(cosine) - ($signed(  sine) >>> 17);
    sine   = $signed(  sine) + ($signed(cosine) >>> 17);
  end

  // Exponential function approximation

  wire  [7:0] scaled = 8'd167 + sine[20:13];
  wire [31:0] exp = {1'b1, scaled[2:0]} << scaled[7:3];

  // Sigma-delta modulator

  reg  [31:0] phase = 0;
  wire [32:0] phase_new = phase + exp;
  always @(posedge clk) phase <= phase_new[31:0];
  wire breathe = phase_new[32];

  assign D1 = ~breathe; // These LEDs are inverted
  assign D2 = ~breathe;

endmodule
