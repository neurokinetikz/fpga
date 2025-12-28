//=============================================================================
// Testbench: EEG Export - All Oscillator Outputs for Comparison Analysis
//
// Exports all 21 oscillator waveforms to CSV for offline EEG comparison.
// Designed for spectral analysis (PSD), phase-amplitude coupling (PAC),
// and cross-frequency coherence studies.
//
// Output: oscillator_eeg_export.csv
//   - 27 columns: time, state, theta_phase, theta x/y, 5 SR, 15 cortical
//   - 1 kHz sample rate (every 4th clk_4khz_en update)
//   - Default 60 seconds (60,000 samples)
//
// Usage:
//   iverilog -o tb_eeg_export.vvp -s tb_eeg_export \
//       src/clock_enable_generator.v src/hopf_oscillator.v \
//       src/hopf_oscillator_stochastic.v src/ca3_phase_memory.v \
//       src/thalamus.v src/cortical_column.v src/config_controller.v \
//       src/pink_noise_generator.v src/output_mixer.v \
//       src/phi_n_neural_processor.v src/sr_harmonic_bank.v \
//       src/sr_noise_generator.v src/sr_frequency_drift.v \
//       src/layer1_minimal.v src/pv_interneuron.v \
//       src/dendritic_compartment.v \
//       tb/tb_eeg_export.v && vvp tb_eeg_export.vvp
//
//   python3 scripts/analyze_eeg_comparison.py oscillator_eeg_export.csv
//=============================================================================
`timescale 1ns / 1ps

module tb_eeg_export;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 8;  // 125 MHz
parameter DURATION_MS = 60000;  // 60 seconds of simulated time
parameter SAMPLE_DIVISOR = 4;   // Sample every 4th update = 1 kHz output

// Total samples to export
localparam TOTAL_SAMPLES = DURATION_MS;  // 1 sample per ms at 1 kHz

reg clk;
reg rst;
reg signed [WIDTH-1:0] sensory_input;
reg signed [WIDTH-1:0] sr_field_input;
reg [2:0] state_select;

// Top-level outputs
wire [11:0] dac_output;
wire signed [WIDTH-1:0] debug_motor_l23;
wire signed [WIDTH-1:0] debug_theta;
wire ca3_learning, ca3_recalling;
wire [5:0] ca3_phase_pattern;
wire [5:0] cortical_pattern_out;

// SR outputs
wire signed [WIDTH-1:0] f0_x, f0_y, f0_amplitude;
wire signed [WIDTH-1:0] sr_coherence;
wire sr_amplification;
wire beta_quiet;
wire [2:0] theta_phase;

// Multi-harmonic SR packed outputs
wire signed [5*WIDTH-1:0] sr_f_x_packed;
wire signed [5*WIDTH-1:0] sr_coherence_packed;
wire [4:0] sie_per_harmonic;
wire [4:0] coherence_mask;

// Instantiate DUT with FAST_SIM
phi_n_neural_processor #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .FAST_SIM(1)
) dut (
    .clk(clk),
    .rst(rst),
    .sensory_input(sensory_input),
    .state_select(state_select),
    .sr_field_input(sr_field_input),
    .sr_field_packed(90'd0),
    .dac_output(dac_output),
    .debug_motor_l23(debug_motor_l23),
    .debug_theta(debug_theta),
    .ca3_learning(ca3_learning),
    .ca3_recalling(ca3_recalling),
    .ca3_phase_pattern(ca3_phase_pattern),
    .cortical_pattern_out(cortical_pattern_out),
    .f0_x(f0_x),
    .f0_y(f0_y),
    .f0_amplitude(f0_amplitude),
    .sr_f_x_packed(sr_f_x_packed),
    .sr_coherence_packed(sr_coherence_packed),
    .sie_per_harmonic(sie_per_harmonic),
    .coherence_mask(coherence_mask),
    .sr_coherence(sr_coherence),
    .sr_amplification(sr_amplification),
    .beta_quiet(beta_quiet),
    .theta_phase(theta_phase)
);

// Clock generation
always #(CLK_PERIOD/2) clk = ~clk;

//=============================================================================
// Signal extraction for CSV export
//=============================================================================

// Thalamic theta (from internal thalamus module)
wire signed [WIDTH-1:0] theta_x = dut.thal.theta_x_int;
wire signed [WIDTH-1:0] theta_y = dut.thal.theta_y_int;

// SR harmonics unpacked from sr_f_x_packed
wire signed [WIDTH-1:0] sr_f0_x = sr_f_x_packed[0*WIDTH +: WIDTH];
wire signed [WIDTH-1:0] sr_f1_x = sr_f_x_packed[1*WIDTH +: WIDTH];
wire signed [WIDTH-1:0] sr_f2_x = sr_f_x_packed[2*WIDTH +: WIDTH];
wire signed [WIDTH-1:0] sr_f3_x = sr_f_x_packed[3*WIDTH +: WIDTH];
wire signed [WIDTH-1:0] sr_f4_x = sr_f_x_packed[4*WIDTH +: WIDTH];

// Cortical column outputs - Sensory
wire signed [WIDTH-1:0] sensory_l6_x  = dut.col_sensory.l6_x;
wire signed [WIDTH-1:0] sensory_l5a_x = dut.col_sensory.l5a_x;
wire signed [WIDTH-1:0] sensory_l5b_x = dut.col_sensory.l5b_x;
wire signed [WIDTH-1:0] sensory_l4_x  = dut.col_sensory.l4_x;
wire signed [WIDTH-1:0] sensory_l23_x = dut.col_sensory.l23_x;

// Cortical column outputs - Association
wire signed [WIDTH-1:0] assoc_l6_x  = dut.col_assoc.l6_x;
wire signed [WIDTH-1:0] assoc_l5a_x = dut.col_assoc.l5a_x;
wire signed [WIDTH-1:0] assoc_l5b_x = dut.col_assoc.l5b_x;
wire signed [WIDTH-1:0] assoc_l4_x  = dut.col_assoc.l4_x;
wire signed [WIDTH-1:0] assoc_l23_x = dut.col_assoc.l23_x;

// Cortical column outputs - Motor
wire signed [WIDTH-1:0] motor_l6_x  = dut.col_motor.l6_x;
wire signed [WIDTH-1:0] motor_l5a_x = dut.col_motor.l5a_x;
wire signed [WIDTH-1:0] motor_l5b_x = dut.col_motor.l5b_x;
wire signed [WIDTH-1:0] motor_l4_x  = dut.col_motor.l4_x;
wire signed [WIDTH-1:0] motor_l23_x = dut.col_motor.l23_x;

//=============================================================================
// CSV export logic
//=============================================================================
integer csv_file;
integer sample_count;
integer update_count;

// Track clk_4khz_en rising edge
reg prev_clk_en;
wire clk_en_rising;
assign clk_en_rising = dut.clk_4khz_en && !prev_clk_en;

initial begin
    // Initialize
    clk = 0;
    rst = 1;
    sensory_input = 18'sd4096;  // Moderate stimulus to excite oscillators (required for startup)
    sr_field_input = 18'sd0;    // No external SR field
    state_select = 3'd0;  // NORMAL state
    sample_count = 0;
    update_count = 0;
    prev_clk_en = 0;

    // Open CSV file
    csv_file = $fopen("oscillator_eeg_export.csv", "w");

    // Write header (27 columns)
    $fwrite(csv_file, "time_ms,state,theta_phase,");
    $fwrite(csv_file, "theta_x,theta_y,");
    $fwrite(csv_file, "sr_f0_x,sr_f1_x,sr_f2_x,sr_f3_x,sr_f4_x,");
    $fwrite(csv_file, "sensory_l6_x,sensory_l5a_x,sensory_l5b_x,sensory_l4_x,sensory_l23_x,");
    $fwrite(csv_file, "assoc_l6_x,assoc_l5a_x,assoc_l5b_x,assoc_l4_x,assoc_l23_x,");
    $fwrite(csv_file, "motor_l6_x,motor_l5a_x,motor_l5b_x,motor_l4_x,motor_l23_x,");
    $fwrite(csv_file, "beta_quiet,sr_amplification\n");

    $display("=============================================================================");
    $display("EEG Export Testbench - Exporting all 21 oscillators");
    $display("Duration: %0d seconds (%0d samples at 1 kHz)", DURATION_MS/1000, TOTAL_SAMPLES);
    $display("=============================================================================");

    // Release reset
    repeat(100) @(posedge clk);
    rst = 0;

    // Let oscillators stabilize (500 ms equivalent)
    $display("Stabilizing oscillators...");
    repeat(50000) @(posedge clk);

    $display("Recording data...");

    // Main export loop
    while (sample_count < TOTAL_SAMPLES) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;

        if (clk_en_rising) begin
            update_count = update_count + 1;

            // Sample every SAMPLE_DIVISOR updates (default 4 = 1 kHz)
            if ((update_count % SAMPLE_DIVISOR) == 0) begin
                // Write data row
                $fwrite(csv_file, "%0d,%0d,%0d,",
                    sample_count,
                    state_select,
                    theta_phase);

                // Theta
                $fwrite(csv_file, "%0d,%0d,",
                    $signed(theta_x),
                    $signed(theta_y));

                // SR harmonics (5)
                $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,",
                    $signed(sr_f0_x),
                    $signed(sr_f1_x),
                    $signed(sr_f2_x),
                    $signed(sr_f3_x),
                    $signed(sr_f4_x));

                // Sensory column (5 layers)
                $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,",
                    $signed(sensory_l6_x),
                    $signed(sensory_l5a_x),
                    $signed(sensory_l5b_x),
                    $signed(sensory_l4_x),
                    $signed(sensory_l23_x));

                // Association column (5 layers)
                $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,",
                    $signed(assoc_l6_x),
                    $signed(assoc_l5a_x),
                    $signed(assoc_l5b_x),
                    $signed(assoc_l4_x),
                    $signed(assoc_l23_x));

                // Motor column (5 layers)
                $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,",
                    $signed(motor_l6_x),
                    $signed(motor_l5a_x),
                    $signed(motor_l5b_x),
                    $signed(motor_l4_x),
                    $signed(motor_l23_x));

                // Status flags
                $fwrite(csv_file, "%0d,%0d\n",
                    beta_quiet,
                    sr_amplification);

                sample_count = sample_count + 1;

                // Progress every 10 seconds
                if (sample_count % 10000 == 0) begin
                    $display("  %0d seconds exported (%0d/%0d samples)...",
                        sample_count/1000, sample_count, TOTAL_SAMPLES);
                end
            end
        end
    end

    $fclose(csv_file);
    $display("=============================================================================");
    $display("Export complete: oscillator_eeg_export.csv");
    $display("Total samples: %0d (%.1f seconds at 1 kHz)", sample_count, sample_count/1000.0);
    $display("");
    $display("Analyze with: python3 scripts/analyze_eeg_comparison.py");
    $display("=============================================================================");
    $finish;
end

endmodule
