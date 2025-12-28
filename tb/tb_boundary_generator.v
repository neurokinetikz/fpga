//=============================================================================
// Testbench: Boundary Generator
//
// Tests:
// 1. Aligned oscillators → strong boundary
// 2. Anti-phase oscillators → weak/no boundary
// 3. Mixing strength = 0 → no output
// 4. Mixing strength = 1.0 → full output
// 5. Equal amplitude parents → boundary amp = parent amp
// 6. Different amplitude parents → geometric mean amplitude
// 7. Phase 90° apart → boundary at 45°
//
// Usage:
//   iverilog -o tb_boundary_generator.vvp src/boundary_generator.v \
//       tb/tb_boundary_generator.v && vvp tb_boundary_generator.vvp
//=============================================================================
`timescale 1ns / 1ps

module tb_boundary_generator;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 10;

reg clk;
reg rst;
reg clk_en;

// Oscillator inputs
reg signed [WIDTH-1:0] osc_low_x, osc_low_y;
reg signed [WIDTH-1:0] osc_high_x, osc_high_y;
reg signed [WIDTH-1:0] mixing_strength;

// Outputs
wire signed [WIDTH-1:0] boundary_x;
wire signed [WIDTH-1:0] boundary_y;
wire signed [WIDTH-1:0] boundary_amplitude;

// Test counters
integer tests_passed;
integer tests_failed;

// DUT
boundary_generator #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .osc_low_x(osc_low_x),
    .osc_low_y(osc_low_y),
    .osc_high_x(osc_high_x),
    .osc_high_y(osc_high_y),
    .mixing_strength(mixing_strength),
    .boundary_x(boundary_x),
    .boundary_y(boundary_y),
    .boundary_amplitude(boundary_amplitude)
);

// Clock generation
always #(CLK_PERIOD/2) clk = ~clk;

// Q14 constants
localparam signed [WIDTH-1:0] ONE = 18'sd16384;
localparam signed [WIDTH-1:0] HALF = 18'sd8192;
localparam signed [WIDTH-1:0] SQRT2_HALF = 18'sd11585;  // 0.707

// Helper task to wait for computation
task wait_compute;
    begin
        repeat(5) @(posedge clk);
        clk_en = 1;
        @(posedge clk);
        clk_en = 0;
        repeat(3) @(posedge clk);
    end
endtask

// Helper to display value
function real to_float;
    input signed [WIDTH-1:0] val;
    begin
        to_float = val / 16384.0;
    end
endfunction

initial begin
    $display("==============================================");
    $display("Boundary Generator Testbench");
    $display("==============================================");

    // Initialize
    clk = 0;
    rst = 1;
    clk_en = 0;
    tests_passed = 0;
    tests_failed = 0;

    osc_low_x = 0; osc_low_y = 0;
    osc_high_x = 0; osc_high_y = 0;
    mixing_strength = 0;

    // Release reset
    repeat(5) @(posedge clk);
    rst = 0;
    repeat(5) @(posedge clk);

    //=========================================================================
    // TEST 1: Aligned oscillators (both at phase 0, equal amplitude)
    // Expected: Strong boundary with amplitude ≈ parent amplitude
    //=========================================================================
    $display("\n[TEST 1] Aligned oscillators (both at phase 0)");
    osc_low_x = ONE;  osc_low_y = 0;   // Phase 0, amp 1.0
    osc_high_x = ONE; osc_high_y = 0;  // Phase 0, amp 1.0
    mixing_strength = ONE;              // Full mixing

    wait_compute;

    $display("  boundary_x = %0d (%.3f)", boundary_x, to_float(boundary_x));
    $display("  boundary_y = %0d (%.3f)", boundary_y, to_float(boundary_y));
    $display("  amplitude = %0d (%.3f)", boundary_amplitude, to_float(boundary_amplitude));

    // Boundary should be strong (amplitude near 1.0)
    if (boundary_amplitude > 18'sd12288) begin  // > 0.75
        $display("  PASS - Strong boundary for aligned oscillators");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected strong boundary (amp > 0.75)");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 2: Anti-phase oscillators (180° apart)
    // Expected: Weak/no boundary (phases cancel)
    //=========================================================================
    $display("\n[TEST 2] Anti-phase oscillators (180 apart)");
    osc_low_x = ONE;  osc_low_y = 0;    // Phase 0
    osc_high_x = -ONE; osc_high_y = 0;  // Phase π
    mixing_strength = ONE;

    wait_compute;

    $display("  boundary_x = %0d (%.3f)", boundary_x, to_float(boundary_x));
    $display("  amplitude = %0d (%.3f)", boundary_amplitude, to_float(boundary_amplitude));

    // Boundary should be very weak (phases cancel)
    if (boundary_amplitude < 18'sd1638) begin  // < 0.1
        $display("  PASS - Weak boundary for anti-phase");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected weak boundary (amp < 0.1)");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 3: Mixing strength = 0
    // Expected: No boundary output
    //=========================================================================
    $display("\n[TEST 3] Mixing strength = 0");
    osc_low_x = ONE;  osc_low_y = 0;
    osc_high_x = ONE; osc_high_y = 0;
    mixing_strength = 0;  // No mixing

    wait_compute;

    $display("  amplitude = %0d (%.3f)", boundary_amplitude, to_float(boundary_amplitude));

    if (boundary_amplitude < 18'sd164) begin  // < 0.01
        $display("  PASS - No boundary when mixing=0");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected no boundary when mixing=0");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 4: Mixing strength = 0.5
    // Expected: Half amplitude
    //=========================================================================
    $display("\n[TEST 4] Mixing strength = 0.5");
    osc_low_x = ONE;  osc_low_y = 0;
    osc_high_x = ONE; osc_high_y = 0;
    mixing_strength = HALF;  // 50% mixing

    wait_compute;

    $display("  amplitude = %0d (%.3f)", boundary_amplitude, to_float(boundary_amplitude));

    if (boundary_amplitude > 18'sd4096 && boundary_amplitude < 18'sd12288) begin  // 0.25-0.75
        $display("  PASS - Partial boundary with mixing=0.5");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected intermediate amplitude");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 5: Different amplitudes (geometric mean)
    // Parent amps: 1.0 and 0.25 → geometric mean = 0.5
    //=========================================================================
    $display("\n[TEST 5] Different amplitudes (geometric mean)");
    osc_low_x = ONE;           osc_low_y = 0;   // Amp 1.0
    osc_high_x = ONE >>> 2;    osc_high_y = 0;  // Amp 0.25
    mixing_strength = ONE;

    wait_compute;

    $display("  amplitude = %0d (%.3f)", boundary_amplitude, to_float(boundary_amplitude));

    // Geometric mean of 1.0 and 0.25 = sqrt(0.25) = 0.5
    if (boundary_amplitude > 18'sd6554 && boundary_amplitude < 18'sd10923) begin  // 0.4-0.67
        $display("  PASS - Amplitude follows geometric mean");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected geometric mean (~0.5)");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 6: Orthogonal phases (90° apart)
    // Phase 0 and phase π/2 → boundary at π/4
    //=========================================================================
    $display("\n[TEST 6] Orthogonal phases (90 apart)");
    osc_low_x = ONE;  osc_low_y = 0;   // Phase 0: (1, 0)
    osc_high_x = 0;   osc_high_y = ONE; // Phase π/2: (0, 1)
    mixing_strength = ONE;

    wait_compute;

    $display("  boundary_x = %0d (%.3f)", boundary_x, to_float(boundary_x));
    $display("  boundary_y = %0d (%.3f)", boundary_y, to_float(boundary_y));
    $display("  amplitude = %0d (%.3f)", boundary_amplitude, to_float(boundary_amplitude));

    // Boundary should be at ~45°: x ≈ y, both positive
    // Amplitude should be ~0.707 (cos(45°)) of max
    if (boundary_x > 18'sd4096 && boundary_y > 18'sd4096 &&
        boundary_amplitude > 18'sd8192) begin
        $display("  PASS - Boundary at 45 degrees");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected boundary at 45 degrees");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 7: Full range oscillation (simulate rotating phases)
    // Both oscillators at same phase → boundary follows
    //=========================================================================
    $display("\n[TEST 7] Phase tracking (both at π/4)");
    osc_low_x = SQRT2_HALF;  osc_low_y = SQRT2_HALF;   // Phase π/4
    osc_high_x = SQRT2_HALF; osc_high_y = SQRT2_HALF;  // Phase π/4
    mixing_strength = ONE;

    wait_compute;

    $display("  boundary_x = %0d (%.3f)", boundary_x, to_float(boundary_x));
    $display("  boundary_y = %0d (%.3f)", boundary_y, to_float(boundary_y));
    $display("  amplitude = %0d (%.3f)", boundary_amplitude, to_float(boundary_amplitude));

    // Boundary should also be at π/4
    if (boundary_x > 18'sd8192 && boundary_y > 18'sd8192 &&
        boundary_amplitude > 18'sd12288) begin
        $display("  PASS - Boundary tracks aligned phase");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected boundary at same phase");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n==============================================");
    $display("SUMMARY: %0d passed, %0d failed", tests_passed, tests_failed);
    $display("==============================================");

    if (tests_failed == 0)
        $display("ALL TESTS PASSED!");
    else
        $display("SOME TESTS FAILED");

    $finish;
end

endmodule
