//=============================================================================
// Thalamic Frequency Drift Generator - v1.1
//
// v1.1 CHANGES (Three-Boundary Architecture):
// - SEEKER RATE: Theta now drifts 3× faster than SR1 (reference)
//   SR1 updates every 2s (UPDATE_PERIOD = 8000)
//   Theta updates every 0.625s (UPDATE_PERIOD = 2500) - 3.2× faster
// - This implements the "seeker-reference" model where internal oscillators
//   scan faster than the external SR reference, creating alignment windows
//
// v1.0 (Dual Alignment Ignition - v12.2):
// - Adds bounded random walk frequency drift to the theta oscillator
// - Enables stochastic alignment between sqrt(theta*alpha) and SR1
//
// THETA FREQUENCY (derived from SR1 = 7.75 Hz):
//   theta = SR1 / sqrt(phi) = 7.75 / 1.272 = 6.09 Hz
//   OMEGA_DT = round(2*pi * 6.09 * 0.00025 * 16384) = 157
//
// DRIFT MODEL:
// - Bounded random walk with reflecting boundaries
// - Update rate: 0.625s (SEEKER - 3× faster than SR1's 2s)
// - Drift range: +/-0.5 Hz (matches SR1 for boundary alignment)
// - Fast jitter: +/-0.2 Hz per sample for naturalness
// - Random initialization: Prevents startup alignment
//
// ALIGNMENT WINDOW BEHAVIOR:
// With theta/alpha drifting at ~0.125 Hz/sec and SR1 at ~0.039 Hz/sec,
// alignment windows of 5-15 seconds emerge naturally.
//=============================================================================
`timescale 1ns / 1ps

module thalamic_frequency_drift #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter FAST_SIM = 0,
    parameter RANDOM_INIT = 1,  // Enable random start position within drift bounds
    parameter [15:0] SEED_OFFSET = 16'h0000  // XOR'd with base seeds for variation
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Slow drift offset (bounded random walk, updates slowly)
    output wire signed [WIDTH-1:0] theta_drift,

    // Fast jitter (cycle-by-cycle noise)
    output wire signed [WIDTH-1:0] theta_jitter,

    // Combined actual omega_dt for alignment detector
    output wire signed [WIDTH-1:0] omega_dt_theta_actual
);

//-----------------------------------------------------------------------------
// Theta Center Frequency
// Derived from SR1 = 7.75 Hz: theta = 7.75 / sqrt(phi) = 6.09 Hz
// OMEGA_DT = round(2*pi * 6.09 * 0.00025 * 16384) = 157
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] OMEGA_CENTER_THETA = 18'sd157;  // 6.09 Hz

//-----------------------------------------------------------------------------
// Drift Range
// +/-0.5 Hz in OMEGA_DT units: round(2*pi * 0.5 * 0.00025 * 16384) = +/-13
// Matches SR1 drift range for optimal boundary alignment probability
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] DRIFT_MAX = 18'sd13;  // +/-0.5 Hz

//-----------------------------------------------------------------------------
// Fast Jitter Range
// +/-0.2 Hz in OMEGA_DT units = +/-5
// Small per-sample noise for natural variability
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] JITTER_MAX = 18'sd5;  // +/-0.2 Hz

//-----------------------------------------------------------------------------
// Update Period (v1.1: SEEKER RATE - 3× faster than SR1)
// Theta drifts 3.2× faster than SR1 (8000) to create "seeker-reference" dynamics
// FAST_SIM: 250 clk_en = 0.0625s at 4kHz (was 800)
// Real-time: 2500 clk_en = 0.625s at 4kHz (3× faster than SR1's 8000 = 2s)
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    localparam [21:0] UPDATE_PERIOD = 22'd1000;  // 0.25s (3× faster than SR1's 3200)
`else
    localparam [21:0] UPDATE_PERIOD = (FAST_SIM != 0) ? 22'd250 : 22'd2500;  // 0.625s
`endif

//-----------------------------------------------------------------------------
// LFSR Seed (unique for theta, different from cortical and SR seeds)
// Base seed XOR'd with SEED_OFFSET for variation across runs
//-----------------------------------------------------------------------------
localparam [15:0] LFSR_SEED = 16'hC3A7 ^ SEED_OFFSET;

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
// LFSR for Random Walk
//-----------------------------------------------------------------------------
reg [15:0] lfsr;

// LFSR feedback: x^16 + x^14 + x^13 + x^11 + 1
wire fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

// Step direction from LSB
wire dir = lfsr[0];

// Variable step size (1-2 for theta, conservative)
wire signed [WIDTH-1:0] step = lfsr[1] ? 18'sd2 : 18'sd1;

//-----------------------------------------------------------------------------
// Random Initialization
// Use LFSR seed bits to select initial position within drift bounds
// Maps seed bits [15:11] (0-31) to [-DRIFT_MAX, +DRIFT_MAX]
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] init_offset;
assign init_offset = RANDOM_INIT ?
    (((LFSR_SEED[15:11] - 5'd16) * DRIFT_MAX) >>> 4) : 18'sd0;
// LFSR_SEED[15:11] = 5'b11000 = 24, so (24-16)*13/16 = 8*13/16 = 6.5 -> 6

//-----------------------------------------------------------------------------
// Drift State
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] drift_reg;
reg signed [WIDTH-1:0] next_drift;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr <= LFSR_SEED;
        drift_reg <= init_offset;  // Random initial position
    end else if (clk_en && update_tick) begin
        lfsr <= {lfsr[14:0], fb};

        // Compute next drift with step
        next_drift = dir ? (drift_reg + step) : (drift_reg - step);

        // Clamp to bounds
        if (next_drift > DRIFT_MAX)
            drift_reg <= DRIFT_MAX;
        else if (next_drift < -DRIFT_MAX)
            drift_reg <= -DRIFT_MAX;
        else
            drift_reg <= next_drift;
    end
end

//-----------------------------------------------------------------------------
// Fast Jitter LFSR (separate from drift LFSR)
// Base seed XOR'd with rotated SEED_OFFSET for independence from drift
//-----------------------------------------------------------------------------
localparam [15:0] JLFSR_SEED = 16'h5E91 ^ {SEED_OFFSET[7:0], SEED_OFFSET[15:8]};  // byte swap

reg [15:0] jlfsr;
wire jfb = jlfsr[15] ^ jlfsr[13] ^ jlfsr[12] ^ jlfsr[10];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        jlfsr <= JLFSR_SEED;
    end else if (clk_en) begin
        jlfsr <= {jlfsr[14:0], jfb};
    end
end

//-----------------------------------------------------------------------------
// Fast Jitter Computation
// Use 2 bits from LFSR to create values in range [-5, +5]
// Triangular distribution: (bit1 ? +3 : -3) + (bit0 ? +2 : -2)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] jitter_raw;
assign jitter_raw = (jlfsr[1] ? 18'sd3 : -18'sd3) + (jlfsr[0] ? 18'sd2 : -18'sd2);

// Clamp jitter (should already be in range, but safety check)
wire signed [WIDTH-1:0] jitter_clamped;
assign jitter_clamped = (jitter_raw > JITTER_MAX) ? JITTER_MAX :
                        (jitter_raw < -JITTER_MAX) ? -JITTER_MAX : jitter_raw;

//-----------------------------------------------------------------------------
// Output Assignments
//-----------------------------------------------------------------------------
assign theta_drift = drift_reg;
assign theta_jitter = jitter_clamped;
assign omega_dt_theta_actual = OMEGA_CENTER_THETA + drift_reg + jitter_clamped;

endmodule
