//=============================================================================
// Output Mixer - v7.20
// Per-band amplitude envelope modulation for EEG-realistic spectral dynamics
//
// v7.20 CHANGES (Continuous Gain Interpolation):
// - Added pac_gain/harmonic_gain inputs from coupling_mode_controller v1.2b
// - Added use_continuous_gains flag for MEDITATION state transitions
// - When enabled: mode_blend = normalize(harmonic_gain) for smooth interpolation
// - Pink weight and osc_scale lerp with mode_blend, synchronized with MU
// - Eliminates transient artifacts (alpha dip at N→M, spike at M→N)
// - Added debug outputs: debug_mode_blend, debug_pink_weight, debug_osc_scale
//
// v7.19 CHANGES (Even Darker Baseline - Round 2):
// - OSC_SCALE_MODULATORY reduced from 0.5× to 0.25× (-6 dB, -12 dB total from v7.17)
// - OSC_SCALE_HARMONIC reduced from 1.3× to 0.35× (-11 dB) for quieter MEDITATION
// - W_PINK_MODULATORY increased from 0.96 to 0.98 (more 1/f masking)
// - Goal: Match real EEG dark purple baseline with SIE bursts emerging from silence
//
// v7.18 CHANGES (Darker Baseline for SIE Contrast):
// - OSC_SCALE_MODULATORY reduced from 1.0× to 0.5× (-6 dB oscillator power)
// - W_PINK_MODULATORY increased from 0.93 to 0.96 (more 1/f masking)
// - Goal: Quiet baseline for SIE transients to emerge from "silence"
// - Matches real EEG: dark purple baseline, yellow SIE bursts
//
// v7.17 CHANGES (Distributed SIE Boost Reduction - Option C):
// - sie_boost reduced from [1.0, 2.0] to [1.0, 1.4] (+2.9 dB contribution)
// - Part of distributed 6.8 dB target: mixer(2.9) + f₀(2.3) + f₁(1.6) = 6.8 dB
// - Matches empirical SIE power increase of 4-5× (6-7 dB)
//
// v7.16 CHANGES (Further Compressed Dynamic Range):
// - MEDITATION: 85% pink, 1.3× osc (+5% pink for ~2-3 dB range compression)
// - Combined with sr_ignition_controller v1.3 (GAIN_COHERENCE=0.40)
// - Target: ~20-25 dB dynamic range matching typical EEG
//
// v7.15 CHANGES (Compressed Dynamic Range):
// - MEDITATION: 80% pink, 1.3× osc (was 75% pink, 1.5× osc in v7.14)
// - Dynamic range compressed from ~40 dB to ~25-30 dB
//
// v7.14 CHANGES (Smooth State Transitions):
// - Added transition_progress and state_select inputs
// - Mixing weights now interpolate smoothly during state transitions
// - Shadow registers capture start values for lerp interpolation
// - Eliminates abrupt spectral jumps when entering/exiting MEDITATION
//
// v7.13 CHANGES (Stronger SIE Visibility):
// - v7.12: Correlation improved to +0.167 with [1.0, 1.5] boost
// - v7.13: Increased boost range to [1.0, 2.0] for stronger visibility
// - Boost factor: 1.0 + (1.0 × sr_gain_envelope) → range [1.0, 2.0]
// - Target: envelope correlation > 0.3 for clearly visible SIE events
// - This creates POSITIVE correlation between gain_envelope and DAC output
//
// v7.10 CHANGES (Reduce Theta Dominance):
// - Reduced W_THETA_BASE from 123 to 82 (0.0075 → 0.005)
// - θ/α ratio was +5 dB, typical awake EEG is -3 to +3 dB (alpha often ≥ theta)
// - W_ALPHA:W_THETA ratio now 2:1 (was 1.33:1), targeting ~3 dB θ/α reduction
//
// v7.9 CHANGES (Further Reduced Oscillator Prominence):
// - Halved base oscillator weights again (~5.5% → ~2.75% total contribution)
// - Increased W_PINK_MODULATORY from 0.90 to 0.93
// - Bands still slightly too discrete after v7.8, further reduction needed
//
// v7.8 CHANGES (Reduced Oscillator Prominence):
// - Halved base oscillator weights (~11% → ~5.5% total contribution)
// - Increased W_PINK_MODULATORY from 0.85 to 0.90
// - Eliminates prominent horizontal bands at oscillator frequencies
// - Real EEG should have diffuse power distribution, not sharp spectral lines
//
// v7.7 CHANGES (Coupling Mode Dynamic Mix):
// - Added coupling_mode input from coupling_mode_controller
// - Mix ratios controlled by mode (not sr_gain_envelope):
//   - MODULATORY: 85% pink / 15% osc (baseline, subtle peaks)
//   - TRANSITION: 67% pink / 33% osc (gradual shift)
//   - HARMONIC:   50% pink / 50% osc (SIE visible as spectral reorganization)
// - This makes SIE events visible as structural spectral changes
//
// v7.6 CHANGES (SR Ignition Modulation):
// - sr_gain_envelope RE-CONNECTED in v7.13 via post-mix amplitude boost
//
// v7.5 CHANGES (Balanced Mixing):
// - Reduced oscillator weights for subtle ~3-5 dB peaks on 1/f background
// - Pink noise at 85% (was 50% in v7.4, 92% in v7.1)
// - Oscillators at 12% total (was 32% in v7.4, 8% in v7.1)
// - State differentiation via MU scaling, not mixer dominance
//
// v7.1: Added soft limiter before DAC to prevent hard clipping
// v7.0: Added envelope inputs for "alpha breathing" effect (2-5s timescales)
// v6.0: Added theta + L6 alpha inputs, reweighted for ~10 Hz alpha peak
//=============================================================================
`timescale 1ns / 1ps

module output_mixer #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // 5-channel input for realistic EEG spectrum
    input  wire signed [WIDTH-1:0] theta_x,       // 5.89 Hz - thalamic theta
    input  wire signed [WIDTH-1:0] motor_l6_x,    // 9.53 Hz - alpha (L6)
    input  wire signed [WIDTH-1:0] motor_l5a_x,   // 15.42 Hz - low beta
    input  wire signed [WIDTH-1:0] motor_l23_x,   // 40.36 Hz - gamma
    input  wire signed [WIDTH-1:0] pink_noise,    // 1/f broadband

    // v7.0: Per-band amplitude envelopes (Q14 format, 0.5-1.5 range, mean 1.0)
    input  wire signed [WIDTH-1:0] env_theta,     // Theta band envelope
    input  wire signed [WIDTH-1:0] env_alpha,     // Alpha band envelope
    input  wire signed [WIDTH-1:0] env_beta,      // Beta band envelope
    input  wire signed [WIDTH-1:0] env_gamma,     // Gamma band envelope

    // v7.6: SR ignition gain envelope (kept for backward compatibility, ignored in v7.7)
    input  wire signed [WIDTH-1:0] sr_gain_envelope,

    // v7.7: Coupling mode for dynamic mix ratios
    input  wire [1:0] coupling_mode,  // 00=MODULATORY, 01=TRANSITION, 10=HARMONIC

    // v7.14: Smooth state transitions
    input  wire [15:0] transition_progress,  // From config_controller (0-65535)
    input  wire [2:0]  state_select,         // Current/target consciousness state

    // v7.20: Continuous gain inputs from coupling_mode_controller v1.2b
    input  wire signed [WIDTH-1:0] pac_gain,      // Q14: 0.125 (HARMONIC) to 1.0 (MODULATORY)
    input  wire signed [WIDTH-1:0] harmonic_gain, // Q14: 1.0 (HARMONIC) to 0.125 (MODULATORY)
    input  wire use_continuous_gains,             // Enable continuous blending during transitions

    output reg signed [WIDTH-1:0] mixed_output,
    output wire [11:0] dac_output,

    // v7.20: Debug outputs for gain interpolation verification
    output wire signed [WIDTH-1:0] debug_mode_blend,
    output wire signed [WIDTH-1:0] debug_pink_weight,
    output wire signed [WIDTH-1:0] debug_osc_scale
);

//-----------------------------------------------------------------------------
// v7.7: Coupling Mode Definitions
//-----------------------------------------------------------------------------
localparam [1:0] MODE_MODULATORY = 2'b00;  // Baseline PAC-based coupling
localparam [1:0] MODE_TRANSITION = 2'b01;  // Gradual crossfade (~500ms)
localparam [1:0] MODE_HARMONIC   = 2'b10;  // Ignition-phase harmonic locking

//-----------------------------------------------------------------------------
// v7.16: Mode-Specific Weights (Q14) - now with smooth interpolation
// MODULATORY: 98% pink, 0.25× osc - diffuse 1/f spectrum (NORMAL, FLOW, PSYCHEDELIC) - v7.19 very dark baseline
// TRANSITION: 67% pink, 2.2× osc - gradual shift toward prominence
// HARMONIC:   85% pink, 0.35× osc - MEDITATION (v7.19: reduced from 1.3× for darker baseline)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] W_PINK_MODULATORY = 18'sd16056;  // 0.98 (v7.19: was 0.96)
localparam signed [WIDTH-1:0] W_PINK_TRANSITION = 18'sd10978;  // 0.67
localparam signed [WIDTH-1:0] W_PINK_HARMONIC   = 18'sd13926;  // 0.85 (v7.16: was 0.80, +5% higher floor)

// Oscillator scale factors: how much to multiply baseline oscillator weights
// MODULATORY: 0.25× (v7.19: was 0.5×, -12 dB total from v7.17)
// TRANSITION: 2.2× boost (33/15 = 2.2)
// HARMONIC:   0.35× (v7.19: was 1.3×, -11 dB for darker MEDITATION)
localparam signed [WIDTH-1:0] OSC_SCALE_MODULATORY = 18'sd4096;   // 0.25× (v7.19: was 0.5×, -12 dB total)
localparam signed [WIDTH-1:0] OSC_SCALE_TRANSITION = 18'sd36045;  // 2.2×
localparam signed [WIDTH-1:0] OSC_SCALE_HARMONIC   = 18'sd5734;   // 0.35× (v7.19: was 1.3×, darker MEDITATION)

// v7.10: Baseline oscillator weights - theta reduced for better θ/α balance
// v7.5 values: theta=0.03, alpha=0.04, beta=0.025, gamma=0.015 (~11% total)
// v7.8 values: theta=0.015, alpha=0.02, beta=0.0125, gamma=0.0075 (~5.5% total)
// v7.9 values: theta=0.0075, alpha=0.01, beta=0.00625, gamma=0.00375 (~2.75% total)
// v7.10: theta=0.005 (W_ALPHA:W_THETA = 2:1) to reduce θ/α from +5dB toward 0dB
// These get scaled by the mode-dependent OSC_SCALE factor
localparam signed [WIDTH-1:0] W_THETA_BASE = 18'sd82;    // 0.005 (was 0.0075) - reduced for θ/α balance
localparam signed [WIDTH-1:0] W_ALPHA_BASE = 18'sd164;   // 0.01   (unchanged)
localparam signed [WIDTH-1:0] W_BETA_BASE  = 18'sd102;   // 0.00625 (unchanged)
localparam signed [WIDTH-1:0] W_GAMMA_BASE = 18'sd61;    // 0.00375 (unchanged)

// Default envelope value (1.0 = no modulation)
localparam signed [WIDTH-1:0] ENVELOPE_UNITY = 18'sd16384;

// v7.1: Soft limiter thresholds (Q14)
localparam signed [WIDTH-1:0] SOFT_THRESH = 18'sd12288;   // 0.75 in Q14
localparam signed [WIDTH-1:0] SOFT_LIMIT  = 18'sd16384;   // 1.0 in Q14 (max output)

//-----------------------------------------------------------------------------
// v7.20: Continuous Gain Interpolation (from coupling_mode_controller v1.2b)
// When use_continuous_gains=1, mode_blend is derived from harmonic_gain
// mode_blend = 0.0 → MODULATORY weights, mode_blend = 1.0 → HARMONIC weights
// This synchronizes mixing weight changes with MU amplitude interpolation
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] GAIN_LOW = 18'sd2048;     // 0.125 (harmonic_gain at MODULATORY)
localparam signed [WIDTH-1:0] GAIN_RANGE = 18'sd14336;  // 0.875 (1.0 - 0.125)
localparam signed [WIDTH-1:0] ONE_Q14 = 18'sd16384;     // 1.0

// Normalize harmonic_gain to [0, 1] range for blending
// mode_blend = (harmonic_gain - GAIN_LOW) / GAIN_RANGE
wire signed [WIDTH-1:0] gain_shifted = harmonic_gain - GAIN_LOW;
wire signed [2*WIDTH-1:0] blend_full = (gain_shifted <<< FRAC) / GAIN_RANGE;
wire signed [WIDTH-1:0] mode_blend_raw = blend_full[WIDTH-1:0];

// Clamp to [0, 1] range
wire signed [WIDTH-1:0] mode_blend_clamped =
    (mode_blend_raw < 0) ? 18'sd0 :
    (mode_blend_raw > ONE_Q14) ? ONE_Q14 : mode_blend_raw;

// Interpolate pink_weight: MODULATORY + blend × (HARMONIC - MODULATORY)
// pink_delta = 0.85 - 0.98 = -0.13 (pink decreases in HARMONIC)
wire signed [2*WIDTH-1:0] pink_delta_cont = W_PINK_HARMONIC - W_PINK_MODULATORY;
wire signed [2*WIDTH-1:0] pink_interp_cont = (pink_delta_cont * mode_blend_clamped) >>> FRAC;
wire signed [WIDTH-1:0] pink_weight_continuous = W_PINK_MODULATORY + pink_interp_cont[WIDTH-1:0];

// Interpolate osc_scale: MODULATORY + blend × (HARMONIC - MODULATORY)
// osc_delta = 0.35 - 0.25 = 0.10 (osc increases in HARMONIC)
wire signed [2*WIDTH-1:0] osc_delta_cont = OSC_SCALE_HARMONIC - OSC_SCALE_MODULATORY;
wire signed [2*WIDTH-1:0] osc_interp_cont = (osc_delta_cont * mode_blend_clamped) >>> FRAC;
wire signed [WIDTH-1:0] osc_scale_continuous = OSC_SCALE_MODULATORY + osc_interp_cont[WIDTH-1:0];

// v7.20: Effective weights with continuous/discrete mux
// When use_continuous_gains=1: use continuous interpolation from harmonic_gain
// When use_continuous_gains=0: use discrete state-based interpolation (v7.14 behavior)
wire signed [WIDTH-1:0] W_PINK_FINAL;
wire signed [WIDTH-1:0] OSC_SCALE_FINAL;

// Debug outputs
assign debug_mode_blend = mode_blend_clamped;
assign debug_pink_weight = W_PINK_FINAL;
assign debug_osc_scale = OSC_SCALE_FINAL;

//-----------------------------------------------------------------------------
// v7.14: State-Based Weight Selection with Smooth Interpolation
// Uses transition_progress from config_controller for lerp between states
//-----------------------------------------------------------------------------

// Consciousness state codes (must match config_controller.v)
localparam [2:0] STATE_MEDITATION = 3'd4;

// State-based target selection (combinational)
// MEDITATION uses HARMONIC weights, all others use MODULATORY
reg signed [WIDTH-1:0] W_PINK_TARGET;
reg signed [WIDTH-1:0] OSC_SCALE_TARGET;

always @(*) begin
    case (state_select)
        STATE_MEDITATION: begin
            W_PINK_TARGET = W_PINK_HARMONIC;        // 0.75 pink
            OSC_SCALE_TARGET = OSC_SCALE_HARMONIC;  // 1.5× osc
        end
        default: begin
            W_PINK_TARGET = W_PINK_MODULATORY;      // 0.93 pink
            OSC_SCALE_TARGET = OSC_SCALE_MODULATORY; // 1.0× osc
        end
    endcase
end

// Shadow registers for interpolation start values
reg signed [WIDTH-1:0] w_pink_start;
reg signed [WIDTH-1:0] osc_scale_start;
reg [2:0] prev_state;

// Interpolation using transition_progress (0-65535)
// Formula: start + (target - start) * progress / 65535
wire signed [35:0] pink_delta;
wire signed [35:0] osc_delta;
wire signed [35:0] pink_interp;
wire signed [35:0] osc_interp;
wire signed [WIDTH-1:0] W_PINK_EFF;
wire signed [WIDTH-1:0] OSC_SCALE;

assign pink_delta = W_PINK_TARGET - w_pink_start;
assign osc_delta = OSC_SCALE_TARGET - osc_scale_start;

// Linear interpolation: start + delta * progress / 65536
// Using >>> 16 is equivalent to / 65536 (close enough to 65535)
assign pink_interp = (pink_delta * $signed({1'b0, transition_progress})) >>> 16;
assign osc_interp = (osc_delta * $signed({1'b0, transition_progress})) >>> 16;

assign W_PINK_EFF = w_pink_start + pink_interp[WIDTH-1:0];
assign OSC_SCALE = osc_scale_start + osc_interp[WIDTH-1:0];

// v7.20: Final weight selection mux
// use_continuous_gains=1: use harmonic_gain-based interpolation (synchronized with MU)
// use_continuous_gains=0: use discrete state-based interpolation (v7.14 behavior)
assign W_PINK_FINAL = use_continuous_gains ? pink_weight_continuous : W_PINK_EFF;
assign OSC_SCALE_FINAL = use_continuous_gains ? osc_scale_continuous : OSC_SCALE;

// Update shadow registers on state change
always @(posedge clk or posedge rst) begin
    if (rst) begin
        w_pink_start <= W_PINK_MODULATORY;
        osc_scale_start <= OSC_SCALE_MODULATORY;
        prev_state <= 3'd0;
    end else if (clk_en) begin
        if (state_select != prev_state) begin
            // Capture current interpolated values as new start point
            w_pink_start <= W_PINK_EFF;
            osc_scale_start <= OSC_SCALE;
            prev_state <= state_select;
        end
    end
end

//-----------------------------------------------------------------------------
// v7.0: Envelope Modulation
// Each oscillator signal is multiplied by its envelope before weighting
// Envelope range [0.5, 1.5] creates natural amplitude "breathing"
//-----------------------------------------------------------------------------
wire signed [2*WIDTH-1:0] mod_theta_full, mod_alpha_full, mod_beta_full, mod_gamma_full;
wire signed [WIDTH-1:0] mod_theta, mod_alpha, mod_beta, mod_gamma;

// Use envelope if valid (non-zero), otherwise use unity (no modulation)
wire signed [WIDTH-1:0] env_theta_eff  = (env_theta  != 0) ? env_theta  : ENVELOPE_UNITY;
wire signed [WIDTH-1:0] env_alpha_eff  = (env_alpha  != 0) ? env_alpha  : ENVELOPE_UNITY;
wire signed [WIDTH-1:0] env_beta_eff   = (env_beta   != 0) ? env_beta   : ENVELOPE_UNITY;
wire signed [WIDTH-1:0] env_gamma_eff  = (env_gamma  != 0) ? env_gamma  : ENVELOPE_UNITY;

// Envelope modulation: signal * envelope / 16384
assign mod_theta_full = theta_x     * env_theta_eff;
assign mod_alpha_full = motor_l6_x  * env_alpha_eff;
assign mod_beta_full  = motor_l5a_x * env_beta_eff;
assign mod_gamma_full = motor_l23_x * env_gamma_eff;

// Scale back to Q14 (divide by 16384)
assign mod_theta = mod_theta_full >>> FRAC;
assign mod_alpha = mod_alpha_full >>> FRAC;
assign mod_beta  = mod_beta_full  >>> FRAC;
assign mod_gamma = mod_gamma_full >>> FRAC;

//-----------------------------------------------------------------------------
// v7.7: Scaled Oscillator Weights
// Apply mode-dependent scaling to each oscillator
//-----------------------------------------------------------------------------
wire signed [2*WIDTH-1:0] scaled_w_theta_full, scaled_w_alpha_full;
wire signed [2*WIDTH-1:0] scaled_w_beta_full, scaled_w_gamma_full;
wire signed [WIDTH-1:0] W_THETA, W_ALPHA, W_BETA, W_GAMMA;

assign scaled_w_theta_full = W_THETA_BASE * OSC_SCALE_FINAL;  // v7.20: use FINAL for mux
assign scaled_w_alpha_full = W_ALPHA_BASE * OSC_SCALE_FINAL;
assign scaled_w_beta_full  = W_BETA_BASE  * OSC_SCALE_FINAL;
assign scaled_w_gamma_full = W_GAMMA_BASE * OSC_SCALE_FINAL;

assign W_THETA = scaled_w_theta_full >>> FRAC;
assign W_ALPHA = scaled_w_alpha_full >>> FRAC;
assign W_BETA  = scaled_w_beta_full  >>> FRAC;
assign W_GAMMA = scaled_w_gamma_full >>> FRAC;

//-----------------------------------------------------------------------------
// v7.17: SIE Post-Mix Amplitude Boost (distributed reduction)
// Reduced from [1.0, 2.0] to [1.0, 1.4] as part of Option C distributed boost.
// Boost factor: 1.0 + (0.4 × sr_gain_envelope / 16384)
// When envelope=0: 1.0× (no boost)
// When envelope=16384: 1.4× (+2.9 dB during SIE)
// Combined with thalamus f₀(1.3×) and f₁(1.2×) for ~6.8 dB total
//-----------------------------------------------------------------------------
wire signed [2*WIDTH-1:0] sie_env_scaled;
wire signed [WIDTH-1:0] sie_boost;
assign sie_env_scaled = sr_gain_envelope * 18'sd6554;  // 0.4 × envelope (Q28)
assign sie_boost = 18'sd16384 + (sie_env_scaled >>> FRAC);  // Range: [1.0, 1.4]

//-----------------------------------------------------------------------------
// Weighted mixing (using envelope-modulated signals and mode-scaled weights)
//-----------------------------------------------------------------------------
wire signed [2*WIDTH-1:0] term_theta, term_alpha, term_beta, term_gamma, term_noise;
wire signed [2*WIDTH-1:0] sum_full;
wire signed [WIDTH-1:0] sum_raw;
wire signed [2*WIDTH-1:0] sum_boosted_full;
wire signed [WIDTH-1:0] sum_scaled;

assign term_theta = mod_theta * W_THETA;
assign term_alpha = mod_alpha * W_ALPHA;
assign term_beta  = mod_beta  * W_BETA;
assign term_gamma = mod_gamma * W_GAMMA;
assign term_noise = pink_noise * W_PINK_FINAL;  // v7.20: Use FINAL for mux (continuous/discrete)

// Sum all weighted terms
assign sum_full = term_theta + term_alpha + term_beta + term_gamma + term_noise;
assign sum_raw = sum_full >>> FRAC;

// v7.12: Apply SIE boost to create positive correlation with DAC amplitude
assign sum_boosted_full = sum_raw * sie_boost;
assign sum_scaled = sum_boosted_full >>> FRAC;

//-----------------------------------------------------------------------------
// v7.1: Soft Limiter
// Piecewise linear compression to prevent hard clipping
// Below ±0.75: linear (unchanged)
// Above ±0.75: 2:1 compression toward ±1.0
// Formula: output = sign(x) * (THRESH + (|x| - THRESH) / 2)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] abs_input;
wire input_negative;
wire above_thresh;
wire signed [WIDTH-1:0] excess;
wire signed [WIDTH-1:0] compressed_excess;
wire signed [WIDTH-1:0] soft_limited;

assign input_negative = sum_scaled[WIDTH-1];  // Sign bit
assign abs_input = input_negative ? -sum_scaled : sum_scaled;
assign above_thresh = (abs_input > SOFT_THRESH);
assign excess = abs_input - SOFT_THRESH;
assign compressed_excess = excess >>> 1;  // Divide by 2 (2:1 compression)

// Soft limited absolute value
wire signed [WIDTH-1:0] abs_limited = above_thresh ?
    (SOFT_THRESH + compressed_excess) : abs_input;

// Restore sign
assign soft_limited = input_negative ? -abs_limited : abs_limited;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mixed_output <= 18'sd0;
    end else if (clk_en) begin
        mixed_output <= soft_limited;
    end
end

// 12-bit DAC output with offset to unsigned range
wire signed [WIDTH-1:0] shifted;
wire [15:0] dac_raw;

assign shifted = mixed_output + 18'sd16384;  // Shift to positive
assign dac_raw = shifted[17:3];
assign dac_output = (dac_raw > 16'd4095) ? 12'd4095 : dac_raw[11:0];

endmodule
