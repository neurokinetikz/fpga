//=============================================================================
// State Characterization Testbench - v8.0 Compatible (Clean Rewrite)
// Tests all 5 consciousness states with learning dynamics analysis
//=============================================================================
`timescale 1ns / 1ps

module tb_state_characterization;

parameter WIDTH = 18;
parameter FRAC = 14;

// Clock and reset
reg clk, rst;
reg clk_en;

// Inputs
reg signed [WIDTH-1:0] sensory_input;
reg [2:0] state_select;

// DUT outputs
wire [11:0] dac_output;
wire signed [WIDTH-1:0] debug_motor_l23;
wire signed [WIDTH-1:0] debug_theta;
wire ca3_learning;
wire ca3_recalling;
wire [5:0] ca3_phase_pattern;
wire [5:0] cortical_pattern;
wire [2:0] dut_theta_phase;
wire signed [WIDTH-1:0] f0_x_out, f0_y_out, f0_amplitude_out;
wire signed [5*WIDTH-1:0] sr_f_x_packed_out, sr_coherence_packed_out;
wire [4:0] sie_per_harmonic_out, coherence_mask_out;
wire signed [WIDTH-1:0] sr_coherence_out;
wire sr_amplification_out, beta_quiet_out;

// DUT instantiation
phi_n_neural_processor #(.WIDTH(WIDTH), .FRAC(FRAC)) dut (
    .clk(clk),
    .rst(rst),
    .sensory_input(sensory_input),
    .state_select(state_select),
    .sr_field_input(18'sd0),
    .sr_field_packed(90'd0),
    .dac_output(dac_output),
    .debug_motor_l23(debug_motor_l23),
    .debug_theta(debug_theta),
    .ca3_learning(ca3_learning),
    .ca3_recalling(ca3_recalling),
    .ca3_phase_pattern(ca3_phase_pattern),
    .cortical_pattern_out(cortical_pattern),
    .f0_x(f0_x_out),
    .f0_y(f0_y_out),
    .f0_amplitude(f0_amplitude_out),
    .sr_f_x_packed(sr_f_x_packed_out),
    .sr_coherence_packed(sr_coherence_packed_out),
    .sie_per_harmonic(sie_per_harmonic_out),
    .coherence_mask(coherence_mask_out),
    .sr_coherence(sr_coherence_out),
    .sr_amplification(sr_amplification_out),
    .beta_quiet(beta_quiet_out),
    .theta_phase(dut_theta_phase)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// State definitions
localparam [2:0] STATE_NORMAL     = 3'd0;
localparam [2:0] STATE_ANESTHESIA = 3'd1;
localparam [2:0] STATE_PSYCHEDELIC = 3'd2;
localparam [2:0] STATE_FLOW       = 3'd3;
localparam [2:0] STATE_MEDITATION = 3'd4;

// Test patterns
localparam [5:0] PAT_A = 6'b101010;
localparam [5:0] PAT_B = 6'b010101;
localparam [5:0] PAT_C = 6'b110011;
localparam [5:0] CUE_A = 6'b100000;
localparam [5:0] CUE_B = 6'b000001;
localparam [5:0] CUE_C = 6'b110000;

// Theta thresholds
localparam signed [WIDTH-1:0] THETA_PEAK_THRESH = 18'sd12288;
localparam signed [WIDTH-1:0] THETA_TROUGH_THRESH = -18'sd12288;

// Test variables
integer i, j, k;
integer state_idx;
integer update_count;
integer match_count;
integer phase_export_file;

// Per-state metrics storage
reg signed [31:0] theta_cycles [0:4];
reg signed [31:0] learn_events [0:4];
reg signed [31:0] recall_events [0:4];
reg signed [31:0] weight_change_sum [0:4];
reg signed [31:0] recall_accuracy_a [0:4];
reg signed [31:0] recall_accuracy_b [0:4];
reg signed [31:0] recall_accuracy_c [0:4];
reg signed [31:0] unique_patterns [0:4];
reg signed [31:0] pattern_transitions [0:4];
reg signed [31:0] amp_variance [0:4];
reg signed [31:0] theta_amp_avg [0:4];
reg signed [31:0] gamma_amp_avg [0:4];
reg signed [31:0] alpha_amp_avg [0:4];
reg signed [31:0] osc_pattern_transitions [0:4];
reg signed [31:0] osc_unique_patterns [0:4];
reg signed [31:0] effective_learn_rate [0:4];

// Histograms
reg signed [31:0] phase_pattern_hist [0:63];
reg signed [31:0] osc_pattern_hist [0:63];

// Working variables
reg [5:0] prev_phase_pattern;
reg [5:0] prev_osc_pattern;
reg prev_learning, prev_recalling;
reg prev_theta_high;
integer amp_sum, amp_count;
integer gamma_amp_sum, alpha_amp_sum;

// Weight tracking
reg signed [7:0] prev_weights [0:5][0:5];

// Hierarchical references to internal signals
wire signed [WIDTH-1:0] theta_x = dut.thalamic_theta_x;
wire signed [WIDTH-1:0] theta_y = dut.thalamic_theta_y;
wire signed [WIDTH-1:0] theta_amp = dut.thalamic_theta_amp;
wire signed [WIDTH-1:0] sens_gamma_x = dut.sensory_l23_x;
wire signed [WIDTH-1:0] sens_gamma_y = dut.sensory_l23_y;
wire signed [WIDTH-1:0] sens_alpha_x = dut.sensory_l6_x;
wire signed [WIDTH-1:0] sens_alpha_y = dut.sensory_l6_y;
wire signed [WIDTH-1:0] motor_gamma_x = dut.motor_l23_x;
wire signed [WIDTH-1:0] motor_gamma_y = dut.motor_l23_y;
wire signed [WIDTH-1:0] assoc_gamma_x = dut.assoc_l23_x;
wire signed [WIDTH-1:0] assoc_gamma_y = dut.assoc_l23_y;
wire [5:0] phase_pattern = ca3_phase_pattern;
wire clk_4khz_en = dut.clk_4khz_en;

// Amplitude computation (single-line for iverilog compatibility)
wire signed [WIDTH-1:0] sens_gamma_amp;
wire signed [WIDTH-1:0] motor_gamma_amp;
wire signed [WIDTH-1:0] alpha_amp;
wire signed [WIDTH-1:0] gamma_amp;
assign sens_gamma_amp = (sens_gamma_x[WIDTH-1] ? -sens_gamma_x : sens_gamma_x) + (sens_gamma_y[WIDTH-1] ? -sens_gamma_y : sens_gamma_y);
assign motor_gamma_amp = (motor_gamma_x[WIDTH-1] ? -motor_gamma_x : motor_gamma_x) + (motor_gamma_y[WIDTH-1] ? -motor_gamma_y : motor_gamma_y);
assign alpha_amp = (sens_alpha_x[WIDTH-1] ? -sens_alpha_x : sens_alpha_x) + (sens_alpha_y[WIDTH-1] ? -sens_alpha_y : sens_alpha_y);
assign gamma_amp = motor_gamma_amp;

// Task: wait for n clk_4khz_en pulses
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

// Task: wait for theta peak
task wait_theta_peak;
    begin
        while (theta_x < THETA_PEAK_THRESH) wait_updates(1);
    end
endtask

// Task: wait for theta trough
task wait_theta_trough;
    begin
        while (theta_x > THETA_TROUGH_THRESH) wait_updates(1);
    end
endtask

// Task: train a pattern
task train_pattern;
    input [5:0] pattern;
    begin
        wait_theta_peak();
        sensory_input = (pattern != 0) ? 18'sd12000 : 18'sd0;
        wait_updates(30);
        while (ca3_learning) wait_updates(1);
        sensory_input = 18'sd0;
        wait_theta_trough();
        wait_updates(20);
    end
endtask

// Task: recall from partial cue
task recall_pattern;
    input [5:0] cue;
    input [5:0] expected;
    output integer accuracy;
    integer acc_i;
    begin
        wait_theta_trough();
        sensory_input = (cue != 0) ? 18'sd8000 : 18'sd0;
        wait_updates(30);
        while (ca3_recalling) wait_updates(1);
        accuracy = 0;
        for (acc_i = 0; acc_i < 6; acc_i = acc_i + 1) begin
            if (phase_pattern[acc_i] == expected[acc_i]) accuracy = accuracy + 1;
        end
        sensory_input = 18'sd0;
        wait_updates(50);
    end
endtask

// Task: clear histograms
task clear_histogram;
    integer hi;
    begin
        for (hi = 0; hi < 64; hi = hi + 1) begin
            phase_pattern_hist[hi] = 0;
            osc_pattern_hist[hi] = 0;
        end
    end
endtask

// Task: save weights
task save_weights;
    integer wi, wj;
    begin
        for (wi = 0; wi < 6; wi = wi + 1) begin
            for (wj = 0; wj < 6; wj = wj + 1) begin
                prev_weights[wi][wj] = dut.ca3_mem.weights[wi][wj];
            end
        end
    end
endtask

// Task: compute weight delta
task compute_weight_delta;
    output integer delta;
    integer di, dj, d;
    begin
        delta = 0;
        for (di = 0; di < 6; di = di + 1) begin
            for (dj = 0; dj < 6; dj = dj + 1) begin
                d = dut.ca3_mem.weights[di][dj] - prev_weights[di][dj];
                if (d < 0) d = -d;
                delta = delta + d;
            end
        end
    end
endtask

// Task: run full test for one state
task run_state_test;
    input [2:0] state;
    input integer idx;
    integer acc_a, acc_b, acc_c;
    integer local_theta_cycles;
    integer local_learn_events;
    integer local_recall_events;
    integer local_weight_delta;
    integer local_transitions;
    integer local_unique;
    integer local_osc_transitions;
    integer local_osc_unique;
    integer measurement_samples;
    integer tk;
    integer hi;
    begin
        $display("");
        $display("=== Testing State %0d ===", state);

        rst = 1;
        sensory_input = 18'sd0;
        state_select = state;
        update_count = 0;
        repeat(20) @(posedge clk);
        rst = 0;

        $display("  Warmup...");
        wait_updates(2000);

        $display("  Training 3 patterns x5...");
        save_weights();

        for (tk = 0; tk < 5; tk = tk + 1) begin
            train_pattern(PAT_A);
            train_pattern(PAT_B);
            train_pattern(PAT_C);
        end

        compute_weight_delta(local_weight_delta);
        weight_change_sum[idx] = local_weight_delta;
        $display("  Weight change after training: %0d", local_weight_delta);

        $display("  Measurement phase (2 sec)...");

        local_theta_cycles = 0;
        local_learn_events = 0;
        local_recall_events = 0;
        local_transitions = 0;
        local_unique = 0;
        local_osc_transitions = 0;
        local_osc_unique = 0;
        amp_sum = 0;
        amp_count = 0;
        measurement_samples = 0;
        gamma_amp_sum = 0;
        alpha_amp_sum = 0;

        prev_theta_high = 0;
        prev_learning = 0;
        prev_recalling = 0;
        prev_phase_pattern = phase_pattern;
        prev_osc_pattern = cortical_pattern;

        clear_histogram();

        for (tk = 0; tk < 8000; tk = tk + 1) begin
            @(posedge clk_4khz_en);
            measurement_samples = measurement_samples + 1;

            if (tk % 2000 == 0) begin
                sensory_input = 18'sd8000;
            end else if (tk % 2000 == 100) begin
                sensory_input = 18'sd0;
            end

            if (theta_x > THETA_PEAK_THRESH && !prev_theta_high) begin
                local_theta_cycles = local_theta_cycles + 1;
                prev_theta_high = 1;
            end
            if (theta_x < 18'sd8000) prev_theta_high = 0;

            if (ca3_learning && !prev_learning) begin
                local_learn_events = local_learn_events + 1;
            end
            prev_learning = ca3_learning;

            if (ca3_recalling && !prev_recalling) begin
                local_recall_events = local_recall_events + 1;
            end
            prev_recalling = ca3_recalling;

            if (phase_pattern != prev_phase_pattern) begin
                local_transitions = local_transitions + 1;
                prev_phase_pattern = phase_pattern;
            end

            if (cortical_pattern != prev_osc_pattern) begin
                local_osc_transitions = local_osc_transitions + 1;
                prev_osc_pattern = cortical_pattern;
            end

            phase_pattern_hist[phase_pattern] = phase_pattern_hist[phase_pattern] + 1;
            osc_pattern_hist[cortical_pattern] = osc_pattern_hist[cortical_pattern] + 1;

            amp_sum = amp_sum + theta_amp;
            gamma_amp_sum = gamma_amp_sum + gamma_amp;
            alpha_amp_sum = alpha_amp_sum + alpha_amp;
            amp_count = amp_count + 1;
        end

        sensory_input = 18'sd0;

        theta_amp_avg[idx] = amp_sum / amp_count;
        gamma_amp_avg[idx] = gamma_amp_sum / amp_count;
        alpha_amp_avg[idx] = alpha_amp_sum / amp_count;

        for (hi = 0; hi < 64; hi = hi + 1) begin
            if (phase_pattern_hist[hi] > 0) local_unique = local_unique + 1;
            if (osc_pattern_hist[hi] > 0) local_osc_unique = local_osc_unique + 1;
        end

        theta_cycles[idx] = local_theta_cycles;
        learn_events[idx] = local_learn_events;
        recall_events[idx] = local_recall_events;
        pattern_transitions[idx] = local_transitions;
        unique_patterns[idx] = local_unique;
        osc_pattern_transitions[idx] = local_osc_transitions;
        osc_unique_patterns[idx] = local_osc_unique;

        if (local_theta_cycles > 0)
            effective_learn_rate[idx] = (local_learn_events * 100) / local_theta_cycles;
        else
            effective_learn_rate[idx] = 0;

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

        $display("  Unique patterns: %0d, Transitions: %0d", local_unique, local_transitions);
    end
endtask

// Main test sequence
initial begin
    $display("================================================================");
    $display("STATE CHARACTERIZATION TESTBENCH - v8.0 Enhanced");
    $display("Testing all 5 consciousness states with learning dynamics");
    $display("================================================================");

    rst = 1;
    sensory_input = 18'sd0;
    state_select = STATE_NORMAL;

    // Run all state tests
    run_state_test(STATE_NORMAL, 0);
    run_state_test(STATE_ANESTHESIA, 1);
    run_state_test(STATE_PSYCHEDELIC, 2);
    run_state_test(STATE_FLOW, 3);
    run_state_test(STATE_MEDITATION, 4);

    // Summary Table
    $display("");
    $display("================================================================");
    $display("SUMMARY TABLE");
    $display("================================================================");
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
    $display("ENTROPY METRICS:");
    $display("  Unique patterns    %6d   %10d   %10d   %6d   %10d",
             unique_patterns[0], unique_patterns[1], unique_patterns[2], unique_patterns[3], unique_patterns[4]);
    $display("  Transitions/8k     %6d   %10d   %10d   %6d   %10d",
             pattern_transitions[0], pattern_transitions[1], pattern_transitions[2], pattern_transitions[3], pattern_transitions[4]);
    $display("");
    $display("CORTICAL PATTERN:");
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
    $display("================================================================");
    $display("STATE CHARACTERIZATION COMPLETE");
    $display("================================================================");

    $finish;
end

// Waveform dump
initial begin
    $dumpfile("tb_state_characterization.vcd");
    $dumpvars(0, tb_state_characterization);
end

endmodule
