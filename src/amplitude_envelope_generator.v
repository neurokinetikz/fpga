//=============================================================================
// Amplitude Envelope Generator v1.0
//
// Implements Ornstein-Uhlenbeck process for slow stochastic amplitude modulation.
// Creates biological "alpha breathing" effect where oscillator amplitudes
// wax and wane over 2-5 second timescales.
//
// O-U PROCESS (discrete-time approximation):
//   x[n+1] = x[n] + alpha*(mu - x[n]) + sigma*noise
//
// Where:
//   - alpha = dt/tau (mean-reversion rate)
//   - mu = 1.0 (equilibrium = no modulation)
//   - sigma = noise amplitude (state-dependent)
//   - noise = pseudo-random from LFSR
//
// OUTPUT RANGE:
//   - Q14 format: 8192 to 24576 (0.5 to 1.5)
//   - Mean: 16384 (1.0 = no change to MU)
//   - Multiply with MU_DT to get effective modulated MU
//
// USAGE:
//   mu_effective = (mu_dt * envelope) >>> FRAC;
//
// Based on observed EEG alpha band waxing/waning patterns in resting state.
//=============================================================================
`timescale 1ns / 1ps

module amplitude_envelope_generator #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter FAST_SIM = 0
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,                         // 4kHz update rate

    input  wire [15:0] seed,                    // LFSR seed (unique per oscillator)
    input  wire signed [WIDTH-1:0] tau_inv,     // Inverse time constant (state-dependent)

    output reg signed [WIDTH-1:0] envelope      // Range: 0.5 to 1.5 in Q14
);

//-----------------------------------------------------------------------------
// Constants (Q14 format)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] ENVELOPE_MEAN = 18'sd16384;   // 1.0 (equilibrium)
localparam signed [WIDTH-1:0] ENVELOPE_MIN  = 18'sd8192;    // 0.5 (lower bound)
localparam signed [WIDTH-1:0] ENVELOPE_MAX  = 18'sd24576;   // 1.5 (upper bound)

// Mean-reversion rate alpha = dt/tau
// For tau = 3s at 4kHz: alpha = 1/(3*4000) = 0.000083 → ~1.4 in Q14
// We'll use tau_inv input to allow state-dependent time constants
// tau_inv = round(16384 / (tau_seconds * 4000))
// NORMAL: tau = 3s → tau_inv = 1
// MEDITATION: tau = 5s → tau_inv = 0.8 (round to 1)
// PSYCHEDELIC: tau = 2s → tau_inv = 2
localparam signed [WIDTH-1:0] DEFAULT_TAU_INV = 18'sd1;  // ~3 second tau

// Noise amplitude (sigma * sqrt(dt) scaled)
// Larger = more variation, smaller = smoother
// In Q14, value of ~100 gives visible ±0.15 modulation at tau=3s
`ifdef FAST_SIM
    localparam signed [WIDTH-1:0] NOISE_AMPLITUDE = 18'sd150;  // More visible in fast sim
`else
    localparam signed [WIDTH-1:0] NOISE_AMPLITUDE = 18'sd100;
`endif

//-----------------------------------------------------------------------------
// Decimation Counter (optional: update envelope slower than 4kHz)
// Even at 4kHz, with slow tau, we get smooth envelopes
// But decimating by 4 reduces computation without visible change
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    localparam [2:0] DECIMATE_BITS = 3'd2;  // Update every 4 clk_en
`else
    localparam [2:0] DECIMATE_BITS = 3'd4;  // Update every 16 clk_en
`endif

reg [DECIMATE_BITS-1:0] decimate_counter;
wire decimate_tick;

assign decimate_tick = (decimate_counter == 0);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        decimate_counter <= 0;
    end else if (clk_en) begin
        decimate_counter <= decimate_counter + 1'b1;
    end
end

//-----------------------------------------------------------------------------
// LFSR Random Number Generator (16-bit Galois)
// Polynomial: x^16 + x^14 + x^13 + x^11 + 1
//-----------------------------------------------------------------------------
reg [15:0] lfsr;
wire lfsr_fb;

assign lfsr_fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr <= (seed != 16'd0) ? seed : 16'hACE1;  // Avoid all-zero state
    end else if (clk_en && decimate_tick) begin
        lfsr <= {lfsr[14:0], lfsr_fb};
    end
end

//-----------------------------------------------------------------------------
// Noise Term Generation
// Convert LFSR bits to centered noise [-NOISE_AMPLITUDE, +NOISE_AMPLITUDE]
// Use sign bit from lfsr[15], magnitude from lfsr[7:0]
//-----------------------------------------------------------------------------
wire noise_sign;
wire [7:0] noise_mag;
wire signed [WIDTH-1:0] noise_raw;
wire signed [2*WIDTH-1:0] noise_scaled;
wire signed [WIDTH-1:0] noise_term;

assign noise_sign = lfsr[15];
assign noise_mag = lfsr[7:0];

// Scale noise_mag [0,255] to [-1, +1] range, then multiply by NOISE_AMPLITUDE
// noise_raw in range [-128, +127] after centering
assign noise_raw = noise_sign ? -{{(WIDTH-8){1'b0}}, noise_mag} : {{(WIDTH-8){1'b0}}, noise_mag};

// Scale by NOISE_AMPLITUDE and normalize
// noise_scaled = noise_raw * NOISE_AMPLITUDE / 128
assign noise_scaled = noise_raw * NOISE_AMPLITUDE;
assign noise_term = noise_scaled >>> 7;  // Divide by 128

//-----------------------------------------------------------------------------
// Mean-Reversion Term
// alpha * (mu - x) where alpha = tau_inv (scaled appropriately)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] deviation;
wire signed [2*WIDTH-1:0] reversion_raw;
wire signed [WIDTH-1:0] reversion_term;
wire signed [WIDTH-1:0] tau_effective;

assign deviation = ENVELOPE_MEAN - envelope;

// Use input tau_inv if provided, else default
assign tau_effective = (tau_inv > 18'sd0) ? tau_inv : DEFAULT_TAU_INV;

// reversion = tau_inv * deviation (in Q14, divide by 16384)
assign reversion_raw = tau_effective * deviation;
assign reversion_term = reversion_raw >>> FRAC;

//-----------------------------------------------------------------------------
// O-U Update: x[n+1] = x[n] + reversion + noise
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] envelope_next_raw;
wire signed [WIDTH-1:0] envelope_next;

assign envelope_next_raw = envelope + reversion_term + noise_term;

// Clamp to valid range [0.5, 1.5]
assign envelope_next = (envelope_next_raw < ENVELOPE_MIN) ? ENVELOPE_MIN :
                       (envelope_next_raw > ENVELOPE_MAX) ? ENVELOPE_MAX :
                       envelope_next_raw;

//-----------------------------------------------------------------------------
// State Update
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        envelope <= ENVELOPE_MEAN;  // Start at 1.0 (no modulation)
    end else if (clk_en && decimate_tick) begin
        envelope <= envelope_next;
    end
end

endmodule
