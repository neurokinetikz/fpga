//=============================================================================
// Coupling Mode Controller - v1.2b
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
//   MODULATORY → TRANSITION: state_driven OR (kuramoto_R > 0.55 AND boundary_power > 0.30)
//   TRANSITION → HARMONIC: after transition duration
//   HARMONIC → MODULATORY: kuramoto_R < 0.35 OR boundary_power < 0.15 (unless state_driven)
//
// v1.2b CHANGES (Synchronized Gain Interpolation):
// - pac_gain and harmonic_gain interpolate with state transition progress
// - Eliminates transient artifacts (alpha dip at N→M, spike at M→N)
// - Gains track MU changes: PAC support maintained until amplitude compensates
// - New inputs: transitioning, state_transition_from, state_transition_to
//
// v1.2 CHANGES (State-Gated Debounce):
// - State-gated MEDITATION forcing: HARMONIC only after 25% transition progress
// - Temporal debounce filter: DEBOUNCE_CYCLES parameter (default 2000 = 500ms)
// - Wider hysteresis: R entry 0.55, R exit 0.35 (20% window)
// - Separate boundary entry 0.30, boundary exit 0.15 (15% window)
// - New inputs: transition_progress, transition_duration from config_controller
// - Prevents mode chattering during state transitions
//
// v1.1 CHANGES (State-Driven Mode):
// - Added state_select input for consciousness state
// - MEDITATION state (4) directly forces HARMONIC mode
// - Lowered thresholds: R 0.7→0.5, boundary 0.5→0.25
// - Prevents horizontal bands by varying mix with state
//
// v1.0: Initial implementation with three-state machine
//=============================================================================
`timescale 1ns / 1ps

module coupling_mode_controller #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter TRANSITION_CYCLES = 2000,  // ~500ms at 4 kHz
    parameter DEBOUNCE_CYCLES = 2000     // v1.2: Debounce duration (default 500ms at 4kHz)
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // v1.1: Consciousness state for state-driven mode
    input  wire [2:0] state_select,                  // Consciousness state (0-4)

    // v1.2: State transition progress from config_controller
    input  wire [15:0] transition_progress,          // 0-65535 ramp position
    input  wire [15:0] transition_duration,          // Total transition duration (cycles)

    // v1.2b: State transition tracking for gain interpolation
    input  wire transitioning,                       // High during state transition
    input  wire [2:0] state_transition_from,         // Source state
    input  wire [2:0] state_transition_to,           // Target state

    // Synchronization metrics
    input  wire signed [WIDTH-1:0] kuramoto_R,       // Order parameter [0, 1.0]
    input  wire signed [WIDTH-1:0] boundary_power,   // Total boundary strength

    // SIE phase input (from sr_ignition_controller)
    input  wire [2:0] sie_phase,                     // 0-5: baseline to refractory

    // Thresholds (configurable, use 0 for defaults)
    input  wire signed [WIDTH-1:0] r_high_thresh,    // Kuramoto R threshold to enter harmonic
    input  wire signed [WIDTH-1:0] r_low_thresh,     // Kuramoto R threshold to exit harmonic
    input  wire signed [WIDTH-1:0] boundary_thresh,  // Boundary power entry threshold

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

// v1.2b: Ramp step for non-meditation transitions (~500ms at 4kHz = 2000 cycles)
// GAIN_FULL - GAIN_WEAK = 14336, divided by 2000 = ~7 per cycle
localparam signed [WIDTH-1:0] GAIN_RAMP_STEP = 18'sd7;

// Default thresholds (Q14) - v1.2: Wider hysteresis band (20% R, 15% boundary)
localparam signed [WIDTH-1:0] DEFAULT_R_HIGH = 18'sd9011;          // 0.55 (was 0.5)
localparam signed [WIDTH-1:0] DEFAULT_R_LOW = 18'sd5734;           // 0.35 (was 0.4)
localparam signed [WIDTH-1:0] DEFAULT_BOUNDARY_ENTRY = 18'sd4915;  // 0.30 (was 0.25)
localparam signed [WIDTH-1:0] DEFAULT_BOUNDARY_EXIT = 18'sd2458;   // 0.15 (new)

// v1.2: State-gated transition threshold (25% = 16384 in Q16 space)
localparam [15:0] TRANSITION_GATE_25PCT = 16'd16384;

// v1.1: Consciousness state codes
localparam [2:0] STATE_MEDITATION = 3'd4;

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

// v1.2: Debounce counters
reg [15:0] entry_hold_counter;      // Counts cycles entry condition held
reg [15:0] exit_hold_counter;       // Counts cycles exit condition held

// v1.2b: Gain interpolation registers
reg signed [WIDTH-1:0] pac_gain_start;       // PAC gain at transition start
reg signed [WIDTH-1:0] harmonic_gain_start;  // Harmonic gain at transition start
reg signed [WIDTH-1:0] pac_gain_target;      // PAC gain target
reg signed [WIDTH-1:0] harmonic_gain_target; // Harmonic gain target
reg transitioning_prev;                       // Edge detection for transition start

// v1.2b: Meditation transition detection
wire entering_meditation = (state_transition_to == STATE_MEDITATION);
wire exiting_meditation = (state_transition_from == STATE_MEDITATION);
wire meditation_transition = transitioning && (entering_meditation || exiting_meditation);

// Effective thresholds (use default if input is zero)
wire signed [WIDTH-1:0] eff_r_high = (r_high_thresh == 0) ? DEFAULT_R_HIGH : r_high_thresh;
wire signed [WIDTH-1:0] eff_r_low = (r_low_thresh == 0) ? DEFAULT_R_LOW : r_low_thresh;
wire signed [WIDTH-1:0] eff_boundary_entry = (boundary_thresh == 0) ? DEFAULT_BOUNDARY_ENTRY : boundary_thresh;
wire signed [WIDTH-1:0] eff_boundary_exit = DEFAULT_BOUNDARY_EXIT;  // Always use default for exit

// v1.2: State-driven mode forcing WITH transition gating
// Only force HARMONIC after transition progress reaches 25%
// This prevents instant mode flip during early transition, allowing oscillators to ramp up
wire transition_gate_passed = (transition_progress >= TRANSITION_GATE_25PCT) ||
                               (transition_duration == 0);  // Instant if no transition active

wire state_driven_harmonic = (state_select == STATE_MEDITATION) && transition_gate_passed;

// v1.2: Raw (undebounced) entry/exit conditions
wire raw_enter_harmonic = (kuramoto_R > eff_r_high) && (boundary_power > eff_boundary_entry);

// v1.2: Exit condition includes separate boundary exit threshold
wire raw_exit_harmonic = (kuramoto_R < eff_r_low) ||
                         (boundary_power < eff_boundary_exit) ||
                         (sie_phase == SIE_DECAY);

// v1.2: Debounced conditions (counter-based temporal filtering)
wire debounced_enter_harmonic = (entry_hold_counter >= DEBOUNCE_CYCLES);
wire debounced_exit_harmonic = (exit_hold_counter >= DEBOUNCE_CYCLES);

// Final conditions combine debounce with state-driven forcing
// State-driven bypasses metric-based debounce (instant forcing once gate passed)
wire enter_harmonic_condition = state_driven_harmonic ||
                                 (raw_enter_harmonic && debounced_enter_harmonic);

// Exit condition: don't exit if state_driven, and require debounced exit
wire exit_harmonic_condition = !state_driven_harmonic &&
                               (raw_exit_harmonic && debounced_exit_harmonic);

// SIE active phases (ignition through propagation)
wire sie_active = (sie_phase >= SIE_IGNITION) && (sie_phase <= SIE_PROPAGATION);

//-----------------------------------------------------------------------------
// v1.2: Debounce Counter Logic
// Entry/exit conditions must hold for DEBOUNCE_CYCLES before triggering
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        entry_hold_counter <= 16'd0;
        exit_hold_counter <= 16'd0;
    end else if (clk_en) begin
        // Entry debounce: increment while raw condition true, reset on false
        // Don't count if already state-driven (bypasses debounce)
        if (raw_enter_harmonic && !state_driven_harmonic) begin
            if (entry_hold_counter < DEBOUNCE_CYCLES)
                entry_hold_counter <= entry_hold_counter + 1'b1;
            // else: saturate at DEBOUNCE_CYCLES (condition met)
        end else begin
            entry_hold_counter <= 16'd0;  // Reset if condition drops
        end

        // Exit debounce: increment while raw condition true, reset on false
        if (raw_exit_harmonic && !state_driven_harmonic) begin
            if (exit_hold_counter < DEBOUNCE_CYCLES)
                exit_hold_counter <= exit_hold_counter + 1'b1;
        end else begin
            exit_hold_counter <= 16'd0;
        end
    end
end

//-----------------------------------------------------------------------------
// v1.2b: Gain Interpolation Logic
// During meditation state transitions, gains interpolate with transition_progress
// Outside meditation, gains use slow 500ms ramp for metric-driven changes
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pac_gain_start <= GAIN_FULL;
        harmonic_gain_start <= GAIN_WEAK;
        pac_gain_target <= GAIN_FULL;
        harmonic_gain_target <= GAIN_WEAK;
        transitioning_prev <= 1'b0;
    end else if (clk_en) begin
        transitioning_prev <= transitioning;

        // Detect transition start - capture current gain values
        if (transitioning && !transitioning_prev) begin
            pac_gain_start <= pac_gain;
            harmonic_gain_start <= harmonic_gain;
        end

        // Update target gains based on meditation transition OR state_select
        // v1.2b FIX: State-controlled gain targets prioritize consciousness state
        // over the metric-driven state machine (target_mode)
        if (meditation_transition) begin
            if (entering_meditation) begin
                // N→M: Target is HARMONIC mode (low PAC, high harmonic)
                pac_gain_target <= GAIN_WEAK;
                harmonic_gain_target <= GAIN_FULL;
            end else begin
                // M→N: Target is MODULATORY mode (high PAC, low harmonic)
                pac_gain_target <= GAIN_FULL;
                harmonic_gain_target <= GAIN_WEAK;
            end
        end else if (state_select == STATE_MEDITATION) begin
            // In MEDITATION state (not transitioning): HARMONIC targets
            pac_gain_target <= GAIN_WEAK;
            harmonic_gain_target <= GAIN_FULL;
        end else begin
            // Not in MEDITATION state: always MODULATORY targets
            // This ensures M→N transition completes to correct state
            // (Metric-driven target_mode only affects coupling_mode, not gains)
            pac_gain_target <= GAIN_FULL;
            harmonic_gain_target <= GAIN_WEAK;
        end
    end
end

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

        //---------------------------------------------------------------------
        // v1.2b: Gain Computation (before state machine)
        // Priority: meditation_transition > mode_transition > steady-state
        //---------------------------------------------------------------------
        if (meditation_transition) begin
            // During MEDITATION state transitions: interpolate with MU
            // Linear interpolation: gain = start + (target - start) * progress / duration
            if (transition_duration != 16'd0) begin
                // Compute interpolated pac_gain
                // v1.2b FIX: Use 32-bit arithmetic to prevent overflow
                // delta * progress can be up to 14336 * 65535 = ~940M (30 bits)
                if (pac_gain_target >= pac_gain_start) begin
                    pac_gain <= pac_gain_start +
                        ((({14'd0, pac_gain_target - pac_gain_start}) * {16'd0, transition_progress}) / {16'd0, transition_duration});
                end else begin
                    pac_gain <= pac_gain_start -
                        ((({14'd0, pac_gain_start - pac_gain_target}) * {16'd0, transition_progress}) / {16'd0, transition_duration});
                end

                // Compute interpolated harmonic_gain
                if (harmonic_gain_target >= harmonic_gain_start) begin
                    harmonic_gain <= harmonic_gain_start +
                        ((({14'd0, harmonic_gain_target - harmonic_gain_start}) * {16'd0, transition_progress}) / {16'd0, transition_duration});
                end else begin
                    harmonic_gain <= harmonic_gain_start -
                        ((({14'd0, harmonic_gain_start - harmonic_gain_target}) * {16'd0, transition_progress}) / {16'd0, transition_duration});
                end
            end else begin
                // Instant transition if duration is 0
                pac_gain <= pac_gain_target;
                harmonic_gain <= harmonic_gain_target;
            end
        end else if (mode_state == MODE_TRANSITION) begin
            // During internal mode transition: use HALF gains (existing behavior)
            pac_gain <= GAIN_HALF;
            harmonic_gain <= GAIN_HALF;
        end else begin
            // Steady state: slow ramp toward target for metric-driven changes
            // This provides smooth transitions outside meditation
            if (pac_gain < pac_gain_target) begin
                pac_gain <= (pac_gain + GAIN_RAMP_STEP > pac_gain_target) ?
                            pac_gain_target : pac_gain + GAIN_RAMP_STEP;
            end else if (pac_gain > pac_gain_target) begin
                pac_gain <= (pac_gain < pac_gain_target + GAIN_RAMP_STEP) ?
                            pac_gain_target : pac_gain - GAIN_RAMP_STEP;
            end

            if (harmonic_gain < harmonic_gain_target) begin
                harmonic_gain <= (harmonic_gain + GAIN_RAMP_STEP > harmonic_gain_target) ?
                                 harmonic_gain_target : harmonic_gain + GAIN_RAMP_STEP;
            end else if (harmonic_gain > harmonic_gain_target) begin
                harmonic_gain <= (harmonic_gain < harmonic_gain_target + GAIN_RAMP_STEP) ?
                                 harmonic_gain_target : harmonic_gain - GAIN_RAMP_STEP;
            end
        end

        //---------------------------------------------------------------------
        // Mode State Machine
        //---------------------------------------------------------------------
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
                    mode_transition_active <= 1'b0;
                end
            end

            MODE_TRANSITION: begin
                // Gradual transition between modes
                transition_counter <= transition_counter + 1'b1;
                coupling_mode <= MODE_TRANSITION;

                if (transition_counter >= TRANSITION_CYCLES) begin
                    // Transition complete
                    mode_state <= target_mode;
                    transition_counter <= 16'd0;
                    mode_transition_active <= 1'b0;
                end

                // Check for early exit conditions (only if SIE not active)
                if (target_mode == MODE_HARMONIC && exit_harmonic_condition && !sie_active) begin
                    // Abort transition to harmonic, go back to modulatory
                    target_mode <= MODE_MODULATORY;
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
