//=============================================================================
// Cross-Layer PV+ Testbench - v9.3
//
// Tests the Phase 4 cross-layer PV+ implementation with:
// - L2/3 local PV+ (PING network) - 1.0× weight
// - L4 feedforward PV+ - 0.5× weight
// - L5 feedback PV+ - 0.25× weight
//
// Verifies:
// 1. All three PV+ populations are active
// 2. L4 PV+ gates feedforward to L2/3
// 3. L5 PV+ provides feedback inhibition
// 4. Combined inhibition stabilizes L2/3
// 5. Cross-layer E-I balance
//=============================================================================
`timescale 1ns / 1ps

module tb_pv_crosslayer;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter FAST_SIM = 1;

reg clk;
reg rst;
reg clk_en;

// Cortical column inputs
reg signed [WIDTH-1:0] thalamic_theta_input;
reg signed [WIDTH-1:0] feedforward_input;
reg signed [WIDTH-1:0] matrix_thalamic_input;
reg signed [WIDTH-1:0] feedback_input_1;
reg signed [WIDTH-1:0] feedback_input_2;
reg signed [WIDTH-1:0] phase_couple_l23;
reg signed [WIDTH-1:0] phase_couple_l6;
reg encoding_window;
reg signed [WIDTH-1:0] mu_dt_l6, mu_dt_l5b, mu_dt_l5a, mu_dt_l4, mu_dt_l23;

// Cortical column outputs
wire signed [WIDTH-1:0] l23_x, l23_y;
wire signed [WIDTH-1:0] l5b_x, l5a_x;
wire signed [WIDTH-1:0] l6_x, l6_y;
wire signed [WIDTH-1:0] l4_x;

// Test tracking
integer test_num;
integer pass_count;
integer fail_count;

// Access internal PV+ states via hierarchical paths
wire signed [WIDTH-1:0] pv_l23_state;
wire signed [WIDTH-1:0] pv_l4_state;
wire signed [WIDTH-1:0] pv_l5_state;
wire signed [WIDTH-1:0] pv_l23_inhib;
wire signed [WIDTH-1:0] pv_l4_inhib;
wire signed [WIDTH-1:0] pv_l5_inhib;
wire signed [WIDTH-1:0] pv_total_inhib;

assign pv_l23_state = dut.pv_l23.pv_state;
assign pv_l4_state = dut.pv_l4.pv_state;
assign pv_l5_state = dut.pv_l5.pv_state;
assign pv_l23_inhib = dut.pv_l23_inhibition;
assign pv_l4_inhib = dut.pv_l4_inhibition;
assign pv_l5_inhib = dut.pv_l5_inhibition;
assign pv_total_inhib = dut.pv_total_inhibition;

// Amplitude tracking
reg signed [WIDTH-1:0] max_l23_amp, min_l23_amp;
wire signed [WIDTH-1:0] l23_amp;

wire signed [WIDTH-1:0] abs_x, abs_y;
assign abs_x = (l23_x < 0) ? -l23_x : l23_x;
assign abs_y = (l23_y < 0) ? -l23_y : l23_y;
assign l23_amp = (abs_x > abs_y) ? abs_x + (abs_y >>> 1) : abs_y + (abs_x >>> 1);

// Clock generation
initial begin
    clk = 0;
    forever #4 clk = ~clk;
end

// Clock enable generation
reg [3:0] clk_div;
always @(posedge clk) begin
    if (rst) begin
        clk_div <= 0;
        clk_en <= 0;
    end else begin
        clk_div <= clk_div + 1;
        clk_en <= (clk_div == 0);
    end
end

// DUT instantiation
cortical_column #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .thalamic_theta_input(thalamic_theta_input),
    .feedforward_input(feedforward_input),
    .matrix_thalamic_input(matrix_thalamic_input),
    .feedback_input_1(feedback_input_1),
    .feedback_input_2(feedback_input_2),
    .phase_couple_l23(phase_couple_l23),
    .phase_couple_l6(phase_couple_l6),
    .encoding_window(encoding_window),
    .attention_input(18'sd0),  // v9.4: No attention for PV+ tests
    .ca_threshold(18'sd8192),  // v9.5: Default Ca2+ threshold (0.5)
    // v10.0: No frequency drift for PV+ tests
    .omega_drift_l6(18'sd0),
    .omega_drift_l5a(18'sd0),
    .omega_drift_l5b(18'sd0),
    .omega_drift_l4(18'sd0),
    .omega_drift_l23(18'sd0),
    .mu_dt_l6(mu_dt_l6),
    .mu_dt_l5b(mu_dt_l5b),
    .mu_dt_l5a(mu_dt_l5a),
    .mu_dt_l4(mu_dt_l4),
    .mu_dt_l23(mu_dt_l23),
    .l23_x(l23_x),
    .l23_y(l23_y),
    .l5b_x(l5b_x),
    .l5a_x(l5a_x),
    .l6_x(l6_x),
    .l6_y(l6_y),
    .l4_x(l4_x)
);

// Helper tasks
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

task run_and_track_amplitude;
    input integer n;
    integer i;
    begin
        max_l23_amp = 0;
        min_l23_amp = 18'sd32767;
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk);
            while (!clk_en) @(posedge clk);
            if (l23_amp > max_l23_amp) max_l23_amp = l23_amp;
            if (l23_amp < min_l23_amp && l23_amp > 0) min_l23_amp = l23_amp;
        end
    end
endtask

task init_inputs;
    begin
        thalamic_theta_input = 0;
        feedforward_input = 0;
        matrix_thalamic_input = 0;
        feedback_input_1 = 0;
        feedback_input_2 = 0;
        phase_couple_l23 = 0;
        phase_couple_l6 = 0;
        encoding_window = 0;
        mu_dt_l6 = 18'sd66;
        mu_dt_l5b = 18'sd66;
        mu_dt_l5a = 18'sd66;
        mu_dt_l4 = 18'sd66;
        mu_dt_l23 = 18'sd66;
    end
endtask

initial begin
    $display("=============================================================");
    $display("Cross-Layer PV+ Testbench - v9.3");
    $display("=============================================================");

    test_num = 0;
    pass_count = 0;
    fail_count = 0;

    // Reset
    rst = 1;
    init_inputs;
    repeat(10) @(posedge clk);
    rst = 0;
    wait_cycles(10);

    //=========================================================================
    // Test 1: All PV+ states reset to zero
    //=========================================================================
    test_num = 1;
    $display("\nTest %0d: All PV+ populations reset to zero", test_num);

    rst = 1;
    repeat(10) @(posedge clk);

    if (pv_l23_state == 0 && pv_l4_state == 0 && pv_l5_state == 0) begin
        $display("  PASS: All PV+ states reset to zero");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: PV+ states not zero (L23=%0d, L4=%0d, L5=%0d)",
                 pv_l23_state, pv_l4_state, pv_l5_state);
        fail_count = fail_count + 1;
    end

    rst = 0;

    //=========================================================================
    // Test 2: All three PV+ populations become active
    //=========================================================================
    test_num = 2;
    $display("\nTest %0d: All PV+ populations active", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    feedforward_input = 18'sd4096;

    wait_cycles(500);

    $display("  PV+ states: L23=%0d, L4=%0d, L5=%0d",
             pv_l23_state, pv_l4_state, pv_l5_state);

    // All PV+ should have non-zero activity
    if (pv_l23_state != 0 && pv_l4_state != 0 && pv_l5_state != 0) begin
        $display("  PASS: All PV+ populations active");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Some PV+ populations inactive");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 3: L4 PV+ tracks L4 activity
    //=========================================================================
    test_num = 3;
    $display("\nTest %0d: L4 PV+ tracks L4 pyramid", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    feedforward_input = 18'sd8192;  // Strong L4 drive

    wait_cycles(500);

    begin : l4_tracking_test
        reg signed [WIDTH-1:0] l4_pv_strong;
        l4_pv_strong = pv_l4_state;

        // Reduce L4 drive
        rst = 1;
        repeat(10) @(posedge clk);
        rst = 0;
        feedforward_input = 18'sd1024;  // Weak drive
        wait_cycles(500);

        $display("  L4 PV+ with strong drive: %0d, weak drive: %0d",
                 l4_pv_strong, pv_l4_state);

        // L4 PV+ should be lower with weaker L4 drive
        if (l4_pv_strong > pv_l4_state) begin
            $display("  PASS: L4 PV+ tracks L4 activity");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: L4 PV+ not tracking L4");
            fail_count = fail_count + 1;
        end
    end

    //=========================================================================
    // Test 4: L5 PV+ responds to L5b activity
    //=========================================================================
    test_num = 4;
    $display("\nTest %0d: L5 PV+ tracks L5b pyramid", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    feedforward_input = 18'sd4096;
    feedback_input_1 = 18'sd4096;  // Drive L5b

    wait_cycles(500);

    begin : l5_tracking_test
        reg signed [WIDTH-1:0] l5_pv_driven;
        l5_pv_driven = pv_l5_state;

        // Remove feedback drive
        rst = 1;
        repeat(10) @(posedge clk);
        rst = 0;
        feedback_input_1 = 0;
        wait_cycles(500);

        $display("  L5 PV+ with feedback: %0d, without: %0d",
                 l5_pv_driven, pv_l5_state);

        // L5 PV+ should be lower without feedback
        if (l5_pv_driven > pv_l5_state) begin
            $display("  PASS: L5 PV+ tracks L5b activity");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: L5 PV+ not tracking L5b");
            fail_count = fail_count + 1;
        end
    end

    //=========================================================================
    // Test 5: Combined inhibition is sum of weighted components
    //=========================================================================
    test_num = 5;
    $display("\nTest %0d: Combined inhibition is weighted sum", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    feedforward_input = 18'sd4096;

    wait_cycles(500);

    begin : combined_test
        reg signed [WIDTH-1:0] expected_total;
        reg signed [WIDTH-1:0] actual_total;

        expected_total = pv_l23_inhib + (pv_l4_inhib >>> 1) + (pv_l5_inhib >>> 2);
        actual_total = pv_total_inhib;

        $display("  Individual: L23=%0d, L4=%0d, L5=%0d",
                 pv_l23_inhib, pv_l4_inhib, pv_l5_inhib);
        $display("  Expected total: %0d, Actual: %0d", expected_total, actual_total);

        // Allow small rounding error
        if (actual_total >= expected_total - 2 && actual_total <= expected_total + 2) begin
            $display("  PASS: Combined inhibition correct");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Combined inhibition mismatch");
            fail_count = fail_count + 1;
        end
    end

    //=========================================================================
    // Test 6: L2/3 amplitude stable with cross-layer inhibition
    //=========================================================================
    test_num = 6;
    $display("\nTest %0d: L2/3 stable with cross-layer PV+", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    feedforward_input = 18'sd4096;

    wait_cycles(500);
    run_and_track_amplitude(300);

    $display("  L2/3 amplitude: min=%0d, max=%0d", min_l23_amp, max_l23_amp);

    if (max_l23_amp > 18'sd1000 && max_l23_amp < 18'sd40000) begin
        $display("  PASS: L2/3 amplitude bounded");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: L2/3 amplitude out of range");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 7: High MU stability with cross-layer PV+
    //=========================================================================
    test_num = 7;
    $display("\nTest %0d: High MU stability", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    mu_dt_l23 = 18'sd99;  // MU=6
    mu_dt_l4 = 18'sd99;
    feedforward_input = 18'sd4096;

    wait_cycles(500);
    run_and_track_amplitude(300);

    $display("  L2/3 amplitude with high MU: max=%0d", max_l23_amp);

    if (max_l23_amp < 18'sd50000) begin
        $display("  PASS: Cross-layer PV+ stabilizes high MU");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Amplitude too high");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 8: Feedforward gating (L4 PV+ affects L2/3)
    //=========================================================================
    test_num = 8;
    $display("\nTest %0d: Feedforward gating effect", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    feedforward_input = 18'sd8192;  // Strong feedforward

    wait_cycles(500);

    // L4 PV+ should have significant inhibition
    $display("  L4 PV+ inhibition: %0d (contributing %0d to total)",
             pv_l4_inhib, pv_l4_inhib >>> 1);

    if ((pv_l4_inhib >>> 1) > 18'sd100) begin
        $display("  PASS: L4 PV+ provides feedforward gating");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: L4 PV+ gating too weak");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n=============================================================");
    $display("Cross-Layer PV+ Test Summary");
    $display("=============================================================");
    $display("Total tests: %0d", test_num);
    $display("Passed: %0d", pass_count);
    $display("Failed: %0d", fail_count);

    if (fail_count == 0) begin
        $display("\n*** ALL TESTS PASSED ***");
    end else begin
        $display("\n*** SOME TESTS FAILED ***");
    end

    $display("=============================================================");
    $finish;
end

endmodule
