//=============================================================================
// Top-Level Module - v8.7 with Matrix Thalamic Pathway
//
// v8.7 CHANGES (Matrix Thalamic Input):
// - Added matrix thalamic pathway: L5b (all columns) → Thalamus → L1 (all columns)
// - Thalamus receives L5b from sensory, association, and motor columns
// - Computes theta-gated average for matrix_output
// - matrix_output broadcast identically to all cortical columns' L1
// - Implements biologically accurate POm/Pulvinar pathway
//
// v9.1 CHANGES (Dual Feedback Inputs for L1):
// - Cortical columns now have two feedback inputs for L1 gain modulation
// - feedback_input_1: adjacent column (weight 0.3 in L1)
// - feedback_input_2: distant column (weight 0.2 in L1)
// - Hierarchical top-down: Motor → Association → Sensory
// - Sensory receives feedback from both association AND motor columns
//
// v8.2 CHANGES (Realistic SR Frequency Variation):
// - Added sr_frequency_drift module for realistic Schumann resonance modeling
// - SR frequencies drift via bounded random walk within observed ranges:
//   f₀: 7.6 Hz ± 0.6 Hz, f₁: 13.75 Hz ± 0.75 Hz, f₂: 20 Hz ± 1 Hz
//   f₃: 25 Hz ± 1.5 Hz, f₄: 32 Hz ± 2 Hz
// - Hours-scale drift pattern mimics real SR monitoring data
// - Natural detuning prevents unrealistic high coherence from exact frequency match
// - Controllable via SR_DRIFT_ENABLE parameter
//
// v8.1 CHANGES (Gamma-Theta PAC):
// - L2/3 gamma frequency now modulated by theta phase
// - encoding_window=1: fast gamma (65.3 Hz, φ⁴·⁵) for sensory encoding
// - encoding_window=0: slow gamma (40.36 Hz, φ³·⁵) for memory retrieval
// - Frequency ratio = φ (exactly one golden ratio step)
// - Routes ca3_encoding_window to all cortical columns
//
// v8.0 CHANGES (Dupret et al. 2025 Integration):
// - Theta phase multiplexing: 8 discrete phases per theta cycle
// - Enables fine-grained encoding/retrieval gating in CA3
// - Phases 0-3: encoding-dominant window (theta_x > 0)
// - Phases 4-7: retrieval-dominant window (theta_x < 0)
// - Scaffold architecture: L4/L5b stable, L2/3/L6 plastic
//
// v7.3 CHANGES (Multi-Harmonic SR Bank):
// - 5 SR harmonics (7.83, 14.3, 20.8, 27.3, 33.8 Hz) externally driven
// - Each harmonic couples to corresponding EEG band
// - Per-harmonic coherence and SIE detection
// - Aggregate SIE when ANY harmonic achieves high coherence + beta quiet
// - New input: sr_field_packed (5 × 18-bit packed SR harmonics)
// - New outputs: sie_per_harmonic, coherence_mask, sr_coherence_packed
//
// v7.2 CHANGES (Stochastic Resonance Model - preserved):
// - f₀ is now EXTERNALLY DRIVEN via sr_field_input (represents Schumann field)
// - Beta amplitude from L5 layers gates the entrainment coupling
// - When beta quiets (meditation), stochastic resonance enables f₀ detection
// - f₀ entrains theta only when beta is at optimal quiet level
// - SIE = high coherence AND beta quiet (natural emergence, not explicit state)
// - New input: sr_field_input (external Schumann field signal)
// - New output: beta_quiet (indicates SR-ready state)
//
// v7.1 CHANGES (SIE Research Integration):
// - Thalamus includes f₀ oscillator (7.49 Hz, φ⁰ = Schumann fundamental)
// - Phase coherence detection between theta (5.89 Hz) and f₀ (7.49 Hz)
// - Dynamic gain amplification when theta-f₀ coherence exceeds threshold
// - Outputs: f0_x, f0_y, f0_amplitude, sr_coherence, sr_amplification
// - Models Schumann Ignition Event (SIE) transient power boost from research
//
// v6.3 CHANGES:
// - Added FAST_SIM parameter for testbench simulation speedup
// - FAST_SIM=1 uses ÷10 clock divider (vs ÷31250) for ~3000x faster simulation
// - All testbenches can now use full closed-loop DUT with fast simulation
//
// v6.2 CHANGES:
// - Removed ca3_pattern_in - sensory_input is the ONLY external data input
// - All learning must go through: sensory_input → thalamus → cortex → CA3
//
// v6.1 CHANGES:
// - CA3 pattern_in now derived from cortical activity (closed loop)
// - True recurrent architecture: cortex → CA3 → phase coupling → cortex
//
// v6.0 CHANGES:
// - 4 kHz update rate (was 1 kHz in v5.5) for better gamma resolution
// - Renamed clk_1khz_en → clk_4khz_en
// - K_PHASE = 4096 (validated stable at 4 kHz)
//
// FEATURES:
// - CA3 phase memory with Hebbian learning (v5.2)
// - Memory decay for unused associations (v5.3)
// - Phase coupling computation from theta × phase_pattern
// - Connected phase coupling to cortical columns (L2/3 and L6)
// - Theta-gated learning: encode at theta peak, recall at theta trough
//
// CLOSED-LOOP SIGNAL FLOW (v6.2 - sensory input only):
//   sensory_input → thalamus → theta_gated_output → cortical columns
//   Cortical L2/3 & L6 outputs → threshold → cortical_pattern (6-bit)
//   cortical_pattern → CA3 → phase_pattern
//   phase_pattern → phase coupling → cortical columns
//
// PHASE COUPLING MAPPING (6 bits → 6 oscillators):
//   Bit 0: Sensory L2/3 (gamma)
//   Bit 1: Sensory L6 (alpha)
//   Bit 2: Association L2/3 (gamma)
//   Bit 3: Association L6 (alpha)
//   Bit 4: Motor L2/3 (gamma)
//   Bit 5: Motor L6 (alpha)
//
// PHASE COUPLING MECHANISM:
//   phase_couple = K_PHASE × theta_x × sign
//   sign = +1 if bit=1 (in-phase), -1 if bit=0 (anti-phase)
//=============================================================================
`timescale 1ns / 1ps

module phi_n_neural_processor #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter FAST_SIM = 0,  // 1 = use fast clock divider (÷10 vs ÷31250) for simulation
    parameter NUM_HARMONICS = 5,  // v7.3: Number of SR harmonics
    parameter SR_STOCHASTIC_ENABLE = 1,  // Enable stochastic noise in SR oscillators
    parameter SR_DRIFT_ENABLE = 1  // v8.2: Enable SR frequency drift (realistic variation)
)(
    input  wire clk,
    input  wire rst,

    input  wire signed [WIDTH-1:0] sensory_input,  // v6.2: ONLY external data input
    input  wire [2:0] state_select,

    // v7.2 compatibility: Single SR field input (uses f₀ only)
    input  wire signed [WIDTH-1:0] sr_field_input,

    // v7.3: Multi-harmonic SR field inputs (packed: 5 × 18 bits = 90 bits)
    input  wire signed [NUM_HARMONICS*WIDTH-1:0] sr_field_packed,

    output wire [11:0] dac_output,
    output wire signed [WIDTH-1:0] debug_motor_l23,
    output wire signed [WIDTH-1:0] debug_theta,

    // CA3 status outputs
    output wire ca3_learning,
    output wire ca3_recalling,
    output wire [5:0] ca3_phase_pattern,

    // v6.1: Expose cortical pattern for debugging
    output wire [5:0] cortical_pattern_out,

    // f₀ SR Reference outputs (v7.2 compatibility)
    output wire signed [WIDTH-1:0] f0_x,
    output wire signed [WIDTH-1:0] f0_y,
    output wire signed [WIDTH-1:0] f0_amplitude,

    // v7.3: Multi-harmonic outputs (packed)
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sr_f_x_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] sr_coherence_packed,

    // v7.3: Per-harmonic SIE status
    output wire [NUM_HARMONICS-1:0] sie_per_harmonic,
    output wire [NUM_HARMONICS-1:0] coherence_mask,

    // SR Coupling indicators
    output wire signed [WIDTH-1:0] sr_coherence,  // f₀ coherence (v7.2 compat)
    output wire                    sr_amplification,  // SIE active (any harmonic)
    output wire                    beta_quiet,  // v7.2: Indicates SR-ready state

    // v8.0: Theta phase output (8 phases per cycle for temporal multiplexing)
    output wire [2:0] theta_phase
);

localparam signed [WIDTH-1:0] ONE_THIRD = 18'sd5461;
localparam signed [WIDTH-1:0] K_PHASE = 18'sd4096;  // 0.25 - phase coupling (validated stable at 4 kHz)

wire clk_4khz_en, clk_100khz_en;

clock_enable_generator #(
    .CLK_DIV_OVERRIDE(FAST_SIM ? 10 : 0)  // FAST_SIM: ÷10, normal: ÷31250
) clk_gen (
    .clk(clk),
    .rst(rst),
    .clk_4khz_en(clk_4khz_en),
    .clk_100khz_en(clk_100khz_en)
);

//-----------------------------------------------------------------------------
// SR Stochastic Noise Generator
// Generates independent white noise for each SR harmonic oscillator
//-----------------------------------------------------------------------------
wire signed [NUM_HARMONICS*WIDTH-1:0] sr_noise_packed;

sr_noise_generator #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_HARMONICS(NUM_HARMONICS)
) sr_noise_gen (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .noise_packed(sr_noise_packed)
);

//-----------------------------------------------------------------------------
// v8.2: SR Frequency Drift Generator
// Models realistic hours-scale frequency drift observed in real SR monitoring
// Natural detuning between SR and neural frequencies prevents unrealistic coherence
//-----------------------------------------------------------------------------
wire signed [NUM_HARMONICS*WIDTH-1:0] sr_omega_dt_packed;
wire signed [NUM_HARMONICS*WIDTH-1:0] sr_drift_offset_packed;

sr_frequency_drift #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_HARMONICS(NUM_HARMONICS),
    .FAST_SIM(FAST_SIM)
) sr_drift_gen (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .omega_dt_packed(sr_omega_dt_packed),
    .drift_offset_packed(sr_drift_offset_packed)
);

wire signed [WIDTH-1:0] mu_dt_theta;
wire signed [WIDTH-1:0] mu_dt_l6, mu_dt_l5b, mu_dt_l5a, mu_dt_l4, mu_dt_l23;

config_controller #(.WIDTH(WIDTH), .FRAC(FRAC)) config_ctrl (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .state_select(state_select),
    .mu_dt_theta(mu_dt_theta),
    .mu_dt_l6(mu_dt_l6),
    .mu_dt_l5b(mu_dt_l5b),
    .mu_dt_l5a(mu_dt_l5a),
    .mu_dt_l4(mu_dt_l4),
    .mu_dt_l23(mu_dt_l23)
);

wire signed [WIDTH-1:0] thalamic_theta_output;
wire signed [WIDTH-1:0] thalamic_theta_x, thalamic_theta_y;
wire signed [WIDTH-1:0] thalamic_theta_amp;
wire [2:0] thalamic_theta_phase;  // v8.0: 8-phase theta cycle
wire signed [WIDTH-1:0] l6_alpha_feedback;

// v9.2: Matrix thalamic output (broadcast to all columns' L1)
wire signed [WIDTH-1:0] thalamic_matrix_output;

wire signed [WIDTH-1:0] sensory_l6_x, assoc_l6_x, motor_l6_x;
wire signed [WIDTH-1:0] l6_sum;
wire signed [2*WIDTH-1:0] l6_avg_full;

assign l6_sum = sensory_l6_x + assoc_l6_x + motor_l6_x;
assign l6_avg_full = l6_sum * ONE_THIRD;
assign l6_alpha_feedback = l6_avg_full >>> FRAC;

//=============================================================================
// v7.2: BETA AMPLITUDE COMPUTATION (for Stochastic Resonance gating)
// Compute average beta amplitude from motor cortex L5a (low beta) and L5b (high beta).
// This is used to gate the f₀→theta entrainment: when beta is quiet, SR enables
// detection of the weak external Schumann field.
//=============================================================================
wire signed [WIDTH-1:0] motor_l5a_x_fwd, motor_l5b_x_fwd;  // Forward declarations
wire signed [WIDTH-1:0] motor_l5a_abs, motor_l5b_abs;
wire signed [WIDTH-1:0] beta_amplitude_sum;
wire signed [WIDTH-1:0] beta_amplitude_avg;

// Absolute values of L5 oscillator states
assign motor_l5a_abs = motor_l5a_x_fwd[WIDTH-1] ? -motor_l5a_x_fwd : motor_l5a_x_fwd;
assign motor_l5b_abs = motor_l5b_x_fwd[WIDTH-1] ? -motor_l5b_x_fwd : motor_l5b_x_fwd;

// Average of L5a and L5b beta amplitudes
assign beta_amplitude_sum = motor_l5a_abs + motor_l5b_abs;
assign beta_amplitude_avg = beta_amplitude_sum >>> 1;

// v7.3: Multi-harmonic SR field packed outputs (internal wires)
wire signed [NUM_HARMONICS*WIDTH-1:0] sr_f_y_packed_int;
wire signed [NUM_HARMONICS*WIDTH-1:0] sr_amplitude_packed_int;

thalamus #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_HARMONICS(NUM_HARMONICS),
    .ENABLE_STOCHASTIC(SR_STOCHASTIC_ENABLE),
    .ENABLE_DRIFT(SR_DRIFT_ENABLE)
) thal (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .sensory_input(sensory_input),
    .l6_alpha_feedback(l6_alpha_feedback),
    .mu_dt(mu_dt_theta),

    // v8.2: Drifting omega_dt values for realistic SR frequency variation
    .omega_dt_packed(sr_omega_dt_packed),

    // v7.3: Multi-harmonic SR field inputs
    .sr_field_packed(sr_field_packed),
    .noise_packed(sr_noise_packed),  // Stochastic noise for SR oscillators
    .sr_field_input(sr_field_input),  // v7.2 compatibility
    .beta_amplitude(beta_amplitude_avg),

    // v9.2: L5b inputs from all cortical columns (for matrix thalamic pathway)
    .l5b_sensory(sensory_l5b_x),
    .l5b_assoc(assoc_l5b_x),
    .l5b_motor(motor_l5b_x),

    // v7.3: Cortical oscillator states for per-band coherence
    .alpha_x(sensory_l6_x),
    .alpha_y(sensory_l6_y),
    .beta_low_x(motor_l5a_x),
    .beta_low_y(18'sd0),  // L5a doesn't expose y directly
    .beta_high_x(motor_l5b_x),
    .beta_high_y(18'sd0),  // L5b doesn't expose y directly
    .gamma_x(sensory_l4_x),
    .gamma_y(18'sd0),  // L4 doesn't expose y directly

    // Theta outputs
    .theta_gated_output(thalamic_theta_output),
    .theta_x(thalamic_theta_x),
    .theta_y(thalamic_theta_y),
    .theta_amplitude(thalamic_theta_amp),
    .theta_phase(thalamic_theta_phase),  // v8.0: 8-phase theta cycle

    // f₀ SR Reference outputs (v7.2 compatibility)
    .f0_x(f0_x),
    .f0_y(f0_y),
    .f0_amplitude(f0_amplitude),

    // v7.3: Multi-harmonic outputs (packed)
    .sr_f_x_packed(sr_f_x_packed),
    .sr_f_y_packed(sr_f_y_packed_int),
    .sr_amplitude_packed(sr_amplitude_packed_int),
    .sr_coherence_packed(sr_coherence_packed),
    .sie_per_harmonic(sie_per_harmonic),
    .coherence_mask(coherence_mask),

    // SR Coupling indicators
    .sr_coherence(sr_coherence),
    .sr_amplification(sr_amplification),
    .beta_quiet(beta_quiet),

    // v9.2: Matrix thalamic output (broadcast to all columns' L1)
    .matrix_output(thalamic_matrix_output)
);

//=============================================================================
// CORTICAL PATTERN DERIVATION (v6.2 pure closed-loop)
// Derive CA3 input from cortical activity by thresholding oscillator outputs
// This creates the biological loop: cortex → hippocampus → cortex
// v6.2: No external injection - sensory_input is the only way to drive patterns
//=============================================================================
wire [5:0] cortical_pattern;

// Threshold cortical outputs: x > 0 → active (1), x ≤ 0 → inactive (0)
// Bit mapping matches phase coupling: [S_γ, S_α, A_γ, A_α, M_γ, M_α]
assign cortical_pattern[0] = ~sensory_l23_x[WIDTH-1];  // Sensory L2/3 gamma (sign bit)
assign cortical_pattern[1] = ~sensory_l6_x[WIDTH-1];   // Sensory L6 alpha
assign cortical_pattern[2] = ~assoc_l23_x[WIDTH-1];    // Association L2/3 gamma
assign cortical_pattern[3] = ~assoc_l6_x[WIDTH-1];     // Association L6 alpha
assign cortical_pattern[4] = ~motor_l23_x[WIDTH-1];    // Motor L2/3 gamma
assign cortical_pattern[5] = ~motor_l6_x[WIDTH-1];     // Motor L6 alpha

//=============================================================================
// CA3 PHASE MEMORY (v8.0 with theta phase multiplexing)
//=============================================================================
wire [5:0] phase_pattern;
wire ca3_learning_int, ca3_recalling_int;
wire [3:0] ca3_debug;
wire ca3_encoding_window, ca3_retrieval_window;
wire [1:0] ca3_phase_subwindow;

ca3_phase_memory #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .N_UNITS(6)
) ca3_mem (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .theta_x(thalamic_theta_x),
    .theta_phase(thalamic_theta_phase),  // v8.0: 8-phase theta cycle
    .pattern_in(cortical_pattern),  // v6.2: Pure closed-loop, no external injection
    .phase_pattern(phase_pattern),
    .learning(ca3_learning_int),
    .recalling(ca3_recalling_int),
    .debug_state(ca3_debug),
    .encoding_window(ca3_encoding_window),    // v8.0: phase-based windows
    .retrieval_window(ca3_retrieval_window),
    .phase_subwindow(ca3_phase_subwindow)
);

assign ca3_learning = ca3_learning_int;
assign ca3_recalling = ca3_recalling_int;
assign ca3_phase_pattern = phase_pattern;

//=============================================================================
// PHASE COUPLING COMPUTATION
//=============================================================================
wire signed [2*WIDTH-1:0] theta_scaled;
wire signed [WIDTH-1:0] theta_couple_base;

assign theta_scaled = K_PHASE * thalamic_theta_x;
assign theta_couple_base = theta_scaled >>> FRAC;

wire signed [WIDTH-1:0] phase_couple_sensory_l23;
wire signed [WIDTH-1:0] phase_couple_sensory_l6;
wire signed [WIDTH-1:0] phase_couple_assoc_l23;
wire signed [WIDTH-1:0] phase_couple_assoc_l6;
wire signed [WIDTH-1:0] phase_couple_motor_l23;
wire signed [WIDTH-1:0] phase_couple_motor_l6;

assign phase_couple_sensory_l23 = phase_pattern[0] ? theta_couple_base : -theta_couple_base;
assign phase_couple_sensory_l6  = phase_pattern[1] ? theta_couple_base : -theta_couple_base;
assign phase_couple_assoc_l23   = phase_pattern[2] ? theta_couple_base : -theta_couple_base;
assign phase_couple_assoc_l6    = phase_pattern[3] ? theta_couple_base : -theta_couple_base;
assign phase_couple_motor_l23   = phase_pattern[4] ? theta_couple_base : -theta_couple_base;
assign phase_couple_motor_l6    = phase_pattern[5] ? theta_couple_base : -theta_couple_base;

//=============================================================================
// CORTICAL COLUMNS (with phase coupling)
//=============================================================================

wire signed [WIDTH-1:0] sensory_l23_x, sensory_l23_y, sensory_l5b_x, sensory_l5a_x, sensory_l4_x;
wire signed [WIDTH-1:0] sensory_l6_y;

wire signed [WIDTH-1:0] assoc_l23_x, assoc_l23_y, assoc_l5b_x, assoc_l5a_x, assoc_l4_x;
wire signed [WIDTH-1:0] assoc_l6_y;

wire signed [WIDTH-1:0] motor_l23_x, motor_l23_y, motor_l5b_x, motor_l5a_x, motor_l4_x;
wire signed [WIDTH-1:0] motor_l6_y;

wire signed [WIDTH-1:0] sensory_feedforward = 18'sd0;
wire signed [WIDTH-1:0] assoc_feedforward   = sensory_l23_x;
wire signed [WIDTH-1:0] motor_feedforward   = assoc_l23_x;

// v9.1: Dual feedback inputs for L1 gain modulation
// Each column receives feedback from higher-level columns:
// - Sensory: fb1=association (adjacent), fb2=motor (distant)
// - Association: fb1=motor (adjacent), fb2=0 (no distant)
// - Motor: fb1=0, fb2=0 (top of hierarchy)
wire signed [WIDTH-1:0] sensory_feedback_1 = assoc_l5b_x;   // Adjacent: Association
wire signed [WIDTH-1:0] sensory_feedback_2 = motor_l5b_x;   // Distant: Motor
wire signed [WIDTH-1:0] assoc_feedback_1   = motor_l5b_x;   // Adjacent: Motor
wire signed [WIDTH-1:0] assoc_feedback_2   = 18'sd0;        // No distant feedback
wire signed [WIDTH-1:0] motor_feedback_1   = 18'sd0;        // Top of hierarchy
wire signed [WIDTH-1:0] motor_feedback_2   = 18'sd0;        // Top of hierarchy

cortical_column #(.WIDTH(WIDTH), .FRAC(FRAC)) col_sensory (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .thalamic_theta_input(thalamic_theta_output),
    .feedforward_input(sensory_feedforward),
    .matrix_thalamic_input(thalamic_matrix_output),  // v9.2: broadcast to all
    .feedback_input_1(sensory_feedback_1),  // v9.1: Adjacent (association)
    .feedback_input_2(sensory_feedback_2),  // v9.1: Distant (motor)
    .phase_couple_l23(phase_couple_sensory_l23),
    .phase_couple_l6(phase_couple_sensory_l6),
    .encoding_window(ca3_encoding_window),  // v8.1: gamma-theta nesting
    .mu_dt_l6(mu_dt_l6),
    .mu_dt_l5b(mu_dt_l5b),
    .mu_dt_l5a(mu_dt_l5a),
    .mu_dt_l4(mu_dt_l4),
    .mu_dt_l23(mu_dt_l23),
    .l23_x(sensory_l23_x),
    .l23_y(sensory_l23_y),
    .l5b_x(sensory_l5b_x),
    .l5a_x(sensory_l5a_x),
    .l6_x(sensory_l6_x),
    .l6_y(sensory_l6_y),
    .l4_x(sensory_l4_x)
);

cortical_column #(.WIDTH(WIDTH), .FRAC(FRAC)) col_assoc (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .thalamic_theta_input(thalamic_theta_output),
    .feedforward_input(assoc_feedforward),
    .matrix_thalamic_input(thalamic_matrix_output),  // v9.2: broadcast to all
    .feedback_input_1(assoc_feedback_1),    // v9.1: Adjacent (motor)
    .feedback_input_2(assoc_feedback_2),    // v9.1: Distant (none)
    .phase_couple_l23(phase_couple_assoc_l23),
    .phase_couple_l6(phase_couple_assoc_l6),
    .encoding_window(ca3_encoding_window),  // v8.1: gamma-theta nesting
    .mu_dt_l6(mu_dt_l6),
    .mu_dt_l5b(mu_dt_l5b),
    .mu_dt_l5a(mu_dt_l5a),
    .mu_dt_l4(mu_dt_l4),
    .mu_dt_l23(mu_dt_l23),
    .l23_x(assoc_l23_x),
    .l23_y(assoc_l23_y),
    .l5b_x(assoc_l5b_x),
    .l5a_x(assoc_l5a_x),
    .l6_x(assoc_l6_x),
    .l6_y(assoc_l6_y),
    .l4_x(assoc_l4_x)
);

cortical_column #(.WIDTH(WIDTH), .FRAC(FRAC)) col_motor (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .thalamic_theta_input(thalamic_theta_output),
    .feedforward_input(motor_feedforward),
    .matrix_thalamic_input(thalamic_matrix_output),  // v9.2: broadcast to all
    .feedback_input_1(motor_feedback_1),    // v9.1: No adjacent (top of hierarchy)
    .feedback_input_2(motor_feedback_2),    // v9.1: No distant (top of hierarchy)
    .phase_couple_l23(phase_couple_motor_l23),
    .phase_couple_l6(phase_couple_motor_l6),
    .encoding_window(ca3_encoding_window),  // v8.1: gamma-theta nesting
    .mu_dt_l6(mu_dt_l6),
    .mu_dt_l5b(mu_dt_l5b),
    .mu_dt_l5a(mu_dt_l5a),
    .mu_dt_l4(mu_dt_l4),
    .mu_dt_l23(mu_dt_l23),
    .l23_x(motor_l23_x),
    .l23_y(motor_l23_y),
    .l5b_x(motor_l5b_x),
    .l5a_x(motor_l5a_x),
    .l6_x(motor_l6_x),
    .l6_y(motor_l6_y),
    .l4_x(motor_l4_x)
);

// v7.2: Connect forward declarations for beta amplitude computation
// These feed the stochastic resonance gating in the thalamus
assign motor_l5a_x_fwd = motor_l5a_x;
assign motor_l5b_x_fwd = motor_l5b_x;

wire signed [WIDTH-1:0] pink_noise_out;

pink_noise_generator #(.WIDTH(WIDTH), .FRAC(FRAC)) pink_gen (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .noise_out(pink_noise_out)
);

wire signed [WIDTH-1:0] mixed_output;

output_mixer #(.WIDTH(WIDTH), .FRAC(FRAC)) mixer (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .motor_l23_x(motor_l23_x),
    .motor_l5a_x(motor_l5a_x),
    .pink_noise(pink_noise_out),
    .mixed_output(mixed_output),
    .dac_output(dac_output)
);

assign debug_motor_l23 = motor_l23_x;
assign debug_theta = thalamic_theta_x;
assign cortical_pattern_out = cortical_pattern;  // v6.1: Expose for debugging
assign theta_phase = thalamic_theta_phase;       // v8.0: Expose theta phase for analysis

endmodule
