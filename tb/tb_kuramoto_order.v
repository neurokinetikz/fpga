//=============================================================================
// Testbench: Kuramoto Order Parameter
//
// Tests:
// 1. Perfectly synchronized oscillators (R ≈ 1.0)
// 2. Random/desynchronized phases (R < 0.5)
// 3. Partial synchronization (R ≈ 0.5-0.7)
// 4. Anti-phase pairs (R ≈ 0)
// 5. High synchrony flag threshold
//
// Usage:
//   iverilog -o tb_kuramoto_order.vvp tb/tb_kuramoto_order.v \
//       src/kuramoto_order_parameter.v && vvp tb_kuramoto_order.vvp
//=============================================================================
`timescale 1ns / 1ps

module tb_kuramoto_order;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 10;

reg clk;
reg rst;
reg clk_en;

// Oscillator inputs
reg signed [WIDTH-1:0] theta_x, theta_y;
reg signed [WIDTH-1:0] alpha_x, alpha_y;
reg signed [WIDTH-1:0] beta1_x, beta1_y;
reg signed [WIDTH-1:0] beta2_x, beta2_y;
reg signed [WIDTH-1:0] gamma_x, gamma_y;
reg signed [WIDTH-1:0] sr_f0_x, sr_f0_y;

// Outputs
wire signed [WIDTH-1:0] kuramoto_R;
wire signed [WIDTH-1:0] mean_phase;
wire high_synchrony;

// Test counters
integer tests_passed;
integer tests_failed;

// DUT
kuramoto_order_parameter #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .theta_x(theta_x), .theta_y(theta_y),
    .alpha_x(alpha_x), .alpha_y(alpha_y),
    .beta1_x(beta1_x), .beta1_y(beta1_y),
    .beta2_x(beta2_x), .beta2_y(beta2_y),
    .gamma_x(gamma_x), .gamma_y(gamma_y),
    .sr_f0_x(sr_f0_x), .sr_f0_y(sr_f0_y),
    .kuramoto_R(kuramoto_R),
    .mean_phase(mean_phase),
    .high_synchrony(high_synchrony)
);

// Clock generation
always #(CLK_PERIOD/2) clk = ~clk;

// Q14 constants for test patterns
localparam signed [WIDTH-1:0] ONE = 18'sd16384;
localparam signed [WIDTH-1:0] HALF = 18'sd8192;
localparam signed [WIDTH-1:0] SQRT2_HALF = 18'sd11585;  // 0.707

// Helper task to wait for computation
// v1.1: Single-cycle latency - one clk_en pulse captures result
task wait_compute;
    begin
        repeat(5) @(posedge clk);
        clk_en = 1;
        @(posedge clk);
        clk_en = 0;
        repeat(3) @(posedge clk);
    end
endtask

// Helper to display R value
function real to_float;
    input signed [WIDTH-1:0] val;
    begin
        to_float = val / 16384.0;
    end
endfunction

initial begin
    $display("==============================================");
    $display("Kuramoto Order Parameter Testbench");
    $display("==============================================");

    // Initialize
    clk = 0;
    rst = 1;
    clk_en = 0;
    tests_passed = 0;
    tests_failed = 0;

    // All oscillators start at zero
    theta_x = 0; theta_y = 0;
    alpha_x = 0; alpha_y = 0;
    beta1_x = 0; beta1_y = 0;
    beta2_x = 0; beta2_y = 0;
    gamma_x = 0; gamma_y = 0;
    sr_f0_x = 0; sr_f0_y = 0;

    // Release reset
    repeat(5) @(posedge clk);
    rst = 0;
    repeat(5) @(posedge clk);

    //=========================================================================
    // TEST 1: All oscillators aligned at phase 0 (x=1, y=0)
    // Expected: R ≈ 1.0 (perfect synchrony)
    //=========================================================================
    $display("\n[TEST 1] Perfect synchrony (all at phase 0)");
    theta_x = ONE; theta_y = 0;
    alpha_x = ONE; alpha_y = 0;
    beta1_x = ONE; beta1_y = 0;
    beta2_x = ONE; beta2_y = 0;
    gamma_x = ONE; gamma_y = 0;
    sr_f0_x = ONE; sr_f0_y = 0;

    wait_compute;

    $display("  R = %0d (%.3f), high_synchrony = %b", kuramoto_R, to_float(kuramoto_R), high_synchrony);
    if (kuramoto_R > 18'sd14746 && high_synchrony == 1) begin  // > 0.9
        $display("  PASS - R > 0.9 as expected");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected R > 0.9");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 2: All oscillators aligned at phase π/4 (x=y=0.707)
    // Expected: R ≈ 1.0 (still synchronized, just different phase)
    //=========================================================================
    $display("\n[TEST 2] Perfect synchrony at phase π/4");
    theta_x = SQRT2_HALF; theta_y = SQRT2_HALF;
    alpha_x = SQRT2_HALF; alpha_y = SQRT2_HALF;
    beta1_x = SQRT2_HALF; beta1_y = SQRT2_HALF;
    beta2_x = SQRT2_HALF; beta2_y = SQRT2_HALF;
    gamma_x = SQRT2_HALF; gamma_y = SQRT2_HALF;
    sr_f0_x = SQRT2_HALF; sr_f0_y = SQRT2_HALF;

    wait_compute;

    $display("  R = %0d (%.3f), high_synchrony = %b", kuramoto_R, to_float(kuramoto_R), high_synchrony);
    if (kuramoto_R > 18'sd14746) begin  // > 0.9
        $display("  PASS - R > 0.9 as expected");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected R > 0.9");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 3: Half at phase 0, half at phase π (anti-phase)
    // Expected: R ≈ 0 (cancellation)
    //=========================================================================
    $display("\n[TEST 3] Anti-phase pairs (half at 0, half at π)");
    theta_x = ONE; theta_y = 0;        // phase 0
    alpha_x = ONE; alpha_y = 0;        // phase 0
    beta1_x = ONE; beta1_y = 0;        // phase 0
    beta2_x = -ONE; beta2_y = 0;       // phase π
    gamma_x = -ONE; gamma_y = 0;       // phase π
    sr_f0_x = -ONE; sr_f0_y = 0;       // phase π

    wait_compute;

    $display("  R = %0d (%.3f), high_synchrony = %b", kuramoto_R, to_float(kuramoto_R), high_synchrony);
    if (kuramoto_R < 18'sd1638 && high_synchrony == 0) begin  // < 0.1
        $display("  PASS - R ≈ 0 as expected");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected R ≈ 0");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 4: Uniform distribution around circle
    // Phases at 0, π/3, 2π/3, π, 4π/3, 5π/3
    // Expected: R ≈ 0 (uniform = no net direction)
    //=========================================================================
    $display("\n[TEST 4] Uniform distribution (6 phases evenly spaced)");
    // Phase 0: (1, 0)
    theta_x = ONE; theta_y = 0;
    // Phase π/3: (0.5, 0.866)
    alpha_x = 18'sd8192; alpha_y = 18'sd14189;
    // Phase 2π/3: (-0.5, 0.866)
    beta1_x = -18'sd8192; beta1_y = 18'sd14189;
    // Phase π: (-1, 0)
    beta2_x = -ONE; beta2_y = 0;
    // Phase 4π/3: (-0.5, -0.866)
    gamma_x = -18'sd8192; gamma_y = -18'sd14189;
    // Phase 5π/3: (0.5, -0.866)
    sr_f0_x = 18'sd8192; sr_f0_y = -18'sd14189;

    wait_compute;

    $display("  R = %0d (%.3f), high_synchrony = %b", kuramoto_R, to_float(kuramoto_R), high_synchrony);
    if (kuramoto_R < 18'sd3277) begin  // < 0.2
        $display("  PASS - R ≈ 0 for uniform distribution");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected R < 0.2");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 5: Partial synchrony (4 aligned, 2 opposite)
    // Expected: R ≈ 0.33 (4/6 - 2/6 = 2/6)
    //=========================================================================
    $display("\n[TEST 5] Partial synchrony (4 at 0, 2 at π)");
    theta_x = ONE; theta_y = 0;
    alpha_x = ONE; alpha_y = 0;
    beta1_x = ONE; beta1_y = 0;
    beta2_x = ONE; beta2_y = 0;
    gamma_x = -ONE; gamma_y = 0;
    sr_f0_x = -ONE; sr_f0_y = 0;

    wait_compute;

    $display("  R = %0d (%.3f), high_synchrony = %b", kuramoto_R, to_float(kuramoto_R), high_synchrony);
    if (kuramoto_R > 18'sd3277 && kuramoto_R < 18'sd8192) begin  // 0.2 < R < 0.5
        $display("  PASS - R in expected range for partial sync");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected 0.2 < R < 0.5");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 6: High synchrony threshold test
    // 5 aligned + 1 opposite → R ≈ 0.67
    //=========================================================================
    $display("\n[TEST 6] Near threshold (5 at 0, 1 at π)");
    theta_x = ONE; theta_y = 0;
    alpha_x = ONE; alpha_y = 0;
    beta1_x = ONE; beta1_y = 0;
    beta2_x = ONE; beta2_y = 0;
    gamma_x = ONE; gamma_y = 0;
    sr_f0_x = -ONE; sr_f0_y = 0;

    wait_compute;

    $display("  R = %0d (%.3f), high_synchrony = %b", kuramoto_R, to_float(kuramoto_R), high_synchrony);
    // Expected R = (5-1)/6 = 0.67, should be near but below 0.7 threshold
    if (kuramoto_R > 18'sd9830 && kuramoto_R < 18'sd12288) begin  // 0.6 < R < 0.75
        $display("  PASS - R in expected range near threshold");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected 0.6 < R < 0.75");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 7: Variable amplitudes (should still work after normalization)
    //=========================================================================
    $display("\n[TEST 7] Variable amplitudes (all aligned, different magnitudes)");
    theta_x = ONE; theta_y = 0;
    alpha_x = HALF; alpha_y = 0;         // Half amplitude
    beta1_x = ONE * 2; beta1_y = 0;       // Double amplitude
    beta2_x = ONE / 4; beta2_y = 0;       // Quarter amplitude
    gamma_x = ONE; gamma_y = 0;
    sr_f0_x = HALF; sr_f0_y = 0;

    wait_compute;

    $display("  R = %0d (%.3f), high_synchrony = %b", kuramoto_R, to_float(kuramoto_R), high_synchrony);
    if (kuramoto_R > 18'sd14746) begin  // > 0.9
        $display("  PASS - R > 0.9 (amplitude-independent)");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected R > 0.9 regardless of amplitude");
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
