//=============================================================================
// Bicoherence Monitor - v1.0
//
// Detects nonlinear three-frequency interactions (f1, f2, f1+f2 triads).
// High bicoherence indicates active nonlinear coupling generating sum frequencies.
//
// Standard Bicoherence:
//   B(f1,f2) = |E[X(f1)×X(f2)×X*(f1+f2)]| / sqrt(P1×P2×P12)
//
// Simplified Hardware Implementation:
//   Uses phase angles from oscillator (x,y) states:
//   - θ_k = atan2(y_k, x_k) for each oscillator
//   - Bispectral phase: Φ = θ_1 + θ_2 - θ_12
//   - Bicoherence ≈ |cos(Φ)| averaged over time
//
// For φⁿ frequency triads:
//   - θ (5.89 Hz) + α (9.53 Hz) → boundary at 7.49 Hz (geometric mean)
//   - These should show high bicoherence during SIE ignition
//
// v1.0: Initial implementation with phase-based bispectrum
//=============================================================================
`timescale 1ns / 1ps

module bicoherence_monitor #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter AVG_SHIFT = 6  // IIR averaging: α = 1/64
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // First oscillator (f1)
    input  wire signed [WIDTH-1:0] osc1_x,
    input  wire signed [WIDTH-1:0] osc1_y,

    // Second oscillator (f2)
    input  wire signed [WIDTH-1:0] osc2_x,
    input  wire signed [WIDTH-1:0] osc2_y,

    // Third oscillator (f12 - related to f1+f2 or boundary frequency)
    input  wire signed [WIDTH-1:0] osc12_x,
    input  wire signed [WIDTH-1:0] osc12_y,

    // Outputs
    output reg signed [WIDTH-1:0] bicoherence,  // [0, 1.0] in Q14
    output reg high_bicoherence                 // Flag: bicoherence > 0.5
);

// Constants
localparam signed [WIDTH-1:0] ONE = 18'sd16384;           // 1.0 in Q14
localparam signed [WIDTH-1:0] HALF = 18'sd8192;           // 0.5 in Q14
localparam signed [WIDTH-1:0] BICOH_THRESH = 18'sd8192;   // 0.5 threshold
localparam signed [WIDTH-1:0] MIN_AMP = 18'sd164;         // 0.01 minimum

//-----------------------------------------------------------------------------
// Amplitude approximation (same as kuramoto_order_parameter)
//-----------------------------------------------------------------------------
function signed [WIDTH-1:0] approx_amplitude;
    input signed [WIDTH-1:0] x;
    input signed [WIDTH-1:0] y;
    reg signed [WIDTH-1:0] abs_x, abs_y, max_val, min_val;
    reg signed [2*WIDTH-1:0] min_scaled;
    begin
        abs_x = (x[WIDTH-1]) ? -x : x;
        abs_y = (y[WIDTH-1]) ? -y : y;
        max_val = (abs_x > abs_y) ? abs_x : abs_y;
        min_val = (abs_x > abs_y) ? abs_y : abs_x;
        min_scaled = min_val * 18'sd6554;  // 0.4
        approx_amplitude = max_val + (min_scaled >>> FRAC);
    end
endfunction

//-----------------------------------------------------------------------------
// Normalization to unit vector
//-----------------------------------------------------------------------------
function signed [WIDTH-1:0] normalize;
    input signed [WIDTH-1:0] val;
    input signed [WIDTH-1:0] amp;
    reg signed [2*WIDTH-1:0] scaled;
    reg signed [WIDTH-1:0] safe_amp;
    begin
        safe_amp = (amp < MIN_AMP) ? MIN_AMP : amp;
        scaled = (val <<< FRAC);
        normalize = scaled / safe_amp;
    end
endfunction

//-----------------------------------------------------------------------------
// Compute amplitudes
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] amp1 = approx_amplitude(osc1_x, osc1_y);
wire signed [WIDTH-1:0] amp2 = approx_amplitude(osc2_x, osc2_y);
wire signed [WIDTH-1:0] amp12 = approx_amplitude(osc12_x, osc12_y);

//-----------------------------------------------------------------------------
// Normalize to unit phasors
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] cos1 = normalize(osc1_x, amp1);
wire signed [WIDTH-1:0] sin1 = normalize(osc1_y, amp1);
wire signed [WIDTH-1:0] cos2 = normalize(osc2_x, amp2);
wire signed [WIDTH-1:0] sin2 = normalize(osc2_y, amp2);
wire signed [WIDTH-1:0] cos12 = normalize(osc12_x, amp12);
wire signed [WIDTH-1:0] sin12 = normalize(osc12_y, amp12);

//-----------------------------------------------------------------------------
// Bispectral phase computation
//
// For phase coupling, we compute:
//   exp(i×(θ1 + θ2 - θ12))
//
// Using complex arithmetic:
//   exp(i×θ1) × exp(i×θ2) × exp(-i×θ12)
//   = (cos1 + i×sin1) × (cos2 + i×sin2) × (cos12 - i×sin12)
//
// The real part of this product is our measure of phase alignment.
// When phases are coupled (θ1 + θ2 = θ12), the real part ≈ 1.
//-----------------------------------------------------------------------------

// First compute exp(i×θ1) × exp(i×θ2)
// = (cos1×cos2 - sin1×sin2) + i×(cos1×sin2 + sin1×cos2)
wire signed [2*WIDTH-1:0] prod12_real_full = cos1 * cos2 - sin1 * sin2;
wire signed [2*WIDTH-1:0] prod12_imag_full = cos1 * sin2 + sin1 * cos2;
wire signed [WIDTH-1:0] prod12_real = prod12_real_full >>> FRAC;
wire signed [WIDTH-1:0] prod12_imag = prod12_imag_full >>> FRAC;

// Now compute × exp(-i×θ12) = × (cos12 - i×sin12)
// Final = (prod12_real×cos12 + prod12_imag×sin12)
//       + i×(prod12_imag×cos12 - prod12_real×sin12)
wire signed [2*WIDTH-1:0] bispec_real_full = prod12_real * cos12 + prod12_imag * sin12;
wire signed [2*WIDTH-1:0] bispec_imag_full = prod12_imag * cos12 - prod12_real * sin12;
wire signed [WIDTH-1:0] bispec_real = bispec_real_full >>> FRAC;
wire signed [WIDTH-1:0] bispec_imag = bispec_imag_full >>> FRAC;

// Bicoherence magnitude = |bispec| = sqrt(real² + imag²)
// For normalized inputs, this is already [0, 1]
wire signed [WIDTH-1:0] bispec_amp = approx_amplitude(bispec_real, bispec_imag);

//-----------------------------------------------------------------------------
// IIR averaging for temporal smoothing
// avg_new = avg_old + (sample - avg_old) / 64
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] avg_bicoherence;

wire signed [WIDTH-1:0] diff = bispec_amp - avg_bicoherence;
wire signed [WIDTH-1:0] delta = diff >>> AVG_SHIFT;

//-----------------------------------------------------------------------------
// Registered outputs
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        avg_bicoherence <= 18'sd0;
        bicoherence <= 18'sd0;
        high_bicoherence <= 1'b0;
    end else if (clk_en) begin
        // Update IIR average
        avg_bicoherence <= avg_bicoherence + delta;

        // Output the smoothed bicoherence
        bicoherence <= avg_bicoherence;

        // Threshold flag
        high_bicoherence <= (avg_bicoherence > BICOH_THRESH);
    end
end

endmodule
