//=============================================================================
// φⁿ-Scaled Harmonic Bank v7.3.1
//
// Implements 5 externally-driven Hopf oscillators at φⁿ-scaled frequencies.
// Each harmonic can independently couple to brain oscillators when beta quiet.
//
// φⁿ HARMONIC MAPPING (φ = 1.618034, f_base = 7.49 Hz):
//   f₀ (7.49 Hz)  → φ⁰ → Theta band (5.89 Hz internal)
//   f₁ (12.12 Hz) → φ¹ → Alpha/Low Beta boundary (L6 ~9.53 Hz)
//   f₂ (19.60 Hz) → φ² → Beta (L5a ~15.42 Hz)
//   f₃ (31.73 Hz) → φ³ → φ³ consciousness gate (L4 ~31.73 Hz)
//   f₄ (51.33 Hz) → φ⁴ → High Gamma (beyond L2/3 ~40.36 Hz)
//
// STOCHASTIC RESONANCE MODEL:
// - Each harmonic is externally driven (represents weak φⁿ-scaled field)
// - Beta amplitude gates all entrainment (when beta quiet, coupling enabled)
// - Per-harmonic coherence computed against matching EEG band
// - SIE activates when ANY harmonic achieves high coherence + beta quiet
//=============================================================================
`timescale 1ns / 1ps

module sr_harmonic_bank #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_HARMONICS = 5,
    parameter ENABLE_STOCHASTIC = 1  // Enable stochastic noise injection
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,
    input  wire signed [WIDTH-1:0] mu_dt,

    // External SR field inputs (one per harmonic) - packed for synthesis
    input  wire signed [NUM_HARMONICS*WIDTH-1:0] sr_field_packed,

    // Stochastic noise inputs (one per harmonic) - packed for synthesis
    input  wire signed [NUM_HARMONICS*WIDTH-1:0] noise_packed,

    // Brain oscillator states for coherence computation
    input  wire signed [WIDTH-1:0] theta_x, theta_y,      // 5.89 Hz (thalamus)
    input  wire signed [WIDTH-1:0] alpha_x, alpha_y,      // ~10 Hz (L6)
    input  wire signed [WIDTH-1:0] beta_low_x, beta_low_y,  // ~15 Hz (L5a)
    input  wire signed [WIDTH-1:0] beta_high_x, beta_high_y, // ~25 Hz (L5b)
    input  wire signed [WIDTH-1:0] gamma_x, gamma_y,      // ~32 Hz (L4)

    // Beta amplitude for SR gating
    input  wire signed [WIDTH-1:0] beta_amplitude,

    // Per-harmonic outputs - packed for synthesis
    output wire signed [NUM_HARMONICS*WIDTH-1:0] f_x_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] f_y_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] f_amplitude_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] coherence_packed,
    output wire [NUM_HARMONICS-1:0] sie_per_harmonic,

    // v7.4: Continuous per-harmonic gain (replaces binary SIE)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] gain_per_harmonic_packed,

    // Aggregate outputs
    output wire sie_active_any,                    // Any harmonic in SIE state
    output wire [NUM_HARMONICS-1:0] coherence_mask, // Which harmonics have high coherence
    output wire beta_quiet,                        // Beta below threshold

    // Primary f₀ outputs for backwards compatibility with v7.2
    output wire signed [WIDTH-1:0] f0_x,
    output wire signed [WIDTH-1:0] f0_y,
    output wire signed [WIDTH-1:0] f0_amplitude,
    output wire signed [WIDTH-1:0] f0_coherence
);

//-----------------------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------------------

// OMEGA_DT values for φⁿ-scaled harmonics (Q14 format)
// Formula: OMEGA_DT = round(2π × f_hz × dt × 2^14) where dt = 0.00025s (4 kHz)
// φ = 1.618034, f_base = 7.49 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_F0 = 18'sd193;   // 7.49 Hz  (φ⁰ × 7.49)
localparam signed [WIDTH-1:0] OMEGA_DT_F1 = 18'sd312;   // 12.12 Hz (φ¹ × 7.49)
localparam signed [WIDTH-1:0] OMEGA_DT_F2 = 18'sd504;   // 19.60 Hz (φ² × 7.49)
localparam signed [WIDTH-1:0] OMEGA_DT_F3 = 18'sd817;   // 31.73 Hz (φ³ × 7.49)
localparam signed [WIDTH-1:0] OMEGA_DT_F4 = 18'sd1321;  // 51.33 Hz (φ⁴ × 7.49)

// Beta quiet threshold: 0.75 in Q14 (power-of-2 friendly for shift operations)
localparam signed [WIDTH-1:0] BETA_QUIET_THRESHOLD = 18'sd12288;

// Coherence threshold: 0.75 in Q14 (high phase-locking = SIE state)
localparam signed [WIDTH-1:0] COHERENCE_THRESHOLD = 18'sd12288;

// Continuous gain parameters (piecewise linear sigmoid approximation)
// Coherence floor: 0.5 - below this, no contribution
localparam signed [WIDTH-1:0] COH_LOW = 18'sd8192;   // 0.5 in Q14
// Coherence ceiling: 1.0 - above this, full contribution
localparam signed [WIDTH-1:0] COH_HIGH = 18'sd16384; // 1.0 in Q14
// One in Q14 format
localparam signed [WIDTH-1:0] ONE_Q14 = 18'sd16384;

//-----------------------------------------------------------------------------
// Unpack input signals
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] sr_field_input [0:NUM_HARMONICS-1];
assign sr_field_input[0] = sr_field_packed[0*WIDTH +: WIDTH];
assign sr_field_input[1] = sr_field_packed[1*WIDTH +: WIDTH];
assign sr_field_input[2] = sr_field_packed[2*WIDTH +: WIDTH];
assign sr_field_input[3] = sr_field_packed[3*WIDTH +: WIDTH];
assign sr_field_input[4] = sr_field_packed[4*WIDTH +: WIDTH];

//-----------------------------------------------------------------------------
// Unpack noise signals
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] noise_input [0:NUM_HARMONICS-1];
assign noise_input[0] = noise_packed[0*WIDTH +: WIDTH];
assign noise_input[1] = noise_packed[1*WIDTH +: WIDTH];
assign noise_input[2] = noise_packed[2*WIDTH +: WIDTH];
assign noise_input[3] = noise_packed[3*WIDTH +: WIDTH];
assign noise_input[4] = noise_packed[4*WIDTH +: WIDTH];

//-----------------------------------------------------------------------------
// Beta Quiet Detection (Stochastic Resonance Gate)
//-----------------------------------------------------------------------------
wire beta_is_quiet;
assign beta_is_quiet = (beta_amplitude < BETA_QUIET_THRESHOLD);
assign beta_quiet = beta_is_quiet;

//-----------------------------------------------------------------------------
// v7.4: Continuous Beta Factor (replaces binary gate)
// beta_factor = 1.0 when beta=0, linearly decreases to 0.0 at threshold
// Formula: beta_factor = max(0, 1 - beta_amplitude / threshold)
// Using shift approximation: threshold=12288, so /12288 ≈ *4/3/16384
// Simplified: beta_factor = (threshold - beta_amplitude) * (16384/12288)
//           = (threshold - beta_amplitude) * 4/3 (then shift)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] beta_diff;
wire signed [WIDTH-1:0] beta_factor;
wire signed [2*WIDTH-1:0] beta_factor_full;

// Clamp: if beta >= threshold, diff = 0
assign beta_diff = (beta_amplitude >= BETA_QUIET_THRESHOLD) ? 18'sd0 :
                   (BETA_QUIET_THRESHOLD - beta_amplitude);

// Scale to Q14: (diff / threshold) * 16384 = diff * (16384/12288) = diff * 4/3
// Approximate 4/3 as (1 + 1/4 + 1/16) = 1.3125 (close enough)
// = diff + (diff >> 2) + (diff >> 4)
assign beta_factor_full = {beta_diff, 14'b0} + {2'b0, beta_diff, 12'b0} + {4'b0, beta_diff, 10'b0};
assign beta_factor = (beta_factor_full[2*WIDTH-1:FRAC] > ONE_Q14) ? ONE_Q14 :
                     beta_factor_full[FRAC +: WIDTH];

//-----------------------------------------------------------------------------
// OMEGA_DT Array for Generate Block
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] OMEGA_DT_HARMONICS [0:NUM_HARMONICS-1];
assign OMEGA_DT_HARMONICS[0] = OMEGA_DT_F0;
assign OMEGA_DT_HARMONICS[1] = OMEGA_DT_F1;
assign OMEGA_DT_HARMONICS[2] = OMEGA_DT_F2;
assign OMEGA_DT_HARMONICS[3] = OMEGA_DT_F3;
assign OMEGA_DT_HARMONICS[4] = OMEGA_DT_F4;

//-----------------------------------------------------------------------------
// Coherence Target Mapping
// Each SR harmonic computes coherence against the nearest EEG band
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] target_x [0:NUM_HARMONICS-1];
wire signed [WIDTH-1:0] target_y [0:NUM_HARMONICS-1];

assign target_x[0] = theta_x;     assign target_y[0] = theta_y;     // f₀ → theta
assign target_x[1] = alpha_x;     assign target_y[1] = alpha_y;     // f₁ → alpha
assign target_x[2] = beta_low_x;  assign target_y[2] = beta_low_y;  // f₂ → low beta
assign target_x[3] = beta_high_x; assign target_y[3] = beta_high_y; // f₃ → high beta
assign target_x[4] = gamma_x;     assign target_y[4] = gamma_y;     // f₄ → gamma

//-----------------------------------------------------------------------------
// Internal signals for generate block outputs
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] f_x_int [0:NUM_HARMONICS-1];
wire signed [WIDTH-1:0] f_y_int [0:NUM_HARMONICS-1];
wire signed [WIDTH-1:0] f_amp_int [0:NUM_HARMONICS-1];
wire signed [WIDTH-1:0] coh_abs_int [0:NUM_HARMONICS-1];
wire [NUM_HARMONICS-1:0] high_coherence_int;
wire [NUM_HARMONICS-1:0] sie_active_int;

// v7.4: Per-harmonic continuous gain values
wire signed [WIDTH-1:0] gain_int [0:NUM_HARMONICS-1];

//-----------------------------------------------------------------------------
// Generate Block: Create 5 Hopf Oscillators with Coherence Detection
//-----------------------------------------------------------------------------
genvar h;
generate
    for (h = 0; h < NUM_HARMONICS; h = h + 1) begin : harmonic_gen

        // Internal signals for this harmonic
        wire signed [WIDTH-1:0] f_x_local, f_y_local, f_amp_local;
        wire signed [2*WIDTH-1:0] dot_product;
        wire signed [WIDTH-1:0] coh_raw, coh_abs_local;

        // v7.4: Continuous gain signals
        wire signed [WIDTH-1:0] coh_diff;
        wire signed [WIDTH-1:0] coh_factor;
        wire signed [2*WIDTH-1:0] gain_product;
        wire signed [WIDTH-1:0] gain_local;

        // Noise input: enabled by ENABLE_STOCHASTIC parameter
        wire signed [WIDTH-1:0] noise_effective;
        assign noise_effective = ENABLE_STOCHASTIC ? noise_input[h] : 18'sd0;

        // Hopf oscillator for this harmonic (stochastic variant)
        hopf_oscillator_stochastic #(
            .WIDTH(WIDTH),
            .FRAC(FRAC)
        ) f_osc (
            .clk(clk),
            .rst(rst),
            .clk_en(clk_en),
            .mu_dt(mu_dt),
            .omega_dt(OMEGA_DT_HARMONICS[h]),
            .input_x(sr_field_input[h]),  // Externally driven
            .noise_x(noise_effective),    // Stochastic noise injection
            .x(f_x_local),
            .y(f_y_local),
            .amplitude(f_amp_local)
        );

        // Phase coherence: target_oscillator · f_h
        // cos(θ_target - θ_fh) = (x_target × x_fh + y_target × y_fh) / (|target| × |fh|)
        // With amplitude stabilization at r≈1, simplify to just dot product
        assign dot_product = (target_x[h] * f_x_local) + (target_y[h] * f_y_local);
        assign coh_raw = dot_product >>> FRAC;
        assign coh_abs_local = coh_raw[WIDTH-1] ? -coh_raw : coh_raw;

        // High coherence detection (kept for backwards compatibility)
        assign high_coherence_int[h] = (coh_abs_local > COHERENCE_THRESHOLD);

        // SIE for this harmonic: coherence + beta quiet (kept for backwards compatibility)
        assign sie_active_int[h] = high_coherence_int[h] && beta_is_quiet;

        //---------------------------------------------------------------------
        // v7.4: Continuous Coherence Factor (piecewise linear sigmoid)
        // Below COH_LOW (0.5): factor = 0
        // Above COH_HIGH (1.0): factor = 1.0
        // Between: linear ramp, factor = (coh - 0.5) * 2
        //---------------------------------------------------------------------
        assign coh_diff = (coh_abs_local < COH_LOW) ? 18'sd0 :
                          (coh_abs_local >= COH_HIGH) ? COH_LOW :  // COH_LOW = 8192 = half of 16384
                          (coh_abs_local - COH_LOW);

        // Scale coh_diff (0 to 8192) to coh_factor (0 to 16384): multiply by 2
        assign coh_factor = coh_diff << 1;

        //---------------------------------------------------------------------
        // v7.4: Per-Harmonic Gain = coh_factor × beta_factor
        // Both are Q14, so product is Q28, shift back to Q14
        //---------------------------------------------------------------------
        assign gain_product = coh_factor * beta_factor;
        assign gain_local = gain_product >>> FRAC;

        // Connect to output arrays
        assign f_x_int[h] = f_x_local;
        assign f_y_int[h] = f_y_local;
        assign f_amp_int[h] = f_amp_local;
        assign coh_abs_int[h] = coh_abs_local;
        assign gain_int[h] = gain_local;

    end
endgenerate

//-----------------------------------------------------------------------------
// Pack output signals
//-----------------------------------------------------------------------------
assign f_x_packed = {f_x_int[4], f_x_int[3], f_x_int[2], f_x_int[1], f_x_int[0]};
assign f_y_packed = {f_y_int[4], f_y_int[3], f_y_int[2], f_y_int[1], f_y_int[0]};
assign f_amplitude_packed = {f_amp_int[4], f_amp_int[3], f_amp_int[2], f_amp_int[1], f_amp_int[0]};
assign coherence_packed = {coh_abs_int[4], coh_abs_int[3], coh_abs_int[2], coh_abs_int[1], coh_abs_int[0]};

// v7.4: Pack per-harmonic continuous gains
assign gain_per_harmonic_packed = {gain_int[4], gain_int[3], gain_int[2], gain_int[1], gain_int[0]};

//-----------------------------------------------------------------------------
// Aggregate Outputs
//-----------------------------------------------------------------------------
assign sie_per_harmonic = sie_active_int;
assign coherence_mask = high_coherence_int;

// SIE active if ANY harmonic achieves high coherence + beta quiet
assign sie_active_any = |sie_active_int;

//-----------------------------------------------------------------------------
// Primary f₀ Outputs (backwards compatibility with v7.2)
//-----------------------------------------------------------------------------
assign f0_x = f_x_int[0];
assign f0_y = f_y_int[0];
assign f0_amplitude = f_amp_int[0];
assign f0_coherence = coh_abs_int[0];

endmodule
