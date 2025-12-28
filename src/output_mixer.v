//=============================================================================
// Output Mixer - v7.1
// Per-band amplitude envelope modulation for EEG-realistic spectral dynamics
//
// v7.1 CHANGES (Soft Limiting):
// - Added soft limiter before DAC to prevent hard clipping
// - Piecewise linear: linear below ±0.75, 2:1 compression above
// - Maps full dynamic range to DAC range without harsh saturation
//
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

    output reg signed [WIDTH-1:0] mixed_output,
    output wire [11:0] dac_output
);

// v7.3: Minimal oscillator weights for EEG-realistic 1/f-dominated spectrum
// Target: 1/f slope dominates, oscillator peaks barely visible (~1-2 dB above floor)
// Real EEG: oscillators are subtle modulations on 1/f background
// Total oscillators: ~8%, pink noise: ~92%
localparam signed [WIDTH-1:0] W_THETA      = 18'sd328;   // 0.02 - theta (was 0.04)
localparam signed [WIDTH-1:0] W_ALPHA      = 18'sd492;   // 0.03 - alpha peak (was 0.06)
localparam signed [WIDTH-1:0] W_BETA       = 18'sd328;   // 0.02 - low beta (was 0.04)
localparam signed [WIDTH-1:0] W_GAMMA      = 18'sd164;   // 0.01 - gamma (was 0.025)
localparam signed [WIDTH-1:0] W_PINK_NOISE = 18'sd15073; // 0.92 - 1/f background dominates (was 0.835)

// Default envelope value (1.0 = no modulation)
localparam signed [WIDTH-1:0] ENVELOPE_UNITY = 18'sd16384;

// v7.1: Soft limiter thresholds (Q14)
// Linear region: |x| < SOFT_THRESH (0.75)
// Compression region: |x| >= SOFT_THRESH, 2:1 compression toward SOFT_LIMIT (1.0)
localparam signed [WIDTH-1:0] SOFT_THRESH = 18'sd12288;   // 0.75 in Q14
localparam signed [WIDTH-1:0] SOFT_LIMIT  = 18'sd16384;   // 1.0 in Q14 (max output)

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
// Weighted mixing (using envelope-modulated signals)
//-----------------------------------------------------------------------------
wire signed [2*WIDTH-1:0] term_theta, term_alpha, term_beta, term_gamma, term_noise;
wire signed [2*WIDTH-1:0] sum_full;
wire signed [WIDTH-1:0] sum_scaled;

assign term_theta = mod_theta * W_THETA;
assign term_alpha = mod_alpha * W_ALPHA;
assign term_beta  = mod_beta  * W_BETA;
assign term_gamma = mod_gamma * W_GAMMA;
assign term_noise = pink_noise * W_PINK_NOISE;  // Pink noise NOT modulated

// Sum all weighted terms
assign sum_full = term_theta + term_alpha + term_beta + term_gamma + term_noise;
assign sum_scaled = sum_full >>> FRAC;

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
