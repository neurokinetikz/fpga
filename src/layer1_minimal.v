//=============================================================================
// Layer 1 with SST+ Slow Dynamics - v9.1
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
// - Receives: matrix thalamic input, cortico-cortical feedback, neuromodulators
// - Outputs: modulation to L2/3 and L5 apical dendrites
// - Function: top-down attention gating, contextual integration
//
// SST+ GAIN MODEL (v9.1):
// 1. combined = 0.15 * matrix + 0.3 * feedback_1 + 0.2 * feedback_2
// 2. sst_activity = lowpass(combined, tau=25ms)  // SST+ slow dynamics
// 3. apical_gain = clamp(1.0 + sst_activity, 0.5, 1.5)
// - Slow rise/fall creates realistic inhibition dynamics
// - Time constant ~25ms matches GABA-B kinetics
//
// FUTURE ENHANCEMENTS:
// v9.4: VIP+ disinhibition of SST+
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

    // Output: multiplicative gain for L2/3 and L5 apical dendrites
    output wire signed [WIDTH-1:0] apical_gain
);

// Constants in Q4.14 format
localparam signed [WIDTH-1:0] GAIN_BASE  = 18'sd16384;  // 1.0 - unity gain baseline

// v9.2: Matrix thalamic weight (diffuse modulation, less than cortico-cortical)
localparam signed [WIDTH-1:0] K_MATRIX = 18'sd2458;  // 0.15 - matrix thalamus weight

// v9.1: Dual feedback weights
localparam signed [WIDTH-1:0] K_FB1 = 18'sd4915;   // 0.3 - adjacent column weight
localparam signed [WIDTH-1:0] K_FB2 = 18'sd3277;   // 0.2 - distant column weight

// Gain limits to prevent instability
localparam signed [WIDTH-1:0] GAIN_MIN = 18'sd8192;   // 0.5 minimum
localparam signed [WIDTH-1:0] GAIN_MAX = 18'sd24576;  // 1.5 maximum

//=============================================================================
// v9.1: SST+ Slow Dynamics Constants
//=============================================================================
// SST+ (Martinotti) cells have slow GABA-B kinetics
// Time constant ~25ms at 4 kHz update rate
// IIR filter: y[n] = y[n-1] + alpha * (x[n] - y[n-1])
// For tau = 25ms at dt = 0.25ms: alpha = dt/tau = 0.25/25 = 0.01
localparam signed [WIDTH-1:0] SST_ALPHA = 18'sd164;  // 0.01 - IIR filter coefficient

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

// v9.2: Total gain offset: 0.15*matrix + 0.3*fb1 + 0.2*fb2
wire signed [WIDTH-1:0] gain_offset;
assign gain_offset = matrix_contrib + fb1_contrib + fb2_contrib;

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

// Compute raw gain using FILTERED SST+ activity (not instantaneous)
wire signed [WIDTH-1:0] gain_raw;
assign gain_raw = GAIN_BASE + sst_activity;

// Clamp gain to valid range [0.5, 1.5]
wire signed [WIDTH-1:0] gain_clamped;
assign gain_clamped = (gain_raw < GAIN_MIN) ? GAIN_MIN :
                      (gain_raw > GAIN_MAX) ? GAIN_MAX :
                      gain_raw;

// Output the clamped gain
assign apical_gain = gain_clamped;

endmodule
