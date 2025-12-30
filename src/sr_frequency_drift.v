//=============================================================================
// SR Frequency Drift Generator - v2.1
//
// v2.1 CHANGES (Dual Alignment Ignition - v12.2):
// - Updated f₀ center: 7.6 → 7.75 Hz (exact SR1 from geophysical data)
// - Tightened drift ranges for impedance matching with internal oscillators
// - Added RANDOM_INIT parameter for stochastic startup alignment
// - Added omega_dt_f0_actual output for alignment detector
//
// v2.0 CHANGES (Biological Realism - Phase 4):
// - Faster UPDATE_PERIOD: 1500 → 400 cycles (~0.1s per step in FAST_SIM)
// - Variable step sizes (1-4): Lévy flight-like for biological variability
//
// SR FREQUENCIES (v2.1 - tightened for phi^n alignment):
//   f₀ = 7.75 Hz ± 0.5 Hz   (range: 7.25-8.25 Hz)  v2.1: tightened for alignment
//   f₁ = 13.75 Hz ± 0.8 Hz  (range: 12.95-14.55 Hz) v2.1: tightened
//   f₂ = 20 Hz   ± 1.0 Hz   (range: 19-21 Hz)      v2.1: tightened
//   f₃ = 25 Hz   ± 1.5 Hz   (range: 23.5-26.5 Hz)  v2.1: tightened
//   f₄ = 32 Hz   ± 2.0 Hz   (range: 30-34 Hz)      v2.1: tightened
//
// DRIFT MODEL:
// - Bounded random walk with reflecting boundaries
// - Update rate: ~0.1s (visible in spectrogram)
// - Step size: 1-4 OMEGA_DT units per update (variable, Lévy flight-like)
// - Random initialization prevents startup alignment
//=============================================================================
`timescale 1ns / 1ps

module sr_frequency_drift #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_HARMONICS = 5,
    parameter FAST_SIM = 0,
    parameter RANDOM_INIT = 1  // v2.1: Enable random start position
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Drifting OMEGA_DT values for each harmonic
    output wire signed [NUM_HARMONICS*WIDTH-1:0] omega_dt_packed,

    // Debug: current offset from center (signed)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] drift_offset_packed,

    // v2.1: Actual f0 omega_dt for alignment detector
    output wire signed [WIDTH-1:0] omega_dt_f0_actual
);

//-----------------------------------------------------------------------------
// Center Frequencies (OMEGA_DT in Q14)
// Formula: OMEGA_DT = round(2π × f_hz × dt × 2^14) where dt = 0.00025s
// v2.1: f₀ updated to 7.75 Hz for exact phi^n alignment
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] OMEGA_CENTER_F0 = 18'sd199;   // 7.75 Hz (v2.1: was 7.6)
localparam signed [WIDTH-1:0] OMEGA_CENTER_F1 = 18'sd354;   // 13.75 Hz
localparam signed [WIDTH-1:0] OMEGA_CENTER_F2 = 18'sd514;   // 20 Hz
localparam signed [WIDTH-1:0] OMEGA_CENTER_F3 = 18'sd643;   // 25 Hz
localparam signed [WIDTH-1:0] OMEGA_CENTER_F4 = 18'sd823;   // 32 Hz

//-----------------------------------------------------------------------------
// Drift Ranges (±OMEGA_DT units) - v2.1: Tightened for impedance matching
// Converted from Hz: DRIFT_MAX = round(2π × Δf × dt × 2^14)
// Matches internal oscillator drift ranges for alignment probability
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] DRIFT_MAX_F0 = 18'sd13;   // ±0.5 Hz (v2.1: was ±0.9)
localparam signed [WIDTH-1:0] DRIFT_MAX_F1 = 18'sd21;   // ±0.8 Hz (v2.1: was ±1.1)
localparam signed [WIDTH-1:0] DRIFT_MAX_F2 = 18'sd26;   // ±1.0 Hz (v2.1: was ±1.5)
localparam signed [WIDTH-1:0] DRIFT_MAX_F3 = 18'sd39;   // ±1.5 Hz (v2.1: was ±2.25)
localparam signed [WIDTH-1:0] DRIFT_MAX_F4 = 18'sd51;   // ±2.0 Hz (v2.1: was ±3.0)

//-----------------------------------------------------------------------------
// Random Walk Update Period - v2.0: Faster for visible spectrogram wobble
// Previous: 15 minutes (3.6M cycles) - too slow for visible variation
// v2.0: ~0.1s updates - creates seconds-scale visible frequency wobble
//
// FAST_SIM: 400 clk_en = 0.1s at 4kHz (was 1500 = 0.375s)
// Real-time: 960000 clk_en = 4 minutes (was 3.6M = 15 minutes)
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    localparam [21:0] UPDATE_PERIOD = 22'd400;      // v2.0: 0.1s updates (was 1500)
`else
    localparam [21:0] UPDATE_PERIOD = (FAST_SIM != 0) ? 22'd400 : 22'd960000;
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
// v2.0: Variable Step Sizes (1-4) for Lévy flight-like behavior
// Use LFSR bits [3:2] to determine step magnitude (1-4 units)
// Creates occasional large jumps like biological frequency variability
//-----------------------------------------------------------------------------
wire [1:0] step_bits_0 = lfsr_0[3:2];
wire [1:0] step_bits_1 = lfsr_1[3:2];
wire [1:0] step_bits_2 = lfsr_2[3:2];
wire [1:0] step_bits_3 = lfsr_3[3:2];
wire [1:0] step_bits_4 = lfsr_4[3:2];

// Step size: 1 + step_bits gives range 1-4
wire signed [WIDTH-1:0] step_0 = {{(WIDTH-3){1'b0}}, step_bits_0, 1'b0} + 18'sd1;  // 1, 2, 3, or 4
wire signed [WIDTH-1:0] step_1 = {{(WIDTH-3){1'b0}}, step_bits_1, 1'b0} + 18'sd1;
wire signed [WIDTH-1:0] step_2 = {{(WIDTH-3){1'b0}}, step_bits_2, 1'b0} + 18'sd1;
wire signed [WIDTH-1:0] step_3 = {{(WIDTH-3){1'b0}}, step_bits_3, 1'b0} + 18'sd1;
wire signed [WIDTH-1:0] step_4 = {{(WIDTH-3){1'b0}}, step_bits_4, 1'b0} + 18'sd1;

//-----------------------------------------------------------------------------
// v2.1: Random Initialization Offsets
// Use LFSR seed bits to compute initial position within drift bounds
// Maps seed bits [15:11] (0-31) to [-DRIFT_MAX, +DRIFT_MAX]
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] init_offset_0, init_offset_1, init_offset_2, init_offset_3, init_offset_4;
assign init_offset_0 = RANDOM_INIT ? (((LFSR_SEED_0[15:11] - 5'd16) * DRIFT_MAX_F0) >>> 4) : 18'sd0;
assign init_offset_1 = RANDOM_INIT ? (((LFSR_SEED_1[15:11] - 5'd16) * DRIFT_MAX_F1) >>> 4) : 18'sd0;
assign init_offset_2 = RANDOM_INIT ? (((LFSR_SEED_2[15:11] - 5'd16) * DRIFT_MAX_F2) >>> 4) : 18'sd0;
assign init_offset_3 = RANDOM_INIT ? (((LFSR_SEED_3[15:11] - 5'd16) * DRIFT_MAX_F3) >>> 4) : 18'sd0;
assign init_offset_4 = RANDOM_INIT ? (((LFSR_SEED_4[15:11] - 5'd16) * DRIFT_MAX_F4) >>> 4) : 18'sd0;

//-----------------------------------------------------------------------------
// Random Walk Update Logic - Harmonic 0 (v2.0: variable step size)
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_0 <= LFSR_SEED_0;
        drift_0 <= init_offset_0;  // v2.1: Random initial position
    end else if (clk_en && update_tick) begin
        lfsr_0 <= {lfsr_0[14:0], fb_0};
        if (dir_0) begin
            if (drift_0 + step_0 <= DRIFT_MAX_F0)
                drift_0 <= drift_0 + step_0;
            else
                drift_0 <= drift_0 - step_0;  // Reflect at boundary
        end else begin
            if (drift_0 - step_0 >= -DRIFT_MAX_F0)
                drift_0 <= drift_0 - step_0;
            else
                drift_0 <= drift_0 + step_0;  // Reflect at boundary
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - Harmonic 1 (v2.0: variable step size)
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_1 <= LFSR_SEED_1;
        drift_1 <= init_offset_1;  // v2.1: Random initial position
    end else if (clk_en && update_tick) begin
        lfsr_1 <= {lfsr_1[14:0], fb_1};
        if (dir_1) begin
            if (drift_1 + step_1 <= DRIFT_MAX_F1)
                drift_1 <= drift_1 + step_1;
            else
                drift_1 <= drift_1 - step_1;  // Reflect at boundary
        end else begin
            if (drift_1 - step_1 >= -DRIFT_MAX_F1)
                drift_1 <= drift_1 - step_1;
            else
                drift_1 <= drift_1 + step_1;  // Reflect at boundary
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - Harmonic 2 (v2.0: variable step size)
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_2 <= LFSR_SEED_2;
        drift_2 <= init_offset_2;  // v2.1: Random initial position
    end else if (clk_en && update_tick) begin
        lfsr_2 <= {lfsr_2[14:0], fb_2};
        if (dir_2) begin
            if (drift_2 + step_2 <= DRIFT_MAX_F2)
                drift_2 <= drift_2 + step_2;
            else
                drift_2 <= drift_2 - step_2;  // Reflect at boundary
        end else begin
            if (drift_2 - step_2 >= -DRIFT_MAX_F2)
                drift_2 <= drift_2 - step_2;
            else
                drift_2 <= drift_2 + step_2;  // Reflect at boundary
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - Harmonic 3 (v2.0: variable step size)
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_3 <= LFSR_SEED_3;
        drift_3 <= init_offset_3;  // v2.1: Random initial position
    end else if (clk_en && update_tick) begin
        lfsr_3 <= {lfsr_3[14:0], fb_3};
        if (dir_3) begin
            if (drift_3 + step_3 <= DRIFT_MAX_F3)
                drift_3 <= drift_3 + step_3;
            else
                drift_3 <= drift_3 - step_3;  // Reflect at boundary
        end else begin
            if (drift_3 - step_3 >= -DRIFT_MAX_F3)
                drift_3 <= drift_3 - step_3;
            else
                drift_3 <= drift_3 + step_3;  // Reflect at boundary
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - Harmonic 4 (v2.0: variable step size)
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_4 <= LFSR_SEED_4;
        drift_4 <= init_offset_4;  // v2.1: Random initial position
    end else if (clk_en && update_tick) begin
        lfsr_4 <= {lfsr_4[14:0], fb_4};
        if (dir_4) begin
            if (drift_4 + step_4 <= DRIFT_MAX_F4)
                drift_4 <= drift_4 + step_4;
            else
                drift_4 <= drift_4 - step_4;  // Reflect at boundary
        end else begin
            if (drift_4 - step_4 >= -DRIFT_MAX_F4)
                drift_4 <= drift_4 - step_4;
            else
                drift_4 <= drift_4 + step_4;  // Reflect at boundary
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

// v2.1: Individual f0 output for alignment detector
assign omega_dt_f0_actual = omega_0;

endmodule
