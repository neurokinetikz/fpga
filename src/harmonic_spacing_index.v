//=============================================================================
// Harmonic Spacing Index - v1.0
//
// Measures deviation from ideal φⁿ frequency ratios.
//
// HSI = 1.0 when all frequency ratios exactly match golden ratio
// HSI = 0.0 when ratios deviate by 0.5 or more from φ
//
// Key Ratios Monitored:
//   r1 = alpha / theta     (ideal: φ^1.0 = 1.618)
//   r2 = beta1 / alpha     (ideal: φ^1.0 = 1.618)
//   r3 = beta2 / beta1     (ideal: φ^1.0 = 1.618)
//   r4 = gamma / beta2     (ideal: varies)
//
// Algorithm:
//   1. Compute frequency ratios from omega_dt values
//   2. Deviation = |ratio - φ|
//   3. HSI = 1.0 - clamp(mean_deviation / 0.5, 0, 1)
//   4. ΔHSI = HSI - baseline (EMA)
//
// Uses:
//   - Positive ΔHSI → system tightening toward φⁿ attractors
//   - Negative ΔHSI → system loosening from ideal ratios
//   - harmonic_locked flag when all ratios within 5% of φ
//
// v1.0: Initial implementation using omega_dt inputs
//=============================================================================
`timescale 1ns / 1ps

module harmonic_spacing_index #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter AVG_SHIFT = 8  // Baseline EMA: α = 1/256 (~64s time constant at 4kHz)
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Frequency parameters (omega_dt values, scaled)
    input  wire signed [WIDTH-1:0] omega_theta,   // ~152 for 5.89 Hz
    input  wire signed [WIDTH-1:0] omega_alpha,   // ~245 for 9.53 Hz
    input  wire signed [WIDTH-1:0] omega_beta1,   // ~397 for 15.42 Hz
    input  wire signed [WIDTH-1:0] omega_beta2,   // ~642 for 24.94 Hz
    input  wire signed [WIDTH-1:0] omega_gamma,   // ~1040 for 40.36 Hz

    // Outputs
    output reg signed [WIDTH-1:0] hsi,            // [0, 1.0] Q14
    output reg signed [WIDTH-1:0] delta_hsi,      // HSI - baseline
    output reg harmonic_locked                    // All ratios within 5% of φ
);

// Constants in Q14
localparam signed [WIDTH-1:0] PHI = 18'sd26510;           // φ = 1.618
localparam signed [WIDTH-1:0] ONE = 18'sd16384;           // 1.0
localparam signed [WIDTH-1:0] HALF = 18'sd8192;           // 0.5
localparam signed [WIDTH-1:0] TOLERANCE = 18'sd1311;      // 0.08 (8% tolerance for lock)
localparam signed [WIDTH-1:0] MAX_DEV = 18'sd8192;        // 0.5 max deviation for normalization
localparam signed [WIDTH-1:0] MIN_OMEGA = 18'sd10;        // Minimum frequency to avoid div by zero

// Number of ratios to compute
localparam N_RATIOS = 4;

//-----------------------------------------------------------------------------
// Ratio computation (combinational)
// ratio = omega_high / omega_low, result in Q14
//-----------------------------------------------------------------------------
function signed [WIDTH-1:0] compute_ratio;
    input signed [WIDTH-1:0] omega_high;
    input signed [WIDTH-1:0] omega_low;
    reg signed [WIDTH-1:0] safe_low;
    reg signed [2*WIDTH-1:0] scaled;
    begin
        safe_low = (omega_low < MIN_OMEGA) ? MIN_OMEGA : omega_low;
        scaled = (omega_high <<< FRAC);
        compute_ratio = scaled / safe_low;
    end
endfunction

//-----------------------------------------------------------------------------
// Absolute value
//-----------------------------------------------------------------------------
function signed [WIDTH-1:0] abs_val;
    input signed [WIDTH-1:0] val;
    begin
        abs_val = (val[WIDTH-1]) ? -val : val;
    end
endfunction

//-----------------------------------------------------------------------------
// Compute ratios (combinational)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] ratio1 = compute_ratio(omega_alpha, omega_theta);   // α/θ
wire signed [WIDTH-1:0] ratio2 = compute_ratio(omega_beta1, omega_alpha);   // β₁/α
wire signed [WIDTH-1:0] ratio3 = compute_ratio(omega_beta2, omega_beta1);   // β₂/β₁
wire signed [WIDTH-1:0] ratio4 = compute_ratio(omega_gamma, omega_beta2);   // γ/β₂

//-----------------------------------------------------------------------------
// Compute deviations from φ (combinational)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] dev1 = abs_val(ratio1 - PHI);
wire signed [WIDTH-1:0] dev2 = abs_val(ratio2 - PHI);
wire signed [WIDTH-1:0] dev3 = abs_val(ratio3 - PHI);
wire signed [WIDTH-1:0] dev4 = abs_val(ratio4 - PHI);

//-----------------------------------------------------------------------------
// Mean deviation (sum / 4 = sum >>> 2)
//-----------------------------------------------------------------------------
wire signed [WIDTH+1:0] dev_sum = dev1 + dev2 + dev3 + dev4;
wire signed [WIDTH-1:0] mean_dev = dev_sum >>> 2;

//-----------------------------------------------------------------------------
// HSI = 1.0 - clamp(mean_dev / 0.5, 0, 1)
// Normalize: (mean_dev * 2) gives fraction of 0.5
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] normalized_dev = (mean_dev > MAX_DEV) ? ONE : (mean_dev <<< 1);
wire signed [WIDTH-1:0] hsi_instant = ONE - normalized_dev;
wire signed [WIDTH-1:0] hsi_clamped = (hsi_instant < 0) ? 18'sd0 : hsi_instant;

//-----------------------------------------------------------------------------
// Check if all ratios are within tolerance of φ (harmonic lock)
//-----------------------------------------------------------------------------
wire locked1 = (dev1 < TOLERANCE);
wire locked2 = (dev2 < TOLERANCE);
wire locked3 = (dev3 < TOLERANCE);
wire locked4 = (dev4 < TOLERANCE);
wire all_locked = locked1 && locked2 && locked3 && locked4;

//-----------------------------------------------------------------------------
// Baseline HSI (exponential moving average)
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] baseline_hsi;
wire signed [WIDTH-1:0] diff = hsi_clamped - baseline_hsi;
wire signed [WIDTH-1:0] delta = diff >>> AVG_SHIFT;

//-----------------------------------------------------------------------------
// Registered outputs
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        hsi <= ONE;                 // Start assuming perfect tuning
        baseline_hsi <= ONE;
        delta_hsi <= 18'sd0;
        harmonic_locked <= 1'b0;
    end else if (clk_en) begin
        // Update HSI
        hsi <= hsi_clamped;

        // Update baseline (slow EMA)
        baseline_hsi <= baseline_hsi + delta;

        // Compute delta (current - baseline)
        delta_hsi <= hsi_clamped - baseline_hsi;

        // Harmonic lock flag
        harmonic_locked <= all_locked;
    end
end

endmodule
