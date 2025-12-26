//=============================================================================
// Cortical Column - v8.7 with Matrix Thalamic Input to Layer 1
//
// v8.7 CHANGES (Matrix Thalamic Input):
// - Added matrix_thalamic_input port for diffuse thalamic modulation
// - Matrix thalamus (POm, Pulvinar) projects to L1 across all columns
// - Implements cortex→matrix thalamus→L1 feedback loop
// - L1 now integrates: matrix input + feedback_1 + feedback_2
//
// v9.1 CHANGES (Dual Feedback Inputs):
// - L1 now receives two feedback inputs for longer-range modulation
// - feedback_input_1: adjacent column feedback (weight 0.3)
// - feedback_input_2: distant column feedback (weight 0.2)
// - Enables hierarchical top-down: Motor → Association → Sensory
//
// v9.0 CHANGES (Spectrolaminar Architecture - Layer 1):
// - Added Layer 1 (molecular layer) for top-down gain modulation
// - L1 receives feedback_input, outputs apical_gain (0.5 to 1.5)
// - L2/3 input is modulated by apical_gain (apical dendrites in L1)
// - L5 input is modulated by apical_gain (thick-tufted PT neurons reach L1)
// - Implements: feedback -> L1 -> gain modulation of superficial processing
//
// v8.6 CHANGES (Canonical Microcircuit):
// - L5 now receives from L2/3 (processed) instead of L4 (raw)
// - L6 receives intra-column L5b feedback for corticothalamic modulation
// - Implements canonical L4→L2/3→L5→L6→Thalamus pathway
// - Signal flow: Thalamus→L4→L2/3→L5→output, L5→L6→Thalamus
//
// v8.1 CHANGES (Theta-Phase Gamma Nesting):
// - L2/3 gamma frequency now switches based on theta phase (encoding_window)
// - encoding_window=1 (encoding): fast gamma (65.3 Hz, φ⁴·⁵)
// - encoding_window=0 (retrieval): slow gamma (40.36 Hz, φ³·⁵)
// - Frequency ratio = φ (exactly one golden ratio step)
// - Implements true theta-gamma PAC with functional meaning:
//   "Slow gamma at late theta = retrieval; Fast gamma at theta trough = encoding"
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
//     - L2/3 (40.36/65.3 Hz, φ³·⁵/φ⁴·⁵): Gamma, feedforward output [PHASE COUPLED]
//       • Integrates new sensory patterns
//       • Fast gamma (65.3 Hz) during encoding for precise temporal coding
//       • Slow gamma (40.36 Hz) during retrieval matches CA3 reactivation
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
// - L2/3: 40.36/65.3 Hz (φ^3.5/φ^4.5) - Gamma, theta-phase dependent [PLASTIC]
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

    // v9.2: Matrix thalamic input (diffuse projection to L1)
    input  wire signed [WIDTH-1:0] matrix_thalamic_input,

    // v9.1: Dual feedback inputs for L1 gain modulation
    input  wire signed [WIDTH-1:0] feedback_input_1,  // Adjacent column (weight 0.3)
    input  wire signed [WIDTH-1:0] feedback_input_2,  // Distant column (weight 0.2)

    // Phase coupling inputs from CA3
    input  wire signed [WIDTH-1:0] phase_couple_l23,
    input  wire signed [WIDTH-1:0] phase_couple_l6,

    // v8.1: Theta phase window for gamma nesting
    input  wire encoding_window,  // From CA3: 1=encoding (fast gamma), 0=retrieval (slow gamma)

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
// Formula: OMEGA_DT = round(2π × f_hz × 0.00025 × 16384)
localparam signed [WIDTH-1:0] OMEGA_DT_L6  = 18'sd245;   // 9.53 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L5B = 18'sd642;   // 24.94 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L5A = 18'sd397;   // 15.42 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L4  = 18'sd817;   // 31.73 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L23 = 18'sd1039;  // 40.36 Hz (slow gamma, φ³·⁵)

// v8.1: Fast gamma for encoding window - exactly φ higher than slow gamma
// 65.3 Hz = 40.36 Hz × φ (one golden ratio step up)
localparam signed [WIDTH-1:0] OMEGA_DT_L23_FAST = 18'sd1681;  // 65.3 Hz (fast gamma, φ⁴·⁵)

// v8.1: Theta-phase-dependent gamma frequency selection
// encoding_window=1 → fast gamma (65.3 Hz) for precise temporal coding during sensory input
// encoding_window=0 → slow gamma (40.36 Hz) matches CA3 reactivation during retrieval
wire signed [WIDTH-1:0] omega_dt_l23_active;
assign omega_dt_l23_active = encoding_window ? OMEGA_DT_L23_FAST : OMEGA_DT_L23;

// v8.6: Coupling constants for canonical microcircuit
localparam signed [WIDTH-1:0] K_L4_L23 = 18'sd6554;  // 0.4 - L4 → L2/3
localparam signed [WIDTH-1:0] K_L23_L5 = 18'sd4915;  // 0.3 - L2/3 → L5 (canonical pathway)
localparam signed [WIDTH-1:0] K_L5_L6  = 18'sd3277;  // 0.2 - L5b → L6 intra-column feedback
localparam signed [WIDTH-1:0] K_PAC    = 18'sd3277;  // 0.2 - PAC modulation
localparam signed [WIDTH-1:0] K_FB_L5  = 18'sd3277;  // 0.2 - Inter-column feedback

wire signed [WIDTH-1:0] l6_x_int, l6_y_int;
wire signed [WIDTH-1:0] l5b_x_int, l5b_y_int;
wire signed [WIDTH-1:0] l5a_x_int, l5a_y_int;
wire signed [WIDTH-1:0] l4_x_int, l4_y_int;
wire signed [WIDTH-1:0] l23_x_int, l23_y_int;

wire signed [WIDTH-1:0] l6_amp, l5b_amp, l5a_amp, l4_amp, l23_amp;

// v9.0: Layer 1 apical gain modulation
wire signed [WIDTH-1:0] l1_apical_gain;

wire signed [WIDTH-1:0] l4_input, l23_input, l5_input, l6_input;
wire signed [WIDTH-1:0] l23_input_raw, l5_input_raw;  // v9.0: Pre-modulation inputs
wire signed [2*WIDTH-1:0] l23_to_l5_full, l4_to_l23_full, pac_full, fb_l5_full;
wire signed [2*WIDTH-1:0] l5_to_l6_full;  // v8.6: Intra-column L5b → L6 feedback
wire signed [WIDTH-1:0] pac_mod;

//=============================================================================
// v9.2: Layer 1 - Matrix Thalamic + Dual Feedback Apical Gain Modulation
//=============================================================================
// L1 receives matrix thalamic input plus TWO cortico-cortical feedback sources.
// This models the molecular layer's integration of:
// - matrix_thalamic_input: diffuse projection from POm/Pulvinar (global attention)
// - feedback_input_1: adjacent column (e.g., association → sensory)
// - feedback_input_2: distant column (e.g., motor → sensory)
layer1_minimal #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) l1 (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .matrix_thalamic_input(matrix_thalamic_input),  // v9.2: diffuse thalamic
    .feedback_input_1(feedback_input_1),
    .feedback_input_2(feedback_input_2),
    .apical_gain(l1_apical_gain)
);

//=============================================================================
// Layer Input Computations with L1 Gain Modulation
//=============================================================================

// L4 input: thalamic + feedforward (L4 dendrites don't reach L1, no gain)
assign l4_input = thalamic_theta_input + feedforward_input;

// v8.6: L5 receives from L2/3 (processed) instead of L4 (raw)
// This implements canonical cortical pathway: L4 → L2/3 → L5
assign l23_to_l5_full = l23_x_int * K_L23_L5;
// v9.1: Use primary feedback (feedback_input_1) for L5/L6 direct input
assign fb_l5_full = feedback_input_1 * K_FB_L5;

// v9.0: L5 raw input (before L1 modulation)
assign l5_input_raw = (l23_to_l5_full >>> FRAC) + (fb_l5_full >>> FRAC);

// v9.0: Apply L1 apical gain to L5 input (PT neurons have thick-tufted dendrites in L1)
wire signed [2*WIDTH-1:0] l5_input_modulated;
assign l5_input_modulated = l5_input_raw * l1_apical_gain;
assign l5_input = l5_input_modulated >>> FRAC;

// v8.6: L6 receives: intra-column L5b feedback + inter-column feedback + PHASE COUPLING
// Implements corticothalamic pathway: L5 → L6 → Thalamus
// Note: L6 dendrites don't extend to L1, so no gain modulation here
assign l5_to_l6_full = l5b_x_int * K_L5_L6;
assign l6_input = (l5_to_l6_full >>> FRAC) + (fb_l5_full >>> FRAC) + phase_couple_l6;

assign pac_full = K_PAC * l6_y_int;
assign pac_mod = pac_full[FRAC +: WIDTH];

// L2/3 receives: L4 feedforward + PAC modulation + PHASE COUPLING
assign l4_to_l23_full = l4_x_int * K_L4_L23;

// v9.0: L2/3 raw input (before L1 modulation)
assign l23_input_raw = (l4_to_l23_full >>> FRAC) + pac_mod + phase_couple_l23;

// v9.0: Apply L1 apical gain to L2/3 input (pyramidal neurons have apical tufts in L1)
wire signed [2*WIDTH-1:0] l23_input_modulated;
assign l23_input_modulated = l23_input_raw * l1_apical_gain;
assign l23_input = l23_input_modulated >>> FRAC;

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

// v8.1: L2/3 now uses dynamic omega based on theta phase (gamma nesting)
hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l23 (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l23), .omega_dt(omega_dt_l23_active),  // v8.1: theta-phase dependent
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
