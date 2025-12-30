//=============================================================================
// f₂ Boundary Detector - v1.1
//
// NEW MODULE for Three-Boundary Architecture
//
// Computes alignment metrics between f₂ boundary √(β_low×β_high) and
// the external Schumann Resonance harmonic SR3. This boundary serves as
// the "Stability Anchor" - SR3 is the most stable SR harmonic (~10s updates).
//
// CORE INSIGHT:
// The geometric mean of low and high beta oscillators aligns with SR3:
//   f₂ = √(β_low × β_high) ≈ SR3 (20 Hz)
//
// When this alignment occurs through stochastic drift, it provides a
// stable reference frame that anchors the other boundaries.
//
// MATHEMATICAL BASIS (7.75 Hz base):
//   β_low  = SR1 × φ^1.5 = 7.75 × 2.058 = 15.95 Hz (OMEGA_DT = 410)
//   β_high = SR1 × φ^2.5 = 7.75 × 3.330 = 25.81 Hz (OMEGA_DT = 664)
//   f₂ = √(410 × 664) = √272,240 ≈ 522 (20.3 Hz)
//   SR3 = 20 Hz (OMEGA_DT = 514)
//   Nominal detuning: |522 - 514| = 8 OMEGA_DT (~0.3 Hz)
//
// OUTPUTS:
// - f2_boundary: √(β_low × β_high) in OMEGA_DT units
// - f2_detuning: |f2_boundary - SR3| in OMEGA_DT units
// - f2_alignment: [0,1] Q14 Gaussian response peaking at alignment
// - f2_stability_score: alignment factor (stability anchor role)
//=============================================================================
`timescale 1ns / 1ps

module boundary_detector_f2 #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Actual drifting frequencies (OMEGA_DT values with drift+jitter)
    input  wire signed [WIDTH-1:0] omega_beta_low_actual,   // ~410 +/- drift (L5a)
    input  wire signed [WIDTH-1:0] omega_beta_high_actual,  // ~664 +/- drift (L5b)
    input  wire signed [WIDTH-1:0] omega_sr3_actual,        // ~514 +/- drift

    // Outputs
    output reg signed [WIDTH-1:0] f2_boundary,        // sqrt(β_low×β_high) OMEGA_DT
    output reg signed [WIDTH-1:0] f2_detuning,        // |boundary - SR3| OMEGA_DT
    output reg signed [WIDTH-1:0] f2_alignment,       // [0,1] Q14 peaks when aligned
    output reg signed [WIDTH-1:0] f2_stability_score  // [0,1] Q14 stability contribution
);

//-----------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] ONE = 18'sd16384;        // 1.0 in Q14

// Gaussian width for alignment factor
// v1.1: Widened from σ=5 to σ=8 for longer alignment windows (matching f₀)
// sigma = 8 OMEGA_DT units (~0.3 Hz)
// sigma^2 = 64
localparam signed [WIDTH-1:0] SIGMA_SQ = 18'sd64;

// For Gaussian approximation: 1 - x^2/sigma^2
// Scale factor = ONE / SIGMA_SQ = 16384 / 64 = 256
localparam signed [WIDTH-1:0] GAUSSIAN_SCALE = 18'sd256;

//-----------------------------------------------------------------------------
// Pipeline Stage 1: Compute product β_low × β_high
//-----------------------------------------------------------------------------
reg signed [2*WIDTH-1:0] product_full;
reg signed [WIDTH-1:0] product;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        product_full <= 36'sd0;
        product <= 18'sd0;
    end else if (clk_en) begin
        // Clamp negative values to 0 (frequencies should be positive)
        if (omega_beta_low_actual > 0 && omega_beta_high_actual > 0) begin
            product_full <= omega_beta_low_actual * omega_beta_high_actual;
            // Product is ~272000 for nominal values, needs 19 bits, clamp to 18-bit max
            product <= (omega_beta_low_actual * omega_beta_high_actual > 18'sd131071) ?
                       18'sd131071 : omega_beta_low_actual * omega_beta_high_actual;
        end else begin
            product_full <= 36'sd0;
            product <= 18'sd0;
        end
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 2: Integer Square Root (Newton-Raphson, 2 iterations)
//
// For product ~272000, sqrt ~522
// Initial guess: product >> 9 gives ~531 (reasonable starting point)
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] sqrt_result;

// Use full product for sqrt to handle larger values
wire signed [2*WIDTH-1:0] product_pos;
assign product_pos = (product_full > 0) ? product_full : 36'sd0;

// Initial guess: use leading bit position / 2
// For 18-bit range, sqrt is 9-bit range
// Better approximation for larger values: (product >> 9) gives ~530 for 272000
wire signed [WIDTH-1:0] guess0 = (product_full >>> 9) + 18'sd64;

// One Newton-Raphson iteration: x_new = (x + n/x) / 2
// Need to use product_full for division to get accuracy
wire signed [WIDTH-1:0] div0 = (guess0 > 0) ? (product_full / {{18{guess0[17]}}, guess0}) : 18'sd0;
wire signed [WIDTH-1:0] guess1 = (guess0 + div0) >>> 1;

// Second iteration for better accuracy
wire signed [WIDTH-1:0] div1 = (guess1 > 0) ? (product_full / {{18{guess1[17]}}, guess1}) : 18'sd0;
wire signed [WIDTH-1:0] guess2 = (guess1 + div1) >>> 1;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sqrt_result <= 18'sd0;
    end else if (clk_en) begin
        sqrt_result <= guess2;
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
        f2_boundary <= 18'sd0;
        detuning_raw <= 18'sd0;
        f2_detuning <= 18'sd0;
    end else if (clk_en) begin
        // f2 boundary is the sqrt result
        f2_boundary <= sqrt_result;

        // Detuning = |boundary - SR3|
        if (sqrt_result > omega_sr3_actual) begin
            detuning_raw <= sqrt_result - omega_sr3_actual;
        end else begin
            detuning_raw <= omega_sr3_actual - sqrt_result;
        end
        f2_detuning <= detuning_raw;
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
        f2_alignment <= 18'sd0;
    end else if (clk_en) begin
        // Compute detuning squared (values up to ~64 for nominal gap)
        detuning_sq <= detuning_raw * detuning_raw;

        // Gaussian approximation
        // If detuning > 8 (sigma), alignment ~= 0
        if (detuning_raw > 18'sd8) begin
            alignment_raw <= 18'sd0;
        end else begin
            // alignment = ONE - detuning_sq * GAUSSIAN_SCALE
            alignment_raw <= ONE - ((detuning_sq * GAUSSIAN_SCALE) >>> 0);
        end

        // Clamp to [0, ONE]
        if (alignment_raw < 0) begin
            f2_alignment <= 18'sd0;
        end else if (alignment_raw > ONE) begin
            f2_alignment <= ONE;
        end else begin
            f2_alignment <= alignment_raw;
        end
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 5: Stability Score
// For f₂, stability score equals alignment (no additional crystallinity)
// This simplification reflects that f₂ primarily serves as stability anchor
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        f2_stability_score <= 18'sd0;
    end else if (clk_en) begin
        f2_stability_score <= f2_alignment;
    end
end

endmodule
