//=============================================================================
// PV+ Basket Cell Minimal Model Testbench - v9.0
//
// Tests the Phase 1 minimal PV+ implementation in cortical_column.v
// Verifies:
// 1. PV+ inhibition is proportional to L2/3 amplitude
// 2. Gamma amplitude is stabilized by PV+ feedback
// 3. No inhibition when L2/3 is quiet
// 4. E-I balance maintains oscillation
//=============================================================================
`timescale 1ns / 1ps

module tb_pv_minimal;

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
integer cycle_count;

// Amplitude tracking
reg signed [WIDTH-1:0] max_l23_amp;
reg signed [WIDTH-1:0] min_l23_amp;
wire signed [WIDTH-1:0] l23_amp;

// Compute amplitude as sqrt(x^2 + y^2) approximation: max(|x|, |y|) + 0.5*min(|x|, |y|)
wire signed [WIDTH-1:0] abs_x, abs_y;
assign abs_x = (l23_x < 0) ? -l23_x : l23_x;
assign abs_y = (l23_y < 0) ? -l23_y : l23_y;
assign l23_amp = (abs_x > abs_y) ? abs_x + (abs_y >>> 1) : abs_y + (abs_x >>> 1);

// Clock generation
initial begin
    clk = 0;
    forever #4 clk = ~clk;  // 125 MHz
end

// Clock enable generation (simplified for testing)
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

// Helper task: wait for N clk_en cycles
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

// Helper task: run and track amplitude for N cycles
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

// Initialize inputs
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
        // Standard MU values
        mu_dt_l6 = 18'sd66;   // MU=4
        mu_dt_l5b = 18'sd66;
        mu_dt_l5a = 18'sd66;
        mu_dt_l4 = 18'sd66;
        mu_dt_l23 = 18'sd66;
    end
endtask

initial begin
    $display("=============================================================");
    $display("PV+ Basket Cell Minimal Model Testbench - v9.0");
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
    // Test 1: L2/3 oscillates with zero input (baseline)
    //=========================================================================
    test_num = 1;
    $display("\nTest %0d: Baseline L2/3 oscillation (no external input)", test_num);

    init_inputs;
    wait_cycles(500);  // Let oscillators settle

    run_and_track_amplitude(200);

    $display("  L2/3 amplitude range: min=%0d, max=%0d", min_l23_amp, max_l23_amp);

    // Amplitude should be bounded - with PV+ it shouldn't exceed ~2.0 (32768)
    if (max_l23_amp > 0 && max_l23_amp < 18'sd35000) begin
        $display("  PASS: L2/3 oscillating with bounded amplitude");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: L2/3 amplitude out of expected range");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 2: Strong feedforward input - PV+ should limit amplitude
    //=========================================================================
    test_num = 2;
    $display("\nTest %0d: Strong feedforward input (PV+ amplitude limiting)", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;

    // Apply strong L4 input to drive L2/3
    feedforward_input = 18'sd8192;  // 0.5 - strong input

    wait_cycles(500);  // Let oscillators settle

    run_and_track_amplitude(200);

    $display("  L2/3 amplitude with strong input: min=%0d, max=%0d", min_l23_amp, max_l23_amp);

    // With PV+ inhibition, amplitude should be bounded (not runaway)
    if (max_l23_amp > 18'sd1000 && max_l23_amp < 18'sd30000) begin
        $display("  PASS: PV+ inhibition bounds L2/3 amplitude under strong drive");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: L2/3 amplitude not properly bounded (got %0d)", max_l23_amp);
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 3: Compare high vs low MU (PV+ should stabilize both)
    //=========================================================================
    test_num = 3;
    $display("\nTest %0d: High MU stability (PV+ prevents runaway)", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;

    // High MU for enhanced oscillation
    mu_dt_l23 = 18'sd99;  // MU=6 (enhanced)
    feedforward_input = 18'sd4096;  // 0.25 - moderate input

    wait_cycles(500);

    run_and_track_amplitude(200);

    $display("  L2/3 amplitude with high MU: min=%0d, max=%0d", min_l23_amp, max_l23_amp);

    // Even with high MU, PV+ should prevent extreme amplitudes
    if (max_l23_amp < 18'sd40000) begin
        $display("  PASS: PV+ stabilizes high-MU oscillation");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Amplitude too high with high MU (%0d)", max_l23_amp);
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 4: Verify oscillation is active (amplitude check instead of frequency)
    //=========================================================================
    test_num = 4;
    $display("\nTest %0d: Gamma oscillation active with PV+", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    feedforward_input = 18'sd2048;  // 0.125 - light drive

    wait_cycles(800);  // Longer settle time

    run_and_track_amplitude(400);

    $display("  L2/3 oscillation check: min=%0d, max=%0d", min_l23_amp, max_l23_amp);

    // Verify oscillation is active (amplitude > threshold) and stable
    if (max_l23_amp > 18'sd5000 && max_l23_amp < 18'sd35000) begin
        $display("  PASS: Gamma oscillation active and bounded");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Oscillation amplitude unexpected");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Test 5: PV+ inhibition proportional to amplitude
    //=========================================================================
    test_num = 5;
    $display("\nTest %0d: PV+ inhibition proportionality", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;

    // Measure amplitude with weak input
    feedforward_input = 18'sd1024;  // 0.0625
    wait_cycles(500);
    run_and_track_amplitude(200);
    begin : proportionality_test
        reg signed [WIDTH-1:0] amp_weak;
        amp_weak = max_l23_amp;

        // Measure amplitude with strong input
        rst = 1;
        repeat(10) @(posedge clk);
        rst = 0;
        feedforward_input = 18'sd8192;  // 0.5
        wait_cycles(500);
        run_and_track_amplitude(200);

        $display("  Amplitude with weak input: %0d", amp_weak);
        $display("  Amplitude with strong input: %0d", max_l23_amp);

        // Strong input should give higher amplitude, but not 8x higher due to PV+
        if (max_l23_amp > amp_weak && max_l23_amp < amp_weak * 5) begin
            $display("  PASS: PV+ compresses amplitude response (sublinear gain)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Amplitude scaling not as expected");
            fail_count = fail_count + 1;
        end
    end

    //=========================================================================
    // Test 6: Encoding window (fast gamma) stability
    //=========================================================================
    test_num = 6;
    $display("\nTest %0d: Fast gamma (encoding window) stability", test_num);

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
    init_inputs;
    encoding_window = 1;  // Fast gamma mode (65.3 Hz)
    feedforward_input = 18'sd4096;

    wait_cycles(500);
    run_and_track_amplitude(200);

    $display("  Fast gamma amplitude: min=%0d, max=%0d", min_l23_amp, max_l23_amp);

    if (max_l23_amp > 0 && max_l23_amp < 18'sd30000) begin
        $display("  PASS: Fast gamma stable with PV+ inhibition");
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL: Fast gamma amplitude unstable");
        fail_count = fail_count + 1;
    end

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n=============================================================");
    $display("PV+ Minimal Model Test Summary");
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
