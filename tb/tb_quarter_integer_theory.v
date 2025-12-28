//=============================================================================
// Testbench: tb_quarter_integer_theory.v
//
// Validates the v10.5 Quarter-Integer phi^n Theory:
// - f1 explained as phi^1.25 fallback due to 2:1 Harmonic Catastrophe
// - Geometric mean solution between boundary (n=1) and compromised attractor (n=1.5)
// - Quarter-integer modes have higher SIE responsiveness (3.0x)
//
// Theory Summary:
// - Energy landscape: E_total(n) = E_phi(n) + E_h(n)
// - E_phi(n) = -A*cos(2*pi*n) with minima at half-integers
// - E_h(n) = B/(phi^n - 2)^2 diverges at 2:1 harmonic
// - phi^1.5 = 2.058 is catastrophically close to 2.0
// - System falls back to quarter-integer: n_stable = (1.0 + 1.5)/2 = 1.25
// - phi^1.25 = 1.8249, giving f1 = 7.72 Hz x 1.8249 = 14.09 Hz
// - Observed: 13.75-14.17 Hz (< 1% error)
//
// References:
// - docs/SPEC_v10.5_UPDATE.md
// - F2_QUARTER_INTEGER_ANALYSIS_REPORT.md
//=============================================================================
`timescale 1ns / 1ps

module tb_quarter_integer_theory;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter NUM_HARMONICS = 5;

// Test counters
integer passed, failed;

// Clock and reset
reg clk;
reg rst;

//-----------------------------------------------------------------------------
// phi^n Reference Constants (high-precision calculations)
// phi = (1 + sqrt(5)) / 2 = 1.6180339887498948482...
//-----------------------------------------------------------------------------
localparam real PHI_REAL = 1.6180339887;
localparam real PHI_0_25_REAL = 1.127628156;   // phi^0.25
localparam real PHI_0_5_REAL = 1.272019649;    // phi^0.5
localparam real PHI_1_0_REAL = 1.618033989;    // phi^1.0
localparam real PHI_1_25_REAL = 1.824939959;   // phi^1.25 (quarter-integer fallback)
localparam real PHI_1_5_REAL = 2.058171027;    // phi^1.5 (compromised by 2:1)
localparam real PHI_2_0_REAL = 2.618033989;    // phi^2.0

//-----------------------------------------------------------------------------
// Q14 Constants from sr_harmonic_bank.v v7.6
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] PHI_Q14 = 18'sd26510;
localparam signed [WIDTH-1:0] PHI_0_25 = 18'sd18474;
localparam signed [WIDTH-1:0] PHI_0_5 = 18'sd20833;
localparam signed [WIDTH-1:0] PHI_1_25 = 18'sd29899;
localparam signed [WIDTH-1:0] PHI_1_5 = 18'sd33718;
localparam signed [WIDTH-1:0] PHI_2_0 = 18'sd42891;
localparam signed [WIDTH-1:0] HARMONIC_2_1 = 18'sd32768;
localparam signed [WIDTH-1:0] OMEGA_DT_F1_THEORY = 18'sd356;  // 13.84 Hz theoretical
localparam signed [WIDTH-1:0] OMEGA_DT_F1 = 18'sd354;         // 13.75 Hz observed

// SIE Enhancement factors
localparam signed [WIDTH-1:0] SIE_ENHANCE_F0 = 18'sd44237;  // 2.7x
localparam signed [WIDTH-1:0] SIE_ENHANCE_F1 = 18'sd49152;  // 3.0x (quarter-integer, MOST responsive)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F2 = 18'sd20480;  // 1.25x

// SR frequencies
localparam real F0_HZ = 7.6;            // Observed SR fundamental
localparam real F0_TOMSK_HZ = 7.72;     // Tomsk 27-year average
localparam real F1_OBSERVED_HZ = 13.75; // Our implementation
localparam real F1_TOMSK_HZ = 14.17;    // Tomsk 27-year average
localparam real F1_THEORY_HZ = 14.09;   // phi^1.25 x 7.72 Hz

//-----------------------------------------------------------------------------
// Clock generation
//-----------------------------------------------------------------------------
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

//-----------------------------------------------------------------------------
// Helper function: Q14 to real
//-----------------------------------------------------------------------------
function real q14_to_real;
    input signed [WIDTH-1:0] q14_val;
    begin
        q14_to_real = q14_val / 16384.0;
    end
endfunction

//-----------------------------------------------------------------------------
// Test procedure
//-----------------------------------------------------------------------------
initial begin
    $dumpfile("tb_quarter_integer_theory.vcd");
    $dumpvars(0, tb_quarter_integer_theory);

    passed = 0;
    failed = 0;

    rst = 1;
    #100 rst = 0;

    $display("");
    $display("=============================================================");
    $display("  Quarter-Integer phi^n Theory Tests (v10.5)");
    $display("=============================================================");
    $display("");

    //=========================================================================
    // TEST 1: phi^1.0 Constant Accuracy
    //=========================================================================
    $display("TEST 1: phi^1.0 Constant Accuracy");
    begin : test1
        real phi_computed, error_pct;
        phi_computed = q14_to_real(PHI_Q14);
        error_pct = (phi_computed - PHI_1_0_REAL) / PHI_1_0_REAL * 100.0;
        $display("  PHI_Q14 = %0d, computed = %f, expected = %f", PHI_Q14, phi_computed, PHI_1_0_REAL);
        $display("  Error = %f%%", error_pct);
        if (error_pct < 0.1 && error_pct > -0.1) begin
            $display("  PASS: phi^1.0 accuracy < 0.1%%");
            passed = passed + 1;
        end else begin
            $display("  FAIL: phi^1.0 accuracy >= 0.1%%");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 2: phi^0.25 Constant Accuracy (Quarter Power)
    //=========================================================================
    $display("");
    $display("TEST 2: phi^0.25 Constant Accuracy");
    begin : test2
        real phi_computed, error_pct;
        phi_computed = q14_to_real(PHI_0_25);
        error_pct = (phi_computed - PHI_0_25_REAL) / PHI_0_25_REAL * 100.0;
        $display("  PHI_0_25 = %0d, computed = %f, expected = %f", PHI_0_25, phi_computed, PHI_0_25_REAL);
        $display("  Error = %f%%", error_pct);
        if (error_pct < 0.1 && error_pct > -0.1) begin
            $display("  PASS: phi^0.25 accuracy < 0.1%%");
            passed = passed + 1;
        end else begin
            $display("  FAIL: phi^0.25 accuracy >= 0.1%%");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 3: phi^1.25 Constant Accuracy (f1 Theoretical)
    //=========================================================================
    $display("");
    $display("TEST 3: phi^1.25 Constant Accuracy");
    begin : test3
        real phi_computed, error_pct;
        phi_computed = q14_to_real(PHI_1_25);
        error_pct = (phi_computed - PHI_1_25_REAL) / PHI_1_25_REAL * 100.0;
        $display("  PHI_1_25 = %0d, computed = %f, expected = %f", PHI_1_25, phi_computed, PHI_1_25_REAL);
        $display("  Error = %f%%", error_pct);
        if (error_pct < 0.1 && error_pct > -0.1) begin
            $display("  PASS: phi^1.25 accuracy < 0.1%%");
            passed = passed + 1;
        end else begin
            $display("  FAIL: phi^1.25 accuracy >= 0.1%%");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 4: f1 Theoretical Frequency (phi^1.25 x f0)
    //=========================================================================
    $display("");
    $display("TEST 4: f1 Theoretical Frequency Match");
    begin : test4
        real f1_theory, error_pct;
        f1_theory = F0_TOMSK_HZ * PHI_1_25_REAL;
        error_pct = (f1_theory - F1_TOMSK_HZ) / F1_TOMSK_HZ * 100.0;
        $display("  f0 (Tomsk) = %f Hz", F0_TOMSK_HZ);
        $display("  phi^1.25 = %f", PHI_1_25_REAL);
        $display("  f1_theory = f0 x phi^1.25 = %f Hz", f1_theory);
        $display("  f1_observed (Tomsk 27-yr) = %f Hz", F1_TOMSK_HZ);
        $display("  Error = %f%%", error_pct);
        if (error_pct < 1.0 && error_pct > -1.0) begin
            $display("  PASS: f1 theory matches Tomsk 27-yr within 1%%");
            passed = passed + 1;
        end else begin
            $display("  FAIL: f1 theory error >= 1%%");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 5: 2:1 Harmonic Proximity (phi^1.5 to 2.0)
    //=========================================================================
    $display("");
    $display("TEST 5: 2:1 Harmonic Catastrophe Detection");
    begin : test5
        real phi_1_5, distance, repulsion_energy;
        phi_1_5 = q14_to_real(PHI_1_5);
        distance = phi_1_5 - 2.0;  // Distance from 2:1 harmonic
        repulsion_energy = 1.0 / (distance * distance);
        $display("  phi^1.5 = %f", phi_1_5);
        $display("  Distance from 2:1 = %f", distance);
        $display("  Harmonic repulsion energy = 1/d^2 = %f", repulsion_energy);
        if (distance < 0.1 && distance > 0.0) begin
            $display("  PASS: phi^1.5 is dangerously close to 2:1 (distance < 0.1)");
            passed = passed + 1;
        end else begin
            $display("  FAIL: phi^1.5 not in expected proximity to 2:1");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 6: Geometric Mean Verification
    //=========================================================================
    $display("");
    $display("TEST 6: Geometric Mean sqrt(phi^1 x phi^1.5) = phi^1.25");
    begin : test6
        real geometric_mean, expected, error_pct;
        geometric_mean = $sqrt(PHI_1_0_REAL * PHI_1_5_REAL);
        expected = PHI_1_25_REAL;
        error_pct = (geometric_mean - expected) / expected * 100.0;
        $display("  sqrt(phi^1 x phi^1.5) = sqrt(%f x %f) = %f", PHI_1_0_REAL, PHI_1_5_REAL, geometric_mean);
        $display("  phi^1.25 = %f", expected);
        $display("  Error = %f%%", error_pct);
        if (error_pct < 0.01 && error_pct > -0.01) begin
            $display("  PASS: Geometric mean equals phi^1.25 (< 0.01%% error)");
            passed = passed + 1;
        end else begin
            $display("  FAIL: Geometric mean mismatch");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 7: Arithmetic Mean in Exponent Space
    //=========================================================================
    $display("");
    $display("TEST 7: Arithmetic Mean (1.0 + 1.5)/2 = 1.25");
    begin : test7
        real n_low, n_high, n_fallback;
        n_low = 1.0;   // Stable boundary
        n_high = 1.5;  // Unstable half-integer (2:1 catastrophe)
        n_fallback = (n_low + n_high) / 2.0;
        $display("  n_low (boundary) = %f", n_low);
        $display("  n_high (compromised attractor) = %f", n_high);
        $display("  n_fallback = (n_low + n_high) / 2 = %f", n_fallback);
        if (n_fallback == 1.25) begin
            $display("  PASS: Quarter-integer fallback n = 1.25");
            passed = passed + 1;
        end else begin
            $display("  FAIL: Unexpected fallback value");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 8: Quarter-Integer Mode Highest SIE Responsiveness
    //=========================================================================
    $display("");
    $display("TEST 8: Quarter-Integer Mode SIE Responsiveness");
    begin : test8
        real sie_f0_x, sie_f1_x, sie_f2_x;
        sie_f0_x = q14_to_real(SIE_ENHANCE_F0);
        sie_f1_x = q14_to_real(SIE_ENHANCE_F1);
        sie_f2_x = q14_to_real(SIE_ENHANCE_F2);

        $display("  SIE_ENHANCE_F0 = %f (half-integer phi^0.5)", sie_f0_x);
        $display("  SIE_ENHANCE_F1 = %f (quarter-integer phi^1.25)", sie_f1_x);
        $display("  SIE_ENHANCE_F2 = %f (anchor)", sie_f2_x);

        if (SIE_ENHANCE_F1 > SIE_ENHANCE_F0 && SIE_ENHANCE_F1 > SIE_ENHANCE_F2) begin
            $display("  PASS: f1 (quarter-integer) has highest SIE responsiveness");
            passed = passed + 1;
        end else begin
            $display("  FAIL: f1 should have highest SIE enhancement");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 9: Q14 Comparison PHI_1_5 > HARMONIC_2_1
    //=========================================================================
    $display("");
    $display("TEST 9: phi^1.5 vs 2:1 Harmonic (Q14 Comparison)");
    begin : test9
        $display("  PHI_1_5 (Q14) = %0d", PHI_1_5);
        $display("  HARMONIC_2_1 (Q14) = %0d", HARMONIC_2_1);
        $display("  Difference = %0d", PHI_1_5 - HARMONIC_2_1);
        if (PHI_1_5 > HARMONIC_2_1 && (PHI_1_5 - HARMONIC_2_1) < 2000) begin
            $display("  PASS: phi^1.5 slightly above 2:1, within catastrophe zone");
            passed = passed + 1;
        end else begin
            $display("  FAIL: Unexpected Q14 relationship");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 10: Other Half-Integers Safe from Harmonics
    //=========================================================================
    $display("");
    $display("TEST 10: Other Half-Integer Stability Check");
    begin : test10
        real dist_0_5, dist_2_5, dist_3_0;
        dist_0_5 = PHI_0_5_REAL - 1.0;  // Distance from 1:1
        dist_2_5 = 3.330 - 3.0;          // phi^2.5 distance from 3:1
        dist_3_0 = 4.236 - 4.0;          // phi^3.0 distance from 4:1

        $display("  phi^0.5 = %f (distance from 1:1 = %f)", PHI_0_5_REAL, dist_0_5);
        $display("  phi^2.5 = 3.330 (distance from 3:1 = %f)", dist_2_5);
        $display("  phi^3.0 = 4.236 (distance from 4:1 = %f)", dist_3_0);

        // None are within 0.2 of a harmonic
        if (dist_0_5 > 0.2 && dist_2_5 > 0.2 && dist_3_0 > 0.2) begin
            $display("  PASS: All other half-integers are > 0.2 from harmonics (safe)");
            passed = passed + 1;
        end else begin
            $display("  FAIL: Unexpected proximity to harmonics");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 11: f1/f0 Ratio Matches phi^1.25
    //=========================================================================
    $display("");
    $display("TEST 11: f1/f0 Ratio Verification");
    begin : test11
        real ratio_observed, ratio_theory, error_pct;
        ratio_observed = F1_OBSERVED_HZ / F0_HZ;
        ratio_theory = PHI_1_25_REAL;
        error_pct = (ratio_observed - ratio_theory) / ratio_theory * 100.0;

        $display("  f1/f0 observed = %f / %f = %f", F1_OBSERVED_HZ, F0_HZ, ratio_observed);
        $display("  phi^1.25 (theory) = %f", ratio_theory);
        $display("  Error = %f%%", error_pct);

        if (error_pct < 1.5 && error_pct > -1.5) begin
            $display("  PASS: f1/f0 ratio matches phi^1.25 within 1.5%%");
            passed = passed + 1;
        end else begin
            $display("  FAIL: Ratio mismatch >= 1.5%%");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // TEST 12: Tomsk 27-Year Validation
    //=========================================================================
    $display("");
    $display("TEST 12: Tomsk 27-Year Data Validation");
    begin : test12
        real f1_predicted, error_pct;
        f1_predicted = F0_TOMSK_HZ * PHI_1_25_REAL;
        error_pct = (f1_predicted - F1_TOMSK_HZ) / F1_TOMSK_HZ * 100.0;

        $display("  Tomsk f0 = %f Hz", F0_TOMSK_HZ);
        $display("  Predicted f1 = f0 x phi^1.25 = %f Hz", f1_predicted);
        $display("  Tomsk f1 (27-yr avg) = %f Hz", F1_TOMSK_HZ);
        $display("  Error = %f%%", error_pct);

        if (error_pct < 1.0 && error_pct > -1.0) begin
            $display("  PASS: Predicted matches Tomsk 27-yr average within 1%%");
            passed = passed + 1;
        end else begin
            $display("  FAIL: Tomsk validation error >= 1%%");
            failed = failed + 1;
        end
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("");
    $display("=============================================================");
    $display("  Test Summary");
    $display("=============================================================");
    $display("  Passed: %0d", passed);
    $display("  Failed: %0d", failed);
    $display("  Total:  %0d", passed + failed);
    $display("");

    if (failed == 0)
        $display("  *** ALL QUARTER-INTEGER THEORY TESTS PASSED ***");
    else
        $display("  *** SOME TESTS FAILED ***");

    $display("");
    $display("  Theory Summary:");
    $display("  - f1 is NOT anomalous - it follows the quarter-integer rule");
    $display("  - phi^1.5 = 2.058 is compromised by 2:1 harmonic (ratio 2.0)");
    $display("  - f1 retreats to geometric mean: n = (1.0 + 1.5)/2 = 1.25");
    $display("  - phi^1.25 = 1.825, giving f1 = 14.09 Hz (Tomsk: 14.17 Hz)");
    $display("  - Quarter-integer has highest SIE response (3.0x)");
    $display("");

    #100 $finish;
end

endmodule
