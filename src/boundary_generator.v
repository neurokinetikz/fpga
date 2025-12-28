//=============================================================================
// Boundary Generator - v1.0
//
// Generates boundary frequency oscillations via nonlinear mixing of adjacent
// attractor oscillators. Boundary frequencies emerge at geometric means:
//
//   f_boundary = sqrt(f_low × f_high)
//
// Empirical boundaries (from SIE dynamics analysis):
//   θ/α boundary: sqrt(5.89 × 9.53) = 7.49 Hz
//   α/β₁ boundary: sqrt(9.53 × 15.42) = 12.12 Hz
//   β₁/β₂ boundary: sqrt(15.42 × 24.94) = 19.60 Hz
//
// The boundary amplitude scales with mixing_strength and geometric mean of
// parent oscillator amplitudes. Phase is averaged from parent phases.
//
// Used for:
//   - SIE transition detection (boundary power increases during ignition)
//   - State boundary identification (between stable φⁿ attractors)
//   - Cross-frequency interaction measurement
//
// v1.0: Initial implementation with amplitude product mixing
//=============================================================================
`timescale 1ns / 1ps

module boundary_generator #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Lower attractor oscillator (x, y coordinates)
    input  wire signed [WIDTH-1:0] osc_low_x,
    input  wire signed [WIDTH-1:0] osc_low_y,

    // Upper attractor oscillator (x, y coordinates)
    input  wire signed [WIDTH-1:0] osc_high_x,
    input  wire signed [WIDTH-1:0] osc_high_y,

    // Mixing control
    input  wire signed [WIDTH-1:0] mixing_strength,  // Q14: 0 = no mixing, 1.0 = full

    // Outputs
    output reg signed [WIDTH-1:0] boundary_x,        // Boundary oscillator x
    output reg signed [WIDTH-1:0] boundary_y,        // Boundary oscillator y
    output reg signed [WIDTH-1:0] boundary_amplitude // Boundary amplitude
);

// Constants
localparam signed [WIDTH-1:0] MIN_AMP = 18'sd164;  // 0.01 in Q14 (avoid div by zero)

//-----------------------------------------------------------------------------
// Amplitude computation (combinational)
// |z| = sqrt(x² + y²), approximated as max(|x|,|y|) + 0.4×min(|x|,|y|)
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
        // 0.4 ≈ 6554/16384
        min_scaled = min_val * 18'sd6554;
        approx_amplitude = max_val + (min_scaled >>> FRAC);
    end
endfunction

//-----------------------------------------------------------------------------
// Square root approximation (Newton-Raphson, 3 iterations)
//-----------------------------------------------------------------------------
function signed [WIDTH-1:0] approx_sqrt;
    input signed [WIDTH-1:0] val;
    reg signed [WIDTH-1:0] x, x_new;
    reg signed [2*WIDTH-1:0] val_over_x;
    begin
        if (val <= 0) begin
            approx_sqrt = 0;
        end else begin
            x = (val >>> 1);
            if (x == 0) x = 18'sd1;

            // Newton iteration 1
            val_over_x = (val <<< FRAC) / x;
            x_new = (x + val_over_x[WIDTH-1:0]) >>> 1;

            // Newton iteration 2
            if (x_new != 0) begin
                val_over_x = (val <<< FRAC) / x_new;
                x_new = (x_new + val_over_x[WIDTH-1:0]) >>> 1;
            end

            // Newton iteration 3
            if (x_new != 0) begin
                val_over_x = (val <<< FRAC) / x_new;
                x_new = (x_new + val_over_x[WIDTH-1:0]) >>> 1;
            end

            approx_sqrt = x_new;
        end
    end
endfunction

//-----------------------------------------------------------------------------
// Combinational amplitude computation
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] amp_low = approx_amplitude(osc_low_x, osc_low_y);
wire signed [WIDTH-1:0] amp_high = approx_amplitude(osc_high_x, osc_high_y);

//-----------------------------------------------------------------------------
// Geometric mean of amplitudes: sqrt(amp_low × amp_high)
// This is the natural amplitude for the boundary frequency
//-----------------------------------------------------------------------------
wire signed [2*WIDTH-1:0] amp_product = amp_low * amp_high;
wire signed [WIDTH-1:0] amp_product_scaled = amp_product >>> FRAC;
wire signed [WIDTH-1:0] amp_geom_mean = approx_sqrt(amp_product_scaled);

//-----------------------------------------------------------------------------
// Phase averaging: (phase_low + phase_high) / 2
// Rather than computing atan2 and averaging, we average the unit vectors
// This gives correct phase averaging on the circle
//
// norm_low = (x_low, y_low) / |z_low|
// norm_high = (x_high, y_high) / |z_high|
// avg = (norm_low + norm_high) / 2
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

// Normalized unit vectors
wire signed [WIDTH-1:0] norm_low_x = normalize(osc_low_x, amp_low);
wire signed [WIDTH-1:0] norm_low_y = normalize(osc_low_y, amp_low);
wire signed [WIDTH-1:0] norm_high_x = normalize(osc_high_x, amp_high);
wire signed [WIDTH-1:0] norm_high_y = normalize(osc_high_y, amp_high);

// Average phase direction (sum of unit vectors, then normalize)
wire signed [WIDTH:0] sum_x = norm_low_x + norm_high_x;  // Extra bit for sum
wire signed [WIDTH:0] sum_y = norm_low_y + norm_high_y;

// Amplitude of average: this tells us how aligned the oscillators are
// If perfectly aligned: amp_avg = 2, if anti-phase: amp_avg = 0
wire signed [WIDTH-1:0] sum_x_scaled = sum_x >>> 1;  // Back to WIDTH bits
wire signed [WIDTH-1:0] sum_y_scaled = sum_y >>> 1;
wire signed [WIDTH-1:0] amp_avg = approx_amplitude(sum_x_scaled, sum_y_scaled);

// Normalize the average to get boundary direction
wire signed [WIDTH-1:0] dir_x = normalize(sum_x_scaled, amp_avg);
wire signed [WIDTH-1:0] dir_y = normalize(sum_y_scaled, amp_avg);

//-----------------------------------------------------------------------------
// Boundary output computation
// boundary = mixing_strength × amp_geom_mean × amp_alignment × direction
//
// amp_alignment (from amp_avg) scales with how aligned the parents are:
// - Aligned phases → strong boundary
// - Anti-phase → weak boundary (natural suppression)
//-----------------------------------------------------------------------------
wire signed [2*WIDTH-1:0] mix_amp_full = amp_geom_mean * mixing_strength;
wire signed [WIDTH-1:0] mix_amp = mix_amp_full >>> FRAC;

// Scale by alignment (amp_avg is already ~1.0 for aligned, ~0 for anti-phase)
wire signed [2*WIDTH-1:0] final_amp_full = mix_amp * amp_avg;
wire signed [WIDTH-1:0] final_amp = final_amp_full >>> FRAC;

// Apply to direction
wire signed [2*WIDTH-1:0] out_x_full = final_amp * dir_x;
wire signed [2*WIDTH-1:0] out_y_full = final_amp * dir_y;
wire signed [WIDTH-1:0] out_x = out_x_full >>> FRAC;
wire signed [WIDTH-1:0] out_y = out_y_full >>> FRAC;

//-----------------------------------------------------------------------------
// Registered outputs
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        boundary_x <= 18'sd0;
        boundary_y <= 18'sd0;
        boundary_amplitude <= 18'sd0;
    end else if (clk_en) begin
        boundary_x <= out_x;
        boundary_y <= out_y;
        boundary_amplitude <= final_amp;
    end
end

endmodule
