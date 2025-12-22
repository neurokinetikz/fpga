//=============================================================================
// CA3 Learning Explicit Test
// Verifies Hebbian weight updates and pattern recall
//=============================================================================
`timescale 1ns / 1ps

module tb_ca3_learning;

parameter WIDTH = 18;
parameter FRAC = 14;

reg clk, rst, clk_en;

// Theta oscillator
wire signed [WIDTH-1:0] theta_x, theta_y, theta_amp;
localparam signed [WIDTH-1:0] MU_DT = 18'sd4;      // 4 kHz update rate
localparam signed [WIDTH-1:0] OMEGA_THETA = 18'sd152;  // 5.89 Hz at 4 kHz

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
    .pattern_in(pattern_in),
    .phase_pattern(phase_pattern),
    .learning(learning),
    .recalling(recalling),
    .debug_state(ca3_debug)
);

// Clock
initial begin clk = 0; forever #5 clk = ~clk; end

// Test patterns
localparam [5:0] PAT_A = 6'b101010;  // Bits 0,2,4 active
localparam [5:0] PAT_B = 6'b010101;  // Bits 1,3,5 active

integer i, j;
integer learn_events;
integer recall_events;
integer matches;

// Access weights for display (hierarchical reference)
// Note: This works in simulation but not synthesis

task show_weights;
    begin
        $display("  Weight Matrix:");
        $display("       0    1    2    3    4    5");
        for (i = 0; i < 6; i = i + 1) begin
            $write("  %0d: ", i);
            for (j = 0; j < 6; j = j + 1) begin
                $write("%4d ", $signed(ca3.weights[i][j]));
            end
            $display("");
        end
    end
endtask

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

task wait_theta_peak;
    begin
        while (theta_x < 18'sd12288) wait_updates(1);
    end
endtask

task wait_theta_trough;
    begin
        while (theta_x > -18'sd12288) wait_updates(1);
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

    repeat(5) @(posedge clk);
    rst = 0;

    // Warmup
    wait_updates(500);

    // =========================================
    // TEST 1: Initial weights should be zero
    // =========================================
    $display("\n[TEST 1] Initial weights (should be all zeros)");
    show_weights();

    // =========================================
    // TEST 2: Learn Pattern A once
    // =========================================
    $display("\n[TEST 2] Learning Pattern A (101010) - single exposure");
    pattern_in = PAT_A;
    wait_theta_peak();
    $display("  Theta peak reached: %0d", theta_x);

    // Wait for learning to trigger
    while (!learning) wait_updates(1);
    $display("  Learning STARTED");
    learn_events = learn_events + 1;

    // Wait for learning to complete
    while (learning) wait_updates(1);
    $display("  Learning COMPLETED");

    pattern_in = 6'b000000;
    wait_updates(50);

    $display("  Weights after 1x Pattern A:");
    show_weights();

    // =========================================
    // TEST 3: Learn Pattern A 4 more times
    // =========================================
    $display("\n[TEST 3] Learning Pattern A 4 more times (total 5x)");
    for (i = 0; i < 4; i = i + 1) begin
        pattern_in = PAT_A;
        wait_theta_peak();
        while (!learning) wait_updates(1);
        learn_events = learn_events + 1;
        while (learning) wait_updates(1);
        pattern_in = 6'b000000;
        wait_theta_trough();
        wait_updates(50);
    end

    $display("  Weights after 5x Pattern A:");
    show_weights();
    $display("  Expected: w[0][2], w[0][4], w[2][4] = 20 (5 x LEARN_RATE=2 x 2 for symmetry)");

    // =========================================
    // TEST 4: Learn Pattern B 5 times
    // =========================================
    $display("\n[TEST 4] Learning Pattern B (010101) 5 times");
    for (i = 0; i < 5; i = i + 1) begin
        pattern_in = PAT_B;
        wait_theta_peak();
        while (!learning) wait_updates(1);
        learn_events = learn_events + 1;
        while (learning) wait_updates(1);
        pattern_in = 6'b000000;
        wait_theta_trough();
        wait_updates(50);
    end

    $display("  Weights after 5x Pattern B:");
    show_weights();

    // =========================================
    // TEST 5: Recall Pattern A from partial cue
    // =========================================
    $display("\n[TEST 5] Recall Pattern A from cue (100000)");
    wait_theta_trough();
    pattern_in = 6'b100000;  // Only bit 0

    while (!recalling) wait_updates(1);
    $display("  Recall STARTED");
    recall_events = recall_events + 1;

    while (recalling) wait_updates(1);
    $display("  Recall COMPLETED");
    $display("  Cue:      100000");
    $display("  Recalled: %b", phase_pattern);
    $display("  Target:   101010");

    // Count matches
    matches = 0;
    for (i = 0; i < 6; i = i + 1) begin
        if (phase_pattern[i] == PAT_A[i]) matches = matches + 1;
    end
    $display("  Match: %0d/6 bits", matches);

    pattern_in = 6'b000000;
    wait_updates(100);

    // =========================================
    // TEST 6: Recall Pattern B from partial cue
    // =========================================
    $display("\n[TEST 6] Recall Pattern B from cue (000001)");
    wait_theta_trough();
    pattern_in = 6'b000001;  // Only bit 0 (but that's part of B!)

    while (!recalling) wait_updates(1);
    recall_events = recall_events + 1;
    while (recalling) wait_updates(1);

    $display("  Cue:      000001");
    $display("  Recalled: %b", phase_pattern);
    $display("  Target:   010101");

    matches = 0;
    for (i = 0; i < 6; i = i + 1) begin
        if (phase_pattern[i] == PAT_B[i]) matches = matches + 1;
    end
    $display("  Match: %0d/6 bits", matches);

    // =========================================
    // SUMMARY
    // =========================================
    $display("\n========================================");
    $display("SUMMARY");
    $display("========================================");
    $display("  Learning events:  %0d", learn_events);
    $display("  Recall events:    %0d", recall_events);
    $display("  Final weight matrix:");
    show_weights();
    $display("========================================");

    $finish;
end

initial begin
    $dumpfile("tb_ca3_learning.vcd");
    $dumpvars(0, tb_ca3_learning);
end

endmodule
