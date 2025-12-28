//=============================================================================
// Kuramoto Order Parameter - v1.1
//
// Computes population-level synchronization metric for φⁿ oscillator network.
//
// Kuramoto Order Parameter:
//   R = |1/N × Σ exp(i×θ_k)| = sqrt(sum_cos² + sum_sin²) / N
//
// Where θ_k is the phase of oscillator k, computed from its (x,y) state as:
//   cos(θ) ≈ x / |z|, sin(θ) ≈ y / |z|
//
// Output:
//   R ∈ [0, 1.0]: 0 = fully desynchronized, 1 = perfectly synchronized
//   mean_phase: Average phase of all oscillators
//
// Used for:
//   - SIE ignition detection (R > 0.7 indicates global coherence)
//   - Coupling mode switching (modulatory vs harmonic)
//   - State characterization (MEDITATION shows higher baseline R)
//
// v1.1: Fixed pipeline timing - fully combinational math with registered outputs
// v1.0: Initial implementation with 6 core oscillators
//=============================================================================
`timescale 1ns / 1ps

module kuramoto_order_parameter #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter N_OSC = 6  // Core oscillators: theta, alpha, beta1, beta2, gamma, SR_f0
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Oscillator state inputs (x, y coordinates)
    // Each oscillator represented by its Hopf state variables
    input  wire signed [WIDTH-1:0] theta_x,
    input  wire signed [WIDTH-1:0] theta_y,
    input  wire signed [WIDTH-1:0] alpha_x,
    input  wire signed [WIDTH-1:0] alpha_y,
    input  wire signed [WIDTH-1:0] beta1_x,
    input  wire signed [WIDTH-1:0] beta1_y,
    input  wire signed [WIDTH-1:0] beta2_x,
    input  wire signed [WIDTH-1:0] beta2_y,
    input  wire signed [WIDTH-1:0] gamma_x,
    input  wire signed [WIDTH-1:0] gamma_y,
    input  wire signed [WIDTH-1:0] sr_f0_x,
    input  wire signed [WIDTH-1:0] sr_f0_y,

    // Outputs
    output reg signed [WIDTH-1:0] kuramoto_R,     // Order parameter [0, 1.0] in Q14
    output reg signed [WIDTH-1:0] mean_phase,     // Average phase [0, 2π) scaled to Q14
    output reg high_synchrony                     // Flag: R > 0.7
);

// Constants
localparam signed [WIDTH-1:0] ONE = 18'sd16384;           // 1.0 in Q14
localparam signed [WIDTH-1:0] SYNC_THRESHOLD = 18'sd11469; // 0.7 in Q14
localparam signed [WIDTH-1:0] MIN_AMP = 18'sd164;          // 0.01 in Q14 (avoid div by zero)

//-----------------------------------------------------------------------------
// Amplitude computation for normalization (combinational)
// |z| = sqrt(x² + y²), approximated as max(|x|,|y|) + 0.4×min(|x|,|y|)
// This is accurate to within ~4% and avoids sqrt
//-----------------------------------------------------------------------------
function signed [WIDTH-1:0] approx_amplitude;
    input signed [WIDTH-1:0] x;
    input signed [WIDTH-1:0] y;
    reg signed [WIDTH-1:0] abs_x, abs_y, max_val, min_val;
    reg signed [2*WIDTH-1:0] min_scaled;
    begin
        abs_x = (x[WIDTH-1]) ? -x : x;
        abs_y = (y[WIDTH-1]) ? -y : y;
        max_val = (abs_x > abs_y) ? abs_x : abs_y;
        min_val = (abs_x > abs_y) ? abs_y : abs_x;
        // 0.4 ≈ 6554/16384
        min_scaled = min_val * 18'sd6554;
        approx_amplitude = max_val + (min_scaled >>> FRAC);
    end
endfunction

//-----------------------------------------------------------------------------
// Normalized phase unit vector computation (combinational)
// Returns x/|z| in Q14 format
//-----------------------------------------------------------------------------
function signed [WIDTH-1:0] normalize;
    input signed [WIDTH-1:0] val;
    input signed [WIDTH-1:0] amp;
    reg signed [2*WIDTH-1:0] scaled;
    reg signed [WIDTH-1:0] safe_amp;
    begin
        // Ensure minimum amplitude to avoid division issues
        safe_amp = (amp < MIN_AMP) ? MIN_AMP : amp;
        // val × ONE / amp
        scaled = (val <<< FRAC);
        normalize = scaled / safe_amp;
    end
endfunction

//-----------------------------------------------------------------------------
// Integer square root approximation (Newton-Raphson, 3 iterations)
// Input: Q14 value, Output: Q14 sqrt
//-----------------------------------------------------------------------------
function signed [WIDTH-1:0] approx_sqrt;
    input signed [WIDTH-1:0] val;
    reg signed [WIDTH-1:0] x, x_new;
    reg signed [2*WIDTH-1:0] val_over_x;
    begin
        if (val <= 0) begin
            approx_sqrt = 0;
        end else begin
            // Initial guess: val/2 (reasonable for [0,1] range)
            x = (val >>> 1);
            if (x == 0) x = 18'sd1;

            // Newton iteration 1: x_new = (x + val/x) / 2
            val_over_x = (val <<< FRAC) / x;
            x_new = (x + val_over_x[WIDTH-1:0]) >>> 1;

            // Newton iteration 2
            if (x_new != 0) begin
                val_over_x = (val <<< FRAC) / x_new;
                x_new = (x_new + val_over_x[WIDTH-1:0]) >>> 1;
            end

            // Newton iteration 3 for better accuracy
            if (x_new != 0) begin
                val_over_x = (val <<< FRAC) / x_new;
                x_new = (x_new + val_over_x[WIDTH-1:0]) >>> 1;
            end

            approx_sqrt = x_new;
        end
    end
endfunction

//-----------------------------------------------------------------------------
// Combinational computation of amplitudes
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] amp_theta = approx_amplitude(theta_x, theta_y);
wire signed [WIDTH-1:0] amp_alpha = approx_amplitude(alpha_x, alpha_y);
wire signed [WIDTH-1:0] amp_beta1 = approx_amplitude(beta1_x, beta1_y);
wire signed [WIDTH-1:0] amp_beta2 = approx_amplitude(beta2_x, beta2_y);
wire signed [WIDTH-1:0] amp_gamma = approx_amplitude(gamma_x, gamma_y);
wire signed [WIDTH-1:0] amp_sr_f0 = approx_amplitude(sr_f0_x, sr_f0_y);

//-----------------------------------------------------------------------------
// Combinational normalization to unit phasors
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] norm_cos_theta = normalize(theta_x, amp_theta);
wire signed [WIDTH-1:0] norm_sin_theta = normalize(theta_y, amp_theta);
wire signed [WIDTH-1:0] norm_cos_alpha = normalize(alpha_x, amp_alpha);
wire signed [WIDTH-1:0] norm_sin_alpha = normalize(alpha_y, amp_alpha);
wire signed [WIDTH-1:0] norm_cos_beta1 = normalize(beta1_x, amp_beta1);
wire signed [WIDTH-1:0] norm_sin_beta1 = normalize(beta1_y, amp_beta1);
wire signed [WIDTH-1:0] norm_cos_beta2 = normalize(beta2_x, amp_beta2);
wire signed [WIDTH-1:0] norm_sin_beta2 = normalize(beta2_y, amp_beta2);
wire signed [WIDTH-1:0] norm_cos_gamma = normalize(gamma_x, amp_gamma);
wire signed [WIDTH-1:0] norm_sin_gamma = normalize(gamma_y, amp_gamma);
wire signed [WIDTH-1:0] norm_cos_sr_f0 = normalize(sr_f0_x, amp_sr_f0);
wire signed [WIDTH-1:0] norm_sin_sr_f0 = normalize(sr_f0_y, amp_sr_f0);

//-----------------------------------------------------------------------------
// Combinational sum of unit phasors
//-----------------------------------------------------------------------------
wire signed [WIDTH+3:0] sum_cos = norm_cos_theta + norm_cos_alpha + norm_cos_beta1 +
                                  norm_cos_beta2 + norm_cos_gamma + norm_cos_sr_f0;
wire signed [WIDTH+3:0] sum_sin = norm_sin_theta + norm_sin_alpha + norm_sin_beta1 +
                                  norm_sin_beta2 + norm_sin_gamma + norm_sin_sr_f0;

//-----------------------------------------------------------------------------
// Combinational R computation
// R = sqrt(sum_cos² + sum_sin²) / N
// Scale sums by 1/N first: sum/N = sum/6 ≈ sum × 2731/16384
//-----------------------------------------------------------------------------
wire signed [2*WIDTH-1:0] avg_cos_full = sum_cos * 18'sd2731;
wire signed [2*WIDTH-1:0] avg_sin_full = sum_sin * 18'sd2731;
wire signed [WIDTH-1:0] avg_cos = avg_cos_full >>> FRAC;
wire signed [WIDTH-1:0] avg_sin = avg_sin_full >>> FRAC;

// R² = avg_cos² + avg_sin²
wire signed [2*WIDTH-1:0] cos_sq = avg_cos * avg_cos;
wire signed [2*WIDTH-1:0] sin_sq = avg_sin * avg_sin;
wire signed [2*WIDTH-1:0] r_sq_full = cos_sq + sin_sq;
wire signed [WIDTH-1:0] r_sq = r_sq_full >>> FRAC;

// R = sqrt(R²)
wire signed [WIDTH-1:0] r_computed = approx_sqrt(r_sq);

// Synchrony flag - computed combinationally from r_computed
wire sync_flag = (r_computed > SYNC_THRESHOLD);

//-----------------------------------------------------------------------------
// Registered outputs - single cycle latency after clk_en
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        kuramoto_R <= 18'sd0;
        mean_phase <= 18'sd0;
        high_synchrony <= 1'b0;
    end else if (clk_en) begin
        kuramoto_R <= r_computed;
        mean_phase <= avg_cos;  // Simplified: x-component of mean phasor
        high_synchrony <= sync_flag;
    end
end

endmodule
