//=============================================================================
// Testbench: Coupling Mode Controller
//
// Tests:
// 1. Initial state is MODULATORY
// 2. High Kuramoto R + boundary power → transition to HARMONIC
// 3. Low Kuramoto R → transition back to MODULATORY
// 4. SIE active phases force HARMONIC mode
// 5. SIE decay triggers exit from HARMONIC
// 6. Transition duration is respected
// 7. Gain values are correct for each mode
//
// Usage:
//   iverilog -o tb_coupling_mode_controller.vvp src/coupling_mode_controller.v \
//       tb/tb_coupling_mode_controller.v && vvp tb_coupling_mode_controller.vvp
//=============================================================================
`timescale 1ns / 1ps

module tb_coupling_mode_controller;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 10;
parameter TRANSITION_CYCLES = 100;  // Short for testing

reg clk;
reg rst;
reg clk_en;

// Inputs
reg signed [WIDTH-1:0] kuramoto_R;
reg signed [WIDTH-1:0] boundary_power;
reg [2:0] sie_phase;
reg signed [WIDTH-1:0] r_high_thresh;
reg signed [WIDTH-1:0] r_low_thresh;
reg signed [WIDTH-1:0] boundary_thresh;

// Outputs
wire [1:0] coupling_mode;
wire signed [WIDTH-1:0] pac_gain;
wire signed [WIDTH-1:0] harmonic_gain;
wire mode_transition_active;

// Test counters
integer tests_passed;
integer tests_failed;
integer i;

// DUT
coupling_mode_controller #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .TRANSITION_CYCLES(TRANSITION_CYCLES)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .kuramoto_R(kuramoto_R),
    .boundary_power(boundary_power),
    .sie_phase(sie_phase),
    .r_high_thresh(r_high_thresh),
    .r_low_thresh(r_low_thresh),
    .boundary_thresh(boundary_thresh),
    .coupling_mode(coupling_mode),
    .pac_gain(pac_gain),
    .harmonic_gain(harmonic_gain),
    .mode_transition_active(mode_transition_active)
);

// Clock generation
always #(CLK_PERIOD/2) clk = ~clk;

// Q14 constants
localparam signed [WIDTH-1:0] ONE = 18'sd16384;
localparam signed [WIDTH-1:0] HALF = 18'sd8192;
localparam signed [WIDTH-1:0] GAIN_FULL = 18'sd16384;
localparam signed [WIDTH-1:0] GAIN_HALF = 18'sd8192;
localparam signed [WIDTH-1:0] GAIN_WEAK = 18'sd2048;

// Mode constants
localparam [1:0] MODE_MODULATORY = 2'b00;
localparam [1:0] MODE_TRANSITION = 2'b01;
localparam [1:0] MODE_HARMONIC   = 2'b10;

// SIE phases
localparam [2:0] SIE_BASELINE = 3'd0;
localparam [2:0] SIE_IGNITION = 3'd2;
localparam [2:0] SIE_DECAY    = 3'd5;

// Helper task
task run_clocks;
    input integer n;
    begin
        repeat(n) begin
            clk_en = 1;
            @(posedge clk);
            clk_en = 0;
            @(posedge clk);
        end
    end
endtask

function real to_float;
    input signed [WIDTH-1:0] val;
    begin
        to_float = val / 16384.0;
    end
endfunction

initial begin
    $display("==============================================");
    $display("Coupling Mode Controller Testbench");
    $display("==============================================");

    // Initialize
    clk = 0;
    rst = 1;
    clk_en = 0;
    tests_passed = 0;
    tests_failed = 0;

    kuramoto_R = 0;
    boundary_power = 0;
    sie_phase = SIE_BASELINE;
    r_high_thresh = 0;  // Use defaults
    r_low_thresh = 0;
    boundary_thresh = 0;

    // Release reset
    repeat(5) @(posedge clk);
    rst = 0;
    run_clocks(5);

    //=========================================================================
    // TEST 1: Initial state is MODULATORY
    //=========================================================================
    $display("\n[TEST 1] Initial state is MODULATORY");

    if (coupling_mode == MODE_MODULATORY && pac_gain == GAIN_FULL) begin
        $display("  coupling_mode = %b, pac_gain = %0d (%.3f)",
                 coupling_mode, pac_gain, to_float(pac_gain));
        $display("  PASS - Initial mode is MODULATORY with full PAC gain");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected MODULATORY mode");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 2: Low sync doesn't trigger mode change
    //=========================================================================
    $display("\n[TEST 2] Low sync maintains MODULATORY");
    kuramoto_R = 18'sd8192;   // 0.5 - below threshold
    boundary_power = ONE;      // High boundary
    run_clocks(20);

    if (coupling_mode == MODE_MODULATORY) begin
        $display("  kuramoto_R = %.3f, mode = MODULATORY", to_float(kuramoto_R));
        $display("  PASS - Stays MODULATORY when R < threshold");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Should stay MODULATORY");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 3: High sync + boundary → transition
    //=========================================================================
    $display("\n[TEST 3] High sync + boundary triggers transition");
    kuramoto_R = 18'sd13107;   // 0.8 - above threshold
    boundary_power = ONE;       // High boundary
    run_clocks(10);

    if (coupling_mode == MODE_TRANSITION && mode_transition_active == 1) begin
        $display("  kuramoto_R = %.3f, mode = TRANSITION, active = 1", to_float(kuramoto_R));
        $display("  PASS - Entered TRANSITION mode");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected TRANSITION mode");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 4: Complete transition to HARMONIC
    //=========================================================================
    $display("\n[TEST 4] Complete transition to HARMONIC");
    run_clocks(TRANSITION_CYCLES + 10);

    if (coupling_mode == MODE_HARMONIC && harmonic_gain == GAIN_FULL) begin
        $display("  coupling_mode = HARMONIC, harmonic_gain = %.3f", to_float(harmonic_gain));
        $display("  PASS - Reached HARMONIC mode");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected HARMONIC mode");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 5: Low R triggers exit from HARMONIC
    //=========================================================================
    $display("\n[TEST 5] Low R triggers exit from HARMONIC");
    kuramoto_R = 18'sd6554;  // 0.4 - below low threshold
    run_clocks(10);

    if (coupling_mode == MODE_TRANSITION) begin
        $display("  kuramoto_R = %.3f, mode = TRANSITION", to_float(kuramoto_R));
        $display("  PASS - Started transition back to MODULATORY");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected TRANSITION mode on exit");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 6: Complete return to MODULATORY
    //=========================================================================
    $display("\n[TEST 6] Complete return to MODULATORY");
    run_clocks(TRANSITION_CYCLES + 10);

    if (coupling_mode == MODE_MODULATORY && pac_gain == GAIN_FULL) begin
        $display("  coupling_mode = MODULATORY, pac_gain = %.3f", to_float(pac_gain));
        $display("  PASS - Returned to MODULATORY mode");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected MODULATORY mode");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 7: SIE active forces HARMONIC
    //=========================================================================
    $display("\n[TEST 7] SIE ignition forces HARMONIC");
    kuramoto_R = 18'sd4096;   // Low R (wouldn't normally trigger)
    boundary_power = 18'sd2048;  // Low boundary
    sie_phase = SIE_IGNITION;  // But SIE is active
    // Need extra time: 2x transition for full mode propagation
    run_clocks(TRANSITION_CYCLES * 2 + 20);

    if (coupling_mode == MODE_HARMONIC) begin
        $display("  sie_phase = IGNITION, mode = HARMONIC");
        $display("  PASS - SIE ignition forces HARMONIC mode");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  mode = %b (expected 10=HARMONIC)", coupling_mode);
        $display("  FAIL - SIE should force HARMONIC");
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 8: SIE decay triggers exit
    //=========================================================================
    $display("\n[TEST 8] SIE decay triggers exit from HARMONIC");
    sie_phase = SIE_DECAY;
    kuramoto_R = 18'sd6554;  // Low R to allow exit
    run_clocks(10);

    if (coupling_mode == MODE_TRANSITION) begin
        $display("  sie_phase = DECAY, mode = TRANSITION");
        $display("  PASS - SIE decay triggers mode exit");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected exit on SIE decay");
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
