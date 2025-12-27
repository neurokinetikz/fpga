//=============================================================================
// Layer 1 with VIP+ Disinhibition - v9.6
//
// v9.6 CHANGES (L6 Direct Input - Phase 7):
// - Added l6_direct_input port for intra-column L6 modulation
// - L6 corticothalamic neurons project to L1 in addition to thalamus
// - Weight: K_L6_L1 = 0.1 (smallest of all inputs, local modulation)
// - Total scaling now: 0.15*matrix + 0.3*fb1 + 0.2*fb2 + 0.1*l6 = 0.75 max
// - L6 contribution goes through SST+ dynamics (not direct to gain)
// - Biological basis: L6 CT cells have local axon collaterals to L1
//
// v9.4 CHANGES (VIP+ Disinhibition - Phase 5):
// - Added VIP+ (vasoactive intestinal peptide) interneuron model
// - VIP+ cells receive attention_input and INHIBIT SST+ cells
// - Creates disinhibition: high attention → less SST+ → higher gain
// - Implements attention spotlight for selective enhancement
// - Biological basis: VIP+ cells target other interneurons (SST+/PV+)
//
// v9.1 CHANGES (SST+ Slow Dynamics):
// - Added SST+ (somatostatin-positive) Martinotti cell dynamics
// - IIR lowpass filter models slow GABA-B kinetics (~25ms time constant)
// - Gain now tracks FILTERED input, not instantaneous
// - Creates realistic slow inhibition matching biological SST+ cells
// - Biological basis: SST+ cells target distal dendrites with slow kinetics
//
// v8.7 CHANGES (Matrix Thalamic Input):
// - Added matrix_thalamic_input port for diffuse thalamic modulation
// - Matrix thalamus (POm, Pulvinar) projects to L1 across all columns
// - Weight: 0.15 (less than cortico-cortical feedback)
// - Implements cortex→matrix thalamus→L1 feedback loop
//
// v9.1 CHANGES (Dual Feedback Inputs):
// - Added second feedback input for longer-range top-down modulation
// - feedback_input_1: adjacent column (weight 0.3)
// - feedback_input_2: distant column (weight 0.2)
// - Total scaling remains 0.5, but now integrates two sources
// - Enables: Sensory ← Association + Motor feedback hierarchy
//
// BIOLOGICAL BASIS:
// - L1 contains only GABAergic interneurons (no excitatory neurons)
// - SST+ Martinotti cells: slow GABA-B kinetics, target distal dendrites
// - VIP+ cells: disinhibitory circuit, receive attention/arousal signals
// - Receives: matrix thalamic input, cortico-cortical feedback, neuromodulators
// - Outputs: modulation to L2/3 and L5 apical dendrites
// - Function: top-down attention gating, contextual integration
//
// VIP+ DISINHIBITION MODEL (v9.4):
// 1. combined = 0.15 * matrix + 0.3 * feedback_1 + 0.2 * feedback_2
// 2. sst_activity = lowpass(combined, tau=25ms)  // SST+ slow dynamics
// 3. vip_activity = lowpass(attention_input * K_VIP, tau=50ms)  // VIP+ slower
// 4. sst_effective = max(0, sst_activity - vip_activity)  // Disinhibition
// 5. apical_gain = clamp(1.0 + sst_effective, 0.5, 1.5)
// - VIP+ suppresses SST+ → increases gain when attention is high
// - Time constant ~50ms reflects slower VIP+ kinetics
//
// FUTURE ENHANCEMENTS:
// v9.5: ACh neuromodulator input
//=============================================================================
`timescale 1ns / 1ps

module layer1_minimal #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // v9.2: Matrix thalamic input (diffuse projection from POm/Pulvinar)
    input  wire signed [WIDTH-1:0] matrix_thalamic_input,

    // Feedback input 1: adjacent column (e.g., association for sensory)
    input  wire signed [WIDTH-1:0] feedback_input_1,

    // Feedback input 2: distant column (e.g., motor for sensory)
    input  wire signed [WIDTH-1:0] feedback_input_2,

    // v9.4: Attention input for VIP+ disinhibition
    // Higher values create "spotlight" effect by suppressing SST+
    input  wire signed [WIDTH-1:0] attention_input,

    // v9.6: L6 direct input for intra-column gain modulation
    // L6 corticothalamic neurons project to L1 in addition to thalamus
    input  wire signed [WIDTH-1:0] l6_direct_input,

    // Output: multiplicative gain for L2/3 and L5 apical dendrites
    output wire signed [WIDTH-1:0] apical_gain,

    // v9.4: Debug outputs for testbench access
    output wire signed [WIDTH-1:0] sst_activity_out,
    output wire signed [WIDTH-1:0] vip_activity_out,
    output wire signed [WIDTH-1:0] sst_effective_out
);

// Constants in Q4.14 format
localparam signed [WIDTH-1:0] GAIN_BASE  = 18'sd16384;  // 1.0 - unity gain baseline

// v9.2: Matrix thalamic weight (diffuse modulation, less than cortico-cortical)
localparam signed [WIDTH-1:0] K_MATRIX = 18'sd2458;  // 0.15 - matrix thalamus weight

// v9.1: Dual feedback weights
localparam signed [WIDTH-1:0] K_FB1 = 18'sd4915;   // 0.3 - adjacent column weight
localparam signed [WIDTH-1:0] K_FB2 = 18'sd3277;   // 0.2 - distant column weight

// Gain limits - expanded range for more dynamic modulation (v9.6)
// Literature: attention can increase gain 2-4×, anesthesia reduces to near zero
// With BAC firing (1.5× boost), effective range becomes [0.375, 3.0]
localparam signed [WIDTH-1:0] GAIN_MIN = 18'sd4096;   // 0.25 minimum (was 0.5)
localparam signed [WIDTH-1:0] GAIN_MAX = 18'sd32768;  // 2.0 maximum (was 1.5)

//=============================================================================
// v9.1: SST+ Slow Dynamics Constants
//=============================================================================
// SST+ (Martinotti) cells have slow GABA-B kinetics
// Time constant ~25ms at 4 kHz update rate
// IIR filter: y[n] = y[n-1] + alpha * (x[n] - y[n-1])
// For tau = 25ms at dt = 0.25ms: alpha = dt/tau = 0.25/25 = 0.01
localparam signed [WIDTH-1:0] SST_ALPHA = 18'sd164;  // 0.01 - IIR filter coefficient

//=============================================================================
// v9.4: VIP+ Disinhibition Constants
//=============================================================================
// VIP+ (vasoactive intestinal peptide) interneurons:
// - Receive attention/arousal signals from higher cortical areas
// - Inhibit SST+ cells (disinhibition of pyramidal dendrites)
// - Have slower dynamics than SST+ (~50ms time constant)
// - Create "spotlight" effect for selective attention
//
// VIP+ inhibits SST+, which inhibits pyramidal dendrites
// Net effect: VIP+ activation → increased gain (disinhibition)
//
// Time constant ~50ms at 4 kHz: alpha = 0.25/50 = 0.005
localparam signed [WIDTH-1:0] VIP_ALPHA = 18'sd82;   // 0.005 - slower than SST+
localparam signed [WIDTH-1:0] K_VIP = 18'sd8192;     // 0.5 - attention scaling

// v9.6: L6 direct pathway weight
// L6 CT neurons project to L1, provides intra-column modulation
localparam signed [WIDTH-1:0] K_L6_L1 = 18'sd1638;   // 0.1 - L6 direct to L1

// v9.2: Matrix thalamic contribution
wire signed [2*WIDTH-1:0] scaled_matrix;
assign scaled_matrix = matrix_thalamic_input * K_MATRIX;
wire signed [WIDTH-1:0] matrix_contrib;
assign matrix_contrib = scaled_matrix >>> FRAC;

// v9.1: Compute weighted feedback contributions from both sources
wire signed [2*WIDTH-1:0] scaled_fb1, scaled_fb2;
assign scaled_fb1 = feedback_input_1 * K_FB1;
assign scaled_fb2 = feedback_input_2 * K_FB2;

// Combine both feedback sources
wire signed [WIDTH-1:0] fb1_contrib, fb2_contrib;
assign fb1_contrib = scaled_fb1 >>> FRAC;
assign fb2_contrib = scaled_fb2 >>> FRAC;

// v9.6: L6 direct contribution (intra-column alpha feedback)
wire signed [2*WIDTH-1:0] scaled_l6;
assign scaled_l6 = l6_direct_input * K_L6_L1;
wire signed [WIDTH-1:0] l6_contrib;
assign l6_contrib = scaled_l6 >>> FRAC;

// v9.6: Total gain offset: 0.15*matrix + 0.3*fb1 + 0.2*fb2 + 0.1*l6
wire signed [WIDTH-1:0] gain_offset;
assign gain_offset = matrix_contrib + fb1_contrib + fb2_contrib + l6_contrib;

//=============================================================================
// v9.1: SST+ Slow Dynamics (IIR Lowpass Filter)
//=============================================================================
// SST+ Martinotti cells have slow GABA-B receptor kinetics
// This creates a lowpass-filtered version of the input
// Time constant ~25ms provides realistic slow inhibition dynamics
//
// Filter equation: sst[n] = sst[n-1] + alpha * (input - sst[n-1])
// This is equivalent to: sst[n] = (1-alpha) * sst[n-1] + alpha * input
reg signed [WIDTH-1:0] sst_activity;

// Intermediate signals for filter computation
wire signed [WIDTH-1:0] sst_error;
wire signed [2*WIDTH-1:0] sst_delta_full;
wire signed [WIDTH-1:0] sst_delta;

assign sst_error = gain_offset - sst_activity;
assign sst_delta_full = sst_error * SST_ALPHA;
assign sst_delta = sst_delta_full >>> FRAC;

always @(posedge clk) begin
    if (rst) begin
        sst_activity <= 0;
    end else if (clk_en) begin
        // IIR lowpass: sst_activity += alpha * (gain_offset - sst_activity)
        sst_activity <= sst_activity + sst_delta;
    end
end

//=============================================================================
// v9.4: VIP+ Disinhibition Dynamics
//=============================================================================
// VIP+ cells receive attention input and inhibit SST+ cells
// This creates a disinhibitory pathway:
//   High attention → High VIP+ → Low SST+ effective → Higher gain
//
// VIP+ uses slower dynamics (tau=50ms) than SST+ (tau=25ms)
// This reflects the slower buildup/decay of attention effects

// Scale attention input by VIP+ gain
wire signed [2*WIDTH-1:0] vip_scaled_full;
wire signed [WIDTH-1:0] vip_scaled;
assign vip_scaled_full = attention_input * K_VIP;
assign vip_scaled = vip_scaled_full >>> FRAC;

// VIP+ state variable with IIR lowpass filter
reg signed [WIDTH-1:0] vip_activity;

wire signed [WIDTH-1:0] vip_error;
wire signed [2*WIDTH-1:0] vip_delta_full;
wire signed [WIDTH-1:0] vip_delta;

assign vip_error = vip_scaled - vip_activity;
assign vip_delta_full = vip_error * VIP_ALPHA;
assign vip_delta = vip_delta_full >>> FRAC;

always @(posedge clk) begin
    if (rst) begin
        vip_activity <= 0;
    end else if (clk_en) begin
        // IIR lowpass: vip_activity += alpha * (vip_scaled - vip_activity)
        vip_activity <= vip_activity + vip_delta;
    end
end

// Compute effective SST+ activity after VIP+ disinhibition
// VIP+ can only reduce positive SST+, not push negative SST+ further down
// - If sst_activity >= 0 and VIP+ would push it negative: clamp at 0
// - If sst_activity < 0 (negative feedback): pass through unchanged
wire signed [WIDTH-1:0] sst_minus_vip;
wire signed [WIDTH-1:0] sst_effective;
assign sst_minus_vip = sst_activity - vip_activity;
// Clamp at 0 only if SST+ was positive and VIP+ would make it negative
assign sst_effective = (sst_activity >= 0 && sst_minus_vip < 0) ? 0 : sst_minus_vip;

// Compute raw gain using EFFECTIVE SST+ activity (after VIP+ disinhibition)
wire signed [WIDTH-1:0] gain_raw;
assign gain_raw = GAIN_BASE + sst_effective;

// Clamp gain to valid range [0.5, 1.5]
wire signed [WIDTH-1:0] gain_clamped;
assign gain_clamped = (gain_raw < GAIN_MIN) ? GAIN_MIN :
                      (gain_raw > GAIN_MAX) ? GAIN_MAX :
                      gain_raw;

// Output the clamped gain
assign apical_gain = gain_clamped;

// v9.4: Debug outputs
assign sst_activity_out = sst_activity;
assign vip_activity_out = vip_activity;
assign sst_effective_out = sst_effective;

endmodule
