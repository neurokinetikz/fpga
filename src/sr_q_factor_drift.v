//=============================================================================
// SR Q-Factor Drift Generator - v1.0
//
// Implements Ornstein-Uhlenbeck process for per-harmonic Q-factor drift.
// Creates realistic SR Q-factor variations matching geophysical observations.
//
// STABILITY HIERARCHY (matches sr_frequency_drift.v):
//   SR3 (f2, 20 Hz): MOST STABLE - slowest tau, smallest drift
//   SR2 (f1, 13.75 Hz): Very stable
//   SR1 (f0, 7.75 Hz): Moderate
//   SR5 (f4, 32 Hz): Moderate
//   SR4 (f3, 25 Hz): MOST VARIABLE - fastest tau, largest drift
//
// Q-FACTOR CENTERS (from real geophysical SR data):
//   Q0 = 7.5  (SR1, 7.75 Hz)
//   Q1 = 9.5  (SR2, 13.75 Hz)
//   Q2 = 15.5 (SR3, 20 Hz) - ANCHOR
//   Q3 = 8.5  (SR4, 25 Hz)
//   Q4 = 7.0  (SR5, 32 Hz)
//
// Q-FACTOR RANGES (from real observations):
//   Q1: 5-16 (F1 in real data)
//   Q3: 5-21 (F3 in real data)
//
// O-U PROCESS:
//   q[n+1] = q[n] + tau_inv*(q_center - q[n]) + sigma*noise
//
// OUTPUTS:
//   q_factor_packed: Normalized Q values (Q14, ~0.5-1.0 relative to anchor)
//   q_scaled_packed: Integer Q values for CSV output (range 5-20)
//=============================================================================
`timescale 1ns / 1ps

module sr_q_factor_drift #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_HARMONICS = 5,
    parameter FAST_SIM = 0,
    parameter RANDOM_INIT = 1,
    parameter [15:0] SEED_OFFSET = 16'h0000
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Q-factor outputs (Q14 format, normalized to Q2 anchor)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] q_factor_packed,

    // Integer Q values for CSV export (range 5-25)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] q_scaled_packed,

    // Individual Q outputs for debugging
    output wire signed [WIDTH-1:0] q_f0_scaled,
    output wire signed [WIDTH-1:0] q_f1_scaled,
    output wire signed [WIDTH-1:0] q_f2_scaled,
    output wire signed [WIDTH-1:0] q_f3_scaled,
    output wire signed [WIDTH-1:0] q_f4_scaled
);

//-----------------------------------------------------------------------------
// Q-Factor Centers (Q14 format, normalized so Q2=1.0)
// Real data: Q0=7.5, Q1=9.5, Q2=15.5 (anchor), Q3=8.5, Q4=7.0
// Normalized: Q0=0.484, Q1=0.613, Q2=1.0, Q3=0.549, Q4=0.452
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] Q_CENTER_F0 = 18'sd7929;   // 0.484 (Q=7.5)
localparam signed [WIDTH-1:0] Q_CENTER_F1 = 18'sd10051;  // 0.613 (Q=9.5)
localparam signed [WIDTH-1:0] Q_CENTER_F2 = 18'sd16384;  // 1.0   (Q=15.5, ANCHOR)
localparam signed [WIDTH-1:0] Q_CENTER_F3 = 18'sd8995;   // 0.549 (Q=8.5)
localparam signed [WIDTH-1:0] Q_CENTER_F4 = 18'sd7405;   // 0.452 (Q=7.0)

//-----------------------------------------------------------------------------
// Q-Factor Drift Ranges (Q14, fraction of center Q value)
// From real data: Q1 ranges 5-16 (~55% variation), Q3 ranges 5-21 (~60%)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] Q_DRIFT_MAX_F0 = 18'sd4915;   // ±0.30 (Q varies 5-10)
localparam signed [WIDTH-1:0] Q_DRIFT_MAX_F1 = 18'sd6554;   // ±0.40 (Q varies 6-14)
localparam signed [WIDTH-1:0] Q_DRIFT_MAX_F2 = 18'sd3277;   // ±0.20 (Q varies 12-18, STABLE)
localparam signed [WIDTH-1:0] Q_DRIFT_MAX_F3 = 18'sd4915;   // ±0.30 (Q varies 6-11)
localparam signed [WIDTH-1:0] Q_DRIFT_MAX_F4 = 18'sd5734;   // ±0.35 (Q varies 4.5-9.5)

//-----------------------------------------------------------------------------
// O-U Time Constants (tau_inv = dt/tau)
// Stability hierarchy: tau proportional to how stable the harmonic is
// At 4kHz: tau_inv = round(16384 / (tau_seconds * 4000))
//
// FAST_SIM values scaled for faster dynamics while preserving hierarchy
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    // Fast sim: tau reduced by ~4x for visible dynamics
    localparam signed [WIDTH-1:0] TAU_INV_F0 = 18'sd33;   // tau ~120s (moderate)
    localparam signed [WIDTH-1:0] TAU_INV_F1 = 18'sd16;   // tau ~250s (stable)
    localparam signed [WIDTH-1:0] TAU_INV_F2 = 18'sd8;    // tau ~500s (MOST STABLE)
    localparam signed [WIDTH-1:0] TAU_INV_F3 = 18'sd65;   // tau ~60s (FASTEST)
    localparam signed [WIDTH-1:0] TAU_INV_F4 = 18'sd33;   // tau ~120s (moderate)
`else
    // Real-time: Q changes over minutes to tens of minutes
    localparam signed [WIDTH-1:0] TAU_INV_F0 = 18'sd8;    // tau ~500s (~8 min)
    localparam signed [WIDTH-1:0] TAU_INV_F1 = 18'sd4;    // tau ~1000s (~17 min)
    localparam signed [WIDTH-1:0] TAU_INV_F2 = 18'sd2;    // tau ~2000s (~33 min, SLOWEST)
    localparam signed [WIDTH-1:0] TAU_INV_F3 = 18'sd16;   // tau ~250s (~4 min, FASTEST)
    localparam signed [WIDTH-1:0] TAU_INV_F4 = 18'sd8;    // tau ~500s (~8 min)
`endif

//-----------------------------------------------------------------------------
// Noise Amplitudes (sigma, per-harmonic)
// More variable harmonics have higher noise
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    localparam signed [WIDTH-1:0] NOISE_AMP_F0 = 18'sd120;  // Moderate
    localparam signed [WIDTH-1:0] NOISE_AMP_F1 = 18'sd100;  // Low (stable)
    localparam signed [WIDTH-1:0] NOISE_AMP_F2 = 18'sd60;   // Lowest (ANCHOR)
    localparam signed [WIDTH-1:0] NOISE_AMP_F3 = 18'sd180;  // Highest (VARIABLE)
    localparam signed [WIDTH-1:0] NOISE_AMP_F4 = 18'sd140;  // Moderate-high
`else
    localparam signed [WIDTH-1:0] NOISE_AMP_F0 = 18'sd80;
    localparam signed [WIDTH-1:0] NOISE_AMP_F1 = 18'sd60;
    localparam signed [WIDTH-1:0] NOISE_AMP_F2 = 18'sd40;   // Lowest (ANCHOR)
    localparam signed [WIDTH-1:0] NOISE_AMP_F3 = 18'sd120;  // Highest (VARIABLE)
    localparam signed [WIDTH-1:0] NOISE_AMP_F4 = 18'sd100;
`endif

//-----------------------------------------------------------------------------
// Decimation: Q-factor changes slowly, update every 64 clk_en cycles
// At 4kHz, this is ~16ms per update (62.5 Hz update rate)
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    localparam [5:0] DECIMATE_MAX = 6'd15;   // Update every 16 cycles in fast sim
`else
    localparam [5:0] DECIMATE_MAX = 6'd63;   // Update every 64 cycles normally
`endif

reg [5:0] decimate_counter;
wire decimate_tick;

assign decimate_tick = (decimate_counter == 6'd0);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        decimate_counter <= 6'd0;
    end else if (clk_en) begin
        if (decimate_counter >= DECIMATE_MAX)
            decimate_counter <= 6'd0;
        else
            decimate_counter <= decimate_counter + 1'b1;
    end
end

//-----------------------------------------------------------------------------
// LFSR Seeds (different from sr_frequency_drift.v for independence)
//-----------------------------------------------------------------------------
localparam [15:0] LFSR_SEED_Q0 = 16'hF1D9 ^ SEED_OFFSET;
localparam [15:0] LFSR_SEED_Q1 = 16'h8A2E ^ {SEED_OFFSET[7:0], SEED_OFFSET[15:8]};
localparam [15:0] LFSR_SEED_Q2 = 16'h3C7B ^ {SEED_OFFSET[11:0], SEED_OFFSET[15:12]};
localparam [15:0] LFSR_SEED_Q3 = 16'hE5A4 ^ {SEED_OFFSET[3:0], SEED_OFFSET[15:4]};
localparam [15:0] LFSR_SEED_Q4 = 16'h6D18 ^ ~SEED_OFFSET;

//-----------------------------------------------------------------------------
// Per-Harmonic State
//-----------------------------------------------------------------------------
reg [15:0] lfsr_0, lfsr_1, lfsr_2, lfsr_3, lfsr_4;
reg signed [WIDTH-1:0] q_state_0, q_state_1, q_state_2, q_state_3, q_state_4;

// LFSR feedback: x^16 + x^14 + x^13 + x^11 + 1
wire fb_0 = lfsr_0[15] ^ lfsr_0[13] ^ lfsr_0[12] ^ lfsr_0[10];
wire fb_1 = lfsr_1[15] ^ lfsr_1[13] ^ lfsr_1[12] ^ lfsr_1[10];
wire fb_2 = lfsr_2[15] ^ lfsr_2[13] ^ lfsr_2[12] ^ lfsr_2[10];
wire fb_3 = lfsr_3[15] ^ lfsr_3[13] ^ lfsr_3[12] ^ lfsr_3[10];
wire fb_4 = lfsr_4[15] ^ lfsr_4[13] ^ lfsr_4[12] ^ lfsr_4[10];

//-----------------------------------------------------------------------------
// Random Initialization Offsets
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] init_offset_0, init_offset_1, init_offset_2;
wire signed [WIDTH-1:0] init_offset_3, init_offset_4;

// Scale seed bits to initial offset within drift range
// (seed[15:11] - 16) * drift_max / 16
assign init_offset_0 = RANDOM_INIT ? (((LFSR_SEED_Q0[15:11] - 5'd16) * Q_DRIFT_MAX_F0) >>> 4) : 18'sd0;
assign init_offset_1 = RANDOM_INIT ? (((LFSR_SEED_Q1[15:11] - 5'd16) * Q_DRIFT_MAX_F1) >>> 4) : 18'sd0;
assign init_offset_2 = RANDOM_INIT ? (((LFSR_SEED_Q2[15:11] - 5'd16) * Q_DRIFT_MAX_F2) >>> 4) : 18'sd0;
assign init_offset_3 = RANDOM_INIT ? (((LFSR_SEED_Q3[15:11] - 5'd16) * Q_DRIFT_MAX_F3) >>> 4) : 18'sd0;
assign init_offset_4 = RANDOM_INIT ? (((LFSR_SEED_Q4[15:11] - 5'd16) * Q_DRIFT_MAX_F4) >>> 4) : 18'sd0;

//-----------------------------------------------------------------------------
// O-U Process Functions (shared computation pattern)
//-----------------------------------------------------------------------------

// Compute noise term from LFSR: [-noise_amp, +noise_amp]
function signed [WIDTH-1:0] compute_noise;
    input [15:0] lfsr;
    input signed [WIDTH-1:0] noise_amp;
    reg signed [WIDTH-1:0] noise_raw;
    reg signed [2*WIDTH-1:0] noise_scaled;
    begin
        // lfsr[7:0] gives magnitude, lfsr[15] gives sign
        noise_raw = lfsr[15] ? -{{(WIDTH-8){1'b0}}, lfsr[7:0]} : {{(WIDTH-8){1'b0}}, lfsr[7:0]};
        noise_scaled = noise_raw * noise_amp;
        compute_noise = noise_scaled >>> 7;  // Divide by 128
    end
endfunction

// Compute next O-U state with clamping
function signed [WIDTH-1:0] ou_update;
    input signed [WIDTH-1:0] current;
    input signed [WIDTH-1:0] center;
    input signed [WIDTH-1:0] tau_inv;
    input signed [WIDTH-1:0] noise;
    input signed [WIDTH-1:0] drift_max;
    reg signed [WIDTH-1:0] deviation;
    reg signed [2*WIDTH-1:0] reversion_raw;
    reg signed [WIDTH-1:0] reversion;
    reg signed [WIDTH-1:0] next_raw;
    reg signed [WIDTH-1:0] q_min;
    reg signed [WIDTH-1:0] q_max;
    begin
        // Mean reversion term
        deviation = center - current;
        reversion_raw = tau_inv * deviation;
        reversion = reversion_raw >>> FRAC;

        // Update
        next_raw = current + reversion + noise;

        // Clamp to [center - drift_max, center + drift_max]
        q_min = center - drift_max;
        q_max = center + drift_max;
        if (next_raw < q_min)
            ou_update = q_min;
        else if (next_raw > q_max)
            ou_update = q_max;
        else
            ou_update = next_raw;
    end
endfunction

//-----------------------------------------------------------------------------
// Harmonic 0 (SR1, f0, 7.75 Hz) - Moderate stability
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] noise_0 = compute_noise(lfsr_0, NOISE_AMP_F0);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_0 <= (LFSR_SEED_Q0 != 16'd0) ? LFSR_SEED_Q0 : 16'hF1D9;
        q_state_0 <= Q_CENTER_F0 + init_offset_0;
    end else if (clk_en && decimate_tick) begin
        lfsr_0 <= {lfsr_0[14:0], fb_0};
        q_state_0 <= ou_update(q_state_0, Q_CENTER_F0, TAU_INV_F0, noise_0, Q_DRIFT_MAX_F0);
    end
end

//-----------------------------------------------------------------------------
// Harmonic 1 (SR2, f1, 13.75 Hz) - Very stable (timing reference)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] noise_1 = compute_noise(lfsr_1, NOISE_AMP_F1);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_1 <= (LFSR_SEED_Q1 != 16'd0) ? LFSR_SEED_Q1 : 16'h8A2E;
        q_state_1 <= Q_CENTER_F1 + init_offset_1;
    end else if (clk_en && decimate_tick) begin
        lfsr_1 <= {lfsr_1[14:0], fb_1};
        q_state_1 <= ou_update(q_state_1, Q_CENTER_F1, TAU_INV_F1, noise_1, Q_DRIFT_MAX_F1);
    end
end

//-----------------------------------------------------------------------------
// Harmonic 2 (SR3, f2, 20 Hz) - MOST STABLE (stability anchor)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] noise_2 = compute_noise(lfsr_2, NOISE_AMP_F2);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_2 <= (LFSR_SEED_Q2 != 16'd0) ? LFSR_SEED_Q2 : 16'h3C7B;
        q_state_2 <= Q_CENTER_F2 + init_offset_2;
    end else if (clk_en && decimate_tick) begin
        lfsr_2 <= {lfsr_2[14:0], fb_2};
        q_state_2 <= ou_update(q_state_2, Q_CENTER_F2, TAU_INV_F2, noise_2, Q_DRIFT_MAX_F2);
    end
end

//-----------------------------------------------------------------------------
// Harmonic 3 (SR4, f3, 25 Hz) - MOST VARIABLE (arousal modulator)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] noise_3 = compute_noise(lfsr_3, NOISE_AMP_F3);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_3 <= (LFSR_SEED_Q3 != 16'd0) ? LFSR_SEED_Q3 : 16'hE5A4;
        q_state_3 <= Q_CENTER_F3 + init_offset_3;
    end else if (clk_en && decimate_tick) begin
        lfsr_3 <= {lfsr_3[14:0], fb_3};
        q_state_3 <= ou_update(q_state_3, Q_CENTER_F3, TAU_INV_F3, noise_3, Q_DRIFT_MAX_F3);
    end
end

//-----------------------------------------------------------------------------
// Harmonic 4 (SR5, f4, 32 Hz) - Moderate stability (consciousness gate)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] noise_4 = compute_noise(lfsr_4, NOISE_AMP_F4);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_4 <= (LFSR_SEED_Q4 != 16'd0) ? LFSR_SEED_Q4 : 16'h6D18;
        q_state_4 <= Q_CENTER_F4 + init_offset_4;
    end else if (clk_en && decimate_tick) begin
        lfsr_4 <= {lfsr_4[14:0], fb_4};
        q_state_4 <= ou_update(q_state_4, Q_CENTER_F4, TAU_INV_F4, noise_4, Q_DRIFT_MAX_F4);
    end
end

//-----------------------------------------------------------------------------
// Q-Factor Scaling to Integer (for CSV output)
// q_scaled = q_state * 15.5 (the anchor Q value)
// Implemented as: q_scaled = (q_state * 31) >> 1 >> FRAC
//                           = (q_state * 31) >> 15
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] q_scaled_0, q_scaled_1, q_scaled_2, q_scaled_3, q_scaled_4;

// Scale from Q14 normalized to integer Q value
// q_state in Q14, multiply by 15.5 (anchor Q), divide by 16384
// = q_state * 15.5 / 16384 = q_state * 31 / 32768
wire signed [2*WIDTH-1:0] q_prod_0 = q_state_0 * 18'sd31;
wire signed [2*WIDTH-1:0] q_prod_1 = q_state_1 * 18'sd31;
wire signed [2*WIDTH-1:0] q_prod_2 = q_state_2 * 18'sd31;
wire signed [2*WIDTH-1:0] q_prod_3 = q_state_3 * 18'sd31;
wire signed [2*WIDTH-1:0] q_prod_4 = q_state_4 * 18'sd31;

assign q_scaled_0 = q_prod_0 >>> 15;  // Integer Q value
assign q_scaled_1 = q_prod_1 >>> 15;
assign q_scaled_2 = q_prod_2 >>> 15;
assign q_scaled_3 = q_prod_3 >>> 15;
assign q_scaled_4 = q_prod_4 >>> 15;

//-----------------------------------------------------------------------------
// Output Packing
//-----------------------------------------------------------------------------
assign q_factor_packed = {q_state_4, q_state_3, q_state_2, q_state_1, q_state_0};
assign q_scaled_packed = {q_scaled_4, q_scaled_3, q_scaled_2, q_scaled_1, q_scaled_0};

// Individual outputs for debugging
assign q_f0_scaled = q_scaled_0;
assign q_f1_scaled = q_scaled_1;
assign q_f2_scaled = q_scaled_2;
assign q_f3_scaled = q_scaled_3;
assign q_f4_scaled = q_scaled_4;

endmodule
