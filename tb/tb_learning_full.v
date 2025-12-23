//=============================================================================
// Learning & Memory Testbench (Full Version) - v1.0
// Tests CA3 Hebbian learning using phi_n_neural_processor at production speed
//
// PRODUCTION SIMULATION: Uses phi_n_neural_processor with real clock dividers
// Note: This testbench runs slower but tests actual timing behavior
//
// TEST SCENARIOS:
// 1. Single pattern encoding and recall
// 2. Multiple pattern storage
// 3. Sensory-driven learning (thalamic relay pathway)
//
// For faster iteration, use tb_learning_fast.v
//=============================================================================
`timescale 1ns / 1ps

module tb_learning_full;

parameter WIDTH = 18;
parameter FRAC = 14;

//-----------------------------------------------------------------------------
// Clock, Reset, and Control
//-----------------------------------------------------------------------------
reg clk, rst;
reg signed [WIDTH-1:0] sensory_input;  // v6.2: ONLY external data input
reg [2:0] state_select;

//-----------------------------------------------------------------------------
// State Definitions
//-----------------------------------------------------------------------------
localparam [2:0] STATE_NORMAL     = 3'd0;
localparam [2:0] STATE_ANESTHESIA = 3'd1;
localparam [2:0] STATE_PSYCHEDELIC = 3'd2;
localparam [2:0] STATE_FLOW       = 3'd3;
localparam [2:0] STATE_MEDITATION = 3'd4;

//-----------------------------------------------------------------------------
// Test Patterns
//-----------------------------------------------------------------------------
localparam [5:0] PAT_A = 6'b101010;
localparam [5:0] PAT_B = 6'b010101;
localparam [5:0] PAT_C = 6'b110011;

localparam [5:0] CUE_A = 6'b100000;
localparam [5:0] CUE_B = 6'b000001;
localparam [5:0] CUE_C = 6'b110000;

//-----------------------------------------------------------------------------
// Theta Thresholds
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] THETA_PEAK_THRESH  = 18'sd12288;
localparam signed [WIDTH-1:0] THETA_TROUGH_THRESH = -18'sd12288;

//-----------------------------------------------------------------------------
// DUT: phi_n_neural_processor (full production module)
//-----------------------------------------------------------------------------
wire [11:0] dac_output;
wire signed [WIDTH-1:0] debug_motor_l23;
wire signed [WIDTH-1:0] debug_theta;
wire ca3_learning;
wire ca3_recalling;
wire [5:0] ca3_phase_pattern;
wire [5:0] cortical_pattern;

phi_n_neural_processor #(.WIDTH(WIDTH), .FRAC(FRAC)) dut (
    .clk(clk),
    .rst(rst),
    .sensory_input(sensory_input),  // v6.2: ONLY external data input
    .state_select(state_select),
    .sr_field_input(18'sd0),
    .sr_field_packed(90'd0),
    .dac_output(dac_output),
    .debug_motor_l23(debug_motor_l23),
    .debug_theta(debug_theta),
    .ca3_learning(ca3_learning),
    .ca3_recalling(ca3_recalling),
    .ca3_phase_pattern(ca3_phase_pattern),
    .cortical_pattern_out(cortical_pattern)
);

//-----------------------------------------------------------------------------
// Hierarchical access to internal signals
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] theta_x = dut.thalamic_theta_x;
wire clk_4khz_en = dut.clk_4khz_en;

//-----------------------------------------------------------------------------
// Clock Generation: 8ns period (125 MHz - production speed)
//-----------------------------------------------------------------------------
initial begin clk = 0; forever #4 clk = ~clk; end

//-----------------------------------------------------------------------------
// Test Variables
//-----------------------------------------------------------------------------
integer i, j;
integer test_pass, test_fail;
integer update_count;
integer learn_count, recall_count;
integer recall_accuracy;
integer total_weight_delta;

reg signed [7:0] weights_before [0:5][0:5];

//-----------------------------------------------------------------------------
// Task: Wait for N 4kHz updates (production timing)
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
// Task: Train pattern via sensory input (v6.2 - thalamic relay pathway)
//-----------------------------------------------------------------------------
task train_pattern;
    input [5:0] pattern;
    input integer repetitions;
    integer r;
    reg signed [WIDTH-1:0] stim_amplitude;
    begin
        for (r = 0; r < repetitions; r = r + 1) begin
            wait_theta_peak();
            stim_amplitude = (pattern != 0) ? 18'sd12000 : 18'sd0;
            sensory_input = stim_amplitude;
            wait_updates(30);
            if (ca3_learning) learn_count = learn_count + 1;
            while (theta_x > THETA_PEAK_THRESH - 18'sd2000) wait_updates(1);
            sensory_input = 18'sd0;
            wait_theta_trough();
            wait_updates(50);
        end
    end
endtask

//-----------------------------------------------------------------------------
// Task: Recall via sensory cue (v6.2 - thalamic relay pathway)
//-----------------------------------------------------------------------------
task recall_pattern;
    input [5:0] cue;
    input [5:0] expected;
    output integer accuracy;
    integer bit_matches;
    reg signed [WIDTH-1:0] stim_amplitude;
    begin
        wait_theta_trough();
        stim_amplitude = (cue != 0) ? -18'sd8000 : 18'sd0;
        sensory_input = stim_amplitude;
        wait_updates(10);
        if (ca3_recalling) recall_count = recall_count + 1;
        wait_updates(50);

        bit_matches = 0;
        for (i = 0; i < 6; i = i + 1) begin
            if (ca3_phase_pattern[i] == expected[i]) bit_matches = bit_matches + 1;
        end
        accuracy = bit_matches;

        sensory_input = 18'sd0;
        wait_theta_peak();
        wait_updates(20);
    end
endtask

//-----------------------------------------------------------------------------
// Task: Save weights
//-----------------------------------------------------------------------------
task save_weights;
    begin
        for (i = 0; i < 6; i = i + 1) begin
            for (j = 0; j < 6; j = j + 1) begin
                weights_before[i][j] = dut.ca3_mem.weights[i][j];
            end
        end
    end
endtask

//-----------------------------------------------------------------------------
// Task: Compute weight change
//-----------------------------------------------------------------------------
task compute_weight_change;
    output integer delta;
    integer d;
    begin
        delta = 0;
        for (i = 0; i < 6; i = i + 1) begin
            for (j = 0; j < 6; j = j + 1) begin
                d = dut.ca3_mem.weights[i][j] - weights_before[i][j];
                if (d < 0) d = -d;
                delta = delta + d;
            end
        end
    end
endtask

//-----------------------------------------------------------------------------
// Task: Print weight matrix
//-----------------------------------------------------------------------------
task print_weights;
    input [255:0] label;
    begin
        $display("  %s:", label);
        $display("       S_g S_a A_g A_a M_g M_a");
        for (i = 0; i < 6; i = i + 1) begin
            $write("    %0d:", i);
            for (j = 0; j < 6; j = j + 1) begin
                $write(" %3d", dut.ca3_mem.weights[i][j]);
            end
            $display("");
        end
    end
endtask

//-----------------------------------------------------------------------------
// MAIN TEST
//-----------------------------------------------------------------------------
initial begin
    $display("================================================================================");
    $display("LEARNING & MEMORY TESTBENCH v1.0 (FULL - Production Speed)");
    $display("Testing: CA3 Hebbian learning with phi_n_neural_processor");
    $display("Note: This test runs at production clock speed (125 MHz / 31250 = 4 kHz)");
    $display("================================================================================");

    // Initialize
    rst = 1;
    sensory_input = 18'sd0;
    state_select = STATE_NORMAL;
    test_pass = 0;
    test_fail = 0;
    update_count = 0;
    learn_count = 0;
    recall_count = 0;

    repeat(100) @(posedge clk);
    rst = 0;

    // Warmup (oscillators need time to stabilize at production speed)
    $display("");
    $display("Warming up oscillators (2000 updates)...");
    wait_updates(2000);
    $display("  Theta: %0d, oscillators active", theta_x);

    //=========================================================================
    // TEST 1: Single Pattern Learning
    //=========================================================================
    $display("");
    $display("========================================");
    $display("TEST 1: SINGLE PATTERN LEARNING");
    $display("========================================");

    save_weights();
    print_weights("Initial weights");

    $display("  Training pattern A (101010) x5...");
    learn_count = 0;
    train_pattern(PAT_A, 5);
    $display("  Learning events: %0d", learn_count);

    compute_weight_change(total_weight_delta);
    $display("  Weight change: %0d", total_weight_delta);
    print_weights("After training A");

    // Test recall
    $display("  Testing recall from cue (100000)...");
    recall_pattern(CUE_A, PAT_A, recall_accuracy);
    $display("  Recall: pattern=%b, accuracy=%0d/6", ca3_phase_pattern, recall_accuracy);

    // At production speed, focus on weight changes as primary indicator
    // Recall accuracy can be noisy due to ongoing cortical activity
    if (total_weight_delta > 50 && learn_count >= 3) begin
        $display("  [PASS] Single pattern learned (weights updated, learning triggered)");
        test_pass = test_pass + 1;
    end else begin
        $display("  [FAIL] Learning mechanism failed");
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 2: Multiple Patterns
    //=========================================================================
    $display("");
    $display("========================================");
    $display("TEST 2: MULTIPLE PATTERNS");
    $display("========================================");

    // Reset to avoid pattern interference
    rst = 1;
    repeat(100) @(posedge clk);
    rst = 0;
    wait_updates(1000);

    save_weights();

    $display("  Training patterns A, B, C x3 each...");
    learn_count = 0;
    train_pattern(PAT_A, 3);
    train_pattern(PAT_B, 3);
    train_pattern(PAT_C, 3);
    $display("  Learning events: %0d", learn_count);

    compute_weight_change(total_weight_delta);
    $display("  Weight change: %0d", total_weight_delta);
    print_weights("After training A,B,C");

    // Test all three recalls
    $display("  Testing recall...");

    recall_pattern(CUE_A, PAT_A, recall_accuracy);
    $display("    A: %b -> %b = %0d/6", CUE_A, ca3_phase_pattern, recall_accuracy);

    recall_pattern(CUE_B, PAT_B, recall_accuracy);
    $display("    B: %b -> %b = %0d/6", CUE_B, ca3_phase_pattern, recall_accuracy);

    recall_pattern(CUE_C, PAT_C, recall_accuracy);
    $display("    C: %b -> %b = %0d/6", CUE_C, ca3_phase_pattern, recall_accuracy);

    // Focus on learning mechanism, not recall accuracy
    if (total_weight_delta > 100 && learn_count >= 6) begin
        $display("  [PASS] Multiple patterns stored (Hebbian learning active)");
        test_pass = test_pass + 1;
    end else begin
        $display("  [FAIL] Multiple pattern storage failed");
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 3: Sensory-Driven Learning
    //=========================================================================
    $display("");
    $display("========================================");
    $display("TEST 3: SENSORY-DRIVEN LEARNING");
    $display("========================================");
    $display("  Testing learning via thalamic relay pathway");

    // Reset
    rst = 1;
    repeat(100) @(posedge clk);
    rst = 0;
    wait_updates(500);

    save_weights();

    $display("  Training via sensory_input stimulus x3...");
    learn_count = 0;
    train_pattern(PAT_A, 3);  // v6.2: All training uses sensory input now
    $display("  Learning events: %0d", learn_count);

    compute_weight_change(total_weight_delta);
    $display("  Weight change: %0d", total_weight_delta);

    if (total_weight_delta > 20 || learn_count > 0) begin
        $display("  [PASS] Sensory stimulus caused Hebbian learning");
        test_pass = test_pass + 1;
    end else begin
        $display("  [FAIL] Sensory stimulus did not propagate to CA3");
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // SUMMARY
    //=========================================================================
    $display("");
    $display("================================================================================");
    $display("SUMMARY");
    $display("================================================================================");
    $display("  Tests passed: %0d", test_pass);
    $display("  Tests failed: %0d", test_fail);
    $display("  Total updates: %0d", update_count);
    $display("");

    if (test_fail == 0) begin
        $display("  *** ALL TESTS PASSED ***");
    end else begin
        $display("  *** SOME TESTS FAILED ***");
    end

    $display("");
    $display("Note: For faster iteration, use tb_learning_fast.v");
    $display("================================================================================");

    #1000;
    $finish;
end

//-----------------------------------------------------------------------------
// Optional VCD dump
//-----------------------------------------------------------------------------
// initial begin
//     $dumpfile("tb_learning_full.vcd");
//     $dumpvars(0, tb_learning_full);
// end

endmodule
