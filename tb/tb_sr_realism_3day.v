//=============================================================================
// Testbench: 3-Day SR Realism Validation - v1.1
//
// v1.1 CHANGES:
// - Added per-harmonic AMP_SCALE factors for realistic 1/f amplitude decay
// - Enabled SLOW_DRIFT=1 for geophysical drift timescales (120× slower)
//
// Simulates 72 hours of Schumann Resonance dynamics with:
// - Per-harmonic frequency drift (sr_frequency_drift.v v3.2)
// - Per-harmonic Q-factor drift (sr_q_factor_drift.v)
// - 5 Hopf oscillators with per-harmonic amplitude scaling
//
// OUTPUT: sr_realism_3day.csv
//   259,200 samples (1 per simulated second)
//   Columns: time_s, F1-F5 (Hz), A1-A5 (normalized), Q1-Q5 (integer)
//
// USAGE:
//   iverilog -o tb_sr_realism_3day.vvp -s tb_sr_realism_3day -DFAST_SIM \
//       src/clock_enable_generator.v src/hopf_oscillator.v \
//       src/sr_frequency_drift.v src/sr_q_factor_drift.v \
//       tb/tb_sr_realism_3day.v
//   vvp tb_sr_realism_3day.vvp +seed=42
//
// Expected wall-clock time: ~2 minutes with FAST_SIM
//=============================================================================
`timescale 1ns / 1ps

module tb_sr_realism_3day;

//=============================================================================
// Parameters
//=============================================================================
parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 8;  // 125 MHz

// Duration: configurable (72 hours = 259200 seconds)
// Use shorter duration for testing: 1 hour = 3600 seconds
parameter DURATION_S = 259200;  // Full 3-day (72 hours)

// At 4 kHz update rate, 1 second = 4000 clk_en pulses
// Sample every 4000 updates = 1 sample/second (1 Hz for faster sim)
parameter SAMPLE_DIVISOR = 4000;  // 1 Hz output (259,200 samples for 72 hours)

// Total samples = DURATION_S * (4000 / SAMPLE_DIVISOR) = samples per second * duration
// At 10 Hz (SAMPLE_DIVISOR=400): 3600s * 10 = 36000 samples
localparam TOTAL_SAMPLES = DURATION_S * (4000 / SAMPLE_DIVISOR);

// Default seed (can be overridden with +seed=N)
parameter [31:0] DEFAULT_SEED = 32'd42;

//=============================================================================
// Clock and Reset
//=============================================================================
reg clk;
reg rst;

always #(CLK_PERIOD/2) clk = ~clk;

//=============================================================================
// Runtime Seed
//=============================================================================
reg [31:0] runtime_seed;

initial begin
    if (!$value$plusargs("seed=%d", runtime_seed)) begin
        runtime_seed = DEFAULT_SEED;
    end
end

//=============================================================================
// Clock Enable Generator
// Use CLK_DIV_OVERRIDE=1 for maximum simulation speed (clk_en every cycle)
//=============================================================================
wire clk_4khz_en;
wire clk_100khz_en;

clock_enable_generator #(
    .CLK_DIV_OVERRIDE(2)  // clk_en every 2 cycles (need pulse, not constant high)
) clk_gen (
    .clk(clk),
    .rst(rst),
    .clk_4khz_en(clk_4khz_en),
    .clk_100khz_en(clk_100khz_en)
);

//=============================================================================
// SR Frequency Drift
// Note: SEED_OFFSET uses DEFAULT_SEED parameter (runtime_seed can't be used
// for module parameters since they're resolved at elaboration time)
//=============================================================================
wire signed [5*WIDTH-1:0] omega_dt_packed;
wire signed [5*WIDTH-1:0] drift_offset_packed;
wire signed [WIDTH-1:0] omega_dt_f0, omega_dt_f1, omega_dt_f2, omega_dt_f3, omega_dt_f4;

sr_frequency_drift #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .FAST_SIM(1),
    .RANDOM_INIT(1),
    .SEED_OFFSET(DEFAULT_SEED[15:0]),
    .SLOW_DRIFT(1)   // v3.2: Enable slow drift for 3-day realism (120× slower)
) sr_drift (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .omega_dt_packed(omega_dt_packed),
    .drift_offset_packed(drift_offset_packed),
    .omega_dt_f0_actual(omega_dt_f0),
    .omega_dt_f1_actual(omega_dt_f1),
    .omega_dt_f2_actual(omega_dt_f2),
    .omega_dt_f3_actual(omega_dt_f3),
    .omega_dt_f4_actual(omega_dt_f4)
);

//=============================================================================
// SR Q-Factor Drift
//=============================================================================
wire signed [5*WIDTH-1:0] q_factor_packed;
wire signed [5*WIDTH-1:0] q_scaled_packed;
wire signed [WIDTH-1:0] q_f0, q_f1, q_f2, q_f3, q_f4;

sr_q_factor_drift #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .FAST_SIM(1),
    .RANDOM_INIT(1),
    .SEED_OFFSET(DEFAULT_SEED[15:0] ^ 16'hAAAA)  // Different from freq drift
) q_drift (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_4khz_en),
    .q_factor_packed(q_factor_packed),
    .q_scaled_packed(q_scaled_packed),
    .q_f0_scaled(q_f0),
    .q_f1_scaled(q_f1),
    .q_f2_scaled(q_f2),
    .q_f3_scaled(q_f3),
    .q_f4_scaled(q_f4)
);

//=============================================================================
// Hopf Oscillators (5 SR harmonics)
//=============================================================================
// MU_DT = mu * DT / ONE = 3.0 * 4 / 16384 = 196 (Q14)
localparam signed [WIDTH-1:0] MU_DT = 18'sd196;

// Per-harmonic amplitude scale factors (from sr_harmonic_bank.v)
// Models real SR 1/f amplitude decay: higher harmonics have lower power
localparam signed [WIDTH-1:0] AMP_SCALE_F0 = 18'sd16384;  // 1.0
localparam signed [WIDTH-1:0] AMP_SCALE_F1 = 18'sd13926;  // 0.85
localparam signed [WIDTH-1:0] AMP_SCALE_F2 = 18'sd5571;   // 0.34 ≈ φ⁻²
localparam signed [WIDTH-1:0] AMP_SCALE_F3 = 18'sd2458;   // 0.15 ≈ φ⁻⁴
localparam signed [WIDTH-1:0] AMP_SCALE_F4 = 18'sd983;    // 0.06 ≈ φ⁻⁶

wire signed [WIDTH-1:0] f0_x, f0_y, f0_amp;
wire signed [WIDTH-1:0] f1_x, f1_y, f1_amp;
wire signed [WIDTH-1:0] f2_x, f2_y, f2_amp;
wire signed [WIDTH-1:0] f3_x, f3_y, f3_amp;
wire signed [WIDTH-1:0] f4_x, f4_y, f4_amp;

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_f0 (
    .clk(clk), .rst(rst), .clk_en(clk_4khz_en),
    .mu_dt(MU_DT), .omega_dt(omega_dt_f0), .input_x(18'sd0),
    .x(f0_x), .y(f0_y), .amplitude(f0_amp)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_f1 (
    .clk(clk), .rst(rst), .clk_en(clk_4khz_en),
    .mu_dt(MU_DT), .omega_dt(omega_dt_f1), .input_x(18'sd0),
    .x(f1_x), .y(f1_y), .amplitude(f1_amp)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_f2 (
    .clk(clk), .rst(rst), .clk_en(clk_4khz_en),
    .mu_dt(MU_DT), .omega_dt(omega_dt_f2), .input_x(18'sd0),
    .x(f2_x), .y(f2_y), .amplitude(f2_amp)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_f3 (
    .clk(clk), .rst(rst), .clk_en(clk_4khz_en),
    .mu_dt(MU_DT), .omega_dt(omega_dt_f3), .input_x(18'sd0),
    .x(f3_x), .y(f3_y), .amplitude(f3_amp)
);

hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) osc_f4 (
    .clk(clk), .rst(rst), .clk_en(clk_4khz_en),
    .mu_dt(MU_DT), .omega_dt(omega_dt_f4), .input_x(18'sd0),
    .x(f4_x), .y(f4_y), .amplitude(f4_amp)
);

//=============================================================================
// Frequency Conversion: OMEGA_DT (Q14) to Hz
// Formula: f_hz = OMEGA_DT / (2*pi * dt * 2^14)
// At 4kHz: dt = 0.00025, so divisor = 2*pi*0.00025*16384 = 25.736
// f_hz = OMEGA_DT * 1000 / 25736 (scaled for integer math)
// Better: f_hz_x100 = OMEGA_DT * 388585 / 100000 ≈ OMEGA_DT * 3886 / 1000
//=============================================================================
wire signed [31:0] f_hz_x100_0, f_hz_x100_1, f_hz_x100_2, f_hz_x100_3, f_hz_x100_4;

assign f_hz_x100_0 = (omega_dt_f0 * 3886) / 1000;  // Hz * 100
assign f_hz_x100_1 = (omega_dt_f1 * 3886) / 1000;
assign f_hz_x100_2 = (omega_dt_f2 * 3886) / 1000;
assign f_hz_x100_3 = (omega_dt_f3 * 3886) / 1000;
assign f_hz_x100_4 = (omega_dt_f4 * 3886) / 1000;

//=============================================================================
// Amplitude Scaling (Q14 to 0-100 normalized with per-harmonic scaling)
// amplitude in Q14 (16384 = 1.0), apply AMP_SCALE, then scale to 0-100
// This models real SR 1/f amplitude hierarchy: A1 > A2 > A3 > A4 > A5
//=============================================================================
wire signed [31:0] amp_scaled_0, amp_scaled_1, amp_scaled_2, amp_scaled_3, amp_scaled_4;

// Apply AMP_SCALE first (Q14 * Q14 >> 14 = Q14), then scale to 0-100
assign amp_scaled_0 = (((f0_amp * AMP_SCALE_F0) >>> FRAC) * 100) >>> FRAC;
assign amp_scaled_1 = (((f1_amp * AMP_SCALE_F1) >>> FRAC) * 100) >>> FRAC;
assign amp_scaled_2 = (((f2_amp * AMP_SCALE_F2) >>> FRAC) * 100) >>> FRAC;
assign amp_scaled_3 = (((f3_amp * AMP_SCALE_F3) >>> FRAC) * 100) >>> FRAC;
assign amp_scaled_4 = (((f4_amp * AMP_SCALE_F4) >>> FRAC) * 100) >>> FRAC;

//=============================================================================
// Main Test Sequence
//=============================================================================
integer csv_file;
integer sample_count;
integer update_count;
reg prev_clk_en;

initial begin
    // Initialize
    clk = 0;
    rst = 1;
    sample_count = 0;
    update_count = 0;
    prev_clk_en = 0;

    // Wait for seed to be read
    #1;

    // Open CSV file
    csv_file = $fopen("sr_realism_3day.csv", "w");
    if (csv_file == 0) begin
        $display("ERROR: Could not open output file!");
        $finish;
    end

    // Write header
    $fwrite(csv_file, "time_s,F1,F2,F3,F4,F5,A1,A2,A3,A4,A5,Q1,Q2,Q3,Q4,Q5\n");

    $display("=============================================================================");
    $display("3-Day SR Realism Validation Testbench");
    $display("=============================================================================");
    $display("Duration: 72 hours (%0d seconds, %0d samples)", DURATION_S, TOTAL_SAMPLES);
    $display("Seed: %0d", runtime_seed);
    $display("Output: sr_realism_3day.csv");
    $display("=============================================================================");

    // Release reset
    repeat(100) @(posedge clk);
    rst = 0;

    // Brief stabilization (1000 cycles ~ 0.08 seconds)
    repeat(1000) @(posedge clk);

    // Debug: Print raw omega values to verify connections
    $display("");
    $display("DEBUG: Raw OMEGA_DT values after stabilization:");
    $display("  omega_dt_f0 = %0d (expect ~199)", $signed(omega_dt_f0));
    $display("  omega_dt_f1 = %0d (expect ~354)", $signed(omega_dt_f1));
    $display("  omega_dt_f2 = %0d (expect ~514)", $signed(omega_dt_f2));
    $display("  omega_dt_f3 = %0d (expect ~643)", $signed(omega_dt_f3));
    $display("  omega_dt_f4 = %0d (expect ~823)", $signed(omega_dt_f4));
    $display("");

    $display("Recording SR data (72 hours at 1 Hz)...");
    $display("");

    // Main export loop
    while (sample_count < TOTAL_SAMPLES) begin
        @(posedge clk);

        // Detect clk_en rising edge
        if (clk_4khz_en && !prev_clk_en) begin
            update_count = update_count + 1;

            // Sample every SAMPLE_DIVISOR updates (4000 = 1 sample/second)
            if ((update_count % SAMPLE_DIVISOR) == 0) begin
                // Write data row
                // Format: time_s,F1,F2,F3,F4,F5,A1,A2,A3,A4,A5,Q1,Q2,Q3,Q4,Q5
                $fwrite(csv_file, "%0d,", sample_count);

                // Frequencies (Hz with 2 decimal places)
                $fwrite(csv_file, "%0d.%02d,", f_hz_x100_0/100, f_hz_x100_0 % 100);
                $fwrite(csv_file, "%0d.%02d,", f_hz_x100_1/100, f_hz_x100_1 % 100);
                $fwrite(csv_file, "%0d.%02d,", f_hz_x100_2/100, f_hz_x100_2 % 100);
                $fwrite(csv_file, "%0d.%02d,", f_hz_x100_3/100, f_hz_x100_3 % 100);
                $fwrite(csv_file, "%0d.%02d,", f_hz_x100_4/100, f_hz_x100_4 % 100);

                // Amplitudes (0-100 normalized)
                $fwrite(csv_file, "%0d,", amp_scaled_0);
                $fwrite(csv_file, "%0d,", amp_scaled_1);
                $fwrite(csv_file, "%0d,", amp_scaled_2);
                $fwrite(csv_file, "%0d,", amp_scaled_3);
                $fwrite(csv_file, "%0d,", amp_scaled_4);

                // Q-factors (integer)
                $fwrite(csv_file, "%0d,", $signed(q_f0));
                $fwrite(csv_file, "%0d,", $signed(q_f1));
                $fwrite(csv_file, "%0d,", $signed(q_f2));
                $fwrite(csv_file, "%0d,", $signed(q_f3));
                $fwrite(csv_file, "%0d\n", $signed(q_f4));

                sample_count = sample_count + 1;

                // Progress every 1 hour (3600 samples)
                if (sample_count % 3600 == 0) begin
                    $display("  Hour %2d: F1=%0d.%02d Hz, Q1=%0d, A1=%0d",
                        sample_count/3600,
                        f_hz_x100_0/100, f_hz_x100_0 % 100,
                        $signed(q_f0),
                        amp_scaled_0);
                end
            end
        end

        prev_clk_en <= clk_4khz_en;
    end

    // Close file
    $fclose(csv_file);

    $display("");
    $display("=============================================================================");
    $display("Export complete: sr_realism_3day.csv");
    $display("Total samples: %0d (72 hours at 1 Hz)", sample_count);
    $display("");
    $display("Analyze results:");
    $display("  python3 scripts/analyze_sr_realism.py");
    $display("=============================================================================");

    $finish;
end

endmodule
