//=============================================================================
// phi^n Alignment Detector - v1.1
//
// NEW MODULE for v12.2: Dual Alignment Ignition
//
// Computes alignment metrics between internal boundary sqrt(theta*alpha) and
// the external Schumann Resonance fundamental (SR1). When theta and alpha
// drift into alignment such that their geometric mean matches SR1, ignition
// sensitivity is enhanced.
//
// CORE INSIGHT:
// Evolution tuned brain oscillators so that sqrt(theta * alpha) = SR1.
// When this alignment occurs naturally through stochastic drift, the
// brain becomes more sensitive to SR ignition events.
//
// OUTPUTS:
// - internal_boundary: sqrt(theta * alpha) in OMEGA_DT units
// - detuning: |internal_boundary - SR1| in OMEGA_DT units
// - alignment_factor: [0,1] Q14 Gaussian response peaking at alignment
// - crystallinity: [0,1] Q14 how close alpha/theta is to phi
// - ignition_sensitivity: alignment_factor * crystallinity
//
// MATHEMATICAL BASIS:
// theta = SR1 / sqrt(phi) = 7.75 / 1.272 = 6.09 Hz (OMEGA_DT = 157)
// alpha = SR1 * sqrt(phi) = 7.75 * 1.272 = 9.86 Hz (OMEGA_DT = 254)
// boundary = sqrt(157 * 254) = sqrt(39878) = 199.7 ~= 199 (7.75 Hz) = SR1
//=============================================================================
`timescale 1ns / 1ps

module phi_n_alignment_detector #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Actual drifting frequencies (OMEGA_DT values with drift+jitter)
    input  wire signed [WIDTH-1:0] omega_theta_actual,  // ~157 +/- drift
    input  wire signed [WIDTH-1:0] omega_alpha_actual,  // ~254 +/- drift
    input  wire signed [WIDTH-1:0] omega_sr_f0_actual,  // ~199 +/- drift

    // Outputs
    output reg signed [WIDTH-1:0] internal_boundary,    // sqrt(theta*alpha) OMEGA_DT
    output reg signed [WIDTH-1:0] detuning,             // |boundary - SR1| OMEGA_DT
    output reg signed [WIDTH-1:0] alignment_factor,     // [0,1] Q14 peaks when aligned
    output reg signed [WIDTH-1:0] crystallinity,        // [0,1] Q14 alpha/theta closeness to phi
    output reg signed [WIDTH-1:0] ignition_sensitivity  // alignment * crystallinity Q14
);

//-----------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] ONE = 18'sd16384;        // 1.0 in Q14
localparam signed [WIDTH-1:0] PHI_Q14 = 18'sd26510;    // phi = 1.618 in Q14

// Gaussian width for alignment factor
// v1.1: Widened from σ=5 to σ=8 for longer alignment windows
// sigma = 8 OMEGA_DT units (~0.3 Hz)
// sigma^2 = 64
localparam signed [WIDTH-1:0] SIGMA_SQ = 18'sd64;

// For Gaussian approximation: 1 - x^2/sigma^2
// Scale factor = ONE / SIGMA_SQ = 16384 / 64 = 256
localparam signed [WIDTH-1:0] GAUSSIAN_SCALE = 18'sd256;

//-----------------------------------------------------------------------------
// Pipeline Stage 1: Compute product theta * alpha
//-----------------------------------------------------------------------------
reg signed [2*WIDTH-1:0] product_full;
reg signed [WIDTH-1:0] product;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        product_full <= 36'sd0;
        product <= 18'sd0;
    end else if (clk_en) begin
        // Clamp negative values to 0 (frequencies should be positive)
        if (omega_theta_actual > 0 && omega_alpha_actual > 0) begin
            product_full <= omega_theta_actual * omega_alpha_actual;
            // Product is ~40000 for nominal values, fits in 18 bits
            product <= (omega_theta_actual * omega_alpha_actual > 18'sd131071) ?
                       18'sd131071 : omega_theta_actual * omega_alpha_actual;
        end else begin
            product_full <= 36'sd0;
            product <= 18'sd0;
        end
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 2: Integer Square Root (Newton-Raphson, 3 iterations)
//
// For product ~40000, sqrt ~200
// Initial guess: product >> 8 gives ~156 (reasonable starting point)
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] sqrt_result;
reg signed [WIDTH-1:0] sqrt_guess;
reg signed [2*WIDTH-1:0] sqrt_div;

// Combinatorial sqrt approximation (single cycle with lookup + refinement)
// For our range (product ~30000-50000), we use linear interpolation
// sqrt(30000) = 173, sqrt(50000) = 224
// Approximation: sqrt(x) ~= 100 + x/400 for x in [30000, 50000]
// More accurate: use bit manipulation for initial guess

wire signed [WIDTH-1:0] sqrt_approx;
wire signed [2*WIDTH-1:0] product_pos;
assign product_pos = (product > 0) ? product : 18'sd0;

// Initial guess: use leading bit position / 2
// For 16-bit range, sqrt is 8-bit range
// Simple approximation: (product >> 7) + 64 gives reasonable start
wire signed [WIDTH-1:0] guess0 = (product >>> 7) + 18'sd64;

// One Newton-Raphson iteration: x_new = (x + n/x) / 2
wire signed [WIDTH-1:0] div0 = (guess0 > 0) ? (product / guess0) : 18'sd0;
wire signed [WIDTH-1:0] guess1 = (guess0 + div0) >>> 1;

// Second iteration for better accuracy
wire signed [WIDTH-1:0] div1 = (guess1 > 0) ? (product / guess1) : 18'sd0;
wire signed [WIDTH-1:0] guess2 = (guess1 + div1) >>> 1;

assign sqrt_approx = guess2;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sqrt_result <= 18'sd0;
    end else if (clk_en) begin
        sqrt_result <= sqrt_approx;
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 3: Compute detuning and alignment factor
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] detuning_raw;
reg signed [WIDTH-1:0] detuning_sq;
reg signed [WIDTH-1:0] alignment_raw;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        internal_boundary <= 18'sd0;
        detuning_raw <= 18'sd0;
        detuning <= 18'sd0;
    end else if (clk_en) begin
        // Internal boundary is the sqrt result
        internal_boundary <= sqrt_result;

        // Detuning = |boundary - SR1|
        if (sqrt_result > omega_sr_f0_actual) begin
            detuning_raw <= sqrt_result - omega_sr_f0_actual;
        end else begin
            detuning_raw <= omega_sr_f0_actual - sqrt_result;
        end
        detuning <= detuning_raw;
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 4: Gaussian alignment factor
// alignment = max(0, 1 - detuning^2 / sigma^2)
// = max(0, ONE - detuning^2 * GAUSSIAN_SCALE)
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        detuning_sq <= 18'sd0;
        alignment_raw <= 18'sd0;
        alignment_factor <= 18'sd0;
    end else if (clk_en) begin
        // Compute detuning squared (small values, won't overflow)
        detuning_sq <= detuning_raw * detuning_raw;

        // Gaussian approximation
        // If detuning > 8 (sigma), alignment ~= 0
        if (detuning_raw > 18'sd8) begin
            alignment_raw <= 18'sd0;
        end else begin
            // alignment = ONE - detuning_sq * GAUSSIAN_SCALE
            // Need to handle overflow
            alignment_raw <= ONE - ((detuning_sq * GAUSSIAN_SCALE) >>> 0);
        end

        // Clamp to [0, ONE]
        if (alignment_raw < 0) begin
            alignment_factor <= 18'sd0;
        end else if (alignment_raw > ONE) begin
            alignment_factor <= ONE;
        end else begin
            alignment_factor <= alignment_raw;
        end
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 5: Crystallinity (how close is alpha/theta to phi)
//
// ratio = alpha / theta
// crystallinity = 1 - |ratio - phi| / phi
//
// To avoid division, we compute:
//   ratio_q14 = (alpha << FRAC) / theta  (Q14 result)
//   deviation = |ratio_q14 - PHI_Q14|
//   crystallinity = ONE - (deviation << FRAC) / PHI_Q14
//
// Simplified: use multiplicative comparison
//   expected_alpha = theta * phi (in Q14 arithmetic)
//   error = |actual_alpha * ONE - expected_alpha|
//   crystallinity = 1 - error / expected_alpha
//-----------------------------------------------------------------------------
reg signed [2*WIDTH-1:0] expected_alpha_full;
reg signed [WIDTH-1:0] expected_alpha;
reg signed [WIDTH-1:0] alpha_scaled;
reg signed [WIDTH-1:0] ratio_error;
reg signed [WIDTH-1:0] crystallinity_raw;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        expected_alpha_full <= 36'sd0;
        expected_alpha <= 18'sd0;
        alpha_scaled <= 18'sd0;
        ratio_error <= 18'sd0;
        crystallinity_raw <= 18'sd0;
        crystallinity <= 18'sd0;
    end else if (clk_en) begin
        // expected_alpha = theta * phi (in Q14, so result needs >> FRAC)
        // But theta is OMEGA_DT (~157), not Q14
        // We want: expected_alpha_omega = theta * 1.618
        // = (theta * PHI_Q14) >> FRAC
        expected_alpha_full <= omega_theta_actual * PHI_Q14;
        expected_alpha <= expected_alpha_full >>> FRAC;

        // Scale actual alpha for comparison (already OMEGA_DT)
        alpha_scaled <= omega_alpha_actual;

        // Error = |alpha - expected_alpha| as fraction of expected
        if (alpha_scaled > expected_alpha) begin
            ratio_error <= alpha_scaled - expected_alpha;
        end else begin
            ratio_error <= expected_alpha - alpha_scaled;
        end

        // Normalize error: error_fraction = (error << FRAC) / expected_alpha
        // crystallinity = ONE - error_fraction
        // Simplified: crystallinity ~= ONE - (ratio_error * ONE / expected_alpha)
        if (expected_alpha > 0) begin
            // Scale error relative to expected
            // error / expected ~= error * ONE / expected (Q14 result)
            crystallinity_raw <= ONE - ((ratio_error <<< FRAC) / expected_alpha);
        end else begin
            crystallinity_raw <= 18'sd0;
        end

        // Clamp to [0, ONE]
        if (crystallinity_raw < 0) begin
            crystallinity <= 18'sd0;
        end else if (crystallinity_raw > ONE) begin
            crystallinity <= ONE;
        end else begin
            crystallinity <= crystallinity_raw;
        end
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 6: Combined ignition sensitivity
// sensitivity = alignment_factor * crystallinity (Q14 * Q14 -> Q14)
//-----------------------------------------------------------------------------
reg signed [2*WIDTH-1:0] sensitivity_full;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sensitivity_full <= 36'sd0;
        ignition_sensitivity <= 18'sd0;
    end else if (clk_en) begin
        sensitivity_full <= alignment_factor * crystallinity;
        ignition_sensitivity <= sensitivity_full >>> FRAC;
    end
end

endmodule
