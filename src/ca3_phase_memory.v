//=============================================================================
// CA3 Phase Memory - v8.0 with Theta Phase Multiplexing
//
// v8.0 CHANGES (Dupret et al. 2025 Integration):
// - Theta phase multiplexing: uses 8 discrete phases per theta cycle
// - Early encoding (phases 0-1): strongest learning, sensory-dominated
// - Late encoding (phases 2-3): consolidation, CA3 recurrence begins
// - Early retrieval (phases 4-5): pattern completion, CA3-dominated
// - Late retrieval (phases 6-7): output phase, decay/pruning
// - Phase window outputs: encoding_window, retrieval_window for downstream gating
// - Maintains backwards compatibility with theta_x threshold-based gating
//
// Implements Hebbian learning with PHASE ENCODING output.
// Each stored pattern bit indicates phase relationship to theta:
//   1 = in-phase with theta (phase offset = 0)
//   0 = anti-phase with theta (phase offset = π)
//
// THETA-GATED OPERATION (biologically accurate):
//   - Learn during theta PEAK (encoding window, phases 0-3)
//   - Recall during theta TROUGH (retrieval window, phases 4-7)
//   - DECAY during theta TROUGH when no pattern active (v5.3)
//
// MEMORY DECAY (v5.3):
//   - Implements synaptic homeostasis / forgetting
//   - Weights decay by DECAY_RATE every DECAY_INTERVAL theta cycles
//   - Only occurs when pattern_in = 0 (no active input)
//   - Creates competitive learning: reinforced patterns persist
//
// INTERFACE:
//   - Input: 6-bit pattern (maps to 6 cortical oscillators)
//   - Input: 3-bit theta_phase (8 phases per cycle from thalamus, v8.0)
//   - Output: 6-bit phase_pattern for coupling signals
//   - Output: encoding_window, retrieval_window (v8.0 phase-based windows)
//   - Theta phase determines learn vs recall vs decay mode automatically
//
// TIMING ANALYSIS:
//   - LEARN: 36 iterations at 1 kHz = 36 ms (< theta peak ~45 ms) ✓
//   - RECALL: 6 iterations at 1 kHz = 6 ms (< theta trough ~45 ms) ✓
//   - DECAY: 36 iterations at 1 kHz = 36 ms (< theta trough ~45 ms) ✓
//=============================================================================
`timescale 1ns / 1ps

module ca3_phase_memory #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter N_UNITS = 6           // 6 oscillators: 3 columns × (L2/3 + L6)
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Theta phase reference (from thalamus)
    input  wire signed [WIDTH-1:0] theta_x,

    // v8.0: Fine-grained theta phase (8 phases per cycle)
    input  wire [2:0] theta_phase,

    // Pattern input (from external or cortical activity)
    input  wire [N_UNITS-1:0] pattern_in,

    // Phase pattern output (for cortical phase coupling)
    output reg  [N_UNITS-1:0] phase_pattern,

    // Status outputs
    output reg  learning,           // High during learn phase
    output reg  recalling,          // High during recall phase
    output wire [3:0] debug_state,

    // v8.0: Phase-based window outputs for downstream gating
    output wire encoding_window,    // High during phases 0-3 (encoding)
    output wire retrieval_window,   // High during phases 4-7 (retrieval)
    output wire [1:0] phase_subwindow  // 0=early_enc, 1=late_enc, 2=early_ret, 3=late_ret
);

//-----------------------------------------------------------------------------
// Theta Phase Thresholds
// Learn at theta peak, recall/decay at theta trough
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] THETA_LEARN_THRESHOLD  = 18'sd12288;   // +0.75
localparam signed [WIDTH-1:0] THETA_RECALL_THRESHOLD = -18'sd12288;  // -0.75
localparam signed [WIDTH-1:0] THETA_HYSTERESIS       = 18'sd4096;    // 0.25

//-----------------------------------------------------------------------------
// States
//-----------------------------------------------------------------------------
localparam [2:0] IDLE        = 3'd0;
localparam [2:0] LEARN       = 3'd1;
localparam [2:0] LEARN_DONE  = 3'd2;
localparam [2:0] RECALL      = 3'd3;
localparam [2:0] RECALL_DONE = 3'd4;
localparam [2:0] DECAY       = 3'd5;  // v5.3: Memory decay state
localparam [2:0] DECAY_DONE  = 3'd6;

reg [2:0] state;

//-----------------------------------------------------------------------------
// Decay Parameters (v5.3)
//
// BIOLOGICAL BASIS:
// - Synaptic homeostasis: weights drift toward baseline without reinforcement
// - Sleep-dependent consolidation: pruning occurs during specific phases
// - Hebbian competition: frequently-used patterns outcompete unused ones
//
// IMPLEMENTATION:
// - Decay occurs during theta trough (same phase as recall)
// - Small decrement prevents catastrophic forgetting
// - Only positive weights decay (no negative weights in Hopfield model)
// - Edge detection prevents over-counting theta cycles
//-----------------------------------------------------------------------------
localparam signed [7:0] DECAY_RATE = 8'sd1;       // Slow decay (1 per event)
localparam [7:0] DECAY_INTERVAL = 8'd10;          // Decay every N theta cycles
reg [7:0] theta_cycle_count;                       // Counter for decay timing
reg decay_triggered;                               // One decay per interval
reg was_above_threshold;                           // Edge detection for cycle counting

//-----------------------------------------------------------------------------
// Weight Matrix (N_UNITS x N_UNITS)
// Symmetric matrix, diagonal = 0
//-----------------------------------------------------------------------------
reg signed [7:0] weights [0:N_UNITS-1][0:N_UNITS-1];

//-----------------------------------------------------------------------------
// Accumulators for recall
//-----------------------------------------------------------------------------
reg signed [15:0] accum [0:N_UNITS-1];

//-----------------------------------------------------------------------------
// Learning Parameters
//-----------------------------------------------------------------------------
localparam signed [7:0] LEARN_RATE = 8'sd2;           // Increment per co-activation
localparam signed [7:0] WEIGHT_MAX = 8'sd100;         // Saturation limit
localparam signed [15:0] RECALL_THRESHOLD = 16'sd10;  // Activation threshold

//-----------------------------------------------------------------------------
// Counters for iterating through matrix
//-----------------------------------------------------------------------------
reg [2:0] row_idx;
reg [2:0] col_idx;

//-----------------------------------------------------------------------------
// Main State Machine
//-----------------------------------------------------------------------------
integer i, j;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        learning <= 1'b0;
        recalling <= 1'b0;
        phase_pattern <= {N_UNITS{1'b0}};
        row_idx <= 0;
        col_idx <= 0;
        theta_cycle_count <= 8'd0;
        decay_triggered <= 1'b0;
        was_above_threshold <= 1'b1;  // Start as if we just came from above

        // Initialize weights to zero
        for (i = 0; i < N_UNITS; i = i + 1) begin
            for (j = 0; j < N_UNITS; j = j + 1) begin
                weights[i][j] <= 8'sd0;
            end
            accum[i] <= 16'sd0;
        end

    end else if (clk_en) begin
        case (state)
            //------------------------------------------------------------------
            // IDLE: Monitor theta phase to determine operation mode
            // v5.3: Also triggers periodic decay ONLY when no pattern active
            //------------------------------------------------------------------
            IDLE: begin
                learning <= 1'b0;
                recalling <= 1'b0;

                // Theta peak → LEARN (only if pattern is non-zero)
                if (theta_x > THETA_LEARN_THRESHOLD) begin
                    was_above_threshold <= 1'b1;  // Track that we were high

                    if (pattern_in != 0) begin
                        learning <= 1'b1;
                        row_idx <= 0;
                        col_idx <= 0;
                        state <= LEARN;
                    end
                    decay_triggered <= 1'b0;  // Reset decay flag
                end
                // Theta trough → RECALL or DECAY
                else if (theta_x < THETA_RECALL_THRESHOLD) begin
                    // Only count cycles and decay when NO pattern is presented
                    if (pattern_in == 0) begin
                        // Count once per transition from high to low (edge detect)
                        if (was_above_threshold) begin
                            theta_cycle_count <= theta_cycle_count + 1'b1;
                            was_above_threshold <= 1'b0;
                        end

                        // Trigger decay after interval
                        if (theta_cycle_count >= DECAY_INTERVAL && !decay_triggered) begin
                            row_idx <= 0;
                            col_idx <= 0;
                            decay_triggered <= 1'b1;
                            state <= DECAY;
                        end
                        // Otherwise just stay in IDLE during trough (nothing to recall)
                    end else begin
                        was_above_threshold <= 1'b0;  // Still track transitions
                        // Pattern is active - do normal recall
                        recalling <= 1'b1;
                        for (i = 0; i < N_UNITS; i = i + 1) begin
                            accum[i] <= 16'sd0;
                        end
                        col_idx <= 0;
                        state <= RECALL;
                    end
                end
            end

            //------------------------------------------------------------------
            // LEARN: Hebbian update - strengthen co-active connections
            // w_ij += learn_rate if both units active
            // v5.2 FIX: Update BOTH w_ij and w_ji for symmetric weights
            //------------------------------------------------------------------
            LEARN: begin
                // Update weight if both units are active and not self-connection
                if (pattern_in[row_idx] && pattern_in[col_idx] && row_idx != col_idx) begin
                    // Update w[row][col]
                    if (weights[row_idx][col_idx] < WEIGHT_MAX - LEARN_RATE) begin
                        weights[row_idx][col_idx] <= weights[row_idx][col_idx] + LEARN_RATE;
                    end else begin
                        weights[row_idx][col_idx] <= WEIGHT_MAX;
                    end
                    // v5.2 FIX: Also update w[col][row] for symmetry
                    if (weights[col_idx][row_idx] < WEIGHT_MAX - LEARN_RATE) begin
                        weights[col_idx][row_idx] <= weights[col_idx][row_idx] + LEARN_RATE;
                    end else begin
                        weights[col_idx][row_idx] <= WEIGHT_MAX;
                    end
                end

                // Iterate through matrix
                if (col_idx == N_UNITS - 1) begin
                    col_idx <= 0;
                    if (row_idx == N_UNITS - 1) begin
                        state <= LEARN_DONE;
                    end else begin
                        row_idx <= row_idx + 1;
                    end
                end else begin
                    col_idx <= col_idx + 1;
                end
            end

            //------------------------------------------------------------------
            // LEARN_DONE: Wait for theta to drop before returning to IDLE
            //------------------------------------------------------------------
            LEARN_DONE: begin
                if (theta_x < THETA_LEARN_THRESHOLD - THETA_HYSTERESIS) begin
                    learning <= 1'b0;
                    state <= IDLE;
                end
            end

            //------------------------------------------------------------------
            // RECALL: Compute activations from partial input
            // a_i = sum_j(w_ij * input_j)
            //------------------------------------------------------------------
            RECALL: begin
                // Accumulate weighted inputs
                for (i = 0; i < N_UNITS; i = i + 1) begin
                    if (pattern_in[col_idx]) begin
                        accum[i] <= accum[i] + {{8{weights[i][col_idx][7]}}, weights[i][col_idx]};
                    end
                end

                if (col_idx == N_UNITS - 1) begin
                    state <= RECALL_DONE;
                end else begin
                    col_idx <= col_idx + 1;
                end
            end

            //------------------------------------------------------------------
            // RECALL_DONE: Threshold activations to produce phase pattern
            // High activation → in-phase (1), low → anti-phase (0)
            //------------------------------------------------------------------
            RECALL_DONE: begin
                for (i = 0; i < N_UNITS; i = i + 1) begin
                    phase_pattern[i] <= (accum[i] > RECALL_THRESHOLD) ? 1'b1 : 1'b0;
                end

                // Wait for theta to rise before returning to IDLE
                if (theta_x > THETA_RECALL_THRESHOLD + THETA_HYSTERESIS) begin
                    recalling <= 1'b0;
                    state <= IDLE;
                end
            end

            //------------------------------------------------------------------
            // DECAY: Reduce all positive weights by decay rate (v5.3)
            //
            // BIOLOGICAL RATIONALE:
            // - Implements synaptic homeostasis / forgetting
            // - Weights that aren't reinforced gradually decay to zero
            // - Creates competition: frequently-used patterns persist
            // - Prevents weight saturation over time
            //------------------------------------------------------------------
            DECAY: begin
                // Decay weight if positive
                if (weights[row_idx][col_idx] > DECAY_RATE) begin
                    weights[row_idx][col_idx] <= weights[row_idx][col_idx] - DECAY_RATE;
                end else if (weights[row_idx][col_idx] > 0) begin
                    weights[row_idx][col_idx] <= 8'sd0;  // Clamp to zero
                end
                // Note: Symmetric matrix maintained because both [i][j] and [j][i] decay equally

                // Iterate through all weights
                if (col_idx == N_UNITS - 1) begin
                    col_idx <= 0;
                    if (row_idx == N_UNITS - 1) begin
                        state <= DECAY_DONE;
                    end else begin
                        row_idx <= row_idx + 1;
                    end
                end else begin
                    col_idx <= col_idx + 1;
                end
            end

            //------------------------------------------------------------------
            // DECAY_DONE: Wait for theta to rise before returning to IDLE
            //------------------------------------------------------------------
            DECAY_DONE: begin
                if (theta_x > THETA_RECALL_THRESHOLD + THETA_HYSTERESIS) begin
                    decay_triggered <= 1'b0;  // Allow next decay cycle
                    theta_cycle_count <= 8'd0;  // Reset counter
                    state <= IDLE;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

//-----------------------------------------------------------------------------
// v8.0: Theta Phase Window Computation
//
// BIOLOGICAL BASIS (Dupret et al. 2025):
// "With an across-timescales multiplexing, a single population performs
// multiple computations at the same time, but with some computations
// performed over faster-timescale activity and other computations
// performed over slower-timescale activity."
//
// Phase windows enable downstream circuits to gate based on theta phase:
//   - encoding_window (phases 0-3): sensory inputs should dominate
//   - retrieval_window (phases 4-7): CA3 recurrence should dominate
//   - phase_subwindow: finer 4-way distinction for gamma nesting
//     0 = early_encoding (phases 0-1): fast gamma, sensory
//     1 = late_encoding (phases 2-3): slow gamma, consolidation
//     2 = early_retrieval (phases 4-5): pattern completion
//     3 = late_retrieval (phases 6-7): output/decay
//-----------------------------------------------------------------------------

// Encoding window: phases 0-3 (theta_x > 0 region, peak vicinity)
assign encoding_window = ~theta_phase[2];  // Bit 2 = 0 means phases 0-3

// Retrieval window: phases 4-7 (theta_x < 0 region, trough vicinity)
assign retrieval_window = theta_phase[2];   // Bit 2 = 1 means phases 4-7

// Subwindow computation: {theta_phase[2], theta_phase[1]}
// This gives 4 windows: 00=early_enc, 01=late_enc, 10=early_ret, 11=late_ret
assign phase_subwindow = theta_phase[2:1];

assign debug_state = {state, learning};

endmodule
