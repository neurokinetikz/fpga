//=============================================================================
// Testbench: State Transition Spectrogram
//
// Generates 100 seconds of DAC output with NORMAL ↔ MEDITATION state transitions
// using config_controller's proper state-dependent MU values.
//
// Timeline (100 seconds total, 5 phases of 20 seconds each):
// - Phase 0 (0-20s):   NORMAL baseline
// - Phase 1 (20-40s):  20-second linear ramp NORMAL → MEDITATION
// - Phase 2 (40-60s):  MEDITATION steady-state
// - Phase 3 (60-80s):  20-second linear ramp MEDITATION → NORMAL
// - Phase 4 (80-100s): NORMAL steady-state
//
// v11.4b: Uses transition_duration for 20-second linear interpolation
// - config_controller lerp functions handle gradual MU ramping
// - Spectrogram should show gradual power changes during transitions
// v11.4: Uses state_select to trigger proper config_controller states
// NORMAL (state_select=0):     All MU=3 (MU_MODERATE)
// MEDITATION (state_select=4): theta/L6=6, L5a/L5b/L4=1, L23=2
//   - Theta/Alpha BOOSTED (6 vs 3 = +100%)
//   - Beta/Gamma SUPPRESSED (1 vs 3 = -67%)
//   - This creates visible >3dB spectral differentiation
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

// State codes matching config_controller.v
localparam [2:0] STATE_NORMAL     = 3'd0;
localparam [2:0] STATE_MEDITATION = 3'd4;

// Phase updates: 20 seconds at 4 kHz = 80,000 updates per phase
localparam PHASE_UPDATES = 80000;

// v11.4b: 20-second linear interpolation for state transitions
// At 4 kHz update rate: 20 seconds = 80,000 cycles
localparam [15:0] TRANSITION_DURATION = 16'd80000;

reg clk;
reg rst;
reg signed [WIDTH-1:0] sensory_input;
reg signed [WIDTH-1:0] sr_field_input;
reg [2:0] state_select;
reg [15:0] transition_duration;

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
    .transition_duration(transition_duration),  // v11.4b: 20-second ramp
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

// Thalamic theta (from thalamus module outputs - scaled by MU)
wire signed [WIDTH-1:0] theta_x = dut.thal.theta_x;
wire signed [WIDTH-1:0] theta_y = dut.thal.theta_y;

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
// Phase tracking and state_select control
// v11.4: Uses state_select instead of forcing individual MU values
//=============================================================================
reg [2:0] current_phase;
reg [31:0] phase_update_counter;  // Wide enough for 80,000
reg [31:0] global_update_count;

// Track clk_4khz_en rising edge
reg prev_clk_en;
wire clk_en_rising;
assign clk_en_rising = dut.clk_4khz_en && !prev_clk_en;

// Phase and state_select update logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        current_phase <= PHASE_NORMAL1;
        phase_update_counter <= 0;
        global_update_count <= 0;
        state_select <= STATE_NORMAL;
    end else if (clk_en_rising) begin
        global_update_count <= global_update_count + 1;
        phase_update_counter <= phase_update_counter + 1;

        // Phase transitions every PHASE_UPDATES (80,000 updates = 20 seconds)
        if (phase_update_counter >= PHASE_UPDATES - 1) begin
            phase_update_counter <= 0;
            if (current_phase < PHASE_NORMAL2)
                current_phase <= current_phase + 1;
        end

        // Update state_select based on phase
        // v11.4b: Trigger state_select at START of transition window
        // config_controller's lerp handles the 20-second linear ramp via transition_duration
        case (current_phase)
            PHASE_NORMAL1, PHASE_NORMAL2: begin
                state_select <= STATE_NORMAL;
            end
            PHASE_TRANS_N_M: begin
                // Trigger MEDITATION at start of window - lerp handles 20s ramp
                state_select <= STATE_MEDITATION;
            end
            PHASE_MEDITATION: begin
                state_select <= STATE_MEDITATION;
            end
            PHASE_TRANS_M_N: begin
                // Trigger NORMAL at start of window - lerp handles 20s ramp
                state_select <= STATE_NORMAL;
            end
        endcase
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
    transition_duration = TRANSITION_DURATION;  // v11.4b: 20-second linear ramp
    state_select = STATE_NORMAL; // v11.4: State controlled by phase logic
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

    // Write header for DAC file (5 columns for state_transition_spectrogram.py)
    // v11.4: Added gain_envelope to track SR ignition events
    $fwrite(dac_file, "time_ms,phase,state_select,dac_output,gain_envelope\n");

    $display("=============================================================================");
    $display("State Transition Spectrogram Testbench v11.4b");
    $display("Using 20-second linear interpolation via config_controller lerp");
    $display("Duration: 100 seconds (5 phases x 20 seconds)");
    $display("");
    $display("Phase 0 (0-20s):   NORMAL baseline (state=0, all MU=3)");
    $display("Phase 1 (20-40s):  20s linear ramp NORMAL → MEDITATION");
    $display("Phase 2 (40-60s):  MEDITATION steady-state (theta/alpha=6, beta/gamma=1)");
    $display("Phase 3 (60-80s):  20s linear ramp MEDITATION → NORMAL");
    $display("Phase 4 (80-100s): NORMAL baseline (state=0, all MU=3)");
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

                // Write to DAC file (5 columns for state_transition_spectrogram.py)
                // v11.4: Added gain_envelope to track SR ignition events
                $fwrite(dac_file, "%0d,%0d,%0d,%0d,%0d\n",
                    sample_count,
                    current_phase,
                    state_select,
                    dac_output,
                    $signed(dut.sie_gain_envelope));

                sample_count = sample_count + 1;

                // Progress every 10 seconds (10,000 samples)
                if (sample_count % 10000 == 0) begin
                    $display("  %0d seconds exported (phase %0d, state=%0d, mu_theta=%0d, mu_l6=%0d, mu_l5a=%0d)...",
                        sample_count/1000, current_phase, state_select,
                        $signed(dut.config_ctrl.mu_dt_theta),
                        $signed(dut.config_ctrl.mu_dt_l6),
                        $signed(dut.config_ctrl.mu_dt_l5a));
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
