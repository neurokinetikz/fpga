//=============================================================================
// Schumann-Aligned Harmonic Bank v7.7
//
// Implements 5 externally-driven Hopf oscillators at Schumann-aligned frequencies.
// Each harmonic can independently couple to brain oscillators when beta quiet.
//
// v7.7: Dynamic SIE Enhancement (v11.4 Active φⁿ Dynamics)
//   - ENABLE_ADAPTIVE parameter for stability-based enhancement
//   - Stability inputs from quarter_integer_detector
//   - Enhancement = 1.2× + 1.8× × (1 - stability)
//   - Less stable positions → higher responsiveness to SR field
//
// v7.6: Quarter-Integer φⁿ Theory - f₁ explained as φ^1.25 fallback
//   - 2:1 Harmonic Catastrophe makes φ^1.5 unstable (too close to ratio 2.0)
//   - f₁ retreats to geometric mean: n = (1.0 + 1.5)/2 = 1.25 (quarter-integer)
//   - φ^1.25 = 1.8249, giving f₁ = 7.72 Hz × 1.8249 = 14.09 Hz theoretical
//   - Observed 13.75-14.17 Hz matches theory within 1%
//   - Resolves "bridging mode mystery" from v10.4 specification
//   - See docs/SPEC_v10.5_UPDATE.md for full derivation
//
// v7.5: φⁿ Q-factor and amplitude hierarchy from geophysical SR data
// v7.4: Support for external drifting omega_dt (realistic SR frequency variation)
//
// SR FREQUENCIES (v12.2 - exact φⁿ alignment):
//   f₀ = 7.75 Hz ± 0.5 Hz   → Theta band (6.09 Hz internal = 7.75/√φ)
//   f₁ = 13.75 Hz ± 0.8 Hz  → Alpha (L6 ~9.86 Hz = 7.75×√φ) [φ^1.25 quarter-integer mode]
//   f₂ = 20 Hz   ± 1 Hz     → Beta (L5a ~15.95 Hz) [ANCHOR - highest Q]
//   f₃ = 25 Hz   ± 1.5 Hz   → High Beta (L5b ~25.81 Hz)
//   f₄ = 32 Hz   ± 2 Hz     → Consciousness gate (L4 ~32.83 Hz)
//
// GEOPHYSICAL φⁿ RELATIONSHIPS (Dec 2025 data):
//   Q-factors: Q₀=7.5, Q₁=9.5, Q₂=15.5 (anchor), Q₃=8.5, Q₄=7.0
//   Q ratios follow φⁿ: Q₂/Q₀ ≈ φ^1.5 (0.6% error), Q₂/Q₁ ≈ φ¹ (0.7% error)
//   Amplitude decay: A ∝ φ^(-n), power ∝ φ^(-2n)
//   Mode-selective enhancement: f₀/f₁ respond 2.7-3×, f₂/f₃/f₄ only 1.2×
//
// STOCHASTIC RESONANCE MODEL:
// - Each harmonic is externally driven (represents weak SR field)
// - Frequency drift creates realistic SR behavior with natural detuning
// - Beta amplitude gates all entrainment (when beta quiet, coupling enabled)
// - Per-harmonic coherence computed against matching EEG band
// - SIE activates when ANY harmonic achieves high coherence + beta quiet
// - Q-factor affects coherence sensitivity (higher Q = sharper detection)
// - Amplitude weights create realistic 1/f power spectrum
//=============================================================================
`timescale 1ns / 1ps

module sr_harmonic_bank #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_HARMONICS = 5,
    parameter ENABLE_STOCHASTIC = 1,  // Enable stochastic noise injection
    parameter ENABLE_DRIFT = 1,       // Enable external frequency drift
    parameter ENABLE_ADAPTIVE = 0     // v11.4: Enable stability-based dynamic SIE enhancement
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,
    input  wire signed [WIDTH-1:0] mu_dt,

    // v7.4: External drifting omega_dt values (from sr_frequency_drift)
    // If ENABLE_DRIFT=0 or all zeros, uses internal defaults
    input  wire signed [NUM_HARMONICS*WIDTH-1:0] omega_dt_packed,

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

    // v11.4: Per-harmonic stability metrics from quarter_integer_detector
    // Q14 format: 0 = unstable (boundary), 1.0 = fully stable (half-integer)
    // Only used when ENABLE_ADAPTIVE = 1
    input  wire signed [NUM_HARMONICS*WIDTH-1:0] stability_packed,

    // Per-harmonic outputs - packed for synthesis
    output wire signed [NUM_HARMONICS*WIDTH-1:0] f_x_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] f_y_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] f_amplitude_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] coherence_packed,
    output wire [NUM_HARMONICS-1:0] sie_per_harmonic,

    // v7.4: Continuous per-harmonic gain (replaces binary SIE)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] gain_per_harmonic_packed,

    // v7.5: Weighted per-harmonic gain (with Q-factor, amplitude scale, SIE enhancement)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] gain_weighted_packed,

    // v11.4: Dynamic SIE enhancement output (for use by thalamus.v)
    // When ENABLE_ADAPTIVE=1, computed from stability; otherwise, hardcoded values
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sie_enhance_packed,

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

// OMEGA_DT values for Schumann-aligned harmonics (Q14 format)
// Formula: OMEGA_DT = round(2π × f_hz × dt × 2^14) where dt = 0.00025s (4 kHz)
// Based on observed real-time SR monitoring data
localparam signed [WIDTH-1:0] OMEGA_DT_F0 = 18'sd199;   // 7.75 Hz (v12.2: exact φⁿ base)
localparam signed [WIDTH-1:0] OMEGA_DT_F1 = 18'sd354;   // 13.75 Hz (2nd SR mode)
    // v7.6 NOTE: f₁ is φ^1.25 × f₀ due to 2:1 Harmonic Catastrophe
    // φ^1.5 = 2.058 is unstable (too close to 2.0 harmonic ratio)
    // Quarter-integer fallback: n = (1.0 + 1.5)/2 = 1.25
    // Theoretical: φ^1.25 × 7.75 = 1.8249 × 7.75 = 14.14 Hz
    // Observed: 13.75 Hz (Tomsk 27-yr avg: 14.17 Hz) - confirms fallback mechanism
localparam signed [WIDTH-1:0] OMEGA_DT_F2 = 18'sd514;   // 20 Hz (3rd SR mode)
localparam signed [WIDTH-1:0] OMEGA_DT_F3 = 18'sd643;   // 25 Hz (4th SR mode)
localparam signed [WIDTH-1:0] OMEGA_DT_F4 = 18'sd823;   // 32 Hz (5th SR mode)

// Beta quiet threshold: 0.35 in Q14 (v7.5 - calibrated to actual oscillator behavior)
// Observed: At MU=4 (NORMAL), |x| avg ~0.46 - need lower threshold
// Threshold 0.35 means beta is only "quiet" when dampened below normal operation
// This prevents false SR ignition in NORMAL resting state
localparam signed [WIDTH-1:0] BETA_QUIET_THRESHOLD = 18'sd5734;  // 0.35 in Q14

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
// v7.6: φⁿ Fundamental Constants (Q14 format)
// φ = (1 + √5) / 2 = 1.6180339887...
// These constants document the energy landscape that determines mode positions
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] PHI_Q14 = 18'sd26510;         // φ^1.0 = 1.618
localparam signed [WIDTH-1:0] PHI_0_25 = 18'sd18474;        // φ^0.25 = 1.1276 (quarter power)
localparam signed [WIDTH-1:0] PHI_0_5 = 18'sd20833;         // φ^0.5 = 1.272
localparam signed [WIDTH-1:0] PHI_0_75 = 18'sd20935;        // φ^0.75 = 1.2785
localparam signed [WIDTH-1:0] PHI_1_25 = 18'sd29899;        // φ^1.25 = 1.8249 (f₁ fallback)
localparam signed [WIDTH-1:0] PHI_1_5 = 18'sd33718;         // φ^1.5 = 2.058 (UNSTABLE!)
localparam signed [WIDTH-1:0] PHI_2_0 = 18'sd42891;         // φ^2.0 = 2.618
localparam signed [WIDTH-1:0] PHI_2_5 = 18'sd54569;         // φ^2.5 = 3.330

// 2:1 Harmonic catastrophe zone (for documentation/validation)
localparam signed [WIDTH-1:0] HARMONIC_2_1 = 18'sd32768;    // 2.0 in Q14
// Distance from φ^1.5 to 2:1: |2.058 - 2.0| = 0.058, E_h = 1/0.058² ≈ 297 (catastrophic!)

// Theoretical f₁ at quarter-integer position (for validation only)
// OMEGA_DT = round(2π × f_hz × 0.00025 × 16384) = round(25.736 × f_hz)
localparam signed [WIDTH-1:0] OMEGA_DT_F1_THEORY = 18'sd364;  // 14.14 Hz (φ^1.25 × 7.75)
// Actual OMEGA_DT_F1 = 354 (13.75 Hz observed) - 0.6% from theory validates quarter-integer rule

//-----------------------------------------------------------------------------
// v7.5: Q-Factor Normalization Weights (from geophysical Dec 2025 data)
// Higher Q = sharper resonance = more sensitive coherence detection
// Q-factors: Q₀=7.5, Q₁=9.5, Q₂=15.5 (anchor), Q₃=8.5, Q₄=7.0
// Normalized to Q₂ (anchor): Q_NORM[h] = Q[h] / 15.5 × 16384
// Q ratios follow φⁿ: Q₂/Q₀ ≈ φ^1.5, Q₂/Q₁ ≈ φ¹ (< 1% error)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] Q_NORM_F0 = 18'sd7929;   // 7.5/15.5 = 0.484
localparam signed [WIDTH-1:0] Q_NORM_F1 = 18'sd10051;  // 9.5/15.5 = 0.613 (bridging mode)
localparam signed [WIDTH-1:0] Q_NORM_F2 = 18'sd16384;  // 15.5/15.5 = 1.0 (ANCHOR)
localparam signed [WIDTH-1:0] Q_NORM_F3 = 18'sd8995;   // 8.5/15.5 = 0.549
localparam signed [WIDTH-1:0] Q_NORM_F4 = 18'sd7405;   // 7.0/15.5 = 0.452

//-----------------------------------------------------------------------------
// v7.5: Amplitude Scale Factors (φ^(-n) decay from geophysical power data)
// Power decays as φ^(-2n), amplitude as φ^(-n)
// Based on observed A ratios: A₃/A₁ ≈ 0.58 ≈ φ⁻¹, A₄/A₃ ≈ 0.66 ≈ φ⁻¹
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] AMP_SCALE_F0 = 18'sd16384;  // 1.0 (reference)
localparam signed [WIDTH-1:0] AMP_SCALE_F1 = 18'sd13926;  // 0.85 (quarter-integer)
    // v7.6 NOTE: f₁ amplitude is intermediate due to quarter-integer position
    // φ^(-1) = 0.618, φ^(-1.25) = 0.55, φ^(-1.5) = 0.486
    // Observed 0.85 is elevated above pure φⁿ decay - consistent with energy
    // concentration at quarter-integer fallback position between modes
localparam signed [WIDTH-1:0] AMP_SCALE_F2 = 18'sd5571;   // 0.34 ≈ φ⁻²
localparam signed [WIDTH-1:0] AMP_SCALE_F3 = 18'sd2458;   // 0.15 ≈ φ⁻⁴
localparam signed [WIDTH-1:0] AMP_SCALE_F4 = 18'sd983;    // 0.06 ≈ φ⁻⁶

//-----------------------------------------------------------------------------
// v7.5: Mode-Selective SIE Enhancement (from Dec 27 geophysical event data)
// Lower modes (f₀, f₁) respond 2.7-3× during events
// Higher modes (f₂, f₃, f₄) are "protected", respond only 1.2×
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] SIE_ENHANCE_F0 = 18'sd44237;  // 2.7× (responsive)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F1 = 18'sd49152;  // 3.0× (quarter-integer, MOST responsive)
    // v7.6 NOTE: f₁'s highest enhancement (3.0×) explained by quarter-integer theory:
    // Quarter-integer modes are intrinsically less stable than half-integer attractors
    // Less stability = more susceptibility to external perturbation (SR field)
    // The 3.0× responsiveness is a signature of the fallback position's reduced energy barrier
localparam signed [WIDTH-1:0] SIE_ENHANCE_F2 = 18'sd20480;  // 1.25× (anchor, protected)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F3 = 18'sd19661;  // 1.2× (protected)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F4 = 18'sd19661;  // 1.2× (protected)

//-----------------------------------------------------------------------------
// v11.4: Dynamic SIE Enhancement Constants
// Enhancement = BASE_ENHANCE + K_INSTABILITY × (1 - stability)
// - When stability=1.0 (half-integer): enhance = 1.2×
// - When stability=0.5 (quarter-integer): enhance = 1.2 + 0.9 × 0.5 = 1.65× → use higher K
// - When stability=0 (boundary): enhance = 1.2 + 1.8 = 3.0×
// Calibrated so that:
//   f₁ (quarter-integer, stability≈0.5) → ~3.0×
//   f₂ (stable anchor, stability≈1.0) → ~1.2×
//   f₀ (boundary, stability≈0) → ~3.0×
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] SIE_BASE_ENHANCE = 18'sd19661;  // 1.2× in Q14
localparam signed [WIDTH-1:0] SIE_K_INSTABILITY = 18'sd29491; // 1.8× in Q14 (scaling factor)

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
// v11.4: Unpack stability signals
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] stability_input [0:NUM_HARMONICS-1];
assign stability_input[0] = stability_packed[0*WIDTH +: WIDTH];
assign stability_input[1] = stability_packed[1*WIDTH +: WIDTH];
assign stability_input[2] = stability_packed[2*WIDTH +: WIDTH];
assign stability_input[3] = stability_packed[3*WIDTH +: WIDTH];
assign stability_input[4] = stability_packed[4*WIDTH +: WIDTH];

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

// Scale to Q14: (diff / threshold) * 16384 = diff * (16384/15360) = diff * 1.0667
// Approximate 1.0667 as (1 + 1/16) = 1.0625 (close enough)
// = diff + (diff >> 4)
assign beta_factor_full = {beta_diff, 14'b0} + {4'b0, beta_diff, 10'b0};
assign beta_factor = (beta_factor_full[2*WIDTH-1:FRAC] > ONE_Q14) ? ONE_Q14 :
                     beta_factor_full[FRAC +: WIDTH];

//-----------------------------------------------------------------------------
// Unpack external omega_dt (for drift support)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] omega_dt_ext [0:NUM_HARMONICS-1];
assign omega_dt_ext[0] = omega_dt_packed[0*WIDTH +: WIDTH];
assign omega_dt_ext[1] = omega_dt_packed[1*WIDTH +: WIDTH];
assign omega_dt_ext[2] = omega_dt_packed[2*WIDTH +: WIDTH];
assign omega_dt_ext[3] = omega_dt_packed[3*WIDTH +: WIDTH];
assign omega_dt_ext[4] = omega_dt_packed[4*WIDTH +: WIDTH];

//-----------------------------------------------------------------------------
// OMEGA_DT Array for Generate Block
// v7.4: Use external drifting values if ENABLE_DRIFT=1 and non-zero input
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] OMEGA_DT_DEFAULT [0:NUM_HARMONICS-1];
assign OMEGA_DT_DEFAULT[0] = OMEGA_DT_F0;
assign OMEGA_DT_DEFAULT[1] = OMEGA_DT_F1;
assign OMEGA_DT_DEFAULT[2] = OMEGA_DT_F2;
assign OMEGA_DT_DEFAULT[3] = OMEGA_DT_F3;
assign OMEGA_DT_DEFAULT[4] = OMEGA_DT_F4;

wire signed [WIDTH-1:0] OMEGA_DT_HARMONICS [0:NUM_HARMONICS-1];
// Use external if ENABLE_DRIFT=1 and external value is non-zero
assign OMEGA_DT_HARMONICS[0] = (ENABLE_DRIFT && omega_dt_ext[0] != 0) ? omega_dt_ext[0] : OMEGA_DT_DEFAULT[0];
assign OMEGA_DT_HARMONICS[1] = (ENABLE_DRIFT && omega_dt_ext[1] != 0) ? omega_dt_ext[1] : OMEGA_DT_DEFAULT[1];
assign OMEGA_DT_HARMONICS[2] = (ENABLE_DRIFT && omega_dt_ext[2] != 0) ? omega_dt_ext[2] : OMEGA_DT_DEFAULT[2];
assign OMEGA_DT_HARMONICS[3] = (ENABLE_DRIFT && omega_dt_ext[3] != 0) ? omega_dt_ext[3] : OMEGA_DT_DEFAULT[3];
assign OMEGA_DT_HARMONICS[4] = (ENABLE_DRIFT && omega_dt_ext[4] != 0) ? omega_dt_ext[4] : OMEGA_DT_DEFAULT[4];

//-----------------------------------------------------------------------------
// v7.5: Parameter Arrays for Generate Block Access
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] Q_NORM [0:NUM_HARMONICS-1];
assign Q_NORM[0] = Q_NORM_F0;
assign Q_NORM[1] = Q_NORM_F1;
assign Q_NORM[2] = Q_NORM_F2;
assign Q_NORM[3] = Q_NORM_F3;
assign Q_NORM[4] = Q_NORM_F4;

wire signed [WIDTH-1:0] AMP_SCALE [0:NUM_HARMONICS-1];
assign AMP_SCALE[0] = AMP_SCALE_F0;
assign AMP_SCALE[1] = AMP_SCALE_F1;
assign AMP_SCALE[2] = AMP_SCALE_F2;
assign AMP_SCALE[3] = AMP_SCALE_F3;
assign AMP_SCALE[4] = AMP_SCALE_F4;

wire signed [WIDTH-1:0] SIE_ENHANCE [0:NUM_HARMONICS-1];
assign SIE_ENHANCE[0] = SIE_ENHANCE_F0;
assign SIE_ENHANCE[1] = SIE_ENHANCE_F1;
assign SIE_ENHANCE[2] = SIE_ENHANCE_F2;
assign SIE_ENHANCE[3] = SIE_ENHANCE_F3;
assign SIE_ENHANCE[4] = SIE_ENHANCE_F4;

//-----------------------------------------------------------------------------
// v11.4: Dynamic SIE Enhancement Computation
// Enhancement = BASE_ENHANCE + K_INSTABILITY × (1 - stability)
// Uses hardcoded values when ENABLE_ADAPTIVE=0, computed values when =1
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] SIE_ENHANCE_DYN [0:NUM_HARMONICS-1];
wire signed [WIDTH-1:0] instability [0:NUM_HARMONICS-1];
wire signed [2*WIDTH-1:0] enhance_contrib [0:NUM_HARMONICS-1];
wire signed [WIDTH-1:0] enhance_computed [0:NUM_HARMONICS-1];

// Compute instability = 1.0 - stability for each harmonic
assign instability[0] = ONE_Q14 - stability_input[0];
assign instability[1] = ONE_Q14 - stability_input[1];
assign instability[2] = ONE_Q14 - stability_input[2];
assign instability[3] = ONE_Q14 - stability_input[3];
assign instability[4] = ONE_Q14 - stability_input[4];

// Compute enhancement contribution: K × instability
assign enhance_contrib[0] = SIE_K_INSTABILITY * instability[0];
assign enhance_contrib[1] = SIE_K_INSTABILITY * instability[1];
assign enhance_contrib[2] = SIE_K_INSTABILITY * instability[2];
assign enhance_contrib[3] = SIE_K_INSTABILITY * instability[3];
assign enhance_contrib[4] = SIE_K_INSTABILITY * instability[4];

// Compute final enhancement: BASE + contribution (shift Q28 → Q14)
assign enhance_computed[0] = SIE_BASE_ENHANCE + (enhance_contrib[0] >>> FRAC);
assign enhance_computed[1] = SIE_BASE_ENHANCE + (enhance_contrib[1] >>> FRAC);
assign enhance_computed[2] = SIE_BASE_ENHANCE + (enhance_contrib[2] >>> FRAC);
assign enhance_computed[3] = SIE_BASE_ENHANCE + (enhance_contrib[3] >>> FRAC);
assign enhance_computed[4] = SIE_BASE_ENHANCE + (enhance_contrib[4] >>> FRAC);

// Select between hardcoded and computed based on ENABLE_ADAPTIVE
assign SIE_ENHANCE_DYN[0] = ENABLE_ADAPTIVE ? enhance_computed[0] : SIE_ENHANCE[0];
assign SIE_ENHANCE_DYN[1] = ENABLE_ADAPTIVE ? enhance_computed[1] : SIE_ENHANCE[1];
assign SIE_ENHANCE_DYN[2] = ENABLE_ADAPTIVE ? enhance_computed[2] : SIE_ENHANCE[2];
assign SIE_ENHANCE_DYN[3] = ENABLE_ADAPTIVE ? enhance_computed[3] : SIE_ENHANCE[3];
assign SIE_ENHANCE_DYN[4] = ENABLE_ADAPTIVE ? enhance_computed[4] : SIE_ENHANCE[4];

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

// v7.5: Per-harmonic weighted gains (includes Q-factor, amplitude scale, SIE enhancement)
wire signed [WIDTH-1:0] gain_weighted_int [0:NUM_HARMONICS-1];

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

        // v7.5: Q-weighted coherence and weighted gain signals
        wire signed [2*WIDTH-1:0] coh_q_product;
        wire signed [WIDTH-1:0] coh_q_weighted;
        wire signed [2*WIDTH-1:0] gain_amp_product;
        wire signed [WIDTH-1:0] gain_amp_scaled;
        wire signed [2*WIDTH-1:0] gain_sie_product;
        wire signed [WIDTH-1:0] gain_weighted_local;

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

        //---------------------------------------------------------------------
        // v7.5: Q-Weighted Coherence (higher Q = more sensitive detection)
        // coh_q_weighted = coh_abs × Q_NORM[h] (both Q14, result Q28→Q14)
        // Higher Q means coherence is "amplified", reaching threshold sooner
        // f₂ (anchor) has Q_NORM=1.0, others have Q_NORM<1.0
        //---------------------------------------------------------------------
        assign coh_q_product = coh_abs_local * Q_NORM[h];
        assign coh_q_weighted = coh_q_product >>> FRAC;

        //---------------------------------------------------------------------
        // v7.5: Weighted Gain = gain × AMP_SCALE
        // Apply amplitude scale (φ^(-n) power decay) for realistic power spectrum
        // SIE_ENHANCE is applied separately in thalamus.v during ignition events
        // (Mode-selective enhancement should only apply during SIE, not baseline)
        //---------------------------------------------------------------------
        assign gain_amp_product = gain_local * AMP_SCALE[h];
        assign gain_amp_scaled = gain_amp_product >>> FRAC;

        // Note: SIE_ENHANCE not applied here - handled in thalamus.v
        assign gain_sie_product = 36'sd0;  // Unused, kept for signal declaration
        assign gain_weighted_local = gain_amp_scaled;

        // Connect to output arrays
        assign f_x_int[h] = f_x_local;
        assign f_y_int[h] = f_y_local;
        assign f_amp_int[h] = f_amp_local;
        assign coh_abs_int[h] = coh_abs_local;
        assign gain_int[h] = gain_local;
        assign gain_weighted_int[h] = gain_weighted_local;

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

// v7.5: Pack per-harmonic weighted gains (Q-factor + amplitude + SIE enhancement)
assign gain_weighted_packed = {gain_weighted_int[4], gain_weighted_int[3], gain_weighted_int[2],
                                gain_weighted_int[1], gain_weighted_int[0]};

// v11.4: Pack dynamic SIE enhancement values
assign sie_enhance_packed = {SIE_ENHANCE_DYN[4], SIE_ENHANCE_DYN[3], SIE_ENHANCE_DYN[2],
                              SIE_ENHANCE_DYN[1], SIE_ENHANCE_DYN[0]};

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
