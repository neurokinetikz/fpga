//=============================================================================
// Cortical Frequency Drift Generator - v3.4
//
// Models frequency variability in cortical oscillators for EEG-realistic output.
// Three components work together:
//
// 1. SLOW DRIFT: Bounded random walk (±0.5 Hz over seconds)
//    - Updates every 0.2s in simulation
//    - Models slow frequency drift seen in EEG
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
// CORTICAL OSCILLATOR FREQUENCIES (phi^n based):
//   L6:   9.53 Hz  (phi^0.5)  - alpha band
//   L5a:  15.42 Hz (phi^1.5)  - low beta
//   L5b:  24.94 Hz (phi^2.5)  - high beta
//   L4:   31.73 Hz (phi^3)    - low gamma
//   L2/3: 40.36 Hz (phi^3.5)  - gamma (switches to 65.3 Hz in encoding)
//
// Effect: Narrow spectral peaks (~1-2 Hz) with per-cycle naturalness
//=============================================================================
`timescale 1ns / 1ps

module cortical_frequency_drift #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_LAYERS = 5,
    parameter FAST_SIM = 0,
    parameter ENABLE_ADAPTIVE = 0  // v3.0: Enable energy-landscape force input
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
// Slow Drift Range
// ±0.5 Hz in OMEGA_DT units: round(2π × 0.5 × 0.00025 × 16384) = ±13
// Cortical oscillators are more stable than SR
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] DRIFT_MAX = 18'sd13;  // ±0.5 Hz

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
// Update Period
// Slower than SR drift - cortical oscillators are more stable
// FAST_SIM: 800 clk_en = 0.2s at 4kHz
// Real-time: 1920000 clk_en = 8 minutes
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    localparam [21:0] UPDATE_PERIOD = 22'd800;      // 0.2s updates (slower than SR)
`else
    localparam [21:0] UPDATE_PERIOD = (FAST_SIM != 0) ? 22'd800 : 22'd1920000;
`endif

//-----------------------------------------------------------------------------
// Update Counter
//-----------------------------------------------------------------------------
reg [21:0] update_counter;
wire update_tick;

assign update_tick = (update_counter == UPDATE_PERIOD);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter <= 22'd0;
    end else if (clk_en) begin
        if (update_tick) begin
            update_counter <= 22'd0;
        end else begin
            update_counter <= update_counter + 1'b1;
        end
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
// v3.0: Adds force_contrib when ENABLE_ADAPTIVE=1
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l6 <= LFSR_SEED_L6;
        drift_l6_reg <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_l6 <= {lfsr_l6[14:0], fb_l6};
        // v3.0: Base step + force contribution + v11.2 omega correction, then clamp
        next_drift_l6 = dir_l6 ? (drift_l6_reg + step_l6 + force_contrib_l6 + omega_corr_contrib_l6)
                               : (drift_l6_reg - step_l6 + force_contrib_l6 + omega_corr_contrib_l6);
        if (next_drift_l6 > DRIFT_MAX)
            drift_l6_reg <= DRIFT_MAX;
        else if (next_drift_l6 < -DRIFT_MAX)
            drift_l6_reg <= -DRIFT_MAX;
        else
            drift_l6_reg <= next_drift_l6;
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L5a Low Beta
// v3.0: Adds force_contrib when ENABLE_ADAPTIVE=1
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l5a <= LFSR_SEED_L5A;
        drift_l5a_reg <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_l5a <= {lfsr_l5a[14:0], fb_l5a};
        next_drift_l5a = dir_l5a ? (drift_l5a_reg + step_l5a + force_contrib_l5a + omega_corr_contrib_l5a)
                                 : (drift_l5a_reg - step_l5a + force_contrib_l5a + omega_corr_contrib_l5a);
        if (next_drift_l5a > DRIFT_MAX)
            drift_l5a_reg <= DRIFT_MAX;
        else if (next_drift_l5a < -DRIFT_MAX)
            drift_l5a_reg <= -DRIFT_MAX;
        else
            drift_l5a_reg <= next_drift_l5a;
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L5b High Beta
// v3.0: Adds force_contrib when ENABLE_ADAPTIVE=1
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l5b <= LFSR_SEED_L5B;
        drift_l5b_reg <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_l5b <= {lfsr_l5b[14:0], fb_l5b};
        next_drift_l5b = dir_l5b ? (drift_l5b_reg + step_l5b + force_contrib_l5b + omega_corr_contrib_l5b)
                                 : (drift_l5b_reg - step_l5b + force_contrib_l5b + omega_corr_contrib_l5b);
        if (next_drift_l5b > DRIFT_MAX)
            drift_l5b_reg <= DRIFT_MAX;
        else if (next_drift_l5b < -DRIFT_MAX)
            drift_l5b_reg <= -DRIFT_MAX;
        else
            drift_l5b_reg <= next_drift_l5b;
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L4 Low Gamma
// v3.0: Adds force_contrib when ENABLE_ADAPTIVE=1
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l4 <= LFSR_SEED_L4;
        drift_l4_reg <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_l4 <= {lfsr_l4[14:0], fb_l4};
        next_drift_l4 = dir_l4 ? (drift_l4_reg + step_l4 + force_contrib_l4 + omega_corr_contrib_l4)
                               : (drift_l4_reg - step_l4 + force_contrib_l4 + omega_corr_contrib_l4);
        if (next_drift_l4 > DRIFT_MAX)
            drift_l4_reg <= DRIFT_MAX;
        else if (next_drift_l4 < -DRIFT_MAX)
            drift_l4_reg <= -DRIFT_MAX;
        else
            drift_l4_reg <= next_drift_l4;
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L2/3 Gamma
// v3.0: Adds force_contrib when ENABLE_ADAPTIVE=1
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l23 <= LFSR_SEED_L23;
        drift_l23_reg <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_l23 <= {lfsr_l23[14:0], fb_l23};
        next_drift_l23 = dir_l23 ? (drift_l23_reg + step_l23 + force_contrib_l23 + omega_corr_contrib_l23)
                                 : (drift_l23_reg - step_l23 + force_contrib_l23 + omega_corr_contrib_l23);
        if (next_drift_l23 > DRIFT_MAX)
            drift_l23_reg <= DRIFT_MAX;
        else if (next_drift_l23 < -DRIFT_MAX)
            drift_l23_reg <= -DRIFT_MAX;
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

endmodule
