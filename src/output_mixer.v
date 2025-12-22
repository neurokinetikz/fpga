//=============================================================================
// Output Mixer - v5.5
//=============================================================================
`timescale 1ns / 1ps

module output_mixer #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    input  wire signed [WIDTH-1:0] motor_l23_x,
    input  wire signed [WIDTH-1:0] motor_l5a_x,
    input  wire signed [WIDTH-1:0] pink_noise,

    output reg signed [WIDTH-1:0] mixed_output,
    output wire [11:0] dac_output
);

localparam signed [WIDTH-1:0] W_MOTOR_GAMMA = 18'sd6554;
localparam signed [WIDTH-1:0] W_MOTOR_BETA  = 18'sd4915;
localparam signed [WIDTH-1:0] W_PINK_NOISE  = 18'sd3277;

wire signed [2*WIDTH-1:0] term_gamma, term_beta, term_noise;
wire signed [2*WIDTH-1:0] sum_full;
wire signed [WIDTH-1:0] sum_scaled;

assign term_gamma = motor_l23_x * W_MOTOR_GAMMA;
assign term_beta  = motor_l5a_x * W_MOTOR_BETA;
assign term_noise = pink_noise  * W_PINK_NOISE;

assign sum_full = term_gamma + term_beta + term_noise;
assign sum_scaled = sum_full >>> FRAC;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mixed_output <= 18'sd0;
    end else if (clk_en) begin
        mixed_output <= sum_scaled;
    end
end

wire signed [WIDTH-1:0] shifted;
wire [15:0] dac_raw;

assign shifted = mixed_output + 18'sd16384;
assign dac_raw = shifted[17:3];
assign dac_output = (dac_raw > 16'd4095) ? 12'd4095 : dac_raw[11:0];

endmodule
