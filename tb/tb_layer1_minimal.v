//=============================================================================
// Testbench for Layer 1 Minimal Module - v8.7 with Matrix Thalamic Input
//
// Tests the full L1 gain modulation including matrix thalamic input:
// 1. All inputs=0 -> gain=1.0 (baseline)
// 2. Matrix only -> gain modulation (0.15 weight)
// 3. fb1=+1.0, fb2=0 -> gain=1.3 (adjacent only)
// 4. fb1=0, fb2=+1.0 -> gain=1.2 (distant only)
// 5. All inputs positive -> gain=1.5 (max enhancement)
// 6. All inputs negative -> gain=0.5 (max suppression)
// 7. Verify gain clamping at boundaries
// 8. Mixed positive/negative inputs
//=============================================================================
`timescale 1ns / 1ps

module tb_layer1_minimal;

parameter WIDTH = 18;
parameter FRAC = 14;

// Clock and reset
reg clk;
reg rst;
reg clk_en;

// Inputs - v9.2: Matrix thalamic + Dual feedback
reg signed [WIDTH-1:0] matrix_thalamic_input;
reg signed [WIDTH-1:0] feedback_input_1;
reg signed [WIDTH-1:0] feedback_input_2;

// Outputs
wire signed [WIDTH-1:0] apical_gain;

// Expected values (Q4.14)
localparam signed [WIDTH-1:0] GAIN_1_0 = 18'sd16384;  // 1.0
localparam signed [WIDTH-1:0] GAIN_0_5 = 18'sd8192;   // 0.5
localparam signed [WIDTH-1:0] GAIN_1_5 = 18'sd24576;  // 1.5
localparam signed [WIDTH-1:0] ONE = 18'sd16384;       // 1.0 for input

// v9.1: Weights for gain calculation (match layer1_minimal.v)
// K_FB1 = 0.3 (4915), K_FB2 = 0.2 (3277)
// gain = 1.0 + 0.3*fb1 + 0.2*fb2

// Tolerance for comparison (increased for dual weight rounding)
localparam signed [WIDTH-1:0] TOLERANCE = 18'sd100;  // ~0.006

// Test tracking
integer tests_passed;
integer tests_failed;

// Instantiate DUT
layer1_minimal #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .matrix_thalamic_input(matrix_thalamic_input),  // v9.2
    .feedback_input_1(feedback_input_1),
    .feedback_input_2(feedback_input_2),
    .apical_gain(apical_gain)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100 MHz
end

// Helper function to check value within tolerance
function automatic check_value;
    input signed [WIDTH-1:0] actual;
    input signed [WIDTH-1:0] expected;
    input signed [WIDTH-1:0] tol;
    reg signed [WIDTH-1:0] diff;
    begin
        diff = actual - expected;
        if (diff < 0) diff = -diff;
        check_value = (diff <= tol);
    end
endfunction

// Helper to display Q14 value as decimal
function real q14_to_real;
    input signed [WIDTH-1:0] val;
    begin
        q14_to_real = $itor(val) / 16384.0;
    end
endfunction

// Report test result
task report_test;
    input [255:0] test_name;
    input pass;
    begin
        if (pass) begin
            $display("[PASS] %s", test_name);
            tests_passed = tests_passed + 1;
        end else begin
            $display("[FAIL] %s", test_name);
            tests_failed = tests_failed + 1;
        end
    end
endtask

// Main test sequence
initial begin
    $display("===========================================");
    $display("Layer 1 Minimal Testbench - v8.7 Matrix Thalamic");
    $display("===========================================");

    tests_passed = 0;
    tests_failed = 0;

    // Initialize
    rst = 1;
    clk_en = 1;
    matrix_thalamic_input = 0;  // v9.2
    feedback_input_1 = 0;
    feedback_input_2 = 0;

    // Reset
    repeat(10) @(posedge clk);
    rst = 0;
    repeat(5) @(posedge clk);

    //=========================================================================
    // TEST 1: All inputs=0 -> unity gain (1.0)
    //=========================================================================
    $display("\n--- TEST 1: All inputs=0 -> unity gain ---");
    matrix_thalamic_input = 0;
    feedback_input_1 = 0;
    feedback_input_2 = 0;
    @(posedge clk);
    #1;

    $display("matrix = %.4f, fb1 = %.4f, fb2 = %.4f",
             q14_to_real(matrix_thalamic_input), q14_to_real(feedback_input_1), q14_to_real(feedback_input_2));
    $display("apical_gain = %d (%.4f)", apical_gain, q14_to_real(apical_gain));
    $display("expected = %d (%.4f)", GAIN_1_0, q14_to_real(GAIN_1_0));

    report_test("all inputs=0 -> gain=1.0", check_value(apical_gain, GAIN_1_0, TOLERANCE));

    //=========================================================================
    // TEST 2: Matrix only +1.0 -> gain=1.15
    // gain = 1.0 + 0.15*1.0 + 0.3*0 + 0.2*0 = 1.15 = 18842
    //=========================================================================
    $display("\n--- TEST 2: Matrix thalamic only (+1.0) ---");
    matrix_thalamic_input = ONE;  // +1.0
    feedback_input_1 = 0;
    feedback_input_2 = 0;
    @(posedge clk);
    #1;

    $display("matrix = %.4f, fb1 = %.4f, fb2 = %.4f",
             q14_to_real(matrix_thalamic_input), q14_to_real(feedback_input_1), q14_to_real(feedback_input_2));
    $display("apical_gain = %d (%.4f)", apical_gain, q14_to_real(apical_gain));
    // Expected: 1.0 + 0.15*1.0 = 1.15 = 18842
    $display("expected ~= 18842 (1.15)");

    report_test("matrix=+1.0, fb=0 -> gain~1.15", check_value(apical_gain, 18'sd18842, TOLERANCE));

    //=========================================================================
    // TEST 3: fb1=+1.0, fb2=0 -> gain=1.3 (adjacent only)
    // gain = 1.0 + 0.15*0 + 0.3*1.0 + 0.2*0 = 1.3 = 21299
    //=========================================================================
    $display("\n--- TEST 3: Adjacent feedback only (+1.0) ---");
    matrix_thalamic_input = 0;
    feedback_input_1 = ONE;  // +1.0
    feedback_input_2 = 0;
    @(posedge clk);
    #1;

    $display("matrix = %.4f, fb1 = %.4f, fb2 = %.4f",
             q14_to_real(matrix_thalamic_input), q14_to_real(feedback_input_1), q14_to_real(feedback_input_2));
    $display("apical_gain = %d (%.4f)", apical_gain, q14_to_real(apical_gain));
    // Expected: 1.0 + 0.3*1.0 = 1.3 = 21299
    $display("expected ~= 21299 (1.30)");

    report_test("fb1=+1.0, fb2=0 -> gain~1.3", check_value(apical_gain, 18'sd21299, TOLERANCE));

    //=========================================================================
    // TEST 4: fb1=0, fb2=+1.0 -> gain=1.2 (distant only)
    // gain = 1.0 + 0.15*0 + 0.3*0 + 0.2*1.0 = 1.2 = 19661
    //=========================================================================
    $display("\n--- TEST 4: Distant feedback only (+1.0) ---");
    matrix_thalamic_input = 0;
    feedback_input_1 = 0;
    feedback_input_2 = ONE;  // +1.0
    @(posedge clk);
    #1;

    $display("matrix = %.4f, fb1 = %.4f, fb2 = %.4f",
             q14_to_real(matrix_thalamic_input), q14_to_real(feedback_input_1), q14_to_real(feedback_input_2));
    $display("apical_gain = %d (%.4f)", apical_gain, q14_to_real(apical_gain));
    // Expected: 1.0 + 0.2*1.0 = 1.2 = 19661
    $display("expected ~= 19661 (1.20)");

    report_test("fb1=0, fb2=+1.0 -> gain~1.2", check_value(apical_gain, 18'sd19661, TOLERANCE));

    //=========================================================================
    // TEST 5: All inputs positive -> gain=1.5 (clamped max)
    // gain = 1.0 + 0.15*1.0 + 0.3*1.0 + 0.2*1.0 = 1.65 -> clamped to 1.5
    //=========================================================================
    $display("\n--- TEST 5: All inputs +1.0 -> max gain (clamped) ---");
    matrix_thalamic_input = ONE;
    feedback_input_1 = ONE;
    feedback_input_2 = ONE;
    @(posedge clk);
    #1;

    $display("matrix = %.4f, fb1 = %.4f, fb2 = %.4f",
             q14_to_real(matrix_thalamic_input), q14_to_real(feedback_input_1), q14_to_real(feedback_input_2));
    $display("apical_gain = %d (%.4f)", apical_gain, q14_to_real(apical_gain));
    $display("expected = %d (%.4f) [clamped]", GAIN_1_5, q14_to_real(GAIN_1_5));

    report_test("all inputs=+1.0 -> gain=1.5 (clamped)", check_value(apical_gain, GAIN_1_5, TOLERANCE));

    //=========================================================================
    // TEST 6: All inputs negative -> gain=0.5 (clamped min)
    // gain = 1.0 + 0.15*(-1) + 0.3*(-1) + 0.2*(-1) = 0.35 -> clamped to 0.5
    //=========================================================================
    $display("\n--- TEST 6: All inputs -1.0 -> min gain (clamped) ---");
    matrix_thalamic_input = -ONE;
    feedback_input_1 = -ONE;
    feedback_input_2 = -ONE;
    @(posedge clk);
    #1;

    $display("matrix = %.4f, fb1 = %.4f, fb2 = %.4f",
             q14_to_real(matrix_thalamic_input), q14_to_real(feedback_input_1), q14_to_real(feedback_input_2));
    $display("apical_gain = %d (%.4f)", apical_gain, q14_to_real(apical_gain));
    $display("expected = %d (%.4f) [clamped]", GAIN_0_5, q14_to_real(GAIN_0_5));

    report_test("all inputs=-1.0 -> gain=0.5 (clamped)", check_value(apical_gain, GAIN_0_5, TOLERANCE));

    //=========================================================================
    // TEST 7: Clamping - extreme positive should clamp at 1.5
    //=========================================================================
    $display("\n--- TEST 7: Extreme positive clamping ---");
    matrix_thalamic_input = 18'sd32768;  // +2.0
    feedback_input_1 = 18'sd32768;  // +2.0
    feedback_input_2 = 18'sd32768;  // +2.0
    @(posedge clk);
    #1;

    $display("matrix = %.4f, fb1 = %.4f, fb2 = %.4f",
             q14_to_real(matrix_thalamic_input), q14_to_real(feedback_input_1), q14_to_real(feedback_input_2));
    $display("apical_gain = %d (%.4f)", apical_gain, q14_to_real(apical_gain));
    $display("expected max = %d (%.4f)", GAIN_1_5, q14_to_real(GAIN_1_5));

    report_test("extreme positive clamped at 1.5", check_value(apical_gain, GAIN_1_5, TOLERANCE));

    //=========================================================================
    // TEST 8: Clamping - extreme negative should clamp at 0.5
    //=========================================================================
    $display("\n--- TEST 8: Extreme negative clamping ---");
    matrix_thalamic_input = -18'sd32768;  // -2.0
    feedback_input_1 = -18'sd32768;  // -2.0
    feedback_input_2 = -18'sd32768;  // -2.0
    @(posedge clk);
    #1;

    $display("matrix = %.4f, fb1 = %.4f, fb2 = %.4f",
             q14_to_real(matrix_thalamic_input), q14_to_real(feedback_input_1), q14_to_real(feedback_input_2));
    $display("apical_gain = %d (%.4f)", apical_gain, q14_to_real(apical_gain));
    $display("expected min = %d (%.4f)", GAIN_0_5, q14_to_real(GAIN_0_5));

    report_test("extreme negative clamped at 0.5", check_value(apical_gain, GAIN_0_5, TOLERANCE));

    //=========================================================================
    // TEST 9: Mixed - matrix positive, feedbacks negative
    // gain = 1.0 + 0.15*1.0 + 0.3*(-1.0) + 0.2*(-1.0) = 0.65
    //=========================================================================
    $display("\n--- TEST 9: Matrix+, feedbacks- ---");
    matrix_thalamic_input = ONE;   // +1.0
    feedback_input_1 = -ONE;  // -1.0
    feedback_input_2 = -ONE;  // -1.0
    @(posedge clk);
    #1;

    $display("matrix = %.4f, fb1 = %.4f, fb2 = %.4f",
             q14_to_real(matrix_thalamic_input), q14_to_real(feedback_input_1), q14_to_real(feedback_input_2));
    $display("apical_gain = %d (%.4f)", apical_gain, q14_to_real(apical_gain));
    // Expected: 1.0 + 0.15 - 0.3 - 0.2 = 0.65 = 10650
    $display("expected ~= 10650 (0.65)");

    report_test("matrix+, fb- -> gain~0.65", check_value(apical_gain, 18'sd10650, TOLERANCE));

    //=========================================================================
    // TEST 10: Mixed - matrix negative, feedbacks positive
    // gain = 1.0 + 0.15*(-1.0) + 0.3*1.0 + 0.2*1.0 = 1.35
    //=========================================================================
    $display("\n--- TEST 10: Matrix-, feedbacks+ ---");
    matrix_thalamic_input = -ONE;  // -1.0
    feedback_input_1 = ONE;   // +1.0
    feedback_input_2 = ONE;   // +1.0
    @(posedge clk);
    #1;

    $display("matrix = %.4f, fb1 = %.4f, fb2 = %.4f",
             q14_to_real(matrix_thalamic_input), q14_to_real(feedback_input_1), q14_to_real(feedback_input_2));
    $display("apical_gain = %d (%.4f)", apical_gain, q14_to_real(apical_gain));
    // Expected: 1.0 - 0.15 + 0.3 + 0.2 = 1.35 = 22118
    $display("expected ~= 22118 (1.35)");

    report_test("matrix-, fb+ -> gain~1.35", check_value(apical_gain, 18'sd22118, TOLERANCE));

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n===========================================");
    $display("TEST SUMMARY");
    $display("===========================================");
    $display("Tests passed: %d", tests_passed);
    $display("Tests failed: %d", tests_failed);
    $display("Total tests:  %d", tests_passed + tests_failed);

    if (tests_failed == 0) begin
        $display("\n*** ALL TESTS PASSED ***");
    end else begin
        $display("\n*** SOME TESTS FAILED ***");
    end

    $display("===========================================\n");

    #100;
    $finish;
end

endmodule
