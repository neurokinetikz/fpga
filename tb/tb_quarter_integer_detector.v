//=============================================================================
// Testbench for Quarter-Integer Detector - v11.3
//
// Validates position classification in the φⁿ energy landscape:
//   - Integer boundaries correctly detected
//   - Half-integer attractors correctly detected
//   - Quarter-integer fallbacks correctly detected
//   - Catastrophe zone (2:1 harmonic) correctly flagged
//   - Stability metric reasonable for each position type
//
// 8 tests total
//=============================================================================
`timescale 1ns / 1ps

module tb_quarter_integer_detector;

//-----------------------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------------------
parameter WIDTH = 18;
parameter FRAC = 14;
parameter NUM_OSCILLATORS = 21;
parameter CLK_PERIOD = 8;  // 125 MHz

//-----------------------------------------------------------------------------
// Classification codes (match module)
//-----------------------------------------------------------------------------
localparam [1:0] CLASS_INTEGER_BOUNDARY = 2'b00;
localparam [1:0] CLASS_HALF_INTEGER = 2'b01;
localparam [1:0] CLASS_QUARTER_INTEGER = 2'b10;
localparam [1:0] CLASS_NEAR_CATASTROPHE = 2'b11;

//-----------------------------------------------------------------------------
// Signals
//-----------------------------------------------------------------------------
reg clk;
reg rst;
reg clk_en;

reg signed [NUM_OSCILLATORS*WIDTH-1:0] n_packed;

wire [NUM_OSCILLATORS*2-1:0] position_class_packed;
wire signed [NUM_OSCILLATORS*WIDTH-1:0] stability_packed;
wire [NUM_OSCILLATORS-1:0] is_integer_boundary;
wire [NUM_OSCILLATORS-1:0] is_half_integer;
wire [NUM_OSCILLATORS-1:0] is_quarter_integer;
wire [NUM_OSCILLATORS-1:0] is_near_catastrophe;

//-----------------------------------------------------------------------------
// DUT Instantiation
//-----------------------------------------------------------------------------
quarter_integer_detector #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .NUM_OSCILLATORS(NUM_OSCILLATORS)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .n_packed(n_packed),
    .position_class_packed(position_class_packed),
    .stability_packed(stability_packed),
    .is_integer_boundary(is_integer_boundary),
    .is_half_integer(is_half_integer),
    .is_quarter_integer(is_quarter_integer),
    .is_near_catastrophe(is_near_catastrophe)
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

// Variables for test 8 (declared here for Verilog-2001 compliance)
reg signed [WIDTH-1:0] stab_half;
reg signed [WIDTH-1:0] stab_quarter;
reg signed [WIDTH-1:0] stab_boundary;
reg pass_t8;

// Helper function to get position class for oscillator 0
function [1:0] get_class;
    input integer osc_idx;
    begin
        get_class = position_class_packed[osc_idx*2 +: 2];
    end
endfunction

// Helper function to get stability for oscillator 0
function signed [WIDTH-1:0] get_stability;
    input integer osc_idx;
    begin
        get_stability = stability_packed[osc_idx*WIDTH +: WIDTH];
    end
endfunction

// Set n value for oscillator 0
task set_n;
    input signed [WIDTH-1:0] n_val;
    begin
        n_packed[0*WIDTH +: WIDTH] = n_val;
        // Wait for computation
        repeat (3) @(posedge clk);
        #1;
    end
endtask

// Test classification
task test_class;
    input signed [WIDTH-1:0] n_val;
    input [255:0] description;
    input [1:0] expected_class;
    input signed [WIDTH-1:0] min_stability;
    input signed [WIDTH-1:0] max_stability;
    reg [1:0] actual_class;
    reg signed [WIDTH-1:0] actual_stability;
    reg pass;
    begin
        set_n(n_val);
        actual_class = get_class(0);
        actual_stability = get_stability(0);

        pass = (actual_class == expected_class);
        pass = pass && (actual_stability >= min_stability);
        pass = pass && (actual_stability <= max_stability);

        test_count = test_count + 1;
        if (pass) begin
            pass_count = pass_count + 1;
            $display("PASS: Test %0d - %s", test_count, description);
            $display("      n=%.4f, class=%0d (expected %0d), stability=%.3f",
                     $itor(n_val)/16384.0, actual_class, expected_class,
                     $itor(actual_stability)/16384.0);
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: Test %0d - %s", test_count, description);
            $display("      n=%.4f, class=%0d (expected %0d), stability=%.3f (range [%.3f, %.3f])",
                     $itor(n_val)/16384.0, actual_class, expected_class,
                     $itor(actual_stability)/16384.0,
                     $itor(min_stability)/16384.0,
                     $itor(max_stability)/16384.0);
        end
    end
endtask

//-----------------------------------------------------------------------------
// Test Sequence
//-----------------------------------------------------------------------------
initial begin
    $display("");
    $display("=============================================================");
    $display("Quarter-Integer Detector Testbench - v11.3");
    $display("=============================================================");
    $display("");

    // Initialize
    clk = 0;
    rst = 1;
    clk_en = 1;
    n_packed = 0;
    test_count = 0;
    pass_count = 0;
    fail_count = 0;

    // Reset
    repeat (10) @(posedge clk);
    rst = 0;
    repeat (5) @(posedge clk);

    $display("--- Test 1: Integer boundary (n = 1.0) ---");
    // n = 1.0 (integer boundary, unstable)
    test_class(
        18'sd16384,               // n = 1.0 in Q14
        "n=1.0 (integer boundary)",
        CLASS_INTEGER_BOUNDARY,
        18'sd0,                   // Min stability = 0
        18'sd2048                 // Max stability = 0.125 (low)
    );

    $display("");
    $display("--- Test 2: Integer boundary (n = 2.0) ---");
    test_class(
        18'sd32768,               // n = 2.0 in Q14
        "n=2.0 (integer boundary)",
        CLASS_INTEGER_BOUNDARY,
        18'sd0,
        18'sd2048
    );

    $display("");
    $display("--- Test 3: Half-integer attractor (n = 0.5) ---");
    test_class(
        18'sd8192,                // n = 0.5 in Q14
        "n=0.5 (half-integer attractor)",
        CLASS_HALF_INTEGER,
        18'sd14336,               // Min stability = 0.875 (high)
        18'sd16384                // Max stability = 1.0
    );

    $display("");
    $display("--- Test 4: Half-integer attractor (n = 2.5) ---");
    test_class(
        18'sd40960,               // n = 2.5 in Q14
        "n=2.5 (half-integer attractor)",
        CLASS_HALF_INTEGER,
        18'sd14336,               // High stability
        18'sd16384
    );

    $display("");
    $display("--- Test 5: Quarter-integer fallback (n = 1.25) ---");
    test_class(
        18'sd20480,               // n = 1.25 in Q14
        "n=1.25 (quarter-integer fallback)",
        CLASS_QUARTER_INTEGER,
        18'sd4096,                // Min stability = 0.25 (intermediate)
        18'sd8192                 // Max stability = 0.5
    );

    $display("");
    $display("--- Test 6: Quarter-integer fallback (n = 0.75) ---");
    test_class(
        18'sd12288,               // n = 0.75 in Q14
        "n=0.75 (quarter-integer fallback)",
        CLASS_QUARTER_INTEGER,
        18'sd4096,
        18'sd8192
    );

    $display("");
    $display("--- Test 7: Catastrophe zone (n = 1.44) ---");
    // n = 1.44 where φ^1.44 ≈ 2.0 (2:1 harmonic catastrophe)
    test_class(
        18'sd23593,               // n = 1.44 in Q14
        "n=1.44 (2:1 catastrophe zone)",
        CLASS_NEAR_CATASTROPHE,
        18'sd2048,                // Low stability (want to escape)
        18'sd6144
    );

    $display("");
    $display("--- Test 8: Stability ordering check ---");
    // Check that stability follows: half-int > quarter-int > boundary

    set_n(18'sd8192);   // n = 0.5 (half-integer)
    stab_half = get_stability(0);

    set_n(18'sd20480);  // n = 1.25 (quarter-integer)
    stab_quarter = get_stability(0);

    set_n(18'sd16384);  // n = 1.0 (integer boundary)
    stab_boundary = get_stability(0);

    pass_t8 = (stab_half > stab_quarter) && (stab_quarter > stab_boundary);

    test_count = test_count + 1;
    if (pass_t8) begin
        pass_count = pass_count + 1;
        $display("PASS: Test %0d - Stability ordering correct", test_count);
        $display("      half=%.3f > quarter=%.3f > boundary=%.3f",
                 $itor(stab_half)/16384.0,
                 $itor(stab_quarter)/16384.0,
                 $itor(stab_boundary)/16384.0);
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL: Test %0d - Stability ordering incorrect", test_count);
        $display("      half=%.3f, quarter=%.3f, boundary=%.3f",
                 $itor(stab_half)/16384.0,
                 $itor(stab_quarter)/16384.0,
                 $itor(stab_boundary)/16384.0);
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("");
    $display("=============================================================");
    $display("Test Summary: %0d/%0d passed", pass_count, test_count);
    if (fail_count == 0) begin
        $display("QUARTER-INTEGER DETECTOR: ALL TESTS PASSED");
    end else begin
        $display("QUARTER-INTEGER DETECTOR: %0d FAILED", fail_count);
    end
    $display("=============================================================");
    $display("");

    #100;
    $finish;
end

endmodule
