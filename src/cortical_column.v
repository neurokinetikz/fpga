//=============================================================================
// Cortical Column - v9.5 with Two-Compartment Dendritic Computation
//
// v9.5 CHANGES (Dendritic Compartment - Phase 6):
// - Added dendritic_compartment instances for L2/3, L5a, L5b pyramidal neurons
// - Basal compartment: receives feedforward input (direct passthrough)
// - Apical compartment: receives feedback input (Ca2+ spike dynamics)
// - BAC firing: supralinear coincidence detection (1.5x boost)
// - State-dependent ca_threshold from config_controller
// - L2/3: basal = L4 feedforward - PV, apical = phase_couple_l23
// - L5a: basal = L2/3 + L6 + L4_bypass, apical = feedback_input_2
// - L5b: basal = L2/3 + inter-column FB, apical = feedback_input_1
// - L4, L6: unchanged (dendrites don't reach L1)
//
// v9.4 CHANGES (VIP+ Disinhibition - Phase 5):
// - Added attention_input port for VIP+ disinhibition in Layer 1
// - VIP+ cells receive attention signals and inhibit SST+ cells
// - Creates "spotlight" effect: high attention → less SST+ → higher gain
// - Passes attention_input to layer1_minimal module
// - Biological basis: VIP+ cells target SST+ for selective enhancement
//
// v9.3 CHANGES (Cross-Layer PV+ - Phase 4):
// - Added L4 PV+ population: gates L4→L2/3 feedforward pathway (0.5× weight)
// - Added L5 PV+ population: provides L5b→L2/3 feedback inhibition (0.25× weight)
// - L2/3 now receives combined inhibition from three PV+ sources:
//   • pv_l23: local PING (from L2/3 pyramids) - 1.0× weight
//   • pv_l4: feedforward gating (from L4 pyramids) - 0.5× weight
//   • pv_l5: feedback inhibition (from L5b pyramids) - 0.25× weight
// - Biological basis: PV+ interneurons gate inter-layer communication
//
// v9.2 CHANGES (PV+ Interneuron - Phase 3 PING Network):
// - PV+ interneuron module with leaky integrator dynamics (tau = 5ms)
// - Creates proper PING (Pyramidal-Interneuron Gamma Network) dynamics
//
// v9.0 CHANGES (PV+ Interneuron - Phase 1):
// - [Superseded by v9.2/v9.3] Amplitude-proportional inhibition replaced
//
// v8.8 CHANGES (L6 Output Targets):
// - L5a now has SEPARATE input from L5b (was shared)
// - Added L6 → L5a intra-column pathway (K_L6_L5A = 0.15)
//   Recent finding: L6 CT projects to L5a, NOT L4
// - Added L4 → L5a bypass pathway (K_L4_L5A = 0.1)
//   Enables faster sensorimotor responses
// - L5a input = L2/3 + L6_feedback + L4_bypass (all × apical_gain)
// - L5b input = L2/3 + inter-column_feedback (unchanged)
//
// v8.7 CHANGES (Matrix Thalamic Input):
// - Added matrix_thalamic_input port for diffuse thalamic modulation
// - Matrix thalamus (POm, Pulvinar) projects to L1 across all columns
// - Implements cortex→matrix thalamus→L1 feedback loop
// - L1 now integrates: matrix input + feedback_1 + feedback_2
// - Dual feedback inputs for L1 gain modulation
// - Layer 1 (molecular layer) for top-down gain modulation
// - L2/3 input modulated by apical_gain (apical dendrites in L1)
// - L5 input modulated by apical_gain (thick-tufted PT neurons reach L1)
//
// v8.6 CHANGES (Canonical Microcircuit):
// - L5 now receives from L2/3 (processed) instead of L4 (raw)
// - L6 receives intra-column L5b feedback for corticothalamic modulation
// - Implements canonical L4→L2/3→L5→L6→Thalamus pathway
// - Signal flow: Thalamus→L4→L2/3→L5→output, L5→L6→Thalamus
//
// v8.1 CHANGES (Theta-Phase Gamma Nesting):
// - L2/3 gamma frequency now switches based on theta phase (encoding_window)
// - encoding_window=1 (encoding): fast gamma (65.3 Hz, φ⁴·⁵)
// - encoding_window=0 (retrieval): slow gamma (40.36 Hz, φ³·⁵)
// - Frequency ratio = φ (exactly one golden ratio step)
// - Implements true theta-gamma PAC with functional meaning:
//   "Slow gamma at late theta = retrieval; Fast gamma at theta trough = encoding"
//
// v8.0 CHANGES (Dupret et al. 2025 Integration):
// - Scaffold architecture: distinguishes stable vs plastic layers
// - Scaffold layers (L4, L5b) form stable backbone, no phase coupling
// - Plastic layers (L2/3, L6) receive phase coupling from CA3
// - Implements the "scaffolding principle" from hippocampal memory research:
//   "Higher-activity cells form stable backbone; lower-activity cells
//   integrate new motifs on demand"
//
// LAYER CLASSIFICATION (v8.0 Scaffold Architecture):
//
//   SCAFFOLD LAYERS (stable backbone, no phase coupling):
//     - L4 (31.73 Hz, φ³): Thalamocortical input boundary
//       • Anchors spatial/contextual representation
//       • Higher rate, more rigid activity
//       • Robust to perturbation by experience
//
//     - L5b (24.94 Hz, φ²·⁵): High beta, subcortical feedback
//       • Maintains state across time
//       • Provides stability for motor sequences
//       • No phase coupling preserves timing
//
//   PLASTIC LAYERS (flexible integration, with phase coupling):
//     - L2/3 (40.36/65.3 Hz, φ³·⁵/φ⁴·⁵): Gamma, feedforward output [PHASE COUPLED]
//       • Integrates new sensory patterns
//       • Fast gamma (65.3 Hz) during encoding for precise temporal coding
//       • Slow gamma (40.36 Hz) during retrieval matches CA3 reactivation
//       • Phase coupling enables memory-guided gating
//
//     - L6 (9.53 Hz, φ⁰·⁵): Alpha, gain control / PAC [PHASE COUPLED]
//       • Modulates processing gain
//       • Phase coupling from CA3 memory
//       • Enables memory-dependent attention
//
//     - L5a (15.42 Hz, φ¹·⁵): Low beta, motor output
//       • Intermediate plasticity
//       • Motor learning and adaptation
//
// LAYER FREQUENCIES (φⁿ architecture):
// - L2/3: 40.36/65.3 Hz (φ^3.5/φ^4.5) - Gamma, theta-phase dependent [PLASTIC]
// - L4:   31.73 Hz (φ^3.0) - Boundary, thalamocortical input [SCAFFOLD]
// - L5a:  15.42 Hz (φ^1.5) - Low beta, motor output [INTERMEDIATE]
// - L5b:  24.94 Hz (φ^2.5) - High beta, subcortical feedback [SCAFFOLD]
// - L6:    9.53 Hz (φ^0.5) - Alpha, gain control / PAC [PLASTIC]
//=============================================================================
`timescale 1ns / 1ps

module cortical_column #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    input  wire signed [WIDTH-1:0] thalamic_theta_input,
    input  wire signed [WIDTH-1:0] feedforward_input,

    // v9.2: Matrix thalamic input (diffuse projection to L1)
    input  wire signed [WIDTH-1:0] matrix_thalamic_input,

    // v9.1: Dual feedback inputs for L1 gain modulation
    input  wire signed [WIDTH-1:0] feedback_input_1,  // Adjacent column (weight 0.3)
    input  wire signed [WIDTH-1:0] feedback_input_2,  // Distant column (weight 0.2)

    // Phase coupling inputs from CA3
    input  wire signed [WIDTH-1:0] phase_couple_l23,
    input  wire signed [WIDTH-1:0] phase_couple_l6,

    // v8.1: Theta phase window for gamma nesting
    input  wire encoding_window,  // From CA3: 1=encoding (fast gamma), 0=retrieval (slow gamma)

    // v9.4: Attention input for VIP+ disinhibition in Layer 1
    // Higher values create selective enhancement via SST+ suppression
    input  wire signed [WIDTH-1:0] attention_input,

    // v9.5: State-dependent Ca2+ threshold for dendritic compartments
    input  wire signed [WIDTH-1:0] ca_threshold,

    input  wire signed [WIDTH-1:0] mu_dt_l6,
    input  wire signed [WIDTH-1:0] mu_dt_l5b,
    input  wire signed [WIDTH-1:0] mu_dt_l5a,
    input  wire signed [WIDTH-1:0] mu_dt_l4,
    input  wire signed [WIDTH-1:0] mu_dt_l23,

    output wire signed [WIDTH-1:0] l23_x,
    output wire signed [WIDTH-1:0] l23_y,
    output wire signed [WIDTH-1:0] l5b_x,
    output wire signed [WIDTH-1:0] l5a_x,
    output wire signed [WIDTH-1:0] l6_x,
    output wire signed [WIDTH-1:0] l6_y,
    output wire signed [WIDTH-1:0] l4_x,

    // v9.5: Dendritic compartment debug outputs
    output wire l23_ca_spike,   // L2/3 Ca2+ spike active
    output wire l23_bac,        // L2/3 BAC coincidence
    output wire l5a_ca_spike,   // L5a Ca2+ spike active
    output wire l5a_bac,        // L5a BAC coincidence
    output wire l5b_ca_spike,   // L5b Ca2+ spike active
    output wire l5b_bac         // L5b BAC coincidence
);

// OMEGA_DT = 2*pi*f*dt, dt=0.00025 for 4 kHz update rate
// Formula: OMEGA_DT = round(2π × f_hz × 0.00025 × 16384)
localparam signed [WIDTH-1:0] OMEGA_DT_L6  = 18'sd245;   // 9.53 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L5B = 18'sd642;   // 24.94 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L5A = 18'sd397;   // 15.42 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L4  = 18'sd817;   // 31.73 Hz
localparam signed [WIDTH-1:0] OMEGA_DT_L23 = 18'sd1039;  // 40.36 Hz (slow gamma, φ³·⁵)

// v8.1: Fast gamma for encoding window - exactly φ higher than slow gamma
// 65.3 Hz = 40.36 Hz × φ (one golden ratio step up)
localparam signed [WIDTH-1:0] OMEGA_DT_L23_FAST = 18'sd1681;  // 65.3 Hz (fast gamma, φ⁴·⁵)

// v8.1: Theta-phase-dependent gamma frequency selection
// encoding_window=1 → fast gamma (65.3 Hz) for precise temporal coding during sensory input
// encoding_window=0 → slow gamma (40.36 Hz) matches CA3 reactivation during retrieval
wire signed [WIDTH-1:0] omega_dt_l23_active;
assign omega_dt_l23_active = encoding_window ? OMEGA_DT_L23_FAST : OMEGA_DT_L23;

// v8.6: Coupling constants for canonical microcircuit
localparam signed [WIDTH-1:0] K_L4_L23 = 18'sd6554;  // 0.4 - L4 → L2/3
localparam signed [WIDTH-1:0] K_L23_L5 = 18'sd4915;  // 0.3 - L2/3 → L5 (canonical pathway)
localparam signed [WIDTH-1:0] K_L5_L6  = 18'sd3277;  // 0.2 - L5b → L6 intra-column feedback
localparam signed [WIDTH-1:0] K_PAC    = 18'sd3277;  // 0.2 - PAC modulation
localparam signed [WIDTH-1:0] K_FB_L5  = 18'sd3277;  // 0.2 - Inter-column feedback

// v8.8: L6 output connectivity constants
localparam signed [WIDTH-1:0] K_L6_L5A = 18'sd2458;  // 0.15 - L6 → L5a intra-column
localparam signed [WIDTH-1:0] K_L4_L5A = 18'sd1638;  // 0.1 - L4 → L5a bypass (fast sensorimotor)

// v9.2: PV+ interneuron now uses separate module with its own dynamics
// K_PV, K_EXCITE, TAU_INV are inside pv_interneuron.v

wire signed [WIDTH-1:0] l6_x_int, l6_y_int;
wire signed [WIDTH-1:0] l5b_x_int, l5b_y_int;
wire signed [WIDTH-1:0] l5a_x_int, l5a_y_int;
wire signed [WIDTH-1:0] l4_x_int, l4_y_int;
wire signed [WIDTH-1:0] l23_x_int, l23_y_int;

wire signed [WIDTH-1:0] l6_amp, l5b_amp, l5a_amp, l4_amp, l23_amp;

// v9.0: Layer 1 apical gain modulation
wire signed [WIDTH-1:0] l1_apical_gain;

wire signed [WIDTH-1:0] l4_input, l23_input, l5b_input, l5a_input, l6_input;  // v8.8: separate L5a/L5b
wire signed [WIDTH-1:0] l23_input_raw, l5b_input_raw, l5a_input_raw;  // v8.8: separate pre-modulation
wire signed [2*WIDTH-1:0] l23_to_l5_full, l4_to_l23_full, pac_full, fb_l5_full;
wire signed [2*WIDTH-1:0] l5_to_l6_full;  // v8.6: Intra-column L5b → L6 feedback
wire signed [2*WIDTH-1:0] l6_to_l5a_full;  // v8.8: L6 → L5a intra-column
wire signed [2*WIDTH-1:0] l4_to_l5a_full;  // v8.8: L4 → L5a bypass
wire signed [WIDTH-1:0] pac_mod;

//=============================================================================
// v9.2: Layer 1 - Matrix Thalamic + Dual Feedback Apical Gain Modulation
//=============================================================================
// L1 receives matrix thalamic input plus TWO cortico-cortical feedback sources.
// This models the molecular layer's integration of:
// - matrix_thalamic_input: diffuse projection from POm/Pulvinar (global attention)
// - feedback_input_1: adjacent column (e.g., association → sensory)
// - feedback_input_2: distant column (e.g., motor → sensory)
// v9.4: Debug signals for Layer 1 VIP+ disinhibition
wire signed [WIDTH-1:0] l1_sst_activity;
wire signed [WIDTH-1:0] l1_vip_activity;
wire signed [WIDTH-1:0] l1_sst_effective;

layer1_minimal #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) l1 (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .matrix_thalamic_input(matrix_thalamic_input),  // v9.2: diffuse thalamic
    .feedback_input_1(feedback_input_1),
    .feedback_input_2(feedback_input_2),
    .attention_input(attention_input),              // v9.4: VIP+ disinhibition
    .apical_gain(l1_apical_gain),
    .sst_activity_out(l1_sst_activity),             // v9.4: debug
    .vip_activity_out(l1_vip_activity),             // v9.4: debug
    .sst_effective_out(l1_sst_effective)            // v9.4: debug
);

//=============================================================================
// Layer Input Computations with L1 Gain Modulation
//=============================================================================

// L4 input: thalamic + feedforward (L4 dendrites don't reach L1, no gain)
assign l4_input = thalamic_theta_input + feedforward_input;

// v8.6: L5 receives from L2/3 (processed) instead of L4 (raw)
// This implements canonical cortical pathway: L4 → L2/3 → L5
assign l23_to_l5_full = l23_x_int * K_L23_L5;
// v9.1: Use primary feedback (feedback_input_1) for L5b/L6 direct input
assign fb_l5_full = feedback_input_1 * K_FB_L5;

//=============================================================================
// v8.8: Separate L5a and L5b Inputs
//=============================================================================
// L5b: receives L2/3 feedforward + inter-column feedback (unchanged from v8.7)
// L5a: receives L2/3 feedforward + L6 feedback + L4 bypass (NEW in v8.8)
//
// Biological basis:
// - L6 CT → L5a: Recent finding shows L6 projects to L5a, not L4
// - L4 → L5a bypass: Fast sensorimotor pathway bypassing L2/3

// L5b raw input (before L1 modulation) - unchanged
assign l5b_input_raw = (l23_to_l5_full >>> FRAC) + (fb_l5_full >>> FRAC);

// v8.8: L5a receives L6 intra-column feedback
assign l6_to_l5a_full = l6_x_int * K_L6_L5A;

// v8.8: L5a receives L4 bypass (fast sensorimotor pathway)
assign l4_to_l5a_full = l4_x_int * K_L4_L5A;

// L5a raw input: L2/3 + L6 feedback + L4 bypass
assign l5a_input_raw = (l23_to_l5_full >>> FRAC) + (l6_to_l5a_full >>> FRAC) + (l4_to_l5a_full >>> FRAC);

// v9.5: L5b and L5a now use dendritic compartment model instead of simple gain
// L5b Dendritic Compartment
// - Basal: L2/3 feedforward + inter-column feedback (canonical pathway)
// - Apical: feedback_input_1 from adjacent column (associative)
dendritic_compartment #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dend_l5b (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .basal_input(l5b_input_raw),
    .apical_input(feedback_input_1),
    .apical_gain(l1_apical_gain),
    .ca_threshold(ca_threshold),
    .dendritic_output(l5b_input),
    .ca_spike_active(l5b_ca_spike),
    .bac_active(l5b_bac)
);

// L5a Dendritic Compartment
// - Basal: L2/3 + L6 feedback + L4 bypass (motor pathway)
// - Apical: feedback_input_2 from distant column (motor context)
dendritic_compartment #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dend_l5a (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .basal_input(l5a_input_raw),
    .apical_input(feedback_input_2),
    .apical_gain(l1_apical_gain),
    .ca_threshold(ca_threshold),
    .dendritic_output(l5a_input),
    .ca_spike_active(l5a_ca_spike),
    .bac_active(l5a_bac)
);

// v8.6: L6 receives: intra-column L5b feedback + inter-column feedback + PHASE COUPLING
// Implements corticothalamic pathway: L5 → L6 → Thalamus
// Note: L6 dendrites don't extend to L1, so no gain modulation here
assign l5_to_l6_full = l5b_x_int * K_L5_L6;
assign l6_input = (l5_to_l6_full >>> FRAC) + (fb_l5_full >>> FRAC) + phase_couple_l6;

assign pac_full = K_PAC * l6_y_int;
assign pac_mod = pac_full[FRAC +: WIDTH];

// L2/3 receives: L4 feedforward + PAC modulation + PHASE COUPLING
assign l4_to_l23_full = l4_x_int * K_L4_L23;

// v9.0: L2/3 raw input (before L1 modulation)
assign l23_input_raw = (l4_to_l23_full >>> FRAC) + pac_mod + phase_couple_l23;

//=============================================================================
// v9.3: Cross-Layer PV+ Network (Phase 4 - Multi-Source Inhibition)
//=============================================================================
// Three PV+ populations provide inhibition to L2/3 from different sources:
//
// 1. pv_l23 (local PING): Receives L2/3 pyramid output
//    - Creates E-I balance for gamma oscillation
//    - Weight: 1.0× (full inhibition)
//
// 2. pv_l4 (feedforward gating): Receives L4 pyramid output
//    - Gates L4→L2/3 feedforward pathway
//    - Provides surround suppression
//    - Weight: 0.5× (half inhibition)
//
// 3. pv_l5 (feedback inhibition): Receives L5b pyramid output
//    - Provides top-down feedback inhibition
//    - Balances feedforward/feedback processing
//    - Weight: 0.25× (quarter inhibition)
//
// Biological basis:
// - PV+ basket cells in each layer gate information flow
// - Creates canonical feedforward inhibition (L4→L2/3)
// - Creates feedback inhibition (L5→L2/3)
// - Combined effect: balanced E-I across the column

// L2/3 local PV+ (PING network)
wire signed [WIDTH-1:0] pv_l23_inhibition;
wire signed [WIDTH-1:0] pv_l23_state;  // Debug

pv_interneuron #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) pv_l23 (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .pyramid_input(l23_x_int),
    .inhibition(pv_l23_inhibition),
    .pv_state_out(pv_l23_state)
);

// L4 PV+ (feedforward gating)
wire signed [WIDTH-1:0] pv_l4_inhibition;
wire signed [WIDTH-1:0] pv_l4_state;  // Debug

pv_interneuron #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) pv_l4 (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .pyramid_input(l4_x_int),
    .inhibition(pv_l4_inhibition),
    .pv_state_out(pv_l4_state)
);

// L5 PV+ (feedback inhibition)
wire signed [WIDTH-1:0] pv_l5_inhibition;
wire signed [WIDTH-1:0] pv_l5_state;  // Debug

pv_interneuron #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) pv_l5 (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .pyramid_input(l5b_x_int),
    .inhibition(pv_l5_inhibition),
    .pv_state_out(pv_l5_state)
);

// Combined inhibition to L2/3:
// - pv_l23: 1.0× (local PING)
// - pv_l4: 0.5× (feedforward gating) = >>> 1
// - pv_l5: 0.25× (feedback) = >>> 2
wire signed [WIDTH-1:0] pv_total_inhibition;
assign pv_total_inhibition = pv_l23_inhibition +
                             (pv_l4_inhibition >>> 1) +
                             (pv_l5_inhibition >>> 2);

// L2/3 input with combined PV+ inhibition subtracted (before dendritic processing)
wire signed [WIDTH-1:0] l23_input_with_pv;
assign l23_input_with_pv = l23_input_raw - pv_total_inhibition;

//=============================================================================
// v9.5: Two-Compartment Dendritic Computation
//=============================================================================
// Replace simple L1 gain modulation with dendritic compartment model.
// Applies to L2/3, L5a, L5b (pyramidal neurons with apical tufts in L1).
// NOT applied to L4, L6 (dendrites don't extend to L1).
//
// Each dendritic_compartment receives:
// - basal_input: feedforward (direct passthrough)
// - apical_input: feedback (Ca2+ spike dynamics)
// - apical_gain: L1 SST+/VIP+ gain modulation
// - ca_threshold: state-dependent (from config_controller)
//
// Output: (basal + Ca2+ contribution) × BAC boost

// L2/3 Dendritic Compartment
// - Basal: L4 feedforward + PAC - PV inhibition (bottom-up sensory)
// - Apical: phase_couple_l23 from CA3 (top-down memory)
dendritic_compartment #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dend_l23 (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .basal_input(l23_input_with_pv),
    .apical_input(phase_couple_l23),
    .apical_gain(l1_apical_gain),
    .ca_threshold(ca_threshold),
    .dendritic_output(l23_input),
    .ca_spike_active(l23_ca_spike),
    .bac_active(l23_bac)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l6 (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l6), .omega_dt(OMEGA_DT_L6),
    .input_x(l6_input),
    .x(l6_x_int), .y(l6_y_int), .amplitude(l6_amp)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l5b (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l5b), .omega_dt(OMEGA_DT_L5B),
    .input_x(l5b_input),  // v8.8: separate L5b input
    .x(l5b_x_int), .y(l5b_y_int), .amplitude(l5b_amp)
);

// v8.8: L5a now has separate input with L6 feedback and L4 bypass
hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l5a (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l5a), .omega_dt(OMEGA_DT_L5A),
    .input_x(l5a_input),  // v8.8: separate L5a input (L2/3 + L6 + L4_bypass)
    .x(l5a_x_int), .y(l5a_y_int), .amplitude(l5a_amp)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l4 (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l4), .omega_dt(OMEGA_DT_L4),
    .input_x(l4_input),
    .x(l4_x_int), .y(l4_y_int), .amplitude(l4_amp)
);

// v8.1: L2/3 now uses dynamic omega based on theta phase (gamma nesting)
hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_l23 (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l23), .omega_dt(omega_dt_l23_active),  // v8.1: theta-phase dependent
    .input_x(l23_input),
    .x(l23_x_int), .y(l23_y_int), .amplitude(l23_amp)
);

assign l23_x = l23_x_int;
assign l23_y = l23_y_int;
assign l5b_x = l5b_x_int;
assign l5a_x = l5a_x_int;
assign l6_x  = l6_x_int;
assign l6_y  = l6_y_int;
assign l4_x  = l4_x_int;

endmodule
