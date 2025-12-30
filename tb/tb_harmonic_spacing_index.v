//=============================================================================
// Testbench for Harmonic Spacing Index - v1.0
//
// Tests:
// 1. Perfect φ ratios should give HSI ≈ 1.0
// 2. Large deviations should give HSI close to 0
// 3. Partial lock detection
// 4. Delta HSI responds to changes
// 5. Harmonic lock flag accuracy
// 6. Realistic frequencies (nominal φⁿ values)
// 7. Drift tolerance
// 8. Recovery from deviation
//=============================================================================
`timescale 1ns / 1ps

module tb_harmonic_spacing_index;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 8;  // 125 MHz

reg clk;
reg rst;
reg clk_en;
reg signed [WIDTH-1:0] omega_theta;
reg signed [WIDTH-1:0] omega_alpha;
reg signed [WIDTH-1:0] omega_beta1;
reg signed [WIDTH-1:0] omega_beta2;
reg signed [WIDTH-1:0] omega_gamma;

wire signed [WIDTH-1:0] hsi;
wire signed [WIDTH-1:0] delta_hsi;
wire harmonic_locked;

// Constants
localparam signed [WIDTH-1:0] PHI = 18'sd26510;    // 1.618 in Q14
localparam signed [WIDTH-1:0] ONE = 18'sd16384;    // 1.0 in Q14

// Instantiate DUT
harmonic_spacing_index #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .AVG_SHIFT(4)  // Faster baseline for testing
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .omega_theta(omega_theta),
    .omega_alpha(omega_alpha),
    .omega_beta1(omega_beta1),
    .omega_beta2(omega_beta2),
    .omega_gamma(omega_gamma),
    .hsi(hsi),
    .delta_hsi(delta_hsi),
    .harmonic_locked(harmonic_locked)
);

// Clock generation
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// Test counters
integer test_pass = 0;
integer test_fail = 0;

// Helper: wait for N clock cycles with clk_en
task wait_cycles;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk);
            clk_en = 1;
            @(posedge clk);
            clk_en = 0;
        end
    end
endtask

// Helper: set frequencies with exact φ ratios
// Uses wider intermediate values to avoid overflow
task set_phi_ratios;
    input signed [WIDTH-1:0] base_omega;
    reg signed [2*WIDTH-1:0] temp;
    begin
        omega_theta = base_omega;
        // α = θ × φ
        temp = base_omega * PHI;
        omega_alpha = temp >>> FRAC;
        // β₁ = α × φ = θ × φ²
        temp = omega_alpha * PHI;
        omega_beta1 = temp >>> FRAC;
        // β₂ = β₁ × φ = θ × φ³
        temp = omega_beta1 * PHI;
        omega_beta2 = temp >>> FRAC;
        // γ = β₂ × φ = θ × φ⁴
        temp = omega_beta2 * PHI;
        omega_gamma = temp >>> FRAC;
    end
endtask

// Main test sequence
initial begin
    $display("========================================");
    $display("Harmonic Spacing Index Testbench v1.0");
    $display("========================================");

    // Initialize
    rst = 1;
    clk_en = 0;
    omega_theta = 18'sd157;   // 6.09 Hz nominal (v12.2: φ^-0.5 × 7.75)
    omega_alpha = 18'sd254;   // 9.86 Hz (v12.2: φ^0.5 × 7.75)
    omega_beta1 = 18'sd410;   // 15.95 Hz (v12.2: φ^1.5 × 7.75)
    omega_beta2 = 18'sd664;   // 25.81 Hz (v12.2: φ^2.5 × 7.75)
    omega_gamma = 18'sd1075;  // 41.76 Hz (v12.2: φ^3.5 × 7.75)

    repeat (10) @(posedge clk);
    rst = 0;
    repeat (5) @(posedge clk);

    //=========================================================================
    // TEST 1: Perfect φ ratios → HSI ≈ 1.0
    //=========================================================================
    $display("\n[TEST 1] Perfect phi ratios");
    set_phi_ratios(18'sd100);  // Base frequency
    wait_cycles(10);

    $display("         omega: θ=%0d, α=%0d, β₁=%0d, β₂=%0d, γ=%0d",
             omega_theta, omega_alpha, omega_beta1, omega_beta2, omega_gamma);
    $display("         HSI = %0d (expected ~%0d)", hsi, ONE);

    if (hsi > 18'sd14000) begin  // > 0.85
        $display("         PASS - HSI high for perfect ratios");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - HSI too low: %0d", hsi);
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 2: Large deviations → HSI near 0
    //=========================================================================
    $display("\n[TEST 2] Large frequency deviations");
    // Set non-φ ratios (all = 1:1)
    omega_theta = 18'sd100;
    omega_alpha = 18'sd100;
    omega_beta1 = 18'sd100;
    omega_beta2 = 18'sd100;
    omega_gamma = 18'sd100;
    wait_cycles(10);

    $display("         All frequencies equal (ratio=1.0, not φ)");
    $display("         HSI = %0d (expected < 6000)", hsi);

    if (hsi < 18'sd6000) begin  // < 0.4
        $display("         PASS - HSI low for non-φ ratios");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - HSI too high: %0d", hsi);
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 3: Harmonic lock detection
    //=========================================================================
    $display("\n[TEST 3] Harmonic lock detection");
    set_phi_ratios(18'sd100);
    wait_cycles(10);

    $display("         Perfect φ ratios → harmonic_locked = %b", harmonic_locked);
    if (harmonic_locked) begin
        $display("         PASS - Harmonic lock detected");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - Should be locked");
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 4: No lock with large deviations
    //=========================================================================
    $display("\n[TEST 4] No lock with deviations");
    omega_theta = 18'sd100;
    omega_alpha = 18'sd200;  // ratio = 2.0, not φ
    omega_beta1 = 18'sd400;
    omega_beta2 = 18'sd800;
    omega_gamma = 18'sd1600;
    wait_cycles(10);

    $display("         2:1 ratios → harmonic_locked = %b", harmonic_locked);
    if (!harmonic_locked) begin
        $display("         PASS - Lock correctly not detected");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - Should not be locked");
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 5: Delta HSI responds to changes
    //=========================================================================
    $display("\n[TEST 5] Delta HSI response");
    // First stabilize at perfect ratios
    set_phi_ratios(18'sd100);
    wait_cycles(50);  // Let baseline settle

    // Save baseline
    $display("         Baseline HSI = %0d", hsi);

    // Now shift to bad ratios
    omega_theta = 18'sd100;
    omega_alpha = 18'sd100;  // 1:1 ratio
    omega_beta1 = 18'sd100;
    omega_beta2 = 18'sd100;
    omega_gamma = 18'sd100;
    wait_cycles(5);

    $display("         After deviation: HSI = %0d, delta = %0d", hsi, delta_hsi);
    if (delta_hsi < 0) begin  // Delta should be negative (worse than baseline)
        $display("         PASS - Delta HSI negative on degradation");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - Delta should be negative");
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 6: Realistic frequencies (actual omega_dt values)
    //=========================================================================
    $display("\n[TEST 6] Realistic omega_dt values");
    // These are actual omega_dt values from the system
    omega_theta = 18'sd157;   // 6.09 Hz (v12.2)
    omega_alpha = 18'sd254;   // 9.86 Hz (ratio ≈ 1.62)
    omega_beta1 = 18'sd410;   // 15.95 Hz (ratio ≈ 1.61)
    omega_beta2 = 18'sd664;   // 25.81 Hz (ratio ≈ 1.62)
    omega_gamma = 18'sd1075;  // 41.76 Hz (ratio ≈ 1.62)
    wait_cycles(10);

    $display("         Real ω values: θ=157, α=254, β₁=410, β₂=664, γ=1075");
    $display("         HSI = %0d, locked = %b", hsi, harmonic_locked);

    // Actual system ratios are close to φ but not exact
    if (hsi > 18'sd12000) begin  // > 0.73
        $display("         PASS - HSI reasonable for real frequencies");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - HSI too low for φⁿ frequencies");
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 7: Small drift tolerance
    //=========================================================================
    $display("\n[TEST 7] Small drift within tolerance");
    set_phi_ratios(18'sd100);
    // Add small drift (±3%)
    omega_alpha = omega_alpha + 18'sd5;  // +3%
    omega_beta1 = omega_beta1 - 18'sd8;  // -3%
    wait_cycles(10);

    $display("         ±3%% drift: HSI = %0d, locked = %b", hsi, harmonic_locked);
    if (hsi > 18'sd13000) begin  // Still good
        $display("         PASS - HSI tolerant of small drift");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - HSI too sensitive");
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 8: Recovery from deviation
    //=========================================================================
    $display("\n[TEST 8] Recovery from deviation");
    // Start with bad ratios
    omega_theta = 18'sd100;
    omega_alpha = 18'sd100;
    omega_beta1 = 18'sd100;
    omega_beta2 = 18'sd100;
    omega_gamma = 18'sd100;
    wait_cycles(20);
    $display("         Bad ratios: HSI = %0d", hsi);

    // Return to good ratios
    set_phi_ratios(18'sd100);
    wait_cycles(20);
    $display("         Good ratios: HSI = %0d, delta = %0d", hsi, delta_hsi);

    if (hsi > 18'sd14000 && delta_hsi > 0) begin
        $display("         PASS - HSI recovered with positive delta");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - Recovery not detected");
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n========================================");
    $display("SUMMARY: %0d passed, %0d failed", test_pass, test_fail);
    $display("========================================");

    if (test_fail == 0) begin
        $display("ALL TESTS PASSED!");
    end

    $finish;
end

endmodule
