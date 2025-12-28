//=============================================================================
// Testbench: State Transition Spectrogram
//
// Generates 100 seconds of DAC output with smooth NORMAL ↔ MEDITATION transitions
// using MU interpolation for gradual state changes.
//
// Timeline (100 seconds total, 5 phases of 20 seconds each):
// - Phase 0 (0-20s):   NORMAL baseline
// - Phase 1 (20-40s):  Smooth transition NORMAL → MEDITATION
// - Phase 2 (40-60s):  MEDITATION steady-state
// - Phase 3 (60-80s):  Smooth transition MEDITATION → NORMAL
// - Phase 4 (80-100s): NORMAL steady-state
//
// MU interpolation (NORMAL → MEDITATION):
// v11.1: NORMAL now uses MU=3 (was 4) to prevent DAC clipping
// - mu_theta: 3 → 3 (unchanged, note: theta also at 3 via config_controller)
// - mu_l6:    3 → 3 (unchanged, note: L6 also at 3 via config_controller)
// - mu_l5b:   3 → 2 (reduced)
// - mu_l5a:   3 → 2 (reduced)
// - mu_l4:    3 → 2 (reduced)
// - mu_l23:   3 → 2 (reduced)
//
// Output files:
//   state_transition_eeg.csv - Full oscillator data (27 columns)
//   state_transition_dac.csv - DAC output only (time_ms, phase, mu_l5b, dac_output)
//   Both have 100,000 samples at 1 kHz
//
// Usage:
//   iverilog -o tb_state_transition_spectrogram.vvp -s tb_state_transition_spectrogram \
//       src/*.v tb/tb_state_transition_spectrogram.v && \
//   vvp tb_state_transition_spectrogram.vvp
//
//   python3 scripts/state_transition_spectrogram.py
//=============================================================================
`timescale 1ns / 1ps

module tb_state_transition_spectrogram;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 8;  // 125 MHz
parameter DURATION_MS = 100000;  // 100 seconds
parameter SAMPLE_DIVISOR = 4;    // Sample every 4th update = 1 kHz output
parameter PHASE_MS = 20000;      // 20 seconds per phase

// Total samples to export
localparam TOTAL_SAMPLES = DURATION_MS;  // 1 sample per ms at 1 kHz

// Phase definitions
localparam PHASE_NORMAL1    = 3'd0;  // 0-20s
localparam PHASE_TRANS_N_M  = 3'd1;  // 20-40s (Normal → Meditation)
localparam PHASE_MEDITATION = 3'd2;  // 40-60s
localparam PHASE_TRANS_M_N  = 3'd3;  // 60-80s (Meditation → Normal)
localparam PHASE_NORMAL2    = 3'd4;  // 80-100s

// MU values in integer form (these are raw values, not Q4.14)
// In config_controller, MU values are small integers (2-6 range)
// v11.1: NORMAL reduced from 4 to 3 to prevent DAC clipping
localparam signed [WIDTH-1:0] MU_FULL = 18'sd3;  // NORMAL state MU (was 4, now 3)
localparam signed [WIDTH-1:0] MU_HALF = 18'sd2;  // MEDITATION state MU

// Phase updates: 20 seconds at 4 kHz = 80,000 updates per phase
localparam PHASE_UPDATES = 80000;

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
// Signal extraction for CSV export (same as tb_eeg_export.v)
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
// Phase tracking and MU interpolation
//=============================================================================
reg [2:0] current_phase;
reg [31:0] phase_update_counter;  // Wide enough for 80,000
reg [31:0] global_update_count;

// Interpolated MU values (computed in always block)
reg signed [WIDTH-1:0] mu_l5b_interp;
reg signed [WIDTH-1:0] mu_l5a_interp;
reg signed [WIDTH-1:0] mu_l4_interp;
reg signed [WIDTH-1:0] mu_l23_interp;

// Linear interpolation function
// Returns: start + (end - start) * counter / total
// For N→M transition: start=4, end=2, so diff=-2
// As counter goes 0→80000, output goes 4→2
function signed [WIDTH-1:0] interpolate;
    input signed [WIDTH-1:0] start_val;
    input signed [WIDTH-1:0] end_val;
    input [31:0] counter;
    input [31:0] total;
    reg signed [35:0] diff;
    reg signed [35:0] scaled;
    reg signed [35:0] counter_signed;
    reg signed [35:0] total_signed;
    begin
        diff = end_val - start_val;  // -2 for N→M, +2 for M→N
        // CRITICAL: Cast unsigned counter/total to signed for correct arithmetic
        counter_signed = {4'b0, counter};  // Zero-extend to 36-bit positive
        total_signed = {4'b0, total};
        scaled = (diff * counter_signed) / total_signed;
        // Result is in range [diff, 0] or [0, diff], so fits in WIDTH bits
        interpolate = start_val + scaled[WIDTH-1:0];
    end
endfunction

// Track clk_4khz_en rising edge
reg prev_clk_en;
wire clk_en_rising;
assign clk_en_rising = dut.clk_4khz_en && !prev_clk_en;

// Phase and MU update logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        current_phase <= PHASE_NORMAL1;
        phase_update_counter <= 0;
        global_update_count <= 0;
        mu_l5b_interp <= MU_FULL;
        mu_l5a_interp <= MU_FULL;
        mu_l4_interp <= MU_FULL;
        mu_l23_interp <= MU_FULL;
    end else if (clk_en_rising) begin
        global_update_count <= global_update_count + 1;
        phase_update_counter <= phase_update_counter + 1;

        // Phase transitions every PHASE_UPDATES (80,000 updates = 20 seconds)
        if (phase_update_counter >= PHASE_UPDATES - 1) begin
            phase_update_counter <= 0;
            if (current_phase < PHASE_NORMAL2)
                current_phase <= current_phase + 1;
        end

        // Update MU values based on phase
        case (current_phase)
            PHASE_NORMAL1, PHASE_NORMAL2: begin
                // Full MU for all cortical layers
                mu_l5b_interp <= MU_FULL;
                mu_l5a_interp <= MU_FULL;
                mu_l4_interp  <= MU_FULL;
                mu_l23_interp <= MU_FULL;
            end
            PHASE_TRANS_N_M: begin
                // Interpolate from FULL (4) to HALF (2)
                mu_l5b_interp <= interpolate(MU_FULL, MU_HALF, phase_update_counter, PHASE_UPDATES);
                mu_l5a_interp <= interpolate(MU_FULL, MU_HALF, phase_update_counter, PHASE_UPDATES);
                mu_l4_interp  <= interpolate(MU_FULL, MU_HALF, phase_update_counter, PHASE_UPDATES);
                mu_l23_interp <= interpolate(MU_FULL, MU_HALF, phase_update_counter, PHASE_UPDATES);
            end
            PHASE_MEDITATION: begin
                // Half MU for cortical layers (theta/L6 stay at 4)
                mu_l5b_interp <= MU_HALF;
                mu_l5a_interp <= MU_HALF;
                mu_l4_interp  <= MU_HALF;
                mu_l23_interp <= MU_HALF;
            end
            PHASE_TRANS_M_N: begin
                // Interpolate from HALF (2) to FULL (4)
                mu_l5b_interp <= interpolate(MU_HALF, MU_FULL, phase_update_counter, PHASE_UPDATES);
                mu_l5a_interp <= interpolate(MU_HALF, MU_FULL, phase_update_counter, PHASE_UPDATES);
                mu_l4_interp  <= interpolate(MU_HALF, MU_FULL, phase_update_counter, PHASE_UPDATES);
                mu_l23_interp <= interpolate(MU_HALF, MU_FULL, phase_update_counter, PHASE_UPDATES);
            end
        endcase
    end
end

// Apply MU overrides using force (after reset)
// Note: force must be in initial/always block, applied continuously
always @(posedge clk) begin
    if (!rst) begin
        // Override config_controller's MU outputs with interpolated values
        force dut.config_ctrl.mu_dt_l5b = mu_l5b_interp;
        force dut.config_ctrl.mu_dt_l5a = mu_l5a_interp;
        force dut.config_ctrl.mu_dt_l4 = mu_l4_interp;
        force dut.config_ctrl.mu_dt_l23 = mu_l23_interp;
    end
end

//=============================================================================
// CSV export logic
//=============================================================================
integer csv_file;
integer dac_file;  // Second file for state_transition_dac.csv
integer sample_count;
integer update_count;

initial begin
    // Initialize
    clk = 0;
    rst = 1;
    sensory_input = 18'sd4096;  // Moderate stimulus to excite oscillators
    sr_field_input = 18'sd2048; // External SR field to enable ignition events
    state_select = 3'd0;        // NORMAL state (base, but we override MU values)
    sample_count = 0;
    update_count = 0;
    prev_clk_en = 0;

    // Open CSV file (same format as oscillator_eeg_export.csv for dac_spectrogram.py)
    csv_file = $fopen("state_transition_eeg.csv", "w");

    // Open second CSV file for state_transition_spectrogram.py
    dac_file = $fopen("state_transition_dac.csv", "w");

    // Write header (27 columns - same as tb_eeg_export.v)
    $fwrite(csv_file, "time_ms,state,theta_phase,");
    $fwrite(csv_file, "theta_x,theta_y,");
    $fwrite(csv_file, "sr_f0_x,sr_f1_x,sr_f2_x,sr_f3_x,sr_f4_x,");
    $fwrite(csv_file, "sensory_l6_x,sensory_l5a_x,sensory_l5b_x,sensory_l4_x,sensory_l23_x,");
    $fwrite(csv_file, "assoc_l6_x,assoc_l5a_x,assoc_l5b_x,assoc_l4_x,assoc_l23_x,");
    $fwrite(csv_file, "motor_l6_x,motor_l5a_x,motor_l5b_x,motor_l4_x,motor_l23_x,");
    $fwrite(csv_file, "beta_quiet,sr_amplification\n");

    // Write header for DAC file (4 columns for state_transition_spectrogram.py)
    $fwrite(dac_file, "time_ms,phase,mu_l5b,dac_output\n");

    $display("=============================================================================");
    $display("State Transition Spectrogram Testbench");
    $display("Duration: 100 seconds (5 phases x 20 seconds)");
    $display("Phase 0: NORMAL (0-20s)");
    $display("Phase 1: NORMAL → MEDITATION transition (20-40s)");
    $display("Phase 2: MEDITATION (40-60s)");
    $display("Phase 3: MEDITATION → NORMAL transition (60-80s)");
    $display("Phase 4: NORMAL (80-100s)");
    $display("=============================================================================");

    // Release reset
    repeat(100) @(posedge clk);
    rst = 0;

    // Let oscillators stabilize (500 ms equivalent at FAST_SIM)
    $display("Stabilizing oscillators...");
    repeat(50000) @(posedge clk);

    $display("Recording data (100 seconds at 1 kHz = 100,000 samples)...");

    // Main export loop
    while (sample_count < TOTAL_SAMPLES) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;

        if (clk_en_rising) begin
            update_count = update_count + 1;

            // Sample every SAMPLE_DIVISOR updates (4 = 1 kHz output)
            if ((update_count % SAMPLE_DIVISOR) == 0) begin
                // Write data row (27 columns - same format as tb_eeg_export.v)
                $fwrite(csv_file, "%0d,%0d,%0d,",
                    sample_count,
                    current_phase,  // Use phase as "state" for analysis
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

                // Write to DAC file (4 columns for state_transition_spectrogram.py)
                $fwrite(dac_file, "%0d,%0d,%0d,%0d\n",
                    sample_count,
                    current_phase,
                    $signed(mu_l5b_interp),
                    dac_output);

                sample_count = sample_count + 1;

                // Progress every 10 seconds (10,000 samples)
                if (sample_count % 10000 == 0) begin
                    $display("  %0d seconds exported (phase %0d, mu_l5b=%0d)...",
                        sample_count/1000, current_phase, $signed(mu_l5b_interp));
                end
            end
        end
    end

    $fclose(csv_file);
    $fclose(dac_file);
    $display("=============================================================================");
    $display("Export complete:");
    $display("  state_transition_eeg.csv (27 columns, all oscillators)");
    $display("  state_transition_dac.csv (4 columns, DAC output only)");
    $display("Total samples: %0d (100 seconds at 1 kHz)", sample_count);
    $display("");
    $display("Generate spectrograms:");
    $display("  python3 scripts/state_transition_spectrogram.py");
    $display("  python3 scripts/dac_spectrogram.py state_transition_eeg.csv");
    $display("=============================================================================");
    $finish;
end

endmodule
