//=============================================================================
// SR Frequency Drift Generator - v3.0
//
// v3.0 CHANGES (Three-Boundary Architecture):
// - Per-harmonic UPDATE_PERIOD implementing SR STABILITY HIERARCHY
//   SR3 (f₂) = SLOWEST (10s) - stability anchor
//   SR2 (f₁) = Very slow (5s) - timing reference
//   SR1 (f₀) = Moderate (2s) - event detector
//   SR5 (f₄) = Moderate (2s) - consciousness gate
//   SR4 (f₃) = FASTEST (1s) - arousal modulator
// - Per-harmonic STEP_MAX: SR3/SR2 smallest, SR4 largest
// - Separate update counters per harmonic
// - Added individual omega outputs for all harmonics (boundary detectors)
//
// v2.1 CHANGES (Dual Alignment Ignition - v12.2):
// - Updated f₀ center: 7.6 → 7.75 Hz (exact SR1 from geophysical data)
// - Tightened drift ranges for impedance matching with internal oscillators
// - Added RANDOM_INIT parameter for stochastic startup alignment
//
// SR FREQUENCIES (unchanged from v2.1):
//   f₀ = 7.75 Hz ± 0.5 Hz   (range: 7.25-8.25 Hz)
//   f₁ = 13.75 Hz ± 0.8 Hz  (range: 12.95-14.55 Hz)
//   f₂ = 20 Hz   ± 1.0 Hz   (range: 19-21 Hz)
//   f₃ = 25 Hz   ± 1.5 Hz   (range: 23.5-26.5 Hz)
//   f₄ = 32 Hz   ± 2.0 Hz   (range: 30-34 Hz)
//
// STABILITY HIERARCHY (from real geophysical data):
//   SR3 > SR2 > SR1 = SR5 > SR4 (most to least stable)
//=============================================================================
`timescale 1ns / 1ps

module sr_frequency_drift #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_HARMONICS = 5,
    parameter FAST_SIM = 0,
    parameter RANDOM_INIT = 1
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Drifting OMEGA_DT values for each harmonic
    output wire signed [NUM_HARMONICS*WIDTH-1:0] omega_dt_packed,

    // Debug: current offset from center (signed)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] drift_offset_packed,

    // v2.1: Individual omega_dt outputs for alignment/boundary detectors
    output wire signed [WIDTH-1:0] omega_dt_f0_actual,  // SR1 - f₀ boundary
    output wire signed [WIDTH-1:0] omega_dt_f1_actual,  // SR2 - timing ref
    output wire signed [WIDTH-1:0] omega_dt_f2_actual,  // SR3 - f₂ boundary (stability)
    output wire signed [WIDTH-1:0] omega_dt_f3_actual,  // SR4 - arousal
    output wire signed [WIDTH-1:0] omega_dt_f4_actual   // SR5 - f₃ boundary (consciousness)
);

//-----------------------------------------------------------------------------
// Center Frequencies (OMEGA_DT in Q14)
// Formula: OMEGA_DT = round(2π × f_hz × dt × 2^14) where dt = 0.00025s
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] OMEGA_CENTER_F0 = 18'sd199;   // 7.75 Hz (SR1)
localparam signed [WIDTH-1:0] OMEGA_CENTER_F1 = 18'sd354;   // 13.75 Hz (SR2)
localparam signed [WIDTH-1:0] OMEGA_CENTER_F2 = 18'sd514;   // 20 Hz (SR3)
localparam signed [WIDTH-1:0] OMEGA_CENTER_F3 = 18'sd643;   // 25 Hz (SR4)
localparam signed [WIDTH-1:0] OMEGA_CENTER_F4 = 18'sd823;   // 32 Hz (SR5)

//-----------------------------------------------------------------------------
// Drift Ranges (±OMEGA_DT units) - unchanged from v2.1
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] DRIFT_MAX_F0 = 18'sd13;   // ±0.5 Hz
localparam signed [WIDTH-1:0] DRIFT_MAX_F1 = 18'sd21;   // ±0.8 Hz
localparam signed [WIDTH-1:0] DRIFT_MAX_F2 = 18'sd26;   // ±1.0 Hz
localparam signed [WIDTH-1:0] DRIFT_MAX_F3 = 18'sd39;   // ±1.5 Hz
localparam signed [WIDTH-1:0] DRIFT_MAX_F4 = 18'sd51;   // ±2.0 Hz

//-----------------------------------------------------------------------------
// v3.0: Per-Harmonic Update Periods - STABILITY HIERARCHY
//
// From real geophysical data:
//   SR3 = MOST STABLE (highest Q ~9)
//   SR2 = Very stable
//   SR1 = Moderate (event-responsive, Q varies 8-22)
//   SR5 = Moderate
//   SR4 = MOST VARIABLE
//
// FAST_SIM values are 1/10th of real-time for simulation speed
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    // FAST_SIM: Scaled for longer alignment windows (~10-20ms instead of ~3ms)
    // Increased 4x from previous values to slow down drift dynamics
    localparam [21:0] UPDATE_PERIOD_F0 = 22'd3200;   // SR1: 0.8s (moderate)
    localparam [21:0] UPDATE_PERIOD_F1 = 22'd8000;   // SR2: 2.0s (slow - timing ref)
    localparam [21:0] UPDATE_PERIOD_F2 = 22'd16000;  // SR3: 4.0s (SLOWEST - anchor)
    localparam [21:0] UPDATE_PERIOD_F3 = 22'd1600;   // SR4: 0.4s (FASTEST - variable)
    localparam [21:0] UPDATE_PERIOD_F4 = 22'd3200;   // SR5: 0.8s (moderate)
`else
    // Real-time at 4kHz: values in clock cycles
    localparam [21:0] UPDATE_PERIOD_F0 = (FAST_SIM != 0) ? 22'd800  : 22'd8000;   // 2s
    localparam [21:0] UPDATE_PERIOD_F1 = (FAST_SIM != 0) ? 22'd2000 : 22'd20000;  // 5s
    localparam [21:0] UPDATE_PERIOD_F2 = (FAST_SIM != 0) ? 22'd4000 : 22'd40000;  // 10s (SLOWEST)
    localparam [21:0] UPDATE_PERIOD_F3 = (FAST_SIM != 0) ? 22'd400  : 22'd4000;   // 1s (FASTEST)
    localparam [21:0] UPDATE_PERIOD_F4 = (FAST_SIM != 0) ? 22'd800  : 22'd8000;   // 2s
`endif

//-----------------------------------------------------------------------------
// v3.0: Per-Harmonic Step Sizes - STABILITY HIERARCHY
//
// More stable harmonics take smaller steps
//   SR3/SR2: 1 only (most stable)
//   SR1/SR5: 1-2 (moderate)
//   SR4: 1-3 (most variable)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] STEP_MAX_F0 = 18'sd2;  // SR1: 1-2 (moderate)
localparam signed [WIDTH-1:0] STEP_MAX_F1 = 18'sd1;  // SR2: 1 only (stable)
localparam signed [WIDTH-1:0] STEP_MAX_F2 = 18'sd1;  // SR3: 1 only (MOST STABLE)
localparam signed [WIDTH-1:0] STEP_MAX_F3 = 18'sd3;  // SR4: 1-3 (MOST VARIABLE)
localparam signed [WIDTH-1:0] STEP_MAX_F4 = 18'sd2;  // SR5: 1-2 (moderate)

//-----------------------------------------------------------------------------
// v3.0: Per-Harmonic Update Counters
//-----------------------------------------------------------------------------
reg [21:0] update_counter_0, update_counter_1, update_counter_2;
reg [21:0] update_counter_3, update_counter_4;

wire update_tick_0 = (update_counter_0 >= UPDATE_PERIOD_F0);
wire update_tick_1 = (update_counter_1 >= UPDATE_PERIOD_F1);
wire update_tick_2 = (update_counter_2 >= UPDATE_PERIOD_F2);
wire update_tick_3 = (update_counter_3 >= UPDATE_PERIOD_F3);
wire update_tick_4 = (update_counter_4 >= UPDATE_PERIOD_F4);

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
// v3.0: Variable Step Sizes based on per-harmonic STEP_MAX
//-----------------------------------------------------------------------------
// For STEP_MAX=1: always step 1
// For STEP_MAX=2: step 1 or 2 based on LFSR bit
// For STEP_MAX=3: step 1, 2, or 3 based on LFSR bits

// F0: STEP_MAX=2, use bit[2] for 1 or 2
wire signed [WIDTH-1:0] step_0 = lfsr_0[2] ? 18'sd2 : 18'sd1;

// F1: STEP_MAX=1, always 1
wire signed [WIDTH-1:0] step_1 = 18'sd1;

// F2: STEP_MAX=1, always 1 (MOST STABLE)
wire signed [WIDTH-1:0] step_2 = 18'sd1;

// F3: STEP_MAX=3, use bits[3:2] for 1, 2, or 3
wire signed [WIDTH-1:0] step_3 = (lfsr_3[3:2] == 2'b11) ? 18'sd3 :
                                  (lfsr_3[2] ? 18'sd2 : 18'sd1);

// F4: STEP_MAX=2, use bit[2] for 1 or 2
wire signed [WIDTH-1:0] step_4 = lfsr_4[2] ? 18'sd2 : 18'sd1;

//-----------------------------------------------------------------------------
// Random Initialization Offsets
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] init_offset_0, init_offset_1, init_offset_2;
wire signed [WIDTH-1:0] init_offset_3, init_offset_4;

assign init_offset_0 = RANDOM_INIT ? (((LFSR_SEED_0[15:11] - 5'd16) * DRIFT_MAX_F0) >>> 4) : 18'sd0;
assign init_offset_1 = RANDOM_INIT ? (((LFSR_SEED_1[15:11] - 5'd16) * DRIFT_MAX_F1) >>> 4) : 18'sd0;
assign init_offset_2 = RANDOM_INIT ? (((LFSR_SEED_2[15:11] - 5'd16) * DRIFT_MAX_F2) >>> 4) : 18'sd0;
assign init_offset_3 = RANDOM_INIT ? (((LFSR_SEED_3[15:11] - 5'd16) * DRIFT_MAX_F3) >>> 4) : 18'sd0;
assign init_offset_4 = RANDOM_INIT ? (((LFSR_SEED_4[15:11] - 5'd16) * DRIFT_MAX_F4) >>> 4) : 18'sd0;

//-----------------------------------------------------------------------------
// v3.0: Harmonic 0 (SR1) - Moderate stability, event detector
// Update period: 2s, Step: 1-2
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter_0 <= 22'd0;
        lfsr_0 <= LFSR_SEED_0;
        drift_0 <= init_offset_0;
    end else if (clk_en) begin
        if (update_tick_0) begin
            update_counter_0 <= 22'd0;
            lfsr_0 <= {lfsr_0[14:0], fb_0};
            if (dir_0) begin
                if (drift_0 + step_0 <= DRIFT_MAX_F0)
                    drift_0 <= drift_0 + step_0;
                else
                    drift_0 <= drift_0 - step_0;
            end else begin
                if (drift_0 - step_0 >= -DRIFT_MAX_F0)
                    drift_0 <= drift_0 - step_0;
                else
                    drift_0 <= drift_0 + step_0;
            end
        end else begin
            update_counter_0 <= update_counter_0 + 1'b1;
        end
    end
end

//-----------------------------------------------------------------------------
// v3.0: Harmonic 1 (SR2) - Very stable, timing reference
// Update period: 5s, Step: 1 only
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter_1 <= 22'd0;
        lfsr_1 <= LFSR_SEED_1;
        drift_1 <= init_offset_1;
    end else if (clk_en) begin
        if (update_tick_1) begin
            update_counter_1 <= 22'd0;
            lfsr_1 <= {lfsr_1[14:0], fb_1};
            if (dir_1) begin
                if (drift_1 + step_1 <= DRIFT_MAX_F1)
                    drift_1 <= drift_1 + step_1;
                else
                    drift_1 <= drift_1 - step_1;
            end else begin
                if (drift_1 - step_1 >= -DRIFT_MAX_F1)
                    drift_1 <= drift_1 - step_1;
                else
                    drift_1 <= drift_1 + step_1;
            end
        end else begin
            update_counter_1 <= update_counter_1 + 1'b1;
        end
    end
end

//-----------------------------------------------------------------------------
// v3.0: Harmonic 2 (SR3) - MOST STABLE, stability anchor
// Update period: 10s (SLOWEST), Step: 1 only
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter_2 <= 22'd0;
        lfsr_2 <= LFSR_SEED_2;
        drift_2 <= init_offset_2;
    end else if (clk_en) begin
        if (update_tick_2) begin
            update_counter_2 <= 22'd0;
            lfsr_2 <= {lfsr_2[14:0], fb_2};
            if (dir_2) begin
                if (drift_2 + step_2 <= DRIFT_MAX_F2)
                    drift_2 <= drift_2 + step_2;
                else
                    drift_2 <= drift_2 - step_2;
            end else begin
                if (drift_2 - step_2 >= -DRIFT_MAX_F2)
                    drift_2 <= drift_2 - step_2;
                else
                    drift_2 <= drift_2 + step_2;
            end
        end else begin
            update_counter_2 <= update_counter_2 + 1'b1;
        end
    end
end

//-----------------------------------------------------------------------------
// v3.0: Harmonic 3 (SR4) - MOST VARIABLE, arousal modulator
// Update period: 1s (FASTEST), Step: 1-3
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter_3 <= 22'd0;
        lfsr_3 <= LFSR_SEED_3;
        drift_3 <= init_offset_3;
    end else if (clk_en) begin
        if (update_tick_3) begin
            update_counter_3 <= 22'd0;
            lfsr_3 <= {lfsr_3[14:0], fb_3};
            if (dir_3) begin
                if (drift_3 + step_3 <= DRIFT_MAX_F3)
                    drift_3 <= drift_3 + step_3;
                else
                    drift_3 <= drift_3 - step_3;
            end else begin
                if (drift_3 - step_3 >= -DRIFT_MAX_F3)
                    drift_3 <= drift_3 - step_3;
                else
                    drift_3 <= drift_3 + step_3;
            end
        end else begin
            update_counter_3 <= update_counter_3 + 1'b1;
        end
    end
end

//-----------------------------------------------------------------------------
// v3.0: Harmonic 4 (SR5) - Moderate stability, consciousness gate
// Update period: 2s, Step: 1-2
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter_4 <= 22'd0;
        lfsr_4 <= LFSR_SEED_4;
        drift_4 <= init_offset_4;
    end else if (clk_en) begin
        if (update_tick_4) begin
            update_counter_4 <= 22'd0;
            lfsr_4 <= {lfsr_4[14:0], fb_4};
            if (dir_4) begin
                if (drift_4 + step_4 <= DRIFT_MAX_F4)
                    drift_4 <= drift_4 + step_4;
                else
                    drift_4 <= drift_4 - step_4;
            end else begin
                if (drift_4 - step_4 >= -DRIFT_MAX_F4)
                    drift_4 <= drift_4 - step_4;
                else
                    drift_4 <= drift_4 + step_4;
            end
        end else begin
            update_counter_4 <= update_counter_4 + 1'b1;
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

// Individual outputs for boundary detectors
assign omega_dt_f0_actual = omega_0;  // SR1 - f₀ boundary partner
assign omega_dt_f1_actual = omega_1;  // SR2 - timing reference
assign omega_dt_f2_actual = omega_2;  // SR3 - f₂ boundary (stability anchor)
assign omega_dt_f3_actual = omega_3;  // SR4 - arousal modulator
assign omega_dt_f4_actual = omega_4;  // SR5 - f₃ boundary (consciousness gate)

endmodule
