//=============================================================================
// Energy Landscape Module - v11.0
//
// Computes restoring forces based on the φⁿ energy landscape.
// Energy: E(n) = +A × cos(2πn) where n is the exponent in φⁿ
// Force:  F(n) = -dE/dn = +2πA × sin(2πn)
//
// Key properties:
//   - MINIMA at half-integers (n = 0.5, 1.5, 2.5): these are ATTRACTORS
//   - MAXIMA at integers (n = 0, 1, 2): these are BOUNDARIES
//   - Positive force increases n, negative force decreases n
//   - Force pushes oscillators toward nearest half-integer attractor:
//     * n < 0.5: sin(2πn) > 0 → F > 0 → n increases toward 0.5
//     * n > 0.5: sin(2πn) < 0 → F < 0 → n decreases toward 0.5
//
// Also includes 2:1 harmonic catastrophe repulsion near φⁿ = 2.0 (n ≈ 1.44)
// This causes oscillators to retreat from n=1.5 to n=1.25 (quarter-integer)
//
// v11.0: Initial implementation with quarter-wave sine LUT
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
    output wire [NUM_OSCILLATORS-1:0] near_harmonic_2_1  // True if φⁿ close to 2.0
);

//-----------------------------------------------------------------------------
// Constants
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] ONE_Q14 = 18'sd16384;
localparam signed [WIDTH-1:0] TWO_PI_Q14 = 18'sd102944;  // 2π × 16384 (but overflows, use shift)

// Force amplitude A (0.1 for gentle correction)
// 2πA in Q14 = 2 × 3.14159 × 0.1 × 16384 = 10294
localparam signed [WIDTH-1:0] TWO_PI_A = 18'sd10294;

// Harmonic catastrophe parameters
// φ^1.44 ≈ 2.0, so danger zone is n ∈ [1.35, 1.55]
// In Q14: n=1.35 → 22118, n=1.55 → 25395
localparam signed [WIDTH-1:0] N_DANGER_LOW = 18'sd22118;   // n = 1.35
localparam signed [WIDTH-1:0] N_DANGER_HIGH = 18'sd25395;  // n = 1.55
localparam signed [WIDTH-1:0] N_CATASTROPHE = 18'sd23593;  // n = 1.44 (φⁿ = 2.0)

// Catastrophe repulsion strength (higher = stronger push away from 2:1)
// Must be strong enough to overcome phi-landscape force at n=1.44
// Phi force at n=1.44 ≈ +3788, so K > 3788 needed for net downward push
// Using 0.75 (12288) for decisive escape to quarter-integer n=1.25
localparam signed [WIDTH-1:0] K_CATASTROPHE = 18'sd12288;  // 0.75 in Q14

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
// Force computation: F = -2πA × sin(2πn)
// Also includes harmonic catastrophe repulsion
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] force_phi [0:NUM_OSCILLATORS-1];     // φⁿ landscape force
reg signed [WIDTH-1:0] force_harmonic [0:NUM_OSCILLATORS-1]; // 2:1 catastrophe force
reg signed [WIDTH-1:0] force_total [0:NUM_OSCILLATORS-1];   // Combined force
reg signed [WIDTH-1:0] energy [0:NUM_OSCILLATORS-1];
reg [NUM_OSCILLATORS-1:0] near_2_1_reg;

// Intermediate products for force computation (need 36 bits to avoid overflow)
// Multiplying two 18-bit Q14 values needs 36 bits before shifting back to 18-bit
reg signed [2*WIDTH-1:0] force_product;
reg signed [2*WIDTH-1:0] energy_product;

// Loop variable
integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < NUM_OSCILLATORS; i = i + 1) begin
            force_phi[i] <= 18'sd0;
            force_harmonic[i] <= 18'sd0;
            force_total[i] <= 18'sd0;
            energy[i] <= 18'sd0;
        end
        near_2_1_reg <= 0;
    end else if (clk_en && ENABLE_ADAPTIVE) begin
        for (i = 0; i < NUM_OSCILLATORS; i = i + 1) begin
            // φⁿ landscape force: F = +2πA × sin(2πn)
            // For E(n) = +A × cos(2πn): minima at half-integers (0.5, 1.5, ...)
            // Force F = -dE/dn = +2πA × sin(2πn)
            // - At n=0.3: sin(0.6π)>0 → F>0 → pushes UP toward 0.5 ✓
            // - At n=0.7: sin(1.4π)<0 → F<0 → pushes DOWN toward 0.5 ✓
            // sin_val is Q14, TWO_PI_A is Q14
            // Product is Q28 (needs 36 bits), shift by 14 to get Q14 result
            force_product = TWO_PI_A * sin_val[i];  // 36-bit intermediate
            force_phi[i] <= force_product >>> FRAC;  // Positive sign for attractors at half-integers

            // Harmonic catastrophe force (near n = 1.44 where φⁿ = 2.0)
            // Push AWAY from n = 1.44 toward lower n (n = 1.25)
            if (n_effective[i] >= N_DANGER_LOW && n_effective[i] <= N_DANGER_HIGH) begin
                // Within danger zone - apply repulsion
                // Force = -K × (n - 1.44) when n > 1.44 (push down)
                // Force = +K × (1.44 - n) when n < 1.44 (push down too, toward 1.25)
                // Actually, we always push toward n = 1.25 (away from 2:1)
                force_harmonic[i] <= -K_CATASTROPHE;  // Always push down
                near_2_1_reg[i] <= 1'b1;
            end else begin
                force_harmonic[i] <= 18'sd0;
                near_2_1_reg[i] <= 1'b0;
            end

            // Total force
            force_total[i] <= force_phi[i] + force_harmonic[i];

            // Energy for monitoring: E = -A × cos(2πn)
            // We don't have cos LUT, but can approximate: E ≈ A × (1 - 2×sin²(πn))
            // For now, just report sin² as proxy (higher = nearer boundary)
            energy_product = sin_val[i] * sin_val[i];  // 36-bit intermediate
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

endmodule
