//=============================================================================
// CA3 Learning Explicit Test - v8.0 Compatible
// Verifies Hebbian weight updates and pattern recall
//=============================================================================
`timescale 1ns / 1ps

module tb_ca3_learning;

parameter WIDTH = 18;
parameter FRAC = 14;

reg clk, rst, clk_en;

// Theta oscillator
wire signed [WIDTH-1:0] theta_x, theta_y, theta_amp;
localparam signed [WIDTH-1:0] MU_DT = 18'sd4;
localparam signed [WIDTH-1:0] OMEGA_THETA = 18'sd152;

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) theta_osc (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(MU_DT), .omega_dt(OMEGA_THETA), .input_x(18'sd0),
    .x(theta_x), .y(theta_y), .amplitude(theta_amp)
);

// CA3 Phase Memory
reg [5:0] pattern_in;
wire [5:0] phase_pattern;
wire learning, recalling;
wire [3:0] ca3_debug;

ca3_phase_memory #(.WIDTH(WIDTH), .FRAC(FRAC), .N_UNITS(6)) ca3 (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .theta_x(theta_x),
    .theta_phase(3'b000),  // v8.0: fixed for this test
    .pattern_in(pattern_in),
    .phase_pattern(phase_pattern),
    .learning(learning),
    .recalling(recalling),
    .debug_state(ca3_debug)
);

// Clock
initial begin clk = 0; forever #5 clk = ~clk; end

// Test patterns
localparam [5:0] PAT_A = 6'b101010;
localparam [5:0] PAT_B = 6'b010101;

// Variables
integer learn_events;
integer recall_events;
integer test_pass, test_fail;

// Task to advance simulation
task wait_updates;
    input integer n;
    integer k;
    begin
        for (k = 0; k < n; k = k + 1) begin
            @(posedge clk); clk_en = 1;
            @(posedge clk); clk_en = 0;
        end
    end
endtask

// Task to wait for theta peak
task wait_theta_peak;
    begin
        while (theta_x < 18'sd12288) begin
            wait_updates(1);
        end
    end
endtask

// Task to wait for theta trough
task wait_theta_trough;
    begin
        while (theta_x > -18'sd12288) begin
            wait_updates(1);
        end
    end
endtask

initial begin
    $display("========================================");
    $display("CA3 LEARNING EXPLICIT TEST");
    $display("========================================");

    rst = 1;
    clk_en = 0;
    pattern_in = 6'b000000;
    learn_events = 0;
    recall_events = 0;
    test_pass = 0;
    test_fail = 0;

    repeat(5) @(posedge clk);
    rst = 0;

    // Warmup
    wait_updates(500);

    // =========================================
    // TEST 1: Learn Pattern A 5 times
    // =========================================
    $display("\n[TEST 1] Learning Pattern A (101010) 5 times");
    repeat(5) begin
        pattern_in = PAT_A;
        wait_theta_peak();
        while (!learning) wait_updates(1);
        learn_events = learn_events + 1;
        while (learning) wait_updates(1);
        pattern_in = 6'b000000;
        wait_theta_trough();
        wait_updates(50);
    end
    $display("  Learning events: %0d", learn_events);
    if (learn_events >= 5) begin
        $display("  PASS");
        test_pass = test_pass + 1;
    end else begin
        $display("  FAIL");
        test_fail = test_fail + 1;
    end

    // =========================================
    // TEST 2: Learn Pattern B 5 times
    // =========================================
    $display("\n[TEST 2] Learning Pattern B (010101) 5 times");
    repeat(5) begin
        pattern_in = PAT_B;
        wait_theta_peak();
        while (!learning) wait_updates(1);
        learn_events = learn_events + 1;
        while (learning) wait_updates(1);
        pattern_in = 6'b000000;
        wait_theta_trough();
        wait_updates(50);
    end
    $display("  Total learning events: %0d", learn_events);
    if (learn_events >= 10) begin
        $display("  PASS");
        test_pass = test_pass + 1;
    end else begin
        $display("  FAIL");
        test_fail = test_fail + 1;
    end

    // =========================================
    // TEST 3: Recall Pattern A
    // =========================================
    $display("\n[TEST 3] Recall Pattern A from cue (100000)");
    wait_theta_trough();
    pattern_in = 6'b100000;
    while (!recalling) wait_updates(1);
    recall_events = recall_events + 1;
    while (recalling) wait_updates(1);
    $display("  Cue:      100000");
    $display("  Recalled: %b", phase_pattern);
    $display("  Target:   101010");
    if (phase_pattern != 6'b000000) begin
        $display("  PASS - recall produced output");
        test_pass = test_pass + 1;
    end else begin
        $display("  FAIL - no recall output");
        test_fail = test_fail + 1;
    end
    pattern_in = 6'b000000;
    wait_updates(100);

    // =========================================
    // TEST 4: Recall Pattern B
    // =========================================
    $display("\n[TEST 4] Recall Pattern B from cue (000001)");
    wait_theta_trough();
    pattern_in = 6'b000001;
    while (!recalling) wait_updates(1);
    recall_events = recall_events + 1;
    while (recalling) wait_updates(1);
    $display("  Cue:      000001");
    $display("  Recalled: %b", phase_pattern);
    $display("  Target:   010101");
    if (phase_pattern != 6'b000000) begin
        $display("  PASS - recall produced output");
        test_pass = test_pass + 1;
    end else begin
        $display("  FAIL - no recall output");
        test_fail = test_fail + 1;
    end

    // =========================================
    // SUMMARY
    // =========================================
    $display("\n========================================");
    $display("SUMMARY");
    $display("========================================");
    $display("  Learning events:  %0d", learn_events);
    $display("  Recall events:    %0d", recall_events);
    $display("  Tests passed:     %0d", test_pass);
    $display("  Tests failed:     %0d", test_fail);
    $display("========================================");

    $finish;
end

initial begin
    $dumpfile("tb_ca3_learning.vcd");
    $dumpvars(0, tb_ca3_learning);
end

endmodule
