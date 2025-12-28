//=============================================================================
// Testbench for Coupling Susceptibility Module - v11.0
//
// Validates the chi(r) computation for frequency ratios.
// Tests that:
//   - Integer ratios have HIGH chi (boundaries)
//   - Half-integer ratios have LOW chi (attractors)
//   - Quarter-integers have INTERMEDIATE chi (fallback positions)
//   - The 2:1 harmonic catastrophe zone shows very high chi
//
// 10 tests total covering V1 validation criteria
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
    $display("Coupling Susceptibility Testbench - v11.0");
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
    // Test 2: Integer ratio 2.0 (2:1 CATASTROPHE - very high chi)
    //=========================================================================
    test_ratio(
        18'sd32768,           // ratio = 2.0 in Q14
        "Integer ratio 2.0 (2:1 catastrophe)",
        18'sd14000,           // chi > 0.85
        18'sd16384,           // chi <= 1.0
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
    // Test 5: Half-integer ratio 1.5 (ATTRACTOR - low chi)
    //=========================================================================
    test_ratio(
        18'sd24576,           // ratio = 1.5 in Q14
        "Half-integer ratio 1.5 (attractor)",
        18'sd1000,            // chi > 0.06 (not zero)
        18'sd4096,            // chi < 0.25 (attractor threshold)
        2'b00                 // Class = attractor
    );

    //=========================================================================
    // Test 6: Half-integer ratio 2.5 (ATTRACTOR - low chi)
    //=========================================================================
    test_ratio(
        18'sd40960,           // ratio = 2.5 in Q14
        "Half-integer ratio 2.5 (attractor)",
        18'sd1000,            // chi > 0.06
        18'sd4096,            // chi < 0.25 (attractor threshold)
        2'b00                 // Class = attractor
    );

    //=========================================================================
    // Test 7: Quarter-integer ratio 1.25 (FALLBACK - intermediate chi)
    //=========================================================================
    test_ratio(
        18'sd20480,           // ratio = 1.25 in Q14
        "Quarter-integer ratio 1.25 (fallback)",
        18'sd4096,            // chi > 0.25 (above attractor threshold)
        18'sd9830,            // chi < 0.60 (below boundary zone)
        2'b10                 // Class = quarter-integer
    );

    //=========================================================================
    // Test 8: Phi^1.5 = 2.058 (near 2:1 - HIGH chi, catastrophe zone)
    //=========================================================================
    test_ratio(
        18'sd33718,           // ratio = phi^1.5 = 2.058 in Q14
        "Phi^1.5 = 2.058 (near 2:1 catastrophe)",
        18'sd6000,            // chi > 0.37 (elevated due to 2:1 proximity)
        18'sd12000,           // chi < 0.73 (not as high as exact 2.0)
        2'b11                 // Don't check class (in transition zone)
    );

    //=========================================================================
    // Test 9: Phi^1.25 = 1.825 (quarter-integer FALLBACK for f1)
    //=========================================================================
    test_ratio(
        18'sd29899,           // ratio = phi^1.25 = 1.825 in Q14
        "Phi^1.25 = 1.825 (f1 fallback position)",
        18'sd3000,            // chi > 0.18
        18'sd8000,            // chi < 0.49
        2'b10                 // Class = quarter-integer
    );

    //=========================================================================
    // Test 10: Chi comparison - integer > quarter > half
    //=========================================================================
    $display("");
    $display("--- Test 10: Chi hierarchy verification ---");

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
    if ((chi_int_t10 > chi_quarter_t10) && (chi_quarter_t10 > chi_half_t10)) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - Chi hierarchy: integer(%.3f) > quarter(%.3f) > half(%.3f)",
                 test_count, chi_int_t10/16384.0, chi_quarter_t10/16384.0, chi_half_t10/16384.0);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Chi hierarchy: integer(%.3f), quarter(%.3f), half(%.3f)",
                 test_count, chi_int_t10/16384.0, chi_quarter_t10/16384.0, chi_half_t10/16384.0);
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("");
    $display("=============================================================");
    $display("Test Summary: %0d/%0d passed", pass_count, test_count);
    if (fail_count == 0) begin
        $display("V1 CRITERIA: ALL PASSED");
    end else begin
        $display("V1 CRITERIA: %0d FAILED", fail_count);
    end
    $display("=============================================================");
    $display("");

    #100;
    $finish;
end

endmodule
