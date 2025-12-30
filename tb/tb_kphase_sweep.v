//=============================================================================
// K_PHASE Stability Sweep Testbench
// Tests different K_PHASE values to find stable coupling regime
//=============================================================================
`timescale 1ns / 1ps

module tb_kphase_sweep;

parameter WIDTH = 18;
parameter FRAC = 14;

// Clock and reset
reg clk;
reg rst;

// Test control
reg signed [WIDTH-1:0] k_phase_test;
reg [5:0] pattern_in;

// Fast clock enable
reg clk_en;

// Theta oscillator
wire signed [WIDTH-1:0] theta_x, theta_y, theta_amp;
localparam signed [WIDTH-1:0] MU_DT = 18'sd4;      // 4 kHz update rate
localparam signed [WIDTH-1:0] OMEGA_THETA = 18'sd157;  // 6.09 Hz at 4 kHz (v12.2: φ^-0.5 × 7.75)

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) theta_osc (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(MU_DT), .omega_dt(OMEGA_THETA), .input_x(18'sd0),
    .x(theta_x), .y(theta_y), .amplitude(theta_amp)
);

// Gamma oscillator (L2/3) with phase coupling
wire signed [WIDTH-1:0] gamma_x, gamma_y, gamma_amp;
localparam signed [WIDTH-1:0] OMEGA_GAMMA = 18'sd1075;  // 41.76 Hz at 4 kHz (v12.2: φ^3.5 × 7.75)

// Phase coupling computation
wire signed [2*WIDTH-1:0] theta_scaled;
wire signed [WIDTH-1:0] theta_couple_base;
wire signed [WIDTH-1:0] phase_couple;

assign theta_scaled = k_phase_test * theta_x;
assign theta_couple_base = theta_scaled >>> FRAC;
assign phase_couple = pattern_in[0] ? theta_couple_base : -theta_couple_base;

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) gamma_osc (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(MU_DT), .omega_dt(OMEGA_GAMMA), .input_x(phase_couple),
    .x(gamma_x), .y(gamma_y), .amplitude(gamma_amp)
);

// Alpha oscillator (L6) with phase coupling
wire signed [WIDTH-1:0] alpha_x, alpha_y, alpha_amp;
localparam signed [WIDTH-1:0] OMEGA_ALPHA = 18'sd254;  // 9.86 Hz at 4 kHz (v12.2: φ^0.5 × 7.75)

wire signed [WIDTH-1:0] phase_couple_alpha;
assign phase_couple_alpha = pattern_in[1] ? theta_couple_base : -theta_couple_base;

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) alpha_osc (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(MU_DT), .omega_dt(OMEGA_ALPHA), .input_x(phase_couple_alpha),
    .x(alpha_x), .y(alpha_y), .amplitude(alpha_amp)
);

// Clock: 10ns period
initial begin clk = 0; forever #5 clk = ~clk; end

// Test variables
integer i, j;
integer update_count;

// Metrics per K_PHASE value
integer theta_amp_min, theta_amp_max;
integer gamma_amp_min, gamma_amp_max;
integer alpha_amp_min, alpha_amp_max;
integer theta_zero_crossings;
integer gamma_zero_crossings;
integer coupling_magnitude_sum;
integer coupling_samples;

reg theta_prev_sign;
reg gamma_prev_sign;

// K_PHASE values to test
reg signed [WIDTH-1:0] kphase_values [0:5];

// Results storage
reg [2:0] stability [0:5];  // 0=UNSTABLE, 1=MARGINAL, 2=STABLE

// For stable range calculation
integer min_stable, max_stable;

// Task to run one K_PHASE test
task run_kphase_test;
    input signed [WIDTH-1:0] kp;
    input integer test_idx;
    begin
        // Reset
        rst = 1;
        k_phase_test = kp;
        pattern_in = 6'b101010;  // Alternating pattern
        repeat(10) @(posedge clk);
        rst = 0;

        // Warmup (500 updates)
        for (i = 0; i < 500; i = i + 1) begin
            @(posedge clk); clk_en = 1;
            @(posedge clk); clk_en = 0;
        end

        // Reset metrics
        theta_amp_min = 100000;
        theta_amp_max = 0;
        gamma_amp_min = 100000;
        gamma_amp_max = 0;
        alpha_amp_min = 100000;
        alpha_amp_max = 0;
        theta_zero_crossings = 0;
        gamma_zero_crossings = 0;
        coupling_magnitude_sum = 0;
        coupling_samples = 0;
        theta_prev_sign = theta_x[WIDTH-1];
        gamma_prev_sign = gamma_x[WIDTH-1];

        // Measurement period (2000 updates = 2 seconds)
        for (update_count = 0; update_count < 2000; update_count = update_count + 1) begin
            @(posedge clk); clk_en = 1;
            @(posedge clk); clk_en = 0;

            // Track amplitude bounds
            if (theta_amp < theta_amp_min) theta_amp_min = theta_amp;
            if (theta_amp > theta_amp_max) theta_amp_max = theta_amp;
            if (gamma_amp < gamma_amp_min) gamma_amp_min = gamma_amp;
            if (gamma_amp > gamma_amp_max) gamma_amp_max = gamma_amp;
            if (alpha_amp < alpha_amp_min) alpha_amp_min = alpha_amp;
            if (alpha_amp > alpha_amp_max) alpha_amp_max = alpha_amp;

            // Count zero crossings for frequency
            if (theta_x[WIDTH-1] != theta_prev_sign) begin
                theta_zero_crossings = theta_zero_crossings + 1;
                theta_prev_sign = theta_x[WIDTH-1];
            end
            if (gamma_x[WIDTH-1] != gamma_prev_sign) begin
                gamma_zero_crossings = gamma_zero_crossings + 1;
                gamma_prev_sign = gamma_x[WIDTH-1];
            end

            // Track coupling magnitude
            coupling_magnitude_sum = coupling_magnitude_sum +
                (phase_couple[WIDTH-1] ? -phase_couple : phase_couple);
            coupling_samples = coupling_samples + 1;
        end

        // Determine stability
        // UNSTABLE: amplitude exploded (>50000) or collapsed (<1000)
        // MARGINAL: amplitude range >2x normal
        // STABLE: amplitude range within expected bounds

        if (theta_amp_max > 50000 || gamma_amp_max > 50000 || alpha_amp_max > 50000 ||
            theta_amp_min < 1000 || gamma_amp_min < 1000 || alpha_amp_min < 1000) begin
            stability[test_idx] = 0;  // UNSTABLE
        end else if ((theta_amp_max - theta_amp_min) > 20000 ||
                     (gamma_amp_max - gamma_amp_min) > 20000 ||
                     (alpha_amp_max - alpha_amp_min) > 20000) begin
            stability[test_idx] = 1;  // MARGINAL
        end else begin
            stability[test_idx] = 2;  // STABLE
        end
    end
endtask

// Stability string helper
function [63:0] stability_str;
    input [2:0] s;
    begin
        case (s)
            0: stability_str = "UNSTABLE";
            1: stability_str = "MARGINAL";
            2: stability_str = "STABLE  ";
            default: stability_str = "UNKNOWN ";
        endcase
    end
endfunction

initial begin
    $display("========================================");
    $display("K_PHASE STABILITY SWEEP");
    $display("========================================");
    $display("");
    $display("Testing phase coupling strength values");
    $display("to find stable operating regime.");
    $display("");

    // Initialize K_PHASE test values
    kphase_values[0] = 18'sd512;    // 0.03125
    kphase_values[1] = 18'sd1024;   // 0.0625
    kphase_values[2] = 18'sd2048;   // 0.125 (current)
    kphase_values[3] = 18'sd4096;   // 0.25
    kphase_values[4] = 18'sd8192;   // 0.5
    kphase_values[5] = 18'sd16384;  // 1.0

    clk_en = 0;
    rst = 1;
    k_phase_test = 18'sd2048;
    pattern_in = 6'b000000;

    // Run tests
    for (j = 0; j < 6; j = j + 1) begin
        $display("Testing K_PHASE = %0d (%.4f)...",
                 kphase_values[j],
                 $itor(kphase_values[j]) / 16384.0);
        run_kphase_test(kphase_values[j], j);

        $display("  Theta: amp=%0d-%0d, freq=%.1f Hz",
                 theta_amp_min, theta_amp_max,
                 theta_zero_crossings / 4.0);  // 2000 updates = 2s, /2 for zero crossings
        $display("  Gamma: amp=%0d-%0d, freq=%.1f Hz",
                 gamma_amp_min, gamma_amp_max,
                 gamma_zero_crossings / 4.0);
        $display("  Alpha: amp=%0d-%0d",
                 alpha_amp_min, alpha_amp_max);
        $display("  Avg coupling: %0d",
                 coupling_magnitude_sum / coupling_samples);
        $display("  Status: %s", stability_str(stability[j]));
        $display("");
    end

    // Summary
    $display("========================================");
    $display("SUMMARY");
    $display("========================================");
    $display("");
    $display("K_PHASE     | Decimal | Status   | Notes");
    $display("------------|---------|----------|------------------");

    for (j = 0; j < 6; j = j + 1) begin
        $display("%5d       | %.4f  | %s | %s",
                 kphase_values[j],
                 $itor(kphase_values[j]) / 16384.0,
                 stability_str(stability[j]),
                 (kphase_values[j] == 2048) ? "<-- CURRENT" : "");
    end

    $display("");
    $display("========================================");
    $display("RECOMMENDATION");
    $display("========================================");

    // Find stable range
    min_stable = -1;
    max_stable = -1;

    for (j = 0; j < 6; j = j + 1) begin
        if (stability[j] >= 2) begin  // STABLE
            if (min_stable < 0) min_stable = kphase_values[j];
            max_stable = kphase_values[j];
        end
    end

    if (min_stable > 0) begin
        $display("Stable range: %0d to %0d", min_stable, max_stable);
        $display("Recommended:  %0d (current value)", 18'sd2048);
    end else begin
        $display("WARNING: No stable K_PHASE values found!");
    end

    $display("========================================");

    $finish;
end

// Waveform dump
initial begin
    $dumpfile("tb_kphase_sweep.vcd");
    $dumpvars(0, tb_kphase_sweep);
end

endmodule
