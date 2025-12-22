//=============================================================================
// Thalamus Module - v5.5 with Clamped Theta Gate
//
// NEUROPHYSIOLOGICAL BASIS:
// "Layer 4 shows characteristic current sinks... with gamma and theta
// oscillations dominating this feedforward processing layer"
// "Gamma is not present in LGN... gamma is an emergent property of cortex"
//
// theta_x also feeds CA3 phase memory for learn/recall gating
//=============================================================================
`timescale 1ns / 1ps

module thalamus #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    input  wire signed [WIDTH-1:0] sensory_input,
    input  wire signed [WIDTH-1:0] l6_alpha_feedback,
    input  wire signed [WIDTH-1:0] mu_dt,

    output wire signed [WIDTH-1:0] theta_gated_output,
    output wire signed [WIDTH-1:0] theta_x,
    output wire signed [WIDTH-1:0] theta_y,
    output wire signed [WIDTH-1:0] theta_amplitude
);

// OMEGA_DT for 5.89 Hz theta: ω×dt = 2π×5.89×0.00025 = 0.00925 → Q14: 152
localparam signed [WIDTH-1:0] OMEGA_DT_THETA = 18'sd152;  // 4 kHz update rate
localparam signed [WIDTH-1:0] HALF = 18'sd8192;
localparam signed [WIDTH-1:0] GAIN_BASELINE = 18'sd16384;
localparam signed [WIDTH-1:0] ALPHA_COUPLING = 18'sd4915;

wire signed [WIDTH-1:0] theta_x_int, theta_y_int, theta_amp_int;

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) theta_relay (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .mu_dt(mu_dt),
    .omega_dt(OMEGA_DT_THETA),
    .input_x(18'sd0),
    .x(theta_x_int),
    .y(theta_y_int),
    .amplitude(theta_amp_int)
);

wire signed [WIDTH-1:0] theta_gate_raw;
wire signed [WIDTH-1:0] theta_gate;
wire signed [2*WIDTH-1:0] gated_full;

assign theta_gate_raw = HALF + (theta_x_int >>> 1);
assign theta_gate = (theta_gate_raw[WIDTH-1]) ? 18'sd0 : theta_gate_raw;

wire signed [WIDTH-1:0] alpha_abs;
wire signed [2*WIDTH-1:0] alpha_modulation;
wire signed [WIDTH-1:0] gain;

assign alpha_abs = l6_alpha_feedback[WIDTH-1] ? -l6_alpha_feedback : l6_alpha_feedback;
assign alpha_modulation = ALPHA_COUPLING * alpha_abs;
assign gain = GAIN_BASELINE - (alpha_modulation >>> FRAC);

wire signed [2*WIDTH-1:0] gain_applied;
wire signed [WIDTH-1:0] gain_applied_scaled;

assign gain_applied = sensory_input * gain;
assign gain_applied_scaled = gain_applied >>> FRAC;
assign gated_full = gain_applied_scaled * theta_gate;
assign theta_gated_output = gated_full >>> FRAC;

assign theta_x = theta_x_int;
assign theta_y = theta_y_int;
assign theta_amplitude = theta_amp_int;

endmodule
