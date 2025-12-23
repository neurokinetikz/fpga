//=============================================================================
// Full System Testbench (Fast Version) - v6.3 (Sensory-Only)
//
// v6.3: Uses phi_n_neural_processor with FAST_SIM=1 parameter
// This uses the actual production module with fast clock divider (÷10 vs ÷31250)
// Ensures testbench matches production RTL exactly
//
// v6.2: Removed ca3_pattern_in - sensory_input is the ONLY external data input
// v6.1: Added closed-loop CA3 pattern from cortical activity
// v6.0: Renamed clk_1khz_en → clk_4khz_en throughout
//=============================================================================
`timescale 1ns / 1ps

module tb_full_system_fast;

parameter WIDTH = 18;
parameter FRAC = 14;

// Clock and reset
reg clk;
reg rst;

// Inputs (v6.2: sensory_input is the ONLY external data input)
reg signed [WIDTH-1:0] sensory_input;
reg [2:0] state_select;

// SR field inputs (must be tied to 0 if not used, otherwise undefined propagates)
reg signed [WIDTH-1:0] sr_field_input;
reg signed [5*WIDTH-1:0] sr_field_packed;

//-----------------------------------------------------------------------------
// DUT: phi_n_neural_processor with FAST_SIM=1
// Uses full production module with fast clock divider for simulation
//-----------------------------------------------------------------------------
wire [11:0] dac_output;
wire signed [WIDTH-1:0] debug_motor_l23;
wire signed [WIDTH-1:0] debug_theta;
wire ca3_learning;
wire ca3_recalling;
wire [5:0] ca3_phase_pattern;
wire [5:0] cortical_pattern;

phi_n_neural_processor #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .FAST_SIM(1)  // Use fast clock divider (÷10 vs ÷31250)
) dut (
    .clk(clk),
    .rst(rst),
    .sensory_input(sensory_input),
    .state_select(state_select),
    .sr_field_input(sr_field_input),      // v7.2: External Schumann field
    .sr_field_packed(sr_field_packed),    // v7.3: Multi-harmonic SR fields
    .dac_output(dac_output),
    .debug_motor_l23(debug_motor_l23),
    .debug_theta(debug_theta),
    .ca3_learning(ca3_learning),
    .ca3_recalling(ca3_recalling),
    .ca3_phase_pattern(ca3_phase_pattern),
    .cortical_pattern_out(cortical_pattern)
);

// Hierarchical access to internal signals for monitoring
wire clk_4khz_en = dut.clk_4khz_en;
wire signed [WIDTH-1:0] sensory_l6_x = dut.sensory_l6_x;
wire signed [WIDTH-1:0] assoc_l6_x = dut.assoc_l6_x;
wire signed [WIDTH-1:0] motor_l6_x = dut.motor_l6_x;
wire signed [WIDTH-1:0] sensory_l23_x = dut.sensory_l23_x;
wire signed [WIDTH-1:0] assoc_l23_x = dut.assoc_l23_x;
wire signed [WIDTH-1:0] motor_l23_x = dut.motor_l23_x;
wire signed [WIDTH-1:0] mu_dt_theta = dut.mu_dt_theta;
wire signed [WIDTH-1:0] mu_dt_l6 = dut.mu_dt_l6;
wire signed [WIDTH-1:0] mu_dt_l23 = dut.mu_dt_l23;
wire [5:0] phase_pattern = ca3_phase_pattern;

// Phase coupling access (computed internally, just reference for test display)
wire signed [WIDTH-1:0] theta_couple_base = dut.theta_couple_base;
wire signed [WIDTH-1:0] phase_couple_sensory_l23 = dut.phase_couple_sensory_l23;
wire signed [WIDTH-1:0] phase_couple_motor_l6 = dut.phase_couple_motor_l6;

// Fast clock: 10ns period (100 MHz)
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Test variables
integer test_pass, test_fail;
integer update_count;
integer dac_min, dac_max;
integer peak_count;
reg prev_peak;

//-----------------------------------------------------------------------------
// Task to wait for N 4kHz updates using clock-based synchronization
// This approach is more reliable than @(posedge clk_4khz_en) because:
// 1. It uses the main clock as the timing reference
// 2. It samples clk_4khz_en after a small delay to avoid race conditions
// 3. It matches the approach used in working testbenches (tb_multi_harmonic_sr)
//-----------------------------------------------------------------------------
task wait_updates;
    input integer n;
    integer local_count;
    begin
        local_count = 0;
        while (local_count < n) begin
            @(posedge clk);
            #1;  // Small delay to let combinational logic settle
            if (clk_4khz_en) begin
                local_count = local_count + 1;
                update_count = update_count + 1;
            end
        end
    end
endtask

//-----------------------------------------------------------------------------
// Task to run for N clock cycles, counting updates
//-----------------------------------------------------------------------------
task run_clocks;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk);
            #1;
            if (clk_4khz_en) begin
                update_count = update_count + 1;
            end
        end
    end
endtask

initial begin
    $display("========================================");
    $display("PHI-N NEURAL PROCESSOR v6.2");
    $display("FAST FULL SYSTEM SIMULATION (SENSORY-ONLY)");
    $display("========================================");

    // Initialize (v6.2: sensory_input is the ONLY external data input)
    // Note: Non-zero sensory_input helps excite oscillators during warmup
    rst = 1;
    sensory_input = 18'sd4096;  // Moderate stimulus to excite oscillators
    state_select = 3'd0;  // NORMAL
    sr_field_input = 18'sd0;   // No external SR field (must be initialized!)
    sr_field_packed = 90'd0;   // No external multi-harmonic SR (must be initialized!)
    test_pass = 0;
    test_fail = 0;
    update_count = 0;
    dac_min = 4096;
    dac_max = 0;
    peak_count = 0;
    prev_peak = 0;

    // Hold reset for 100 clock cycles (allows internal state to settle)
    repeat(100) @(posedge clk);
    rst = 0;
    $display("\n[INFO] Reset released at time %0t", $time);

    // Wait a few clocks for first clk_4khz_en pulse
    repeat(20) @(posedge clk);

    // TEST 1: Oscillator startup (wait 500 updates = 500ms equivalent)
    $display("\n[TEST 1] Oscillator startup (500ms warmup)");
    wait_updates(500);
    $display("         Theta: %0d, Motor L2/3: %0d", debug_theta, debug_motor_l23);
    $display("         Sensory L6: %0d, Assoc L6: %0d, Motor L6: %0d",
             sensory_l6_x, assoc_l6_x, motor_l6_x);
    if (debug_theta != 0 && debug_motor_l23 != 0) begin
        $display("         PASS - All oscillators active");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - Oscillators not running");
        test_fail = test_fail + 1;
    end

    // TEST 2: Theta oscillation verification
    // Note: In fast simulation mode, clock timing is compressed.
    // Full frequency verification is done in tb_hopf_oscillator and tb_v55_fast.
    // Here we just verify theta is oscillating (has peaks).
    $display("\n[TEST 2] Theta oscillation (verify peaks exist)");
    peak_count = 0;
    prev_peak = 0;
    begin : test2_block
        integer local_updates;
        local_updates = 0;
        while (local_updates < 2000) begin
            @(posedge clk);
            #1;
            if (clk_4khz_en) begin
                local_updates = local_updates + 1;
                if (debug_theta > 18'sd12000 && !prev_peak) begin
                    peak_count = peak_count + 1;
                    prev_peak = 1;
                end
                if (debug_theta < 18'sd8000) prev_peak = 0;
            end
        end
    end
    $display("         Measured: %0d peaks in 2000 updates", peak_count);
    // In fast mode, just verify oscillation exists (at least 1 peak)
    if (peak_count >= 1) begin
        $display("         PASS - Theta oscillating");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - No theta oscillation detected");
        test_fail = test_fail + 1;
    end

    // TEST 3: DAC output range
    $display("\n[TEST 3] DAC output range");
    dac_min = 4096;
    dac_max = 0;
    begin : test3_block
        integer local_updates;
        local_updates = 0;
        while (local_updates < 1000) begin
            @(posedge clk);
            #1;
            if (clk_4khz_en) begin
                local_updates = local_updates + 1;
                if (dac_output < dac_min) dac_min = dac_output;
                if (dac_output > dac_max) dac_max = dac_output;
            end
        end
    end
    $display("         DAC range: %0d - %0d (span: %0d)", dac_min, dac_max, dac_max - dac_min);
    if ((dac_max - dac_min) > 500) begin
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
    begin : test4_block
        integer local_updates;
        reg learning_found;
        local_updates = 0;
        learning_found = 0;
        while (local_updates < 500 && !learning_found) begin
            @(posedge clk);
            #1;
            if (clk_4khz_en) begin
                local_updates = local_updates + 1;
                if (ca3_learning) begin
                    $display("         Learning triggered at update %0d - PASS", local_updates);
                    test_pass = test_pass + 1;
                    learning_found = 1;
                end
            end
        end
        if (!learning_found) begin
            $display("         Learning not triggered - FAIL");
            test_fail = test_fail + 1;
        end
    end
    wait_updates(100);
    sensory_input = 18'sd0;

    // TEST 5: CA3 recall integration (v6.2: via sensory input)
    $display("\n[TEST 5] CA3 recall via sensory pathway");
    wait_updates(100);
    sensory_input = 18'sd8000;  // Moderate sensory cue
    begin : test5_block
        integer local_updates;
        reg recall_found;
        local_updates = 0;
        recall_found = 0;
        while (local_updates < 500 && !recall_found) begin
            @(posedge clk);
            #1;
            if (clk_4khz_en) begin
                local_updates = local_updates + 1;
                if (ca3_recalling) begin
                    $display("         Recall triggered - PASS");
                    test_pass = test_pass + 1;
                    recall_found = 1;
                end
            end
        end
        if (!recall_found) begin
            $display("         Recall not triggered - FAIL");
            test_fail = test_fail + 1;
        end
    end
    wait_updates(50);
    $display("         Phase pattern output: %b", ca3_phase_pattern);
    sensory_input = 18'sd0;

    // TEST 6: Phase coupling values
    $display("\n[TEST 6] Phase coupling values");
    wait_updates(100);
    $display("         Base coupling: %0d", theta_couple_base);
    $display("         Sens L2/3 coupling: %0d", phase_couple_sensory_l23);
    $display("         Motor L6 coupling: %0d", phase_couple_motor_l6);
    if (theta_couple_base != 0) begin
        $display("         PASS - Phase coupling active");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - No phase coupling");
        test_fail = test_fail + 1;
    end

    // TEST 7: State modulation - Meditation
    // Updated to match v5.5 config_controller values:
    // MEDITATION: stable theta (MU_FULL=4), reduced gamma (MU_HALF=2)
    $display("\n[TEST 7] State modulation (Meditation)");
    state_select = 3'd4;
    wait_updates(100);
    $display("         Mu_dt values in meditation:");
    $display("           Theta: %0d (stable)", mu_dt_theta);
    $display("           L6:    %0d (stable)", mu_dt_l6);
    $display("           L2/3:  %0d (reduced for internal focus)", mu_dt_l23);
    // Expected: mu_theta=4 (MU_FULL), mu_l23=2 (MU_HALF)
    if (mu_dt_theta == 18'sd4 && mu_dt_l23 == 18'sd2) begin
        $display("         PASS - Meditation state active");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - State not configured correctly");
        $display("         Expected: theta=4, l23=2, Got: theta=%0d, l23=%0d", mu_dt_theta, mu_dt_l23);
        test_fail = test_fail + 1;
    end
    state_select = 3'd0;

    // TEST 8: Inter-column signal flow
    $display("\n[TEST 8] Inter-column signal flow");
    wait_updates(200);
    $display("         Sensory L2/3: %0d", sensory_l23_x);
    $display("         Assoc L2/3:   %0d", assoc_l23_x);
    $display("         Motor L2/3:   %0d", motor_l23_x);
    if (sensory_l23_x != 0 && assoc_l23_x != 0 && motor_l23_x != 0) begin
        $display("         PASS - All columns active");
        test_pass = test_pass + 1;
    end else begin
        $display("         FAIL - Column signals missing");
        test_fail = test_fail + 1;
    end

    $display("\n========================================");
    $display("SUMMARY: %0d passed, %0d failed", test_pass, test_fail);
    $display("========================================");

    #1000;
    $finish;
end

// Waveform dump
initial begin
    $dumpfile("tb_full_system_fast.vcd");
    $dumpvars(0, tb_full_system_fast);
end

endmodule
