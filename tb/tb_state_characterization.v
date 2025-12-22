//=============================================================================
// Consciousness State Characterization Testbench - v6.2 (Sensory-Only)
// Tests all 5 states using phi_n_neural_processor (v6.2)
//
// v6.2 CHANGES (this version):
// - Removed ca3_pattern_in - sensory_input is the ONLY external data input
// - All pattern injection via sensory_input → thalamic relay → cortex → CA3
// - True biologically-realistic closed-loop architecture
//
// v6.1 CHANGES:
// - Uses phi_n_neural_processor instead of standalone oscillators
// - True closed-loop: cortex → CA3 → phase_pattern → cortex
// - Accesses internal signals via hierarchical references
//
// Measures: Learning dynamics, Entropy metrics, Oscillator coherence
//=============================================================================
`timescale 1ns / 1ps

module tb_state_characterization;

parameter WIDTH = 18;
parameter FRAC = 14;

//-----------------------------------------------------------------------------
// Clock, Reset, and Control
//-----------------------------------------------------------------------------
reg clk, rst;

reg signed [WIDTH-1:0] sensory_input;  // v6.2: ONLY external data input
reg [2:0] state_select;

//-----------------------------------------------------------------------------
// State Definitions (from config_controller.v)
//-----------------------------------------------------------------------------
localparam [2:0] STATE_NORMAL     = 3'd0;
localparam [2:0] STATE_ANESTHESIA = 3'd1;
localparam [2:0] STATE_PSYCHEDELIC = 3'd2;
localparam [2:0] STATE_FLOW       = 3'd3;
localparam [2:0] STATE_MEDITATION = 3'd4;

//-----------------------------------------------------------------------------
// Test Patterns
//-----------------------------------------------------------------------------
localparam [5:0] PAT_A = 6'b101010;  // Pattern A
localparam [5:0] PAT_B = 6'b010101;  // Pattern B
localparam [5:0] PAT_C = 6'b110011;  // Pattern C

localparam [5:0] CUE_A = 6'b100000;  // Partial cue for A
localparam [5:0] CUE_B = 6'b000001;  // Partial cue for B
localparam [5:0] CUE_C = 6'b110000;  // Partial cue for C

//-----------------------------------------------------------------------------
// Theta Thresholds (matching ca3_phase_memory.v)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] THETA_PEAK_THRESH  = 18'sd12288;   // +0.75
localparam signed [WIDTH-1:0] THETA_TROUGH_THRESH = -18'sd12288; // -0.75

//-----------------------------------------------------------------------------
// DUT Outputs
//-----------------------------------------------------------------------------
wire [11:0] dac_output;
wire signed [WIDTH-1:0] debug_motor_l23;
wire signed [WIDTH-1:0] debug_theta;
wire ca3_learning;
wire ca3_recalling;
wire [5:0] ca3_phase_pattern;
wire [5:0] cortical_pattern;

//-----------------------------------------------------------------------------
// Fast Clock Enable Generator (for faster simulation)
//-----------------------------------------------------------------------------
reg [3:0] clk_div_count;
wire clk_en;
localparam [3:0] CLK_DIV_MAX = 4'd9;  // Every 10 clocks

always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_div_count <= 4'd0;
    end else begin
        if (clk_div_count == CLK_DIV_MAX) begin
            clk_div_count <= 4'd0;
        end else begin
            clk_div_count <= clk_div_count + 1'b1;
        end
    end
end

assign clk_en = (clk_div_count == CLK_DIV_MAX);

//-----------------------------------------------------------------------------
// Instantiate phi_n_neural_processor (v6.2 sensory-only closed-loop)
//-----------------------------------------------------------------------------
phi_n_neural_processor #(.WIDTH(WIDTH), .FRAC(FRAC)) dut (
    .clk(clk),
    .rst(rst),
    .sensory_input(sensory_input),  // v6.2: ONLY external data input
    .state_select(state_select),
    .dac_output(dac_output),
    .debug_motor_l23(debug_motor_l23),
    .debug_theta(debug_theta),
    .ca3_learning(ca3_learning),
    .ca3_recalling(ca3_recalling),
    .ca3_phase_pattern(ca3_phase_pattern),
    .cortical_pattern_out(cortical_pattern)
);

//-----------------------------------------------------------------------------
// Hierarchical References to Internal Signals
// These access the actual closed-loop signals inside phi_n_neural_processor
//-----------------------------------------------------------------------------

// Theta oscillator (from thalamus)
wire signed [WIDTH-1:0] theta_x = dut.thalamic_theta_x;
wire signed [WIDTH-1:0] theta_y = dut.thalamic_theta_y;
wire signed [WIDTH-1:0] theta_amp = dut.thalamic_theta_amp;

// Sensory column L2/3 (gamma)
wire signed [WIDTH-1:0] sens_gamma_x = dut.sensory_l23_x;
wire signed [WIDTH-1:0] sens_gamma_y = dut.sensory_l23_y;

// Sensory column L6 (alpha)
wire signed [WIDTH-1:0] sens_alpha_x = dut.sensory_l6_x;
wire signed [WIDTH-1:0] sens_alpha_y = dut.sensory_l6_y;

// Association column L2/3 (gamma)
wire signed [WIDTH-1:0] assoc_gamma_x = dut.assoc_l23_x;
wire signed [WIDTH-1:0] assoc_gamma_y = dut.assoc_l23_y;

// Association column L6 (alpha)
wire signed [WIDTH-1:0] assoc_alpha_x = dut.assoc_l6_x;
wire signed [WIDTH-1:0] assoc_alpha_y = dut.assoc_l6_y;

// Motor column L2/3 (gamma)
wire signed [WIDTH-1:0] motor_gamma_x = dut.motor_l23_x;
wire signed [WIDTH-1:0] motor_gamma_y = dut.motor_l23_y;

// Motor column L6 (alpha)
wire signed [WIDTH-1:0] motor_alpha_x = dut.motor_l6_x;
wire signed [WIDTH-1:0] motor_alpha_y = dut.motor_l6_y;

// Phase pattern from CA3
wire [5:0] phase_pattern = ca3_phase_pattern;

// Internal clock enable (match DUT timing)
wire clk_4khz_en = dut.clk_4khz_en;

// MU values from config controller (for reporting)
wire signed [WIDTH-1:0] mu_dt_theta = dut.mu_dt_theta;
wire signed [WIDTH-1:0] mu_dt_l23 = dut.mu_dt_l23;
wire signed [WIDTH-1:0] mu_dt_l6 = dut.mu_dt_l6;

//-----------------------------------------------------------------------------
// Oscillator-Derived Pattern (matches cortical_pattern in DUT)
// This is identical to what phi_n_neural_processor computes internally
//-----------------------------------------------------------------------------
wire [5:0] oscillator_derived_pattern = cortical_pattern;

//-----------------------------------------------------------------------------
// Amplitude Computation (for metrics)
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] sens_gamma_amp;
wire signed [WIDTH-1:0] motor_gamma_amp;
wire signed [WIDTH-1:0] assoc_gamma_amp;
wire signed [WIDTH-1:0] alpha_amp;

// Approximate amplitude as |x| + |y| (Manhattan norm, avoids sqrt)
assign sens_gamma_amp = (sens_gamma_x[WIDTH-1] ? -sens_gamma_x : sens_gamma_x) +
                        (sens_gamma_y[WIDTH-1] ? -sens_gamma_y : sens_gamma_y);
assign motor_gamma_amp = (motor_gamma_x[WIDTH-1] ? -motor_gamma_x : motor_gamma_x) +
                         (motor_gamma_y[WIDTH-1] ? -motor_gamma_y : motor_gamma_y);
assign assoc_gamma_amp = (assoc_gamma_x[WIDTH-1] ? -assoc_gamma_x : assoc_gamma_x) +
                         (assoc_gamma_y[WIDTH-1] ? -assoc_gamma_y : assoc_gamma_y);
assign alpha_amp = (sens_alpha_x[WIDTH-1] ? -sens_alpha_x : sens_alpha_x) +
                   (sens_alpha_y[WIDTH-1] ? -sens_alpha_y : sens_alpha_y);

// Use motor gamma as primary gamma signal (for PAC metrics)
wire signed [WIDTH-1:0] gamma_x = motor_gamma_x;
wire signed [WIDTH-1:0] gamma_y = motor_gamma_y;
wire signed [WIDTH-1:0] gamma_amp = motor_gamma_amp;

//-----------------------------------------------------------------------------
// Clock Generation: 10ns period (100 MHz)
//-----------------------------------------------------------------------------
initial begin clk = 0; forever #5 clk = ~clk; end

//-----------------------------------------------------------------------------
// Measurement Variables (declared at module level for Verilog compatibility)
//-----------------------------------------------------------------------------
integer i, j, k, s;
integer state_idx;

// Per-state metrics storage
integer theta_cycles      [0:4];
integer learn_events      [0:4];
integer recall_events     [0:4];
integer weight_change_sum [0:4];
integer recall_accuracy_a [0:4];
integer recall_accuracy_b [0:4];
integer recall_accuracy_c [0:4];
integer unique_patterns   [0:4];
integer pattern_transitions[0:4];
integer amp_variance      [0:4];

// Oscillator amplitude metrics per state
integer theta_amp_avg     [0:4];
integer gamma_amp_avg     [0:4];
integer alpha_amp_avg     [0:4];

// Oscillator-derived pattern metrics (from cortical_pattern)
integer osc_pattern_transitions [0:4];
integer osc_unique_patterns     [0:4];
integer effective_learn_rate    [0:4];

// Histogram for oscillator-derived pattern entropy
integer osc_pattern_hist [0:63];

// Histogram for phase pattern entropy (64 bins for 6-bit pattern)
integer phase_pattern_hist [0:63];

// Working variables
integer update_count;
integer matches;
reg [5:0] prev_phase_pattern;
reg prev_learning, prev_recalling;
reg prev_theta_high;

// Amplitude tracking
integer amp_sum, amp_count;
integer amp_sq_sum;
integer gamma_amp_sum, alpha_amp_sum;

// Weight tracking (access via hierarchical reference to CA3)
reg signed [7:0] prev_weights [0:5][0:5];
integer weight_delta;

// Log2 lookup table for entropy calculation (scaled by 256)
reg [15:0] log2_lut [1:255];

//-----------------------------------------------------------------------------
// Phase Timeseries Export Control
//-----------------------------------------------------------------------------
integer phase_export_file;
reg phase_export_enabled;

//-----------------------------------------------------------------------------
// Task: Initialize log2 lookup table
//-----------------------------------------------------------------------------
task init_log2_lut;
    integer n;
    begin
        for (n = 1; n < 256; n = n + 1) begin
            log2_lut[n] = (8 * 256) - (n < 2 ? 0 :
                          n < 4 ? 256 :
                          n < 8 ? 512 :
                          n < 16 ? 768 :
                          n < 32 ? 1024 :
                          n < 64 ? 1280 :
                          n < 128 ? 1536 : 1792);
        end
    end
endtask

//-----------------------------------------------------------------------------
// Task: Wait for n 4kHz updates (using DUT's internal clock enable)
//-----------------------------------------------------------------------------
task wait_updates;
    input integer n;
    integer u;
    begin
        for (u = 0; u < n; u = u + 1) begin
            @(posedge clk_4khz_en);
            update_count = update_count + 1;
        end
    end
endtask

//-----------------------------------------------------------------------------
// Task: Wait for theta peak
//-----------------------------------------------------------------------------
task wait_theta_peak;
    begin
        while (theta_x < THETA_PEAK_THRESH) wait_updates(1);
    end
endtask

//-----------------------------------------------------------------------------
// Task: Wait for theta trough
//-----------------------------------------------------------------------------
task wait_theta_trough;
    begin
        while (theta_x > THETA_TROUGH_THRESH) wait_updates(1);
    end
endtask

//-----------------------------------------------------------------------------
// Task: Train a pattern via sensory input (v6.2: sensory-only pathway)
// Applies sensory stimulus at theta peak to drive cortical activity
//-----------------------------------------------------------------------------
task train_pattern;
    input [5:0] pattern;
    reg signed [WIDTH-1:0] stim_amplitude;
    begin
        wait_theta_peak();
        // Drive sensory input to create cortical activity
        stim_amplitude = (pattern != 0) ? 18'sd12000 : 18'sd0;
        sensory_input = stim_amplitude;
        wait_updates(30);  // Allow propagation through thalamic relay
        while (ca3_learning) wait_updates(1);
        sensory_input = 18'sd0;
        wait_theta_trough();
        wait_updates(20);
    end
endtask

//-----------------------------------------------------------------------------
// Task: Recall from partial cue via sensory input (v6.2: sensory-only)
// Note: In pure sensory mode, recall depends on cortical state driving CA3
//-----------------------------------------------------------------------------
task recall_pattern;
    input [5:0] cue;
    input [5:0] expected;
    output integer accuracy;
    begin
        wait_theta_trough();
        // Apply sensory cue to trigger cortical pattern
        sensory_input = (cue != 0) ? 18'sd8000 : 18'sd0;
        wait_updates(30);
        while (ca3_recalling) wait_updates(1);

        accuracy = 0;
        for (i = 0; i < 6; i = i + 1) begin
            if (phase_pattern[i] == expected[i]) accuracy = accuracy + 1;
        end

        sensory_input = 18'sd0;
        wait_updates(50);
    end
endtask

//-----------------------------------------------------------------------------
// Task: Clear histograms
//-----------------------------------------------------------------------------
task clear_histogram;
    begin
        for (i = 0; i < 64; i = i + 1) begin
            phase_pattern_hist[i] = 0;
            osc_pattern_hist[i] = 0;
        end
    end
endtask

//-----------------------------------------------------------------------------
// Task: Compute entropy from histogram (returns bits * 256)
//-----------------------------------------------------------------------------
task compute_entropy;
    input integer total_samples;
    output integer entropy_scaled;
    integer bin_count;
    integer contrib;
    begin
        entropy_scaled = 0;
        for (i = 0; i < 64; i = i + 1) begin
            bin_count = phase_pattern_hist[i];
            if (bin_count > 0 && bin_count < 256) begin
                contrib = bin_count * log2_lut[bin_count];
                entropy_scaled = entropy_scaled + contrib / total_samples;
            end
        end
    end
endtask

//-----------------------------------------------------------------------------
// Task: Save current weights for delta calculation
//-----------------------------------------------------------------------------
task save_weights;
    begin
        for (i = 0; i < 6; i = i + 1) begin
            for (j = 0; j < 6; j = j + 1) begin
                prev_weights[i][j] = dut.ca3_mem.weights[i][j];
            end
        end
    end
endtask

//-----------------------------------------------------------------------------
// Task: Compute weight change magnitude
//-----------------------------------------------------------------------------
task compute_weight_delta;
    output integer delta;
    integer d;
    begin
        delta = 0;
        for (i = 0; i < 6; i = i + 1) begin
            for (j = 0; j < 6; j = j + 1) begin
                d = dut.ca3_mem.weights[i][j] - prev_weights[i][j];
                if (d < 0) d = -d;
                delta = delta + d;
            end
        end
    end
endtask

//-----------------------------------------------------------------------------
// Task: Run full characterization for one state
//-----------------------------------------------------------------------------
task run_state_test;
    input [2:0] state;
    input integer idx;
    integer acc_a, acc_b, acc_c;
    integer entropy_result;
    integer local_theta_cycles;
    integer local_learn_events;
    integer local_recall_events;
    integer local_weight_delta;
    integer local_transitions;
    integer local_unique;
    integer measurement_samples;
    integer local_osc_transitions;
    integer local_osc_unique;
    reg [5:0] prev_osc_pattern;
    begin
        $display("");
        $display("=== Testing State %0d ===", state);

        // Reset system
        rst = 1;
        sensory_input = 18'sd0;  // v6.2: sensory-only
        state_select = state;
        update_count = 0;
        repeat(20) @(posedge clk);
        rst = 0;

        // Warmup: 2000 updates (0.5 sec at 4 kHz)
        $display("  Warmup...");
        wait_updates(2000);

        //---------------------------------------------------------------
        // TRAINING PHASE
        //---------------------------------------------------------------
        $display("  Training 3 patterns x5...");
        save_weights();

        for (k = 0; k < 5; k = k + 1) begin
            train_pattern(PAT_A);
            train_pattern(PAT_B);
            train_pattern(PAT_C);
        end

        compute_weight_delta(local_weight_delta);
        weight_change_sum[idx] = local_weight_delta;
        $display("  Weight change after training: %0d", local_weight_delta);

        //---------------------------------------------------------------
        // MEASUREMENT PHASE: 8000 updates (2 sec)
        // Closed-loop: cortical_pattern feeds CA3 automatically!
        //---------------------------------------------------------------
        $display("  Measurement phase (2 sec) - closed-loop active...");

        // Reset counters
        local_theta_cycles = 0;
        local_learn_events = 0;
        local_recall_events = 0;
        local_transitions = 0;
        local_unique = 0;
        local_osc_transitions = 0;
        local_osc_unique = 0;
        amp_sum = 0;
        amp_sq_sum = 0;
        amp_count = 0;
        measurement_samples = 0;
        gamma_amp_sum = 0;
        alpha_amp_sum = 0;

        prev_theta_high = 0;
        prev_learning = 0;
        prev_recalling = 0;
        prev_phase_pattern = phase_pattern;
        prev_osc_pattern = oscillator_derived_pattern;

        clear_histogram();

        // Run measurement loop - no external pattern injection!
        // The closed-loop (cortical_pattern → CA3) provides natural dynamics
        for (k = 0; k < 8000; k = k + 1) begin
            @(posedge clk_4khz_en);
            measurement_samples = measurement_samples + 1;

            // Export phase timeseries (every 4th sample = 1 kHz)
            if (phase_export_enabled && (k % 4 == 0)) begin
                $fdisplay(phase_export_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                    state, k/4,
                    theta_x, theta_y,
                    gamma_x, gamma_y,
                    sens_alpha_x, sens_alpha_y,
                    sens_gamma_x, sens_gamma_y,
                    motor_gamma_x, motor_gamma_y,
                    assoc_gamma_x, assoc_gamma_y
                );
            end

            // Minimal sensory stimulus to trigger occasional recall (v6.2)
            if (k % 2000 == 0) begin
                // Apply sensory stimulus to evoke cortical pattern
                sensory_input = 18'sd8000;
            end else if (k % 2000 == 100) begin
                sensory_input = 18'sd0;
            end

            // Count theta cycles (peak detection)
            if (theta_x > THETA_PEAK_THRESH && !prev_theta_high) begin
                local_theta_cycles = local_theta_cycles + 1;
                prev_theta_high = 1;
            end
            if (theta_x < 18'sd8000) prev_theta_high = 0;

            // Count learning events (rising edge)
            if (ca3_learning && !prev_learning) begin
                local_learn_events = local_learn_events + 1;
            end
            prev_learning = ca3_learning;

            // Count recall events (rising edge)
            if (ca3_recalling && !prev_recalling) begin
                local_recall_events = local_recall_events + 1;
            end
            prev_recalling = ca3_recalling;

            // Count phase pattern transitions (CA3 output)
            if (phase_pattern != prev_phase_pattern) begin
                local_transitions = local_transitions + 1;
                prev_phase_pattern = phase_pattern;
            end

            // Count cortical pattern transitions (closed-loop input to CA3)
            if (oscillator_derived_pattern != prev_osc_pattern) begin
                local_osc_transitions = local_osc_transitions + 1;
                prev_osc_pattern = oscillator_derived_pattern;
            end

            // Update histograms
            phase_pattern_hist[phase_pattern] = phase_pattern_hist[phase_pattern] + 1;
            osc_pattern_hist[oscillator_derived_pattern] = osc_pattern_hist[oscillator_derived_pattern] + 1;

            // Track amplitudes
            amp_sum = amp_sum + theta_amp;
            gamma_amp_sum = gamma_amp_sum + gamma_amp;
            alpha_amp_sum = alpha_amp_sum + alpha_amp;
            amp_count = amp_count + 1;
        end

        sensory_input = 18'sd0;  // v6.2: Clear sensory input

        // Store amplitude averages
        theta_amp_avg[idx] = amp_sum / amp_count;
        gamma_amp_avg[idx] = gamma_amp_sum / amp_count;
        alpha_amp_avg[idx] = alpha_amp_sum / amp_count;

        // Count unique patterns in histograms
        for (i = 0; i < 64; i = i + 1) begin
            if (phase_pattern_hist[i] > 0) local_unique = local_unique + 1;
            if (osc_pattern_hist[i] > 0) local_osc_unique = local_osc_unique + 1;
        end

        // Store metrics
        theta_cycles[idx] = local_theta_cycles;
        learn_events[idx] = local_learn_events;
        recall_events[idx] = local_recall_events;
        pattern_transitions[idx] = local_transitions;
        unique_patterns[idx] = local_unique;
        osc_pattern_transitions[idx] = local_osc_transitions;
        osc_unique_patterns[idx] = local_osc_unique;

        // Effective learning rate
        if (local_theta_cycles > 0)
            effective_learn_rate[idx] = (local_learn_events * 100) / local_theta_cycles;
        else
            effective_learn_rate[idx] = 0;

        // Compute entropy
        compute_entropy(measurement_samples, entropy_result);
        amp_variance[idx] = entropy_result;

        //---------------------------------------------------------------
        // RECALL TEST
        //---------------------------------------------------------------
        $display("  Recall test...");

        recall_pattern(CUE_A, PAT_A, acc_a);
        recall_accuracy_a[idx] = acc_a;
        $display("    A: Cue %b -> %b (target %b) = %0d/6", CUE_A, phase_pattern, PAT_A, acc_a);

        recall_pattern(CUE_B, PAT_B, acc_b);
        recall_accuracy_b[idx] = acc_b;
        $display("    B: Cue %b -> %b (target %b) = %0d/6", CUE_B, phase_pattern, PAT_B, acc_b);

        recall_pattern(CUE_C, PAT_C, acc_c);
        recall_accuracy_c[idx] = acc_c;
        $display("    C: Cue %b -> %b (target %b) = %0d/6", CUE_C, phase_pattern, PAT_C, acc_c);

        //---------------------------------------------------------------
        // HISTOGRAM EXPORT
        //---------------------------------------------------------------
        $display("HISTOGRAM_EXPORT state=%0d", state);
        for (i = 0; i < 64; i = i + 1) begin
            if (phase_pattern_hist[i] > 0) begin
                $display("  bin[%0d] = %0d", i, phase_pattern_hist[i]);
            end
        end

        $display("OSC_HISTOGRAM_EXPORT state=%0d (cortical_pattern)", state);
        for (i = 0; i < 64; i = i + 1) begin
            if (osc_pattern_hist[i] > 0) begin
                $display("  osc_bin[%0d] = %0d", i, osc_pattern_hist[i]);
            end
        end
        $display("  osc_transitions = %0d", local_osc_transitions);
        $display("  osc_unique = %0d", local_osc_unique);
    end
endtask

//-----------------------------------------------------------------------------
// MAIN TEST
//-----------------------------------------------------------------------------
initial begin
    $display("================================================================================");
    $display("CONSCIOUSNESS STATE CHARACTERIZATION v6.2 (CLOSED-LOOP)");
    $display("Using phi_n_neural_processor with cortex → CA3 → phase_pattern → cortex loop");
    $display("================================================================================");
    $display("");
    $display("Testing: NORMAL, ANESTHESIA, PSYCHEDELIC, FLOW, MEDITATION");
    $display("Metrics: Learning dynamics, Entropy, Coherence");
    $display("");

    // Initialize (v6.2: sensory_input is the only data input)
    rst = 1;
    sensory_input = 18'sd0;
    state_select = STATE_NORMAL;

    init_log2_lut();

    // Open phase timeseries export file
    phase_export_file = $fopen("phase_timeseries.csv", "w");
    $fdisplay(phase_export_file, "state,sample,theta_x,theta_y,gamma_x,gamma_y,alpha_x,alpha_y,sens_gamma_x,sens_gamma_y,motor_gamma_x,motor_gamma_y,assoc_gamma_x,assoc_gamma_y");
    phase_export_enabled = 1;

    // Run characterization for each state
    run_state_test(STATE_NORMAL, 0);
    run_state_test(STATE_ANESTHESIA, 1);
    run_state_test(STATE_PSYCHEDELIC, 2);
    run_state_test(STATE_FLOW, 3);
    run_state_test(STATE_MEDITATION, 4);

    //---------------------------------------------------------------
    // SUMMARY TABLE
    //---------------------------------------------------------------
    $display("");
    $display("================================================================================");
    $display("SUMMARY TABLE (phi_n_neural_processor v6.1 closed-loop)");
    $display("================================================================================");
    $display("");
    $display("                      NORMAL   ANESTHESIA  PSYCHEDELIC    FLOW    MEDITATION");
    $display("                      ------   ----------  -----------   ------   ----------");
    $display("LEARNING DYNAMICS:");
    $display("  Theta cycles/2s    %6d   %10d   %10d   %6d   %10d",
             theta_cycles[0], theta_cycles[1], theta_cycles[2], theta_cycles[3], theta_cycles[4]);
    $display("  Learn events/2s    %6d   %10d   %10d   %6d   %10d",
             learn_events[0], learn_events[1], learn_events[2], learn_events[3], learn_events[4]);
    $display("  Recall events/2s   %6d   %10d   %10d   %6d   %10d",
             recall_events[0], recall_events[1], recall_events[2], recall_events[3], recall_events[4]);
    $display("  Weight delta       %6d   %10d   %10d   %6d   %10d",
             weight_change_sum[0], weight_change_sum[1], weight_change_sum[2], weight_change_sum[3], weight_change_sum[4]);
    $display("  Recall A           %4d/6   %8d/6   %9d/6   %4d/6   %8d/6",
             recall_accuracy_a[0], recall_accuracy_a[1], recall_accuracy_a[2], recall_accuracy_a[3], recall_accuracy_a[4]);
    $display("  Recall B           %4d/6   %8d/6   %9d/6   %4d/6   %8d/6",
             recall_accuracy_b[0], recall_accuracy_b[1], recall_accuracy_b[2], recall_accuracy_b[3], recall_accuracy_b[4]);
    $display("  Recall C           %4d/6   %8d/6   %9d/6   %4d/6   %8d/6",
             recall_accuracy_c[0], recall_accuracy_c[1], recall_accuracy_c[2], recall_accuracy_c[3], recall_accuracy_c[4]);
    $display("");
    $display("ENTROPY METRICS (CA3 phase_pattern output):");
    $display("  Unique patterns    %6d   %10d   %10d   %6d   %10d",
             unique_patterns[0], unique_patterns[1], unique_patterns[2], unique_patterns[3], unique_patterns[4]);
    $display("  Transitions/8k     %6d   %10d   %10d   %6d   %10d",
             pattern_transitions[0], pattern_transitions[1], pattern_transitions[2], pattern_transitions[3], pattern_transitions[4]);
    $display("  Entropy (scaled)   %6d   %10d   %10d   %6d   %10d",
             amp_variance[0], amp_variance[1], amp_variance[2], amp_variance[3], amp_variance[4]);
    $display("");
    $display("CORTICAL PATTERN (closed-loop input to CA3):");
    $display("  Unique cortical    %6d   %10d   %10d   %6d   %10d",
             osc_unique_patterns[0], osc_unique_patterns[1], osc_unique_patterns[2], osc_unique_patterns[3], osc_unique_patterns[4]);
    $display("  Transitions/8k     %6d   %10d   %10d   %6d   %10d",
             osc_pattern_transitions[0], osc_pattern_transitions[1], osc_pattern_transitions[2], osc_pattern_transitions[3], osc_pattern_transitions[4]);
    $display("  Learn/theta (x100) %6d   %10d   %10d   %6d   %10d",
             effective_learn_rate[0], effective_learn_rate[1], effective_learn_rate[2], effective_learn_rate[3], effective_learn_rate[4]);
    $display("");
    $display("OSCILLATOR AMPLITUDES:");
    $display("  Theta (thalamus)   %6d   %10d   %10d   %6d   %10d",
             theta_amp_avg[0], theta_amp_avg[1], theta_amp_avg[2], theta_amp_avg[3], theta_amp_avg[4]);
    $display("  Gamma (motor L23)  %6d   %10d   %10d   %6d   %10d",
             gamma_amp_avg[0], gamma_amp_avg[1], gamma_amp_avg[2], gamma_amp_avg[3], gamma_amp_avg[4]);
    $display("  Alpha (sens L6)    %6d   %10d   %10d   %6d   %10d",
             alpha_amp_avg[0], alpha_amp_avg[1], alpha_amp_avg[2], alpha_amp_avg[3], alpha_amp_avg[4]);

    $display("");
    $display("================================================================================");
    $display("STATE SIGNATURES (from phi_n_neural_processor closed-loop):");
    $display("  NORMAL:      Balanced dynamics, moderate complexity");
    $display("  ANESTHESIA:  Reduced theta/gamma, collapsed patterns (UNCONSCIOUS)");
    $display("  PSYCHEDELIC: Enhanced L2/3 gamma, high entropy, chaotic");
    $display("  FLOW:        Enhanced motor pathway, focused execution");
    $display("  MEDITATION:  Enhanced theta/alpha, introspective coherence");
    $display("================================================================================");

    // Close phase timeseries export file
    $fclose(phase_export_file);
    $display("");
    $display("Phase timeseries exported to: phase_timeseries.csv");
    $display("Run: python3 scripts/analyze_vcd_metrics.py tb_state_characterization.vcd");

    $finish;
end

//-----------------------------------------------------------------------------
// Waveform dump - DISABLED for fast simulation
// VCD at 125MHz is too large. Use CSV phase_timeseries.csv for analysis.
//-----------------------------------------------------------------------------
// Uncomment below for VCD if needed (warning: very large files)
/*
initial begin
    $dumpfile("tb_state_characterization.vcd");
    // Only dump at 4kHz clock enable rate to reduce size
    $dumpvars(1, state_select, theta_x, theta_amp);
    $dumpvars(1, gamma_amp, sens_gamma_amp, motor_gamma_amp);
    $dumpvars(1, alpha_amp, phase_pattern, oscillator_derived_pattern);
    $dumpvars(1, ca3_learning, ca3_recalling, dac_output);
end
*/

endmodule
