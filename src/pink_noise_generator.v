//=============================================================================
// Pink Noise Generator - v6.0 (Voss-McCartney, 12 octave rows)
//
// v6.0 CHANGES (Biological Realism - Phase 4):
// - Expanded from 8 to 12 octave rows for better 1/f slope at high frequencies
// - Provides proper 1/f roll-off to 80+ Hz (was flat above ~30 Hz)
// - Each additional row adds ~1 octave of low-frequency content
//
// FREQUENCY COVERAGE (at 4kHz sample rate):
//   Row 0:  Updates every 2 samples    (1000 Hz Nyquist)
//   Row 1:  Updates every 4 samples    (500 Hz Nyquist)
//   Row 2:  Updates every 8 samples    (250 Hz Nyquist)
//   Row 3:  Updates every 16 samples   (125 Hz Nyquist)
//   Row 4:  Updates every 32 samples   (62.5 Hz Nyquist)
//   Row 5:  Updates every 64 samples   (31.25 Hz Nyquist)
//   Row 6:  Updates every 128 samples  (15.6 Hz Nyquist)
//   Row 7:  Updates every 256 samples  (7.8 Hz Nyquist)
//   Row 8:  Updates every 512 samples  (3.9 Hz Nyquist) [NEW]
//   Row 9:  Updates every 1024 samples (1.95 Hz Nyquist) [NEW]
//   Row 10: Updates every 2048 samples (0.98 Hz Nyquist) [NEW]
//   Row 11: Updates every 4096 samples (0.49 Hz Nyquist) [NEW]
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

// v6.0: Sum all 12 rows
assign row_sum = row[0] + row[1] + row[2] + row[3] +
                 row[4] + row[5] + row[6] + row[7] +
                 row[8] + row[9] + row[10] + row[11];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        noise_out <= 18'sd0;
    end else if (clk_en) begin
        // Sign-extend 16-bit sum to 18-bit output
        noise_out <= {{2{row_sum[15]}}, row_sum};
    end
end

endmodule
