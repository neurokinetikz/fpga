//=============================================================================
// Thalamus Module - v8.1 with Theta Phase Multiplexing + SR Frequency Drift
//
// NEUROPHYSIOLOGICAL BASIS:
// "Layer 4 shows characteristic current sinks... with gamma and theta
// oscillations dominating this feedforward processing layer"
// "Gamma is not present in LGN... gamma is an emergent property of cortex"
//
// v8.1: SR FREQUENCY DRIFT SUPPORT
// - Accepts external drifting omega_dt values from sr_frequency_drift module
// - Models realistic SR frequency variation (hours-scale random walk)
// - Natural detuning between SR and neural oscillators prevents unrealistic
//   high coherence from exact frequency matches
//
// v8.0 THETA PHASE MULTIPLEXING (Dupret et al. 2025):
// - Divides theta cycle into 8 discrete phases (theta_phase[2:0])
// - Enables fine-grained encoding/retrieval gating in CA3
// - Phases 0-3: positive theta (encoding-dominant window)
// - Phases 4-7: negative theta (retrieval-dominant window)
// - Supports temporal multiplexing: different computations at different phases
//
// v7.4 CONTINUOUS GAIN BOOST:
// - Replaces binary SIE gain switching with continuous scaling
// - Per-harmonic gain = sigmoid(coherence) × beta_factor
// - Gains sum independently, total boost clamped to 2.0×
// - More biologically plausible: graded response to coherence levels
//
// v7.3 MULTI-HARMONIC SCHUMANN RESONANCE BANK:
// - 5 SR harmonics at observed frequencies (7.6, 13.75, 20, 25, 32 Hz)
// - Each harmonic couples to corresponding EEG band:
//   f₀→theta, f₁→alpha, f₂→low beta, f₃→high beta, f₄→gamma
// - Per-harmonic coherence and SIE detection
// - Aggregate SIE when ANY harmonic achieves high coherence + beta quiet
//
// v7.2 STOCHASTIC RESONANCE MODEL (preserved):
// - Beta amplitude modulates the coupling gate (high beta masks SR)
// - When beta quiets (meditation), stochastic resonance enables detection
// - f₀ entrains theta when beta is at optimal quiet level
//
// Key insight: Brain doesn't generate SR — it TUNES INTO the external
// Schumann field when beta activity reaches optimal (quiet) levels.
//
// theta_x also feeds CA3 phase memory for learn/recall gating
//=============================================================================
`timescale 1ns / 1ps

module thalamus #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_HARMONICS = 5,
    parameter ENABLE_STOCHASTIC = 1,  // Enable stochastic noise injection to SR bank
    parameter ENABLE_DRIFT = 1        // Enable SR frequency drift
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    input  wire signed [WIDTH-1:0] sensory_input,
    input  wire signed [WIDTH-1:0] l6_alpha_feedback,
    input  wire signed [WIDTH-1:0] mu_dt,

    // v8.1: Drifting omega_dt values from sr_frequency_drift (packed: 5 × 18 bits)
    input  wire signed [NUM_HARMONICS*WIDTH-1:0] omega_dt_packed,

    // v7.3: Multi-harmonic SR field inputs (packed: 5 × 18 bits = 90 bits)
    input  wire signed [NUM_HARMONICS*WIDTH-1:0] sr_field_packed,

    // Stochastic noise inputs for SR bank (packed: 5 × 18 bits = 90 bits)
    input  wire signed [NUM_HARMONICS*WIDTH-1:0] noise_packed,

    // v7.2 compatibility: Single SR field input (uses f₀ only)
    input  wire signed [WIDTH-1:0] sr_field_input,

    // v7.2: Beta amplitude from cortical L5 (for SR gating)
    input  wire signed [WIDTH-1:0] beta_amplitude,

    // v7.3: Cortical oscillator states for per-band coherence
    input  wire signed [WIDTH-1:0] alpha_x, alpha_y,        // L6 ~10 Hz
    input  wire signed [WIDTH-1:0] beta_low_x, beta_low_y,  // L5a ~15 Hz
    input  wire signed [WIDTH-1:0] beta_high_x, beta_high_y, // L5b ~25 Hz
    input  wire signed [WIDTH-1:0] gamma_x, gamma_y,        // L4 ~32 Hz

    // Theta outputs
    output wire signed [WIDTH-1:0] theta_gated_output,
    output wire signed [WIDTH-1:0] theta_x,
    output wire signed [WIDTH-1:0] theta_y,
    output wire signed [WIDTH-1:0] theta_amplitude,

    // v8.0: Theta phase output (8 phases per cycle)
    // Phase 0-1: rising to peak (early encoding)
    // Phase 2-3: falling from peak (late encoding)
    // Phase 4-5: falling to trough (early retrieval)
    // Phase 6-7: rising from trough (late retrieval)
    output wire [2:0] theta_phase,

    // f₀ SR Reference outputs (driven by external field) - v7.2 compatibility
    output wire signed [WIDTH-1:0] f0_x,
    output wire signed [WIDTH-1:0] f0_y,
    output wire signed [WIDTH-1:0] f0_amplitude,

    // v7.3: Multi-harmonic outputs (packed)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sr_f_x_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sr_f_y_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sr_amplitude_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sr_coherence_packed,

    // v7.3: Per-harmonic SIE status
    output wire [NUM_HARMONICS-1:0] sie_per_harmonic,
    output wire [NUM_HARMONICS-1:0] coherence_mask,

    // SR Coupling indicators (v7.2 compatibility + v7.3 aggregate)
    output wire signed [WIDTH-1:0] sr_coherence,      // f₀ coherence (v7.2 compat)
    output wire                    sr_amplification,  // SIE active (any harmonic)
    output wire                    beta_quiet         // Beta below threshold (SR-ready)
);

//-----------------------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------------------

// OMEGA_DT for 5.89 Hz theta: ω×dt = 2π×5.89×0.00025 = 0.00925 → Q14: 152
localparam signed [WIDTH-1:0] OMEGA_DT_THETA = 18'sd152;  // 4 kHz update rate

localparam signed [WIDTH-1:0] HALF = 18'sd8192;
localparam signed [WIDTH-1:0] GAIN_BASELINE = 18'sd16384;
localparam signed [WIDTH-1:0] ALPHA_COUPLING = 18'sd4915;

// Entrainment coupling strength: f₀ → θ (0.125 in Q14)
localparam signed [WIDTH-1:0] K_ENTRAIN = 18'sd2048;

// Amplification gain: 1.5× in Q14 (models SIE 4-5× power boost, conservative)
localparam signed [WIDTH-1:0] AMPLIFICATION_GAIN = 18'sd24576;
// Baseline gain: 1.0× in Q14
localparam signed [WIDTH-1:0] SR_BASELINE_GAIN = 18'sd16384;

//-----------------------------------------------------------------------------
// v7.3: Build SR field input - use packed if non-zero, else replicate single
//-----------------------------------------------------------------------------
wire signed [NUM_HARMONICS*WIDTH-1:0] sr_field_effective;

// If packed input is provided (non-zero), use it; otherwise replicate single f₀ input
// This allows both v7.2 (single) and v7.3 (multi) interfaces to work
assign sr_field_effective = (sr_field_packed != 0) ? sr_field_packed :
                            {sr_field_input, sr_field_input, sr_field_input, sr_field_input, sr_field_input};

//-----------------------------------------------------------------------------
// v7.3: Multi-Harmonic SR Bank
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] f0_x_int, f0_y_int, f0_amp_int, f0_coh_int;
wire beta_is_quiet;
wire sie_active_any;

// v7.4: Per-harmonic continuous gains
wire signed [NUM_HARMONICS*WIDTH-1:0] gain_per_harmonic;

sr_harmonic_bank #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_HARMONICS(NUM_HARMONICS),
    .ENABLE_STOCHASTIC(ENABLE_STOCHASTIC),
    .ENABLE_DRIFT(ENABLE_DRIFT)
) sr_bank (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .mu_dt(mu_dt),

    // v8.1: Drifting omega_dt values (from sr_frequency_drift)
    .omega_dt_packed(omega_dt_packed),

    // External SR field inputs (packed)
    .sr_field_packed(sr_field_effective),

    // Stochastic noise inputs (packed)
    .noise_packed(noise_packed),

    // Brain oscillator states for coherence computation
    .theta_x(theta_x_int),
    .theta_y(theta_y_int),
    .alpha_x(alpha_x),
    .alpha_y(alpha_y),
    .beta_low_x(beta_low_x),
    .beta_low_y(beta_low_y),
    .beta_high_x(beta_high_x),
    .beta_high_y(beta_high_y),
    .gamma_x(gamma_x),
    .gamma_y(gamma_y),

    // Beta amplitude for SR gating
    .beta_amplitude(beta_amplitude),

    // Per-harmonic outputs (packed)
    .f_x_packed(sr_f_x_packed),
    .f_y_packed(sr_f_y_packed),
    .f_amplitude_packed(sr_amplitude_packed),
    .coherence_packed(sr_coherence_packed),
    .sie_per_harmonic(sie_per_harmonic),

    // v7.4: Continuous per-harmonic gains
    .gain_per_harmonic_packed(gain_per_harmonic),

    // Aggregate outputs
    .sie_active_any(sie_active_any),
    .coherence_mask(coherence_mask),
    .beta_quiet(beta_is_quiet),

    // Primary f₀ outputs (backwards compatibility)
    .f0_x(f0_x_int),
    .f0_y(f0_y_int),
    .f0_amplitude(f0_amp_int),
    .f0_coherence(f0_coh_int)
);

//-----------------------------------------------------------------------------
// Entrainment Coupling (f₀ → Theta when beta quiet)
//-----------------------------------------------------------------------------
// Beta-gated coupling: f₀ can entrain theta only when beta is quiet.
// This implements the stochastic resonance mechanism where optimal
// "noise" (quiet beta) enables detection of weak periodic signals.

wire signed [WIDTH-1:0] entrain_coupling;
assign entrain_coupling = beta_is_quiet ? K_ENTRAIN : 18'sd0;

// Compute entrainment signal: K × f₀_x (when beta quiet)
wire signed [2*WIDTH-1:0] entrain_product;
wire signed [WIDTH-1:0] theta_entrain_input;
assign entrain_product = entrain_coupling * f0_x_int;
assign theta_entrain_input = entrain_product >>> FRAC;

//-----------------------------------------------------------------------------
// Theta Oscillator (5.89 Hz - hippocampal timing)
// Receives entrainment input from f₀ when beta is quiet
//-----------------------------------------------------------------------------

wire signed [WIDTH-1:0] theta_x_int, theta_y_int, theta_amp_int;

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) theta_relay (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .mu_dt(mu_dt),
    .omega_dt(OMEGA_DT_THETA),
    .input_x(theta_entrain_input),  // Entrained by f₀ when beta quiet
    .x(theta_x_int),
    .y(theta_y_int),
    .amplitude(theta_amp_int)
);

//-----------------------------------------------------------------------------
// Dynamic Amplification Logic (SIE Model)
// v7.4: Continuous gain based on summed per-harmonic contributions
// Each harmonic contributes 0 to 1.0 (Q14), scaled to 0.2× boost each
// Total boost range: 1.0× (no coherence) to 2.0× (all harmonics maxed)
//-----------------------------------------------------------------------------

// Unpack per-harmonic gains
wire signed [WIDTH-1:0] gain_h0, gain_h1, gain_h2, gain_h3, gain_h4;
assign gain_h0 = gain_per_harmonic[0*WIDTH +: WIDTH];
assign gain_h1 = gain_per_harmonic[1*WIDTH +: WIDTH];
assign gain_h2 = gain_per_harmonic[2*WIDTH +: WIDTH];
assign gain_h3 = gain_per_harmonic[3*WIDTH +: WIDTH];
assign gain_h4 = gain_per_harmonic[4*WIDTH +: WIDTH];

// Sum all per-harmonic gains (each 0 to 16384 Q14)
// Total can be 0 to 81920 (5 × 16384)
wire signed [WIDTH+2:0] total_gain_sum;
assign total_gain_sum = gain_h0 + gain_h1 + gain_h2 + gain_h3 + gain_h4;

// Scale: each harmonic contributes up to 0.2× boost when at max
// Boost = total_gain_sum / 5 × 0.2 = total_gain_sum × 0.2/5 = total_gain_sum × 0.04
// 0.04 in Q14 = 655.36 ≈ 655
// Or simpler: total_gain_sum / 5 gives 0-16384 per harmonic avg
// Then scale by 0.2: (avg / 5) = total / 25 ≈ total >> 4.64 ≈ (total * 3) >> 6
wire signed [WIDTH+4:0] boost_scaled;
assign boost_scaled = (total_gain_sum * 20'sd3277) >>> FRAC;  // 3277/16384 ≈ 0.2

// Dynamic gain = baseline (1.0×) + boost (0 to 1.0×)
wire signed [WIDTH-1:0] dynamic_gain_raw;
wire signed [WIDTH-1:0] dynamic_gain;
assign dynamic_gain_raw = SR_BASELINE_GAIN + boost_scaled[WIDTH-1:0];

// Clamp to max 2.0× (32768 in Q14)
localparam signed [WIDTH-1:0] MAX_GAIN = 18'sd32768;  // 2.0 in Q14
assign dynamic_gain = (dynamic_gain_raw > MAX_GAIN) ? MAX_GAIN : dynamic_gain_raw;

//-----------------------------------------------------------------------------
// Theta Gate and Gain Computation
//-----------------------------------------------------------------------------

wire signed [WIDTH-1:0] theta_gate_raw;
wire signed [WIDTH-1:0] theta_gate;
wire signed [2*WIDTH-1:0] gated_full;

assign theta_gate_raw = HALF + (theta_x_int >>> 1);
assign theta_gate = (theta_gate_raw[WIDTH-1]) ? 18'sd0 : theta_gate_raw;

// Alpha feedback modulation (existing behavior)
wire signed [WIDTH-1:0] alpha_abs;
wire signed [2*WIDTH-1:0] alpha_modulation;
wire signed [WIDTH-1:0] gain;

assign alpha_abs = l6_alpha_feedback[WIDTH-1] ? -l6_alpha_feedback : l6_alpha_feedback;
assign alpha_modulation = ALPHA_COUPLING * alpha_abs;
assign gain = GAIN_BASELINE - (alpha_modulation >>> FRAC);

// Apply dynamic SR amplification to gain
wire signed [2*WIDTH-1:0] amplified_gain_full;
wire signed [WIDTH-1:0] final_gain;

assign amplified_gain_full = gain * dynamic_gain;
assign final_gain = amplified_gain_full >>> FRAC;

//-----------------------------------------------------------------------------
// Output Computation
//-----------------------------------------------------------------------------

wire signed [2*WIDTH-1:0] gain_applied;
wire signed [WIDTH-1:0] gain_applied_scaled;

assign gain_applied = sensory_input * final_gain;
assign gain_applied_scaled = gain_applied >>> FRAC;
assign gated_full = gain_applied_scaled * theta_gate;
assign theta_gated_output = gated_full >>> FRAC;

//-----------------------------------------------------------------------------
// v8.2: Theta Phase Computation (8 phases per cycle)
//
// BIOLOGICAL BASIS (Dupret et al. 2025):
// "Studying cycle-by-cycle variability of theta oscillations has indicated
// multiplexing for population-level trading off between encoding and retrieval."
//
// CHALLENGE: Both theta_x and theta_y have DC offsets from entrainment coupling.
// The Hopf oscillator cross-coupling (omega*x in dy/dt) propagates x's DC to y.
//
// SOLUTION: Remove DC offset from theta_y using an IIR low-pass filter:
//   y_avg = y_avg + alpha*(y - y_avg)  // Tracks DC component
//   y_hp = y - y_avg                    // High-pass (AC only)
//
// Using alpha = 1/256 (>>8) for slow adaptation (~40 samples time constant)
//
// Phase detection using DC-corrected y:
//   - y_hp > 0: "rising toward peak" (encoding phases 0-3)
//   - y_hp <= 0: "falling toward trough" (retrieval phases 4-7)
//
// 8-phase mapping: {y_pos, y_rising, |y|>amp/2}
//   Phase 0: y>0, rising, |y|>amp/2  → early rising (fast)
//   Phase 1: y>0, rising, |y|<=amp/2 → late rising (slow, near peak)
//   Phase 2: y>0, falling, |y|<=amp/2 → early falling (just past peak)
//   Phase 3: y>0, falling, |y|>amp/2  → late falling (fast)
//   Phase 4: y<=0, falling, |y|>amp/2 → early descending (fast)
//   Phase 5: y<=0, falling, |y|<=amp/2 → late descending (near trough)
//   Phase 6: y<=0, rising, |y|<=amp/2 → early rising (just past trough)
//   Phase 7: y<=0, rising, |y|>amp/2  → late rising (fast)
//
// Encoding vs Retrieval windows (based on y sign):
//   - y_hp > 0 (phases 0-3): Encoding - theta approaching/leaving peak
//   - y_hp <= 0 (phases 4-7): Retrieval - theta approaching/leaving trough
//-----------------------------------------------------------------------------

// DC removal: IIR low-pass filter to track mean, then subtract
// y_avg tracks the DC component of theta_y
reg signed [WIDTH-1:0] theta_y_avg;
wire signed [WIDTH-1:0] theta_y_hp;  // High-pass filtered (DC removed)

always @(posedge clk or posedge rst) begin
    if (rst) begin
        theta_y_avg <= 18'sd0;
    end else if (clk_en) begin
        // IIR filter: y_avg = y_avg + (y - y_avg)/256
        // = y_avg + (y >> 8) - (y_avg >> 8)
        theta_y_avg <= theta_y_avg + ((theta_y_int - theta_y_avg) >>> 8);
    end
end

// High-pass = signal minus DC average
assign theta_y_hp = theta_y_int - theta_y_avg;

// Use DC-corrected y for phase detection
wire theta_y_positive = ~theta_y_hp[WIDTH-1];  // y_hp >= 0

// Compute absolute y for magnitude comparison
wire signed [WIDTH-1:0] theta_y_abs = theta_y_hp[WIDTH-1] ? -theta_y_hp : theta_y_hp;

// Track DC-removed amplitude using IIR filter on |y_hp| peaks
// This gives us a better threshold than the DC-inflated raw amplitude
reg signed [WIDTH-1:0] theta_y_hp_amp;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        theta_y_hp_amp <= 18'sd4096;  // Initial estimate
    end else if (clk_en) begin
        // Track peak amplitude: slowly adapt toward current |y_hp|
        // Use faster adaptation when |y| is larger than current estimate
        if (theta_y_abs > theta_y_hp_amp)
            theta_y_hp_amp <= theta_y_hp_amp + ((theta_y_abs - theta_y_hp_amp) >>> 4);
        else
            theta_y_hp_amp <= theta_y_hp_amp - (theta_y_hp_amp >>> 8);  // Slow decay
    end
end

// Compare |y_hp| to quarter of tracked amplitude to determine "fast" vs "slow" region
// Using quarter instead of half gives more even phase distribution
wire signed [WIDTH-1:0] amp_quarter = theta_y_hp_amp >>> 2;
wire y_gt_half_amp = (theta_y_abs > amp_quarter);

// Track y derivative by comparing to previous value (registered)
reg signed [WIDTH-1:0] prev_theta_y;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        prev_theta_y <= 18'sd0;
    end else if (clk_en) begin
        prev_theta_y <= theta_y_hp;
    end
end

wire y_rising = (theta_y_hp > prev_theta_y);  // dy/dt > 0

// Compute phase based on y sign, y derivative, and magnitude
// Using truth table: {y_pos, y_rising, y_gt_half_amp} → phase
reg [2:0] theta_phase_int;
always @(*) begin
    case ({theta_y_positive, y_rising, y_gt_half_amp})
        // y > 0 (encoding window, phases 0-3)
        3'b111: theta_phase_int = 3'd0;  // y>0, rising, |y|>amp/2 → Phase 0
        3'b110: theta_phase_int = 3'd1;  // y>0, rising, |y|<=amp/2 → Phase 1
        3'b100: theta_phase_int = 3'd2;  // y>0, falling, |y|<=amp/2 → Phase 2
        3'b101: theta_phase_int = 3'd3;  // y>0, falling, |y|>amp/2 → Phase 3
        // y <= 0 (retrieval window, phases 4-7)
        3'b001: theta_phase_int = 3'd4;  // y<=0, falling, |y|>amp/2 → Phase 4
        3'b000: theta_phase_int = 3'd5;  // y<=0, falling, |y|<=amp/2 → Phase 5
        3'b010: theta_phase_int = 3'd6;  // y<=0, rising, |y|<=amp/2 → Phase 6
        3'b011: theta_phase_int = 3'd7;  // y<=0, rising, |y|>amp/2 → Phase 7
        default: theta_phase_int = 3'd0;
    endcase
end

assign theta_phase = theta_phase_int;

//-----------------------------------------------------------------------------
// Output Assignments
//-----------------------------------------------------------------------------

// Theta outputs
assign theta_x = theta_x_int;
assign theta_y = theta_y_int;
assign theta_amplitude = theta_amp_int;

// f₀ outputs (v7.2 compatibility)
assign f0_x = f0_x_int;
assign f0_y = f0_y_int;
assign f0_amplitude = f0_amp_int;

// SR coupling outputs
assign sr_coherence = f0_coh_int;        // f₀ coherence (v7.2 compat)
assign sr_amplification = sie_active_any; // SIE active (any harmonic)
assign beta_quiet = beta_is_quiet;        // Expose SR-ready state

endmodule
