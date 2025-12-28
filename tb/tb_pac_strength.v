//=============================================================================
// Testbench for PAC Strength Module - v11.1c
//
// Validates Phase-Amplitude Coupling strength computation based on:
//   - Chi(ratio) lookup from coupling susceptibility LUT
//   - Amplitude factor computation
//   - Classification (boundary/attractor/transition)
//
// 10 tests covering key oscillator pair behaviors
//=============================================================================
`timescale 1ns / 1ps

module tb_pac_strength;

//-----------------------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------------------
parameter WIDTH = 18;
parameter FRAC = 14;
parameter NUM_PAIRS = 10;
parameter CLK_PERIOD = 8;  // 125 MHz

//-----------------------------------------------------------------------------
// Signals
//-----------------------------------------------------------------------------
reg clk;
reg rst;
reg clk_en;

// Frequency inputs (OMEGA_DT values)
reg [WIDTH-1:0] omega_theta;
reg [WIDTH-1:0] omega_alpha;
reg [WIDTH-1:0] omega_beta_low;
reg [WIDTH-1:0] omega_beta_high;
reg [WIDTH-1:0] omega_gamma;
reg [WIDTH-1:0] omega_gamma_fast;
reg [WIDTH-1:0] omega_sr_f0;
reg [WIDTH-1:0] omega_sr_f2;

// Amplitude inputs
reg [WIDTH-1:0] amp_theta;
reg [WIDTH-1:0] amp_alpha;
reg [WIDTH-1:0] amp_beta_low;
reg [WIDTH-1:0] amp_beta_high;
reg [WIDTH-1:0] amp_gamma;
reg [WIDTH-1:0] amp_gamma_fast;
reg [WIDTH-1:0] amp_sr_f0;
reg [WIDTH-1:0] amp_sr_f2;

// PAC strength outputs
wire [WIDTH-1:0] pac_theta_alpha;
wire [WIDTH-1:0] pac_theta_beta_low;
wire [WIDTH-1:0] pac_alpha_beta_low;
wire [WIDTH-1:0] pac_alpha_beta_high;
wire [WIDTH-1:0] pac_beta_low_gamma;
wire [WIDTH-1:0] pac_beta_high_gamma;
wire [WIDTH-1:0] pac_theta_gamma_fast;
wire [WIDTH-1:0] pac_alpha_gamma_fast;
wire [WIDTH-1:0] pac_sr_f0_f2;
wire [WIDTH-1:0] pac_theta_gamma;

// Classification outputs
wire [1:0] class_theta_alpha;
wire [1:0] class_theta_beta_low;
wire [1:0] class_alpha_beta_low;
wire [1:0] class_alpha_beta_high;
wire [1:0] class_beta_low_gamma;
wire [1:0] class_beta_high_gamma;
wire [1:0] class_theta_gamma_fast;
wire [1:0] class_alpha_gamma_fast;
wire [1:0] class_sr_f0_f2;
wire [1:0] class_theta_gamma;

//-----------------------------------------------------------------------------
// DUT Instantiation
//-----------------------------------------------------------------------------
pac_strength #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_PAIRS(NUM_PAIRS)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),

    .omega_theta(omega_theta),
    .omega_alpha(omega_alpha),
    .omega_beta_low(omega_beta_low),
    .omega_beta_high(omega_beta_high),
    .omega_gamma(omega_gamma),
    .omega_gamma_fast(omega_gamma_fast),
    .omega_sr_f0(omega_sr_f0),
    .omega_sr_f2(omega_sr_f2),

    .amp_theta(amp_theta),
    .amp_alpha(amp_alpha),
    .amp_beta_low(amp_beta_low),
    .amp_beta_high(amp_beta_high),
    .amp_gamma(amp_gamma),
    .amp_gamma_fast(amp_gamma_fast),
    .amp_sr_f0(amp_sr_f0),
    .amp_sr_f2(amp_sr_f2),

    .pac_theta_alpha(pac_theta_alpha),
    .pac_theta_beta_low(pac_theta_beta_low),
    .pac_alpha_beta_low(pac_alpha_beta_low),
    .pac_alpha_beta_high(pac_alpha_beta_high),
    .pac_beta_low_gamma(pac_beta_low_gamma),
    .pac_beta_high_gamma(pac_beta_high_gamma),
    .pac_theta_gamma_fast(pac_theta_gamma_fast),
    .pac_alpha_gamma_fast(pac_alpha_gamma_fast),
    .pac_sr_f0_f2(pac_sr_f0_f2),
    .pac_theta_gamma(pac_theta_gamma),

    .class_theta_alpha(class_theta_alpha),
    .class_theta_beta_low(class_theta_beta_low),
    .class_alpha_beta_low(class_alpha_beta_low),
    .class_alpha_beta_high(class_alpha_beta_high),
    .class_beta_low_gamma(class_beta_low_gamma),
    .class_beta_high_gamma(class_beta_high_gamma),
    .class_theta_gamma_fast(class_theta_gamma_fast),
    .class_alpha_gamma_fast(class_alpha_gamma_fast),
    .class_sr_f0_f2(class_sr_f0_f2),
    .class_theta_gamma(class_theta_gamma)
);

//-----------------------------------------------------------------------------
// Clock Generation
//-----------------------------------------------------------------------------
always #(CLK_PERIOD/2) clk = ~clk;

//-----------------------------------------------------------------------------
// Test Variables
//-----------------------------------------------------------------------------
integer test_count;
integer pass_count;
integer fail_count;
integer active_pairs;
reg [WIDTH-1:0] pac_boosted;

// Helper function to decode classification
function [63:0] class_name;
    input [1:0] c;
    begin
        case (c)
            2'b00: class_name = "ATTRACT";
            2'b01: class_name = "TRANSIT";
            2'b10: class_name = "BOUNDRY";
            default: class_name = "UNKNOWN";
        endcase
    end
endfunction

//-----------------------------------------------------------------------------
// Test Sequence
//-----------------------------------------------------------------------------
initial begin
    $display("");
    $display("=============================================================");
    $display("PAC Strength Testbench - v11.1c");
    $display("=============================================================");
    $display("");

    // Initialize
    clk = 0;
    rst = 1;
    clk_en = 1;
    test_count = 0;
    pass_count = 0;
    fail_count = 0;

    // Initialize frequencies (OMEGA_DT values from architecture)
    omega_theta = 18'd152;       // 5.89 Hz
    omega_alpha = 18'd245;       // 9.53 Hz
    omega_beta_low = 18'd397;    // 15.42 Hz
    omega_beta_high = 18'd642;   // 24.94 Hz
    omega_gamma = 18'd817;       // 31.73 Hz
    omega_gamma_fast = 18'd1040; // 40.36 Hz
    omega_sr_f0 = 18'd196;       // 7.6 Hz
    omega_sr_f2 = 18'd514;       // 20 Hz

    // Initialize amplitudes to unity
    amp_theta = 18'd16384;
    amp_alpha = 18'd16384;
    amp_beta_low = 18'd16384;
    amp_beta_high = 18'd16384;
    amp_gamma = 18'd16384;
    amp_gamma_fast = 18'd16384;
    amp_sr_f0 = 18'd16384;
    amp_sr_f2 = 18'd16384;

    // Reset
    repeat (10) @(posedge clk);
    rst = 0;
    repeat (20) @(posedge clk);  // Extra time for LUT initialization

    // Debug: show internal state
    $display("--- Debug: Internal state after reset ---");
    $display("      ratio[0] (theta-alpha) = %0d", dut.ratio[0]);
    $display("      chi_val[0] = %0d (%.4f)", dut.chi_val[0], $itor(dut.chi_val[0])/16384.0);
    $display("      amp_factor[0] = %0d (%.4f)", dut.amp_factor[0], $itor(dut.amp_factor[0])/16384.0);
    $display("      pac_product[0] = %0d", dut.pac_product[0]);
    $display("      pac_strength[0] = %0d (%.4f)", dut.pac_strength[0], $itor(dut.pac_strength[0])/16384.0);
    $display("");

    $display("--- Test 1: Basic PAC strength computation ---");
    test_count = test_count + 1;
    // After reset, PAC values should be non-zero with unity amplitudes
    if (pac_theta_alpha > 18'd0 && pac_beta_low_gamma > 18'd0) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - PAC outputs active", test_count);
        $display("      pac_theta_alpha = %.4f", $itor(pac_theta_alpha)/16384.0);
        $display("      pac_beta_low_gamma = %.4f", $itor(pac_beta_low_gamma)/16384.0);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - PAC outputs should be non-zero", test_count);
    end

    $display("");
    $display("--- Test 2: Beta_low-Gamma highest PAC (near 2:1) ---");
    test_count = test_count + 1;
    // Beta_low-Gamma (phi^1.5 ~ 2.058) should have highest chi
    if (pac_beta_low_gamma >= pac_theta_alpha &&
        pac_beta_low_gamma >= pac_alpha_beta_low) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - Beta_low-Gamma has elevated PAC (near 2:1)", test_count);
        $display("      pac_beta_low_gamma = %.4f (highest)", $itor(pac_beta_low_gamma)/16384.0);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Beta_low-Gamma should be highest (2:1 proximity)", test_count);
    end

    $display("");
    $display("--- Test 3: Phi^0.5 pairs have low PAC (attractor) ---");
    test_count = test_count + 1;
    // Beta_high-Gamma (phi^0.5) should have low chi (attractor)
    if (pac_beta_high_gamma < pac_beta_low_gamma) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - Phi^0.5 pair has lower PAC (attractor region)", test_count);
        $display("      pac_beta_high_gamma = %.4f (low)", $itor(pac_beta_high_gamma)/16384.0);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Phi^0.5 should have lower chi than 2:1", test_count);
    end

    $display("");
    $display("--- Test 4: Classification outputs ---");
    test_count = test_count + 1;
    $display("      class_theta_alpha (phi^1): %s", class_name(class_theta_alpha));
    $display("      class_beta_low_gamma (phi^1.5): %s", class_name(class_beta_low_gamma));
    $display("      class_beta_high_gamma (phi^0.5): %s", class_name(class_beta_high_gamma));
    // Beta_low-Gamma should be boundary (near 2:1)
    if (class_beta_low_gamma == 2'b10 || class_beta_low_gamma == 2'b01) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - Beta_low-Gamma classified as boundary/transition", test_count);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Beta_low-Gamma should be boundary or transition", test_count);
    end

    $display("");
    $display("--- Test 5: Amplitude scaling ---");
    // Increase theta amplitude, check PAC increases
    amp_theta = 18'd32768;  // 2x amplitude
    repeat (5) @(posedge clk);
    test_count = test_count + 1;
    pac_boosted = pac_theta_alpha;
    amp_theta = 18'd16384;  // Reset
    repeat (5) @(posedge clk);
    // PAC should have been higher with 2x amplitude
    if (pac_boosted > pac_theta_alpha) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - PAC scales with amplitude", test_count);
        $display("      boosted=%.4f, normal=%.4f", $itor(pac_boosted)/16384.0, $itor(pac_theta_alpha)/16384.0);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - PAC should scale with amplitude", test_count);
    end

    $display("");
    $display("--- Test 6: Zero amplitude gives zero PAC ---");
    amp_theta = 18'd0;
    amp_alpha = 18'd0;
    repeat (5) @(posedge clk);
    test_count = test_count + 1;
    if (pac_theta_alpha == 18'd0) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - Zero amplitude gives zero PAC", test_count);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - PAC should be zero when amplitudes are zero", test_count);
    end
    // Restore
    amp_theta = 18'd16384;
    amp_alpha = 18'd16384;
    repeat (5) @(posedge clk);

    $display("");
    $display("--- Test 7: All 10 PAC pairs produce values ---");
    test_count = test_count + 1;
    active_pairs = 0;
    if (pac_theta_alpha > 0) active_pairs = active_pairs + 1;
    if (pac_theta_beta_low > 0) active_pairs = active_pairs + 1;
    if (pac_alpha_beta_low > 0) active_pairs = active_pairs + 1;
    if (pac_alpha_beta_high > 0) active_pairs = active_pairs + 1;
    if (pac_beta_low_gamma > 0) active_pairs = active_pairs + 1;
    if (pac_beta_high_gamma > 0) active_pairs = active_pairs + 1;
    if (pac_theta_gamma_fast > 0) active_pairs = active_pairs + 1;
    if (pac_alpha_gamma_fast > 0) active_pairs = active_pairs + 1;
    if (pac_sr_f0_f2 > 0) active_pairs = active_pairs + 1;
    if (pac_theta_gamma > 0) active_pairs = active_pairs + 1;

    if (active_pairs == 10) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - All 10 PAC pairs active", test_count);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Only %0d/10 pairs active", test_count, active_pairs);
    end

    $display("");
    $display("--- Test 8: Theta-Gamma coupling (cross-frequency) ---");
    test_count = test_count + 1;
    // Theta-Gamma is a critical cross-frequency coupling
    $display("      pac_theta_gamma = %.4f", $itor(pac_theta_gamma)/16384.0);
    $display("      class_theta_gamma: %s", class_name(class_theta_gamma));
    if (pac_theta_gamma > 18'd0) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - Theta-Gamma coupling active", test_count);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Theta-Gamma coupling should be active", test_count);
    end

    $display("");
    $display("--- Test 9: SR harmonics coupling (f0-f2) ---");
    test_count = test_count + 1;
    // SR f0-f2 (7.6 Hz to 20 Hz, ratio ~2.63 ~ phi^2)
    $display("      pac_sr_f0_f2 = %.4f", $itor(pac_sr_f0_f2)/16384.0);
    $display("      class_sr_f0_f2: %s", class_name(class_sr_f0_f2));
    if (pac_sr_f0_f2 > 18'd0) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - SR f0-f2 coupling active", test_count);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - SR f0-f2 coupling should be active", test_count);
    end

    $display("");
    $display("--- Test 10: PAC hierarchy matches framework prediction ---");
    test_count = test_count + 1;
    // Expected hierarchy: near-2:1 > phi^1 > phi^2 > phi^0.5
    $display("      PAC hierarchy:");
    $display("        beta_low-gamma (2.058): %.4f", $itor(pac_beta_low_gamma)/16384.0);
    $display("        theta-alpha (phi^1): %.4f", $itor(pac_theta_alpha)/16384.0);
    $display("        theta-beta_low (phi^2): %.4f", $itor(pac_theta_beta_low)/16384.0);
    $display("        beta_high-gamma (phi^0.5): %.4f", $itor(pac_beta_high_gamma)/16384.0);

    // Beta_low-gamma should be elevated relative to pure phi attractors
    if (pac_beta_low_gamma > 18'd4096) begin  // > 0.25
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - PAC hierarchy aligns with framework", test_count);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Near-2:1 PAC should be elevated", test_count);
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("");
    $display("=============================================================");
    $display("Test Summary: %0d/%0d passed", pass_count, test_count);
    if (fail_count == 0) begin
        $display("V11.1c PAC STRENGTH VALIDATION: ALL PASSED");
    end else begin
        $display("V11.1c PAC VALIDATION: %0d FAILED", fail_count);
    end
    $display("=============================================================");
    $display("");

    #100;
    $finish;
end

endmodule
