//=============================================================================
// Top-Level Module - v6.3 with FAST_SIM Parameter
//
// v6.3 CHANGES:
// - Added FAST_SIM parameter for testbench simulation speedup
// - FAST_SIM=1 uses ÷10 clock divider (vs ÷31250) for ~3000x faster simulation
// - All testbenches can now use full closed-loop DUT with fast simulation
//
// v6.2 CHANGES:
// - Removed ca3_pattern_in - sensory_input is the ONLY external data input
// - All learning must go through: sensory_input → thalamus → cortex → CA3
//
// v6.1 CHANGES:
// - CA3 pattern_in now derived from cortical activity (closed loop)
// - True recurrent architecture: cortex → CA3 → phase coupling → cortex
//
// v6.0 CHANGES:
// - 4 kHz update rate (was 1 kHz in v5.5) for better gamma resolution
// - Renamed clk_1khz_en → clk_4khz_en
// - K_PHASE = 4096 (validated stable at 4 kHz)
//
// FEATURES:
// - CA3 phase memory with Hebbian learning (v5.2)
// - Memory decay for unused associations (v5.3)
// - Phase coupling computation from theta × phase_pattern
// - Connected phase coupling to cortical columns (L2/3 and L6)
// - Theta-gated learning: encode at theta peak, recall at theta trough
//
// CLOSED-LOOP SIGNAL FLOW (v6.2 - sensory input only):
//   sensory_input → thalamus → theta_gated_output → cortical columns
//   Cortical L2/3 & L6 outputs → threshold → cortical_pattern (6-bit)
//   cortical_pattern → CA3 → phase_pattern
//   phase_pattern → phase coupling → cortical columns
//
// PHASE COUPLING MAPPING (6 bits → 6 oscillators):
//   Bit 0: Sensory L2/3 (gamma)
//   Bit 1: Sensory L6 (alpha)
//   Bit 2: Association L2/3 (gamma)
//   Bit 3: Association L6 (alpha)
//   Bit 4: Motor L2/3 (gamma)
//   Bit 5: Motor L6 (alpha)
//
// PHASE COUPLING MECHANISM:
//   phase_couple = K_PHASE × theta_x × sign
//   sign = +1 if bit=1 (in-phase), -1 if bit=0 (anti-phase)
//=============================================================================
`timescale 1ns / 1ps

module phi_n_neural_processor #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter FAST_SIM = 0  // 1 = use fast clock divider (÷10 vs ÷31250) for simulation
)(
    input  wire clk,
    input  wire rst,

    input  wire signed [WIDTH-1:0] sensory_input,  // v6.2: ONLY external data input
    input  wire [2:0] state_select,

    output wire [11:0] dac_output,
    output wire signed [WIDTH-1:0] debug_motor_l23,
    output wire signed [WIDTH-1:0] debug_theta,

    // CA3 status outputs
    output wire ca3_learning,
    output wire ca3_recalling,
    output wire [5:0] ca3_phase_pattern,

    // v6.1: Expose cortical pattern for debugging
    output wire [5:0] cortical_pattern_out
);

localparam signed [WIDTH-1:0] ONE_THIRD = 18'sd5461;
localparam signed [WIDTH-1:0] K_PHASE = 18'sd4096;  // 0.25 - phase coupling (validated stable at 4 kHz)

wire clk_4khz_en, clk_100khz_en;

clock_enable_generator #(
    .CLK_DIV_OVERRIDE(FAST_SIM ? 10 : 0)  // FAST_SIM: ÷10, normal: ÷31250
) clk_gen (
    .clk(clk),
    .rst(rst),
    .clk_4khz_en(clk_4khz_en),
    .clk_100khz_en(clk_100khz_en)
);

wire signed [WIDTH-1:0] mu_dt_theta;
wire signed [WIDTH-1:0] mu_dt_l6, mu_dt_l5b, mu_dt_l5a, mu_dt_l4, mu_dt_l23;

config_controller #(.WIDTH(WIDTH), .FRAC(FRAC)) config_ctrl (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .state_select(state_select),
    .mu_dt_theta(mu_dt_theta),
    .mu_dt_l6(mu_dt_l6),
    .mu_dt_l5b(mu_dt_l5b),
    .mu_dt_l5a(mu_dt_l5a),
    .mu_dt_l4(mu_dt_l4),
    .mu_dt_l23(mu_dt_l23)
);

wire signed [WIDTH-1:0] thalamic_theta_output;
wire signed [WIDTH-1:0] thalamic_theta_x, thalamic_theta_y;
wire signed [WIDTH-1:0] thalamic_theta_amp;
wire signed [WIDTH-1:0] l6_alpha_feedback;

wire signed [WIDTH-1:0] sensory_l6_x, assoc_l6_x, motor_l6_x;
wire signed [WIDTH-1:0] l6_sum;
wire signed [2*WIDTH-1:0] l6_avg_full;

assign l6_sum = sensory_l6_x + assoc_l6_x + motor_l6_x;
assign l6_avg_full = l6_sum * ONE_THIRD;
assign l6_alpha_feedback = l6_avg_full >>> FRAC;

thalamus #(.WIDTH(WIDTH), .FRAC(FRAC)) thal (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .sensory_input(sensory_input),
    .l6_alpha_feedback(l6_alpha_feedback),
    .mu_dt(mu_dt_theta),
    .theta_gated_output(thalamic_theta_output),
    .theta_x(thalamic_theta_x),
    .theta_y(thalamic_theta_y),
    .theta_amplitude(thalamic_theta_amp)
);

//=============================================================================
// CORTICAL PATTERN DERIVATION (v6.2 pure closed-loop)
// Derive CA3 input from cortical activity by thresholding oscillator outputs
// This creates the biological loop: cortex → hippocampus → cortex
// v6.2: No external injection - sensory_input is the only way to drive patterns
//=============================================================================
wire [5:0] cortical_pattern;

// Threshold cortical outputs: x > 0 → active (1), x ≤ 0 → inactive (0)
// Bit mapping matches phase coupling: [S_γ, S_α, A_γ, A_α, M_γ, M_α]
assign cortical_pattern[0] = ~sensory_l23_x[WIDTH-1];  // Sensory L2/3 gamma (sign bit)
assign cortical_pattern[1] = ~sensory_l6_x[WIDTH-1];   // Sensory L6 alpha
assign cortical_pattern[2] = ~assoc_l23_x[WIDTH-1];    // Association L2/3 gamma
assign cortical_pattern[3] = ~assoc_l6_x[WIDTH-1];     // Association L6 alpha
assign cortical_pattern[4] = ~motor_l23_x[WIDTH-1];    // Motor L2/3 gamma
assign cortical_pattern[5] = ~motor_l6_x[WIDTH-1];     // Motor L6 alpha

//=============================================================================
// CA3 PHASE MEMORY (v5.3 with decay, v6.2 pure closed-loop)
//=============================================================================
wire [5:0] phase_pattern;
wire ca3_learning_int, ca3_recalling_int;
wire [3:0] ca3_debug;

ca3_phase_memory #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .N_UNITS(6)
) ca3_mem (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .theta_x(thalamic_theta_x),
    .pattern_in(cortical_pattern),  // v6.2: Pure closed-loop, no external injection
    .phase_pattern(phase_pattern),
    .learning(ca3_learning_int),
    .recalling(ca3_recalling_int),
    .debug_state(ca3_debug)
);

assign ca3_learning = ca3_learning_int;
assign ca3_recalling = ca3_recalling_int;
assign ca3_phase_pattern = phase_pattern;

//=============================================================================
// PHASE COUPLING COMPUTATION
//=============================================================================
wire signed [2*WIDTH-1:0] theta_scaled;
wire signed [WIDTH-1:0] theta_couple_base;

assign theta_scaled = K_PHASE * thalamic_theta_x;
assign theta_couple_base = theta_scaled >>> FRAC;

wire signed [WIDTH-1:0] phase_couple_sensory_l23;
wire signed [WIDTH-1:0] phase_couple_sensory_l6;
wire signed [WIDTH-1:0] phase_couple_assoc_l23;
wire signed [WIDTH-1:0] phase_couple_assoc_l6;
wire signed [WIDTH-1:0] phase_couple_motor_l23;
wire signed [WIDTH-1:0] phase_couple_motor_l6;

assign phase_couple_sensory_l23 = phase_pattern[0] ? theta_couple_base : -theta_couple_base;
assign phase_couple_sensory_l6  = phase_pattern[1] ? theta_couple_base : -theta_couple_base;
assign phase_couple_assoc_l23   = phase_pattern[2] ? theta_couple_base : -theta_couple_base;
assign phase_couple_assoc_l6    = phase_pattern[3] ? theta_couple_base : -theta_couple_base;
assign phase_couple_motor_l23   = phase_pattern[4] ? theta_couple_base : -theta_couple_base;
assign phase_couple_motor_l6    = phase_pattern[5] ? theta_couple_base : -theta_couple_base;

//=============================================================================
// CORTICAL COLUMNS (with phase coupling)
//=============================================================================

wire signed [WIDTH-1:0] sensory_l23_x, sensory_l23_y, sensory_l5b_x, sensory_l5a_x, sensory_l4_x;
wire signed [WIDTH-1:0] sensory_l6_y;

wire signed [WIDTH-1:0] assoc_l23_x, assoc_l23_y, assoc_l5b_x, assoc_l5a_x, assoc_l4_x;
wire signed [WIDTH-1:0] assoc_l6_y;

wire signed [WIDTH-1:0] motor_l23_x, motor_l23_y, motor_l5b_x, motor_l5a_x, motor_l4_x;
wire signed [WIDTH-1:0] motor_l6_y;

wire signed [WIDTH-1:0] sensory_feedforward = 18'sd0;
wire signed [WIDTH-1:0] assoc_feedforward   = sensory_l23_x;
wire signed [WIDTH-1:0] motor_feedforward   = assoc_l23_x;

wire signed [WIDTH-1:0] motor_feedback   = 18'sd0;
wire signed [WIDTH-1:0] assoc_feedback   = motor_l5b_x;
wire signed [WIDTH-1:0] sensory_feedback = assoc_l5b_x;

cortical_column #(.WIDTH(WIDTH), .FRAC(FRAC)) col_sensory (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .thalamic_theta_input(thalamic_theta_output),
    .feedforward_input(sensory_feedforward),
    .feedback_input(sensory_feedback),
    .phase_couple_l23(phase_couple_sensory_l23),
    .phase_couple_l6(phase_couple_sensory_l6),
    .mu_dt_l6(mu_dt_l6),
    .mu_dt_l5b(mu_dt_l5b),
    .mu_dt_l5a(mu_dt_l5a),
    .mu_dt_l4(mu_dt_l4),
    .mu_dt_l23(mu_dt_l23),
    .l23_x(sensory_l23_x),
    .l23_y(sensory_l23_y),
    .l5b_x(sensory_l5b_x),
    .l5a_x(sensory_l5a_x),
    .l6_x(sensory_l6_x),
    .l6_y(sensory_l6_y),
    .l4_x(sensory_l4_x)
);

cortical_column #(.WIDTH(WIDTH), .FRAC(FRAC)) col_assoc (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .thalamic_theta_input(thalamic_theta_output),
    .feedforward_input(assoc_feedforward),
    .feedback_input(assoc_feedback),
    .phase_couple_l23(phase_couple_assoc_l23),
    .phase_couple_l6(phase_couple_assoc_l6),
    .mu_dt_l6(mu_dt_l6),
    .mu_dt_l5b(mu_dt_l5b),
    .mu_dt_l5a(mu_dt_l5a),
    .mu_dt_l4(mu_dt_l4),
    .mu_dt_l23(mu_dt_l23),
    .l23_x(assoc_l23_x),
    .l23_y(assoc_l23_y),
    .l5b_x(assoc_l5b_x),
    .l5a_x(assoc_l5a_x),
    .l6_x(assoc_l6_x),
    .l6_y(assoc_l6_y),
    .l4_x(assoc_l4_x)
);

cortical_column #(.WIDTH(WIDTH), .FRAC(FRAC)) col_motor (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .thalamic_theta_input(thalamic_theta_output),
    .feedforward_input(motor_feedforward),
    .feedback_input(motor_feedback),
    .phase_couple_l23(phase_couple_motor_l23),
    .phase_couple_l6(phase_couple_motor_l6),
    .mu_dt_l6(mu_dt_l6),
    .mu_dt_l5b(mu_dt_l5b),
    .mu_dt_l5a(mu_dt_l5a),
    .mu_dt_l4(mu_dt_l4),
    .mu_dt_l23(mu_dt_l23),
    .l23_x(motor_l23_x),
    .l23_y(motor_l23_y),
    .l5b_x(motor_l5b_x),
    .l5a_x(motor_l5a_x),
    .l6_x(motor_l6_x),
    .l6_y(motor_l6_y),
    .l4_x(motor_l4_x)
);

wire signed [WIDTH-1:0] pink_noise_out;

pink_noise_generator #(.WIDTH(WIDTH), .FRAC(FRAC)) pink_gen (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .noise_out(pink_noise_out)
);

wire signed [WIDTH-1:0] mixed_output;

output_mixer #(.WIDTH(WIDTH), .FRAC(FRAC)) mixer (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .motor_l23_x(motor_l23_x),
    .motor_l5a_x(motor_l5a_x),
    .pink_noise(pink_noise_out),
    .mixed_output(mixed_output),
    .dac_output(dac_output)
);

assign debug_motor_l23 = motor_l23_x;
assign debug_theta = thalamic_theta_x;
assign cortical_pattern_out = cortical_pattern;  // v6.1: Expose for debugging

endmodule
