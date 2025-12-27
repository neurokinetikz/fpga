//=============================================================================
// Testbench: Dendritic Compartment Model - v9.5
//
// Tests for two-compartment dendritic computation:
// 1. Reset behavior
// 2. Basal-only passthrough
// 3. Apical below threshold (no Ca2+ spike)
// 4. Apical above threshold (Ca2+ spike activates)
// 5. Ca2+ spike duration (tau=30ms)
// 6. Apical gain modulation
// 7. BAC: basal only (no boost)
// 8. BAC: apical only (no boost)
// 9. BAC: coincidence (1.5x boost)
// 10. BAC timing window
//=============================================================================
`timescale 1ns / 1ps

module tb_dendritic_compartment;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter FAST_SIM = 1;

// Clock and reset
reg clk;
reg rst;
reg clk_en;

// Inputs
reg signed [WIDTH-1:0] basal_input;
reg signed [WIDTH-1:0] apical_input;
reg signed [WIDTH-1:0] apical_gain;
reg signed [WIDTH-1:0] ca_threshold;

// Outputs
wire signed [WIDTH-1:0] dendritic_output;
wire ca_spike_active;
wire bac_active;

// Test tracking
integer test_num;
integer pass_count;
integer fail_count;
integer cycle_count;

// Constants for testing (Q14)
localparam signed [WIDTH-1:0] ONE = 18'sd16384;           // 1.0
localparam signed [WIDTH-1:0] HALF = 18'sd8192;           // 0.5
localparam signed [WIDTH-1:0] QUARTER = 18'sd4096;        // 0.25
localparam signed [WIDTH-1:0] THREE_QUARTER = 18'sd12288; // 0.75
localparam signed [WIDTH-1:0] ONE_POINT_FIVE = 18'sd24576;// 1.5

// DUT instantiation
dendritic_compartment #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .basal_input(basal_input),
    .apical_input(apical_input),
    .apical_gain(apical_gain),
    .ca_threshold(ca_threshold),
    .dendritic_output(dendritic_output),
    .ca_spike_active(ca_spike_active),
    .bac_active(bac_active)
);

// Clock generation: 125 MHz
initial clk = 0;
always #4 clk = ~clk;

// Clock enable generation (4 kHz equivalent, but fast for simulation)
reg [15:0] clk_div;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_div <= 0;
        clk_en <= 0;
    end else begin
        if (clk_div >= (FAST_SIM ? 10 : 31250)) begin
            clk_div <= 0;
            clk_en <= 1;
        end else begin
            clk_div <= clk_div + 1;
            clk_en <= 0;
        end
    end
end

// Helper task: wait for N clock enables
task wait_cycles;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk);
            while (!clk_en) @(posedge clk);
        end
    end
endtask

// Helper task: reset DUT
task do_reset;
    begin
        rst = 1;
        basal_input = 0;
        apical_input = 0;
        apical_gain = ONE;
        ca_threshold = HALF;  // Default: 0.5
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(posedge clk);
    end
endtask

// Main test sequence
initial begin
    $display("========================================");
    $display("Dendritic Compartment Tests (v9.5)");
    $display("========================================");

    pass_count = 0;
    fail_count = 0;
    test_num = 0;

    //=========================================================================
    // TEST 1: Reset behavior
    //=========================================================================
    test_num = 1;
    $display("\n[TEST %0d] Reset behavior", test_num);
    do_reset();

    if (dendritic_output == 0 && ca_spike_active == 0 && bac_active == 0) begin
        $display("         PASS - All outputs zero after reset");
        pass_count = pass_count + 1;
    end else begin
        $display("         FAIL - Output=%0d, ca_spike=%0d, bac=%0d",
                 dendritic_output, ca_spike_active, bac_active);
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // TEST 2: Basal-only passthrough
    //=========================================================================
    test_num = 2;
    $display("\n[TEST %0d] Basal-only passthrough", test_num);
    do_reset();

    basal_input = HALF;  // 0.5
    apical_input = 0;
    apical_gain = ONE;

    wait_cycles(50);

    // Output should be close to basal_input (no apical, no BAC)
    if (dendritic_output > (HALF - QUARTER) && dendritic_output < (HALF + QUARTER)) begin
        $display("         PASS - Output (%0d) tracks basal input (%0d)",
                 dendritic_output, basal_input);
        pass_count = pass_count + 1;
    end else begin
        $display("         FAIL - Output=%0d, expected ~%0d", dendritic_output, HALF);
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // TEST 3: Apical below threshold (no Ca2+ spike)
    //=========================================================================
    test_num = 3;
    $display("\n[TEST %0d] Apical below threshold", test_num);
    do_reset();

    basal_input = 0;
    apical_input = QUARTER;  // 0.25 (below 0.5 threshold)
    apical_gain = ONE;
    ca_threshold = HALF;

    wait_cycles(100);

    if (ca_spike_active == 0) begin
        $display("         PASS - No Ca2+ spike when apical (0.25) < threshold (0.5)");
        pass_count = pass_count + 1;
    end else begin
        $display("         FAIL - Ca2+ spike activated unexpectedly");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // TEST 4: Apical above threshold (Ca2+ spike activates)
    //=========================================================================
    test_num = 4;
    $display("\n[TEST %0d] Apical above threshold", test_num);
    do_reset();

    basal_input = 0;
    apical_input = THREE_QUARTER;  // 0.75 (above 0.5 threshold)
    apical_gain = ONE;
    ca_threshold = HALF;

    wait_cycles(200);  // Allow Ca2+ to build up

    if (ca_spike_active == 1) begin
        $display("         PASS - Ca2+ spike activated when apical (0.75) > threshold (0.5)");
        pass_count = pass_count + 1;
    end else begin
        $display("         FAIL - Ca2+ spike did not activate");
        $display("         apical_depot should be > ca_threshold");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // TEST 5: Ca2+ spike duration (slow dynamics)
    //=========================================================================
    test_num = 5;
    $display("\n[TEST %0d] Ca2+ spike duration (tau=30ms)", test_num);
    do_reset();

    // First, build up Ca2+ spike
    basal_input = 0;
    apical_input = ONE;  // Strong apical
    apical_gain = ONE;
    ca_threshold = HALF;

    wait_cycles(200);

    // Verify Ca2+ spike is active
    if (!ca_spike_active) begin
        $display("         FAIL - Ca2+ spike did not activate during buildup");
        fail_count = fail_count + 1;
    end else begin
        // Now remove apical input and observe slow decay
        apical_input = 0;

        // Wait 50 cycles (~12.5ms) - should still be partially active
        wait_cycles(50);

        // Ca2+ should still be above threshold due to slow tau=30ms
        if (ca_spike_active == 1) begin
            $display("         PASS - Ca2+ spike persists after input removed (slow dynamics)");
            pass_count = pass_count + 1;
        end else begin
            $display("         FAIL - Ca2+ decayed too fast");
            fail_count = fail_count + 1;
        end
    end

    //=========================================================================
    // TEST 6: Apical gain modulation
    //=========================================================================
    test_num = 6;
    $display("\n[TEST %0d] Apical gain modulation", test_num);
    do_reset();

    // Low apical input that would NOT cross threshold at gain=1.0
    basal_input = 0;
    apical_input = QUARTER;  // 0.25
    ca_threshold = HALF;     // 0.5

    // At gain=1.0, apical_scaled=0.25 < 0.5 threshold -> no spike
    apical_gain = ONE;
    wait_cycles(100);

    if (ca_spike_active == 1) begin
        $display("         FAIL - Ca2+ spike at gain=1.0 (shouldn't happen)");
        fail_count = fail_count + 1;
    end else begin
        // Now increase gain to 2.5 -> apical_scaled=0.625 > 0.5 threshold -> spike
        apical_gain = 18'sd40960;  // 2.5 in Q14
        wait_cycles(200);

        if (ca_spike_active == 1) begin
            $display("         PASS - Gain modulation affects Ca2+ threshold crossing");
            pass_count = pass_count + 1;
        end else begin
            $display("         FAIL - Higher gain should have triggered Ca2+ spike");
            fail_count = fail_count + 1;
        end
    end

    //=========================================================================
    // TEST 7: BAC - basal only (no boost)
    //=========================================================================
    test_num = 7;
    $display("\n[TEST %0d] BAC: basal only (no boost)", test_num);
    do_reset();

    // Strong basal, no apical -> no BAC
    basal_input = ONE;  // 1.0 (strong)
    apical_input = 0;
    apical_gain = ONE;
    ca_threshold = HALF;

    wait_cycles(100);

    if (bac_active == 0) begin
        $display("         PASS - No BAC when only basal active");
        pass_count = pass_count + 1;
    end else begin
        $display("         FAIL - BAC triggered without apical activity");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // TEST 8: BAC - apical only (no boost)
    //=========================================================================
    test_num = 8;
    $display("\n[TEST %0d] BAC: apical only (no boost)", test_num);
    do_reset();

    // No basal, strong apical -> Ca2+ spike but no BAC
    basal_input = 0;
    apical_input = ONE;  // 1.0
    apical_gain = ONE;
    ca_threshold = HALF;

    wait_cycles(200);

    // Verify Ca2+ spike is active
    if (!ca_spike_active) begin
        $display("         FAIL - Ca2+ spike should be active");
        fail_count = fail_count + 1;
    end else if (bac_active == 0) begin
        $display("         PASS - No BAC when only apical active (Ca2+ spike but no basal)");
        pass_count = pass_count + 1;
    end else begin
        $display("         FAIL - BAC triggered without basal activity");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // TEST 9: BAC - coincidence (1.5x boost)
    //=========================================================================
    test_num = 9;
    $display("\n[TEST %0d] BAC: coincidence (1.5x boost)", test_num);
    do_reset();

    // First, establish Ca2+ spike
    basal_input = 0;
    apical_input = ONE;
    apical_gain = ONE;
    ca_threshold = HALF;

    wait_cycles(200);

    // Verify Ca2+ spike is active
    if (!ca_spike_active) begin
        $display("         FAIL - Ca2+ spike should be active before coincidence test");
        fail_count = fail_count + 1;
    end else begin
        // Record output without BAC
        // Now add strong basal to trigger BAC
        basal_input = ONE;

        wait_cycles(10);

        if (bac_active == 1) begin
            $display("         PASS - BAC coincidence detected (basal + apical Ca2+)");
            pass_count = pass_count + 1;
        end else begin
            $display("         FAIL - BAC not triggered during coincidence");
            $display("         ca_spike_active=%0d, basal=%0d", ca_spike_active, basal_input);
            fail_count = fail_count + 1;
        end
    end

    //=========================================================================
    // TEST 10: BAC timing window
    //=========================================================================
    test_num = 10;
    $display("\n[TEST %0d] BAC timing window", test_num);
    do_reset();

    // Start with coincidence
    basal_input = ONE;
    apical_input = ONE;
    apical_gain = ONE;
    ca_threshold = HALF;

    wait_cycles(200);

    // Should have BAC
    if (!bac_active) begin
        $display("         FAIL - BAC should be active during coincidence");
        fail_count = fail_count + 1;
    end else begin
        // Remove basal - BAC should deactivate immediately
        basal_input = 0;

        wait_cycles(5);

        if (bac_active == 0) begin
            $display("         PASS - BAC deactivates when basal removed");
            pass_count = pass_count + 1;
        end else begin
            $display("         FAIL - BAC persisted after basal removed");
            fail_count = fail_count + 1;
        end
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n========================================");
    $display("SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
    $display("========================================");

    if (fail_count == 0) begin
        $display("ALL TESTS PASSED!");
    end else begin
        $display("SOME TESTS FAILED!");
    end

    $finish;
end

endmodule
