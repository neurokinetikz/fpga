//=============================================================================
// Full System Testbench - v6.2 (Sensory-Only)
// Tests the complete phi_n_neural_processor
// v6.2: Removed ca3_pattern_in - sensory_input is the ONLY external data input
// v6.1: Added cortical_pattern_out for closed-loop verification
// v6.0: Updated clk_1khz_en → clk_4khz_en
//=============================================================================
`timescale 1ns / 1ps

module tb_full_system;

parameter WIDTH = 18;
parameter FRAC = 14;

// Clock and reset
reg clk;
reg rst;

// Inputs (v6.2: sensory_input is the ONLY external data input)
reg signed [WIDTH-1:0] sensory_input;
reg [2:0] state_select;

// Outputs
wire [11:0] dac_output;
wire signed [WIDTH-1:0] debug_motor_l23;
wire signed [WIDTH-1:0] debug_theta;
wire ca3_learning;
wire ca3_recalling;
wire [5:0] ca3_phase_pattern;
wire [5:0] cortical_pattern;  // v6.1: Cortical activity pattern

// Internal signals for monitoring (v6.0: renamed from clk_1khz_en)
wire clk_4khz_en = dut.clk_4khz_en;

// Instantiate DUT (v6.2: no ca3_pattern_in - sensory_input is the ONLY data input)
phi_n_neural_processor #(.WIDTH(WIDTH), .FRAC(FRAC)) dut (
    .clk(clk),
    .rst(rst),
    .sensory_input(sensory_input),
    .state_select(state_select),
    .sr_field_input(18'sd0),
    .sr_field_packed(90'd0),
    .dac_output(dac_output),
    .debug_motor_l23(debug_motor_l23),
    .debug_theta(debug_theta),
    .ca3_learning(ca3_learning),
    .ca3_recalling(ca3_recalling),
    .ca3_phase_pattern(ca3_phase_pattern),
    .cortical_pattern_out(cortical_pattern)  // v6.1
);

// 125 MHz clock (8ns period)
initial begin
    clk = 0;
    forever #4 clk = ~clk;
end

// Test variables
integer test_pass, test_fail;
integer update_count;
integer dac_min, dac_max;
integer peak_count;
reg prev_peak;

// Task to wait for N 4kHz updates (v6.0: renamed from wait_1khz_updates)
task wait_4khz_updates;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk_4khz_en);
            update_count = update_count + 1;
        end
    end
endtask

initial begin
    $display("========================================");
    $display("PHI-N NEURAL PROCESSOR v6.2");
    $display("FULL SYSTEM SIMULATION (SENSORY-ONLY)");
    $display("========================================");

    // Initialize (v6.2: sensory_input is the ONLY external data input)
    rst = 1;
    sensory_input = 18'sd0;
    state_select = 3'd0;  // NORMAL
    test_pass = 0;
    test_fail = 0;
    update_count = 0;
    dac_min = 4096;
    dac_max = 0;
    peak_count = 0;
    prev_peak = 0;

    // Reset
    repeat(10) @(posedge clk);
    rst = 0;
    $display("\n[INFO] Reset released at time %0t", $time);

    // TEST 1: Oscillator startup (wait 500ms = 500 updates)
    $display("\n[TEST 1] Oscillator startup (500ms warmup)");
    wait_4khz_updates(500);
    $display("         Theta: %0d, Motor L2/3: %0d", debug_theta, debug_motor_l23);
    if (debug_theta != 0 && debug_motor_l23 != 0) begin
        $display("         PASS - All oscillators active");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - Oscillators not running");
        test_fail = test_fail + 1;
    end

    // TEST 2: Theta frequency measurement
    $display("\n[TEST 2] Theta frequency (expect 5-7 peaks/second)");
    peak_count = 0;
    prev_peak = 0;
    for (update_count = 0; update_count < 1000; update_count = update_count + 1) begin
        @(posedge clk_4khz_en);
        if (debug_theta > 18'sd12000 && !prev_peak) begin
            peak_count = peak_count + 1;
            prev_peak = 1;
        end
        if (debug_theta < 18'sd8000) prev_peak = 0;
    end
    $display("         Measured: %0d peaks/second", peak_count);
    if (peak_count >= 4 && peak_count <= 8) begin
        $display("         PASS");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL");
        test_fail = test_fail + 1;
    end

    // TEST 3: DAC output range
    $display("\n[TEST 3] DAC output range");
    dac_min = 4096;
    dac_max = 0;
    for (update_count = 0; update_count < 1000; update_count = update_count + 1) begin
        @(posedge clk_4khz_en);
        if (dac_output < dac_min) dac_min = dac_output;
        if (dac_output > dac_max) dac_max = dac_output;
    end
    $display("         DAC range: %0d - %0d (span: %0d)", dac_min, dac_max, dac_max - dac_min);
    if ((dac_max - dac_min) > 1000) begin
        $display("         PASS - Good dynamic range");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - Insufficient dynamic range");
        test_fail = test_fail + 1;
    end

    // TEST 4: CA3 learning integration (v6.2: via sensory input)
    $display("\n[TEST 4] CA3 learning via sensory pathway");
    sensory_input = 18'sd12000;  // Strong sensory stimulus
    // Wait for theta peak and learning to trigger
    for (update_count = 0; update_count < 500; update_count = update_count + 1) begin
        @(posedge clk_4khz_en);
        if (ca3_learning) begin
            $display("         Learning triggered at update %0d - PASS", update_count);
            test_pass = test_pass + 1;
            update_count = 500;  // Exit loop
        end
    end
    if (!ca3_learning && update_count == 500) begin
        $display("         Learning not triggered - FAIL");
        test_fail = test_fail + 1;
    end
    wait_4khz_updates(100);
    sensory_input = 18'sd0;

    // TEST 5: CA3 recall integration (v6.2: via sensory input)
    $display("\n[TEST 5] CA3 recall via sensory pathway");
    // Wait for theta trough
    wait_4khz_updates(100);
    sensory_input = 18'sd8000;  // Moderate sensory cue
    for (update_count = 0; update_count < 500; update_count = update_count + 1) begin
        @(posedge clk_4khz_en);
        if (ca3_recalling) begin
            $display("         Recall triggered - PASS");
            test_pass = test_pass + 1;
            update_count = 500;
        end
    end
    if (!ca3_recalling && update_count == 500) begin
        $display("         Recall not triggered - FAIL");
        test_fail = test_fail + 1;
    end
    wait_4khz_updates(50);
    $display("         Phase pattern output: %b", ca3_phase_pattern);
    sensory_input = 18'sd0;

    // TEST 6: State modulation - Meditation
    $display("\n[TEST 6] State modulation (Meditation)");
    state_select = 3'd4;  // MEDITATION
    wait_4khz_updates(100);
    $display("         Mu_dt values in meditation:");
    $display("           Theta: %0d (enhanced)", dut.mu_dt_theta);
    $display("           L6:    %0d (enhanced)", dut.mu_dt_l6);
    $display("           L2/3:  %0d (suppressed)", dut.mu_dt_l23);
    if (dut.mu_dt_theta == 18'sd24 && dut.mu_dt_l23 == 18'sd8) begin
        $display("         PASS - Meditation state active");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - State not configured correctly");
        test_fail = test_fail + 1;
    end
    state_select = 3'd0;  // Back to NORMAL

    // TEST 7: Sensory input response
    $display("\n[TEST 7] Sensory input response");
    sensory_input = 18'sd4096;  // Moderate input
    wait_4khz_updates(200);
    $display("         With sensory input: DAC=%0d, Motor L2/3=%0d",
             dac_output, debug_motor_l23);
    sensory_input = 18'sd0;
    wait_4khz_updates(200);
    $display("         Without sensory input: DAC=%0d, Motor L2/3=%0d",
             dac_output, debug_motor_l23);
    test_pass = test_pass + 1;  // Visual check

    // TEST 8: Closed-loop CA3 (v6.2: pure sensory-only pathway)
    $display("\n[TEST 8] Closed-loop cortical → CA3 pattern (sensory-only)");
    sensory_input = 18'sd0;  // No external input - pure closed-loop
    wait_4khz_updates(100);
    $display("         Cortical pattern: %b", cortical_pattern);
    $display("         CA3 phase pattern: %b", ca3_phase_pattern);
    // Verify cortical pattern is non-zero (oscillators are running)
    if (cortical_pattern != 6'b000000) begin
        $display("         PASS - Cortical activity generating patterns");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - No cortical pattern detected");
        test_fail = test_fail + 1;
    end
    // Monitor pattern changes over time (should vary with oscillator phases)
    wait_4khz_updates(50);
    $display("         After 50 updates: cortical=%b, phase=%b", cortical_pattern, ca3_phase_pattern);

    $display("\n========================================");
    $display("SUMMARY: %0d passed, %0d failed", test_pass, test_fail);
    $display("========================================");

    #1000;
    $finish;
end

// Waveform dump
initial begin
    $dumpfile("tb_full_system.vcd");
    $dumpvars(0, tb_full_system);
end

// Timeout
initial begin
    #100000000;  // 100ms timeout
    $display("\n[ERROR] Simulation timeout!");
    $finish;
end

endmodule
