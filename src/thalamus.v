//=============================================================================
// Thalamus Module - v7.4 with Continuous Coherence-Based Gain
//
// NEUROPHYSIOLOGICAL BASIS:
// "Layer 4 shows characteristic current sinks... with gamma and theta
// oscillations dominating this feedforward processing layer"
// "Gamma is not present in LGN... gamma is an emergent property of cortex"
//
// v7.4 CONTINUOUS GAIN BOOST:
// - Replaces binary SIE gain switching with continuous scaling
// - Per-harmonic gain = sigmoid(coherence) × beta_factor
// - Gains sum independently, total boost clamped to 2.0×
// - More biologically plausible: graded response to coherence levels
//
// v7.3 MULTI-HARMONIC SCHUMANN RESONANCE BANK:
// - 5 SR harmonics (7.83, 14.3, 20.8, 27.3, 33.8 Hz) externally driven
// - Each harmonic couples to corresponding EEG band:
//   f₀→theta, f₁→alpha, f₂→low beta, f₃→high beta, f₄→gamma
// - Per-harmonic coherence and SIE detection
// - Aggregate SIE when ANY harmonic achieves high coherence + beta quiet
//
// v7.2 STOCHASTIC RESONANCE MODEL (preserved):
// - Beta amplitude modulates the coupling gate (high beta masks SR)
// - When beta quiets (meditation), stochastic resonance enables detection
// - f₀ entrains theta when beta is at optimal quiet level
//
// Key insight: Brain doesn't generate SR — it TUNES INTO the external
// Schumann field when beta activity reaches optimal (quiet) levels.
//
// theta_x also feeds CA3 phase memory for learn/recall gating
//=============================================================================
`timescale 1ns / 1ps

module thalamus #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_HARMONICS = 5,
    parameter ENABLE_STOCHASTIC = 1  // Enable stochastic noise injection to SR bank
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    input  wire signed [WIDTH-1:0] sensory_input,
    input  wire signed [WIDTH-1:0] l6_alpha_feedback,
    input  wire signed [WIDTH-1:0] mu_dt,

    // v7.3: Multi-harmonic SR field inputs (packed: 5 × 18 bits = 90 bits)
    input  wire signed [NUM_HARMONICS*WIDTH-1:0] sr_field_packed,

    // Stochastic noise inputs for SR bank (packed: 5 × 18 bits = 90 bits)
    input  wire signed [NUM_HARMONICS*WIDTH-1:0] noise_packed,

    // v7.2 compatibility: Single SR field input (uses f₀ only)
    input  wire signed [WIDTH-1:0] sr_field_input,

    // v7.2: Beta amplitude from cortical L5 (for SR gating)
    input  wire signed [WIDTH-1:0] beta_amplitude,

    // v7.3: Cortical oscillator states for per-band coherence
    input  wire signed [WIDTH-1:0] alpha_x, alpha_y,        // L6 ~10 Hz
    input  wire signed [WIDTH-1:0] beta_low_x, beta_low_y,  // L5a ~15 Hz
    input  wire signed [WIDTH-1:0] beta_high_x, beta_high_y, // L5b ~25 Hz
    input  wire signed [WIDTH-1:0] gamma_x, gamma_y,        // L4 ~32 Hz

    // Theta outputs
    output wire signed [WIDTH-1:0] theta_gated_output,
    output wire signed [WIDTH-1:0] theta_x,
    output wire signed [WIDTH-1:0] theta_y,
    output wire signed [WIDTH-1:0] theta_amplitude,

    // f₀ SR Reference outputs (driven by external field) - v7.2 compatibility
    output wire signed [WIDTH-1:0] f0_x,
    output wire signed [WIDTH-1:0] f0_y,
    output wire signed [WIDTH-1:0] f0_amplitude,

    // v7.3: Multi-harmonic outputs (packed)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sr_f_x_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sr_f_y_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sr_amplitude_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sr_coherence_packed,

    // v7.3: Per-harmonic SIE status
    output wire [NUM_HARMONICS-1:0] sie_per_harmonic,
    output wire [NUM_HARMONICS-1:0] coherence_mask,

    // SR Coupling indicators (v7.2 compatibility + v7.3 aggregate)
    output wire signed [WIDTH-1:0] sr_coherence,      // f₀ coherence (v7.2 compat)
    output wire                    sr_amplification,  // SIE active (any harmonic)
    output wire                    beta_quiet         // Beta below threshold (SR-ready)
);

//-----------------------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------------------

// OMEGA_DT for 5.89 Hz theta: ω×dt = 2π×5.89×0.00025 = 0.00925 → Q14: 152
localparam signed [WIDTH-1:0] OMEGA_DT_THETA = 18'sd152;  // 4 kHz update rate

localparam signed [WIDTH-1:0] HALF = 18'sd8192;
localparam signed [WIDTH-1:0] GAIN_BASELINE = 18'sd16384;
localparam signed [WIDTH-1:0] ALPHA_COUPLING = 18'sd4915;

// Entrainment coupling strength: f₀ → θ (0.125 in Q14)
localparam signed [WIDTH-1:0] K_ENTRAIN = 18'sd2048;

// Amplification gain: 1.5× in Q14 (models SIE 4-5× power boost, conservative)
localparam signed [WIDTH-1:0] AMPLIFICATION_GAIN = 18'sd24576;
// Baseline gain: 1.0× in Q14
localparam signed [WIDTH-1:0] SR_BASELINE_GAIN = 18'sd16384;

//-----------------------------------------------------------------------------
// v7.3: Build SR field input - use packed if non-zero, else replicate single
//-----------------------------------------------------------------------------
wire signed [NUM_HARMONICS*WIDTH-1:0] sr_field_effective;

// If packed input is provided (non-zero), use it; otherwise replicate single f₀ input
// This allows both v7.2 (single) and v7.3 (multi) interfaces to work
assign sr_field_effective = (sr_field_packed != 0) ? sr_field_packed :
                            {sr_field_input, sr_field_input, sr_field_input, sr_field_input, sr_field_input};

//-----------------------------------------------------------------------------
// v7.3: Multi-Harmonic SR Bank
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] f0_x_int, f0_y_int, f0_amp_int, f0_coh_int;
wire beta_is_quiet;
wire sie_active_any;

// v7.4: Per-harmonic continuous gains
wire signed [NUM_HARMONICS*WIDTH-1:0] gain_per_harmonic;

sr_harmonic_bank #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_HARMONICS(NUM_HARMONICS),
    .ENABLE_STOCHASTIC(ENABLE_STOCHASTIC)
) sr_bank (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .mu_dt(mu_dt),

    // External SR field inputs (packed)
    .sr_field_packed(sr_field_effective),

    // Stochastic noise inputs (packed)
    .noise_packed(noise_packed),

    // Brain oscillator states for coherence computation
    .theta_x(theta_x_int),
    .theta_y(theta_y_int),
    .alpha_x(alpha_x),
    .alpha_y(alpha_y),
    .beta_low_x(beta_low_x),
    .beta_low_y(beta_low_y),
    .beta_high_x(beta_high_x),
    .beta_high_y(beta_high_y),
    .gamma_x(gamma_x),
    .gamma_y(gamma_y),

    // Beta amplitude for SR gating
    .beta_amplitude(beta_amplitude),

    // Per-harmonic outputs (packed)
    .f_x_packed(sr_f_x_packed),
    .f_y_packed(sr_f_y_packed),
    .f_amplitude_packed(sr_amplitude_packed),
    .coherence_packed(sr_coherence_packed),
    .sie_per_harmonic(sie_per_harmonic),

    // v7.4: Continuous per-harmonic gains
    .gain_per_harmonic_packed(gain_per_harmonic),

    // Aggregate outputs
    .sie_active_any(sie_active_any),
    .coherence_mask(coherence_mask),
    .beta_quiet(beta_is_quiet),

    // Primary f₀ outputs (backwards compatibility)
    .f0_x(f0_x_int),
    .f0_y(f0_y_int),
    .f0_amplitude(f0_amp_int),
    .f0_coherence(f0_coh_int)
);

//-----------------------------------------------------------------------------
// Entrainment Coupling (f₀ → Theta when beta quiet)
//-----------------------------------------------------------------------------
// Beta-gated coupling: f₀ can entrain theta only when beta is quiet.
// This implements the stochastic resonance mechanism where optimal
// "noise" (quiet beta) enables detection of weak periodic signals.

wire signed [WIDTH-1:0] entrain_coupling;
assign entrain_coupling = beta_is_quiet ? K_ENTRAIN : 18'sd0;

// Compute entrainment signal: K × f₀_x (when beta quiet)
wire signed [2*WIDTH-1:0] entrain_product;
wire signed [WIDTH-1:0] theta_entrain_input;
assign entrain_product = entrain_coupling * f0_x_int;
assign theta_entrain_input = entrain_product >>> FRAC;

//-----------------------------------------------------------------------------
// Theta Oscillator (5.89 Hz - hippocampal timing)
// Receives entrainment input from f₀ when beta is quiet
//-----------------------------------------------------------------------------

wire signed [WIDTH-1:0] theta_x_int, theta_y_int, theta_amp_int;

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) theta_relay (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .mu_dt(mu_dt),
    .omega_dt(OMEGA_DT_THETA),
    .input_x(theta_entrain_input),  // Entrained by f₀ when beta quiet
    .x(theta_x_int),
    .y(theta_y_int),
    .amplitude(theta_amp_int)
);

//-----------------------------------------------------------------------------
// Dynamic Amplification Logic (SIE Model)
// v7.4: Continuous gain based on summed per-harmonic contributions
// Each harmonic contributes 0 to 1.0 (Q14), scaled to 0.2× boost each
// Total boost range: 1.0× (no coherence) to 2.0× (all harmonics maxed)
//-----------------------------------------------------------------------------

// Unpack per-harmonic gains
wire signed [WIDTH-1:0] gain_h0, gain_h1, gain_h2, gain_h3, gain_h4;
assign gain_h0 = gain_per_harmonic[0*WIDTH +: WIDTH];
assign gain_h1 = gain_per_harmonic[1*WIDTH +: WIDTH];
assign gain_h2 = gain_per_harmonic[2*WIDTH +: WIDTH];
assign gain_h3 = gain_per_harmonic[3*WIDTH +: WIDTH];
assign gain_h4 = gain_per_harmonic[4*WIDTH +: WIDTH];

// Sum all per-harmonic gains (each 0 to 16384 Q14)
// Total can be 0 to 81920 (5 × 16384)
wire signed [WIDTH+2:0] total_gain_sum;
assign total_gain_sum = gain_h0 + gain_h1 + gain_h2 + gain_h3 + gain_h4;

// Scale: each harmonic contributes up to 0.2× boost when at max
// Boost = total_gain_sum / 5 × 0.2 = total_gain_sum × 0.2/5 = total_gain_sum × 0.04
// 0.04 in Q14 = 655.36 ≈ 655
// Or simpler: total_gain_sum / 5 gives 0-16384 per harmonic avg
// Then scale by 0.2: (avg / 5) = total / 25 ≈ total >> 4.64 ≈ (total * 3) >> 6
wire signed [WIDTH+4:0] boost_scaled;
assign boost_scaled = (total_gain_sum * 20'sd3277) >>> FRAC;  // 3277/16384 ≈ 0.2

// Dynamic gain = baseline (1.0×) + boost (0 to 1.0×)
wire signed [WIDTH-1:0] dynamic_gain_raw;
wire signed [WIDTH-1:0] dynamic_gain;
assign dynamic_gain_raw = SR_BASELINE_GAIN + boost_scaled[WIDTH-1:0];

// Clamp to max 2.0× (32768 in Q14)
localparam signed [WIDTH-1:0] MAX_GAIN = 18'sd32768;  // 2.0 in Q14
assign dynamic_gain = (dynamic_gain_raw > MAX_GAIN) ? MAX_GAIN : dynamic_gain_raw;

//-----------------------------------------------------------------------------
// Theta Gate and Gain Computation
//-----------------------------------------------------------------------------

wire signed [WIDTH-1:0] theta_gate_raw;
wire signed [WIDTH-1:0] theta_gate;
wire signed [2*WIDTH-1:0] gated_full;

assign theta_gate_raw = HALF + (theta_x_int >>> 1);
assign theta_gate = (theta_gate_raw[WIDTH-1]) ? 18'sd0 : theta_gate_raw;

// Alpha feedback modulation (existing behavior)
wire signed [WIDTH-1:0] alpha_abs;
wire signed [2*WIDTH-1:0] alpha_modulation;
wire signed [WIDTH-1:0] gain;

assign alpha_abs = l6_alpha_feedback[WIDTH-1] ? -l6_alpha_feedback : l6_alpha_feedback;
assign alpha_modulation = ALPHA_COUPLING * alpha_abs;
assign gain = GAIN_BASELINE - (alpha_modulation >>> FRAC);

// Apply dynamic SR amplification to gain
wire signed [2*WIDTH-1:0] amplified_gain_full;
wire signed [WIDTH-1:0] final_gain;

assign amplified_gain_full = gain * dynamic_gain;
assign final_gain = amplified_gain_full >>> FRAC;

//-----------------------------------------------------------------------------
// Output Computation
//-----------------------------------------------------------------------------

wire signed [2*WIDTH-1:0] gain_applied;
wire signed [WIDTH-1:0] gain_applied_scaled;

assign gain_applied = sensory_input * final_gain;
assign gain_applied_scaled = gain_applied >>> FRAC;
assign gated_full = gain_applied_scaled * theta_gate;
assign theta_gated_output = gated_full >>> FRAC;

//-----------------------------------------------------------------------------
// Output Assignments
//-----------------------------------------------------------------------------

// Theta outputs
assign theta_x = theta_x_int;
assign theta_y = theta_y_int;
assign theta_amplitude = theta_amp_int;

// f₀ outputs (v7.2 compatibility)
assign f0_x = f0_x_int;
assign f0_y = f0_y_int;
assign f0_amplitude = f0_amp_int;

// SR coupling outputs
assign sr_coherence = f0_coh_int;        // f₀ coherence (v7.2 compat)
assign sr_amplification = sie_active_any; // SIE active (any harmonic)
assign beta_quiet = beta_is_quiet;        // Expose SR-ready state

endmodule
