//=============================================================================
// SR4 Direct Coupling Detector - v1.1
//
// NEW MODULE for Three-Boundary Architecture
//
// Computes coupling strength between β_high cortical oscillator and
// the external Schumann Resonance harmonic SR4. This is NOT a boundary
// (no sqrt) but a direct frequency match, serving as "Arousal Modulation."
//
// CORE INSIGHT:
// SR4 is the MOST VARIABLE SR harmonic (~1s updates, step 1-3).
// β_high (L5b) drifts 3× faster to seek alignment.
// This fast-changing coupling modulates arousal/alertness state.
//
// MATHEMATICAL BASIS (7.75 Hz base):
//   β_high = SR1 × φ^2.5 = 7.75 × 3.330 = 25.81 Hz (OMEGA_DT = 664)
//   SR4 = 25 Hz (OMEGA_DT = 643)
//   Nominal detuning: |664 - 643| = 21 OMEGA_DT (~0.8 Hz)
//
// DESIGN CHOICES:
// - Direct frequency comparison (simpler than boundary detectors)
// - σ = 8 OMEGA_DT for coupling Gaussian
// - Fast dynamics reflect arousal state changes
//
// OUTPUTS:
// - sr4_detuning: |β_high - SR4| in OMEGA_DT units
// - sr4_coupling_strength: [0,1] Q14 Gaussian coupling metric
//=============================================================================
`timescale 1ns / 1ps

module direct_coupling_sr4 #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Actual drifting frequencies (OMEGA_DT values with drift+jitter)
    input  wire signed [WIDTH-1:0] omega_beta_high_actual,  // ~664 +/- drift (L5b)
    input  wire signed [WIDTH-1:0] omega_sr4_actual,        // ~643 +/- drift

    // Outputs
    output reg signed [WIDTH-1:0] sr4_detuning,            // |β_high - SR4| OMEGA_DT
    output reg signed [WIDTH-1:0] sr4_coupling_strength    // [0,1] Q14 coupling metric
);

//-----------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] ONE = 18'sd16384;        // 1.0 in Q14

// Gaussian width for coupling strength
// v1.1: Widened from σ=8 to σ=12 to improve coupling with nominal ~21 OMEGA_DT gap
// sigma = 12 OMEGA_DT units (~0.5 Hz)
// sigma^2 = 144
localparam signed [WIDTH-1:0] SIGMA_SQ = 18'sd144;

// For Gaussian approximation: 1 - x^2/sigma^2
// Scale factor = ONE / SIGMA_SQ = 16384 / 144 = 114
localparam signed [WIDTH-1:0] GAUSSIAN_SCALE = 18'sd114;

//-----------------------------------------------------------------------------
// Pipeline Stage 1: Compute detuning (direct comparison, no sqrt)
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] detuning_raw;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        detuning_raw <= 18'sd0;
        sr4_detuning <= 18'sd0;
    end else if (clk_en) begin
        // Detuning = |β_high - SR4|
        if (omega_beta_high_actual > omega_sr4_actual) begin
            detuning_raw <= omega_beta_high_actual - omega_sr4_actual;
        end else begin
            detuning_raw <= omega_sr4_actual - omega_beta_high_actual;
        end
        sr4_detuning <= detuning_raw;
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 2: Gaussian coupling strength
// coupling = max(0, 1 - detuning^2 / sigma^2)
// = max(0, ONE - detuning^2 * GAUSSIAN_SCALE)
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] detuning_sq;
reg signed [WIDTH-1:0] coupling_raw;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        detuning_sq <= 18'sd0;
        coupling_raw <= 18'sd0;
        sr4_coupling_strength <= 18'sd0;
    end else if (clk_en) begin
        // Compute detuning squared (values typically ~400 for nominal gap)
        detuning_sq <= detuning_raw * detuning_raw;

        // Gaussian approximation
        // If detuning > 12 (sigma), coupling ~= 0
        if (detuning_raw > 18'sd12) begin
            coupling_raw <= 18'sd0;
        end else begin
            // coupling = ONE - detuning_sq * GAUSSIAN_SCALE
            coupling_raw <= ONE - ((detuning_sq * GAUSSIAN_SCALE) >>> 0);
        end

        // Clamp to [0, ONE]
        if (coupling_raw < 0) begin
            sr4_coupling_strength <= 18'sd0;
        end else if (coupling_raw > ONE) begin
            sr4_coupling_strength <= ONE;
        end else begin
            sr4_coupling_strength <= coupling_raw;
        end
    end
end

endmodule
