//=============================================================================
// Top-Level Module - v11.0 with Active φⁿ Dynamics
//
// v11.0 CHANGES (Active φⁿ Dynamics):
// - ENABLE_ADAPTIVE parameter for self-organizing oscillator dynamics
// - Energy landscape module computes restoring forces toward φⁿ positions
// - Quarter-integer detector classifies oscillator positions
// - Dynamic SIE enhancement based on stability metric
// - Force-based frequency corrections through cortical_frequency_drift
// - When ENABLE_ADAPTIVE=0, preserves v10.5 static behavior
// - See docs/SPEC_v11.0_UPDATE.md for implementation details
//
// v10.5 CHANGES (Quarter-Integer φⁿ Theory):
// - RESOLVED: f₁ "bridging mode mystery" - f₁ is φ^1.25 quarter-integer fallback
// - Energy landscape: E_total = E_φ(n) + E_h(n) with 2:1 harmonic catastrophe
// - φ^1.5 = 2.058 is unstable (too close to 2:1 harmonic at ratio 2.0)
// - f₁ retreats to geometric mean: n = (1.0 + 1.5)/2 = 1.25
// - φ^1.25 × 7.6 Hz = 13.84 Hz (observed 13.75 Hz, 0.65% error)
// - Quarter-integer has highest SIE response (3.0×) due to lower energy barrier
// - See docs/SPEC_v10.5_UPDATE.md for full derivation and Tomsk 27-yr validation
//
// v10.4 CHANGES (φⁿ Geophysical SR Integration):
// - Q-factor modeling: f₂ (20 Hz) is anchor with highest Q=15.5
// - Amplitude hierarchy: φ^(-n) power decay across harmonics
// - Mode-selective SIE: f₀/f₁ respond 2.7-3×, f₂/f₃/f₄ only 1.2×
// - Based on Dec 2025 geophysical Schumann Resonance data analysis
//
// v10.2 CHANGES (Spectral Broadening):
// - Added fast cycle-by-cycle frequency jitter (±0.15 Hz per sample)
// - Combined with slow drift (±0.5 Hz over seconds) for realistic spectral peaks
// - Oscillator peaks now ~0.5-1 Hz wide instead of sharp lines
// - Matches natural EEG where bands are diffuse, not discrete frequencies
//
// v10.1 CHANGES (EEG Realism - Phase 8):
// - Added cortical_frequency_drift for ±0.5 Hz bounded random walk on cortical oscillators
// - Spreads sharp spectral peaks into broader bands (~1 Hz width)
// - Added amplitude_envelope_generator instances for output mixer modulation
// - Creates biological "breathing" effect (2-5 second amplitude cycles)
// - Combined with cortical column internal envelopes for maximum realism
// - DAC output now resembles natural human EEG spectrogram
//
// v10.0 CHANGES (Biologically-Accurate SIE Model):
// - Added sr_ignition_controller for six-phase SIE state machine
// - Continuous baseline SR coupling (tonic presence, z ~1-2)
// - Transient amplification during ignition events (z ~20-25, 10-15×)
// - Coherence-first signature: PLV rises before amplitude (~3-4s lead)
// - State-dependent SIE timing via config_controller
// - Matches empirical EEG observations from meditation research
//
// v9.5 CHANGES (Dendritic Compartment - Phase 6):
// - Added ca_threshold output from config_controller (state-dependent)
// - Wired ca_threshold to all cortical_column instances
// - Cortical columns now use two-compartment dendritic model for L2/3, L5a, L5b
// - BAC firing provides supralinear coincidence detection
// - Lower ca_threshold in PSYCHEDELIC = more Ca2+ spikes (enhanced top-down)
// - Higher ca_threshold in ANESTHESIA = fewer Ca2+ spikes (reduced integration)
//
// v9.4 CHANGES (VIP+ Disinhibition - Phase 5):
// - Added attention_input port to cortical_column instantiations
// - Default: attention_input = 0 (no attention modulation)
// - Future: attention can be controlled externally or state-derived
// - VIP+ cells in L1 disinhibit SST+ for selective enhancement
//
// v8.8 CHANGES (L6 Output Targets):
// - L6 → Thalamus inhibitory modulation (10:1 ratio + TRN amplification)
// - L6 → L5a intra-column pathway (K_L6_L5A = 0.15)
// - L4 → L5a bypass pathway (K_L4_L5A = 0.1)
// - L5a now has separate input from L5b
//
// v8.7 CHANGES (Matrix Thalamic Input):
// - Added matrix thalamic pathway: L5b (all columns) → Thalamus → L1 (all columns)
// - Thalamus receives L5b from sensory, association, and motor columns
// - Computes theta-gated average for matrix_output
// - matrix_output broadcast identically to all cortical columns' L1
// - Implements biologically accurate POm/Pulvinar pathway
// - Dual feedback inputs for L1 gain modulation
// - Hierarchical top-down: Motor → Association → Sensory
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
    parameter SR_DRIFT_ENABLE = 1,  // v8.2: Enable SR frequency drift (realistic variation)
    parameter ENABLE_ADAPTIVE = 0  // v11.0: Enable active φⁿ dynamics (self-organizing)
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
localparam signed [WIDTH-1:0] K_PHASE = 18'sd328;   // 0.02 - phase coupling (minimal for frequency separation)

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

//-----------------------------------------------------------------------------
// v10.2: Cortical Frequency Drift + Jitter Generator
// Two components for EEG-like spectral broadening:
// 1. Slow drift: ±0.5 Hz bounded random walk (updates every ~0.2s)
// 2. Fast jitter: ±0.15 Hz cycle-by-cycle noise (updates every sample)
// Combined effect spreads sharp spectral lines into ~0.5-1 Hz wide peaks.
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] cortical_drift_l6, cortical_drift_l5a, cortical_drift_l5b;
wire signed [WIDTH-1:0] cortical_drift_l4, cortical_drift_l23;
wire signed [WIDTH-1:0] cortical_jitter_l6, cortical_jitter_l5a, cortical_jitter_l5b;
wire signed [WIDTH-1:0] cortical_jitter_l4, cortical_jitter_l23;

// v11.0: Forward declarations for force signals (defined later by energy_landscape)
wire signed [WIDTH-1:0] force_l6, force_l5a, force_l5b, force_l4, force_l23;

cortical_frequency_drift #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .FAST_SIM(FAST_SIM),
    .ENABLE_ADAPTIVE(ENABLE_ADAPTIVE)  // v11.0: Enable force-based corrections
) cortical_drift_gen (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    // v11.0: Force inputs from energy landscape (zero when ENABLE_ADAPTIVE=0)
    .force_l6(force_l6),
    .force_l5a(force_l5a),
    .force_l5b(force_l5b),
    .force_l4(force_l4),
    .force_l23(force_l23),
    // Slow drift outputs
    .drift_l6(cortical_drift_l6),
    .drift_l5a(cortical_drift_l5a),
    .drift_l5b(cortical_drift_l5b),
    .drift_l4(cortical_drift_l4),
    .drift_l23(cortical_drift_l23),
    // Fast jitter outputs (v10.2)
    .jitter_l6(cortical_jitter_l6),
    .jitter_l5a(cortical_jitter_l5a),
    .jitter_l5b(cortical_jitter_l5b),
    .jitter_l4(cortical_jitter_l4),
    .jitter_l23(cortical_jitter_l23)
);

// v10.2: Combined frequency offset = slow drift + fast jitter
wire signed [WIDTH-1:0] omega_offset_l6  = cortical_drift_l6  + cortical_jitter_l6;
wire signed [WIDTH-1:0] omega_offset_l5a = cortical_drift_l5a + cortical_jitter_l5a;
wire signed [WIDTH-1:0] omega_offset_l5b = cortical_drift_l5b + cortical_jitter_l5b;
wire signed [WIDTH-1:0] omega_offset_l4  = cortical_drift_l4  + cortical_jitter_l4;
wire signed [WIDTH-1:0] omega_offset_l23 = cortical_drift_l23 + cortical_jitter_l23;

//-----------------------------------------------------------------------------
// v11.0: Active φⁿ Dynamics - Energy Landscape and Force Computation
// When ENABLE_ADAPTIVE=1:
//   - Energy landscape computes restoring forces toward half-integer attractors
//   - Quarter-integer detector classifies oscillator positions
//   - Forces modify drift values to achieve self-organizing dynamics
// When ENABLE_ADAPTIVE=0:
//   - Forces are zero, preserving v10.5 static behavior
//-----------------------------------------------------------------------------

// Precomputed exponent n values for each cortical layer (Q14 format)
// n = log_φ(f_layer / f_reference) where f_reference = 5.89 Hz (theta)
// L6:   9.53 Hz → φ^0.5 → n = 0.5 (half-integer, stable attractor)
// L5a: 15.42 Hz → φ^1.5 → n = 1.5 (half-integer, but near 2:1 catastrophe)
// L5b: 24.94 Hz → φ^2.5 → n = 2.5 (half-integer, stable attractor)
// L4:  31.73 Hz → φ^3.0 → n = 3.0 (integer boundary)
// L2/3: 40.36 Hz → φ^3.5 → n = 3.5 (half-integer, stable attractor)
localparam NUM_CORTICAL_LAYERS = 5;
wire signed [NUM_CORTICAL_LAYERS*WIDTH-1:0] n_cortical_packed;
wire signed [NUM_CORTICAL_LAYERS*WIDTH-1:0] drift_cortical_packed;

// Pack exponent values (static base positions)
assign n_cortical_packed = {
    18'sd57344,   // L2/3: n = 3.5 in Q14
    18'sd49152,   // L4:   n = 3.0 in Q14
    18'sd40960,   // L5b:  n = 2.5 in Q14
    18'sd24576,   // L5a:  n = 1.5 in Q14 (near 2:1 catastrophe!)
    18'sd8192    // L6:   n = 0.5 in Q14
};

// Pack current drift values (for effective n computation)
assign drift_cortical_packed = {
    cortical_drift_l23,
    cortical_drift_l4,
    cortical_drift_l5b,
    cortical_drift_l5a,
    cortical_drift_l6
};

// Force outputs from energy landscape
wire signed [NUM_CORTICAL_LAYERS*WIDTH-1:0] force_cortical_packed;
wire signed [NUM_CORTICAL_LAYERS*WIDTH-1:0] energy_cortical_packed;
wire [NUM_CORTICAL_LAYERS-1:0] near_harmonic_2_1_cortical;

// Unpack forces for cortical_frequency_drift (connects to forward-declared wires)
assign force_l6  = force_cortical_packed[0*WIDTH +: WIDTH];
assign force_l5a = force_cortical_packed[1*WIDTH +: WIDTH];
assign force_l5b = force_cortical_packed[2*WIDTH +: WIDTH];
assign force_l4  = force_cortical_packed[3*WIDTH +: WIDTH];
assign force_l23 = force_cortical_packed[4*WIDTH +: WIDTH];

energy_landscape #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_OSCILLATORS(NUM_CORTICAL_LAYERS),
    .ENABLE_ADAPTIVE(ENABLE_ADAPTIVE)
) energy_landscape_cortical (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .n_packed(n_cortical_packed),
    .drift_packed(drift_cortical_packed),
    .force_packed(force_cortical_packed),
    .energy_packed(energy_cortical_packed),
    .near_harmonic_2_1(near_harmonic_2_1_cortical)
);

// Quarter-integer position detector for cortical layers
wire [NUM_CORTICAL_LAYERS*2-1:0] cortical_position_class;
wire signed [NUM_CORTICAL_LAYERS*WIDTH-1:0] cortical_stability_packed;
wire [NUM_CORTICAL_LAYERS-1:0] cortical_is_half_integer;
wire [NUM_CORTICAL_LAYERS-1:0] cortical_is_quarter_integer;

quarter_integer_detector #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_OSCILLATORS(NUM_CORTICAL_LAYERS)
) quarter_int_cortical (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .n_packed(n_cortical_packed),
    .position_class_packed(cortical_position_class),
    .stability_packed(cortical_stability_packed),
    .is_integer_boundary(),
    .is_half_integer(cortical_is_half_integer),
    .is_quarter_integer(cortical_is_quarter_integer),
    .is_near_catastrophe()
);

//-----------------------------------------------------------------------------
// v10.1: Amplitude Envelope Generators for Output Mixer
// Creates biological "alpha breathing" effect where band power waxes and wanes.
// These are separate from cortical column internal envelopes (which modulate MU).
// Mixer envelopes modulate the signal amplitude directly before mixing.
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] mixer_env_theta, mixer_env_alpha, mixer_env_beta, mixer_env_gamma;

// Theta envelope (slowest: tau=5s)
amplitude_envelope_generator #(.WIDTH(WIDTH), .FRAC(FRAC)) env_mixer_theta (
    .clk(clk), .rst(rst), .clk_en(clk_4khz_en),
    .seed(16'hF1A2), .tau_inv(18'sd1),  // tau ~3-5s
    .envelope(mixer_env_theta)
);

// Alpha envelope (medium-slow: tau=3s)
amplitude_envelope_generator #(.WIDTH(WIDTH), .FRAC(FRAC)) env_mixer_alpha (
    .clk(clk), .rst(rst), .clk_en(clk_4khz_en),
    .seed(16'hD3B4), .tau_inv(18'sd1),  // tau ~3s
    .envelope(mixer_env_alpha)
);

// Beta envelope (medium: tau=2s)
amplitude_envelope_generator #(.WIDTH(WIDTH), .FRAC(FRAC)) env_mixer_beta (
    .clk(clk), .rst(rst), .clk_en(clk_4khz_en),
    .seed(16'hC5E6), .tau_inv(18'sd2),  // tau ~1.5s (faster variation)
    .envelope(mixer_env_beta)
);

// Gamma envelope (fastest: tau=1s)
amplitude_envelope_generator #(.WIDTH(WIDTH), .FRAC(FRAC)) env_mixer_gamma (
    .clk(clk), .rst(rst), .clk_en(clk_4khz_en),
    .seed(16'hA7F8), .tau_inv(18'sd3),  // tau ~1s (fastest variation)
    .envelope(mixer_env_gamma)
);

wire signed [WIDTH-1:0] mu_dt_theta;
wire signed [WIDTH-1:0] mu_dt_l6, mu_dt_l5b, mu_dt_l5a, mu_dt_l4, mu_dt_l23;
wire signed [WIDTH-1:0] ca_threshold;  // v9.5: state-dependent Ca2+ threshold

// v10.0: SIE timing outputs from config controller
wire [15:0] sie_phase2_dur, sie_phase3_dur, sie_phase4_dur;
wire [15:0] sie_phase5_dur, sie_phase6_dur, sie_refractory;

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
    .mu_dt_l23(mu_dt_l23),
    .ca_threshold(ca_threshold),  // v9.5: state-dependent threshold
    // v10.0: SIE timing outputs
    .sie_phase2_dur(sie_phase2_dur),
    .sie_phase3_dur(sie_phase3_dur),
    .sie_phase4_dur(sie_phase4_dur),
    .sie_phase5_dur(sie_phase5_dur),
    .sie_phase6_dur(sie_phase6_dur),
    .sie_refractory(sie_refractory)
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

//=============================================================================
// v10.0: SIE IGNITION CONTROLLER (Six-Phase State Machine)
// Generates gain_envelope for SR→theta entrainment coupling.
// Implements biologically-accurate ignition events:
// - Continuous baseline (z ~1-2)
// - Transient amplification (z ~20-25, 10-15×) lasting ~18-25s
// - Coherence-first signature: PLV rises before amplitude
// - Refractory period prevents rapid re-ignition
//=============================================================================
wire signed [WIDTH-1:0] sie_gain_envelope;
wire signed [WIDTH-1:0] sie_plv_envelope;
wire [2:0] sie_ignition_phase;
wire sie_ignition_active;

// Use f0 coherence from thalamus for ignition triggering
// Note: beta_quiet_int is a forward declaration resolved after thalamus
wire beta_quiet_int;

sr_ignition_controller #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) ignition_ctrl (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),

    // Coherence input (from thalamus SR bank)
    .coherence_in(sr_coherence),

    // Beta quiet input (from thalamus SR bank)
    .beta_quiet(beta_quiet_int),

    // Phase timing (from config_controller)
    .phase2_dur(sie_phase2_dur),
    .phase3_dur(sie_phase3_dur),
    .phase4_dur(sie_phase4_dur),
    .phase5_dur(sie_phase5_dur),
    .phase6_dur(sie_phase6_dur),
    .refractory(sie_refractory),

    // Outputs
    .ignition_phase(sie_ignition_phase),
    .gain_envelope(sie_gain_envelope),
    .plv_envelope(sie_plv_envelope),
    .ignition_active(sie_ignition_active)
);

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

    // v10.0: SIE gain envelope from ignition controller
    .gain_envelope(sie_gain_envelope),

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
    .sr_amplification(),  // v10.0: Not used - ignition controller provides sr_amplification
    .beta_quiet(beta_quiet_int),  // v10.0: route through beta_quiet_int for ignition controller

    // v9.2: Matrix thalamic output (broadcast to all columns' L1)
    .matrix_output(thalamic_matrix_output)
);

// v10.0: Connect beta_quiet_int to output port
assign beta_quiet = beta_quiet_int;

// v10.0: Connect sr_amplification to ignition controller (not thalamus old logic)
// This provides proper six-phase SIE events instead of rapid coherence-based toggling
assign sr_amplification = sie_ignition_active;

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

// v9.5: Dendritic debug wires (optional, can be connected to top-level outputs)
wire sensory_l23_ca_spike, sensory_l23_bac;
wire sensory_l5a_ca_spike, sensory_l5a_bac;
wire sensory_l5b_ca_spike, sensory_l5b_bac;

cortical_column #(.WIDTH(WIDTH), .FRAC(FRAC), .COLUMN_ID(0)) col_sensory (
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
    .attention_input(18'sd0),               // v9.4: no attention (default)
    .ca_threshold(ca_threshold),            // v9.5: state-dependent threshold
    // v10.1: Frequency drift for EEG-realistic spectral spreading
    .omega_drift_l6(omega_offset_l6),      // v10.2: drift + jitter combined
    .omega_drift_l5a(omega_offset_l5a),
    .omega_drift_l5b(omega_offset_l5b),
    .omega_drift_l4(omega_offset_l4),
    .omega_drift_l23(omega_offset_l23),
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
    .l4_x(sensory_l4_x),
    .l23_ca_spike(sensory_l23_ca_spike),    // v9.5: dendritic debug
    .l23_bac(sensory_l23_bac),
    .l5a_ca_spike(sensory_l5a_ca_spike),
    .l5a_bac(sensory_l5a_bac),
    .l5b_ca_spike(sensory_l5b_ca_spike),
    .l5b_bac(sensory_l5b_bac)
);

wire assoc_l23_ca_spike, assoc_l23_bac;
wire assoc_l5a_ca_spike, assoc_l5a_bac;
wire assoc_l5b_ca_spike, assoc_l5b_bac;

cortical_column #(.WIDTH(WIDTH), .FRAC(FRAC), .COLUMN_ID(1)) col_assoc (
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
    .attention_input(18'sd0),               // v9.4: no attention (default)
    .ca_threshold(ca_threshold),            // v9.5: state-dependent threshold
    // v10.1: Frequency drift for EEG-realistic spectral spreading
    .omega_drift_l6(omega_offset_l6),      // v10.2: drift + jitter combined
    .omega_drift_l5a(omega_offset_l5a),
    .omega_drift_l5b(omega_offset_l5b),
    .omega_drift_l4(omega_offset_l4),
    .omega_drift_l23(omega_offset_l23),
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
    .l4_x(assoc_l4_x),
    .l23_ca_spike(assoc_l23_ca_spike),      // v9.5: dendritic debug
    .l23_bac(assoc_l23_bac),
    .l5a_ca_spike(assoc_l5a_ca_spike),
    .l5a_bac(assoc_l5a_bac),
    .l5b_ca_spike(assoc_l5b_ca_spike),
    .l5b_bac(assoc_l5b_bac)
);

wire motor_l23_ca_spike, motor_l23_bac;
wire motor_l5a_ca_spike, motor_l5a_bac;
wire motor_l5b_ca_spike, motor_l5b_bac;

cortical_column #(.WIDTH(WIDTH), .FRAC(FRAC), .COLUMN_ID(2)) col_motor (
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
    .attention_input(18'sd0),               // v9.4: no attention (default)
    .ca_threshold(ca_threshold),            // v9.5: state-dependent threshold
    // v10.1: Frequency drift for EEG-realistic spectral spreading
    .omega_drift_l6(omega_offset_l6),      // v10.2: drift + jitter combined
    .omega_drift_l5a(omega_offset_l5a),
    .omega_drift_l5b(omega_offset_l5b),
    .omega_drift_l4(omega_offset_l4),
    .omega_drift_l23(omega_offset_l23),
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
    .l4_x(motor_l4_x),
    .l23_ca_spike(motor_l23_ca_spike),      // v9.5: dendritic debug
    .l23_bac(motor_l23_bac),
    .l5a_ca_spike(motor_l5a_ca_spike),
    .l5a_bac(motor_l5a_bac),
    .l5b_ca_spike(motor_l5b_ca_spike),
    .l5b_bac(motor_l5b_bac)
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

// v10.1: Expanded 5-channel mixer with per-band amplitude envelopes
output_mixer #(.WIDTH(WIDTH), .FRAC(FRAC)) mixer (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .theta_x(thalamic_theta_x),    // 5.89 Hz - thalamic theta
    .motor_l6_x(motor_l6_x),       // 9.53 Hz - alpha (L6)
    .motor_l5a_x(motor_l5a_x),     // 15.42 Hz - low beta
    .motor_l23_x(motor_l23_x),     // 40.36 Hz - gamma
    .pink_noise(pink_noise_out),   // 1/f broadband
    // v10.1: Per-band amplitude envelopes for "alpha breathing" effect
    .env_theta(mixer_env_theta),   // Theta band envelope
    .env_alpha(mixer_env_alpha),   // Alpha band envelope
    .env_beta(mixer_env_beta),     // Beta band envelope
    .env_gamma(mixer_env_gamma),   // Gamma band envelope
    .mixed_output(mixed_output),
    .dac_output(dac_output)
);

assign debug_motor_l23 = motor_l23_x;
assign debug_theta = thalamic_theta_x;
assign cortical_pattern_out = cortical_pattern;  // v6.1: Expose for debugging
assign theta_phase = thalamic_theta_phase;       // v8.0: Expose theta phase for analysis

endmodule
