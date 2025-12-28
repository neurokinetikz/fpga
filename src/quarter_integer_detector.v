//=============================================================================
// Quarter-Integer Detector Module - v11.3
//
// Classifies oscillator positions in the φⁿ energy landscape:
//   - INTEGER_BOUNDARY: n ≈ 0, 1, 2, 3... (unstable, high χ)
//   - HALF_INTEGER: n ≈ 0.5, 1.5, 2.5... (stable attractors, low χ)
//   - QUARTER_INTEGER: n ≈ 0.25, 0.75, 1.25... (fallback positions)
//
// Also computes a stability metric based on:
//   - Distance from nearest attractor (half-integer)
//   - Fibonacci denominator growth rate approximation
//
// Special case: n ≈ 1.5 is flagged as NEAR_CATASTROPHE due to 2:1 harmonic
//
// v11.3: Initial implementation
//=============================================================================
`timescale 1ns / 1ps

module quarter_integer_detector #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_OSCILLATORS = 21
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Exponent n for each oscillator (Q14 format)
    input  wire signed [NUM_OSCILLATORS*WIDTH-1:0] n_packed,

    // Position classification (2 bits per oscillator)
    // 00 = INTEGER_BOUNDARY (unstable)
    // 01 = HALF_INTEGER (stable attractor)
    // 10 = QUARTER_INTEGER (fallback)
    // 11 = NEAR_CATASTROPHE (2:1 danger zone)
    output wire [NUM_OSCILLATORS*2-1:0] position_class_packed,

    // Stability metric per oscillator (Q14, 0=unstable, 1=fully stable)
    output wire signed [NUM_OSCILLATORS*WIDTH-1:0] stability_packed,

    // Individual flags
    output wire [NUM_OSCILLATORS-1:0] is_integer_boundary,
    output wire [NUM_OSCILLATORS-1:0] is_half_integer,
    output wire [NUM_OSCILLATORS-1:0] is_quarter_integer,
    output wire [NUM_OSCILLATORS-1:0] is_near_catastrophe
);

//-----------------------------------------------------------------------------
// Classification codes
//-----------------------------------------------------------------------------
localparam [1:0] CLASS_INTEGER_BOUNDARY = 2'b00;
localparam [1:0] CLASS_HALF_INTEGER = 2'b01;
localparam [1:0] CLASS_QUARTER_INTEGER = 2'b10;
localparam [1:0] CLASS_NEAR_CATASTROPHE = 2'b11;

//-----------------------------------------------------------------------------
// Threshold constants (Q14)
// Classifications based on fractional part of n:
//   - |frac| < 0.125 OR |frac - 1.0| < 0.125 → integer boundary
//   - |frac - 0.5| < 0.125 → half-integer
//   - |frac - 0.25| < 0.125 OR |frac - 0.75| < 0.125 → quarter-integer
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] THRESH_EIGHTH = 18'sd2048;   // 0.125 in Q14

// Fractional part reference points
localparam signed [WIDTH-1:0] FRAC_ZERO = 18'sd0;          // 0.0
localparam signed [WIDTH-1:0] FRAC_QUARTER = 18'sd4096;    // 0.25
localparam signed [WIDTH-1:0] FRAC_HALF = 18'sd8192;       // 0.5
localparam signed [WIDTH-1:0] FRAC_THREE_QUARTER = 18'sd12288; // 0.75
localparam signed [WIDTH-1:0] FRAC_ONE = 18'sd16384;       // 1.0

// 2:1 Catastrophe zone (n ≈ 1.44 where φⁿ = 2.0)
localparam signed [WIDTH-1:0] N_DANGER_LOW = 18'sd22118;   // n = 1.35
localparam signed [WIDTH-1:0] N_DANGER_HIGH = 18'sd25395;  // n = 1.55

//-----------------------------------------------------------------------------
// Unpack inputs
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] n_val [0:NUM_OSCILLATORS-1];

genvar g;
generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : unpack
        assign n_val[g] = n_packed[g*WIDTH +: WIDTH];
    end
endgenerate

//-----------------------------------------------------------------------------
// Classification and stability computation
//-----------------------------------------------------------------------------
reg [1:0] position_class [0:NUM_OSCILLATORS-1];
reg signed [WIDTH-1:0] stability [0:NUM_OSCILLATORS-1];
reg [NUM_OSCILLATORS-1:0] int_bound_reg;
reg [NUM_OSCILLATORS-1:0] half_int_reg;
reg [NUM_OSCILLATORS-1:0] quarter_int_reg;
reg [NUM_OSCILLATORS-1:0] catastrophe_reg;

// Temporary variables for computation
reg signed [WIDTH-1:0] frac_part;
reg signed [WIDTH-1:0] dist_zero;
reg signed [WIDTH-1:0] dist_quarter;
reg signed [WIDTH-1:0] dist_half;
reg signed [WIDTH-1:0] dist_three_quarter;
reg signed [WIDTH-1:0] dist_one;
reg signed [WIDTH-1:0] min_dist;
reg in_danger_zone;

integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < NUM_OSCILLATORS; i = i + 1) begin
            position_class[i] <= CLASS_INTEGER_BOUNDARY;
            stability[i] <= 18'sd0;
        end
        int_bound_reg <= 0;
        half_int_reg <= 0;
        quarter_int_reg <= 0;
        catastrophe_reg <= 0;
    end else if (clk_en) begin
        for (i = 0; i < NUM_OSCILLATORS; i = i + 1) begin
            // Extract fractional part of n (bits [13:0] for Q14)
            // Use modulo by masking lower 14 bits
            frac_part = {4'b0, n_val[i][FRAC-1:0]};  // Always positive

            // Check for catastrophe zone first (takes precedence)
            in_danger_zone = (n_val[i] >= N_DANGER_LOW) && (n_val[i] <= N_DANGER_HIGH);

            // Compute distances from each reference point
            dist_zero = (frac_part < 0) ? -frac_part : frac_part;

            dist_quarter = frac_part - FRAC_QUARTER;
            dist_quarter = (dist_quarter < 0) ? -dist_quarter : dist_quarter;

            dist_half = frac_part - FRAC_HALF;
            dist_half = (dist_half < 0) ? -dist_half : dist_half;

            dist_three_quarter = frac_part - FRAC_THREE_QUARTER;
            dist_three_quarter = (dist_three_quarter < 0) ? -dist_three_quarter : dist_three_quarter;

            dist_one = FRAC_ONE - frac_part;
            dist_one = (dist_one < 0) ? -dist_one : dist_one;

            // Classification logic
            if (in_danger_zone) begin
                // In 2:1 catastrophe zone
                position_class[i] <= CLASS_NEAR_CATASTROPHE;
                int_bound_reg[i] <= 1'b0;
                half_int_reg[i] <= 1'b0;
                quarter_int_reg[i] <= 1'b0;
                catastrophe_reg[i] <= 1'b1;
                // Stability low in danger zone (want to escape)
                stability[i] <= 18'sd4096;  // 0.25
            end else if (dist_zero < THRESH_EIGHTH || dist_one < THRESH_EIGHTH) begin
                // Near integer boundary
                position_class[i] <= CLASS_INTEGER_BOUNDARY;
                int_bound_reg[i] <= 1'b1;
                half_int_reg[i] <= 1'b0;
                quarter_int_reg[i] <= 1'b0;
                catastrophe_reg[i] <= 1'b0;
                // Stability = 0 at boundaries (unstable equilibrium)
                stability[i] <= 18'sd0;
            end else if (dist_half < THRESH_EIGHTH) begin
                // Near half-integer (stable attractor)
                position_class[i] <= CLASS_HALF_INTEGER;
                int_bound_reg[i] <= 1'b0;
                half_int_reg[i] <= 1'b1;
                quarter_int_reg[i] <= 1'b0;
                catastrophe_reg[i] <= 1'b0;
                // Maximum stability at attractors
                // Stability = 1.0 - 4 * dist_half (linear from 1.0 at center to 0.5 at edge)
                stability[i] <= FRAC_ONE - (dist_half <<< 2);
            end else if (dist_quarter < THRESH_EIGHTH || dist_three_quarter < THRESH_EIGHTH) begin
                // Near quarter-integer (fallback position)
                position_class[i] <= CLASS_QUARTER_INTEGER;
                int_bound_reg[i] <= 1'b0;
                half_int_reg[i] <= 1'b0;
                quarter_int_reg[i] <= 1'b1;
                catastrophe_reg[i] <= 1'b0;
                // Intermediate stability (between boundary and attractor)
                // Use the minimum distance to compute stability
                min_dist = (dist_quarter < dist_three_quarter) ? dist_quarter : dist_three_quarter;
                stability[i] <= FRAC_HALF - (min_dist <<< 1);  // 0.5 at center, lower at edges
            end else begin
                // In transition zone - classify by nearest
                if (dist_half < dist_zero && dist_half < dist_quarter &&
                    dist_half < dist_three_quarter && dist_half < dist_one) begin
                    position_class[i] <= CLASS_HALF_INTEGER;
                    half_int_reg[i] <= 1'b1;
                    int_bound_reg[i] <= 1'b0;
                    quarter_int_reg[i] <= 1'b0;
                    catastrophe_reg[i] <= 1'b0;
                    stability[i] <= FRAC_HALF;  // Medium stability in transition
                end else if (dist_quarter < dist_zero && dist_quarter < dist_one) begin
                    position_class[i] <= CLASS_QUARTER_INTEGER;
                    quarter_int_reg[i] <= 1'b1;
                    int_bound_reg[i] <= 1'b0;
                    half_int_reg[i] <= 1'b0;
                    catastrophe_reg[i] <= 1'b0;
                    stability[i] <= FRAC_QUARTER;  // Lower stability
                end else if (dist_three_quarter < dist_zero && dist_three_quarter < dist_one) begin
                    position_class[i] <= CLASS_QUARTER_INTEGER;
                    quarter_int_reg[i] <= 1'b1;
                    int_bound_reg[i] <= 1'b0;
                    half_int_reg[i] <= 1'b0;
                    catastrophe_reg[i] <= 1'b0;
                    stability[i] <= FRAC_QUARTER;
                end else begin
                    position_class[i] <= CLASS_INTEGER_BOUNDARY;
                    int_bound_reg[i] <= 1'b1;
                    half_int_reg[i] <= 1'b0;
                    quarter_int_reg[i] <= 1'b0;
                    catastrophe_reg[i] <= 1'b0;
                    stability[i] <= 18'sd2048;  // Very low stability near boundaries
                end
            end
        end
    end
end

//-----------------------------------------------------------------------------
// Pack outputs
//-----------------------------------------------------------------------------
generate
    for (g = 0; g < NUM_OSCILLATORS; g = g + 1) begin : pack_outputs
        assign position_class_packed[g*2 +: 2] = position_class[g];
        assign stability_packed[g*WIDTH +: WIDTH] = stability[g];
    end
endgenerate

assign is_integer_boundary = int_bound_reg;
assign is_half_integer = half_int_reg;
assign is_quarter_integer = quarter_int_reg;
assign is_near_catastrophe = catastrophe_reg;

endmodule
