//=============================================================================
// Clock Enable Generator - v6.0
// Generates 4 kHz enable pulse from 125 MHz system clock
// v6.0: Updated from 1 kHz for better gamma accuracy (100 samples/cycle at 40 Hz)
//
// SIMULATION: Use +define+FAST_SIM or parameter CLK_DIV_OVERRIDE for speed
//=============================================================================
`timescale 1ns / 1ps

module clock_enable_generator #(
    parameter CLK_DIV_OVERRIDE = 0  // 0 = use default, >0 = override divider
)(
    input  wire clk,
    input  wire rst,
    output reg  clk_4khz_en,      // v6.0: Renamed from clk_1khz_en
    output reg  clk_100khz_en
);

// 125 MHz / 4 kHz = 31250, so max count = 31249
// For simulation: use smaller divider for speed
`ifdef FAST_SIM
    localparam [14:0] COUNT_4KHZ_MAX = 15'd9;  // 10x per 100 clocks
`else
    localparam [14:0] COUNT_4KHZ_MAX = (CLK_DIV_OVERRIDE > 0) ?
                                       (CLK_DIV_OVERRIDE - 1) : 15'd31249;
`endif
reg [14:0] count_4khz;

// 125 MHz / 100 kHz = 1250, so max count = 1249
reg [10:0] count_100khz;
localparam [10:0] COUNT_100KHZ_MAX = 11'd1249;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        count_4khz <= 15'd0;
        count_100khz <= 11'd0;
        clk_4khz_en <= 1'b0;
        clk_100khz_en <= 1'b0;
    end else begin
        // 4 kHz enable (primary oscillator update rate)
        if (count_4khz == COUNT_4KHZ_MAX) begin
            count_4khz <= 15'd0;
            clk_4khz_en <= 1'b1;
        end else begin
            count_4khz <= count_4khz + 1'b1;
            clk_4khz_en <= 1'b0;
        end

        // 100 kHz enable (reserved for future fast paths)
        if (count_100khz == COUNT_100KHZ_MAX) begin
            count_100khz <= 11'd0;
            clk_100khz_en <= 1'b1;
        end else begin
            count_100khz <= count_100khz + 1'b1;
            clk_100khz_en <= 1'b0;
        end
    end
end

endmodule
