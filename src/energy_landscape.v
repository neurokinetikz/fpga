//=============================================================================
// Energy Landscape Module - v11.2
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
//    - v11.2: Ratio-based detection using actual omega values
//    - Detects proximity to 2:1, 3:2, 3:1, 4:3, 5:4 ratios
//    - Proximity-based repulsion (stronger near center)
//
// 3. Rational Resonance Force: F_rational(n) = Σ -2B_i × d / (d² + ε²)²
//    - Lorentzian gradient pushes oscillators AWAY from p/q ratios
//    - v11.2: Extended to q≤5 (24 rationals)
//
// 4. Escape Mechanism (v11.2):
//    - When in catastrophe zone, computes escape direction
//    - Outputs omega_correction to push toward nearest φⁿ attractor
//
// v11.0: Initial implementation with quarter-wave sine LUT
// v11.1b: Added rational resonance forces with Lorentzian gradient
// v11.2: Ratio-based catastrophe detection, dynamic escape, extended Farey
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
    input  wire signed [NUM_OSCILLATORS*WIDTH-1:0] n_packed,

    // Current frequency drift for each oscillator
    input  wire signed [NUM_OSCILLATORS*WIDTH-1:0] drift_packed,

    // v11.2: Omega values for ratio-based detection
    input  wire signed [NUM_OSCILLATORS*WIDTH-1:0] omega_dt_packed,
    input  wire signed [WIDTH-1:0] omega_dt_reference,

    // Force output for each oscillator (Q14 format)
    output wire signed [NUM_OSCILLATORS*WIDTH-1:0] force_packed,

    // v11.2: Omega correction for escape mechanism
    output wire signed [NUM_OSCILLATORS*WIDTH-1:0] omega_correction_packed,

    // Per-oscillator outputs
    output wire signed [NUM_OSCILLATORS*WIDTH-1:0] energy_packed,

    // Harmonic catastrophe flags
    output wire [NUM_OSCILLATORS-1:0] near_harmonic_2_1,
    output wire [NUM_OSCILLATORS-1:0] near_harmonic_3_1,
    output wire [NUM_OSCILLATORS-1:0] near_harmonic_4_1,
    // v11.2: Additional danger flags
    output wire [NUM_OSCILLATORS-1:0] near_harmonic_3_2,
    output wire [NUM_OSCILLATORS-1:0] near_harmonic_5_4
);

//-----------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] ONE_Q14 = 18'sd16384;
localparam signed [WIDTH-1:0] TWO_PI_A = 18'sd10294;  // 2π × 0.1 × 16384

//-----------------------------------------------------------------------------
// v11.2: Ratio-Based Catastrophe Parameters
// DANGER_MARGIN = 0.05 (5% from exact ratio triggers detection)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] DANGER_MARGIN = 18'sd819;    // 0.05

// Target ratios in Q14 format
localparam signed [WIDTH-1:0] RATIO_2_1 = 18'sd32768;      // 2.0
localparam signed [WIDTH-1:0] RATIO_3_2 = 18'sd24576;      // 1.5
localparam signed [WIDTH-1:0] RATIO_3_1 = 18'sd49152;      // 3.0
localparam signed [WIDTH-1:0] RATIO_4_3 = 18'sd21845;      // 1.333
localparam signed [WIDTH-1:0] RATIO_5_4 = 18'sd20480;      // 1.25

// Escape targets (φⁿ attractors in Q14)
localparam signed [WIDTH-1:0] RATIO_PHI_0_5 = 18'sd20833;  // φ^0.5 = 1.272
localparam signed [WIDTH-1:0] RATIO_PHI_1_0 = 18'sd26510;  // φ^1.0 = 1.618
localparam signed [WIDTH-1:0] RATIO_PHI_1_25 = 18'sd29901; // φ^1.25 = 1.825
localparam signed [WIDTH-1:0] RATIO_PHI_2_0 = 18'sd42891;  // φ^2.0 = 2.618
localparam signed [WIDTH-1:0] RATIO_PHI_2_5 = 18'sd54569;  // φ^2.5 = 3.330

// Escape force gain
localparam signed [WIDTH-1:0] K_ESCAPE = 18'sd1638;  // 0.1

//-----------------------------------------------------------------------------
// Legacy n-based Catastrophe Parameters (backward compatibility)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] N_2_1_LOW = 18'sd22118;
localparam signed [WIDTH-1:0] N_2_1_HIGH = 18'sd25395;
localparam signed [WIDTH-1:0] N_3_1_LOW = 18'sd36045;
localparam signed [WIDTH-1:0] N_3_1_HIGH = 18'sd38666;
localparam signed [WIDTH-1:0] N_4_1_LOW = 18'sd45875;
localparam signed [WIDTH-1:0] N_4_1_HIGH = 18'sd48497;

localparam signed [WIDTH-1:0] K_CATASTROPHE_2_1 = 18'sd12288;
localparam signed [WIDTH-1:0] K_CATASTROPHE_3_1 = 18'sd16384;
localparam signed [WIDTH-1:0] K_CATASTROPHE_4_1 = 18'sd12288;

//-----------------------------------------------------------------------------
// Rational Resonance Parameters (v11.2: extended to q≤5)
//-----------------------------------------------------------------------------
localparam NUM_RATIONALS = 24;  // Extended from 15

// q=1: integers (weight 0.05)
localparam signed [WIDTH-1:0] B_Q1 = 18'sd820;
// q=2: half-integers (weight 0.0125)
localparam signed [WIDTH-1:0] B_Q2 = 18'sd205;
// q=3: thirds (weight 0.0056)
localparam signed [WIDTH-1:0] B_Q3 = 18'sd91;
// q=4: quarters (weight 0.0031)
localparam signed [WIDTH-1:0] B_Q4 = 18'sd51;
// q=5: fifths (weight 0.002)
localparam signed [WIDTH-1:0] B_Q5 = 18'sd33;

localparam signed [WIDTH-1:0] EPSILON_SQ = 18'sd15;

//-----------------------------------------------------------------------------
// Unpack inputs
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] n_base [0:NUM_OSCILLATORS-1];
wire signed [WIDTH-1:0] drift [0:NUM_OSCILLATORS-1];
wire signed [WIDTH-1:0] omega_dt [0:NUM_OSCILLATORS-1];

genvar g;
generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : unpack_inputs
        assign n_base[g] = n_packed[g*WIDTH +: WIDTH];
        assign drift[g] = drift_packed[g*WIDTH +: WIDTH];
        assign omega_dt[g] = omega_dt_packed[g*WIDTH +: WIDTH];
    end
endgenerate

//-----------------------------------------------------------------------------
// Effective n computation
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] n_effective [0:NUM_OSCILLATORS-1];

generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : compute_n_eff
        wire signed [WIDTH-1:0] n_delta = drift[g] >>> 10;
        assign n_effective[g] = n_base[g] + n_delta;
    end
endgenerate

//-----------------------------------------------------------------------------
// v11.2: Ratio computation from omega values
//-----------------------------------------------------------------------------
wire signed [2*WIDTH-1:0] ratio_full [0:NUM_OSCILLATORS-1];
wire signed [WIDTH-1:0] ratio_to_ref [0:NUM_OSCILLATORS-1];

generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : compute_ratio
        // ratio = omega_dt[g] / omega_dt_reference (Q14 result)
        // Avoid division by zero
        wire signed [WIDTH-1:0] safe_ref = (omega_dt_reference == 0) ? ONE_Q14 : omega_dt_reference;
        assign ratio_full[g] = ({omega_dt[g], 14'b0}) / safe_ref;
        assign ratio_to_ref[g] = ratio_full[g][WIDTH-1:0];
    end
endgenerate

//-----------------------------------------------------------------------------
// Phase computation for sine LUT
//-----------------------------------------------------------------------------
wire [9:0] phase [0:NUM_OSCILLATORS-1];

generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : compute_phase
        assign phase[g] = n_effective[g][FRAC-1 -: 10];
    end
endgenerate

//-----------------------------------------------------------------------------
// Sine LUT instances
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
// Force computation registers
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] force_phi [0:NUM_OSCILLATORS-1];
reg signed [WIDTH-1:0] force_harmonic [0:NUM_OSCILLATORS-1];
reg signed [WIDTH-1:0] force_rational [0:NUM_OSCILLATORS-1];
reg signed [WIDTH-1:0] force_total [0:NUM_OSCILLATORS-1];
reg signed [WIDTH-1:0] energy [0:NUM_OSCILLATORS-1];

// v11.2: Omega correction for escape
reg signed [WIDTH-1:0] omega_correction [0:NUM_OSCILLATORS-1];

// Catastrophe zone flags
reg [NUM_OSCILLATORS-1:0] near_2_1_reg;
reg [NUM_OSCILLATORS-1:0] near_3_1_reg;
reg [NUM_OSCILLATORS-1:0] near_4_1_reg;
reg [NUM_OSCILLATORS-1:0] near_3_2_reg;
reg [NUM_OSCILLATORS-1:0] near_5_4_reg;

// Intermediate products
reg signed [2*WIDTH-1:0] force_product;
reg signed [2*WIDTH-1:0] energy_product;

// v11.2: Distance to dangerous ratios
reg signed [WIDTH-1:0] dist_2_1, dist_3_2, dist_3_1, dist_4_3, dist_5_4;
reg signed [WIDTH-1:0] min_dist;
reg [2:0] nearest_ratio;  // 0=2:1, 1=3:2, 2=3:1, 3=4:3, 4=5:4
reg in_danger;
reg signed [WIDTH-1:0] escape_dir;
reg signed [2*WIDTH-1:0] escape_product;

// Rational force computation variables
reg signed [WIDTH-1:0] n_rat [0:NUM_RATIONALS-1];
reg signed [WIDTH-1:0] b_rat [0:NUM_RATIONALS-1];
reg signed [WIDTH-1:0] dist;
reg signed [2*WIDTH-1:0] dist_sq;
reg signed [2*WIDTH-1:0] denom;
reg signed [2*WIDTH-1:0] f_num;
reg signed [2*WIDTH-1:0] f_rat_single;
reg signed [WIDTH-1:0] f_rat_accum;

integer i, r;

// Initialize rational position and weight arrays (v11.2: extended to q≤5)
initial begin
    // q=1: integers
    n_rat[0]  = 18'sd0;       b_rat[0]  = B_Q1;  // φⁿ=1, n=0
    n_rat[1]  = 18'sd23593;   b_rat[1]  = B_Q1;  // φⁿ=2, n=1.44
    n_rat[2]  = 18'sd37409;   b_rat[2]  = B_Q1;  // φⁿ=3, n=2.28
    n_rat[3]  = 18'sd47198;   b_rat[3]  = B_Q1;  // φⁿ=4, n=2.88
    n_rat[4]  = 18'sd54715;   b_rat[4]  = B_Q1;  // φⁿ=5, n=3.34
    // q=2: half-integers
    n_rat[5]  = 18'sd13768;   b_rat[5]  = B_Q2;  // φⁿ=1.5, n=0.84
    n_rat[6]  = 18'sd31115;   b_rat[6]  = B_Q2;  // φⁿ=2.5, n=1.90
    n_rat[7]  = 18'sd42563;   b_rat[7]  = B_Q2;  // φⁿ=3.5, n=2.60
    n_rat[8]  = 18'sd51130;   b_rat[8]  = B_Q2;  // φⁿ=4.5, n=3.12
    // q=3: thirds
    n_rat[9]  = 18'sd9787;    b_rat[9]  = B_Q3;  // φⁿ=1.333, n=0.60
    n_rat[10] = 18'sd17352;   b_rat[10] = B_Q3;  // φⁿ=1.667, n=1.06
    n_rat[11] = 18'sd28741;   b_rat[11] = B_Q3;  // φⁿ=2.333, n=1.76
    n_rat[12] = 18'sd32986;   b_rat[12] = B_Q3;  // φⁿ=2.667, n=2.01
    n_rat[13] = 18'sd39980;   b_rat[13] = B_Q3;  // φⁿ=3.333, n=2.44
    n_rat[14] = 18'sd41986;   b_rat[14] = B_Q3;  // φⁿ=3.667, n=2.56
    // q=4: quarters (v11.2)
    n_rat[15] = 18'sd7581;    b_rat[15] = B_Q4;  // φⁿ=1.25, n=0.46
    n_rat[16] = 18'sd19010;   b_rat[16] = B_Q4;  // φⁿ=1.75, n=1.16
    n_rat[17] = 18'sd27574;   b_rat[17] = B_Q4;  // φⁿ=2.25, n=1.68
    n_rat[18] = 18'sd34645;   b_rat[18] = B_Q4;  // φⁿ=2.75, n=2.11
    // q=5: fifths (v11.2)
    n_rat[19] = 18'sd6193;    b_rat[19] = B_Q5;  // φⁿ=1.2, n=0.38
    n_rat[20] = 18'sd11437;   b_rat[20] = B_Q5;  // φⁿ=1.4, n=0.70
    n_rat[21] = 18'sd16352;   b_rat[21] = B_Q5;  // φⁿ=1.6, n=1.00
    n_rat[22] = 18'sd21005;   b_rat[22] = B_Q5;  // φⁿ=1.8, n=1.28
    n_rat[23] = 18'sd25426;   b_rat[23] = B_Q5;  // φⁿ=2.0 approx, n=1.55
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < NUM_OSCILLATORS; i = i + 1) begin
            force_phi[i] <= 18'sd0;
            force_harmonic[i] <= 18'sd0;
            force_rational[i] <= 18'sd0;
            force_total[i] <= 18'sd0;
            energy[i] <= 18'sd0;
            omega_correction[i] <= 18'sd0;
        end
        near_2_1_reg <= 0;
        near_3_1_reg <= 0;
        near_4_1_reg <= 0;
        near_3_2_reg <= 0;
        near_5_4_reg <= 0;
    end else if (clk_en && ENABLE_ADAPTIVE) begin
        for (i = 0; i < NUM_OSCILLATORS; i = i + 1) begin
            //=================================================================
            // 1. φⁿ landscape force: F = +2πA × sin(2πn)
            //=================================================================
            force_product = TWO_PI_A * sin_val[i];
            force_phi[i] <= force_product >>> FRAC;

            //=================================================================
            // 2. v11.2: Ratio-based catastrophe detection
            // Compute distance to each dangerous ratio
            //=================================================================
            // Absolute distance to 2:1
            dist_2_1 = ratio_to_ref[i] - RATIO_2_1;
            if (dist_2_1 < 0) dist_2_1 = -dist_2_1;

            // Absolute distance to 3:2
            dist_3_2 = ratio_to_ref[i] - RATIO_3_2;
            if (dist_3_2 < 0) dist_3_2 = -dist_3_2;

            // Absolute distance to 3:1
            dist_3_1 = ratio_to_ref[i] - RATIO_3_1;
            if (dist_3_1 < 0) dist_3_1 = -dist_3_1;

            // Absolute distance to 4:3
            dist_4_3 = ratio_to_ref[i] - RATIO_4_3;
            if (dist_4_3 < 0) dist_4_3 = -dist_4_3;

            // Absolute distance to 5:4
            dist_5_4 = ratio_to_ref[i] - RATIO_5_4;
            if (dist_5_4 < 0) dist_5_4 = -dist_5_4;

            // Find minimum distance and set danger flags
            min_dist = dist_2_1;
            nearest_ratio = 3'd0;

            if (dist_3_2 < min_dist) begin
                min_dist = dist_3_2;
                nearest_ratio = 3'd1;
            end
            if (dist_3_1 < min_dist) begin
                min_dist = dist_3_1;
                nearest_ratio = 3'd2;
            end
            if (dist_4_3 < min_dist) begin
                min_dist = dist_4_3;
                nearest_ratio = 3'd3;
            end
            if (dist_5_4 < min_dist) begin
                min_dist = dist_5_4;
                nearest_ratio = 3'd4;
            end

            // Check if in danger zone
            in_danger = (min_dist < DANGER_MARGIN);

            // Set per-ratio flags
            near_2_1_reg[i] <= (dist_2_1 < DANGER_MARGIN);
            near_3_1_reg[i] <= (dist_3_1 < DANGER_MARGIN);
            near_4_1_reg[i] <= (n_effective[i] >= N_4_1_LOW && n_effective[i] <= N_4_1_HIGH);  // Use n-based for 4:1
            near_3_2_reg[i] <= (dist_3_2 < DANGER_MARGIN);
            near_5_4_reg[i] <= (dist_5_4 < DANGER_MARGIN);

            //=================================================================
            // 2b. Compute harmonic repulsion force
            // Proximity-based: stronger when closer to center
            //=================================================================
            if (in_danger) begin
                // Force proportional to (DANGER_MARGIN - distance)
                force_harmonic[i] <= -(K_CATASTROPHE_2_1 * (DANGER_MARGIN - min_dist)) >>> FRAC;
            end else begin
                force_harmonic[i] <= 18'sd0;
            end

            //=================================================================
            // 2c. v11.2: Escape mechanism
            // Compute escape direction toward nearest φⁿ attractor
            //=================================================================
            if (in_danger) begin
                case (nearest_ratio)
                    3'd0: begin  // Near 2:1 (2.0)
                        // Escape to φ^1.25 (1.825) if below, φ^2.0 (2.618) if above
                        escape_dir = (ratio_to_ref[i] < RATIO_2_1) ? -ONE_Q14 : ONE_Q14;
                    end
                    3'd1: begin  // Near 3:2 (1.5)
                        // Escape to φ^0.5 (1.272) if below, φ^1.0 (1.618) if above
                        escape_dir = (ratio_to_ref[i] < RATIO_3_2) ? -ONE_Q14 : ONE_Q14;
                    end
                    3'd2: begin  // Near 3:1 (3.0)
                        // Escape to φ^2.0 (2.618) if below, φ^2.5 (3.330) if above
                        escape_dir = (ratio_to_ref[i] < RATIO_3_1) ? -ONE_Q14 : ONE_Q14;
                    end
                    3'd3: begin  // Near 4:3 (1.333)
                        // Escape to φ^0.5 (1.272) if below, φ^1.0 (1.618) if above
                        escape_dir = (ratio_to_ref[i] < RATIO_4_3) ? -ONE_Q14 : ONE_Q14;
                    end
                    3'd4: begin  // Near 5:4 (1.25)
                        // Escape to φ^0.5 (1.272) if above (push up toward phi)
                        escape_dir = ONE_Q14;
                    end
                    default: escape_dir = 18'sd0;
                endcase

                // omega_correction = (DANGER_MARGIN - distance) × K_ESCAPE × escape_dir
                escape_product = (DANGER_MARGIN - min_dist) * K_ESCAPE;
                escape_product = escape_product * escape_dir;
                omega_correction[i] <= escape_product >>> (2*FRAC);
            end else begin
                omega_correction[i] <= 18'sd0;
            end

            //=================================================================
            // 3. Rational resonance forces (Lorentzian gradient)
            //=================================================================
            f_rat_accum = 18'sd0;
            for (r = 0; r < NUM_RATIONALS; r = r + 1) begin
                dist = n_effective[i] - n_rat[r];
                if (dist > -18'sd8192 && dist < 18'sd8192) begin
                    dist_sq = dist * dist;
                    denom = dist_sq + (EPSILON_SQ <<< FRAC);
                    f_num = -(b_rat[r] * dist) <<< 1;
                    if (denom > 36'sd100) begin
                        f_rat_single = (f_num <<< FRAC) / denom;
                        if (f_rat_single > 18'sd8192) f_rat_single = 18'sd8192;
                        if (f_rat_single < -18'sd8192) f_rat_single = -18'sd8192;
                        f_rat_accum = f_rat_accum + f_rat_single[WIDTH-1:0];
                    end
                end
            end
            force_rational[i] <= f_rat_accum;

            //=================================================================
            // 4. Total force
            //=================================================================
            force_total[i] <= force_phi[i] + force_harmonic[i] + force_rational[i];

            //=================================================================
            // 5. Energy for monitoring
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
        assign omega_correction_packed[g*WIDTH +: WIDTH] = ENABLE_ADAPTIVE ? omega_correction[g] : 18'sd0;
    end
endgenerate

assign near_harmonic_2_1 = ENABLE_ADAPTIVE ? near_2_1_reg : 0;
assign near_harmonic_3_1 = ENABLE_ADAPTIVE ? near_3_1_reg : 0;
assign near_harmonic_4_1 = ENABLE_ADAPTIVE ? near_4_1_reg : 0;
assign near_harmonic_3_2 = ENABLE_ADAPTIVE ? near_3_2_reg : 0;
assign near_harmonic_5_4 = ENABLE_ADAPTIVE ? near_5_4_reg : 0;

endmodule
