//=============================================================================
// Configuration Controller - v9.5 with Dendritic Computation
//
// v9.5 CHANGES:
// - Add state-dependent Ca2+ threshold for two-compartment dendritic model
// - Lower threshold in PSYCHEDELIC = more Ca2+ spikes (enhanced top-down)
// - Higher threshold in ANESTHESIA = fewer Ca2+ spikes (reduced integration)
//
// v8.0 CHANGES (Dupret et al. 2025 Integration):
// - Scaffold architecture: distinguishes stable vs plastic cortical layers
// - Scaffold layers (L4, L5b): higher baseline MU, resistant to perturbation
//   "Higher-activity cells form stable backbone"
// - Plastic layers (L2/3, L6): lower baseline MU, integrate new patterns
//   "Lower-activity cells integrate new motifs"
// - Phase coupling only affects plastic layers (L2/3, L6)
// - This implements the "scaffolding principle" from hippocampal memory
//
// LAYER CLASSIFICATION:
//   SCAFFOLD (stable backbone):
//     - L4 (31.73 Hz): Thalamocortical input boundary, anchors spatial context
//     - L5b (24.94 Hz): High beta feedback, maintains state
//   PLASTIC (flexible integration):
//     - L2/3 (40.36 Hz): Gamma feedforward, receives phase coupling
//     - L6 (9.53 Hz): Alpha gain control, receives phase coupling
//     - L5a (15.42 Hz): Low beta motor, intermediate plasticity
//
//=============================================================================
`timescale 1ns / 1ps

module config_controller #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,
    input  wire [2:0] state_select,

    output reg signed [WIDTH-1:0] mu_dt_theta,
    output reg signed [WIDTH-1:0] mu_dt_l6,
    output reg signed [WIDTH-1:0] mu_dt_l5b,
    output reg signed [WIDTH-1:0] mu_dt_l5a,
    output reg signed [WIDTH-1:0] mu_dt_l4,
    output reg signed [WIDTH-1:0] mu_dt_l23,

    // v9.5: State-dependent Ca2+ threshold for dendritic compartment
    output reg signed [WIDTH-1:0] ca_threshold,

    // v8.0: Scaffold architecture indicator outputs
    output wire scaffold_l4,        // L4 is scaffold layer
    output wire scaffold_l5b,       // L5b is scaffold layer
    output wire plastic_l23,        // L2/3 is plastic layer
    output wire plastic_l6,         // L6 is plastic layer

    // v10.0: SIE (Schumann Ignition Event) phase timing outputs
    // Values in 4kHz cycles (250us per cycle)
    // Based on empirical EEG data: 3-4s, 2-3s, 2-3s, 8-10s, 3-5s event + 10s refractory
    output reg [15:0] sie_phase2_dur,   // Coherence-first phase duration
    output reg [15:0] sie_phase3_dur,   // Ignition phase duration
    output reg [15:0] sie_phase4_dur,   // Plateau phase duration
    output reg [15:0] sie_phase5_dur,   // Propagation phase duration
    output reg [15:0] sie_phase6_dur,   // Decay phase duration
    output reg [15:0] sie_refractory    // Refractory period (no re-ignition)
);

localparam [2:0] STATE_NORMAL     = 3'd0;
localparam [2:0] STATE_ANESTHESIA = 3'd1;
localparam [2:0] STATE_PSYCHEDELIC = 3'd2;
localparam [2:0] STATE_FLOW       = 3'd3;
localparam [2:0] STATE_MEDITATION = 3'd4;

// MU values scaled for 4 kHz update rate (dt=0.00025)
localparam signed [WIDTH-1:0] MU_FULL     = 18'sd4;
localparam signed [WIDTH-1:0] MU_MODERATE = 18'sd3;   // v11.1: between FULL and HALF for NORMAL state
localparam signed [WIDTH-1:0] MU_HALF     = 18'sd2;
localparam signed [WIDTH-1:0] MU_WEAK     = 18'sd1;   // min practical value
localparam signed [WIDTH-1:0] MU_ENHANCED = 18'sd6;

// v9.5: Ca2+ threshold values (Q14)
// Lower threshold = more Ca2+ spikes = enhanced top-down integration
// Higher threshold = fewer Ca2+ spikes = reduced integration
localparam signed [WIDTH-1:0] CA_THRESH_NORMAL     = 18'sd8192;   // 0.5 - balanced
localparam signed [WIDTH-1:0] CA_THRESH_ANESTHESIA = 18'sd12288;  // 0.75 - harder to trigger
localparam signed [WIDTH-1:0] CA_THRESH_PSYCHEDELIC = 18'sd4096;  // 0.25 - easier to trigger
localparam signed [WIDTH-1:0] CA_THRESH_FLOW       = 18'sd8192;   // 0.5 - balanced
localparam signed [WIDTH-1:0] CA_THRESH_MEDITATION = 18'sd6144;   // 0.375 - slightly easier

// v8.0: Scaffold layer type indicators (static classification)
// These can be used by downstream modules to apply different processing
assign scaffold_l4  = 1'b1;  // L4 is always scaffold
assign scaffold_l5b = 1'b1;  // L5b is always scaffold
assign plastic_l23  = 1'b1;  // L2/3 is always plastic
assign plastic_l6   = 1'b1;  // L6 is always plastic

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mu_dt_theta <= MU_MODERATE;  // v11.1: reduced from MU_FULL to prevent clipping
        mu_dt_l6    <= MU_MODERATE;
        mu_dt_l5b   <= MU_MODERATE;
        mu_dt_l5a   <= MU_MODERATE;
        mu_dt_l4    <= MU_MODERATE;
        mu_dt_l23   <= MU_MODERATE;
        ca_threshold <= CA_THRESH_NORMAL;
        // v10.0: SIE timing reset (NORMAL state defaults)
        sie_phase2_dur <= 16'd14000;  // 3.5s coherence-first
        sie_phase3_dur <= 16'd10000;  // 2.5s ignition
        sie_phase4_dur <= 16'd10000;  // 2.5s plateau
        sie_phase5_dur <= 16'd36000;  // 9s propagation (PAC window)
        sie_phase6_dur <= 16'd16000;  // 4s decay
        sie_refractory <= 16'd40000;  // 10s refractory
    end else if (clk_en) begin
        case (state_select)
            STATE_NORMAL: begin
                // v11.1: Reduced from MU_FULL (4) to MU_MODERATE (3) to prevent DAC clipping
                // Amplitude: sqrt(3) ≈ 1.73 instead of 2.0, still distinct from MEDITATION
                mu_dt_theta  <= MU_MODERATE;
                mu_dt_l6     <= MU_MODERATE;
                mu_dt_l5b    <= MU_MODERATE;
                mu_dt_l5a    <= MU_MODERATE;
                mu_dt_l4     <= MU_MODERATE;
                mu_dt_l23    <= MU_MODERATE;
                ca_threshold <= CA_THRESH_NORMAL;  // 0.5 - balanced
                // SIE timing: ~21.5s event + 10s refractory
                sie_phase2_dur <= 16'd14000;  // 3.5s coherence-first
                sie_phase3_dur <= 16'd10000;  // 2.5s ignition
                sie_phase4_dur <= 16'd10000;  // 2.5s plateau
                sie_phase5_dur <= 16'd36000;  // 9s propagation
                sie_phase6_dur <= 16'd16000;  // 4s decay
                sie_refractory <= 16'd40000;  // 10s refractory
            end
            STATE_ANESTHESIA: begin
                mu_dt_theta  <= MU_HALF;
                mu_dt_l6     <= MU_ENHANCED;
                mu_dt_l5b    <= MU_HALF;
                mu_dt_l5a    <= MU_HALF;
                mu_dt_l4     <= MU_WEAK;
                mu_dt_l23    <= MU_WEAK;
                ca_threshold <= CA_THRESH_ANESTHESIA;  // 0.75 - fewer Ca2+ spikes
                // SIE timing: reduced/suppressed events (longer refractory)
                sie_phase2_dur <= 16'd20000;  // 5s coherence (sluggish)
                sie_phase3_dur <= 16'd8000;   // 2s ignition (weak)
                sie_phase4_dur <= 16'd8000;   // 2s plateau
                sie_phase5_dur <= 16'd24000;  // 6s propagation (reduced)
                sie_phase6_dur <= 16'd20000;  // 5s decay (prolonged)
                sie_refractory <= 16'd60000;  // 15s refractory (suppressed)
            end
            STATE_PSYCHEDELIC: begin
                mu_dt_theta  <= MU_FULL;
                mu_dt_l6     <= MU_HALF;
                mu_dt_l5b    <= MU_FULL;
                mu_dt_l5a    <= MU_FULL;
                mu_dt_l4     <= MU_ENHANCED;
                mu_dt_l23    <= MU_ENHANCED;
                ca_threshold <= CA_THRESH_PSYCHEDELIC;  // 0.25 - more Ca2+ spikes
                // SIE timing: ~28s event + 6s refractory (extended propagation, short gap)
                sie_phase2_dur <= 16'd16000;  // 4s coherence
                sie_phase3_dur <= 16'd12000;  // 3s ignition (intense)
                sie_phase4_dur <= 16'd16000;  // 4s plateau (sustained peak)
                sie_phase5_dur <= 16'd48000;  // 12s propagation (extended PAC)
                sie_phase6_dur <= 16'd20000;  // 5s decay
                sie_refractory <= 16'd24000;  // 6s refractory (frequent events)
            end
            STATE_FLOW: begin
                mu_dt_theta  <= MU_FULL;
                mu_dt_l6     <= MU_HALF;
                mu_dt_l5b    <= MU_ENHANCED;
                mu_dt_l5a    <= MU_ENHANCED;
                mu_dt_l4     <= MU_FULL;
                mu_dt_l23    <= MU_FULL;
                ca_threshold <= CA_THRESH_FLOW;  // 0.5 - balanced
                // SIE timing: ~18s event + 12s refractory (shorter events, longer gaps)
                sie_phase2_dur <= 16'd12000;  // 3s coherence (quick)
                sie_phase3_dur <= 16'd8000;   // 2s ignition
                sie_phase4_dur <= 16'd8000;   // 2s plateau
                sie_phase5_dur <= 16'd32000;  // 8s propagation
                sie_phase6_dur <= 16'd12000;  // 3s decay
                sie_refractory <= 16'd48000;  // 12s refractory (task focus)
            end
            STATE_MEDITATION: begin
                // Reduced MU values for frequency stability (high MU destabilizes)
                // MEDITATION = stable theta coherence, not aggressive amplitude
                mu_dt_theta  <= MU_FULL;     // 4 (was 6) - stable theta
                mu_dt_l6     <= MU_FULL;     // 4 (was 6) - moderate alpha
                mu_dt_l5b    <= MU_HALF;     // 2 - low motor feedback
                mu_dt_l5a    <= MU_HALF;     // 2 - low motor output
                mu_dt_l4     <= MU_HALF;     // 2 - sensory withdrawal
                mu_dt_l23    <= MU_HALF;     // 2 - reduced gamma (internal focus)
                ca_threshold <= CA_THRESH_MEDITATION;  // 0.375 - enhanced top-down
                // SIE timing: ~25s event + 8s refractory (enhanced, prominent events)
                sie_phase2_dur <= 16'd16000;  // 4s coherence (extended awareness)
                sie_phase3_dur <= 16'd12000;  // 3s ignition
                sie_phase4_dur <= 16'd12000;  // 3s plateau (sustained)
                sie_phase5_dur <= 16'd40000;  // 10s propagation (enhanced PAC)
                sie_phase6_dur <= 16'd20000;  // 5s decay (slow return)
                sie_refractory <= 16'd32000;  // 8s refractory (moderate frequency)
            end
            default: begin
                mu_dt_theta  <= MU_FULL;
                mu_dt_l6     <= MU_FULL;
                mu_dt_l5b    <= MU_FULL;
                mu_dt_l5a    <= MU_FULL;
                mu_dt_l4     <= MU_FULL;
                mu_dt_l23    <= MU_FULL;
                ca_threshold <= CA_THRESH_NORMAL;  // 0.5 - balanced
                // SIE timing: same as NORMAL
                sie_phase2_dur <= 16'd14000;
                sie_phase3_dur <= 16'd10000;
                sie_phase4_dur <= 16'd10000;
                sie_phase5_dur <= 16'd36000;
                sie_phase6_dur <= 16'd16000;
                sie_refractory <= 16'd40000;
            end
        endcase
    end
end

endmodule
