//=============================================================================
// Testbench: SR Frequency Drift Generator
//
// Tests the realistic Schumann Resonance frequency drift model:
// - Bounded random walk within observed ranges
// - Hours-scale drift pattern (accelerated in FAST_SIM)
// - Proper initialization and reset behavior
// - Frequency stays within specified bounds
//=============================================================================
`timescale 1ns / 1ps

module tb_sr_frequency_drift;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter NUM_HARMONICS = 5;
parameter FAST_SIM = 1;  // Use fast simulation mode

reg clk;
reg rst;
reg clk_en;

wire signed [NUM_HARMONICS*WIDTH-1:0] omega_dt_packed;
wire signed [NUM_HARMONICS*WIDTH-1:0] drift_offset_packed;

// Unpack for analysis
wire signed [WIDTH-1:0] omega_dt [0:NUM_HARMONICS-1];
wire signed [WIDTH-1:0] drift_offset [0:NUM_HARMONICS-1];

genvar g;
generate
    for (g = 0; g < NUM_HARMONICS; g = g + 1) begin : unpack
        assign omega_dt[g] = omega_dt_packed[g*WIDTH +: WIDTH];
        assign drift_offset[g] = drift_offset_packed[g*WIDTH +: WIDTH];
    end
endgenerate

// DUT instantiation
sr_frequency_drift #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_HARMONICS(NUM_HARMONICS),
    .FAST_SIM(FAST_SIM)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .omega_dt_packed(omega_dt_packed),
    .drift_offset_packed(drift_offset_packed)
);

// Clock generation (125 MHz)
always #4 clk = ~clk;

// Test counters
integer tests_passed;
integer tests_failed;
integer i, cycle;

// Expected center frequencies (v12.2: f0 updated to 7.75 Hz)
localparam signed [WIDTH-1:0] OMEGA_CENTER_0 = 18'sd199;   // f0: 7.75 Hz (v12.2)
localparam signed [WIDTH-1:0] OMEGA_CENTER_1 = 18'sd354;   // f1: 13.75 Hz
localparam signed [WIDTH-1:0] OMEGA_CENTER_2 = 18'sd514;   // f2: 20 Hz
localparam signed [WIDTH-1:0] OMEGA_CENTER_3 = 18'sd643;   // f3: 25 Hz
localparam signed [WIDTH-1:0] OMEGA_CENTER_4 = 18'sd823;   // f4: 32 Hz

// Expected drift ranges (v12.2: tightened for impedance matching)
localparam signed [WIDTH-1:0] DRIFT_MAX_0 = 18'sd13;    // f0: ±0.5 Hz (v12.2: was ±0.9)
localparam signed [WIDTH-1:0] DRIFT_MAX_1 = 18'sd21;    // f1: ±0.8 Hz (v12.2: was ±1.1)
localparam signed [WIDTH-1:0] DRIFT_MAX_2 = 18'sd26;    // f2: ±1.0 Hz (v12.2: was ±1.5)
localparam signed [WIDTH-1:0] DRIFT_MAX_3 = 18'sd39;    // f3: ±1.5 Hz (v12.2: was ±2.25)
localparam signed [WIDTH-1:0] DRIFT_MAX_4 = 18'sd51;    // f4: ±2.0 Hz (v12.2: was ±3.0)

// Track min/max drift for each harmonic
reg signed [WIDTH-1:0] min_drift [0:NUM_HARMONICS-1];
reg signed [WIDTH-1:0] max_drift [0:NUM_HARMONICS-1];

// Helper task for test reporting
task report_test;
    input [256*8-1:0] test_name;
    input condition;
    begin
        if (condition) begin
            $display("[PASS] %s", test_name);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] %s", test_name);
            tests_failed = tests_failed + 1;
        end
    end
endtask

initial begin
    $display("========================================");
    $display("SR Frequency Drift Testbench Starting");
    $display("========================================");

    clk = 0;
    rst = 1;
    clk_en = 0;
    tests_passed = 0;
    tests_failed = 0;

    // Initialize tracking
    for (i = 0; i < NUM_HARMONICS; i = i + 1) begin
        min_drift[i] = 18'sd32767;
        max_drift[i] = -18'sd32768;
    end

    // Release reset
    repeat(10) @(posedge clk);
    rst = 0;
    repeat(10) @(posedge clk);

    //=========================================================================
    // TEST 1: Initial values after reset
    //=========================================================================
    $display("\n--- TEST 1: Initial values after reset ---");

    report_test("f0 starts at center (196)", omega_dt[0] == OMEGA_CENTER_0);
    report_test("f1 starts at center (354)", omega_dt[1] == OMEGA_CENTER_1);
    report_test("f2 starts at center (514)", omega_dt[2] == OMEGA_CENTER_2);
    report_test("f3 starts at center (643)", omega_dt[3] == OMEGA_CENTER_3);
    report_test("f4 starts at center (823)", omega_dt[4] == OMEGA_CENTER_4);

    report_test("f0 offset starts at 0", drift_offset[0] == 18'sd0);
    report_test("f1 offset starts at 0", drift_offset[1] == 18'sd0);
    report_test("f2 offset starts at 0", drift_offset[2] == 18'sd0);
    report_test("f3 offset starts at 0", drift_offset[3] == 18'sd0);
    report_test("f4 offset starts at 0", drift_offset[4] == 18'sd0);

    //=========================================================================
    // TEST 2: Run for many cycles, verify drift stays in bounds
    //=========================================================================
    $display("\n--- TEST 2: Drift bounds verification ---");

    // Run for many update periods
    for (cycle = 0; cycle < 10000; cycle = cycle + 1) begin
        @(posedge clk);
        clk_en = 1;
        @(posedge clk);
        clk_en = 0;
        repeat(8) @(posedge clk);  // Some idle time

        // Track min/max drift
        for (i = 0; i < NUM_HARMONICS; i = i + 1) begin
            if (drift_offset[i] < min_drift[i]) min_drift[i] = drift_offset[i];
            if (drift_offset[i] > max_drift[i]) max_drift[i] = drift_offset[i];
        end
    end

    // Verify bounds
    $display("Harmonic 0: drift range [%0d, %0d], max allowed ±%0d", min_drift[0], max_drift[0], DRIFT_MAX_0);
    $display("Harmonic 1: drift range [%0d, %0d], max allowed ±%0d", min_drift[1], max_drift[1], DRIFT_MAX_1);
    $display("Harmonic 2: drift range [%0d, %0d], max allowed ±%0d", min_drift[2], max_drift[2], DRIFT_MAX_2);
    $display("Harmonic 3: drift range [%0d, %0d], max allowed ±%0d", min_drift[3], max_drift[3], DRIFT_MAX_3);
    $display("Harmonic 4: drift range [%0d, %0d], max allowed ±%0d", min_drift[4], max_drift[4], DRIFT_MAX_4);

    report_test("f0 drift stays within ±23",
                min_drift[0] >= -DRIFT_MAX_0 && max_drift[0] <= DRIFT_MAX_0);
    report_test("f1 drift stays within ±28",
                min_drift[1] >= -DRIFT_MAX_1 && max_drift[1] <= DRIFT_MAX_1);
    report_test("f2 drift stays within ±39",
                min_drift[2] >= -DRIFT_MAX_2 && max_drift[2] <= DRIFT_MAX_2);
    report_test("f3 drift stays within ±58",
                min_drift[3] >= -DRIFT_MAX_3 && max_drift[3] <= DRIFT_MAX_3);
    report_test("f4 drift stays within ±77",
                min_drift[4] >= -DRIFT_MAX_4 && max_drift[4] <= DRIFT_MAX_4);

    //=========================================================================
    // TEST 3: Verify omega_dt = center + offset
    //=========================================================================
    $display("\n--- TEST 3: omega_dt = center + offset ---");

    report_test("f0: omega_dt = center + offset",
                omega_dt[0] == OMEGA_CENTER_0 + drift_offset[0]);
    report_test("f1: omega_dt = center + offset",
                omega_dt[1] == OMEGA_CENTER_1 + drift_offset[1]);
    report_test("f2: omega_dt = center + offset",
                omega_dt[2] == OMEGA_CENTER_2 + drift_offset[2]);
    report_test("f3: omega_dt = center + offset",
                omega_dt[3] == OMEGA_CENTER_3 + drift_offset[3]);
    report_test("f4: omega_dt = center + offset",
                omega_dt[4] == OMEGA_CENTER_4 + drift_offset[4]);

    //=========================================================================
    // TEST 4: Verify drift actually changes (not stuck)
    //=========================================================================
    $display("\n--- TEST 4: Drift is actually changing ---");

    report_test("f0 drift explored range > 2",
                (max_drift[0] - min_drift[0]) > 2);
    report_test("f1 drift explored range > 2",
                (max_drift[1] - min_drift[1]) > 2);
    report_test("f2 drift explored range > 2",
                (max_drift[2] - min_drift[2]) > 2);
    report_test("f3 drift explored range > 2",
                (max_drift[3] - min_drift[3]) > 2);
    report_test("f4 drift explored range > 2",
                (max_drift[4] - min_drift[4]) > 2);

    //=========================================================================
    // TEST 5: Reset behavior
    //=========================================================================
    $display("\n--- TEST 5: Reset clears drift ---");

    rst = 1;
    repeat(5) @(posedge clk);
    rst = 0;
    repeat(5) @(posedge clk);

    report_test("f0 offset resets to 0", drift_offset[0] == 18'sd0);
    report_test("f1 offset resets to 0", drift_offset[1] == 18'sd0);
    report_test("f2 offset resets to 0", drift_offset[2] == 18'sd0);
    report_test("f3 offset resets to 0", drift_offset[3] == 18'sd0);
    report_test("f4 offset resets to 0", drift_offset[4] == 18'sd0);

    //=========================================================================
    // Final Summary
    //=========================================================================
    $display("\n========================================");
    $display("SR Frequency Drift Tests Complete");
    $display("Passed: %0d / %0d", tests_passed, tests_passed + tests_failed);
    $display("========================================\n");

    if (tests_failed > 0) begin
        $display("SOME TESTS FAILED!");
        $finish(1);
    end else begin
        $display("ALL TESTS PASSED!");
        $finish(0);
    end
end

endmodule
