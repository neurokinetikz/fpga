//=============================================================================
// Configuration Controller - v12.4 with State-Dependent Phase Coupling
//
// v12.4 CHANGES:
// - Add state-dependent k_phase_couple output for hippocampal-cortical balance
// - NORMAL: 0.05× (balanced sensory-memory)
// - ANESTHESIA/PSYCHEDELIC: 0.02× (suppressed hippocampal)
// - MEDITATION: 0.15× (memory consolidation)
// - Fixes 20:1 phase coupling dominance over L4 feedforward
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

    // v11.4: Transition control - 0 = instant (backward compatible)
    input  wire [15:0] transition_duration,

    output reg signed [WIDTH-1:0] mu_dt_theta,
    output reg signed [WIDTH-1:0] mu_dt_l6,
    output reg signed [WIDTH-1:0] mu_dt_l5b,
    output reg signed [WIDTH-1:0] mu_dt_l5a,
    output reg signed [WIDTH-1:0] mu_dt_l4,
    output reg signed [WIDTH-1:0] mu_dt_l23,

    // v9.5: State-dependent Ca2+ threshold for dendritic compartment
    output reg signed [WIDTH-1:0] ca_threshold,

    // v12.4: State-dependent phase coupling gain
    // Controls hippocampal-cortical balance (fixes 20:1 dominance bug)
    output reg signed [WIDTH-1:0] k_phase_couple,

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
    output reg [15:0] sie_refractory,   // Refractory period (no re-ignition)

    // v11.4: Transition status outputs
    output reg        transitioning,           // High during active transition
    output reg [15:0] transition_progress,     // 0-65535 ramp position
    output reg [2:0]  transition_from,         // Source state
    output reg [2:0]  transition_to            // Target state
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

// v12.4: Phase coupling gain values (Q14)
// Controls hippocampal→cortical signal strength relative to L4 feedforward (K_L4_L23=0.05)
// Fixes the 20:1 dominance bug where phase coupling entered at 1.0× unscaled
localparam signed [WIDTH-1:0] K_PHASE_NORMAL      = 18'sd820;   // 0.05 - balanced (1:1 vs L4)
localparam signed [WIDTH-1:0] K_PHASE_ANESTHESIA  = 18'sd328;   // 0.02 - suppressed (0.4:1)
localparam signed [WIDTH-1:0] K_PHASE_PSYCHEDELIC = 18'sd328;   // 0.02 - sensory-dominant (0.4:1)
localparam signed [WIDTH-1:0] K_PHASE_FLOW        = 18'sd820;   // 0.05 - balanced (1:1)
localparam signed [WIDTH-1:0] K_PHASE_MEDITATION  = 18'sd2458;  // 0.15 - memory consolidation (3:1)

// v8.0: Scaffold layer type indicators (static classification)
// These can be used by downstream modules to apply different processing
assign scaffold_l4  = 1'b1;  // L4 is always scaffold
assign scaffold_l5b = 1'b1;  // L5b is always scaffold
assign plastic_l23  = 1'b1;  // L2/3 is always plastic
assign plastic_l6   = 1'b1;  // L6 is always plastic

//=============================================================================
// v11.4: State Transition Interpolation
// Linear interpolation between states for smooth transitions
//=============================================================================

// Internal state tracking
reg [2:0] current_state;           // Confirmed current state
reg [15:0] ramp_counter;           // Position in transition

// Shadow registers: start values for interpolation
reg signed [WIDTH-1:0] mu_start_theta, mu_start_l6, mu_start_l5b;
reg signed [WIDTH-1:0] mu_start_l5a, mu_start_l4, mu_start_l23;
reg signed [WIDTH-1:0] ca_thresh_start;
reg signed [WIDTH-1:0] k_phase_start;  // v12.4: Phase coupling gain interpolation
reg [15:0] sie_start_p2, sie_start_p3, sie_start_p4;
reg [15:0] sie_start_p5, sie_start_p6, sie_start_refr;

// Target values based on state_select (combinational lookup)
reg signed [WIDTH-1:0] mu_tgt_theta, mu_tgt_l6, mu_tgt_l5b;
reg signed [WIDTH-1:0] mu_tgt_l5a, mu_tgt_l4, mu_tgt_l23;
reg signed [WIDTH-1:0] ca_tgt;
reg signed [WIDTH-1:0] k_phase_tgt;  // v12.4: Phase coupling gain target
reg [15:0] sie_tgt_p2, sie_tgt_p3, sie_tgt_p4;
reg [15:0] sie_tgt_p5, sie_tgt_p6, sie_tgt_refr;

always @(*) begin
    case (state_select)
        STATE_NORMAL: begin
            mu_tgt_theta = MU_MODERATE; mu_tgt_l6 = MU_MODERATE;
            mu_tgt_l5b = MU_MODERATE;   mu_tgt_l5a = MU_MODERATE;
            mu_tgt_l4 = MU_MODERATE;    mu_tgt_l23 = MU_MODERATE;
            ca_tgt = CA_THRESH_NORMAL;
            k_phase_tgt = K_PHASE_NORMAL;  // v12.4: 0.05 - balanced (1:1 vs L4)
            sie_tgt_p2 = 16'd14000; sie_tgt_p3 = 16'd10000;
            sie_tgt_p4 = 16'd10000; sie_tgt_p5 = 16'd36000;
            sie_tgt_p6 = 16'd16000; sie_tgt_refr = 16'd40000;
        end
        STATE_ANESTHESIA: begin
            mu_tgt_theta = MU_HALF;     mu_tgt_l6 = MU_ENHANCED;
            mu_tgt_l5b = MU_HALF;       mu_tgt_l5a = MU_HALF;
            mu_tgt_l4 = MU_WEAK;        mu_tgt_l23 = MU_WEAK;
            ca_tgt = CA_THRESH_ANESTHESIA;
            k_phase_tgt = K_PHASE_ANESTHESIA;  // v12.4: 0.02 - suppressed (0.4:1)
            sie_tgt_p2 = 16'd20000; sie_tgt_p3 = 16'd8000;
            sie_tgt_p4 = 16'd8000;  sie_tgt_p5 = 16'd24000;
            sie_tgt_p6 = 16'd20000; sie_tgt_refr = 16'd60000;
        end
        STATE_PSYCHEDELIC: begin
            mu_tgt_theta = MU_FULL;     mu_tgt_l6 = MU_HALF;
            mu_tgt_l5b = MU_FULL;       mu_tgt_l5a = MU_FULL;
            mu_tgt_l4 = MU_ENHANCED;    mu_tgt_l23 = MU_ENHANCED;
            ca_tgt = CA_THRESH_PSYCHEDELIC;
            k_phase_tgt = K_PHASE_PSYCHEDELIC;  // v12.4: 0.02 - sensory-dominant (0.4:1)
            sie_tgt_p2 = 16'd16000; sie_tgt_p3 = 16'd12000;
            sie_tgt_p4 = 16'd16000; sie_tgt_p5 = 16'd48000;
            sie_tgt_p6 = 16'd20000; sie_tgt_refr = 16'd24000;
        end
        STATE_FLOW: begin
            mu_tgt_theta = MU_FULL;     mu_tgt_l6 = MU_HALF;
            mu_tgt_l5b = MU_ENHANCED;   mu_tgt_l5a = MU_ENHANCED;
            mu_tgt_l4 = MU_FULL;        mu_tgt_l23 = MU_FULL;
            ca_tgt = CA_THRESH_FLOW;
            k_phase_tgt = K_PHASE_FLOW;  // v12.4: 0.05 - balanced (1:1)
            sie_tgt_p2 = 16'd12000; sie_tgt_p3 = 16'd8000;
            sie_tgt_p4 = 16'd8000;  sie_tgt_p5 = 16'd32000;
            sie_tgt_p6 = 16'd12000; sie_tgt_refr = 16'd48000;
        end
        STATE_MEDITATION: begin
            mu_tgt_theta = MU_ENHANCED; mu_tgt_l6 = MU_ENHANCED;
            mu_tgt_l5b = MU_WEAK;       mu_tgt_l5a = MU_WEAK;
            mu_tgt_l4 = MU_WEAK;        mu_tgt_l23 = MU_HALF;
            ca_tgt = CA_THRESH_MEDITATION;
            k_phase_tgt = K_PHASE_MEDITATION;  // v12.4: 0.15 - memory consolidation (3:1)
            sie_tgt_p2 = 16'd16000; sie_tgt_p3 = 16'd12000;
            sie_tgt_p4 = 16'd12000; sie_tgt_p5 = 16'd40000;
            sie_tgt_p6 = 16'd20000; sie_tgt_refr = 16'd32000;
        end
        default: begin
            mu_tgt_theta = MU_FULL;     mu_tgt_l6 = MU_FULL;
            mu_tgt_l5b = MU_FULL;       mu_tgt_l5a = MU_FULL;
            mu_tgt_l4 = MU_FULL;        mu_tgt_l23 = MU_FULL;
            ca_tgt = CA_THRESH_NORMAL;
            k_phase_tgt = K_PHASE_NORMAL;  // v12.4: default to NORMAL
            sie_tgt_p2 = 16'd14000; sie_tgt_p3 = 16'd10000;
            sie_tgt_p4 = 16'd10000; sie_tgt_p5 = 16'd36000;
            sie_tgt_p6 = 16'd16000; sie_tgt_refr = 16'd40000;
        end
    endcase
end

// Linear interpolation functions
// lerp_signed: Returns start + (end - start) * t / duration
// Note: Must cast unsigned t and duration to signed to handle negative delta
function signed [WIDTH-1:0] lerp_signed;
    input signed [WIDTH-1:0] start_val;
    input signed [WIDTH-1:0] end_val;
    input [15:0] t;
    input [15:0] duration;
    reg signed [WIDTH+16:0] delta;
    reg signed [WIDTH+16:0] scaled;
    reg signed [WIDTH+16:0] result;
    begin
        delta = end_val - start_val;
        // Cast t to signed (with leading 0) to preserve sign in multiplication
        scaled = delta * $signed({1'b0, t});
        result = start_val + scaled / $signed({1'b0, duration});
        lerp_signed = result[WIDTH-1:0];
    end
endfunction

// lerp_unsigned: Unsigned version for SIE timing parameters
function [15:0] lerp_unsigned;
    input [15:0] start_val;
    input [15:0] end_val;
    input [15:0] t;
    input [15:0] duration;
    reg [31:0] delta;
    reg [31:0] result;
    begin
        if (end_val >= start_val) begin
            delta = end_val - start_val;
            result = start_val + (delta * t) / duration;
        end else begin
            delta = start_val - end_val;
            result = start_val - (delta * t) / duration;
        end
        lerp_unsigned = result[15:0];
    end
endfunction

// State change detection (restart from current if mid-transition)
wire state_changed = (state_select != transition_to);
// Handle undefined/unconnected transition_duration (defaults to instant: 1 cycle)
// Note: ^val === 1'bx detects any 'x' bits in the value
wire [15:0] ramp_dur = (transition_duration == 16'd0 || ^transition_duration === 1'bx) ? 16'd1 : transition_duration;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset all outputs to NORMAL
        mu_dt_theta <= MU_MODERATE;
        mu_dt_l6    <= MU_MODERATE;
        mu_dt_l5b   <= MU_MODERATE;
        mu_dt_l5a   <= MU_MODERATE;
        mu_dt_l4    <= MU_MODERATE;
        mu_dt_l23   <= MU_MODERATE;
        ca_threshold <= CA_THRESH_NORMAL;
        k_phase_couple <= K_PHASE_NORMAL;  // v12.4: Phase coupling gain
        sie_phase2_dur <= 16'd14000;
        sie_phase3_dur <= 16'd10000;
        sie_phase4_dur <= 16'd10000;
        sie_phase5_dur <= 16'd36000;
        sie_phase6_dur <= 16'd16000;
        sie_refractory <= 16'd40000;

        // Reset transition state
        transitioning <= 1'b0;
        ramp_counter <= 16'd0;
        current_state <= STATE_NORMAL;
        transition_from <= STATE_NORMAL;
        transition_to <= STATE_NORMAL;
        transition_progress <= 16'd0;

        // Reset shadow registers
        mu_start_theta <= MU_MODERATE;
        mu_start_l6 <= MU_MODERATE;
        mu_start_l5b <= MU_MODERATE;
        mu_start_l5a <= MU_MODERATE;
        mu_start_l4 <= MU_MODERATE;
        mu_start_l23 <= MU_MODERATE;
        ca_thresh_start <= CA_THRESH_NORMAL;
        k_phase_start <= K_PHASE_NORMAL;  // v12.4: Phase coupling interpolation start
        sie_start_p2 <= 16'd14000;
        sie_start_p3 <= 16'd10000;
        sie_start_p4 <= 16'd10000;
        sie_start_p5 <= 16'd36000;
        sie_start_p6 <= 16'd16000;
        sie_start_refr <= 16'd40000;

    end else if (clk_en) begin
        if (state_changed) begin
            // NEW TRANSITION: Capture current values as start point
            mu_start_theta <= mu_dt_theta;
            mu_start_l6 <= mu_dt_l6;
            mu_start_l5b <= mu_dt_l5b;
            mu_start_l5a <= mu_dt_l5a;
            mu_start_l4 <= mu_dt_l4;
            mu_start_l23 <= mu_dt_l23;
            ca_thresh_start <= ca_threshold;
            k_phase_start <= k_phase_couple;  // v12.4: Capture for interpolation
            sie_start_p2 <= sie_phase2_dur;
            sie_start_p3 <= sie_phase3_dur;
            sie_start_p4 <= sie_phase4_dur;
            sie_start_p5 <= sie_phase5_dur;
            sie_start_p6 <= sie_phase6_dur;
            sie_start_refr <= sie_refractory;

            // Start transition
            transition_from <= transition_to;  // From wherever we are
            transition_to <= state_select;
            transitioning <= 1'b1;
            ramp_counter <= 16'd0;
            transition_progress <= 16'd0;

        end else if (transitioning) begin
            if (ramp_counter >= ramp_dur) begin
                // TRANSITION COMPLETE: Snap to final values
                mu_dt_theta <= mu_tgt_theta;
                mu_dt_l6 <= mu_tgt_l6;
                mu_dt_l5b <= mu_tgt_l5b;
                mu_dt_l5a <= mu_tgt_l5a;
                mu_dt_l4 <= mu_tgt_l4;
                mu_dt_l23 <= mu_tgt_l23;
                ca_threshold <= ca_tgt;
                k_phase_couple <= k_phase_tgt;  // v12.4: Phase coupling gain
                sie_phase2_dur <= sie_tgt_p2;
                sie_phase3_dur <= sie_tgt_p3;
                sie_phase4_dur <= sie_tgt_p4;
                sie_phase5_dur <= sie_tgt_p5;
                sie_phase6_dur <= sie_tgt_p6;
                sie_refractory <= sie_tgt_refr;

                transitioning <= 1'b0;
                current_state <= transition_to;
                transition_progress <= 16'hFFFF;

            end else begin
                // INTERPOLATING: Apply lerp to all parameters
                ramp_counter <= ramp_counter + 1'b1;
                // v11.4 FIX: Use 32-bit arithmetic to prevent overflow
                // ramp_counter * 65535 can exceed 16 bits, causing wrap-around
                transition_progress <= ({16'd0, ramp_counter} * 32'd65535) / {16'd0, ramp_dur};

                // MU values (signed lerp)
                mu_dt_theta <= lerp_signed(mu_start_theta, mu_tgt_theta, ramp_counter, ramp_dur);
                mu_dt_l6    <= lerp_signed(mu_start_l6, mu_tgt_l6, ramp_counter, ramp_dur);
                mu_dt_l5b   <= lerp_signed(mu_start_l5b, mu_tgt_l5b, ramp_counter, ramp_dur);
                mu_dt_l5a   <= lerp_signed(mu_start_l5a, mu_tgt_l5a, ramp_counter, ramp_dur);
                mu_dt_l4    <= lerp_signed(mu_start_l4, mu_tgt_l4, ramp_counter, ramp_dur);
                mu_dt_l23   <= lerp_signed(mu_start_l23, mu_tgt_l23, ramp_counter, ramp_dur);
                ca_threshold <= lerp_signed(ca_thresh_start, ca_tgt, ramp_counter, ramp_dur);
                k_phase_couple <= lerp_signed(k_phase_start, k_phase_tgt, ramp_counter, ramp_dur);  // v12.4

                // SIE timing (unsigned lerp)
                sie_phase2_dur <= lerp_unsigned(sie_start_p2, sie_tgt_p2, ramp_counter, ramp_dur);
                sie_phase3_dur <= lerp_unsigned(sie_start_p3, sie_tgt_p3, ramp_counter, ramp_dur);
                sie_phase4_dur <= lerp_unsigned(sie_start_p4, sie_tgt_p4, ramp_counter, ramp_dur);
                sie_phase5_dur <= lerp_unsigned(sie_start_p5, sie_tgt_p5, ramp_counter, ramp_dur);
                sie_phase6_dur <= lerp_unsigned(sie_start_p6, sie_tgt_p6, ramp_counter, ramp_dur);
                sie_refractory <= lerp_unsigned(sie_start_refr, sie_tgt_refr, ramp_counter, ramp_dur);
            end
        end
        // else: stable state, no changes
    end
end

endmodule
