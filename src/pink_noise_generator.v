//=============================================================================
// Pink Noise Generator - v7.2 (√Fibonacci-Weighted Voss-McCartney)
//
// v7.2 CHANGES (√Fibonacci Spectral Slope):
// - Weights: sqrt(Fibonacci) for 1/f^φ spectral slope
// - Weights: [1, 1, 1, 2, 2, 3, 4, 5, 6, 7, 9, 12], sum=53
// - Target: 1/f^1.62 ≈ -16.2 dB/decade (golden ratio slope)
// - Rationale: Fibonacci grows as φⁿ, so √Fib → φ^(n/2) → 1/f^φ
//
// v7.0 CHANGES (EEG Spectral Slope):
// - Added weighted row summation to steepen spectral slope
// - Creates "dark pink" noise matching real EEG baseline
//
// v6.0 CHANGES (Biological Realism - Phase 4):
// - Expanded from 8 to 12 octave rows for better 1/f slope at high frequencies
// - Provides proper 1/f roll-off to 80+ Hz (was flat above ~30 Hz)
//
// FREQUENCY COVERAGE (at 4kHz sample rate):
//   Row 0:  Updates every 2 samples    (1000 Hz Nyquist) - weight 1
//   Row 1:  Updates every 4 samples    (500 Hz Nyquist)  - weight 3
//   Row 2:  Updates every 8 samples    (250 Hz Nyquist)  - weight 5
//   Row 3:  Updates every 16 samples   (125 Hz Nyquist)  - weight 8
//   Row 4:  Updates every 32 samples   (62.5 Hz Nyquist) - weight 11
//   Row 5:  Updates every 64 samples   (31.25 Hz Nyquist) - weight 15
//   Row 6:  Updates every 128 samples  (15.6 Hz Nyquist) - weight 19
//   Row 7:  Updates every 256 samples  (7.8 Hz Nyquist)  - weight 23
//   Row 8:  Updates every 512 samples  (3.9 Hz Nyquist)  - weight 27
//   Row 9:  Updates every 1024 samples (1.95 Hz Nyquist) - weight 32
//   Row 10: Updates every 2048 samples (0.98 Hz Nyquist) - weight 36
//   Row 11: Updates every 4096 samples (0.49 Hz Nyquist) - weight 42
//=============================================================================
`timescale 1ns / 1ps

module pink_noise_generator #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_ROWS = 12  // v6.0: expanded from 8 to 12
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,
    output reg signed [WIDTH-1:0] noise_out
);

reg [15:0] lfsr;
wire lfsr_feedback;

assign lfsr_feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr <= 16'hACE1;
    end else if (clk_en) begin
        lfsr <= {lfsr[14:0], lfsr_feedback};
    end
end

// v6.0: Expanded to 12 rows and 12-bit counter
reg signed [11:0] row [0:NUM_ROWS-1];
reg [11:0] sample_count;
wire signed [15:0] row_sum;  // 16 bits to handle sum of 12 rows

integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sample_count <= 12'd0;
        for (i = 0; i < NUM_ROWS; i = i + 1) begin
            row[i] <= 12'sd0;
        end
    end else if (clk_en) begin
        sample_count <= sample_count + 1'b1;

        // Original 8 rows
        if (sample_count[0] == 1'b0)
            row[0] <= lfsr[11:0] - 12'sd2048;
        if (sample_count[1:0] == 2'b00)
            row[1] <= lfsr[11:0] - 12'sd2048;
        if (sample_count[2:0] == 3'b000)
            row[2] <= lfsr[11:0] - 12'sd2048;
        if (sample_count[3:0] == 4'b0000)
            row[3] <= lfsr[11:0] - 12'sd2048;
        if (sample_count[4:0] == 5'b00000)
            row[4] <= lfsr[11:0] - 12'sd2048;
        if (sample_count[5:0] == 6'b000000)
            row[5] <= lfsr[11:0] - 12'sd2048;
        if (sample_count[6:0] == 7'b0000000)
            row[6] <= lfsr[11:0] - 12'sd2048;
        if (sample_count[7:0] == 8'b00000000)
            row[7] <= lfsr[11:0] - 12'sd2048;

        // v6.0: 4 additional rows for better low-frequency 1/f content
        if (sample_count[8:0] == 9'b000000000)
            row[8] <= lfsr[11:0] - 12'sd2048;
        if (sample_count[9:0] == 10'b0000000000)
            row[9] <= lfsr[11:0] - 12'sd2048;
        if (sample_count[10:0] == 11'b00000000000)
            row[10] <= lfsr[11:0] - 12'sd2048;
        if (sample_count[11:0] == 12'b000000000000)
            row[11] <= lfsr[11:0] - 12'sd2048;
    end
end

// v7.2: √Fibonacci-weighted sum for 1/f^φ spectral slope (φ = 1.618)
// Weights: sqrt(Fibonacci) = [1,1,1,2,2,3,4,5,6,7,9,12], sum = 53
// Rationale: Fib grows as φⁿ, so √Fib = φ^(n/2) → creates 1/f^φ exponent
wire signed [18:0] weighted_row_sum =
    row[0]  * 1   +   // 1000 Hz Nyquist: √F(1) = 1
    row[1]  * 1   +   // 500 Hz Nyquist:  √F(2) = 1
    row[2]  * 1   +   // 250 Hz Nyquist:  √F(3) = 1
    row[3]  * 2   +   // 125 Hz Nyquist:  √F(4) = 2
    row[4]  * 2   +   // 62.5 Hz Nyquist: √F(5) = 2
    row[5]  * 3   +   // 31.25 Hz Nyquist: √F(6) = 3
    row[6]  * 4   +   // 15.6 Hz Nyquist: √F(7) = 4
    row[7]  * 5   +   // 7.8 Hz Nyquist: √F(8) = 5
    row[8]  * 6   +   // 3.9 Hz Nyquist: √F(9) = 6
    row[9]  * 7   +   // 1.95 Hz Nyquist: √F(10) = 7
    row[10] * 9   +   // 0.98 Hz Nyquist: √F(11) = 9
    row[11] * 12;     // 0.49 Hz Nyquist: √F(12) = 12

// Normalize to maintain similar amplitude to original:
// Old: sum of 12 rows (total weight = 12)
// New: weighted sum (total weight = 53)
// Scale factor: 53/12 = 4.4, use >>> 2 (divide by 4)
assign row_sum = weighted_row_sum >>> 2;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        noise_out <= 18'sd0;
    end else if (clk_en) begin
        // Sign-extend 16-bit sum to 18-bit output
        noise_out <= {{2{row_sum[15]}}, row_sum};
    end
end

endmodule
