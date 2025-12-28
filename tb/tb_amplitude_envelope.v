//=============================================================================
// Testbench: Amplitude Envelope Generator
//
// Tests the Ornstein-Uhlenbeck process for slow amplitude modulation:
// 1. Output stays within bounds [0.5, 1.5] in Q14
// 2. Mean-reversion toward 1.0
// 3. Slow timescale variation (tau ~3 seconds)
// 4. Different seeds produce different trajectories
//
// Usage:
//   iverilog -o tb_amplitude_envelope.vvp -DFAST_SIM \
//       src/amplitude_envelope_generator.v tb/tb_amplitude_envelope.v && \
//   vvp tb_amplitude_envelope.vvp
//=============================================================================
`timescale 1ns / 1ps

module tb_amplitude_envelope;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 8;  // 125 MHz

reg clk;
reg rst;
reg clk_en;
reg [15:0] seed;
reg signed [WIDTH-1:0] tau_inv;

wire signed [WIDTH-1:0] envelope;

// DUT instantiation
amplitude_envelope_generator #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .seed(seed),
    .tau_inv(tau_inv),
    .envelope(envelope)
);

// Clock generation
always #(CLK_PERIOD/2) clk = ~clk;

// Q14 constants
localparam signed [WIDTH-1:0] Q14_ONE = 18'sd16384;    // 1.0
localparam signed [WIDTH-1:0] Q14_HALF = 18'sd8192;    // 0.5
localparam signed [WIDTH-1:0] Q14_1P5 = 18'sd24576;    // 1.5

// Test tracking
integer test_count = 0;
integer pass_count = 0;
integer fail_count = 0;
integer i;

// Tracking for statistics
reg signed [WIDTH-1:0] min_envelope;
reg signed [WIDTH-1:0] max_envelope;
reg signed [31:0] sum_envelope;
integer sample_count;

// 4kHz clock enable counter
reg [3:0] clk_div;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_div <= 0;
        clk_en <= 0;
    end else begin
        clk_div <= clk_div + 1;
        clk_en <= (clk_div == 4'd9);  // Every 10 cycles
    end
end

// Test task
task check_test;
    input [255:0] name;
    input condition;
    begin
        test_count = test_count + 1;
        if (condition) begin
            pass_count = pass_count + 1;
            $display("  PASS: %s", name);
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: %s", name);
        end
    end
endtask

// Helper task: run N clock enable cycles and track stats
task run_and_track;
    input integer n;
    integer j;
    begin
        for (j = 0; j < n; j = j + 1) begin
            @(posedge clk);
            while (!clk_en) @(posedge clk);

            // Track statistics
            if (envelope < min_envelope) min_envelope = envelope;
            if (envelope > max_envelope) max_envelope = envelope;
            sum_envelope = sum_envelope + envelope;
            sample_count = sample_count + 1;
        end
    end
endtask

initial begin
    $display("=============================================================================");
    $display("Amplitude Envelope Generator Testbench");
    $display("=============================================================================");

    // Initialize
    clk = 0;
    rst = 1;
    seed = 16'hACE1;
    tau_inv = 18'sd1;  // 3 second time constant
    min_envelope = 18'sd131071;  // Max positive
    max_envelope = -18'sd131072; // Max negative
    sum_envelope = 0;
    sample_count = 0;

    // Release reset
    repeat(100) @(posedge clk);
    rst = 0;

    //=========================================================================
    // TEST 1: Initial value after reset (check immediately, before any clk_en)
    //=========================================================================
    $display("\n--- Test 1: Initial Value ---");
    @(posedge clk);  // One cycle to propagate reset release
    check_test("Envelope starts at 1.0 (16384)", envelope == Q14_ONE);

    // Now wait for some updates
    repeat(50) @(posedge clk);

    //=========================================================================
    // TEST 2: Run for many cycles, check bounds
    //=========================================================================
    $display("\n--- Test 2: Bounds Check (10000 samples) ---");
    run_and_track(10000);

    $display("  Min envelope: %0d (expect >= 8192)", min_envelope);
    $display("  Max envelope: %0d (expect <= 24576)", max_envelope);
    $display("  Mean envelope: %0d (expect ~16384)", sum_envelope / sample_count);

    check_test("Envelope stays >= 0.5 (8192)", min_envelope >= Q14_HALF);
    check_test("Envelope stays <= 1.5 (24576)", max_envelope <= Q14_1P5);

    //=========================================================================
    // TEST 3: Mean-reversion check (mean should be near 1.0)
    //=========================================================================
    $display("\n--- Test 3: Mean-Reversion ---");
    begin : mean_check
        reg signed [31:0] mean;
        mean = sum_envelope / sample_count;
        // Mean should be within ±0.2 of 1.0 (13107 to 19661 in Q14)
        check_test("Mean near 1.0 (within ±0.2)",
                   mean >= 18'sd13107 && mean <= 18'sd19661);
    end

    //=========================================================================
    // TEST 4: Envelope is actually varying (not stuck)
    //=========================================================================
    $display("\n--- Test 4: Variation Check ---");
    check_test("Envelope varies (range > 1000)",
               (max_envelope - min_envelope) > 18'sd1000);

    //=========================================================================
    // TEST 5: Different seeds produce different trajectories
    //=========================================================================
    $display("\n--- Test 5: Seed Uniqueness ---");
    begin : seed_test
        reg signed [WIDTH-1:0] env_seed1, env_seed2;

        // Reset with seed 1
        rst = 1;
        seed = 16'hAAAA;
        repeat(50) @(posedge clk);
        rst = 0;
        repeat(100) @(posedge clk);
        while (!clk_en) @(posedge clk);
        run_and_track(1000);
        env_seed1 = envelope;

        // Reset with seed 2
        rst = 1;
        seed = 16'h5555;
        repeat(50) @(posedge clk);
        rst = 0;
        repeat(100) @(posedge clk);
        while (!clk_en) @(posedge clk);
        run_and_track(1000);
        env_seed2 = envelope;

        $display("  Seed 0xAAAA final: %0d", env_seed1);
        $display("  Seed 0x5555 final: %0d", env_seed2);
        check_test("Different seeds → different trajectories", env_seed1 != env_seed2);
    end

    //=========================================================================
    // TEST 6: Reset clears to initial value
    //=========================================================================
    $display("\n--- Test 6: Reset Behavior ---");
    rst = 1;
    repeat(20) @(posedge clk);
    rst = 0;
    repeat(10) @(posedge clk);
    check_test("Reset returns envelope to 1.0", envelope == Q14_ONE);

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n=============================================================================");
    $display("Test Summary: %0d/%0d passed", pass_count, test_count);
    if (fail_count == 0) begin
        $display("ALL TESTS PASSED");
    end else begin
        $display("FAILURES: %0d", fail_count);
    end
    $display("=============================================================================");

    $finish;
end

endmodule
