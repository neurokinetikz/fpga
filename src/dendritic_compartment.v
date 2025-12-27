//=============================================================================
// Dendritic Compartment Model - v9.5
//
// Two-compartment model for pyramidal neurons implementing:
// - Basal compartment: receives feedforward input (direct passthrough)
// - Apical compartment: receives feedback input (Ca2+ spike dynamics)
// - BAC firing: supralinear coincidence detection
//
// BIOLOGICAL BASIS:
// - Basal dendrites: proximal, fast AMPA, bottom-up sensory (L4->L2/3)
// - Apical dendrites: distal (L1), slow NMDA/Ca2+, top-down context
// - Ca2+ spikes: plateau potentials (~20-50ms duration)
// - BAC firing: when basal soma spike meets apical Ca2+, output boosted 1.5x
//
// MATHEMATICAL MODEL:
// 1. Apical cable filter: low-pass IIR (tau=10ms) models electrotonic decay
// 2. Ca2+ threshold: triggers when apical_depot > ca_threshold (state-dependent)
// 3. Ca2+ spike state: slow IIR (tau=30ms) models plateau duration
// 4. BAC detection: coincidence of basal activity AND Ca2+ spike
// 5. Output: (basal + K_APICAL * ca_spike) * bac_boost
//
// USAGE:
// Applied to L2/3, L5a, L5b (neurons with apical dendrites reaching L1)
// NOT applied to L4, L6 (dendrites don't extend to L1)
//=============================================================================
`timescale 1ns / 1ps

module dendritic_compartment #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Basal compartment input (feedforward)
    input  wire signed [WIDTH-1:0] basal_input,

    // Apical compartment input (feedback)
    input  wire signed [WIDTH-1:0] apical_input,

    // L1 gain modulation (from SST+/VIP+ circuit)
    input  wire signed [WIDTH-1:0] apical_gain,

    // State-dependent Ca2+ threshold (from config_controller)
    input  wire signed [WIDTH-1:0] ca_threshold,

    // Output to oscillator
    output wire signed [WIDTH-1:0] dendritic_output,

    // Debug outputs
    output wire ca_spike_active,
    output wire bac_active
);

//=============================================================================
// Constants (Q4.14 format)
//=============================================================================
localparam signed [WIDTH-1:0] ONE = 18'sd16384;           // 1.0
localparam signed [WIDTH-1:0] ZERO = 18'sd0;

// Apical cable filter: tau = 10ms at 4kHz (dt = 0.25ms)
// alpha = dt/tau = 0.25/10 = 0.025
localparam signed [WIDTH-1:0] APICAL_CABLE_ALPHA = 18'sd410;  // 0.025

// Ca2+ spike duration: tau = 30ms at 4kHz
// alpha = dt/tau = 0.25/30 = 0.00833
localparam signed [WIDTH-1:0] CA_DURATION_ALPHA = 18'sd137;   // 0.00833

// Apical contribution weight to final output
localparam signed [WIDTH-1:0] K_APICAL = 18'sd4096;           // 0.25

// BAC supralinear boost factor (binary: 1.0 or 1.5)
localparam signed [WIDTH-1:0] K_BAC = 18'sd24576;             // 1.5

// Thresholds for BAC detection
localparam signed [WIDTH-1:0] BAC_BASAL_THRESH = 18'sd4096;   // 0.25
localparam signed [WIDTH-1:0] BAC_APICAL_THRESH = 18'sd4096;  // 0.25

//=============================================================================
// Apical Compartment: L1 Gain Modulation
//=============================================================================
// First apply L1 SST+/VIP+ gain to apical input
wire signed [2*WIDTH-1:0] apical_scaled_full;
wire signed [WIDTH-1:0] apical_scaled;

assign apical_scaled_full = apical_input * apical_gain;
assign apical_scaled = apical_scaled_full >>> FRAC;

//=============================================================================
// Apical Compartment: Dendritic Cable Filter (tau=10ms)
//=============================================================================
// Models electrotonic decay along apical dendrite trunk
// IIR lowpass: depot[n] = depot[n-1] + alpha * (input - depot[n-1])
reg signed [WIDTH-1:0] apical_depot;

wire signed [WIDTH-1:0] cable_error;
wire signed [2*WIDTH-1:0] cable_delta_full;
wire signed [WIDTH-1:0] cable_delta;

assign cable_error = apical_scaled - apical_depot;
assign cable_delta_full = cable_error * APICAL_CABLE_ALPHA;
assign cable_delta = cable_delta_full >>> FRAC;

always @(posedge clk) begin
    if (rst) begin
        apical_depot <= ZERO;
    end else if (clk_en) begin
        apical_depot <= apical_depot + cable_delta;
    end
end

//=============================================================================
// Calcium Spike Detection and Duration
//=============================================================================
// Threshold crossing triggers Ca2+ spike
// Spike has slow dynamics (tau=30ms) modeling plateau potential

// Threshold is state-dependent (passed in from config_controller)
wire ca_threshold_crossed;
assign ca_threshold_crossed = (apical_depot > ca_threshold);

// Ca2+ spike state with slow rise/fall dynamics
reg signed [WIDTH-1:0] ca_spike_state;

wire signed [WIDTH-1:0] ca_target;
wire signed [WIDTH-1:0] ca_error;
wire signed [2*WIDTH-1:0] ca_delta_full;
wire signed [WIDTH-1:0] ca_delta;

// Target: ONE (1.0) when threshold crossed, ZERO (0.0) otherwise
assign ca_target = ca_threshold_crossed ? ONE : ZERO;
assign ca_error = ca_target - ca_spike_state;
assign ca_delta_full = ca_error * CA_DURATION_ALPHA;
assign ca_delta = ca_delta_full >>> FRAC;

always @(posedge clk) begin
    if (rst) begin
        ca_spike_state <= ZERO;
    end else if (clk_en) begin
        ca_spike_state <= ca_spike_state + ca_delta;
    end
end

// Clamp Ca2+ to positive (calcium concentration can't go negative)
wire signed [WIDTH-1:0] ca_spike_clamped;
assign ca_spike_clamped = (ca_spike_state < ZERO) ? ZERO : ca_spike_state;

// Ca2+ spike is "active" when above threshold
assign ca_spike_active = (ca_spike_clamped > BAC_APICAL_THRESH);

//=============================================================================
// BAC Firing: Coincidence Detection
//=============================================================================
// BAC = Backpropagation-Activated Calcium firing
// When basal (soma) AND apical (Ca2+) are both active, boost output

wire basal_active;
wire apical_ca_active;
wire bac_coincidence;

// Basal is active if significant input (either positive or negative)
assign basal_active = (basal_input > BAC_BASAL_THRESH) ||
                      (basal_input < -BAC_BASAL_THRESH);

// Apical is active if Ca2+ spike is above threshold
assign apical_ca_active = (ca_spike_clamped > BAC_APICAL_THRESH);

// Coincidence: both compartments active simultaneously
assign bac_coincidence = basal_active && apical_ca_active;

assign bac_active = bac_coincidence;

// BAC boost factor: 1.5x when coincident, 1.0x otherwise (BINARY)
wire signed [WIDTH-1:0] bac_factor;
assign bac_factor = bac_coincidence ? K_BAC : ONE;

//=============================================================================
// Output Integration
//=============================================================================
// Combine basal (direct) + apical (Ca2+ modulated) with BAC boost
//
// Output = (basal + K_APICAL * ca_spike) * bac_factor
//
// When no Ca2+ spike: output = basal * 1.0 (passthrough)
// When Ca2+ spike but no BAC: output = (basal + 0.25*ca) * 1.0
// When BAC coincidence: output = (basal + 0.25*ca) * 1.5

wire signed [2*WIDTH-1:0] apical_contrib_full;
wire signed [WIDTH-1:0] apical_contrib;
wire signed [WIDTH-1:0] combined;
wire signed [2*WIDTH-1:0] boosted_full;
wire signed [WIDTH-1:0] boosted;

// Apical contribution scaled by Ca2+ spike state
assign apical_contrib_full = ca_spike_clamped * K_APICAL;
assign apical_contrib = apical_contrib_full >>> FRAC;

// Combine basal + apical contribution
assign combined = basal_input + apical_contrib;

// Apply BAC boost
assign boosted_full = combined * bac_factor;
assign boosted = boosted_full >>> FRAC;

assign dendritic_output = boosted;

endmodule
