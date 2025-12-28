//=============================================================================
// Coupling Mode Controller - v1.0
//
// Dynamically switches between two coupling regimes based on system state:
//
// MODULATORY MODE (baseline):
//   - Gamma amplitude modulated by theta phase (PAC)
//   - High PAC, low bicoherence
//   - pac_gain = 1.0, harmonic_gain = 0.125
//
// HARMONIC MODE (ignition):
//   - Gamma phase-locked to theta at integer ratio
//   - Low PAC, high bicoherence
//   - pac_gain = 0.125, harmonic_gain = 1.0
//
// TRANSITION MODE:
//   - Gradual crossfade between modes
//   - Prevents discontinuities
//   - Duration: ~500ms (configurable)
//
// State Transitions:
//   MODULATORY → TRANSITION: kuramoto_R > 0.7 AND boundary_power > threshold
//   TRANSITION → HARMONIC: after transition duration
//   HARMONIC → MODULATORY: kuramoto_R < 0.5 OR sie_decay_phase
//
// v1.0: Initial implementation with three-state machine
//=============================================================================
`timescale 1ns / 1ps

module coupling_mode_controller #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter TRANSITION_CYCLES = 2000  // ~500ms at 4 kHz
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Synchronization metrics
    input  wire signed [WIDTH-1:0] kuramoto_R,       // Order parameter [0, 1.0]
    input  wire signed [WIDTH-1:0] boundary_power,   // Total boundary strength

    // SIE phase input (from sr_ignition_controller)
    input  wire [2:0] sie_phase,                     // 0-5: baseline to refractory

    // Thresholds (configurable)
    input  wire signed [WIDTH-1:0] r_high_thresh,    // Kuramoto R threshold to enter harmonic
    input  wire signed [WIDTH-1:0] r_low_thresh,     // Kuramoto R threshold to exit harmonic
    input  wire signed [WIDTH-1:0] boundary_thresh,  // Boundary power threshold

    // Outputs
    output reg [1:0] coupling_mode,                  // 00=modulatory, 01=transition, 10=harmonic
    output reg signed [WIDTH-1:0] pac_gain,          // Gain for PAC-based coupling
    output reg signed [WIDTH-1:0] harmonic_gain,     // Gain for harmonic coupling
    output reg mode_transition_active                // Flag during mode change
);

// Mode encodings
localparam [1:0] MODE_MODULATORY = 2'b00;
localparam [1:0] MODE_TRANSITION = 2'b01;
localparam [1:0] MODE_HARMONIC   = 2'b10;

// Gain constants (Q14)
localparam signed [WIDTH-1:0] GAIN_FULL = 18'sd16384;     // 1.0
localparam signed [WIDTH-1:0] GAIN_HALF = 18'sd8192;      // 0.5
localparam signed [WIDTH-1:0] GAIN_WEAK = 18'sd2048;      // 0.125

// Default thresholds (Q14)
localparam signed [WIDTH-1:0] DEFAULT_R_HIGH = 18'sd11469;    // 0.7
localparam signed [WIDTH-1:0] DEFAULT_R_LOW = 18'sd8192;      // 0.5
localparam signed [WIDTH-1:0] DEFAULT_BOUNDARY = 18'sd8192;   // 0.5

// SIE phases (from sr_ignition_controller.v)
localparam [2:0] SIE_BASELINE    = 3'd0;
localparam [2:0] SIE_COHERENCE   = 3'd1;
localparam [2:0] SIE_IGNITION    = 3'd2;
localparam [2:0] SIE_PLATEAU     = 3'd3;
localparam [2:0] SIE_PROPAGATION = 3'd4;
localparam [2:0] SIE_DECAY       = 3'd5;

// Internal state
reg [15:0] transition_counter;
reg [1:0] mode_state;
reg [1:0] target_mode;

// Effective thresholds (use default if input is zero)
wire signed [WIDTH-1:0] eff_r_high = (r_high_thresh == 0) ? DEFAULT_R_HIGH : r_high_thresh;
wire signed [WIDTH-1:0] eff_r_low = (r_low_thresh == 0) ? DEFAULT_R_LOW : r_low_thresh;
wire signed [WIDTH-1:0] eff_boundary = (boundary_thresh == 0) ? DEFAULT_BOUNDARY : boundary_thresh;

// Transition detection
wire enter_harmonic_condition = (kuramoto_R > eff_r_high) && (boundary_power > eff_boundary);
wire exit_harmonic_condition = (kuramoto_R < eff_r_low) || (sie_phase == SIE_DECAY);

// SIE active phases (ignition through propagation)
wire sie_active = (sie_phase >= SIE_IGNITION) && (sie_phase <= SIE_PROPAGATION);

//-----------------------------------------------------------------------------
// Mode State Machine
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mode_state <= MODE_MODULATORY;
        target_mode <= MODE_MODULATORY;
        transition_counter <= 16'd0;
        coupling_mode <= MODE_MODULATORY;
        pac_gain <= GAIN_FULL;
        harmonic_gain <= GAIN_WEAK;
        mode_transition_active <= 1'b0;
    end else if (clk_en) begin
        case (mode_state)

            MODE_MODULATORY: begin
                // Check for transition to harmonic mode
                if (enter_harmonic_condition || sie_active) begin
                    mode_state <= MODE_TRANSITION;
                    target_mode <= MODE_HARMONIC;
                    transition_counter <= 16'd0;
                    mode_transition_active <= 1'b1;
                end else begin
                    // Stay in modulatory mode
                    coupling_mode <= MODE_MODULATORY;
                    pac_gain <= GAIN_FULL;
                    harmonic_gain <= GAIN_WEAK;
                    mode_transition_active <= 1'b0;
                end
            end

            MODE_TRANSITION: begin
                // Gradual transition between modes
                transition_counter <= transition_counter + 1'b1;

                // Linear crossfade based on transition progress
                // progress = counter / TRANSITION_CYCLES
                // For simplicity, use HALF gains during transition
                coupling_mode <= MODE_TRANSITION;
                pac_gain <= GAIN_HALF;
                harmonic_gain <= GAIN_HALF;

                if (transition_counter >= TRANSITION_CYCLES) begin
                    // Transition complete
                    mode_state <= target_mode;
                    transition_counter <= 16'd0;
                    mode_transition_active <= 1'b0;
                end

                // Check for early exit conditions (only if SIE not active)
                // If SIE is active, continue transition regardless of kuramoto_R
                if (target_mode == MODE_HARMONIC && exit_harmonic_condition && !sie_active) begin
                    // Abort transition to harmonic, go back to modulatory
                    target_mode <= MODE_MODULATORY;
                    // Keep transitioning but now toward modulatory
                end
            end

            MODE_HARMONIC: begin
                // Check for exit condition
                if (exit_harmonic_condition && !sie_active) begin
                    mode_state <= MODE_TRANSITION;
                    target_mode <= MODE_MODULATORY;
                    transition_counter <= 16'd0;
                    mode_transition_active <= 1'b1;
                end else begin
                    // Stay in harmonic mode
                    coupling_mode <= MODE_HARMONIC;
                    pac_gain <= GAIN_WEAK;
                    harmonic_gain <= GAIN_FULL;
                    mode_transition_active <= 1'b0;
                end
            end

            default: begin
                mode_state <= MODE_MODULATORY;
            end

        endcase
    end
end

endmodule
