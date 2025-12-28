//=============================================================================
// Testbench for Energy Landscape Module - v11.0
//
// Validates the force computation based on φⁿ energy landscape.
// Tests that:
//   - Forces push oscillators toward half-integer attractors
//   - Harmonic catastrophe zone triggers repulsion
//   - Force magnitude proportional to distance from attractor
//
// 12 tests total covering V2 validation criteria
//=============================================================================
`timescale 1ns / 1ps

module tb_energy_landscape;

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

reg signed [NUM_OSCILLATORS*WIDTH-1:0] n_packed;
reg signed [NUM_OSCILLATORS*WIDTH-1:0] drift_packed;

wire signed [NUM_OSCILLATORS*WIDTH-1:0] force_packed;
wire signed [NUM_OSCILLATORS*WIDTH-1:0] energy_packed;
wire [NUM_OSCILLATORS-1:0] near_harmonic_2_1;

//-----------------------------------------------------------------------------
// DUT Instantiation
//-----------------------------------------------------------------------------
energy_landscape #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_OSCILLATORS(NUM_OSCILLATORS),
    .ENABLE_ADAPTIVE(1)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .n_packed(n_packed),
    .drift_packed(drift_packed),
    .force_packed(force_packed),
    .energy_packed(energy_packed),
    .near_harmonic_2_1(near_harmonic_2_1)
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

// Variables for test 11 and 12 (declared here for Verilog-2001 compliance)
reg signed [WIDTH-1:0] force_far_t11;
reg signed [WIDTH-1:0] force_near_t11;
reg signed [WIDTH-1:0] mag_far_t11;
reg signed [WIDTH-1:0] mag_near_t11;
reg signed [WIDTH-1:0] combined_force_t12;

// Helper function to extract force for oscillator i
function signed [WIDTH-1:0] get_force;
    input integer osc_idx;
    begin
        get_force = force_packed[osc_idx*WIDTH +: WIDTH];
    end
endfunction

// Helper function to extract energy for oscillator i
function signed [WIDTH-1:0] get_energy;
    input integer osc_idx;
    begin
        get_energy = energy_packed[osc_idx*WIDTH +: WIDTH];
    end
endfunction

// Set n value for oscillator 0
task set_n;
    input signed [WIDTH-1:0] n_val;
    begin
        n_packed[0*WIDTH +: WIDTH] = n_val;
        // Wait for LUT and computation
        repeat (5) @(posedge clk);
        #1;
    end
endtask

// Test task: check force at specific n value
task test_force;
    input signed [WIDTH-1:0] n_val;
    input [255:0] description;
    input integer expected_sign;  // -1, 0, or +1
    input signed [WIDTH-1:0] expected_min_magnitude;  // Minimum |force|
    reg signed [WIDTH-1:0] actual_force;
    reg signed [WIDTH-1:0] force_magnitude;
    reg pass;
    integer actual_sign;
    begin
        set_n(n_val);
        actual_force = get_force(0);

        // Determine actual sign
        if (actual_force > 18'sd100) actual_sign = 1;
        else if (actual_force < -18'sd100) actual_sign = -1;
        else actual_sign = 0;

        // Force magnitude
        force_magnitude = (actual_force < 0) ? -actual_force : actual_force;

        // Check sign matches expected
        pass = (actual_sign == expected_sign);

        // Check magnitude if expected non-zero
        if (expected_sign != 0) begin
            pass = pass && (force_magnitude >= expected_min_magnitude);
        end

        test_count = test_count + 1;
        if (pass) begin
            pass_count = pass_count + 1;
            $display("PASS: Test %0d - %s", test_count, description);
            $display("      n=%.4f, force=%.4f (sign=%0d, mag=%.4f)",
                     $itor(n_val)/16384.0,
                     $itor(actual_force)/16384.0,
                     actual_sign,
                     $itor(force_magnitude)/16384.0);
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: Test %0d - %s", test_count, description);
            $display("      n=%.4f, force=%.4f (sign=%0d expected %0d, mag=%.4f min %.4f)",
                     $itor(n_val)/16384.0,
                     $itor(actual_force)/16384.0,
                     actual_sign, expected_sign,
                     $itor(force_magnitude)/16384.0,
                     $itor(expected_min_magnitude)/16384.0);
        end
    end
endtask

//-----------------------------------------------------------------------------
// Test Sequence
//-----------------------------------------------------------------------------
initial begin
    $display("");
    $display("=============================================================");
    $display("Energy Landscape Testbench - v11.0");
    $display("=============================================================");
    $display("");

    // Initialize
    clk = 0;
    rst = 1;
    clk_en = 1;
    n_packed = 0;
    drift_packed = 0;
    test_count = 0;
    pass_count = 0;
    fail_count = 0;

    // Reset
    repeat (10) @(posedge clk);
    rst = 0;
    repeat (5) @(posedge clk);

    $display("--- V2 Criteria: Force Direction ---");
    $display("");

    //=========================================================================
    // Test 1: n = 0.3 (between 0 and 0.5) - should push toward 0.5
    // Energy E = +A×cos(2πn), Force F = -dE/dn = +2πA×sin(2πn)
    // sin(0.6π) = sin(108°) ≈ 0.95 > 0
    // So F > 0, which pushes n UP toward 0.5. ✓
    //=========================================================================
    test_force(
        18'sd4915,            // n = 0.3 in Q14 (0.3 × 16384)
        "n=0.3 (below attractor at 0.5)",
        1,                    // Expect POSITIVE force (pushes UP toward 0.5)
        18'sd1000             // Min magnitude > 0.06
    );

    //=========================================================================
    // Test 2: n = 0.7 (between 0.5 and 1.0) - should push toward 0.5
    // sin(1.4π) = sin(252°) ≈ -0.95 < 0
    // So F < 0, which pushes n DOWN toward 0.5. ✓
    //=========================================================================
    test_force(
        18'sd11469,           // n = 0.7 in Q14
        "n=0.7 (above attractor at 0.5)",
        -1,                   // Expect NEGATIVE force (pushes DOWN toward 0.5)
        18'sd1000             // Min magnitude > 0.06
    );

    //=========================================================================
    // Test 3: n = 0.5 (at attractor) - force should be near zero
    //=========================================================================
    test_force(
        18'sd8192,            // n = 0.5 in Q14
        "n=0.5 (at attractor)",
        0,                    // Expect near-zero force
        18'sd0                // No minimum magnitude
    );

    //=========================================================================
    // Test 4: n = 1.0 (at boundary) - force should be near zero (unstable equilibrium)
    //=========================================================================
    test_force(
        18'sd16384,           // n = 1.0 in Q14
        "n=1.0 (at boundary)",
        0,                    // Expect near-zero force (at max of energy)
        18'sd0
    );

    //=========================================================================
    // Test 5: n = 1.3 (below attractor at 1.5) - should push toward 1.5
    // sin(2.6π) = sin(0.6π) ≈ 0.95 > 0 → F > 0 (pushes UP)
    //=========================================================================
    test_force(
        18'sd21299,           // n = 1.3 in Q14
        "n=1.3 (below attractor at 1.5)",
        1,                    // Expect POSITIVE force (pushes UP toward 1.5)
        18'sd1000
    );

    //=========================================================================
    // Test 6: n = 1.7 (above attractor at 1.5) - should push toward 1.5
    // sin(3.4π) = sin(1.4π) ≈ -0.95 < 0 → F < 0 (pushes DOWN)
    //=========================================================================
    test_force(
        18'sd27853,           // n = 1.7 in Q14
        "n=1.7 (above attractor at 1.5)",
        -1,                   // Expect NEGATIVE force (pushes DOWN toward 1.5)
        18'sd1000
    );

    //=========================================================================
    // Test 7: n = 1.44 (at 2:1 harmonic catastrophe) - near_harmonic flag
    //=========================================================================
    $display("");
    $display("--- Test 7: Harmonic catastrophe detection ---");
    set_n(18'sd23593);  // n = 1.44 in Q14
    test_count = test_count + 1;
    if (near_harmonic_2_1[0] == 1'b1) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - n=1.44 triggers near_harmonic_2_1 flag", test_count);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - n=1.44 should trigger near_harmonic_2_1 flag", test_count);
    end

    //=========================================================================
    // Test 8: n = 1.44 - should have catastrophe repulsion force (NEGATIVE)
    // phi_force ≈ +3788 (pushes UP toward 1.5)
    // catastrophe_force = -12288 (pushes DOWN toward 1.25)
    // combined ≈ -8500 (catastrophe wins, system escapes to 1.25)
    //=========================================================================
    test_force(
        18'sd23593,           // n = 1.44 in Q14
        "n=1.44 (catastrophe zone, repulsion toward 1.25)",
        -1,                   // Expect NEGATIVE force (push down toward 1.25)
        18'sd4000             // Higher magnitude: catastrophe > phi
    );

    //=========================================================================
    // Test 9: n = 1.0 - NOT in catastrophe zone
    //=========================================================================
    $display("");
    $display("--- Test 9: Outside catastrophe zone ---");
    set_n(18'sd16384);  // n = 1.0
    test_count = test_count + 1;
    if (near_harmonic_2_1[0] == 1'b0) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - n=1.0 correctly not in catastrophe zone", test_count);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - n=1.0 should not trigger near_harmonic_2_1", test_count);
    end

    //=========================================================================
    // Test 10: n = 2.5 (at stable attractor, far from any integer)
    //=========================================================================
    test_force(
        18'sd40960,           // n = 2.5 in Q14
        "n=2.5 (stable attractor)",
        0,                    // Expect near-zero force
        18'sd0
    );

    //=========================================================================
    // Test 11: Force magnitude proportional to distance - compare n=0.25 vs n=0.45
    //=========================================================================
    $display("");
    $display("--- Test 11: Force magnitude vs distance ---");

    // n = 0.25 (distance 0.25 from attractor at 0.5)
    set_n(18'sd4096);  // n = 0.25
    force_far_t11 = get_force(0);

    // n = 0.45 (distance 0.05 from attractor at 0.5)
    set_n(18'sd7373);  // n = 0.45
    force_near_t11 = get_force(0);

    mag_far_t11 = (force_far_t11 < 0) ? -force_far_t11 : force_far_t11;
    mag_near_t11 = (force_near_t11 < 0) ? -force_near_t11 : force_near_t11;

    test_count = test_count + 1;
    if (mag_far_t11 > mag_near_t11) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - Force magnitude: far(%.3f) > near(%.3f)",
                 test_count, $itor(mag_far_t11)/16384.0, $itor(mag_near_t11)/16384.0);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Force magnitude: far(%.3f) should > near(%.3f)",
                 test_count, $itor(mag_far_t11)/16384.0, $itor(mag_near_t11)/16384.0);
    end

    //=========================================================================
    // Test 12: Catastrophe force overcomes phi force at n=1.44
    //=========================================================================
    $display("");
    $display("--- Test 12: Catastrophe overcomes phi force ---");

    // At n = 1.44:
    // - phi-landscape pushes UP toward 1.5 (F ≈ +3788)
    // - catastrophe pushes DOWN toward 1.25 (F = -12288)
    // - Combined: catastrophe wins with F ≈ -8500
    set_n(18'sd23593);  // n = 1.44
    combined_force_t12 = get_force(0);

    test_count = test_count + 1;
    // Combined force should be negative (catastrophe wins)
    // Expected: +3788 - 12288 ≈ -8500 (about -0.52)
    if (combined_force_t12 < -18'sd5000) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - Combined force %.3f at catastrophe zone",
                 test_count, $itor(combined_force_t12)/16384.0);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Combined force %.3f should be < -0.30",
                 test_count, $itor(combined_force_t12)/16384.0);
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("");
    $display("=============================================================");
    $display("Test Summary: %0d/%0d passed", pass_count, test_count);
    if (fail_count == 0) begin
        $display("V2 CRITERIA: ALL PASSED");
    end else begin
        $display("V2 CRITERIA: %0d FAILED", fail_count);
    end
    $display("=============================================================");
    $display("");

    #100;
    $finish;
end

endmodule
