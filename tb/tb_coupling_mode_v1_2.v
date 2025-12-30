//=============================================================================
// Testbench: Coupling Mode Controller v1.2
//
// Tests v1.2 specific features:
// 1. State-gated forcing delays HARMONIC until 25% progress
// 2. Debounce prevents chattering near R=0.55
// 3. Wider hysteresis maintains mode through fluctuations
// 4. Boundary exit threshold prevents premature exit
// 5. Combined state forcing + debounce interaction
// 6. Verify transition_progress integration
//
// Usage:
//   iverilog -o tb_coupling_mode_v1_2.vvp src/coupling_mode_controller.v \
//       tb/tb_coupling_mode_v1_2.v && vvp tb_coupling_mode_v1_2.vvp
//=============================================================================
`timescale 1ns / 1ps

module tb_coupling_mode_v1_2;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 10;
parameter TRANSITION_CYCLES = 100;  // Short mode transition for testing
parameter DEBOUNCE_CYCLES = 50;     // Short debounce for testing

reg clk;
reg rst;
reg clk_en;

// Inputs
reg [2:0] state_select;
reg [15:0] transition_progress;
reg [15:0] transition_duration;
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

// DUT - v1.2 with new parameters
coupling_mode_controller #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .TRANSITION_CYCLES(TRANSITION_CYCLES),
    .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .state_select(state_select),
    .transition_progress(transition_progress),
    .transition_duration(transition_duration),
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

// v1.2 threshold values
localparam signed [WIDTH-1:0] R_ENTRY = 18'sd9011;      // 0.55
localparam signed [WIDTH-1:0] R_EXIT = 18'sd5734;       // 0.35
localparam signed [WIDTH-1:0] BND_ENTRY = 18'sd4915;    // 0.30
localparam signed [WIDTH-1:0] BND_EXIT = 18'sd2458;     // 0.15

// Mode constants
localparam [1:0] MODE_MODULATORY = 2'b00;
localparam [1:0] MODE_TRANSITION = 2'b01;
localparam [1:0] MODE_HARMONIC   = 2'b10;

// State constants
localparam [2:0] STATE_NORMAL = 3'd0;
localparam [2:0] STATE_MEDITATION = 3'd4;

// SIE phases
localparam [2:0] SIE_BASELINE = 3'd0;
localparam [2:0] SIE_DECAY = 3'd5;

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
    $display("Coupling Mode Controller v1.2 Testbench");
    $display("==============================================");
    $display("DEBOUNCE_CYCLES = %0d, TRANSITION_CYCLES = %0d", DEBOUNCE_CYCLES, TRANSITION_CYCLES);

    // Initialize
    clk = 0;
    rst = 1;
    clk_en = 0;
    tests_passed = 0;
    tests_failed = 0;

    state_select = STATE_NORMAL;
    transition_progress = 16'd0;
    transition_duration = 16'd80000;  // 20s default
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
    // TEST 1: State-gated forcing delays HARMONIC until 25% progress
    //=========================================================================
    $display("\n[TEST 1] State-gated forcing delays HARMONIC until 25% progress");

    // Set MEDITATION state but progress = 0
    state_select = STATE_MEDITATION;
    transition_progress = 16'd0;
    transition_duration = 16'd80000;
    run_clocks(10);

    if (coupling_mode == MODE_MODULATORY) begin
        $display("  Progress=0: mode=%b (MODULATORY) - PASS", coupling_mode);
        tests_passed = tests_passed + 1;
    end else begin
        $display("  Progress=0: mode=%b - FAIL (expected MODULATORY)", coupling_mode);
        tests_failed = tests_failed + 1;
    end

    // Advance progress to 24% (below gate)
    transition_progress = 16'd15728;  // ~24%
    run_clocks(10);

    if (coupling_mode == MODE_MODULATORY) begin
        $display("  Progress=24%%: mode=%b (MODULATORY) - PASS", coupling_mode);
        tests_passed = tests_passed + 1;
    end else begin
        $display("  Progress=24%%: mode=%b - FAIL (expected MODULATORY)", coupling_mode);
        tests_failed = tests_failed + 1;
    end

    // Advance progress to 26% (above gate) - should trigger transition
    transition_progress = 16'd17039;  // ~26%
    run_clocks(10);

    if (coupling_mode == MODE_TRANSITION || mode_transition_active) begin
        $display("  Progress=26%%: mode=%b transition_active=%b - PASS", coupling_mode, mode_transition_active);
        tests_passed = tests_passed + 1;
    end else begin
        $display("  Progress=26%%: mode=%b - FAIL (expected TRANSITION or active)", coupling_mode);
        tests_failed = tests_failed + 1;
    end

    // Reset state
    state_select = STATE_NORMAL;
    transition_progress = 16'd0;
    run_clocks(TRANSITION_CYCLES + 50);  // Let mode settle

    //=========================================================================
    // TEST 2: Debounce prevents chattering near R=0.55
    //=========================================================================
    $display("\n[TEST 2] Debounce prevents chattering near R threshold");

    // Start in MODULATORY, set R just above entry threshold
    kuramoto_R = R_ENTRY + 100;  // 0.556
    boundary_power = BND_ENTRY + 100;  // 0.306

    // Run fewer cycles than DEBOUNCE_CYCLES
    run_clocks(DEBOUNCE_CYCLES / 2);

    if (coupling_mode == MODE_MODULATORY) begin
        $display("  After %0d cycles (< debounce): mode=%b (MODULATORY) - PASS",
                 DEBOUNCE_CYCLES/2, coupling_mode);
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Should still be MODULATORY during debounce");
        tests_failed = tests_failed + 1;
    end

    // Drop R briefly (simulating fluctuation)
    kuramoto_R = R_ENTRY - 100;
    run_clocks(5);
    kuramoto_R = R_ENTRY + 100;

    // Counter should have reset, run partial debounce again
    run_clocks(DEBOUNCE_CYCLES / 2);

    if (coupling_mode == MODE_MODULATORY) begin
        $display("  After fluctuation + partial debounce: mode=%b (MODULATORY) - PASS", coupling_mode);
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Fluctuation should have reset debounce counter");
        tests_failed = tests_failed + 1;
    end

    // Now hold steady for full debounce duration
    run_clocks(DEBOUNCE_CYCLES + 10);

    if (coupling_mode != MODE_MODULATORY) begin
        $display("  After full debounce: mode=%b (transitioning) - PASS", coupling_mode);
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Should have started transition after debounce");
        tests_failed = tests_failed + 1;
    end

    // Let transition complete to HARMONIC
    run_clocks(TRANSITION_CYCLES + 10);

    //=========================================================================
    // TEST 3: Wider hysteresis maintains mode through fluctuations
    //=========================================================================
    $display("\n[TEST 3] Wider hysteresis (20%% R band)");

    // Should now be in HARMONIC mode
    if (coupling_mode == MODE_HARMONIC) begin
        $display("  Starting in HARMONIC mode - PASS");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  WARNING - Not in HARMONIC, mode=%b", coupling_mode);
    end

    // Drop R to 0.45 (between old 0.4 exit and new 0.35 exit)
    kuramoto_R = 18'sd7373;  // 0.45
    run_clocks(DEBOUNCE_CYCLES + 10);

    if (coupling_mode == MODE_HARMONIC) begin
        $display("  R=0.45 (above new exit 0.35): mode=%b (HARMONIC) - PASS", coupling_mode);
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Should stay HARMONIC at R=0.45 (above new exit threshold 0.35)");
        tests_failed = tests_failed + 1;
    end

    // Now drop R to 0.30 (below exit threshold 0.35)
    kuramoto_R = 18'sd4915;  // 0.30
    run_clocks(DEBOUNCE_CYCLES + TRANSITION_CYCLES + 20);

    if (coupling_mode != MODE_HARMONIC) begin
        $display("  R=0.30 (below exit 0.35): mode=%b (exited) - PASS", coupling_mode);
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Should have exited HARMONIC at R=0.30");
        tests_failed = tests_failed + 1;
    end

    // Reset
    kuramoto_R = 0;
    boundary_power = 0;
    run_clocks(TRANSITION_CYCLES + 50);

    //=========================================================================
    // TEST 4: Boundary exit threshold prevents premature exit
    //=========================================================================
    $display("\n[TEST 4] Boundary exit threshold (0.15)");

    // Enter HARMONIC mode
    kuramoto_R = R_ENTRY + 500;
    boundary_power = BND_ENTRY + 500;
    run_clocks(DEBOUNCE_CYCLES + TRANSITION_CYCLES + 20);

    if (coupling_mode == MODE_HARMONIC) begin
        $display("  Entered HARMONIC mode - PASS");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  WARNING - Failed to enter HARMONIC");
    end

    // Drop boundary to 0.20 (between entry 0.30 and exit 0.15)
    boundary_power = 18'sd3277;  // 0.20
    run_clocks(DEBOUNCE_CYCLES + 10);

    if (coupling_mode == MODE_HARMONIC) begin
        $display("  Boundary=0.20 (above exit 0.15): mode=%b (HARMONIC) - PASS", coupling_mode);
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Should stay HARMONIC at boundary=0.20");
        tests_failed = tests_failed + 1;
    end

    // Drop boundary to 0.10 (below exit 0.15)
    boundary_power = 18'sd1638;  // 0.10
    run_clocks(DEBOUNCE_CYCLES + TRANSITION_CYCLES + 20);

    if (coupling_mode != MODE_HARMONIC) begin
        $display("  Boundary=0.10 (below exit 0.15): mode=%b (exited) - PASS", coupling_mode);
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - Should have exited HARMONIC at boundary=0.10");
        tests_failed = tests_failed + 1;
    end

    // Reset
    kuramoto_R = 0;
    boundary_power = 0;
    run_clocks(TRANSITION_CYCLES + 50);

    //=========================================================================
    // TEST 5: State forcing bypasses debounce
    //=========================================================================
    $display("\n[TEST 5] State forcing bypasses metric debounce");

    // Set MEDITATION with progress above gate (instant should work)
    state_select = STATE_MEDITATION;
    transition_progress = 16'd20000;  // 30%
    transition_duration = 16'd80000;

    // Should immediately trigger transition (no debounce wait)
    run_clocks(5);

    if (mode_transition_active || coupling_mode == MODE_TRANSITION) begin
        $display("  MEDITATION state immediately triggers transition - PASS");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - State forcing should bypass debounce");
        tests_failed = tests_failed + 1;
    end

    // Reset
    state_select = STATE_NORMAL;
    transition_progress = 16'd0;
    run_clocks(TRANSITION_CYCLES + 50);

    //=========================================================================
    // TEST 6: transition_duration=0 means instant forcing
    //=========================================================================
    $display("\n[TEST 6] transition_duration=0 enables instant state forcing");

    // Set MEDITATION with duration=0 (instant mode, no gate)
    state_select = STATE_MEDITATION;
    transition_progress = 16'd0;  // Progress is 0 but duration=0 bypasses gate
    transition_duration = 16'd0;

    run_clocks(5);

    if (mode_transition_active || coupling_mode == MODE_TRANSITION) begin
        $display("  duration=0 bypasses progress gate - PASS");
        tests_passed = tests_passed + 1;
    end else begin
        $display("  FAIL - duration=0 should bypass progress gate");
        tests_failed = tests_failed + 1;
    end

    // Reset
    state_select = STATE_NORMAL;
    transition_duration = 16'd80000;
    run_clocks(TRANSITION_CYCLES + 50);

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n==============================================");
    $display("Test Summary: %0d passed, %0d failed", tests_passed, tests_failed);
    $display("==============================================");

    if (tests_failed == 0)
        $display("ALL TESTS PASSED!");
    else
        $display("SOME TESTS FAILED");

    $finish;
end

endmodule
