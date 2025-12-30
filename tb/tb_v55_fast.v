//=============================================================================
// v5.5 Fast Testbench - Direct CA3 and Column Testing
// Bypasses clock divider for faster simulation
//=============================================================================
`timescale 1ns / 1ps

module tb_v55_fast;

parameter WIDTH = 18;
parameter FRAC = 14;

reg clk, rst, clk_en;

// Theta oscillator (simulates thalamus)
wire signed [WIDTH-1:0] theta_x, theta_y, theta_amp;
localparam signed [WIDTH-1:0] MU_DT = 18'sd4;      // 4 kHz update rate
localparam signed [WIDTH-1:0] OMEGA_THETA = 18'sd157;  // 6.09 Hz at 4 kHz (v12.2: φ^-0.5 × 7.75)

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) theta_osc (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(MU_DT), .omega_dt(OMEGA_THETA), .input_x(18'sd0),
    .x(theta_x), .y(theta_y), .amplitude(theta_amp)
);

// CA3 Phase Memory (v5.3 with decay)
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

// Clock: 10ns period (100 MHz equivalent, but updates at every clk_en)
initial begin clk = 0; forever #5 clk = ~clk; end

// Test patterns
localparam [5:0] PAT_A = 6'b101010;
localparam [5:0] PAT_B = 6'b010101;
localparam [5:0] CUE_A = 6'b100000;
localparam [5:0] CUE_B = 6'b000100;

// Variables
integer update_count;
integer test_pass, test_fail;
integer ii, jj;
integer matches_a, matches_b;
integer peaks;
reg prev_high;

// Task to advance simulation by n updates
task wait_updates;
    input integer n;
    integer k;
    begin
        for (k = 0; k < n; k = k + 1) begin
            @(posedge clk); clk_en = 1;
            @(posedge clk); clk_en = 0;
            update_count = update_count + 1;
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
    $display("V5.5 INTEGRATED PHASE ENCODING TEST");
    $display("========================================");

    rst = 1;
    clk_en = 0;
    pattern_in = 6'b000000;
    update_count = 0;
    test_pass = 0;
    test_fail = 0;
    peaks = 0;
    prev_high = 0;

    repeat(5) @(posedge clk);
    rst = 0;

    // TEST 1: Theta oscillation (4000 updates = 1 second at 4 kHz)
    $display("\n[TEST 1] Theta oscillation");
    wait_updates(1000);  // Warmup

    peaks = 0;
    prev_high = 0;

    for (ii = 0; ii < 4000; ii = ii + 1) begin
        @(posedge clk); clk_en = 1;
        @(posedge clk); clk_en = 0;

        if (theta_x > 18'sd12000 && !prev_high) begin
            peaks = peaks + 1;
            prev_high = 1;
        end
        if (theta_x < 18'sd8000) prev_high = 0;
    end

    $display("    Peaks in 1s: %0d (expected 5-6)", peaks);
    if (peaks >= 4 && peaks <= 8) begin
        $display("    PASS");
        test_pass = test_pass + 1;
    end else begin
        $display("    FAIL");
        test_fail = test_fail + 1;
    end

    // TEST 2: Learning at theta peak
    $display("\n[TEST 2] Learning at theta peak");
    pattern_in = PAT_A;
    wait_theta_peak();
    wait_updates(1);  // Give state machine time to process
    $display("    Theta peak: %0d", theta_x);
    if (learning) begin
        $display("    Learning triggered - PASS");
        test_pass = test_pass + 1;
    end else begin
        $display("    Learning NOT triggered - FAIL");
        test_fail = test_fail + 1;
    end
    wait_updates(50);  // Let learning complete
    $display("    Learning completed");
    pattern_in = 6'b000000;

    // TEST 3: Recall at theta trough
    $display("\n[TEST 3] Recall at theta trough");
    wait_theta_trough();
    $display("    Theta trough: %0d", theta_x);
    pattern_in = CUE_A;
    wait_updates(10);
    if (recalling) begin
        $display("    Recall triggered - PASS");
        test_pass = test_pass + 1;
    end else begin
        $display("    Recall NOT triggered - FAIL");
        test_fail = test_fail + 1;
    end
    wait_updates(20);
    $display("    Recall completed: %b", phase_pattern);
    pattern_in = 6'b000000;

    // TEST 4: Training patterns
    $display("\n[TEST 4] Training patterns");

    // Train Pattern A 5 times
    for (ii = 0; ii < 5; ii = ii + 1) begin
        pattern_in = PAT_A;
        wait_theta_peak();
        wait_updates(50);
        pattern_in = 6'b000000;
        wait_theta_trough();
        wait_updates(50);
    end
    $display("    Pattern A trained 5x");

    // Train Pattern B 5 times
    for (ii = 0; ii < 5; ii = ii + 1) begin
        pattern_in = PAT_B;
        wait_theta_peak();
        wait_updates(50);
        pattern_in = 6'b000000;
        wait_theta_trough();
        wait_updates(50);
    end
    $display("    Pattern B trained 5x");
    test_pass = test_pass + 1;

    // TEST 5: Recall accuracy
    $display("\n[TEST 5] Recall accuracy");

    // Recall Pattern A
    wait_theta_trough();
    pattern_in = CUE_A;
    wait_updates(20);
    $display("    A: Cue %b -> %b (target %b)", CUE_A, phase_pattern, PAT_A);
    matches_a = 0;
    for (ii = 0; ii < 6; ii = ii + 1) begin
        if (phase_pattern[ii] == PAT_A[ii]) matches_a = matches_a + 1;
    end
    $display("    Match: %0d/6", matches_a);
    if (matches_a >= 4) begin
        $display("    PASS");
        test_pass = test_pass + 1;
    end else begin
        $display("    FAIL");
        test_fail = test_fail + 1;
    end
    pattern_in = 6'b000000;
    wait_updates(100);

    // Recall Pattern B
    wait_theta_trough();
    pattern_in = CUE_B;
    wait_updates(20);
    $display("    B: Cue %b -> %b (target %b)", CUE_B, phase_pattern, PAT_B);
    matches_b = 0;
    for (ii = 0; ii < 6; ii = ii + 1) begin
        if (phase_pattern[ii] == PAT_B[ii]) matches_b = matches_b + 1;
    end
    $display("    Match: %0d/6", matches_b);
    if (matches_b >= 4) begin
        $display("    PASS");
        test_pass = test_pass + 1;
    end else begin
        $display("    FAIL");
        test_fail = test_fail + 1;
    end

    $display("\n========================================");
    $display("SUMMARY: %0d passed, %0d failed", test_pass, test_fail);
    $display("========================================");

    $finish;
end

// Optional: Waveform dump
initial begin
    $dumpfile("tb_v55_fast.vcd");
    $dumpvars(0, tb_v55_fast);
end

endmodule
