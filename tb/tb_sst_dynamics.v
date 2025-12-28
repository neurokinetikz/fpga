//=============================================================================
// SST+ Slow Dynamics Testbench - v9.1
//
// Tests the SST+ (somatostatin-positive) Martinotti cell slow dynamics
// added to layer1_minimal.v in v9.1.
//
// Verifies:
// 1. Step input → slow rise of gain (not instantaneous)
// 2. Step removal → slow decay back to baseline
// 3. Time constant approximately 25ms (100 clk_en cycles at 4kHz)
// 4. Final gain reaches correct steady state
// 5. Gain stays within [0.5, 1.5] bounds
//=============================================================================
`timescale 1ns / 1ps

module tb_sst_dynamics;

parameter WIDTH = 18;
parameter FRAC = 14;

reg clk;
reg rst;
reg clk_en;

// L1 inputs
reg signed [WIDTH-1:0] matrix_thalamic_input;
reg signed [WIDTH-1:0] feedback_input_1;
reg signed [WIDTH-1:0] feedback_input_2;

// L1 output
wire signed [WIDTH-1:0] apical_gain;

// Test tracking
integer test_num;
integer pass_count;
integer fail_count;

// Constants
localparam signed [WIDTH-1:0] ONE = 18'sd16384;     // 1.0
localparam signed [WIDTH-1:0] HALF = 18'sd8192;     // 0.5
localparam signed [WIDTH-1:0] GAIN_1_5 = 18'sd24576; // 1.5
localparam signed [WIDTH-1:0] GAIN_2_0 = 18'sd32768; // 2.0 (v9.6 upper bound)
localparam signed [WIDTH-1:0] GAIN_0_25 = 18'sd4096; // 0.25 (v9.6 lower bound)

// Tracking for time constant measurement
reg signed [WIDTH-1:0] gain_at_step;
reg signed [WIDTH-1:0] gain_after_tau;

// Clock generation (125 MHz)
initial begin
    clk = 0;
    forever #4 clk = ~clk;
end

// Clock enable generation (4 kHz equivalent)
reg [3:0] clk_div;
always @(posedge clk) begin
    if (rst) begin
        clk_div <= 0;
        clk_en <= 0;
    end else begin
        clk_div <= clk_div + 1;
        clk_en <= (clk_div == 0);
    end
end

// DUT instantiation
// v9.4: Debug outputs for visibility
wire signed [WIDTH-1:0] sst_activity;
wire signed [WIDTH-1:0] vip_activity;
wire signed [WIDTH-1:0] sst_effective;

layer1_minimal #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .matrix_thalamic_input(matrix_thalamic_input),
    .feedback_input_1(feedback_input_1),
    .feedback_input_2(feedback_input_2),
    .attention_input(18'sd0),        // v9.4: No attention for SST+ tests
    .l6_direct_input(18'sd0),        // v9.6: No L6 direct input for SST+ tests
    .apical_gain(apical_gain),
    .sst_activity_out(sst_activity),
    .vip_activity_out(vip_activity),
    .sst_effective_out(sst_effective)
);

// Helper task: wait for N clk_en cycles
task wait_cycles;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk);
            while (!clk_en) @(posedge clk);
        end
    end
endtask

// Initialize inputs to zero
task init_inputs;
    begin
        matrix_thalamic_input = 0;
        feedback_input_1 = 0;
        feedback_input_2 = 0;
    end
endtask

initial begin
    $display("=============================================================");
    $display("SST+ Slow Dynamics Testbench - v9.1");
    $display("=============================================================");

    test_num = 0;
    pass_count = 0;
    fail_count = 0;

    // Reset
    rst = 1;
    init_inputs;
    repeat(10) @(posedge clk);
    rst = 0;
    wait_cycles(10);

    //=========================================================================
    // Test 1: Zero input = unity gain (1.0) after settling
    //=========================================================================
    test_num = 1;
    $display("\nTest %0d: Zero input gives unity gain", test_num);

    init_inputs;
    wait_cycles(200);  // Let any transient settle

    $display("  apical_gain = %0d (expected ~16384 = 1.0)", apical_gain);

    if (apical_gain >= ONE - 100 && apical_gain <= ONE + 100) begin
        $display("  PASS: Unity gain with zero input");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Expected unity gain, got %0d", apical_gain);
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 2: Step input - verify NOT instantaneous (SST+ slow rise)
    //=========================================================================
    test_num = 2;
    $display("\nTest %0d: Step input - slow rise (not instantaneous)", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    wait_cycles(50);

    // Record gain before step
    gain_at_step = apical_gain;
    $display("  Gain before step: %0d", gain_at_step);

    // Apply positive step input
    feedback_input_1 = ONE;  // +1.0 input (weight 0.3 → +0.3 offset)

    // Check gain after just 5 cycles (should NOT be at final value yet)
    wait_cycles(5);
    $display("  Gain after 5 cycles: %0d", apical_gain);

    // With instantaneous, gain would jump to ~1.3 (21299)
    // With SST+ filter, it should still be close to 1.0
    if (apical_gain < 18'sd18000) begin
        $display("  PASS: Gain rises slowly (not instantaneous)");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Gain jumped too fast (got %0d)", apical_gain);
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 3: Time constant approximately 25ms (100 cycles at 4kHz)
    //=========================================================================
    test_num = 3;
    $display("\nTest %0d: Time constant ~25ms (63%% rise in 100 cycles)", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    wait_cycles(50);

    // Record baseline
    gain_at_step = apical_gain;

    // Apply step
    feedback_input_1 = ONE;  // → final offset ~0.3 → final gain ~1.3

    // Wait one time constant (100 cycles = 25ms at 4kHz)
    wait_cycles(100);
    gain_after_tau = apical_gain;

    // Calculate expected: should reach ~63% of final value
    // Final gain = 1.0 + 0.3 = 1.3 (21299 in Q14)
    // After 1 tau: 1.0 + 0.63 * 0.3 = 1.189 (~19497 in Q14)
    $display("  Gain at baseline: %0d", gain_at_step);
    $display("  Gain after 1 tau (100 cycles): %0d", gain_after_tau);

    // Check if gain is in expected range (roughly 60-70% of way to final)
    if (gain_after_tau > 18'sd18000 && gain_after_tau < 18'sd21000) begin
        $display("  PASS: Time constant approximately correct");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Time constant seems wrong (got %0d)", gain_after_tau);
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 4: Steady state reached after 5 time constants
    //=========================================================================
    test_num = 4;
    $display("\nTest %0d: Steady state after 5 tau (~500 cycles)", test_num);

    // Continue from previous test, wait 4 more time constants
    wait_cycles(400);

    $display("  Gain after 5 tau: %0d (expected ~21299 = 1.3)", apical_gain);

    // Should be very close to final value: 1.0 + 0.3 = 1.3
    // Actual: 16384 + 4915 = 21299
    if (apical_gain > 18'sd20500 && apical_gain < 18'sd22000) begin
        $display("  PASS: Reached steady state");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Did not reach expected steady state");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 5: Step removal - slow decay back to baseline
    //=========================================================================
    test_num = 5;
    $display("\nTest %0d: Step removal - slow decay", test_num);

    // Record gain before step removal
    gain_at_step = apical_gain;
    $display("  Gain before removal: %0d", gain_at_step);

    // Remove input
    feedback_input_1 = 0;

    // Check after 5 cycles (should NOT be at baseline yet)
    wait_cycles(5);
    $display("  Gain after 5 cycles: %0d", apical_gain);

    if (apical_gain > 18'sd18000) begin
        $display("  PASS: Gain decays slowly (not instantaneous)");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Gain decayed too fast");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 6: Full decay back to unity
    //=========================================================================
    test_num = 6;
    $display("\nTest %0d: Full decay back to unity", test_num);

    wait_cycles(500);  // 5 time constants

    $display("  Gain after decay: %0d (expected ~16384 = 1.0)", apical_gain);

    if (apical_gain >= ONE - 200 && apical_gain <= ONE + 200) begin
        $display("  PASS: Decayed back to unity");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Did not decay to unity");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 7: Clamping at upper bound (2.0) - v9.6 changed from 1.5
    //=========================================================================
    test_num = 7;
    $display("\nTest %0d: Upper bound clamping (2.0) - v9.6", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;

    // Apply very large positive input
    matrix_thalamic_input = ONE * 2;  // 2.0
    feedback_input_1 = ONE * 2;       // 2.0
    feedback_input_2 = ONE * 2;       // 2.0

    wait_cycles(600);  // Let it settle

    $display("  Gain with large input: %0d (expected 32768 = 2.0)", apical_gain);

    if (apical_gain == GAIN_2_0) begin
        $display("  PASS: Clamped at upper bound");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Not clamped correctly (got %0d)", apical_gain);
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 8: Clamping at lower bound (0.25) - v9.6 changed from 0.5
    //=========================================================================
    test_num = 8;
    $display("\nTest %0d: Lower bound clamping (0.25) - v9.6", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;

    // Apply very large negative input
    matrix_thalamic_input = -ONE * 2;  // -2.0
    feedback_input_1 = -ONE * 2;       // -2.0
    feedback_input_2 = -ONE * 2;       // -2.0

    wait_cycles(600);  // Let it settle

    $display("  Gain with large negative input: %0d (expected 4096 = 0.25)", apical_gain);

    if (apical_gain == GAIN_0_25) begin
        $display("  PASS: Clamped at lower bound");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Not clamped correctly (got %0d)", apical_gain);
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n=============================================================");
    $display("SST+ Slow Dynamics Test Summary");
    $display("=============================================================");
    $display("Total tests: %0d", test_num);
    $display("Passed: %0d", pass_count);
    $display("Failed: %0d", fail_count);

    if (fail_count == 0) begin
        $display("\n*** ALL TESTS PASSED ***");
    end else begin
        $display("\n*** SOME TESTS FAILED ***");
    end

    $display("=============================================================");
    $finish;
end

endmodule
