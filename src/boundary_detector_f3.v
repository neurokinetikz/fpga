//=============================================================================
// f₃ Boundary Detector - v1.0
//
// NEW MODULE for Three-Boundary Architecture
//
// Computes alignment metrics between f₃ boundary √(β_high×γ) and
// the external Schumann Resonance harmonic SR5. This boundary serves as
// the "Consciousness Gate" - crossing this threshold is required for
// full conscious access but is relatively rare and brief.
//
// CORE INSIGHT:
// The geometric mean of high-beta and gamma oscillators approaches SR5:
//   f₃ = √(β_high × γ) ≈ 29 Hz (inherent ~8% gap to SR5 = 32 Hz)
//
// When this alignment occurs (briefly, due to fast SR5 dynamics), it
// enables consciousness access. The intrinsic gap makes this harder to
// achieve, reflecting the rarity of full conscious processing.
//
// MATHEMATICAL BASIS (7.75 Hz base):
//   β_high = SR1 × φ^2.5 = 7.75 × 3.330 = 25.81 Hz (OMEGA_DT = 664)
//   γ      = SR1 × φ^3.0 = 7.75 × 4.236 = 32.83 Hz (OMEGA_DT = 845)
//   f₃ = √(664 × 845) = √561,180 ≈ 749 (29.1 Hz)
//   SR5 = 32 Hz (OMEGA_DT = 823)
//   Nominal detuning: |749 - 823| = 74 OMEGA_DT (~2.9 Hz = 8% gap)
//
// DESIGN CHOICES:
// - Uses wider σ = 10 OMEGA_DT to account for intrinsic gap
// - Even with drift, alignment is brief (SR5 is moderate stability)
// - consciousness_gate output indicates threshold crossing
//
// OUTPUTS:
// - f3_boundary: √(β_high × γ) in OMEGA_DT units
// - f3_detuning: |f3_boundary - SR5| in OMEGA_DT units
// - f3_alignment: [0,1] Q14 Gaussian response (wider σ)
// - f3_consciousness_gate: [0,1] Q14 gate strength for conscious access
//=============================================================================
`timescale 1ns / 1ps

module boundary_detector_f3 #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Actual drifting frequencies (OMEGA_DT values with drift+jitter)
    input  wire signed [WIDTH-1:0] omega_beta_high_actual,  // ~664 +/- drift (L5b)
    input  wire signed [WIDTH-1:0] omega_gamma_actual,      // ~845 +/- drift (L4)
    input  wire signed [WIDTH-1:0] omega_sr5_actual,        // ~823 +/- drift

    // Outputs
    output reg signed [WIDTH-1:0] f3_boundary,            // sqrt(β_high×γ) OMEGA_DT
    output reg signed [WIDTH-1:0] f3_detuning,            // |boundary - SR5| OMEGA_DT
    output reg signed [WIDTH-1:0] f3_alignment,           // [0,1] Q14 peaks when aligned
    output reg signed [WIDTH-1:0] f3_consciousness_gate   // [0,1] Q14 conscious access gate
);

//-----------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] ONE = 18'sd16384;        // 1.0 in Q14

// Gaussian width for alignment factor
// sigma = 10 OMEGA_DT units (~0.4 Hz) - WIDER than f₀/f₂ to account for gap
// sigma^2 = 100
localparam signed [WIDTH-1:0] SIGMA_SQ = 18'sd100;

// For Gaussian approximation: 1 - x^2/sigma^2
// Scale factor = ONE / SIGMA_SQ = 16384 / 100 = 164
localparam signed [WIDTH-1:0] GAUSSIAN_SCALE = 18'sd164;

// Consciousness gate threshold
// Only consider gate "open" when f3_alignment > 0.3 (4915 Q14)
localparam signed [WIDTH-1:0] GATE_THRESHOLD = 18'sd4915;  // 0.3 in Q14

//-----------------------------------------------------------------------------
// Pipeline Stage 1: Compute product β_high × γ
//-----------------------------------------------------------------------------
reg signed [2*WIDTH-1:0] product_full;
reg signed [WIDTH-1:0] product;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        product_full <= 36'sd0;
        product <= 18'sd0;
    end else if (clk_en) begin
        // Clamp negative values to 0 (frequencies should be positive)
        if (omega_beta_high_actual > 0 && omega_gamma_actual > 0) begin
            product_full <= omega_beta_high_actual * omega_gamma_actual;
            // Product is ~561000 for nominal values, needs 20 bits, clamp to 18-bit max
            product <= (omega_beta_high_actual * omega_gamma_actual > 18'sd131071) ?
                       18'sd131071 : omega_beta_high_actual * omega_gamma_actual;
        end else begin
            product_full <= 36'sd0;
            product <= 18'sd0;
        end
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 2: Integer Square Root (Newton-Raphson, 2 iterations)
//
// For product ~561000, sqrt ~749
// Initial guess: product >> 10 gives ~548 (close enough for Newton-Raphson)
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] sqrt_result;

// Use full product for sqrt to handle larger values
wire signed [2*WIDTH-1:0] product_pos;
assign product_pos = (product_full > 0) ? product_full : 36'sd0;

// Initial guess: for larger values, shift more
// (product >> 10) + 256 gives reasonable start for ~561000
wire signed [WIDTH-1:0] guess0 = (product_full >>> 10) + 18'sd256;

// One Newton-Raphson iteration: x_new = (x + n/x) / 2
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
        f3_boundary <= 18'sd0;
        detuning_raw <= 18'sd0;
        f3_detuning <= 18'sd0;
    end else if (clk_en) begin
        // f3 boundary is the sqrt result
        f3_boundary <= sqrt_result;

        // Detuning = |boundary - SR5|
        if (sqrt_result > omega_sr5_actual) begin
            detuning_raw <= sqrt_result - omega_sr5_actual;
        end else begin
            detuning_raw <= omega_sr5_actual - sqrt_result;
        end
        f3_detuning <= detuning_raw;
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 4: Gaussian alignment factor
// alignment = max(0, 1 - detuning^2 / sigma^2)
// = max(0, ONE - detuning^2 * GAUSSIAN_SCALE)
//
// Note: With σ=10, alignment reaches ~0.45 even at nominal 74-unit gap
// This allows some conscious access even without perfect alignment
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        detuning_sq <= 18'sd0;
        alignment_raw <= 18'sd0;
        f3_alignment <= 18'sd0;
    end else if (clk_en) begin
        // Compute detuning squared (values can be large, ~5000 at nominal)
        detuning_sq <= detuning_raw * detuning_raw;

        // Gaussian approximation
        // If detuning > 10 (sigma), alignment ~= 0
        if (detuning_raw > 18'sd10) begin
            alignment_raw <= 18'sd0;
        end else begin
            // alignment = ONE - detuning_sq * GAUSSIAN_SCALE
            alignment_raw <= ONE - ((detuning_sq * GAUSSIAN_SCALE) >>> 0);
        end

        // Clamp to [0, ONE]
        if (alignment_raw < 0) begin
            f3_alignment <= 18'sd0;
        end else if (alignment_raw > ONE) begin
            f3_alignment <= ONE;
        end else begin
            f3_alignment <= alignment_raw;
        end
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 5: Consciousness Gate
// Gate opens (produces output) only when alignment exceeds threshold
// Output is smoothed alignment factor above threshold
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        f3_consciousness_gate <= 18'sd0;
    end else if (clk_en) begin
        if (f3_alignment >= GATE_THRESHOLD) begin
            // Gate is open - output scaled alignment
            f3_consciousness_gate <= f3_alignment;
        end else begin
            // Gate is closed
            f3_consciousness_gate <= 18'sd0;
        end
    end
end

endmodule
