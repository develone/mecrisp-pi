
module blinky(
  input clk_25mhz,
  input [6:0] btn,
  output [7:0] led,
  output wifi_gpio0
  );

  wire clk = clk_25mhz;

  reg [31:0] clk_divider;

  always @(posedge clk) clk_divider <= btn[1] ? clk_divider + 8 : clk_divider + 1;

  assign led = clk_divider[28:21];

  // Tie GPIO0 high, keep board from rebooting
  assign wifi_gpio0 = 1'b1;

endmodule
