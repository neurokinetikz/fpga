//=============================================================================
// SR Frequency Drift Generator - v2.0
//
// v2.0 CHANGES (Biological Realism - Phase 4):
// - Faster UPDATE_PERIOD: 1500 → 400 cycles (~0.1s per step in FAST_SIM)
// - Larger DRIFT_MAX bounds: 1.5× wider for visible spectrogram wobble
// - Variable step sizes (1-4): Lévy flight-like for biological variability
// - Creates visible ±1-2 Hz frequency wobble at seconds timescale
//
// Models realistic Schumann Resonance frequency drift based on observed data.
// Each harmonic performs a bounded random walk within its natural variation range.
//
// OBSERVED SR FREQUENCIES (from real-time monitoring):
//   f₀ = 7.6 Hz  ± 0.9 Hz   (range: 6.7-8.5 Hz)  v2.0: expanded from ±0.6
//   f₁ = 13.75 Hz ± 1.1 Hz  (range: 12.6-14.9 Hz) v2.0: expanded from ±0.75
//   f₂ = 20 Hz   ± 1.5 Hz   (range: 18.5-21.5 Hz) v2.0: expanded from ±1
//   f₃ = 25 Hz   ± 2.25 Hz  (range: 22.75-27.25 Hz) v2.0: expanded from ±1.5
//   f₄ = 32 Hz   ± 3.0 Hz   (range: 29-35 Hz)     v2.0: expanded from ±2
//
// DRIFT MODEL:
// - Bounded random walk with reflecting boundaries
// - Update rate: ~0.1s (visible in spectrogram)
// - Step size: 1-4 OMEGA_DT units per update (variable, Lévy flight-like)
// - Produces visible seconds-scale wobble matching biological EEG
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
// Drift Ranges (±OMEGA_DT units) - v2.0: Expanded 1.5× for visible wobble
// Converted from Hz: DRIFT_MAX = round(2π × Δf × dt × 2^14)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] DRIFT_MAX_F0 = 18'sd23;   // ±0.9 Hz → ±23 (was ±15)
localparam signed [WIDTH-1:0] DRIFT_MAX_F1 = 18'sd28;   // ±1.1 Hz → ±28 (was ±19)
localparam signed [WIDTH-1:0] DRIFT_MAX_F2 = 18'sd39;   // ±1.5 Hz → ±39 (was ±26)
localparam signed [WIDTH-1:0] DRIFT_MAX_F3 = 18'sd58;   // ±2.25 Hz → ±58 (was ±39)
localparam signed [WIDTH-1:0] DRIFT_MAX_F4 = 18'sd77;   // ±3.0 Hz → ±77 (was ±51)

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
// Random Walk Update Logic - Harmonic 0 (v2.0: variable step size)
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_0 <= LFSR_SEED_0;
        drift_0 <= 18'sd0;
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
        drift_1 <= 18'sd0;
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
        drift_2 <= 18'sd0;
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
        drift_3 <= 18'sd0;
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
        drift_4 <= 18'sd0;
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

endmodule
