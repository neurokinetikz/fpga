//=============================================================================
// Cortical Column - v8.0 with Scaffold Architecture
//
// v8.0 CHANGES (Dupret et al. 2025 Integration):
// - Scaffold architecture: distinguishes stable vs plastic layers
// - Scaffold layers (L4, L5b) form stable backbone, no phase coupling
// - Plastic layers (L2/3, L6) receive phase coupling from CA3
// - Implements the "scaffolding principle" from hippocampal memory research:
//   "Higher-activity cells form stable backbone; lower-activity cells
//   integrate new motifs on demand"
//
// LAYER CLASSIFICATION (v8.0 Scaffold Architecture):
//
//   SCAFFOLD LAYERS (stable backbone, no phase coupling):
//     - L4 (31.73 Hz, φ³): Thalamocortical input boundary
//       • Anchors spatial/contextual representation
//       • Higher rate, more rigid activity
//       • Robust to perturbation by experience
//
//     - L5b (24.94 Hz, φ²·⁵): High beta, subcortical feedback
//       • Maintains state across time
//       • Provides stability for motor sequences
//       • No phase coupling preserves timing
//
//   PLASTIC LAYERS (flexible integration, with phase coupling):
//     - L2/3 (40.36 Hz, φ³·⁵): Gamma, feedforward output [PHASE COUPLED]
//       • Integrates new sensory patterns
//       • Lower rate, more plastic activity
//       • Phase coupling enables memory-guided gating
//
//     - L6 (9.53 Hz, φ⁰·⁵): Alpha, gain control / PAC [PHASE COUPLED]
//       • Modulates processing gain
//       • Phase coupling from CA3 memory
//       • Enables memory-dependent attention
//
//     - L5a (15.42 Hz, φ¹·⁵): Low beta, motor output
//       • Intermediate plasticity
//       • Motor learning and adaptation
//
// LAYER FREQUENCIES (φⁿ architecture):
// - L2/3: 40.36 Hz (φ^3.5) - Gamma, feedforward output [PLASTIC]
// - L4:   31.73 Hz (φ^3.0) - Boundary, thalamocortical input [SCAFFOLD]
// - L5a:  15.42 Hz (φ^1.5) - Low beta, motor output [INTERMEDIATE]
// - L5b:  24.94 Hz (φ^2.5) - High beta, subcortical feedback [SCAFFOLD]
// - L6:    9.53 Hz (φ^0.5) - Alpha, gain control / PAC [PLASTIC]
//=============================================================================
`timescale 1ns / 1ps

module cortical_column #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    input  wire signed [WIDTH-1:0] thalamic_theta_input,
    input  wire signed [WIDTH-1:0] feedforward_input,
    input  wire signed [WIDTH-1:0] feedback_input,

    // Phase coupling inputs from CA3
    input  wire signed [WIDTH-1:0] phase_couple_l23,
    input  wire signed [WIDTH-1:0] phase_couple_l6,

    input  wire signed [WIDTH-1:0] mu_dt_l6,
    input  wire signed [WIDTH-1:0] mu_dt_l5b,
    input  wire signed [WIDTH-1:0] mu_dt_l5a,
    input  wire signed [WIDTH-1:0] mu_dt_l4,
    input  wire signed [WIDTH-1:0] mu_dt_l23,

    output wire signed [WIDTH-1:0] l23_x,
    output wire signed [WIDTH-1:0] l23_y,
    output wire signed [WIDTH-1:0] l5b_x,
    output wire signed [WIDTH-1:0] l5a_x,
    output wire signed [WIDTH-1:0] l6_x,
    output wire signed [WIDTH-1:0] l6_y,
    output wire signed [WIDTH-1:0] l4_x
);

// OMEGA_DT = 2*pi*f*dt, dt=0.00025 for 4 kHz update rate
localparam signed [WIDTH-1:0] OMEGA_DT_L6  = 18'sd245;   // 9.53 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L5B = 18'sd642;   // 24.94 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L5A = 18'sd397;   // 15.42 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L4  = 18'sd817;   // 31.73 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L23 = 18'sd1039;  // 40.36 Hz

localparam signed [WIDTH-1:0] K_L4_L23 = 18'sd6554;
localparam signed [WIDTH-1:0] K_L4_L5  = 18'sd4915;
localparam signed [WIDTH-1:0] K_PAC    = 18'sd3277;
localparam signed [WIDTH-1:0] K_FB_L5  = 18'sd3277;

wire signed [WIDTH-1:0] l6_x_int, l6_y_int;
wire signed [WIDTH-1:0] l5b_x_int, l5b_y_int;
wire signed [WIDTH-1:0] l5a_x_int, l5a_y_int;
wire signed [WIDTH-1:0] l4_x_int, l4_y_int;
wire signed [WIDTH-1:0] l23_x_int, l23_y_int;

wire signed [WIDTH-1:0] l6_amp, l5b_amp, l5a_amp, l4_amp, l23_amp;

wire signed [WIDTH-1:0] l4_input, l23_input, l5_input, l6_input;
wire signed [2*WIDTH-1:0] l4_to_l5_full, l4_to_l23_full, pac_full, fb_l5_full;
wire signed [WIDTH-1:0] pac_mod;

assign l4_input = thalamic_theta_input + feedforward_input;

assign l4_to_l5_full = l4_x_int * K_L4_L5;
assign fb_l5_full = feedback_input * K_FB_L5;
assign l5_input = (l4_to_l5_full >>> FRAC) + (fb_l5_full >>> FRAC);

// L6 receives: feedback + PHASE COUPLING
assign l6_input = (fb_l5_full >>> FRAC) + phase_couple_l6;

assign pac_full = K_PAC * l6_y_int;
assign pac_mod = pac_full[FRAC +: WIDTH];

// L2/3 receives: L4 feedforward + PAC modulation + PHASE COUPLING
assign l4_to_l23_full = l4_x_int * K_L4_L23;
assign l23_input = (l4_to_l23_full >>> FRAC) + pac_mod + phase_couple_l23;

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l6 (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l6), .omega_dt(OMEGA_DT_L6),
    .input_x(l6_input),
    .x(l6_x_int), .y(l6_y_int), .amplitude(l6_amp)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l5b (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l5b), .omega_dt(OMEGA_DT_L5B),
    .input_x(l5_input),
    .x(l5b_x_int), .y(l5b_y_int), .amplitude(l5b_amp)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l5a (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l5a), .omega_dt(OMEGA_DT_L5A),
    .input_x(l5_input),
    .x(l5a_x_int), .y(l5a_y_int), .amplitude(l5a_amp)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l4 (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l4), .omega_dt(OMEGA_DT_L4),
    .input_x(l4_input),
    .x(l4_x_int), .y(l4_y_int), .amplitude(l4_amp)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l23 (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l23), .omega_dt(OMEGA_DT_L23),
    .input_x(l23_input),
    .x(l23_x_int), .y(l23_y_int), .amplitude(l23_amp)
);

assign l23_x = l23_x_int;
assign l23_y = l23_y_int;
assign l5b_x = l5b_x_int;
assign l5a_x = l5a_x_int;
assign l6_x  = l6_x_int;
assign l6_y  = l6_y_int;
assign l4_x  = l4_x_int;

endmodule
