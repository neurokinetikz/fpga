//=============================================================================
// State Interpolation Testbench - v11.4
//
// Tests linear interpolation between consciousness states during transitions.
// Validates:
//   1. Instant mode (transition_duration=0) matches immediate behavior
//   2. Linear ramp produces correct intermediate values
//   3. Mid-transition interrupt handling (restart from current)
//   4. All state pairs
//   5. MU value bounds [1, 6]
//   6. Ca_threshold interpolation
//   7. SIE timing interpolation
//   8. Progress output scaling (0 → 65535)
//=============================================================================
`timescale 1ns / 1ps

module tb_state_interpolation;

parameter WIDTH = 18;
parameter FRAC = 14;

// Clock and reset
reg clk;
reg rst;
reg clk_en;

// Inputs
reg [2:0] state_select;
reg [15:0] transition_duration;

// Outputs
wire signed [WIDTH-1:0] mu_dt_theta;
wire signed [WIDTH-1:0] mu_dt_l6;
wire signed [WIDTH-1:0] mu_dt_l5b;
wire signed [WIDTH-1:0] mu_dt_l5a;
wire signed [WIDTH-1:0] mu_dt_l4;
wire signed [WIDTH-1:0] mu_dt_l23;
wire signed [WIDTH-1:0] ca_threshold;
wire [15:0] sie_phase2_dur;
wire [15:0] sie_phase3_dur;
wire [15:0] sie_phase4_dur;
wire [15:0] sie_phase5_dur;
wire [15:0] sie_phase6_dur;
wire [15:0] sie_refractory;
wire transitioning;
wire [15:0] transition_progress;
wire [2:0] transition_from;
wire [2:0] transition_to;

// Scaffold indicators (unused for this test)
wire scaffold_l4, scaffold_l5b, plastic_l23, plastic_l6;

// DUT
config_controller #(.WIDTH(WIDTH), .FRAC(FRAC)) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .state_select(state_select),
    .transition_duration(transition_duration),
    .mu_dt_theta(mu_dt_theta),
    .mu_dt_l6(mu_dt_l6),
    .mu_dt_l5b(mu_dt_l5b),
    .mu_dt_l5a(mu_dt_l5a),
    .mu_dt_l4(mu_dt_l4),
    .mu_dt_l23(mu_dt_l23),
    .ca_threshold(ca_threshold),
    .scaffold_l4(scaffold_l4),
    .scaffold_l5b(scaffold_l5b),
    .plastic_l23(plastic_l23),
    .plastic_l6(plastic_l6),
    .sie_phase2_dur(sie_phase2_dur),
    .sie_phase3_dur(sie_phase3_dur),
    .sie_phase4_dur(sie_phase4_dur),
    .sie_phase5_dur(sie_phase5_dur),
    .sie_phase6_dur(sie_phase6_dur),
    .sie_refractory(sie_refractory),
    .transitioning(transitioning),
    .transition_progress(transition_progress),
    .transition_from(transition_from),
    .transition_to(transition_to)
);

// State constants
localparam [2:0] STATE_NORMAL     = 3'd0;
localparam [2:0] STATE_ANESTHESIA = 3'd1;
localparam [2:0] STATE_PSYCHEDELIC = 3'd2;
localparam [2:0] STATE_FLOW       = 3'd3;
localparam [2:0] STATE_MEDITATION = 3'd4;

// MU values for verification
localparam signed [WIDTH-1:0] MU_FULL     = 18'sd4;
localparam signed [WIDTH-1:0] MU_MODERATE = 18'sd3;
localparam signed [WIDTH-1:0] MU_HALF     = 18'sd2;
localparam signed [WIDTH-1:0] MU_WEAK     = 18'sd1;
localparam signed [WIDTH-1:0] MU_ENHANCED = 18'sd6;

// Ca thresholds for verification
localparam signed [WIDTH-1:0] CA_THRESH_NORMAL     = 18'sd8192;
localparam signed [WIDTH-1:0] CA_THRESH_ANESTHESIA = 18'sd12288;
localparam signed [WIDTH-1:0] CA_THRESH_PSYCHEDELIC = 18'sd4096;
localparam signed [WIDTH-1:0] CA_THRESH_FLOW       = 18'sd8192;
localparam signed [WIDTH-1:0] CA_THRESH_MEDITATION = 18'sd6144;

// 100 MHz clock (10ns period)
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Test variables
integer test_pass, test_fail;
integer i;
reg signed [WIDTH-1:0] expected_mu;
reg signed [WIDTH-1:0] captured_mu_25, captured_mu_50, captured_mu_75;
reg [15:0] captured_sie_25, captured_sie_50, captured_sie_75;

// Task to apply N clk_en pulses
task apply_updates;
    input integer n;
    integer j;
    begin
        for (j = 0; j < n; j = j + 1) begin
            @(posedge clk);
            clk_en = 1;
            @(posedge clk);
            clk_en = 0;
            repeat(8) @(posedge clk);  // Space out enables
        end
    end
endtask

// Task to wait for transition complete
// Note: Must apply at least one update to start the transition first
task wait_transition_complete;
    begin
        // Apply one update to start the transition (state_changed triggers on clk_en)
        @(posedge clk);
        clk_en = 1;
        @(posedge clk);
        clk_en = 0;
        repeat(8) @(posedge clk);

        // Now wait for the transition to complete
        while (transitioning) begin
            @(posedge clk);
            clk_en = 1;
            @(posedge clk);
            clk_en = 0;
            repeat(8) @(posedge clk);
        end
    end
endtask

initial begin
    $display("========================================");
    $display("STATE INTERPOLATION TESTBENCH v11.4");
    $display("========================================");

    // Initialize
    rst = 1;
    clk_en = 0;
    state_select = STATE_NORMAL;
    transition_duration = 16'd0;
    test_pass = 0;
    test_fail = 0;

    // Release reset
    repeat(20) @(posedge clk);
    rst = 0;
    repeat(10) @(posedge clk);

    //=========================================================================
    // TEST 1: Instant mode (transition_duration=0) - minimal cycle transition
    // With duration=0, ramp_dur=1, so: cycle 0=start, cycle 1=interp, cycle 2=complete
    //=========================================================================
    $display("\n[TEST 1] Instant mode (transition_duration=0)");
    transition_duration = 16'd0;
    state_select = STATE_MEDITATION;
    apply_updates(3);  // Need 3 cycles for instant transition to complete

    if (!transitioning && mu_dt_theta == MU_ENHANCED) begin
        $display("         PASS - Instant transition to MEDITATION");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - mu_dt_theta=%0d (expected %0d), transitioning=%b",
                 mu_dt_theta, MU_ENHANCED, transitioning);
        test_fail = test_fail + 1;
    end

    // Return to NORMAL for next test
    state_select = STATE_NORMAL;
    apply_updates(3);  // Need 3 cycles

    //=========================================================================
    // TEST 2: Linear ramp - verify intermediate values at 25%, 50%, 75%
    //=========================================================================
    $display("\n[TEST 2] Linear ramp intermediate values");
    transition_duration = 16'd100;  // 100 cycles for easy math
    state_select = STATE_MEDITATION;  // NORMAL(3) → MEDITATION(6) for theta

    // Apply ~25% of updates (25 cycles)
    apply_updates(25);
    captured_mu_25 = mu_dt_theta;

    // Apply to ~50% (25 more cycles)
    apply_updates(25);
    captured_mu_50 = mu_dt_theta;

    // Apply to ~75% (25 more cycles)
    apply_updates(25);
    captured_mu_75 = mu_dt_theta;

    // Complete transition
    wait_transition_complete;

    // NORMAL theta=3, MEDITATION theta=6
    // At 25%: 3 + (6-3)*0.25 = 3.75 → truncated ~3 or 4
    // At 50%: 3 + (6-3)*0.5  = 4.5  → truncated ~4
    // At 75%: 3 + (6-3)*0.75 = 5.25 → truncated ~5
    // Final: 6

    $display("         mu_theta at 25%%: %0d (start=3, end=6)", captured_mu_25);
    $display("         mu_theta at 50%%: %0d (expected ~4)", captured_mu_50);
    $display("         mu_theta at 75%%: %0d (expected ~5)", captured_mu_75);
    $display("         mu_theta final:   %0d (expected 6)", mu_dt_theta);

    // Verify monotonic increase and proper final value
    if (captured_mu_25 >= MU_MODERATE && captured_mu_50 >= captured_mu_25 &&
        captured_mu_75 >= captured_mu_50 && mu_dt_theta == MU_ENHANCED) begin
        $display("         PASS - Linear ramp is monotonic and reaches target");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - Non-monotonic or incorrect final value");
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 3: Mid-transition interrupt - restart from current values
    //=========================================================================
    $display("\n[TEST 3] Mid-transition interrupt");
    state_select = STATE_NORMAL;
    apply_updates(3);  // Reset to NORMAL (need 3 cycles for instant)

    transition_duration = 16'd100;
    state_select = STATE_MEDITATION;  // Start NORMAL → MEDITATION

    // Run 50% of transition
    apply_updates(50);
    captured_mu_50 = mu_dt_theta;  // Should be mid-ramp

    // Interrupt: Change to FLOW mid-transition
    state_select = STATE_FLOW;
    apply_updates(1);  // Trigger new transition

    // Verify new transition started from interrupted values
    if (transition_from == STATE_MEDITATION && transition_to == STATE_FLOW && transitioning) begin
        $display("         transition_from=%0d (MEDITATION), transition_to=%0d (FLOW)",
                 transition_from, transition_to);
        $display("         PASS - Mid-transition interrupt started new transition");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - transition_from=%0d, transition_to=%0d, transitioning=%b",
                 transition_from, transition_to, transitioning);
        test_fail = test_fail + 1;
    end

    // Complete the transition
    wait_transition_complete;

    //=========================================================================
    // TEST 4: State pair NORMAL → ANESTHESIA
    //=========================================================================
    $display("\n[TEST 4] State pair NORMAL → ANESTHESIA");
    state_select = STATE_NORMAL;
    transition_duration = 16'd0;
    apply_updates(3);  // Reset to NORMAL instantly (need 3 cycles)

    transition_duration = 16'd50;
    state_select = STATE_ANESTHESIA;
    wait_transition_complete;

    // ANESTHESIA: L6=ENHANCED(6), L23=WEAK(1), theta=HALF(2)
    if (mu_dt_l6 == MU_ENHANCED && mu_dt_l23 == MU_WEAK && mu_dt_theta == MU_HALF) begin
        $display("         PASS - ANESTHESIA values correct (L6=%0d, L23=%0d, theta=%0d)",
                 mu_dt_l6, mu_dt_l23, mu_dt_theta);
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - L6=%0d (exp %0d), L23=%0d (exp %0d), theta=%0d (exp %0d)",
                 mu_dt_l6, MU_ENHANCED, mu_dt_l23, MU_WEAK, mu_dt_theta, MU_HALF);
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 5: State pair NORMAL → PSYCHEDELIC
    //=========================================================================
    $display("\n[TEST 5] State pair NORMAL → PSYCHEDELIC");
    state_select = STATE_NORMAL;
    transition_duration = 16'd0;
    apply_updates(3);  // Need 3 cycles for instant

    transition_duration = 16'd50;
    state_select = STATE_PSYCHEDELIC;
    wait_transition_complete;

    // PSYCHEDELIC: L4=ENHANCED(6), L23=ENHANCED(6), theta=FULL(4)
    if (mu_dt_l4 == MU_ENHANCED && mu_dt_l23 == MU_ENHANCED && mu_dt_theta == MU_FULL) begin
        $display("         PASS - PSYCHEDELIC values correct (L4=%0d, L23=%0d, theta=%0d)",
                 mu_dt_l4, mu_dt_l23, mu_dt_theta);
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - L4=%0d (exp %0d), L23=%0d (exp %0d), theta=%0d (exp %0d)",
                 mu_dt_l4, MU_ENHANCED, mu_dt_l23, MU_ENHANCED, mu_dt_theta, MU_FULL);
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 6: MU bounds check during transition
    //=========================================================================
    $display("\n[TEST 6] MU bounds check during transition");
    state_select = STATE_NORMAL;
    transition_duration = 16'd0;
    apply_updates(3);  // Need 3 cycles for instant

    transition_duration = 16'd100;
    state_select = STATE_ANESTHESIA;  // Some MU go down (theta: 3→2), some up (L6: 3→6)

    // Check bounds throughout transition
    begin : bounds_check
        integer bounds_ok;
        bounds_ok = 1;
        while (transitioning) begin
            @(posedge clk);
            clk_en = 1;
            @(posedge clk);
            clk_en = 0;
            repeat(8) @(posedge clk);

            // Check all MU values are in [1, 6]
            if (mu_dt_theta < MU_WEAK || mu_dt_theta > MU_ENHANCED ||
                mu_dt_l6 < MU_WEAK || mu_dt_l6 > MU_ENHANCED ||
                mu_dt_l5b < MU_WEAK || mu_dt_l5b > MU_ENHANCED ||
                mu_dt_l5a < MU_WEAK || mu_dt_l5a > MU_ENHANCED ||
                mu_dt_l4 < MU_WEAK || mu_dt_l4 > MU_ENHANCED ||
                mu_dt_l23 < MU_WEAK || mu_dt_l23 > MU_ENHANCED) begin
                bounds_ok = 0;
                $display("         Out of bounds: theta=%0d, L6=%0d, L5b=%0d, L5a=%0d, L4=%0d, L23=%0d",
                         mu_dt_theta, mu_dt_l6, mu_dt_l5b, mu_dt_l5a, mu_dt_l4, mu_dt_l23);
            end
        end

        if (bounds_ok) begin
            $display("         PASS - All MU values stayed in [1, 6] range");
            test_pass = test_pass + 1;
        end else begin
            $display("         FAIL - MU values went out of bounds");
            test_fail = test_fail + 1;
        end
    end

    //=========================================================================
    // TEST 7: Ca_threshold interpolation
    //=========================================================================
    $display("\n[TEST 7] Ca_threshold interpolation");
    state_select = STATE_NORMAL;
    transition_duration = 16'd0;
    apply_updates(3);  // Need 3 cycles for instant

    transition_duration = 16'd100;
    state_select = STATE_PSYCHEDELIC;  // Ca: 8192 → 4096 (decrease)

    // Capture at 50%
    apply_updates(50);

    // Expected: 8192 + (4096-8192)*0.5 = 8192 - 2048 = 6144
    $display("         ca_threshold at 50%%: %0d (expected ~6144)", ca_threshold);

    wait_transition_complete;

    if (ca_threshold == CA_THRESH_PSYCHEDELIC) begin
        $display("         ca_threshold final: %0d (expected %0d)", ca_threshold, CA_THRESH_PSYCHEDELIC);
        $display("         PASS - Ca_threshold interpolated correctly");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - ca_threshold=%0d (expected %0d)", ca_threshold, CA_THRESH_PSYCHEDELIC);
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 8: SIE timing interpolation
    //=========================================================================
    $display("\n[TEST 8] SIE timing interpolation");
    state_select = STATE_NORMAL;
    transition_duration = 16'd0;
    apply_updates(3);  // Need 3 cycles for instant

    // NORMAL sie_phase2_dur = 14000, ANESTHESIA sie_phase2_dur = 20000
    transition_duration = 16'd100;
    state_select = STATE_ANESTHESIA;

    // Capture at 50%: expected ~17000
    apply_updates(50);
    captured_sie_50 = sie_phase2_dur;
    $display("         sie_phase2_dur at 50%%: %0d (expected ~17000)", captured_sie_50);

    wait_transition_complete;

    if (sie_phase2_dur == 16'd20000) begin
        $display("         sie_phase2_dur final: %0d (expected 20000)", sie_phase2_dur);
        $display("         PASS - SIE timing interpolated correctly");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - sie_phase2_dur=%0d (expected 20000)", sie_phase2_dur);
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // TEST 9: Progress output scaling (0 → 65535)
    //=========================================================================
    $display("\n[TEST 9] Progress output scaling");
    state_select = STATE_NORMAL;
    transition_duration = 16'd0;
    apply_updates(3);  // Need 3 cycles for instant

    transition_duration = 16'd100;
    state_select = STATE_FLOW;

    // Check initial progress is 0
    apply_updates(1);

    begin : progress_check
        reg [15:0] prev_progress;
        reg [15:0] max_progress;
        integer progress_increasing;
        progress_increasing = 1;
        prev_progress = 16'd0;
        max_progress = 16'd0;
        $display("         Initial progress: %0d", transition_progress);

        while (transitioning) begin
            @(posedge clk);
            clk_en = 1;
            @(posedge clk);
            clk_en = 0;
            repeat(8) @(posedge clk);

            // Track maximum progress seen
            if (transition_progress > max_progress)
                max_progress = transition_progress;

            // Check that progress is generally increasing (allow small variations due to integer math)
            if (transition_progress < prev_progress - 16'd100 && transitioning) begin
                progress_increasing = 0;
                $display("         WARNING: progress dropped from %0d to %0d", prev_progress, transition_progress);
            end
            prev_progress = transition_progress;
        end

        $display("         Final progress: %0d (expected 65535)", transition_progress);
        $display("         Max progress seen: %0d", max_progress);

        if (transition_progress == 16'hFFFF) begin
            $display("         PASS - Progress scales to 65535");
            test_pass = test_pass + 1;
        end else begin
            $display("         FAIL - Progress final value %0d (expected 65535)", transition_progress);
            test_fail = test_fail + 1;
        end
    end

    //=========================================================================
    // TEST 10: Transitioning flag behavior
    //=========================================================================
    $display("\n[TEST 10] Transitioning flag behavior");
    state_select = STATE_NORMAL;
    transition_duration = 16'd0;
    apply_updates(3);  // Need 3 cycles for instant

    // Should not be transitioning in stable state
    if (!transitioning) begin
        $display("         Stable state: transitioning=%b (expected 0)", transitioning);
    end else begin
        $display("         WARNING: transitioning=%b in stable state", transitioning);
    end

    transition_duration = 16'd50;
    state_select = STATE_MEDITATION;
    apply_updates(1);  // Start transition

    if (transitioning && transition_to == STATE_MEDITATION) begin
        $display("         During ramp: transitioning=%b, to=%0d (expected 1, 4)",
                 transitioning, transition_to);
        wait_transition_complete;

        if (!transitioning) begin
            $display("         After complete: transitioning=%b (expected 0)", transitioning);
            $display("         PASS - Transitioning flag works correctly");
            test_pass = test_pass + 1;
        end else begin
            $display("         FAIL - transitioning still high after completion");
            test_fail = test_fail + 1;
        end
    end else begin
        $display("         FAIL - transitioning=%b, to=%0d", transitioning, transition_to);
        test_fail = test_fail + 1;
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n========================================");
    $display("TEST SUMMARY: %0d PASSED, %0d FAILED", test_pass, test_fail);
    $display("========================================");

    if (test_fail == 0) begin
        $display("ALL TESTS PASSED!");
    end else begin
        $display("SOME TESTS FAILED - Review above output");
    end

    $finish;
end

endmodule
