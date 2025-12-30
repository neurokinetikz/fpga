//=============================================================================
// Multi-Alignment Controller - v1.2k
//
// NEW MODULE for Three-Boundary Architecture
//
// Orchestrates the three-boundary alignment system, combining:
// - f₀ alignment (√(θ×α) → SR1): Ignition primary
// - f₂ alignment (√(β_low×β_high) → SR3): Stability anchor
// - f₃ alignment (√(β_high×γ) → SR5): Consciousness gate
// - SR4 coupling (β_high → SR4): Arousal modulation
//
// OUTPUTS:
// - ignition_threshold: Modulated threshold based on alignment state
// - overall_alignment: Weighted sum of all alignments
// - ignition_permitted: All conditions met for ignition
// - consciousness_access_possible: f₃ gate open + ignition permitted
//
// WEIGHTING RATIONALE:
//   f₀ = 0.4 (ignition primary - highest weight)
//   f₂ = 0.3 (stability anchor - second highest)
//   SR4 = 0.2 (arousal modulation)
//   f₃ = 0.1 (consciousness gate - tertiary, rare)
//
// IGNITION PERMISSION:
// - Requires f₀ alignment > 0.3
// - Requires f₂ stability > 0.2
// - Requires beta_quiet signal (from sr_ignition_controller)
//
// THRESHOLD MODULATION:
// - High alignment → lower threshold → easier ignition
// - Low alignment → higher threshold → harder ignition
// - threshold_scale = 1.5 - 0.5 × overall_alignment
//=============================================================================
`timescale 1ns / 1ps

module multi_alignment_ctrl #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Alignment inputs from boundary detectors
    input  wire signed [WIDTH-1:0] f0_alignment,        // √(θ×α) → SR1 [0,1] Q14
    input  wire signed [WIDTH-1:0] f0_ignition_sens,    // from phi_n_alignment_detector
    input  wire signed [WIDTH-1:0] f2_alignment,        // √(β_low×β_high) → SR3 [0,1] Q14
    input  wire signed [WIDTH-1:0] f2_stability,        // stability score from f₂ detector
    input  wire signed [WIDTH-1:0] f3_alignment,        // √(β_high×γ) → SR5 [0,1] Q14
    input  wire signed [WIDTH-1:0] f3_consciousness,    // consciousness gate from f₃ detector
    input  wire signed [WIDTH-1:0] sr4_coupling,        // β_high → SR4 [0,1] Q14

    // State inputs
    input  wire beta_quiet,                             // From sr_ignition_controller

    // Base threshold input (from sr_ignition_controller)
    input  wire signed [WIDTH-1:0] base_threshold,      // Nominal coherence threshold

    // Outputs
    output reg signed [WIDTH-1:0] ignition_threshold,   // Modulated threshold
    output reg signed [WIDTH-1:0] overall_alignment,    // Weighted sum [0,1] Q14
    output reg ignition_permitted,                       // All conditions met
    output reg consciousness_access_possible             // f₃ gate open + ignition ok
);

//-----------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] ONE = 18'sd16384;        // 1.0 in Q14
localparam signed [WIDTH-1:0] HALF = 18'sd8192;        // 0.5 in Q14
localparam signed [WIDTH-1:0] ONE_HALF = 18'sd24576;   // 1.5 in Q14

// Alignment weights (must sum to 1.0 = 16384)
localparam signed [WIDTH-1:0] WEIGHT_F0  = 18'sd6554;  // 0.4 (ignition primary)
localparam signed [WIDTH-1:0] WEIGHT_F2  = 18'sd4915;  // 0.3 (stability anchor)
localparam signed [WIDTH-1:0] WEIGHT_SR4 = 18'sd3277;  // 0.2 (arousal modulation)
localparam signed [WIDTH-1:0] WEIGHT_F3  = 18'sd1638;  // 0.1 (consciousness tertiary)

// Minimum alignment thresholds for ignition permission
localparam signed [WIDTH-1:0] F0_MIN_ALIGNMENT = 18'sd4915;   // 0.3 in Q14
localparam signed [WIDTH-1:0] F2_MIN_STABILITY = 18'sd3277;   // 0.2 in Q14

// Consciousness access requires ignition + f₃ gate open
localparam signed [WIDTH-1:0] F3_MIN_CONSCIOUSNESS = 18'sd4915;  // 0.3 in Q14

//-----------------------------------------------------------------------------
// Pipeline Stage 1: Compute weighted alignment products
//-----------------------------------------------------------------------------
reg signed [2*WIDTH-1:0] weighted_f0, weighted_f2, weighted_f3, weighted_sr4;
reg signed [WIDTH-1:0] scaled_f0, scaled_f2, scaled_f3, scaled_sr4;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        weighted_f0 <= 36'sd0;
        weighted_f2 <= 36'sd0;
        weighted_f3 <= 36'sd0;
        weighted_sr4 <= 36'sd0;
        scaled_f0 <= 18'sd0;
        scaled_f2 <= 18'sd0;
        scaled_f3 <= 18'sd0;
        scaled_sr4 <= 18'sd0;
    end else if (clk_en) begin
        // Compute weighted products (Q14 × Q14 → Q28, then shift)
        weighted_f0 <= f0_alignment * WEIGHT_F0;
        weighted_f2 <= f2_alignment * WEIGHT_F2;
        weighted_f3 <= f3_alignment * WEIGHT_F3;
        weighted_sr4 <= sr4_coupling * WEIGHT_SR4;

        // Scale back to Q14
        scaled_f0 <= weighted_f0 >>> FRAC;
        scaled_f2 <= weighted_f2 >>> FRAC;
        scaled_f3 <= weighted_f3 >>> FRAC;
        scaled_sr4 <= weighted_sr4 >>> FRAC;
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 2: Sum weighted alignments
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] sum_alignment;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sum_alignment <= 18'sd0;
        overall_alignment <= 18'sd0;
    end else if (clk_en) begin
        // Sum all weighted components
        sum_alignment <= scaled_f0 + scaled_f2 + scaled_f3 + scaled_sr4;

        // Clamp to [0, ONE]
        if (sum_alignment < 0) begin
            overall_alignment <= 18'sd0;
        end else if (sum_alignment > ONE) begin
            overall_alignment <= ONE;
        end else begin
            overall_alignment <= sum_alignment;
        end
    end
end

//-----------------------------------------------------------------------------
// Pipeline Stage 3: Compute threshold modulation
// threshold_scale = 1.5 - 0.5 × overall_alignment
//   - alignment = 0 → scale = 1.5 → harder ignition
//   - alignment = 1 → scale = 1.0 → nominal ignition
//   - This creates alignment-dependent ignition sensitivity
//-----------------------------------------------------------------------------
reg signed [2*WIDTH-1:0] alignment_product;
reg signed [WIDTH-1:0] threshold_scale;
reg signed [2*WIDTH-1:0] threshold_product;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        alignment_product <= 36'sd0;
        threshold_scale <= ONE_HALF;
        threshold_product <= 36'sd0;
        ignition_threshold <= 18'sd0;
    end else if (clk_en) begin
        // Compute 0.5 × overall_alignment
        alignment_product <= HALF * overall_alignment;

        // threshold_scale = 1.5 - (0.5 × alignment)
        threshold_scale <= ONE_HALF - (alignment_product >>> FRAC);

        // Apply scale to base threshold
        threshold_product <= base_threshold * threshold_scale;
        ignition_threshold <= threshold_product >>> FRAC;
    end
end

//-----------------------------------------------------------------------------
// v1.2j: Ignition permission logic - PROPER 2-STAGE PIPELINE
// Permission requires:
// - f₀ alignment >= F0_MIN (0.3) = 4915 in Q14
// - f₂ stability >= F2_MIN (0.2) = 3277 in Q14
// - beta_quiet signal active
//
// PIPELINE FIX: The bug was that f0_ok/f2_ok are combinational wires that
// update immediately when boundary detector outputs change (same clock edge),
// but ignition_permitted was computed from these values BEFORE they updated.
// When testbench samples AFTER the clock edge, it sees:
//   - f0_ok/f2_ok: NEW values (combinational, already updated)
//   - ignition_permitted: computed from OLD f0_ok/f2_ok (registered)
//
// SOLUTION: Use a proper 2-stage pipeline where:
//   Stage 1: Register comparisons (f0_ok_reg, f2_ok_reg, beta_quiet_reg)
//   Stage 2: Compute ignition_permitted from Stage 1 registers
//
// This ensures ignition_permitted and the *_reg values are always aligned.
//-----------------------------------------------------------------------------
// Registered comparison results (Stage 1 of pipeline)
reg f0_ok_reg, f2_ok_reg, beta_quiet_reg;

// Intermediate comparison wires for debug export
wire f0_ok = (f0_alignment >= F0_MIN_ALIGNMENT);
wire f2_ok = (f2_stability >= F2_MIN_STABILITY);

// v1.2h: Debug - check what beta_quiet actually is
// debug_bq_is_0: true if beta_quiet === 1'b0
// debug_bq_is_1: true if beta_quiet === 1'b1
// If both are 0, beta_quiet is 'x'
wire debug_bq_is_0 = (beta_quiet === 1'b0) ? 1'b1 : 1'b0;
wire debug_bq_is_1 = (beta_quiet === 1'b1) ? 1'b1 : 1'b0;

// v1.2i: Debug - use raw comparisons (combinational, show current state)
wire debug_f0_ok_is_1 = (f0_ok === 1'b1) ? 1'b1 : 1'b0;
wire debug_f2_ok_is_1 = (f2_ok === 1'b1) ? 1'b1 : 1'b0;
wire debug_beta_quiet_is_1 = debug_bq_is_1;
wire debug_all_conditions_met = debug_f0_ok_is_1 && debug_f2_ok_is_1 && debug_beta_quiet_is_1;

// v1.2k: Debug - show CURRENT registered values (combinational view)
wire debug_f0_ok_reg_is_1 = (f0_ok_reg === 1'b1) ? 1'b1 : 1'b0;
wire debug_f2_ok_reg_is_1 = (f2_ok_reg === 1'b1) ? 1'b1 : 1'b0;
wire debug_beta_quiet_reg_is_1 = (beta_quiet_reg === 1'b1) ? 1'b1 : 1'b0;
wire debug_all_regs_met = debug_f0_ok_reg_is_1 && debug_f2_ok_reg_is_1 && debug_beta_quiet_reg_is_1;

// v1.2k: PROPER 2-STAGE PIPELINE for ignition permission
// Stage 1: Register the comparison results
always @(posedge clk or posedge rst) begin
    if (rst) begin
        f0_ok_reg <= 1'b0;
        f2_ok_reg <= 1'b0;
        beta_quiet_reg <= 1'b0;
    end else if (clk_en) begin
        // Register comparison results with 'x' handling
        f0_ok_reg <= (f0_ok === 1'b1) ? 1'b1 : 1'b0;
        f2_ok_reg <= (f2_ok === 1'b1) ? 1'b1 : 1'b0;
        beta_quiet_reg <= (beta_quiet === 1'b1) ? 1'b1 : 1'b0;
    end
end

// v1.2k: Stage 1.5 - Capture the values that Stage 2 will use for ignition_permitted
// These "prev" registers are delayed by 1 cycle from the _reg values
// After clock N: f0_ok_reg_prev = what f0_ok_reg was at START of clock N
//                ignition_permitted = computed from f0_ok_reg at START of clock N
// So f0_ok_reg_prev should match what ignition_permitted was computed from!
reg f0_ok_reg_prev, f2_ok_reg_prev, beta_quiet_reg_prev;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        f0_ok_reg_prev <= 1'b0;
        f2_ok_reg_prev <= 1'b0;
        beta_quiet_reg_prev <= 1'b0;
    end else if (clk_en) begin
        // Capture current _reg values BEFORE they get updated
        f0_ok_reg_prev <= f0_ok_reg;
        f2_ok_reg_prev <= f2_ok_reg;
        beta_quiet_reg_prev <= beta_quiet_reg;
    end
end

// v1.2k: Debug signal that should ALWAYS match ignition_permitted
// This uses the "prev" values which are what ignition_permitted was computed from
wire debug_f0_ok_prev_is_1 = (f0_ok_reg_prev === 1'b1) ? 1'b1 : 1'b0;
wire debug_f2_ok_prev_is_1 = (f2_ok_reg_prev === 1'b1) ? 1'b1 : 1'b0;
wire debug_bq_prev_is_1 = (beta_quiet_reg_prev === 1'b1) ? 1'b1 : 1'b0;
wire debug_ign_expected = debug_f0_ok_prev_is_1 && debug_f2_ok_prev_is_1 && debug_bq_prev_is_1;

// Stage 2: Compute ignition_permitted from registered values
// This ensures ignition_permitted matches f0_ok_reg/f2_ok_reg timing
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ignition_permitted <= 1'b0;
    end else if (clk_en) begin
        // Use REGISTERED comparisons - these are from the PREVIOUS cycle,
        // ensuring alignment with what the testbench sees
        if ((f0_ok_reg === 1'b1) && (f2_ok_reg === 1'b1) && (beta_quiet_reg === 1'b1))
            ignition_permitted <= 1'b1;
        else
            ignition_permitted <= 1'b0;
    end
end

//-----------------------------------------------------------------------------
// v1.2: Consciousness access determination - REGISTERED
// Requires ignition permitted + f₃ consciousness gate open
//-----------------------------------------------------------------------------
wire f3_ok = (f3_consciousness >= F3_MIN_CONSCIOUSNESS);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        consciousness_access_possible <= 1'b0;
    end else if (clk_en) begin
        // Use === to handle 'x' bits properly
        consciousness_access_possible <= (ignition_permitted === 1'b1) && (f3_ok === 1'b1);
    end
end

endmodule
