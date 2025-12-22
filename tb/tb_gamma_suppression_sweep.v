//=============================================================================
// Gamma Suppression Parametric Sweep Testbench
//
// Models biological propofol dose-response using sigmoidal pharmacokinetics.
// Based on empirical data: EC50 ≈ 1.3 mg/kg, Hill coefficient k ≈ 2.5
//
// The sigmoid: P(dose) = 1 / (1 + exp(-k*(dose - EC50)))
// Gamma level = 1 - P(dose)  (more drug = less gamma)
//
// Biologically: Propofol enhances GABA-A receptor activity, which
// inhibits fast-spiking interneurons that generate gamma oscillations.
//=============================================================================
`timescale 1ns / 1ps

module tb_gamma_suppression_sweep;

parameter WIDTH = 18;
parameter FRAC = 14;

//-----------------------------------------------------------------------------
// Clock, Reset, and Control
//-----------------------------------------------------------------------------
reg clk, rst;
reg clk_en;
reg [2:0] state_select;

//-----------------------------------------------------------------------------
// Oscillator Parameters (matching tb_state_characterization.v)
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] MU_DT = 18'sd4;
localparam signed [WIDTH-1:0] OMEGA_THETA = 18'sd152;  // 5.89 Hz at 4 kHz
localparam signed [WIDTH-1:0] OMEGA_GAMMA = 18'sd1039; // 40.36 Hz at 4 kHz

//-----------------------------------------------------------------------------
// Oscillator Outputs
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] theta_x, theta_y, theta_amp;
wire signed [WIDTH-1:0] gamma_x_raw, gamma_y_raw, gamma_amp_raw;
wire signed [WIDTH-1:0] gamma_x, gamma_y, gamma_amp;

//-----------------------------------------------------------------------------
// Gamma Suppression Variable (Q4.14: 16384 = 1.0)
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] gamma_suppression;

//-----------------------------------------------------------------------------
// Theta Oscillator (thalamic pacemaker - less affected by propofol)
//-----------------------------------------------------------------------------
hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) theta_osc (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(MU_DT), .omega_dt(OMEGA_THETA), .input_x(18'sd0),
    .x(theta_x), .y(theta_y), .amplitude(theta_amp)
);

//-----------------------------------------------------------------------------
// Gamma Oscillator (cortical L2/3 - primary propofol target)
//-----------------------------------------------------------------------------
hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) gamma_osc (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(MU_DT), .omega_dt(OMEGA_GAMMA), .input_x(18'sd0),
    .x(gamma_x_raw), .y(gamma_y_raw), .amplitude(gamma_amp_raw)
);

//-----------------------------------------------------------------------------
// Apply Gamma Suppression (models GABAergic inhibition)
//-----------------------------------------------------------------------------
assign gamma_x   = (gamma_x_raw * gamma_suppression) >>> FRAC;
assign gamma_y   = (gamma_y_raw * gamma_suppression) >>> FRAC;
assign gamma_amp = (gamma_amp_raw * gamma_suppression) >>> FRAC;

//-----------------------------------------------------------------------------
// Clock Generation (100 MHz -> 10 ns period)
//-----------------------------------------------------------------------------
initial begin clk = 0; forever #5 clk = ~clk; end

//-----------------------------------------------------------------------------
// Measurement Variables
//-----------------------------------------------------------------------------
integer i, j;
integer update_count;
integer pattern_transitions;
integer gamma_amp_sum, gamma_amp_count;
integer gamma_amp_min, gamma_amp_max;
reg [1:0] prev_pattern, curr_pattern;

// Histogram for pattern entropy
integer pattern_hist [0:3];  // 2-bit pattern from gamma/theta signs

//-----------------------------------------------------------------------------
// Task: Run measurement for current suppression level
//-----------------------------------------------------------------------------
task run_measurement;
    input integer n_updates;
    begin
        // Reset counters
        pattern_transitions = 0;
        gamma_amp_sum = 0;
        gamma_amp_count = 0;
        gamma_amp_min = 32'h7FFFFFFF;
        gamma_amp_max = 0;
        for (j = 0; j < 4; j = j + 1) pattern_hist[j] = 0;
        prev_pattern = 2'b00;

        // Measurement loop
        for (i = 0; i < n_updates; i = i + 1) begin
            @(posedge clk); clk_en = 1;
            @(posedge clk); clk_en = 0;

            // Track gamma amplitude
            if (gamma_amp > 0) begin
                gamma_amp_sum = gamma_amp_sum + gamma_amp;
                gamma_amp_count = gamma_amp_count + 1;
                if (gamma_amp < gamma_amp_min) gamma_amp_min = gamma_amp;
                if (gamma_amp > gamma_amp_max) gamma_amp_max = gamma_amp;
            end

            // Track pattern: 2 bits from gamma and theta signs
            curr_pattern = {(gamma_x > 0), (theta_x > 0)};
            pattern_hist[curr_pattern] = pattern_hist[curr_pattern] + 1;
            if (curr_pattern != prev_pattern) begin
                pattern_transitions = pattern_transitions + 1;
            end
            prev_pattern = curr_pattern;
        end
    end
endtask

//-----------------------------------------------------------------------------
// Main Test: Propofol Dose-Response Sweep
//-----------------------------------------------------------------------------
initial begin
    $display("================================================================================");
    $display("PROPOFOL DOSE-RESPONSE: GAMMA SUPPRESSION MODEL");
    $display("================================================================================");
    $display("");
    $display("Pharmacokinetic model: Sigmoid with EC50=1.3 mg/kg, Hill coeff k=2.5");
    $display("Mechanism: GABA-A enhancement -> PV+ interneuron inhibition -> gamma block");
    $display("");
    $display(" Dose     | Gamma   | Gamma Amp | Transitions | Clinical State");
    $display(" (mg/kg)  | Level   |  (mean)   |   /4000     |");
    $display("----------|---------|-----------|-------------|---------------------------");

    // Initialize
    rst = 1; clk_en = 0;
    state_select = 3'd0;
    gamma_suppression = 18'sd16384;

    #100;
    rst = 0;

    // Warmup (500 ms at 4 kHz = 2000 updates)
    for (i = 0; i < 2000; i = i + 1) begin
        @(posedge clk); clk_en = 1;
        @(posedge clk); clk_en = 0;
    end

    //=========================================================================
    // PROPOFOL DOSE-RESPONSE CURVE (from empirical data)
    //
    // Sigmoid: P(dose) = 1 / (1 + exp(-2.5*(dose - 1.3)))
    // Gamma level = 1 - P(dose)
    //
    // In Q4.14 fixed-point (16384 = 1.0):
    //=========================================================================

    // 0.0 mg/kg - Awake baseline (no drug)
    // P(0) = 1/(1+exp(3.25)) ≈ 0.037 → gamma_level = 0.963
    gamma_suppression = 18'sd15778;  // 0.963 * 16384
    run_measurement(4000);
    $display("  0.0     |  96.3%%  |   %6d  |    %5d    |  Awake (baseline)",
             gamma_amp_sum / (gamma_amp_count > 0 ? gamma_amp_count : 1),
             pattern_transitions);

    // 0.5 mg/kg - Sub-sedative / Anxiolysis
    // P(0.5) = 1/(1+exp(2.0)) ≈ 0.119 → gamma_level = 0.881
    gamma_suppression = 18'sd14434;  // 0.881 * 16384
    run_measurement(4000);
    $display("  0.5     |  88.1%%  |   %6d  |    %5d    |  Anxiolysis (sub-sedative)",
             gamma_amp_sum / (gamma_amp_count > 0 ? gamma_amp_count : 1),
             pattern_transitions);

    // 1.0 mg/kg - Light sedation
    // P(1.0) = 1/(1+exp(0.75)) ≈ 0.321 → gamma_level = 0.679
    gamma_suppression = 18'sd11124;  // 0.679 * 16384
    run_measurement(4000);
    $display("  1.0     |  67.9%%  |   %6d  |    %5d    |  Light sedation",
             gamma_amp_sum / (gamma_amp_count > 0 ? gamma_amp_count : 1),
             pattern_transitions);

    // 1.3 mg/kg - EC50 (50% effect)
    // P(1.3) = 1/(1+exp(0)) = 0.500 → gamma_level = 0.500
    gamma_suppression = 18'sd8192;   // 0.500 * 16384
    run_measurement(4000);
    $display("  1.3     |  50.0%%  |   %6d  |    %5d    |  EC50 - moderate sedation",
             gamma_amp_sum / (gamma_amp_count > 0 ? gamma_amp_count : 1),
             pattern_transitions);

    // 1.5 mg/kg - Deep sedation (near LOC)
    // P(1.5) = 1/(1+exp(-0.5)) ≈ 0.622 → gamma_level = 0.378
    gamma_suppression = 18'sd6193;   // 0.378 * 16384
    run_measurement(4000);
    $display("  1.5     |  37.8%%  |   %6d  |    %5d    |  Deep sedation (near LOC)",
             gamma_amp_sum / (gamma_amp_count > 0 ? gamma_amp_count : 1),
             pattern_transitions);

    // 2.0 mg/kg - Loss of consciousness (LOC)
    // P(2.0) = 1/(1+exp(-1.75)) ≈ 0.852 → gamma_level = 0.148
    gamma_suppression = 18'sd2425;   // 0.148 * 16384
    run_measurement(4000);
    $display("  2.0     |  14.8%%  |   %6d  |    %5d    |  LOC - light anesthesia",
             gamma_amp_sum / (gamma_amp_count > 0 ? gamma_amp_count : 1),
             pattern_transitions);

    // 2.5 mg/kg - Surgical anesthesia
    // P(2.5) = 1/(1+exp(-3.0)) ≈ 0.953 → gamma_level = 0.047
    gamma_suppression = 18'sd770;    // 0.047 * 16384
    run_measurement(4000);
    $display("  2.5     |   4.7%%  |   %6d  |    %5d    |  Surgical anesthesia",
             gamma_amp_sum / (gamma_amp_count > 0 ? gamma_amp_count : 1),
             pattern_transitions);

    // 3.0 mg/kg - Deep anesthesia (burst suppression)
    // P(3.0) = 1/(1+exp(-4.25)) ≈ 0.986 → gamma_level = 0.014
    gamma_suppression = 18'sd229;    // 0.014 * 16384
    run_measurement(4000);
    $display("  3.0     |   1.4%%  |   %6d  |    %5d    |  Deep anesthesia (burst supp)",
             gamma_amp_sum / (gamma_amp_count > 0 ? gamma_amp_count : 1),
             pattern_transitions);

    // 4.0 mg/kg - Isoelectric (complete suppression)
    // P(4.0) ≈ 0.999 → gamma_level ≈ 0.001
    gamma_suppression = 18'sd16;     // ~0.001 * 16384
    run_measurement(4000);
    $display("  4.0     |   0.1%%  |   %6d  |    %5d    |  Isoelectric (overdose risk)",
             gamma_amp_sum / (gamma_amp_count > 0 ? gamma_amp_count : 1),
             pattern_transitions);

    $display("");
    $display("================================================================================");
    $display("BIOLOGICAL INTERPRETATION:");
    $display("================================================================================");
    $display("");
    $display("  Propofol Mechanism:");
    $display("  - Binds GABA-A receptors, enhancing inhibitory currents");
    $display("  - PV+ fast-spiking interneurons are highly sensitive");
    $display("  - These interneurons generate 40 Hz gamma via PING mechanism");
    $display("  - Result: Dose-dependent gamma power reduction");
    $display("");
    $display("  Clinical Correlates:");
    $display("  - EC50 (1.3 mg/kg): 50%% gamma suppression, loss of responsiveness");
    $display("  - LOC (2.0 mg/kg): ~85%% suppression, no purposeful movement");
    $display("  - Surgical (2.5 mg/kg): >95%% suppression, burst-suppression EEG");
    $display("");
    $display("  Consciousness Signatures:");
    $display("  - Pattern transitions correlate with information integration (Phi)");
    $display("  - Gamma-theta coupling (PLV) collapses before LOC");
    $display("  - This model captures the gamma component of anesthetic mechanisms");
    $display("");
    $display("================================================================================");

    $finish;
end

//-----------------------------------------------------------------------------
// Waveform dump for GTKWave visualization
//-----------------------------------------------------------------------------
initial begin
    $dumpfile("tb_gamma_suppression_sweep.vcd");
    $dumpvars(0, tb_gamma_suppression_sweep);
end

endmodule
