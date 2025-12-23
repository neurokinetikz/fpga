//=============================================================================
// Configuration Controller - v8.0 with Scaffold Architecture
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

    // v8.0: Scaffold architecture indicator outputs
    output wire scaffold_l4,        // L4 is scaffold layer
    output wire scaffold_l5b,       // L5b is scaffold layer
    output wire plastic_l23,        // L2/3 is plastic layer
    output wire plastic_l6          // L6 is plastic layer
);

localparam [2:0] STATE_NORMAL     = 3'd0;
localparam [2:0] STATE_ANESTHESIA = 3'd1;
localparam [2:0] STATE_PSYCHEDELIC = 3'd2;
localparam [2:0] STATE_FLOW       = 3'd3;
localparam [2:0] STATE_MEDITATION = 3'd4;

// MU values scaled for 4 kHz update rate (dt=0.00025)
localparam signed [WIDTH-1:0] MU_FULL     = 18'sd4;
localparam signed [WIDTH-1:0] MU_HALF     = 18'sd2;
localparam signed [WIDTH-1:0] MU_WEAK     = 18'sd1;   // min practical value
localparam signed [WIDTH-1:0] MU_ENHANCED = 18'sd6;

// v8.0: Scaffold layer type indicators (static classification)
// These can be used by downstream modules to apply different processing
assign scaffold_l4  = 1'b1;  // L4 is always scaffold
assign scaffold_l5b = 1'b1;  // L5b is always scaffold
assign plastic_l23  = 1'b1;  // L2/3 is always plastic
assign plastic_l6   = 1'b1;  // L6 is always plastic

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mu_dt_theta <= MU_FULL;
        mu_dt_l6    <= MU_FULL;
        mu_dt_l5b   <= MU_FULL;
        mu_dt_l5a   <= MU_FULL;
        mu_dt_l4    <= MU_FULL;
        mu_dt_l23   <= MU_FULL;
    end else if (clk_en) begin
        case (state_select)
            STATE_NORMAL: begin
                mu_dt_theta <= MU_FULL;
                mu_dt_l6    <= MU_FULL;
                mu_dt_l5b   <= MU_FULL;
                mu_dt_l5a   <= MU_FULL;
                mu_dt_l4    <= MU_FULL;
                mu_dt_l23   <= MU_FULL;
            end
            STATE_ANESTHESIA: begin
                mu_dt_theta <= MU_HALF;
                mu_dt_l6    <= MU_ENHANCED;
                mu_dt_l5b   <= MU_HALF;
                mu_dt_l5a   <= MU_HALF;
                mu_dt_l4    <= MU_WEAK;
                mu_dt_l23   <= MU_WEAK;
            end
            STATE_PSYCHEDELIC: begin
                mu_dt_theta <= MU_FULL;
                mu_dt_l6    <= MU_HALF;
                mu_dt_l5b   <= MU_FULL;
                mu_dt_l5a   <= MU_FULL;
                mu_dt_l4    <= MU_ENHANCED;
                mu_dt_l23   <= MU_ENHANCED;
            end
            STATE_FLOW: begin
                mu_dt_theta <= MU_FULL;
                mu_dt_l6    <= MU_HALF;
                mu_dt_l5b   <= MU_ENHANCED;
                mu_dt_l5a   <= MU_ENHANCED;
                mu_dt_l4    <= MU_FULL;
                mu_dt_l23   <= MU_FULL;
            end
            STATE_MEDITATION: begin
                // Reduced MU values for frequency stability (high MU destabilizes)
                // MEDITATION = stable theta coherence, not aggressive amplitude
                mu_dt_theta <= MU_FULL;     // 4 (was 6) - stable theta
                mu_dt_l6    <= MU_FULL;     // 4 (was 6) - moderate alpha
                mu_dt_l5b   <= MU_HALF;     // 2 - low motor feedback
                mu_dt_l5a   <= MU_HALF;     // 2 - low motor output
                mu_dt_l4    <= MU_HALF;     // 2 - sensory withdrawal
                mu_dt_l23   <= MU_HALF;     // 2 - reduced gamma (internal focus)
            end
            default: begin
                mu_dt_theta <= MU_FULL;
                mu_dt_l6    <= MU_FULL;
                mu_dt_l5b   <= MU_FULL;
                mu_dt_l5a   <= MU_FULL;
                mu_dt_l4    <= MU_FULL;
                mu_dt_l23   <= MU_FULL;
            end
        endcase
    end
end

endmodule
