//=============================================================================
// Pink Noise Generator - v5.5 (Voss-McCartney)
//=============================================================================
`timescale 1ns / 1ps

module pink_noise_generator #(
    parameter WIDTH = 18,
    parameter FRAC = 14
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

reg signed [11:0] row [0:7];
reg [7:0] sample_count;
wire signed [14:0] row_sum;

integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sample_count <= 8'd0;
        for (i = 0; i < 8; i = i + 1) begin
            row[i] <= 12'sd0;
        end
    end else if (clk_en) begin
        sample_count <= sample_count + 1'b1;

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
    end
end

assign row_sum = row[0] + row[1] + row[2] + row[3] +
                 row[4] + row[5] + row[6] + row[7];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        noise_out <= 18'sd0;
    end else if (clk_en) begin
        noise_out <= {{3{row_sum[14]}}, row_sum};
    end
end

endmodule
