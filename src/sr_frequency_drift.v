//=============================================================================
// SR Frequency Drift Generator - v1.0
//
// Models realistic Schumann Resonance frequency drift based on observed data.
// Each harmonic performs a bounded random walk within its natural variation range.
//
// OBSERVED SR FREQUENCIES (from real-time monitoring):
//   f₀ = 7.6 Hz  ± 0.6 Hz   (range: 7.0-8.2 Hz)
//   f₁ = 13.75 Hz ± 0.75 Hz (range: 13.0-14.5 Hz)
//   f₂ = 20 Hz   ± 1 Hz     (range: 19-21 Hz)
//   f₃ = 25 Hz   ± 1.5 Hz   (range: 23.5-26.5 Hz)
//   f₄ = 32 Hz   ± 2 Hz     (range: 30-34 Hz)
//
// DRIFT MODEL:
// - Bounded random walk with reflecting boundaries
// - Update rate: ~2 minutes real-time (scaled for FAST_SIM)
// - Step size: 1 OMEGA_DT unit per update
// - Produces realistic hours-scale drift patterns
//=============================================================================
`timescale 1ns / 1ps

module sr_frequency_drift #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_HARMONICS = 5,
    parameter FAST_SIM = 0
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Drifting OMEGA_DT values for each harmonic
    output wire signed [NUM_HARMONICS*WIDTH-1:0] omega_dt_packed,

    // Debug: current offset from center (signed)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] drift_offset_packed
);

//-----------------------------------------------------------------------------
// Center Frequencies (OMEGA_DT in Q14)
// Formula: OMEGA_DT = round(2π × f_hz × dt × 2^14) where dt = 0.00025s
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] OMEGA_CENTER_F0 = 18'sd196;   // 7.6 Hz
localparam signed [WIDTH-1:0] OMEGA_CENTER_F1 = 18'sd354;   // 13.75 Hz
localparam signed [WIDTH-1:0] OMEGA_CENTER_F2 = 18'sd514;   // 20 Hz
localparam signed [WIDTH-1:0] OMEGA_CENTER_F3 = 18'sd643;   // 25 Hz
localparam signed [WIDTH-1:0] OMEGA_CENTER_F4 = 18'sd823;   // 32 Hz

//-----------------------------------------------------------------------------
// Drift Ranges (±OMEGA_DT units)
// Converted from Hz: DRIFT_MAX = round(2π × Δf × dt × 2^14)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] DRIFT_MAX_F0 = 18'sd15;   // ±0.6 Hz → ±15
localparam signed [WIDTH-1:0] DRIFT_MAX_F1 = 18'sd19;   // ±0.75 Hz → ±19
localparam signed [WIDTH-1:0] DRIFT_MAX_F2 = 18'sd26;   // ±1 Hz → ±26
localparam signed [WIDTH-1:0] DRIFT_MAX_F3 = 18'sd39;   // ±1.5 Hz → ±39
localparam signed [WIDTH-1:0] DRIFT_MAX_F4 = 18'sd51;   // ±2 Hz → ±51

//-----------------------------------------------------------------------------
// Random Walk Update Period
// Tuned to match observed SR drift rates (~0.05-0.1 Hz/hour from monitoring data)
// Real-time: 15 minutes = 3,600,000 clk_en @ 4kHz
//   - 4 steps/hour max = ~0.16 Hz/hour max drift
//   - Random walk σ ≈ 0.08 Hz/hour (matches observed)
// FAST_SIM: 1500 clk_en (same 2400× speedup ratio)
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    localparam [21:0] UPDATE_PERIOD = 22'd1500;
`else
    localparam [21:0] UPDATE_PERIOD = (FAST_SIM != 0) ? 22'd1500 : 22'd3600000;
`endif

//-----------------------------------------------------------------------------
// Update Counter
//-----------------------------------------------------------------------------
reg [21:0] update_counter;
wire update_tick;

assign update_tick = (update_counter == UPDATE_PERIOD);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter <= 22'd0;
    end else if (clk_en) begin
        if (update_tick) begin
            update_counter <= 22'd0;
        end else begin
            update_counter <= update_counter + 1'b1;
        end
    end
end

//-----------------------------------------------------------------------------
// LFSR Seeds (different for each harmonic)
//-----------------------------------------------------------------------------
localparam [15:0] LFSR_SEED_0 = 16'hB5C3;
localparam [15:0] LFSR_SEED_1 = 16'h4E91;
localparam [15:0] LFSR_SEED_2 = 16'hA7D2;
localparam [15:0] LFSR_SEED_3 = 16'h38F6;
localparam [15:0] LFSR_SEED_4 = 16'hC1E4;

//-----------------------------------------------------------------------------
// Per-Harmonic LFSR and Drift State
//-----------------------------------------------------------------------------
reg [15:0] lfsr_0, lfsr_1, lfsr_2, lfsr_3, lfsr_4;
reg signed [WIDTH-1:0] drift_0, drift_1, drift_2, drift_3, drift_4;

// LFSR feedback: x^16 + x^14 + x^13 + x^11 + 1
wire fb_0 = lfsr_0[15] ^ lfsr_0[13] ^ lfsr_0[12] ^ lfsr_0[10];
wire fb_1 = lfsr_1[15] ^ lfsr_1[13] ^ lfsr_1[12] ^ lfsr_1[10];
wire fb_2 = lfsr_2[15] ^ lfsr_2[13] ^ lfsr_2[12] ^ lfsr_2[10];
wire fb_3 = lfsr_3[15] ^ lfsr_3[13] ^ lfsr_3[12] ^ lfsr_3[10];
wire fb_4 = lfsr_4[15] ^ lfsr_4[13] ^ lfsr_4[12] ^ lfsr_4[10];

// Step direction from LSB
wire dir_0 = lfsr_0[0];
wire dir_1 = lfsr_1[0];
wire dir_2 = lfsr_2[0];
wire dir_3 = lfsr_3[0];
wire dir_4 = lfsr_4[0];

//-----------------------------------------------------------------------------
// Random Walk Update Logic - Harmonic 0
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_0 <= LFSR_SEED_0;
        drift_0 <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_0 <= {lfsr_0[14:0], fb_0};
        if (dir_0) begin
            if (drift_0 < DRIFT_MAX_F0)
                drift_0 <= drift_0 + 1;
            else
                drift_0 <= drift_0 - 1;
        end else begin
            if (drift_0 > -DRIFT_MAX_F0)
                drift_0 <= drift_0 - 1;
            else
                drift_0 <= drift_0 + 1;
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - Harmonic 1
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_1 <= LFSR_SEED_1;
        drift_1 <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_1 <= {lfsr_1[14:0], fb_1};
        if (dir_1) begin
            if (drift_1 < DRIFT_MAX_F1)
                drift_1 <= drift_1 + 1;
            else
                drift_1 <= drift_1 - 1;
        end else begin
            if (drift_1 > -DRIFT_MAX_F1)
                drift_1 <= drift_1 - 1;
            else
                drift_1 <= drift_1 + 1;
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - Harmonic 2
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_2 <= LFSR_SEED_2;
        drift_2 <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_2 <= {lfsr_2[14:0], fb_2};
        if (dir_2) begin
            if (drift_2 < DRIFT_MAX_F2)
                drift_2 <= drift_2 + 1;
            else
                drift_2 <= drift_2 - 1;
        end else begin
            if (drift_2 > -DRIFT_MAX_F2)
                drift_2 <= drift_2 - 1;
            else
                drift_2 <= drift_2 + 1;
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - Harmonic 3
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_3 <= LFSR_SEED_3;
        drift_3 <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_3 <= {lfsr_3[14:0], fb_3};
        if (dir_3) begin
            if (drift_3 < DRIFT_MAX_F3)
                drift_3 <= drift_3 + 1;
            else
                drift_3 <= drift_3 - 1;
        end else begin
            if (drift_3 > -DRIFT_MAX_F3)
                drift_3 <= drift_3 - 1;
            else
                drift_3 <= drift_3 + 1;
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - Harmonic 4
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_4 <= LFSR_SEED_4;
        drift_4 <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_4 <= {lfsr_4[14:0], fb_4};
        if (dir_4) begin
            if (drift_4 < DRIFT_MAX_F4)
                drift_4 <= drift_4 + 1;
            else
                drift_4 <= drift_4 - 1;
        end else begin
            if (drift_4 > -DRIFT_MAX_F4)
                drift_4 <= drift_4 - 1;
            else
                drift_4 <= drift_4 + 1;
        end
    end
end

//-----------------------------------------------------------------------------
// Output: Center + Drift Offset
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] omega_0 = OMEGA_CENTER_F0 + drift_0;
wire signed [WIDTH-1:0] omega_1 = OMEGA_CENTER_F1 + drift_1;
wire signed [WIDTH-1:0] omega_2 = OMEGA_CENTER_F2 + drift_2;
wire signed [WIDTH-1:0] omega_3 = OMEGA_CENTER_F3 + drift_3;
wire signed [WIDTH-1:0] omega_4 = OMEGA_CENTER_F4 + drift_4;

//-----------------------------------------------------------------------------
// Pack Outputs
//-----------------------------------------------------------------------------
assign omega_dt_packed = {omega_4, omega_3, omega_2, omega_1, omega_0};
assign drift_offset_packed = {drift_4, drift_3, drift_2, drift_1, drift_0};

endmodule
