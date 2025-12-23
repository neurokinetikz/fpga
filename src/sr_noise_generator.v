//=============================================================================
// SR Noise Generator - v1.0
//
// Generates 5 independent white noise sources for stochastic resonance.
// Each harmonic receives its own uncorrelated noise stream.
//
// Uses 16-bit LFSRs with polynomial x^16 + x^14 + x^13 + x^11 + 1
// (same as pink_noise_generator.v)
//
// Output scaling: noise = (lfsr[11:0] - 2048) * NOISE_AMPLITUDE >> 11
// This produces centered noise with configurable amplitude.
//=============================================================================
`timescale 1ns / 1ps

module sr_noise_generator #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_HARMONICS = 5,
    parameter signed [WIDTH-1:0] NOISE_AMPLITUDE = 18'sd256  // ~0.015 in Q14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] noise_packed
);

//-----------------------------------------------------------------------------
// LFSR Seeds - Different seeds ensure uncorrelated noise streams
// Seeds chosen to be maximally different and not simple bit shifts of each other
//-----------------------------------------------------------------------------
localparam [15:0] SEED_H0 = 16'hACE1;   // Same as pink_noise_generator
localparam [15:0] SEED_H1 = 16'h7B3F;   // Different pattern
localparam [15:0] SEED_H2 = 16'hD4A9;   // Different pattern
localparam [15:0] SEED_H3 = 16'h1E6C;   // Different pattern
localparam [15:0] SEED_H4 = 16'h92F5;   // Different pattern

//-----------------------------------------------------------------------------
// 5 Independent LFSR Registers
//-----------------------------------------------------------------------------
reg [15:0] lfsr [0:NUM_HARMONICS-1];

// Feedback taps: x^16 + x^14 + x^13 + x^11 + 1
wire [NUM_HARMONICS-1:0] lfsr_feedback;

genvar h;
generate
    for (h = 0; h < NUM_HARMONICS; h = h + 1) begin : feedback_gen
        assign lfsr_feedback[h] = lfsr[h][15] ^ lfsr[h][13] ^ lfsr[h][12] ^ lfsr[h][10];
    end
endgenerate

//-----------------------------------------------------------------------------
// LFSR State Update
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr[0] <= SEED_H0;
        lfsr[1] <= SEED_H1;
        lfsr[2] <= SEED_H2;
        lfsr[3] <= SEED_H3;
        lfsr[4] <= SEED_H4;
    end else if (clk_en) begin
        lfsr[0] <= {lfsr[0][14:0], lfsr_feedback[0]};
        lfsr[1] <= {lfsr[1][14:0], lfsr_feedback[1]};
        lfsr[2] <= {lfsr[2][14:0], lfsr_feedback[2]};
        lfsr[3] <= {lfsr[3][14:0], lfsr_feedback[3]};
        lfsr[4] <= {lfsr[4][14:0], lfsr_feedback[4]};
    end
end

//-----------------------------------------------------------------------------
// Noise Scaling
//
// Raw LFSR output: 12-bit unsigned [0, 4095]
// Centered: lfsr[11:0] - 2048 gives [-2048, +2047]
// Scaled: (centered * NOISE_AMPLITUDE) >> 11
//
// With NOISE_AMPLITUDE = 256 (default):
//   Max output = 2047 * 256 / 2048 = ~255 ≈ 0.0156 in Q14
//   Min output = -2048 * 256 / 2048 = -256 ≈ -0.0156 in Q14
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] noise_out [0:NUM_HARMONICS-1];
wire signed [11:0] lfsr_centered [0:NUM_HARMONICS-1];
wire signed [29:0] noise_product [0:NUM_HARMONICS-1];

generate
    for (h = 0; h < NUM_HARMONICS; h = h + 1) begin : noise_scale_gen
        // Center the 12-bit LFSR output around zero
        assign lfsr_centered[h] = $signed({1'b0, lfsr[h][11:0]}) - 12'sd2048;

        // Scale by NOISE_AMPLITUDE and shift down
        // Product is 12-bit signed × 18-bit signed = 30-bit
        assign noise_product[h] = lfsr_centered[h] * NOISE_AMPLITUDE;

        // Shift right by 11 to get final amplitude, sign-extend to WIDTH
        assign noise_out[h] = noise_product[h] >>> 11;
    end
endgenerate

//-----------------------------------------------------------------------------
// Pack Output
//-----------------------------------------------------------------------------
assign noise_packed = {noise_out[4], noise_out[3], noise_out[2], noise_out[1], noise_out[0]};

endmodule
