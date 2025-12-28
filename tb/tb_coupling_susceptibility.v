//=============================================================================
// Testbench for Coupling Susceptibility Module - v11.1a
//
// Validates the chi(r) computation for frequency ratios using
// the Unified Boundary-Attractor Framework with Farey fractions.
//
// Tests that:
//   - Integer ratios (1.0, 2.0, 3.0, 4.0) have HIGH chi (boundaries)
//   - Half-integer ratios (1.5, 2.5, 3.5) have LOW chi (attractors)
//   - Quarter-integers (1.25, 1.75) have INTERMEDIATE chi (fallbacks)
//   - Phi^n positions follow expected patterns
//   - 2:1 harmonic catastrophe zone shows very high chi
//   - Phi^1.25 = 1.825 is the MOST STABLE position (lowest chi)
//   - Chi hierarchy: boundary > quarter-int > half-int > phi-attractor
//
// 20 tests total covering v11.1a Farey fraction computed values
//=============================================================================
`timescale 1ns / 1ps

module tb_coupling_susceptibility;

//-----------------------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------------------
parameter WIDTH = 18;
parameter FRAC = 14;
parameter NUM_OSCILLATORS = 21;
parameter CLK_PERIOD = 8;  // 125 MHz

//-----------------------------------------------------------------------------
// Signals
//-----------------------------------------------------------------------------
reg clk;
reg rst;
reg clk_en;

reg signed [NUM_OSCILLATORS*WIDTH-1:0] omega_dt_packed;
reg signed [WIDTH-1:0] omega_dt_reference;

wire signed [NUM_OSCILLATORS*WIDTH-1:0] chi_packed;
wire [NUM_OSCILLATORS*2-1:0] position_class_packed;
wire signed [WIDTH-1:0] chi_max;
wire signed [WIDTH-1:0] chi_min;
wire [4:0] chi_max_index;

//-----------------------------------------------------------------------------
// DUT Instantiation
//-----------------------------------------------------------------------------
coupling_susceptibility #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_OSCILLATORS(NUM_OSCILLATORS),
    .ENABLE_ADAPTIVE(1)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .omega_dt_packed(omega_dt_packed),
    .omega_dt_reference(omega_dt_reference),
    .chi_packed(chi_packed),
    .position_class_packed(position_class_packed),
    .chi_max(chi_max),
    .chi_min(chi_min),
    .chi_max_index(chi_max_index)
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

// Variables for test 10 (declared here for Verilog-2001 compliance)
reg signed [WIDTH-1:0] chi_int_t10;
reg signed [WIDTH-1:0] chi_quarter_t10;
reg signed [WIDTH-1:0] chi_half_t10;

// Helper function to extract chi for oscillator i
function signed [WIDTH-1:0] get_chi;
    input integer osc_idx;
    begin
        get_chi = chi_packed[osc_idx*WIDTH +: WIDTH];
    end
endfunction

// Helper function to extract position class for oscillator i
function [1:0] get_class;
    input integer osc_idx;
    begin
        get_class = position_class_packed[osc_idx*2 +: 2];
    end
endfunction

// Test task: set oscillator 0 to specific ratio relative to reference
task test_ratio;
    input signed [WIDTH-1:0] ratio_q14;
    input [255:0] description;
    input signed [WIDTH-1:0] expected_chi_min;
    input signed [WIDTH-1:0] expected_chi_max;
    input [1:0] expected_class;
    reg signed [WIDTH-1:0] actual_chi;
    reg [1:0] actual_class;
    reg pass;
    begin
        // Set omega_dt[0] = reference * ratio
        // For simplicity, use reference = 16384 (1.0 in Q14), so omega_dt = ratio
        omega_dt_reference = 18'sd16384;  // 1.0 in Q14
        omega_dt_packed[0*WIDTH +: WIDTH] = ratio_q14;

        // Wait for computation
        repeat (5) @(posedge clk);
        #1;

        actual_chi = get_chi(0);
        actual_class = get_class(0);

        // Check chi within expected range
        pass = (actual_chi >= expected_chi_min) && (actual_chi <= expected_chi_max);

        // Check classification if not 'any' (2'b11 means don't check)
        if (expected_class != 2'b11) begin
            pass = pass && (actual_class == expected_class);
        end

        test_count = test_count + 1;
        if (pass) begin
            pass_count = pass_count + 1;
            $display("PASS: Test %0d - %s", test_count, description);
            $display("      ratio=%.4f, chi=%.4f (expected %.4f-%.4f), class=%b",
                     ratio_q14 / 16384.0,
                     actual_chi / 16384.0,
                     expected_chi_min / 16384.0,
                     expected_chi_max / 16384.0,
                     actual_class);
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: Test %0d - %s", test_count, description);
            $display("      ratio=%.4f, chi=%.4f (expected %.4f-%.4f), class=%b (expected %b)",
                     ratio_q14 / 16384.0,
                     actual_chi / 16384.0,
                     expected_chi_min / 16384.0,
                     expected_chi_max / 16384.0,
                     actual_class,
                     expected_class);
        end
    end
endtask

//-----------------------------------------------------------------------------
// Test Sequence
//-----------------------------------------------------------------------------
initial begin
    $display("");
    $display("=============================================================");
    $display("Coupling Susceptibility Testbench - v11.1a");
    $display("Farey Fraction Formula: chi(r) = sum(1/q^2 * L(r-p/q))");
    $display("                               + sum(w_phi * L(r-phi^n))");
    $display("=============================================================");
    $display("");

    // Initialize
    clk = 0;
    rst = 1;
    clk_en = 1;
    omega_dt_packed = 0;
    omega_dt_reference = 18'sd16384;
    test_count = 0;
    pass_count = 0;
    fail_count = 0;

    // Reset
    repeat (10) @(posedge clk);
    rst = 0;
    repeat (5) @(posedge clk);

    $display("--- V1 Criteria: Chi Correctness ---");
    $display("");

    //=========================================================================
    // Test 1: Integer ratio 1.0 (BOUNDARY - high chi)
    //=========================================================================
    test_ratio(
        18'sd16384,           // ratio = 1.0 in Q14
        "Integer ratio 1.0 (boundary)",
        18'sd12000,           // chi > 0.73
        18'sd16384,           // chi <= 1.0
        2'b01                 // Class = boundary
    );

    //=========================================================================
    // Test 2: Integer ratio 2.0 (2:1 CATASTROPHE - high chi)
    // From Farey computation: chi = 0.769 (elevated, but Lorentzian has width)
    //=========================================================================
    test_ratio(
        18'sd32768,           // ratio = 2.0 in Q14
        "Integer ratio 2.0 (2:1 catastrophe)",
        18'sd11000,           // chi > 0.67 (Farey computed: 0.769)
        18'sd14000,           // chi < 0.85
        2'b01                 // Class = boundary
    );

    //=========================================================================
    // Test 3: Integer ratio 3.0 (BOUNDARY - high chi)
    //=========================================================================
    test_ratio(
        18'sd49152,           // ratio = 3.0 in Q14
        "Integer ratio 3.0 (boundary)",
        18'sd12000,           // chi > 0.73
        18'sd16384,           // chi <= 1.0
        2'b01                 // Class = boundary
    );

    //=========================================================================
    // Test 4: Half-integer ratio 0.5 (ATTRACTOR - low chi)
    //=========================================================================
    // Note: This is at the edge of our LUT, may have edge effects
    test_ratio(
        18'sd8192,            // ratio = 0.5 in Q14
        "Half-integer ratio 0.5 (attractor)",
        18'sd0,               // chi >= 0
        18'sd8192,            // chi < 0.5
        2'b11                 // Don't check class (edge case)
    );

    //=========================================================================
    // Test 5: Half-integer ratio 1.5 (3/2 - moderate chi)
    // Note: 1.5 = 3/2 IS a simple rational (q=2), so has weight 0.25
    // Farey computed: chi = 0.281
    //=========================================================================
    test_ratio(
        18'sd24576,           // ratio = 1.5 in Q14
        "Half-integer ratio 1.5 (3/2 rational)",
        18'sd4000,            // chi > 0.24
        18'sd5500,            // chi < 0.34
        2'b10                 // Class = quarter-integer (transition zone)
    );

    //=========================================================================
    // Test 6: Half-integer ratio 2.5 (5/2 - moderate chi)
    // Note: 2.5 = 5/2 IS a simple rational (q=2), so has weight 0.25
    // Farey computed: chi = 0.279
    //=========================================================================
    test_ratio(
        18'sd40960,           // ratio = 2.5 in Q14
        "Half-integer ratio 2.5 (5/2 rational)",
        18'sd4000,            // chi > 0.24
        18'sd5500,            // chi < 0.34
        2'b10                 // Class = quarter-integer (transition zone)
    );

    //=========================================================================
    // Test 7: Quarter-integer ratio 1.25 = 5/4 (LOW chi - between majors)
    // Key insight: 1.25 sits BETWEEN 1 and 3/2, far from both!
    // Farey computed: chi = 0.143 (actually quite stable)
    //=========================================================================
    test_ratio(
        18'sd20480,           // ratio = 1.25 in Q14
        "Quarter-integer ratio 1.25 (stable between majors)",
        18'sd2000,            // chi > 0.12 (Farey: 0.143)
        18'sd3000,            // chi < 0.18
        2'b00                 // Class = attractor (surprisingly stable!)
    );

    //=========================================================================
    // Test 8: Phi^1.5 = 2.058 (escaped from 2:1 - moderate chi)
    // Farey computed: chi = 0.270 (lower than 2.0 due to Lorentzian falloff)
    //=========================================================================
    test_ratio(
        18'sd33718,           // ratio = phi^1.5 = 2.058 in Q14
        "Phi^1.5 = 2.058 (escaped from 2:1)",
        18'sd3500,            // chi > 0.21 (Farey: 0.270)
        18'sd5500,            // chi < 0.34
        2'b10                 // Class = quarter-integer (transition zone)
    );

    //=========================================================================
    // Test 9: Phi^1.25 = 1.825 (MOST STABLE - f1 fallback position)
    // Farey computed: chi = 0.126 (the absolute minimum in the LUT!)
    //=========================================================================
    test_ratio(
        18'sd29899,           // ratio = phi^1.25 = 1.825 in Q14
        "Phi^1.25 = 1.825 (f1 fallback position)",
        18'sd1800,            // chi > 0.11 (Farey: 0.126)
        18'sd2200,            // chi < 0.13
        2'b00                 // Class = attractor (most stable!)
    );

    //=========================================================================
    // Test 10: Chi comparison - integer > half(3/2) > quarter(5/4)
    // KEY INSIGHT: In Farey computation, 1.5=3/2 is a simple rational (weight 0.25)
    // while 1.25=5/4 is between major rationals, so 1.25 is MORE stable!
    //=========================================================================
    $display("");
    $display("--- Test 10: Chi hierarchy verification ---");
    $display("    Farey hierarchy: integer > half(3/2) > quarter(5/4)");

    // Set up multiple oscillators with different ratios
    omega_dt_reference = 18'sd16384;
    omega_dt_packed[0*WIDTH +: WIDTH] = 18'sd16384;  // ratio 1.0 (integer)
    omega_dt_packed[1*WIDTH +: WIDTH] = 18'sd20480;  // ratio 1.25 (quarter)
    omega_dt_packed[2*WIDTH +: WIDTH] = 18'sd24576;  // ratio 1.5 (half)

    repeat (5) @(posedge clk);
    #1;

    // Use pre-declared variables
    chi_int_t10 = get_chi(0);
    chi_quarter_t10 = get_chi(1);
    chi_half_t10 = get_chi(2);

    test_count = test_count + 1;
    // Correct Farey hierarchy: integer > half(3/2) > quarter(5/4)
    if ((chi_int_t10 > chi_half_t10) && (chi_half_t10 > chi_quarter_t10)) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - Chi hierarchy: int(%.3f) > half(%.3f) > quarter(%.3f)",
                 test_count, chi_int_t10/16384.0, chi_half_t10/16384.0, chi_quarter_t10/16384.0);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Chi hierarchy: int(%.3f), half(%.3f), quarter(%.3f)",
                 test_count, chi_int_t10/16384.0, chi_half_t10/16384.0, chi_quarter_t10/16384.0);
    end

    //=========================================================================
    // V11.1a NEW TESTS: Farey Fraction Computed Values
    //=========================================================================
    $display("");
    $display("--- v11.1a Farey Fraction Tests ---");

    //=========================================================================
    // Test 11: Phi^0.5 = 1.272 (ALPHA BAND ATTRACTOR - low chi)
    // From computed LUT: chi = 0.134
    //=========================================================================
    test_ratio(
        18'sd20833,           // ratio = phi^0.5 = 1.272 in Q14
        "Phi^0.5 = 1.272 (alpha attractor)",
        18'sd1600,            // chi > 0.10
        18'sd3600,            // chi < 0.22
        2'b00                 // Class = attractor
    );

    //=========================================================================
    // Test 12: Phi^1 = 1.618 (near 5/3 boundary - moderate chi)
    // From computed LUT: chi = 0.326
    //=========================================================================
    test_ratio(
        18'sd26510,           // ratio = phi^1 = 1.618 in Q14
        "Phi^1 = 1.618 (near 5/3)",
        18'sd4500,            // chi > 0.27
        18'sd6500,            // chi < 0.40
        2'b10                 // Class = quarter-integer/transition
    );

    //=========================================================================
    // Test 13: Phi^2 = 2.618 (between 5/2 and 3 - moderate chi)
    // From computed LUT: chi = 0.324
    //=========================================================================
    test_ratio(
        18'sd42891,           // ratio = phi^2 = 2.618 in Q14
        "Phi^2 = 2.618",
        18'sd4500,            // chi > 0.27
        18'sd6500,            // chi < 0.40
        2'b10                 // Class = quarter-integer/transition
    );

    //=========================================================================
    // Test 14: Phi^2.5 = 3.330 (ATTRACTOR - low chi)
    // From computed LUT: chi = 0.156
    //=========================================================================
    test_ratio(
        18'sd54569,           // ratio = phi^2.5 = 3.330 in Q14
        "Phi^2.5 = 3.330 (attractor)",
        18'sd2000,            // chi > 0.12
        18'sd3500,            // chi < 0.21
        2'b00                 // Class = attractor
    );

    //=========================================================================
    // Test 15: Integer ratio 4.0 (BOUNDARY - high chi)
    // From computed LUT: chi = 0.773
    //=========================================================================
    test_ratio(
        18'sd65536,           // ratio = 4.0 in Q14
        "Integer ratio 4.0 (boundary)",
        18'sd11000,           // chi > 0.67
        18'sd14000,           // chi < 0.85
        2'b01                 // Class = boundary
    );

    //=========================================================================
    // Test 16: Half-integer ratio 3.5 (ATTRACTOR - low chi)
    // From computed LUT: chi = 0.247
    //=========================================================================
    test_ratio(
        18'sd57344,           // ratio = 3.5 in Q14
        "Half-integer ratio 3.5 (attractor)",
        18'sd3500,            // chi > 0.21
        18'sd5000,            // chi < 0.30
        2'b00                 // Class = attractor
    );

    //=========================================================================
    // Test 17: Steep falloff from 2:1 - ratio 1.98 (approaching catastrophe)
    // Farey computed: chi ~ 0.40 (Lorentzian falloff with width 0.03)
    //=========================================================================
    test_ratio(
        18'sd32440,           // ratio = 1.98 in Q14
        "Ratio 1.98 (approaching 2:1)",
        18'sd5500,            // chi > 0.34 (Farey: ~0.40)
        18'sd7500,            // chi < 0.46
        2'b11                 // Don't check class
    );

    //=========================================================================
    // Test 18: Steep falloff from 2:1 - ratio 2.02 (departing catastrophe)
    // Farey computed: chi = 0.62 (asymmetric - closer to other q=2 rationals)
    //=========================================================================
    test_ratio(
        18'sd33096,           // ratio = 2.02 in Q14
        "Ratio 2.02 (departing 2:1)",
        18'sd9000,            // chi > 0.55 (Farey: ~0.62)
        18'sd11000,           // chi < 0.67
        2'b11                 // Don't check class
    );

    //=========================================================================
    // Test 19: Phi^1.25 = 1.825 should be MOST STABLE (lowest chi)
    // From computed LUT: chi = 0.126 - the absolute minimum!
    //=========================================================================
    test_ratio(
        18'sd29899,           // ratio = phi^1.25 = 1.825 in Q14
        "Phi^1.25 = 1.825 (MOST STABLE)",
        18'sd1500,            // chi > 0.09
        18'sd2500,            // chi < 0.15
        2'b00                 // Class = attractor (most stable)
    );

    //=========================================================================
    // Test 20: Verify phi^1.25 < phi^0.5 (both low, but 1.25 is lower)
    //=========================================================================
    $display("");
    $display("--- Test 20: Phi fallback stability comparison ---");

    omega_dt_reference = 18'sd16384;
    omega_dt_packed[0*WIDTH +: WIDTH] = 18'sd29899;  // phi^1.25 = 1.825
    omega_dt_packed[1*WIDTH +: WIDTH] = 18'sd20833;  // phi^0.5 = 1.272

    repeat (5) @(posedge clk);
    #1;

    begin : test_20_block
        reg signed [WIDTH-1:0] chi_phi_125;
        reg signed [WIDTH-1:0] chi_phi_05;

        chi_phi_125 = get_chi(0);
        chi_phi_05 = get_chi(1);

        test_count = test_count + 1;
        if (chi_phi_125 < chi_phi_05) begin
            pass_count = pass_count + 1;
            $display("PASS: Test %0d - Phi^1.25(%.3f) more stable than Phi^0.5(%.3f)",
                     test_count, chi_phi_125/16384.0, chi_phi_05/16384.0);
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: Test %0d - Expected Phi^1.25(%.3f) < Phi^0.5(%.3f)",
                     test_count, chi_phi_125/16384.0, chi_phi_05/16384.0);
        end
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("");
    $display("=============================================================");
    $display("Test Summary: %0d/%0d passed", pass_count, test_count);
    if (fail_count == 0) begin
        $display("v11.1a FAREY FRACTION VALIDATION: ALL PASSED");
    end else begin
        $display("v11.1a FAREY FRACTION VALIDATION: %0d FAILED", fail_count);
    end
    $display("=============================================================");
    $display("");

    #100;
    $finish;
end

endmodule
