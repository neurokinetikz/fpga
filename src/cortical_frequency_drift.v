//=============================================================================
// Cortical Frequency Drift Generator - v3.6
//
// Models frequency variability in cortical oscillators for EEG-realistic output.
// Three components work together:
//
// 1. SLOW DRIFT: Bounded random walk (per-layer ranges AND rates, see below)
//    - v3.6: Per-layer update rates for "seeker-reference" dynamics
//    - Models slow frequency drift seen in EEG
//    - v3.5: Per-layer drift ranges matching SR harmonics
//
// 2. FAST JITTER: Cycle-by-cycle frequency noise (±0.2 Hz per sample)
//    - Updates every clk_en cycle (4 kHz)
//    - Adds small per-cycle variability for naturalness
//    - Does NOT create spectral broadening (that comes from amplitude modulation)
//
// 3. ADAPTIVE FORCE (v3.0, optional): Energy-landscape restoring force
//    - Enabled via ENABLE_ADAPTIVE parameter
//    - Receives force from energy_landscape.v
//    - Guides oscillators toward φⁿ half-integer attractors
//    - Force added to drift update with gain K_FORCE
//
// v3.6 CHANGES (Three-Boundary Architecture):
// - SEEKER RATES: Internal oscillators drift 3-5× faster than SR partners
//     L6:  0.625s (3× faster than SR1's 2s)    UPDATE_PERIOD = 2500
//     L5a: 2.0s   (5× faster than SR3's 10s)   UPDATE_PERIOD = 8000
//     L5b: 0.325s (3× faster than SR4's 1s)    UPDATE_PERIOD = 1300
//     L4:  0.625s (3× faster than SR5's 2s)    UPDATE_PERIOD = 2500
//     L23: 0.625s (same as L4)                 UPDATE_PERIOD = 2500
// - This implements the "seeker-reference" model where internal oscillators
//   scan faster than the external SR reference, creating alignment windows
//
// v3.5 CHANGES (Dual Alignment Ignition - v12.2):
// - Updated all frequencies to derive from SR1 = 7.75 Hz × φⁿ
// - Per-layer drift ranges matching corresponding SR harmonics:
//     L6:  ±0.5 Hz (13) - SR1 boundary
//     L5a: ±0.8 Hz (21) - SR2
//     L5b: ±1.5 Hz (39) - SR4
//     L4:  ±2.0 Hz (51) - SR5
//     L23: ±2.0 Hz (51) - no SR match
// - Added RANDOM_INIT parameter for stochastic startup
// - Added omega_dt_l6_actual output for alignment detector
//
// v3.4 CHANGES:
// - Added omega_correction inputs from energy_landscape.v escape mechanism
// - Direct frequency correction when oscillator enters catastrophe zone
// - omega_corr added to drift update (no additional scaling)
//
// v3.3 CHANGES:
// - CRITICAL FIX: Reduced jitter from ±4 Hz to ±0.2 Hz
// - Per-sample frequency jitter does NOT create realistic spectral broadening
// - Real EEG spectral width (~1-2 Hz) comes from amplitude modulation, not jitter
// - Previous ±4 Hz jitter created unrealistic 8 Hz wide smeared peaks
//
// v3.2 CHANGES: [REVERTED] Increased jitter to ±4 Hz - too aggressive
// v3.1 CHANGES: [REVERTED] Increased jitter to ±2 Hz - wrong mechanism
//
// v3.0 CHANGES:
// - Added ENABLE_ADAPTIVE parameter (default 0 for backwards compatibility)
// - Added force inputs from energy_landscape.v
// - Added K_FORCE gain for scaling force contribution
// - Force guides drift toward half-integer φⁿ attractors
//
// CORTICAL OSCILLATOR FREQUENCIES (v3.5: derived from SR1 = 7.75 Hz × φⁿ):
//   L6:   9.86 Hz  (φ^0.5)  - alpha band     (OMEGA_DT = 254)
//   L5a:  15.95 Hz (φ^1.5)  - low beta       (OMEGA_DT = 410)
//   L5b:  25.81 Hz (φ^2.5)  - high beta      (OMEGA_DT = 664)
//   L4:   32.83 Hz (φ^3)    - low gamma      (OMEGA_DT = 845)
//   L2/3: 41.76 Hz (φ^3.5)  - gamma          (OMEGA_DT = 1075)
//         67.6 Hz  (φ^4.5)  - fast gamma     (OMEGA_DT = 1740, encoding mode)
//
// Effect: Narrow spectral peaks (~1-2 Hz) with per-cycle naturalness
//=============================================================================
`timescale 1ns / 1ps

module cortical_frequency_drift #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_LAYERS = 5,
    parameter FAST_SIM = 0,
    parameter ENABLE_ADAPTIVE = 0,  // v3.0: Enable energy-landscape force input
    parameter RANDOM_INIT = 1       // v3.5: Enable random start position
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Slow drift offsets for each layer (bounded random walk, updates slowly)
    output wire signed [WIDTH-1:0] drift_l6,      // L6 alpha drift
    output wire signed [WIDTH-1:0] drift_l5a,     // L5a low-beta drift
    output wire signed [WIDTH-1:0] drift_l5b,     // L5b high-beta drift
    output wire signed [WIDTH-1:0] drift_l4,      // L4 low-gamma drift
    output wire signed [WIDTH-1:0] drift_l23,     // L2/3 gamma drift

    // Fast jitter for each layer (cycle-by-cycle noise, updates every sample)
    output wire signed [WIDTH-1:0] jitter_l6,     // L6 alpha jitter
    output wire signed [WIDTH-1:0] jitter_l5a,    // L5a low-beta jitter
    output wire signed [WIDTH-1:0] jitter_l5b,    // L5b high-beta jitter
    output wire signed [WIDTH-1:0] jitter_l4,     // L4 low-gamma jitter
    output wire signed [WIDTH-1:0] jitter_l23,    // L2/3 gamma jitter

    // v3.5: Actual L6 omega_dt for alignment detector
    output wire signed [WIDTH-1:0] omega_dt_l6_actual,  // Center + drift + jitter

    // v3.0: Adaptive force inputs from energy_landscape.v (optional)
    // When ENABLE_ADAPTIVE=1, these forces guide drift toward φⁿ attractors
    input  wire signed [WIDTH-1:0] force_l6,      // L6 restoring force
    input  wire signed [WIDTH-1:0] force_l5a,     // L5a restoring force
    input  wire signed [WIDTH-1:0] force_l5b,     // L5b restoring force
    input  wire signed [WIDTH-1:0] force_l4,      // L4 restoring force
    input  wire signed [WIDTH-1:0] force_l23,     // L2/3 restoring force

    // v11.2: Omega correction inputs from energy_landscape.v escape mechanism
    // Direct frequency correction to escape catastrophe zones
    input  wire signed [WIDTH-1:0] omega_corr_l6,   // L6 escape correction
    input  wire signed [WIDTH-1:0] omega_corr_l5a,  // L5a escape correction
    input  wire signed [WIDTH-1:0] omega_corr_l5b,  // L5b escape correction
    input  wire signed [WIDTH-1:0] omega_corr_l4,   // L4 escape correction
    input  wire signed [WIDTH-1:0] omega_corr_l23   // L2/3 escape correction
);

//-----------------------------------------------------------------------------
// v3.5: Center Frequencies (OMEGA_DT values)
// Derived from SR1 = 7.75 Hz × φⁿ for alignment detector output
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] OMEGA_CENTER_L6  = 18'sd254;   // 9.86 Hz  (φ^0.5)
localparam signed [WIDTH-1:0] OMEGA_CENTER_L5A = 18'sd410;   // 15.95 Hz (φ^1.5)
localparam signed [WIDTH-1:0] OMEGA_CENTER_L5B = 18'sd664;   // 25.81 Hz (φ^2.5)
localparam signed [WIDTH-1:0] OMEGA_CENTER_L4  = 18'sd845;   // 32.83 Hz (φ^3)
localparam signed [WIDTH-1:0] OMEGA_CENTER_L23 = 18'sd1075;  // 41.76 Hz (φ^3.5)

//-----------------------------------------------------------------------------
// v3.5: Per-Layer Drift Ranges (matching corresponding SR harmonics)
// Formula: DRIFT_MAX = round(2π × Δf × 0.00025 × 16384)
// L6 = SR1 boundary, L5a ~ SR2, L5b ~ SR4, L4/L23 ~ SR5
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] DRIFT_MAX_L6  = 18'sd13;   // ±0.5 Hz (SR1 boundary)
localparam signed [WIDTH-1:0] DRIFT_MAX_L5A = 18'sd21;   // ±0.8 Hz (SR2)
localparam signed [WIDTH-1:0] DRIFT_MAX_L5B = 18'sd39;   // ±1.5 Hz (SR4)
localparam signed [WIDTH-1:0] DRIFT_MAX_L4  = 18'sd51;   // ±2.0 Hz (SR5)
localparam signed [WIDTH-1:0] DRIFT_MAX_L23 = 18'sd51;   // ±2.0 Hz (no SR match)

//-----------------------------------------------------------------------------
// Fast Jitter Range
// ±0.2 Hz in OMEGA_DT units: round(2π × 0.2 × 0.00025 × 16384) = ±5
// Small per-sample frequency noise for natural variability
// Does NOT create spectral broadening - that comes from amplitude modulation
// v3.3: Reduced from ±4 Hz (103) which created unrealistic 8 Hz wide peaks
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] JITTER_MAX = 18'sd5;  // ±0.2 Hz (was ±4 Hz)

//-----------------------------------------------------------------------------
// v3.0: Adaptive Force Gain
// K_FORCE scales the energy-landscape force contribution to drift
// K_FORCE = 0.1 in Q14 = 1638 → small perturbations (±5% max)
// Force contribution: (K_FORCE × force) >>> FRAC added each update
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] K_FORCE = 18'sd1638;  // 0.1 in Q14

//-----------------------------------------------------------------------------
// v3.6: Per-Layer Update Periods (SEEKER RATES)
// Internal oscillators drift 3-5× faster than their SR partners
// Creating "seeker-reference" dynamics for alignment window emergence
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    // FAST_SIM: Scaled for longer alignment windows (~10-20ms instead of ~3ms)
    // Increased 4x from previous values while maintaining seeker-reference ratio
    localparam [21:0] UPDATE_PERIOD_L6  = 22'd1000;  // 0.25s (3× faster than SR1's 3200)
    localparam [21:0] UPDATE_PERIOD_L5A = 22'd3200;  // 0.8s (5× faster than SR3's 16000)
    localparam [21:0] UPDATE_PERIOD_L5B = 22'd500;   // 0.125s (3× faster than SR4's 1600)
    localparam [21:0] UPDATE_PERIOD_L4  = 22'd1000;  // 0.25s (3× faster than SR5's 3200)
    localparam [21:0] UPDATE_PERIOD_L23 = 22'd1000;  // 0.25s (same as L4)
`else
    // Real-time: Seeker rates relative to SR stability hierarchy
    localparam [21:0] UPDATE_PERIOD_L6  = (FAST_SIM != 0) ? 22'd250  : 22'd2500;   // 0.625s (3× SR1)
    localparam [21:0] UPDATE_PERIOD_L5A = (FAST_SIM != 0) ? 22'd800  : 22'd8000;   // 2.0s (5× SR3)
    localparam [21:0] UPDATE_PERIOD_L5B = (FAST_SIM != 0) ? 22'd130  : 22'd1300;   // 0.325s (3× SR4)
    localparam [21:0] UPDATE_PERIOD_L4  = (FAST_SIM != 0) ? 22'd250  : 22'd2500;   // 0.625s (3× SR5)
    localparam [21:0] UPDATE_PERIOD_L23 = (FAST_SIM != 0) ? 22'd250  : 22'd2500;   // 0.625s
`endif

//-----------------------------------------------------------------------------
// v3.6: Per-Layer Update Counters
// Each layer has its own counter and update tick for independent seeker rates
//-----------------------------------------------------------------------------
reg [21:0] update_counter_l6, update_counter_l5a, update_counter_l5b;
reg [21:0] update_counter_l4, update_counter_l23;
wire update_tick_l6, update_tick_l5a, update_tick_l5b, update_tick_l4, update_tick_l23;

assign update_tick_l6  = (update_counter_l6  == UPDATE_PERIOD_L6);
assign update_tick_l5a = (update_counter_l5a == UPDATE_PERIOD_L5A);
assign update_tick_l5b = (update_counter_l5b == UPDATE_PERIOD_L5B);
assign update_tick_l4  = (update_counter_l4  == UPDATE_PERIOD_L4);
assign update_tick_l23 = (update_counter_l23 == UPDATE_PERIOD_L23);

// L6 Update Counter
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter_l6 <= 22'd0;
    end else if (clk_en) begin
        if (update_tick_l6)
            update_counter_l6 <= 22'd0;
        else
            update_counter_l6 <= update_counter_l6 + 1'b1;
    end
end

// L5a Update Counter
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter_l5a <= 22'd0;
    end else if (clk_en) begin
        if (update_tick_l5a)
            update_counter_l5a <= 22'd0;
        else
            update_counter_l5a <= update_counter_l5a + 1'b1;
    end
end

// L5b Update Counter
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter_l5b <= 22'd0;
    end else if (clk_en) begin
        if (update_tick_l5b)
            update_counter_l5b <= 22'd0;
        else
            update_counter_l5b <= update_counter_l5b + 1'b1;
    end
end

// L4 Update Counter
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter_l4 <= 22'd0;
    end else if (clk_en) begin
        if (update_tick_l4)
            update_counter_l4 <= 22'd0;
        else
            update_counter_l4 <= update_counter_l4 + 1'b1;
    end
end

// L2/3 Update Counter
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter_l23 <= 22'd0;
    end else if (clk_en) begin
        if (update_tick_l23)
            update_counter_l23 <= 22'd0;
        else
            update_counter_l23 <= update_counter_l23 + 1'b1;
    end
end

//-----------------------------------------------------------------------------
// LFSR Seeds (unique per layer, different from SR seeds)
//-----------------------------------------------------------------------------
localparam [15:0] LFSR_SEED_L6  = 16'h7A3D;
localparam [15:0] LFSR_SEED_L5A = 16'hE5B2;
localparam [15:0] LFSR_SEED_L5B = 16'h29C8;
localparam [15:0] LFSR_SEED_L4  = 16'hD4F1;
localparam [15:0] LFSR_SEED_L23 = 16'h8167;

//-----------------------------------------------------------------------------
// v3.5: Random Initialization Offsets
// Use LFSR seed bits to compute initial position within drift bounds
// Maps seed bits [15:11] (0-31) to [-DRIFT_MAX, +DRIFT_MAX]
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] init_offset_l6, init_offset_l5a, init_offset_l5b;
wire signed [WIDTH-1:0] init_offset_l4, init_offset_l23;
assign init_offset_l6  = RANDOM_INIT ? (((LFSR_SEED_L6[15:11]  - 5'd16) * DRIFT_MAX_L6)  >>> 4) : 18'sd0;
assign init_offset_l5a = RANDOM_INIT ? (((LFSR_SEED_L5A[15:11] - 5'd16) * DRIFT_MAX_L5A) >>> 4) : 18'sd0;
assign init_offset_l5b = RANDOM_INIT ? (((LFSR_SEED_L5B[15:11] - 5'd16) * DRIFT_MAX_L5B) >>> 4) : 18'sd0;
assign init_offset_l4  = RANDOM_INIT ? (((LFSR_SEED_L4[15:11]  - 5'd16) * DRIFT_MAX_L4)  >>> 4) : 18'sd0;
assign init_offset_l23 = RANDOM_INIT ? (((LFSR_SEED_L23[15:11] - 5'd16) * DRIFT_MAX_L23) >>> 4) : 18'sd0;

//-----------------------------------------------------------------------------
// Per-Layer LFSR and Drift State
//-----------------------------------------------------------------------------
reg [15:0] lfsr_l6, lfsr_l5a, lfsr_l5b, lfsr_l4, lfsr_l23;
reg signed [WIDTH-1:0] drift_l6_reg, drift_l5a_reg, drift_l5b_reg, drift_l4_reg, drift_l23_reg;

// LFSR feedback: x^16 + x^14 + x^13 + x^11 + 1
wire fb_l6  = lfsr_l6[15]  ^ lfsr_l6[13]  ^ lfsr_l6[12]  ^ lfsr_l6[10];
wire fb_l5a = lfsr_l5a[15] ^ lfsr_l5a[13] ^ lfsr_l5a[12] ^ lfsr_l5a[10];
wire fb_l5b = lfsr_l5b[15] ^ lfsr_l5b[13] ^ lfsr_l5b[12] ^ lfsr_l5b[10];
wire fb_l4  = lfsr_l4[15]  ^ lfsr_l4[13]  ^ lfsr_l4[12]  ^ lfsr_l4[10];
wire fb_l23 = lfsr_l23[15] ^ lfsr_l23[13] ^ lfsr_l23[12] ^ lfsr_l23[10];

// Step direction from LSB
wire dir_l6  = lfsr_l6[0];
wire dir_l5a = lfsr_l5a[0];
wire dir_l5b = lfsr_l5b[0];
wire dir_l4  = lfsr_l4[0];
wire dir_l23 = lfsr_l23[0];

// Variable step size (1-2 for cortical, smaller than SR)
wire signed [WIDTH-1:0] step_l6  = lfsr_l6[1]  ? 18'sd2 : 18'sd1;
wire signed [WIDTH-1:0] step_l5a = lfsr_l5a[1] ? 18'sd2 : 18'sd1;
wire signed [WIDTH-1:0] step_l5b = lfsr_l5b[1] ? 18'sd2 : 18'sd1;
wire signed [WIDTH-1:0] step_l4  = lfsr_l4[1]  ? 18'sd2 : 18'sd1;
wire signed [WIDTH-1:0] step_l23 = lfsr_l23[1] ? 18'sd2 : 18'sd1;

//-----------------------------------------------------------------------------
// v3.0: Scaled Force Contributions
// force_contrib = (K_FORCE × force) >>> FRAC
// Need 36-bit intermediate for Q14 × Q14 multiplication
//-----------------------------------------------------------------------------
reg signed [2*WIDTH-1:0] force_product_l6, force_product_l5a, force_product_l5b;
reg signed [2*WIDTH-1:0] force_product_l4, force_product_l23;
wire signed [WIDTH-1:0] force_contrib_l6, force_contrib_l5a, force_contrib_l5b;
wire signed [WIDTH-1:0] force_contrib_l4, force_contrib_l23;

// Compute scaled force contributions (combinatorial for simplicity)
assign force_contrib_l6  = ENABLE_ADAPTIVE ? ((K_FORCE * force_l6)  >>> FRAC) : 18'sd0;
assign force_contrib_l5a = ENABLE_ADAPTIVE ? ((K_FORCE * force_l5a) >>> FRAC) : 18'sd0;
assign force_contrib_l5b = ENABLE_ADAPTIVE ? ((K_FORCE * force_l5b) >>> FRAC) : 18'sd0;
assign force_contrib_l4  = ENABLE_ADAPTIVE ? ((K_FORCE * force_l4)  >>> FRAC) : 18'sd0;
assign force_contrib_l23 = ENABLE_ADAPTIVE ? ((K_FORCE * force_l23) >>> FRAC) : 18'sd0;

//-----------------------------------------------------------------------------
// v11.2: Omega Correction Contributions
// Direct escape corrections from energy_landscape when in catastrophe zone
// No additional scaling - omega_corr is already in OMEGA_DT units
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] omega_corr_contrib_l6  = ENABLE_ADAPTIVE ? omega_corr_l6  : 18'sd0;
wire signed [WIDTH-1:0] omega_corr_contrib_l5a = ENABLE_ADAPTIVE ? omega_corr_l5a : 18'sd0;
wire signed [WIDTH-1:0] omega_corr_contrib_l5b = ENABLE_ADAPTIVE ? omega_corr_l5b : 18'sd0;
wire signed [WIDTH-1:0] omega_corr_contrib_l4  = ENABLE_ADAPTIVE ? omega_corr_l4  : 18'sd0;
wire signed [WIDTH-1:0] omega_corr_contrib_l23 = ENABLE_ADAPTIVE ? omega_corr_l23 : 18'sd0;

// Temporary variables for next_drift computation (Verilog-2001 compliance)
reg signed [WIDTH-1:0] next_drift_l6, next_drift_l5a, next_drift_l5b;
reg signed [WIDTH-1:0] next_drift_l4, next_drift_l23;

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L6 Alpha
// v3.6: Uses per-layer update_tick_l6 for seeker rate
// v3.0: Adds force_contrib when ENABLE_ADAPTIVE=1
// v3.5: Uses per-layer DRIFT_MAX and random initialization
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l6 <= LFSR_SEED_L6;
        drift_l6_reg <= init_offset_l6;  // v3.5: Random initial position
    end else if (clk_en && update_tick_l6) begin  // v3.6: Per-layer tick
        lfsr_l6 <= {lfsr_l6[14:0], fb_l6};
        // v3.0: Base step + force contribution + v11.2 omega correction, then clamp
        next_drift_l6 = dir_l6 ? (drift_l6_reg + step_l6 + force_contrib_l6 + omega_corr_contrib_l6)
                               : (drift_l6_reg - step_l6 + force_contrib_l6 + omega_corr_contrib_l6);
        if (next_drift_l6 > DRIFT_MAX_L6)
            drift_l6_reg <= DRIFT_MAX_L6;
        else if (next_drift_l6 < -DRIFT_MAX_L6)
            drift_l6_reg <= -DRIFT_MAX_L6;
        else
            drift_l6_reg <= next_drift_l6;
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L5a Low Beta
// v3.6: Uses per-layer update_tick_l5a for seeker rate (5× faster than SR3)
// v3.0: Adds force_contrib when ENABLE_ADAPTIVE=1
// v3.5: Uses per-layer DRIFT_MAX and random initialization
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l5a <= LFSR_SEED_L5A;
        drift_l5a_reg <= init_offset_l5a;  // v3.5: Random initial position
    end else if (clk_en && update_tick_l5a) begin  // v3.6: Per-layer tick
        lfsr_l5a <= {lfsr_l5a[14:0], fb_l5a};
        next_drift_l5a = dir_l5a ? (drift_l5a_reg + step_l5a + force_contrib_l5a + omega_corr_contrib_l5a)
                                 : (drift_l5a_reg - step_l5a + force_contrib_l5a + omega_corr_contrib_l5a);
        if (next_drift_l5a > DRIFT_MAX_L5A)
            drift_l5a_reg <= DRIFT_MAX_L5A;
        else if (next_drift_l5a < -DRIFT_MAX_L5A)
            drift_l5a_reg <= -DRIFT_MAX_L5A;
        else
            drift_l5a_reg <= next_drift_l5a;
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L5b High Beta
// v3.6: Uses per-layer update_tick_l5b for seeker rate (3× faster than SR4)
// v3.0: Adds force_contrib when ENABLE_ADAPTIVE=1
// v3.5: Uses per-layer DRIFT_MAX and random initialization
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l5b <= LFSR_SEED_L5B;
        drift_l5b_reg <= init_offset_l5b;  // v3.5: Random initial position
    end else if (clk_en && update_tick_l5b) begin  // v3.6: Per-layer tick
        lfsr_l5b <= {lfsr_l5b[14:0], fb_l5b};
        next_drift_l5b = dir_l5b ? (drift_l5b_reg + step_l5b + force_contrib_l5b + omega_corr_contrib_l5b)
                                 : (drift_l5b_reg - step_l5b + force_contrib_l5b + omega_corr_contrib_l5b);
        if (next_drift_l5b > DRIFT_MAX_L5B)
            drift_l5b_reg <= DRIFT_MAX_L5B;
        else if (next_drift_l5b < -DRIFT_MAX_L5B)
            drift_l5b_reg <= -DRIFT_MAX_L5B;
        else
            drift_l5b_reg <= next_drift_l5b;
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L4 Low Gamma
// v3.6: Uses per-layer update_tick_l4 for seeker rate (3× faster than SR5)
// v3.0: Adds force_contrib when ENABLE_ADAPTIVE=1
// v3.5: Uses per-layer DRIFT_MAX and random initialization
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l4 <= LFSR_SEED_L4;
        drift_l4_reg <= init_offset_l4;  // v3.5: Random initial position
    end else if (clk_en && update_tick_l4) begin  // v3.6: Per-layer tick
        lfsr_l4 <= {lfsr_l4[14:0], fb_l4};
        next_drift_l4 = dir_l4 ? (drift_l4_reg + step_l4 + force_contrib_l4 + omega_corr_contrib_l4)
                               : (drift_l4_reg - step_l4 + force_contrib_l4 + omega_corr_contrib_l4);
        if (next_drift_l4 > DRIFT_MAX_L4)
            drift_l4_reg <= DRIFT_MAX_L4;
        else if (next_drift_l4 < -DRIFT_MAX_L4)
            drift_l4_reg <= -DRIFT_MAX_L4;
        else
            drift_l4_reg <= next_drift_l4;
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L2/3 Gamma
// v3.6: Uses per-layer update_tick_l23 for seeker rate
// v3.0: Adds force_contrib when ENABLE_ADAPTIVE=1
// v3.5: Uses per-layer DRIFT_MAX and random initialization
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l23 <= LFSR_SEED_L23;
        drift_l23_reg <= init_offset_l23;  // v3.5: Random initial position
    end else if (clk_en && update_tick_l23) begin  // v3.6: Per-layer tick
        lfsr_l23 <= {lfsr_l23[14:0], fb_l23};
        next_drift_l23 = dir_l23 ? (drift_l23_reg + step_l23 + force_contrib_l23 + omega_corr_contrib_l23)
                                 : (drift_l23_reg - step_l23 + force_contrib_l23 + omega_corr_contrib_l23);
        if (next_drift_l23 > DRIFT_MAX_L23)
            drift_l23_reg <= DRIFT_MAX_L23;
        else if (next_drift_l23 < -DRIFT_MAX_L23)
            drift_l23_reg <= -DRIFT_MAX_L23;
        else
            drift_l23_reg <= next_drift_l23;
    end
end

//=============================================================================
// FAST JITTER - Cycle-by-cycle frequency noise for spectral broadening
//=============================================================================

//-----------------------------------------------------------------------------
// Fast Jitter LFSR Seeds (different from slow drift seeds)
//-----------------------------------------------------------------------------
localparam [15:0] JLFSR_SEED_L6  = 16'hB2C4;
localparam [15:0] JLFSR_SEED_L5A = 16'h4F8E;
localparam [15:0] JLFSR_SEED_L5B = 16'hD1A7;
localparam [15:0] JLFSR_SEED_L4  = 16'h6E39;
localparam [15:0] JLFSR_SEED_L23 = 16'h95CB;

//-----------------------------------------------------------------------------
// Fast Jitter LFSR State (updates every clk_en cycle)
//-----------------------------------------------------------------------------
reg [15:0] jlfsr_l6, jlfsr_l5a, jlfsr_l5b, jlfsr_l4, jlfsr_l23;

// LFSR feedback for fast jitter (same polynomial)
wire jfb_l6  = jlfsr_l6[15]  ^ jlfsr_l6[13]  ^ jlfsr_l6[12]  ^ jlfsr_l6[10];
wire jfb_l5a = jlfsr_l5a[15] ^ jlfsr_l5a[13] ^ jlfsr_l5a[12] ^ jlfsr_l5a[10];
wire jfb_l5b = jlfsr_l5b[15] ^ jlfsr_l5b[13] ^ jlfsr_l5b[12] ^ jlfsr_l5b[10];
wire jfb_l4  = jlfsr_l4[15]  ^ jlfsr_l4[13]  ^ jlfsr_l4[12]  ^ jlfsr_l4[10];
wire jfb_l23 = jlfsr_l23[15] ^ jlfsr_l23[13] ^ jlfsr_l23[12] ^ jlfsr_l23[10];

//-----------------------------------------------------------------------------
// Fast Jitter Update Logic (updates EVERY clk_en cycle)
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        jlfsr_l6  <= JLFSR_SEED_L6;
        jlfsr_l5a <= JLFSR_SEED_L5A;
        jlfsr_l5b <= JLFSR_SEED_L5B;
        jlfsr_l4  <= JLFSR_SEED_L4;
        jlfsr_l23 <= JLFSR_SEED_L23;
    end else if (clk_en) begin
        jlfsr_l6  <= {jlfsr_l6[14:0],  jfb_l6};
        jlfsr_l5a <= {jlfsr_l5a[14:0], jfb_l5a};
        jlfsr_l5b <= {jlfsr_l5b[14:0], jfb_l5b};
        jlfsr_l4  <= {jlfsr_l4[14:0],  jfb_l4};
        jlfsr_l23 <= {jlfsr_l23[14:0], jfb_l23};
    end
end

//-----------------------------------------------------------------------------
// Fast Jitter Value Computation
// v3.3: Use 2 bits from LFSR to create values in range [-5, +5] (±0.2 Hz)
// Simple triangular distribution: (bit1 ? +3 : -3) + (bit0 ? +2 : -2)
// Range: -5 to +5, already within JITTER_MAX so no clamping needed
// IMPORTANT: Per-sample jitter does NOT create spectral broadening
//            Real EEG spectral width comes from amplitude modulation
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] jitter_l6_raw  = (jlfsr_l6[1]  ? 18'sd3 : -18'sd3) +
                                          (jlfsr_l6[0]  ? 18'sd2 : -18'sd2);

wire signed [WIDTH-1:0] jitter_l5a_raw = (jlfsr_l5a[1] ? 18'sd3 : -18'sd3) +
                                          (jlfsr_l5a[0] ? 18'sd2 : -18'sd2);

wire signed [WIDTH-1:0] jitter_l5b_raw = (jlfsr_l5b[1] ? 18'sd3 : -18'sd3) +
                                          (jlfsr_l5b[0] ? 18'sd2 : -18'sd2);

wire signed [WIDTH-1:0] jitter_l4_raw  = (jlfsr_l4[1]  ? 18'sd3 : -18'sd3) +
                                          (jlfsr_l4[0]  ? 18'sd2 : -18'sd2);

wire signed [WIDTH-1:0] jitter_l23_raw = (jlfsr_l23[1] ? 18'sd3 : -18'sd3) +
                                          (jlfsr_l23[0] ? 18'sd2 : -18'sd2);

//-----------------------------------------------------------------------------
// Output Assignments
//-----------------------------------------------------------------------------
// Slow drift outputs
assign drift_l6  = drift_l6_reg;
assign drift_l5a = drift_l5a_reg;
assign drift_l5b = drift_l5b_reg;
assign drift_l4  = drift_l4_reg;
assign drift_l23 = drift_l23_reg;

// Fast jitter outputs (clamped to ±JITTER_MAX for safety)
assign jitter_l6  = (jitter_l6_raw  > JITTER_MAX) ? JITTER_MAX :
                    (jitter_l6_raw  < -JITTER_MAX) ? -JITTER_MAX : jitter_l6_raw;
assign jitter_l5a = (jitter_l5a_raw > JITTER_MAX) ? JITTER_MAX :
                    (jitter_l5a_raw < -JITTER_MAX) ? -JITTER_MAX : jitter_l5a_raw;
assign jitter_l5b = (jitter_l5b_raw > JITTER_MAX) ? JITTER_MAX :
                    (jitter_l5b_raw < -JITTER_MAX) ? -JITTER_MAX : jitter_l5b_raw;
assign jitter_l4  = (jitter_l4_raw  > JITTER_MAX) ? JITTER_MAX :
                    (jitter_l4_raw  < -JITTER_MAX) ? -JITTER_MAX : jitter_l4_raw;
assign jitter_l23 = (jitter_l23_raw > JITTER_MAX) ? JITTER_MAX :
                    (jitter_l23_raw < -JITTER_MAX) ? -JITTER_MAX : jitter_l23_raw;

// v3.5: Actual L6 omega_dt for alignment detector (center + drift + jitter)
assign omega_dt_l6_actual = OMEGA_CENTER_L6 + drift_l6 + jitter_l6;

endmodule
