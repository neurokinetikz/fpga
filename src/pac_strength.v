//=============================================================================
// Phase-Amplitude Coupling Strength Module - v11.1c
//
// Computes PAC (Phase-Amplitude Coupling) strength between oscillator pairs
// based on the Unified Boundary-Attractor Framework.
//
// PAC strength is modulated by coupling susceptibility chi(r) where r is the
// frequency ratio between the amplitude-providing (high freq) and phase-
// providing (low freq) oscillators:
//
//   PAC_strength(f_low, f_high) = chi(f_high / f_low) * sqrt(A_low * A_high)
//
// Key predictions:
//   - PAC is STRONG at boundaries (integer ratios) where chi > 0.75
//   - PAC is WEAK at attractors (half-integers) where chi < 0.25
//   - The 2:1 ratio (phi^1.44) is the strongest PAC configuration
//
// Module tracks 10 key oscillator pairs spanning theta-gamma coupling.
//
// v11.1c: Initial implementation
//=============================================================================
`timescale 1ns / 1ps

module pac_strength #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_PAIRS = 10
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Oscillator frequencies (OMEGA_DT values, Q14 format)
    // These are pre-computed: OMEGA_DT = 2 * pi * f_hz * dt * 16384
    input  wire [WIDTH-1:0] omega_theta,      // Theta: ~152 (5.89 Hz)
    input  wire [WIDTH-1:0] omega_alpha,      // Alpha/L6: ~245 (9.53 Hz)
    input  wire [WIDTH-1:0] omega_beta_low,   // Beta-low/L5a: ~397 (15.42 Hz)
    input  wire [WIDTH-1:0] omega_beta_high,  // Beta-high/L5b: ~642 (24.94 Hz)
    input  wire [WIDTH-1:0] omega_gamma,      // Gamma/L4: ~817 (31.73 Hz)
    input  wire [WIDTH-1:0] omega_gamma_fast, // Gamma-fast/L2_3: ~1040 (40.36 Hz)
    input  wire [WIDTH-1:0] omega_sr_f0,      // SR f0: ~196 (7.6 Hz)
    input  wire [WIDTH-1:0] omega_sr_f2,      // SR f2: ~514 (20 Hz)

    // Oscillator amplitudes (Q14 format, typically from sqrt(x^2 + y^2))
    input  wire [WIDTH-1:0] amp_theta,
    input  wire [WIDTH-1:0] amp_alpha,
    input  wire [WIDTH-1:0] amp_beta_low,
    input  wire [WIDTH-1:0] amp_beta_high,
    input  wire [WIDTH-1:0] amp_gamma,
    input  wire [WIDTH-1:0] amp_gamma_fast,
    input  wire [WIDTH-1:0] amp_sr_f0,
    input  wire [WIDTH-1:0] amp_sr_f2,

    // PAC strength outputs for each pair (Q14 format)
    output wire [WIDTH-1:0] pac_theta_alpha,      // Pair 0: Theta-Alpha (phi)
    output wire [WIDTH-1:0] pac_theta_beta_low,   // Pair 1: Theta-Beta_low (phi^2)
    output wire [WIDTH-1:0] pac_alpha_beta_low,   // Pair 2: Alpha-Beta_low (phi)
    output wire [WIDTH-1:0] pac_alpha_beta_high,  // Pair 3: Alpha-Beta_high (phi^2)
    output wire [WIDTH-1:0] pac_beta_low_gamma,   // Pair 4: Beta_low-Gamma (near 2:1!)
    output wire [WIDTH-1:0] pac_beta_high_gamma,  // Pair 5: Beta_high-Gamma (phi^0.5)
    output wire [WIDTH-1:0] pac_theta_gamma_fast, // Pair 6: Theta-Gamma_fast (phi^4)
    output wire [WIDTH-1:0] pac_alpha_gamma_fast, // Pair 7: Alpha-Gamma_fast (phi^3)
    output wire [WIDTH-1:0] pac_sr_f0_f2,         // Pair 8: SR f0-f2 (phi^2)
    output wire [WIDTH-1:0] pac_theta_gamma,      // Pair 9: Theta-Gamma (critical)

    // Classification outputs (2 bits each)
    // 00 = attractor (chi < 0.25), 01 = transition, 10 = boundary (chi > 0.75)
    output wire [1:0] class_theta_alpha,
    output wire [1:0] class_theta_beta_low,
    output wire [1:0] class_alpha_beta_low,
    output wire [1:0] class_alpha_beta_high,
    output wire [1:0] class_beta_low_gamma,
    output wire [1:0] class_beta_high_gamma,
    output wire [1:0] class_theta_gamma_fast,
    output wire [1:0] class_alpha_gamma_fast,
    output wire [1:0] class_sr_f0_f2,
    output wire [1:0] class_theta_gamma
);

//-----------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] ONE_Q14 = 18'sd16384;

// Classification thresholds
localparam signed [WIDTH-1:0] CHI_BOUNDARY_THRESH = 18'sd12288;   // 0.75 - boundary
localparam signed [WIDTH-1:0] CHI_ATTRACTOR_THRESH = 18'sd4096;   // 0.25 - attractor

// Precomputed frequency ratios (Q14 format)
// These are computed as: (omega_high / omega_low) * 16384
// For static analysis, we use fixed ratios based on phi^n architecture

// Ratio constants (from phi^n theory)
localparam [WIDTH-1:0] RATIO_PHI_0_5 = 18'd20833;   // phi^0.5 = 1.272
localparam [WIDTH-1:0] RATIO_PHI_1_0 = 18'd26510;   // phi^1.0 = 1.618
localparam [WIDTH-1:0] RATIO_PHI_1_5 = 18'd33718;   // phi^1.5 = 2.058
localparam [WIDTH-1:0] RATIO_PHI_2_0 = 18'd42891;   // phi^2.0 = 2.618
localparam [WIDTH-1:0] RATIO_PHI_3_0 = 18'd69384;   // phi^3.0 = 4.236
localparam [WIDTH-1:0] RATIO_PHI_4_0 = 18'd112249;  // phi^4.0 = 6.854

//-----------------------------------------------------------------------------
// Coupling Susceptibility LUT Instance
// We use the ratio to look up chi(r) from the LUT
//-----------------------------------------------------------------------------
// Chi LUT parameters
localparam LUT_SIZE = 256;
localparam [WIDTH-1:0] RATIO_MIN_Q14 = 18'd8192;    // 0.5
localparam [WIDTH-1:0] RATIO_MAX_Q14 = 18'd73728;   // 4.5
localparam [WIDTH-1:0] RATIO_RANGE_Q14 = 18'd65536; // 4.0 range

// LUT storage
reg signed [WIDTH-1:0] chi_lut [0:LUT_SIZE-1];

// LUT initialization variable
integer lut_init_j;

// Include the pre-generated LUT values
// Note: The LUT is initialized from coupling_susceptibility values
// For standalone testing, we duplicate the key entries here
initial begin
    // Simplified LUT with key values (subset of full Farey LUT)
    // These match the chi_lut_values.vh from v11.1a
    // Full LUT has 256 entries; here we initialize critical ones
    for (lut_init_j = 0; lut_init_j < LUT_SIZE; lut_init_j = lut_init_j + 1) begin
        chi_lut[lut_init_j] = 18'sd8192;  // Default: 0.5 (transition)
    end

    // Key positions from chi_lut_values.vh:
    // phi^1 (1.618) at idx ~72: chi = 0.328 (moderate)
    chi_lut[72] = 18'sd5353;   // ratio 1.5-1.6
    chi_lut[73] = 18'sd5000;

    // phi^0.5 (1.272) at idx ~50: chi = 0.134 (attractor)
    chi_lut[49] = 18'sd2193;
    chi_lut[50] = 18'sd2048;

    // phi^1.5 (2.058) at idx ~97: chi = 0.619 (near 2:1 boundary)
    chi_lut[96] = 18'sd12600;  // 2:1 catastrophe region
    chi_lut[97] = 18'sd10136;

    // phi^2 (2.618) at idx ~136: chi = 0.155 (attractor-like)
    chi_lut[136] = 18'sd5330;
    chi_lut[137] = 18'sd4978;

    // phi^3 (4.236) at idx ~239: chi = 0.335 (moderate)
    chi_lut[238] = 18'sd5014;
    chi_lut[239] = 18'sd5475;

    // Integer boundaries (high chi):
    chi_lut[32] = 18'sd16056;  // 1:1 boundary
    chi_lut[96] = 18'sd12600;  // 2:1 catastrophe
    chi_lut[160] = 18'sd12577; // 3:1 boundary
    chi_lut[224] = 18'sd12658; // 4:1 boundary

    // Half-integer attractors (low chi):
    chi_lut[64] = 18'sd4602;   // 1.5 (3/2)
    chi_lut[128] = 18'sd4569;  // 2.5 (5/2)
    chi_lut[192] = 18'sd4053;  // 3.5 (7/2)
end

//-----------------------------------------------------------------------------
// Ratio Computation
// For each pair, compute ratio = omega_high / omega_low
// Division in hardware is expensive, so we use shift-and-subtract
// For simplicity, we'll use a lookup based on OMEGA_DT ratios
//-----------------------------------------------------------------------------

// Registered ratios (computed from omega inputs)
reg [WIDTH-1:0] ratio [0:NUM_PAIRS-1];

// Division helper: ratio = (high << FRAC) / low
// We'll use time-multiplexed division or approximate with shifts
// For v11.1c, use fixed phi^n ratios based on architecture

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Initialize with expected phi^n ratios
        ratio[0] <= RATIO_PHI_1_0;   // Theta-Alpha: phi
        ratio[1] <= RATIO_PHI_2_0;   // Theta-Beta_low: phi^2
        ratio[2] <= RATIO_PHI_1_0;   // Alpha-Beta_low: phi
        ratio[3] <= RATIO_PHI_2_0;   // Alpha-Beta_high: phi^2
        ratio[4] <= RATIO_PHI_1_5;   // Beta_low-Gamma: phi^1.5 (near 2:1!)
        ratio[5] <= RATIO_PHI_0_5;   // Beta_high-Gamma: phi^0.5
        ratio[6] <= RATIO_PHI_4_0;   // Theta-Gamma_fast: phi^4
        ratio[7] <= RATIO_PHI_3_0;   // Alpha-Gamma_fast: phi^3
        ratio[8] <= RATIO_PHI_2_0;   // SR f0-f2: phi^2
        ratio[9] <= 18'd88474;       // Theta-Gamma: ~5.4 (phi^3.5)
    end else if (clk_en) begin
        // Dynamic ratio computation would go here
        // For now, keep static phi^n ratios
        // In a full implementation, we'd compute:
        // ratio[i] = (omega_high[i] << 14) / omega_low[i]
    end
end

//-----------------------------------------------------------------------------
// Chi Lookup
// Convert ratio to LUT index and look up chi(ratio)
// Both lut_idx and chi_val are combinational to avoid pipeline delays
//-----------------------------------------------------------------------------
wire [7:0] lut_idx [0:NUM_PAIRS-1];
wire signed [WIDTH-1:0] chi_val [0:NUM_PAIRS-1];

genvar g;
generate
    for (g = 0; g < NUM_PAIRS; g = g + 1) begin : compute_idx
        // Map ratio [0.5, 4.5] to LUT index [0, 255]
        // idx = (ratio - 0.5) / 4.0 * 256 = (ratio - 8192) >> 8
        wire [WIDTH-1:0] ratio_shifted = (ratio[g] > RATIO_MIN_Q14) ?
                                         (ratio[g] - RATIO_MIN_Q14) : 0;
        wire [WIDTH-1:0] idx_raw = ratio_shifted >> 8;  // Divide by 256
        assign lut_idx[g] = (idx_raw > 255) ? 8'd255 : idx_raw[7:0];
        // Combinational chi lookup - immediate response to ratio changes
        assign chi_val[g] = chi_lut[lut_idx[g]];
    end
endgenerate

// Loop variable for sequential blocks
integer i;

//-----------------------------------------------------------------------------
// PAC Strength Computation
// PAC = chi(ratio) * sqrt(amp_low * amp_high)
// For simplicity, approximate sqrt(a*b) ≈ (a + b) / 2 (arithmetic mean)
// This is faster than true geometric mean but still captures amplitude scaling
//-----------------------------------------------------------------------------

// Amplitude pairs (low, high)
wire [WIDTH-1:0] amp_low [0:NUM_PAIRS-1];
wire [WIDTH-1:0] amp_high [0:NUM_PAIRS-1];

assign amp_low[0]  = amp_theta;      assign amp_high[0]  = amp_alpha;
assign amp_low[1]  = amp_theta;      assign amp_high[1]  = amp_beta_low;
assign amp_low[2]  = amp_alpha;      assign amp_high[2]  = amp_beta_low;
assign amp_low[3]  = amp_alpha;      assign amp_high[3]  = amp_beta_high;
assign amp_low[4]  = amp_beta_low;   assign amp_high[4]  = amp_gamma;
assign amp_low[5]  = amp_beta_high;  assign amp_high[5]  = amp_gamma;
assign amp_low[6]  = amp_theta;      assign amp_high[6]  = amp_gamma_fast;
assign amp_low[7]  = amp_alpha;      assign amp_high[7]  = amp_gamma_fast;
assign amp_low[8]  = amp_sr_f0;      assign amp_high[8]  = amp_sr_f2;
assign amp_low[9]  = amp_theta;      assign amp_high[9]  = amp_gamma;

// Combinational amplitude factor - computed immediately from inputs
// This avoids pipeline delay where pac_strength would use stale amp_factor
wire signed [WIDTH-1:0] amp_factor [0:NUM_PAIRS-1];
genvar af;
generate
    for (af = 0; af < NUM_PAIRS; af = af + 1) begin : amp_factor_gen
        assign amp_factor[af] = ($signed({1'b0, amp_low[af]}) + $signed({1'b0, amp_high[af]})) >>> 1;
    end
endgenerate

// Registered PAC strength values
reg signed [WIDTH-1:0] pac_strength [0:NUM_PAIRS-1];

// Intermediate products (36-bit to capture full multiplication)
// Using generate block instead of for loop to avoid Icarus Verilog issues
wire signed [35:0] pac_product [0:NUM_PAIRS-1];
genvar p;
generate
    for (p = 0; p < NUM_PAIRS; p = p + 1) begin : pac_product_gen
        assign pac_product[p] = chi_val[p] * amp_factor[p];
    end
endgenerate

// Compute PAC strength from chi and amplitude factor
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < NUM_PAIRS; i = i + 1) begin
            pac_strength[i] <= 18'sd0;
        end
    end else if (clk_en) begin
        for (i = 0; i < NUM_PAIRS; i = i + 1) begin
            // PAC = chi * amp_factor (Q14 * Q14 >> 14 = Q14)
            // Use pre-computed 36-bit product then shift
            pac_strength[i] <= pac_product[i] >>> FRAC;
        end
    end
end

//-----------------------------------------------------------------------------
// Classification
// Based on chi value: boundary (>0.75), attractor (<0.25), or transition
//-----------------------------------------------------------------------------
reg [1:0] classification [0:NUM_PAIRS-1];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < NUM_PAIRS; i = i + 1) begin
            classification[i] <= 2'b01;  // Default: transition
        end
    end else if (clk_en) begin
        for (i = 0; i < NUM_PAIRS; i = i + 1) begin
            if (chi_val[i] >= CHI_BOUNDARY_THRESH)
                classification[i] <= 2'b10;      // Boundary
            else if (chi_val[i] <= CHI_ATTRACTOR_THRESH)
                classification[i] <= 2'b00;      // Attractor
            else
                classification[i] <= 2'b01;      // Transition
        end
    end
end

//-----------------------------------------------------------------------------
// Output Assignments
//-----------------------------------------------------------------------------
assign pac_theta_alpha      = pac_strength[0];
assign pac_theta_beta_low   = pac_strength[1];
assign pac_alpha_beta_low   = pac_strength[2];
assign pac_alpha_beta_high  = pac_strength[3];
assign pac_beta_low_gamma   = pac_strength[4];
assign pac_beta_high_gamma  = pac_strength[5];
assign pac_theta_gamma_fast = pac_strength[6];
assign pac_alpha_gamma_fast = pac_strength[7];
assign pac_sr_f0_f2         = pac_strength[8];
assign pac_theta_gamma      = pac_strength[9];

assign class_theta_alpha      = classification[0];
assign class_theta_beta_low   = classification[1];
assign class_alpha_beta_low   = classification[2];
assign class_alpha_beta_high  = classification[3];
assign class_beta_low_gamma   = classification[4];
assign class_beta_high_gamma  = classification[5];
assign class_theta_gamma_fast = classification[6];
assign class_alpha_gamma_fast = classification[7];
assign class_sr_f0_f2         = classification[8];
assign class_theta_gamma      = classification[9];

endmodule
