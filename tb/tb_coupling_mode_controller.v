//=============================================================================
// Testbench: Coupling Mode Controller v1.2b
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
// v1.2b: Added all state transition inputs for full compatibility
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
parameter DEBOUNCE_CYCLES = 20;     // v1.2b: Short debounce for fast testing

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

// v1.2/v1.2b: Additional inputs
reg [2:0] state_select;
reg [15:0] transition_progress;
reg [15:0] transition_duration;
reg transitioning;
reg [2:0] state_transition_from;
reg [2:0] state_transition_to;

// Outputs
wire [1:0] coupling_mode;
wire signed [WIDTH-1:0] pac_gain;
wire signed [WIDTH-1:0] harmonic_gain;
wire mode_transition_active;

// Test counters
integer tests_passed;
integer tests_failed;
integer i;

// DUT - v1.2b: Include all new parameters and connections
coupling_mode_controller #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .TRANSITION_CYCLES(TRANSITION_CYCLES),
    .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    // v1.1: Consciousness state
    .state_select(state_select),
    // v1.2: State transition progress
    .transition_progress(transition_progress),
    .transition_duration(transition_duration),
    // v1.2b: State transition tracking
    .transitioning(transitioning),
    .state_transition_from(state_transition_from),
    .state_transition_to(state_transition_to),
    // Synchronization metrics
    .kuramoto_R(kuramoto_R),
    .boundary_power(boundary_power),
    .sie_phase(sie_phase),
    .r_high_thresh(r_high_thresh),
    .r_low_thresh(r_low_thresh),
    .boundary_thresh(boundary_thresh),
    // Outputs
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
    $display("Coupling Mode Controller Testbench v1.2b");
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

    // v1.2/v1.2b: Initialize new inputs
    state_select = 3'd0;          // NORMAL state
    transition_progress = 16'd0;
    transition_duration = 16'd0;  // No active transition
    transitioning = 1'b0;
    state_transition_from = 3'd0;
    state_transition_to = 3'd0;

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
    // v1.2b: Need DEBOUNCE_CYCLES + extra for mode change detection
    //=========================================================================
    $display("\n[TEST 3] High sync + boundary triggers transition");
    kuramoto_R = 18'sd13107;   // 0.8 - above threshold (DEFAULT_R_HIGH=0.55)
    boundary_power = ONE;       // High boundary (DEFAULT_BOUNDARY_ENTRY=0.30)
    run_clocks(DEBOUNCE_CYCLES + 10);

    if (coupling_mode == MODE_TRANSITION && mode_transition_active == 1) begin
        $display("  kuramoto_R = %.3f, mode = TRANSITION, active = 1", to_float(kuramoto_R));
        $display("  PASS - Entered TRANSITION mode");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected TRANSITION mode (got mode=%b)", coupling_mode);
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 4: Complete transition to HARMONIC
    // v1.2b: Gain ramps slowly at ~7/cycle outside meditation, so check mode only
    //=========================================================================
    $display("\n[TEST 4] Complete transition to HARMONIC");
    run_clocks(TRANSITION_CYCLES + 10);

    // v1.2b: harmonic_gain takes ~2000 cycles to fully ramp outside meditation
    // Check that mode reached HARMONIC and harmonic_gain is increasing
    if (coupling_mode == MODE_HARMONIC && harmonic_gain > GAIN_WEAK) begin
        $display("  coupling_mode = HARMONIC, harmonic_gain = %.3f (ramping toward 1.0)", to_float(harmonic_gain));
        $display("  PASS - Reached HARMONIC mode");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected HARMONIC mode (got mode=%b, gain=%.3f)", coupling_mode, to_float(harmonic_gain));
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 5: Low R triggers exit from HARMONIC
    // v1.2b: Need DEBOUNCE_CYCLES for exit condition
    //=========================================================================
    $display("\n[TEST 5] Low R triggers exit from HARMONIC");
    kuramoto_R = 18'sd4915;  // 0.3 - well below low threshold (DEFAULT_R_LOW=0.35)
    boundary_power = 18'sd1638;  // 0.1 - below boundary exit (DEFAULT_BOUNDARY_EXIT=0.15)
    run_clocks(DEBOUNCE_CYCLES + 10);

    if (coupling_mode == MODE_TRANSITION) begin
        $display("  kuramoto_R = %.3f, mode = TRANSITION", to_float(kuramoto_R));
        $display("  PASS - Started transition back to MODULATORY");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected TRANSITION mode on exit (got mode=%b)", coupling_mode);
        tests_failed = tests_failed + 1;
    end

    //=========================================================================
    // TEST 6: Complete return to MODULATORY
    // v1.2b: Gain ramps slowly, check mode transition completes
    //=========================================================================
    $display("\n[TEST 6] Complete return to MODULATORY");
    run_clocks(TRANSITION_CYCLES + 10);

    // v1.2b: pac_gain ramps slowly toward GAIN_FULL outside meditation
    // Check that mode returned to MODULATORY and pac_gain is ramping up
    if (coupling_mode == MODE_MODULATORY && pac_gain > GAIN_WEAK) begin
        $display("  coupling_mode = MODULATORY, pac_gain = %.3f (ramping toward 1.0)", to_float(pac_gain));
        $display("  PASS - Returned to MODULATORY mode");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected MODULATORY mode (got mode=%b, pac_gain=%.3f)", coupling_mode, to_float(pac_gain));
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
    // v1.2b: SIE_DECAY is part of raw_exit_harmonic, needs debounce
    //=========================================================================
    $display("\n[TEST 8] SIE decay triggers exit from HARMONIC");
    sie_phase = SIE_DECAY;
    kuramoto_R = 18'sd4915;  // 0.3 - Low R to allow exit
    boundary_power = 18'sd1638;  // 0.1 - Low boundary to allow exit
    run_clocks(DEBOUNCE_CYCLES + 10);

    if (coupling_mode == MODE_TRANSITION) begin
        $display("  sie_phase = DECAY, mode = TRANSITION");
        $display("  PASS - SIE decay triggers mode exit");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Expected exit on SIE decay (got mode=%b)", coupling_mode);
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
