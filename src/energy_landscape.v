//=============================================================================
// Energy Landscape Module - v11.1b
//
// Computes restoring forces based on the φⁿ energy landscape with harmonic
// force terms from rational resonances, implementing the Unified Boundary-
// Attractor Framework.
//
// Total Force: F_total(n) = F_φ(n) + F_harmonic(n) + F_rational(n)
//
// 1. φⁿ Landscape Force: F_φ(n) = +2πA × sin(2πn)
//    - ATTRACTORS at half-integers (n = 0.5, 1.5, 2.5, ...)
//    - BOUNDARIES at integers (n = 0, 1, 2, ...)
//
// 2. Harmonic Catastrophe Force: F_harmonic(n)
//    - Strong repulsion near integer ratios (2:1, 3:1, 4:1)
//    - Zone-based: constant repulsion within danger zones
//
// 3. Rational Resonance Force: F_rational(n) = Σ -2B_i × d / (d² + ε²)²
//    - Lorentzian gradient pushes oscillators AWAY from p/q ratios
//    - Weight B_i = BASE_REPULSION / q² (integers strongest)
//    - Rationals: q≤3 gives 15 ratios in range [0.5, 5.0]
//
// Key n-positions (φⁿ = ratio):
//   q=1: 1→0, 2→1.44, 3→2.28, 4→2.88, 5→3.34
//   q=2: 3/2→0.84, 5/2→1.90, 7/2→2.60, 9/2→3.12
//   q=3: 4/3→0.60, 5/3→1.06, 7/3→1.75, 8/3→2.01, 10/3→2.44, 11/3→2.56
//
// v11.0: Initial implementation with quarter-wave sine LUT
// v11.1b: Added rational resonance forces with Lorentzian gradient
//=============================================================================
`timescale 1ns / 1ps

module energy_landscape #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_OSCILLATORS = 21,
    parameter ENABLE_ADAPTIVE = 1
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Exponent n for each oscillator (Q14 format)
    // n = log_φ(ratio) where ratio = oscillator_freq / reference_freq
    // Precomputed: theta=-0.5, L6=0.5, L5a=1.5, L5b=2.5, L4=3.0, etc.
    input  wire signed [NUM_OSCILLATORS*WIDTH-1:0] n_packed,

    // Current frequency drift for each oscillator (modifies effective n)
    input  wire signed [NUM_OSCILLATORS*WIDTH-1:0] drift_packed,

    // Force output for each oscillator (Q14 format)
    // Positive force: push toward higher n
    // Negative force: push toward lower n
    output wire signed [NUM_OSCILLATORS*WIDTH-1:0] force_packed,

    // Per-oscillator outputs
    output wire signed [NUM_OSCILLATORS*WIDTH-1:0] energy_packed,  // E(n) for monitoring

    // Harmonic catastrophe flags
    output wire [NUM_OSCILLATORS-1:0] near_harmonic_2_1,  // True if φⁿ close to 2.0
    output wire [NUM_OSCILLATORS-1:0] near_harmonic_3_1,  // True if φⁿ close to 3.0
    output wire [NUM_OSCILLATORS-1:0] near_harmonic_4_1   // True if φⁿ close to 4.0
);

//-----------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] ONE_Q14 = 18'sd16384;
localparam signed [WIDTH-1:0] TWO_PI_Q14 = 18'sd102944;  // 2π × 16384 (but overflows, use shift)

// Force amplitude A (0.1 for gentle correction)
// 2πA in Q14 = 2 × 3.14159 × 0.1 × 16384 = 10294
localparam signed [WIDTH-1:0] TWO_PI_A = 18'sd10294;

//-----------------------------------------------------------------------------
// Harmonic Catastrophe Parameters (Zone-based repulsion)
// Strong constant repulsion near integer ratios
//-----------------------------------------------------------------------------
// 2:1 catastrophe: φ^1.44 ≈ 2.0, zone n ∈ [1.35, 1.55]
localparam signed [WIDTH-1:0] N_2_1_LOW = 18'sd22118;     // n = 1.35
localparam signed [WIDTH-1:0] N_2_1_HIGH = 18'sd25395;    // n = 1.55
localparam signed [WIDTH-1:0] N_2_1_CENTER = 18'sd23593;  // n = 1.44

// 3:1 catastrophe: φ^2.28 ≈ 3.0, zone n ∈ [2.20, 2.36]
localparam signed [WIDTH-1:0] N_3_1_LOW = 18'sd36045;     // n = 2.20
localparam signed [WIDTH-1:0] N_3_1_HIGH = 18'sd38666;    // n = 2.36
localparam signed [WIDTH-1:0] N_3_1_CENTER = 18'sd37409;  // n = 2.283

// 4:1 catastrophe: φ^2.88 ≈ 4.0, zone n ∈ [2.80, 2.96]
localparam signed [WIDTH-1:0] N_4_1_LOW = 18'sd45875;     // n = 2.80
localparam signed [WIDTH-1:0] N_4_1_HIGH = 18'sd48497;    // n = 2.96
localparam signed [WIDTH-1:0] N_4_1_CENTER = 18'sd47198;  // n = 2.881

// Zone repulsion strengths (must overcome φ-landscape force)
// All zones need sufficient strength to overcome phi-force at zone center
// phi-force at zone center ≈ 2πA×sin(2π×frac) where frac is fractional part
// At n=1.44: sin(0.88π) ≈ 0.37, F_phi ≈ 3800, need K > 3800
// At n=2.28: sin(0.56π) ≈ 0.95, F_phi ≈ 9800, need K > 9800
// At n=2.88: sin(0.76π) ≈ 0.69, F_phi ≈ 7100, need K > 7100
localparam signed [WIDTH-1:0] K_CATASTROPHE_2_1 = 18'sd12288;  // 0.75 (decisive)
localparam signed [WIDTH-1:0] K_CATASTROPHE_3_1 = 18'sd16384;  // 1.00 (must overcome 0.95 phi-force)
localparam signed [WIDTH-1:0] K_CATASTROPHE_4_1 = 18'sd12288;  // 0.75 (moderate)

//-----------------------------------------------------------------------------
// Rational Resonance Parameters (Lorentzian gradient forces)
// 15 rationals with q ≤ 3 in range [0.5, 5.0]
//-----------------------------------------------------------------------------
localparam NUM_RATIONALS = 15;

// n-positions where φⁿ = p/q (precomputed, Q14 format)
// q=1: integers (weight 1.0)
localparam signed [WIDTH-1:0] N_RAT_1_1 = 18'sd0;         // φⁿ=1, n=0
localparam signed [WIDTH-1:0] N_RAT_2_1 = 18'sd23593;     // φⁿ=2, n=1.440
localparam signed [WIDTH-1:0] N_RAT_3_1 = 18'sd37409;     // φⁿ=3, n=2.283
localparam signed [WIDTH-1:0] N_RAT_4_1 = 18'sd47198;     // φⁿ=4, n=2.881
localparam signed [WIDTH-1:0] N_RAT_5_1 = 18'sd54715;     // φⁿ=5, n=3.340

// q=2: half-integers (weight 0.25)
localparam signed [WIDTH-1:0] N_RAT_3_2 = 18'sd13768;     // φⁿ=1.5, n=0.840
localparam signed [WIDTH-1:0] N_RAT_5_2 = 18'sd31115;     // φⁿ=2.5, n=1.900
localparam signed [WIDTH-1:0] N_RAT_7_2 = 18'sd42563;     // φⁿ=3.5, n=2.599
localparam signed [WIDTH-1:0] N_RAT_9_2 = 18'sd51130;     // φⁿ=4.5, n=3.121

// q=3: thirds (weight 0.111)
localparam signed [WIDTH-1:0] N_RAT_4_3 = 18'sd9787;      // φⁿ=1.333, n=0.598
localparam signed [WIDTH-1:0] N_RAT_5_3 = 18'sd17352;     // φⁿ=1.667, n=1.059
localparam signed [WIDTH-1:0] N_RAT_7_3 = 18'sd28741;     // φⁿ=2.333, n=1.755
localparam signed [WIDTH-1:0] N_RAT_8_3 = 18'sd32986;     // φⁿ=2.667, n=2.013
localparam signed [WIDTH-1:0] N_RAT_10_3 = 18'sd39980;    // φⁿ=3.333, n=2.440
localparam signed [WIDTH-1:0] N_RAT_11_3 = 18'sd41986;    // φⁿ=3.667, n=2.563

// Weights: B = BASE_REPULSION / q² (Q14 format)
// BASE_REPULSION = 0.05 (reduced to avoid overpowering φ-landscape)
localparam signed [WIDTH-1:0] B_Q1 = 18'sd820;    // 0.05 × 1.0 = 0.05
localparam signed [WIDTH-1:0] B_Q2 = 18'sd205;    // 0.05 × 0.25 = 0.0125
localparam signed [WIDTH-1:0] B_Q3 = 18'sd91;     // 0.05 × 0.111 = 0.0056

// Lorentzian regularization ε² (prevents singularity at exact rationals)
// ε = 0.03 in n-space, ε² = 0.0009
localparam signed [WIDTH-1:0] EPSILON_SQ = 18'sd15;  // 0.0009 × 16384 ≈ 15

// Backward compatibility alias
localparam signed [WIDTH-1:0] N_DANGER_LOW = N_2_1_LOW;
localparam signed [WIDTH-1:0] N_DANGER_HIGH = N_2_1_HIGH;
localparam signed [WIDTH-1:0] N_CATASTROPHE = N_2_1_CENTER;
localparam signed [WIDTH-1:0] K_CATASTROPHE = K_CATASTROPHE_2_1;

//-----------------------------------------------------------------------------
// Unpack inputs
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] n_base [0:NUM_OSCILLATORS-1];
wire signed [WIDTH-1:0] drift [0:NUM_OSCILLATORS-1];

genvar g;
generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : unpack_inputs
        assign n_base[g] = n_packed[g*WIDTH +: WIDTH];
        assign drift[g] = drift_packed[g*WIDTH +: WIDTH];
    end
endgenerate

//-----------------------------------------------------------------------------
// Effective n computation (base + drift contribution)
// Drift in OMEGA_DT units converts to fractional n change
// Approximate: delta_n = drift × ln(φ) / OMEGA_DT_ref
// For simplicity, use small drift contribution: delta_n ≈ drift / 1000
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] n_effective [0:NUM_OSCILLATORS-1];

generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : compute_n_eff
        // drift / 1024 ≈ drift >> 10 (converts OMEGA_DT drift to n shift)
        wire signed [WIDTH-1:0] n_delta = drift[g] >>> 10;
        assign n_effective[g] = n_base[g] + n_delta;
    end
endgenerate

//-----------------------------------------------------------------------------
// Phase computation for sine LUT
// We need sin(2πn) where n is in Q14
// Phase represents fraction of 2π cycle: phase / 1024 = fractional part of n
// For one full sine cycle per unit n:
//   phase = (n_real mod 1) × 1024 = ((n_q14 / 16384) mod 1) × 1024
//         = (n_q14 >> 4) mod 1024 = n_q14[13:4]
//-----------------------------------------------------------------------------
wire [9:0] phase [0:NUM_OSCILLATORS-1];

generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : compute_phase
        // Extract fractional part of n and scale to 10-bit phase
        // n_effective is Q14 (4 integer bits, 14 fractional bits)
        // phase = (n >> 4) & 0x3FF gives us n × 1024 / 16384 mod 1024
        // This maps one unit of n to one full 2π rotation
        assign phase[g] = n_effective[g][FRAC-1 -: 10];  // bits [13:4]
    end
endgenerate

//-----------------------------------------------------------------------------
// Sine LUT instances (shared for multiple oscillators)
// For efficiency, we use time-multiplexing with a single LUT
// In this version, we instantiate one LUT per oscillator for clarity
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] sin_val [0:NUM_OSCILLATORS-1];

generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : sin_luts
        sin_quarter_lut #(
            .WIDTH(WIDTH),
            .FRAC(FRAC)
        ) sin_inst (
            .clk(clk),
            .phase(phase[g]),
            .sin_out(sin_val[g])
        );
    end
endgenerate

//-----------------------------------------------------------------------------
// Force computation: F_total = F_phi + F_harmonic + F_rational
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] force_phi [0:NUM_OSCILLATORS-1];      // φⁿ landscape force
reg signed [WIDTH-1:0] force_harmonic [0:NUM_OSCILLATORS-1]; // Zone catastrophe force
reg signed [WIDTH-1:0] force_rational [0:NUM_OSCILLATORS-1]; // Rational resonance force
reg signed [WIDTH-1:0] force_total [0:NUM_OSCILLATORS-1];    // Combined force
reg signed [WIDTH-1:0] energy [0:NUM_OSCILLATORS-1];

// Catastrophe zone flags
reg [NUM_OSCILLATORS-1:0] near_2_1_reg;
reg [NUM_OSCILLATORS-1:0] near_3_1_reg;
reg [NUM_OSCILLATORS-1:0] near_4_1_reg;

// Intermediate products for force computation (need 36 bits to avoid overflow)
reg signed [2*WIDTH-1:0] force_product;
reg signed [2*WIDTH-1:0] energy_product;

// Rational force computation variables
reg signed [WIDTH-1:0] n_rat [0:NUM_RATIONALS-1];  // Rational n-positions
reg signed [WIDTH-1:0] b_rat [0:NUM_RATIONALS-1];  // Weights (1/q²)
reg signed [WIDTH-1:0] dist;                        // Distance to rational
reg signed [2*WIDTH-1:0] dist_sq;                   // d²
reg signed [2*WIDTH-1:0] denom;                     // d² + ε²
reg signed [2*WIDTH-1:0] denom_sq;                  // (d² + ε²)²
reg signed [2*WIDTH-1:0] f_num;                     // Numerator: -2B × d
reg signed [2*WIDTH-1:0] f_rat_single;              // Single rational force
reg signed [WIDTH-1:0] f_rat_accum;                 // Accumulated rational force

// Loop variables
integer i, r;

// Initialize rational position and weight arrays
initial begin
    // q=1 rationals (weight B_Q1 = 0.05)
    n_rat[0]  = N_RAT_1_1;  b_rat[0]  = B_Q1;
    n_rat[1]  = N_RAT_2_1;  b_rat[1]  = B_Q1;
    n_rat[2]  = N_RAT_3_1;  b_rat[2]  = B_Q1;
    n_rat[3]  = N_RAT_4_1;  b_rat[3]  = B_Q1;
    n_rat[4]  = N_RAT_5_1;  b_rat[4]  = B_Q1;
    // q=2 rationals (weight B_Q2 = 0.0125)
    n_rat[5]  = N_RAT_3_2;  b_rat[5]  = B_Q2;
    n_rat[6]  = N_RAT_5_2;  b_rat[6]  = B_Q2;
    n_rat[7]  = N_RAT_7_2;  b_rat[7]  = B_Q2;
    n_rat[8]  = N_RAT_9_2;  b_rat[8]  = B_Q2;
    // q=3 rationals (weight B_Q3 = 0.0056)
    n_rat[9]  = N_RAT_4_3;  b_rat[9]  = B_Q3;
    n_rat[10] = N_RAT_5_3;  b_rat[10] = B_Q3;
    n_rat[11] = N_RAT_7_3;  b_rat[11] = B_Q3;
    n_rat[12] = N_RAT_8_3;  b_rat[12] = B_Q3;
    n_rat[13] = N_RAT_10_3; b_rat[13] = B_Q3;
    n_rat[14] = N_RAT_11_3; b_rat[14] = B_Q3;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < NUM_OSCILLATORS; i = i + 1) begin
            force_phi[i] <= 18'sd0;
            force_harmonic[i] <= 18'sd0;
            force_rational[i] <= 18'sd0;
            force_total[i] <= 18'sd0;
            energy[i] <= 18'sd0;
        end
        near_2_1_reg <= 0;
        near_3_1_reg <= 0;
        near_4_1_reg <= 0;
    end else if (clk_en && ENABLE_ADAPTIVE) begin
        for (i = 0; i < NUM_OSCILLATORS; i = i + 1) begin
            //=================================================================
            // 1. φⁿ landscape force: F = +2πA × sin(2πn)
            // For E(n) = +A × cos(2πn): minima at half-integers (0.5, 1.5, ...)
            // Force F = -dE/dn = +2πA × sin(2πn)
            //=================================================================
            force_product = TWO_PI_A * sin_val[i];  // 36-bit intermediate
            force_phi[i] <= force_product >>> FRAC;

            //=================================================================
            // 2. Harmonic catastrophe forces (zone-based constant repulsion)
            // Push AWAY from integer ratios toward nearest quarter-integer
            //=================================================================
            if (n_effective[i] >= N_2_1_LOW && n_effective[i] <= N_2_1_HIGH) begin
                // 2:1 zone: push down toward n=1.25 (φ^1.25 fallback)
                force_harmonic[i] <= -K_CATASTROPHE_2_1;
                near_2_1_reg[i] <= 1'b1;
            end else if (n_effective[i] >= N_3_1_LOW && n_effective[i] <= N_3_1_HIGH) begin
                // 3:1 zone: push toward nearest attractor
                // Center at n=2.283, attractors at n=1.9 (5/2) and n=2.5 (half-int)
                // Push down toward n=1.9 for most cases
                force_harmonic[i] <= -K_CATASTROPHE_3_1;
                near_3_1_reg[i] <= 1'b1;
            end else if (n_effective[i] >= N_4_1_LOW && n_effective[i] <= N_4_1_HIGH) begin
                // 4:1 zone: push toward nearest attractor
                // Center at n=2.881, attractors at n=2.6 (7/2) and n=3.12 (9/2)
                // Push down toward n=2.6
                force_harmonic[i] <= -K_CATASTROPHE_4_1;
                near_4_1_reg[i] <= 1'b1;
            end else begin
                force_harmonic[i] <= 18'sd0;
                near_2_1_reg[i] <= 1'b0;
                near_3_1_reg[i] <= 1'b0;
                near_4_1_reg[i] <= 1'b0;
            end

            //=================================================================
            // 3. Rational resonance forces (Lorentzian gradient)
            // F_rational = Σ -2B × d / (d² + ε²)²
            // This creates smooth repulsion from all p/q rationals
            //=================================================================
            f_rat_accum = 18'sd0;
            for (r = 0; r < NUM_RATIONALS; r = r + 1) begin
                // Distance to this rational (in n-space)
                dist = n_effective[i] - n_rat[r];

                // Skip if distance > 0.5 (force negligible at far distances)
                // 0.5 in Q14 = 8192
                if (dist > -18'sd8192 && dist < 18'sd8192) begin
                    // d² (Q28 from Q14 × Q14)
                    dist_sq = dist * dist;

                    // d² + ε² (still Q28, ε² is Q14 so shift it left)
                    denom = dist_sq + (EPSILON_SQ <<< FRAC);

                    // For division, we need to avoid very small denominators
                    // Approximate: F ≈ -2B × d / denom (ignoring ²)
                    // This is simpler and still repels from rationals

                    // Numerator: -2 × B × d (Q28 from Q14 × Q14)
                    f_num = -(b_rat[r] * dist) <<< 1;

                    // Division: shift numerator up, divide by denom, normalize
                    // F = f_num / denom → needs to be Q14 result
                    // f_num is Q28, denom is Q28, result would be Q0
                    // So shift f_num by 14 before division to get Q14 result
                    if (denom > 36'sd100) begin  // Avoid divide by zero
                        f_rat_single = (f_num <<< FRAC) / denom;
                        // Clamp to prevent overflow
                        if (f_rat_single > 18'sd8192) f_rat_single = 18'sd8192;
                        if (f_rat_single < -18'sd8192) f_rat_single = -18'sd8192;
                        f_rat_accum = f_rat_accum + f_rat_single[WIDTH-1:0];
                    end
                end
            end
            force_rational[i] <= f_rat_accum;

            //=================================================================
            // 4. Total force = φ-landscape + catastrophe + rational
            //=================================================================
            force_total[i] <= force_phi[i] + force_harmonic[i] + force_rational[i];

            //=================================================================
            // 5. Energy for monitoring: E ≈ sin²(2πn)
            //=================================================================
            energy_product = sin_val[i] * sin_val[i];
            energy[i] <= energy_product >>> FRAC;
        end
    end
end

//-----------------------------------------------------------------------------
// Pack outputs
//-----------------------------------------------------------------------------
generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : pack_outputs
        assign force_packed[g*WIDTH +: WIDTH] = ENABLE_ADAPTIVE ? force_total[g] : 18'sd0;
        assign energy_packed[g*WIDTH +: WIDTH] = ENABLE_ADAPTIVE ? energy[g] : 18'sd0;
    end
endgenerate

assign near_harmonic_2_1 = ENABLE_ADAPTIVE ? near_2_1_reg : 0;
assign near_harmonic_3_1 = ENABLE_ADAPTIVE ? near_3_1_reg : 0;
assign near_harmonic_4_1 = ENABLE_ADAPTIVE ? near_4_1_reg : 0;

endmodule
