//=============================================================================
// Testbench: Continuous Gain CSV Export for EEG-style Visualization (v7.4)
//
// Exports per-harmonic coherence, gains, beta modulation, and total gain
// for Python visualization in stacked EEG-style format.
//=============================================================================
`timescale 1ns / 1ps

module tb_continuous_gain_csv;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter NUM_HARMONICS = 5;
parameter CLK_PERIOD = 8;  // 125 MHz

reg clk;
reg rst;
reg signed [WIDTH-1:0] sensory_input;
reg signed [WIDTH-1:0] sr_field_input;
reg signed [NUM_HARMONICS*WIDTH-1:0] sr_field_packed;
reg [2:0] state_select;

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
wire signed [NUM_HARMONICS*WIDTH-1:0] sr_f_x_packed;
wire signed [NUM_HARMONICS*WIDTH-1:0] sr_coherence_packed;
wire [NUM_HARMONICS-1:0] sie_per_harmonic;
wire [NUM_HARMONICS-1:0] coherence_mask;

// Instantiate DUT with FAST_SIM
phi_n_neural_processor #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .FAST_SIM(1),
    .NUM_HARMONICS(NUM_HARMONICS)
) dut (
    .clk(clk),
    .rst(rst),
    .sensory_input(sensory_input),
    .state_select(state_select),
    .sr_field_input(sr_field_input),
    .sr_field_packed(sr_field_packed),
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
    .beta_quiet(beta_quiet)
);

// Clock generation
always #(CLK_PERIOD/2) clk = ~clk;

// Access internal signals for visualization
wire signed [WIDTH-1:0] theta_x = dut.thal.theta_x_int;
wire signed [WIDTH-1:0] beta_amplitude = dut.beta_amplitude_avg;

// Per-harmonic coherence (unpacked from sr_coherence_packed)
wire signed [WIDTH-1:0] coh_h0 = sr_coherence_packed[0*WIDTH +: WIDTH];
wire signed [WIDTH-1:0] coh_h1 = sr_coherence_packed[1*WIDTH +: WIDTH];
wire signed [WIDTH-1:0] coh_h2 = sr_coherence_packed[2*WIDTH +: WIDTH];
wire signed [WIDTH-1:0] coh_h3 = sr_coherence_packed[3*WIDTH +: WIDTH];
wire signed [WIDTH-1:0] coh_h4 = sr_coherence_packed[4*WIDTH +: WIDTH];

// Per-harmonic gains from thalamus
wire signed [WIDTH-1:0] gain_h0 = dut.thal.gain_h0;
wire signed [WIDTH-1:0] gain_h1 = dut.thal.gain_h1;
wire signed [WIDTH-1:0] gain_h2 = dut.thal.gain_h2;
wire signed [WIDTH-1:0] gain_h3 = dut.thal.gain_h3;
wire signed [WIDTH-1:0] gain_h4 = dut.thal.gain_h4;

// Total gain and beta factor from sr_harmonic_bank
wire signed [WIDTH-1:0] beta_factor = dut.thal.sr_bank.beta_factor;
wire signed [WIDTH-1:0] dynamic_gain = dut.thal.dynamic_gain;

// CSV file handle
integer csv_file;
integer sample_count;
integer clk_count;

// Track clk_en
reg prev_clk_en;
wire clk_en_rising;
assign clk_en_rising = dut.clk_4khz_en && !prev_clk_en;

// Simulation phases
integer phase;
localparam PHASE_WARMUP = 0;
localparam PHASE_NORMAL = 1;
localparam PHASE_MEDITATION = 2;
localparam PHASE_SR_DRIVE = 3;

initial begin
    // Initialize
    clk = 0;
    rst = 1;
    sensory_input = 18'sd4096;
    sr_field_input = 18'sd0;
    sr_field_packed = 90'd0;
    state_select = 3'd0;  // NORMAL
    sample_count = 0;
    clk_count = 0;
    prev_clk_en = 0;
    phase = PHASE_WARMUP;

    // Open CSV file
    csv_file = $fopen("continuous_gain_data.csv", "w");
    $fwrite(csv_file, "time_ms,phase,theta_x,beta_amp,beta_factor,");
    $fwrite(csv_file, "coh_h0,coh_h1,coh_h2,coh_h3,coh_h4,");
    $fwrite(csv_file, "gain_h0,gain_h1,gain_h2,gain_h3,gain_h4,");
    $fwrite(csv_file, "dynamic_gain,sie_mask,beta_quiet\n");

    $display("=============================================================================");
    $display("Continuous Gain CSV Export - EEG-style Visualization Data");
    $display("=============================================================================");

    // Release reset
    repeat(100) @(posedge clk);
    rst = 0;

    // Warmup phase (let oscillators stabilize)
    $display("Phase 0: Warmup (1000 samples)...");
    while (sample_count < 1000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;

        if (clk_en_rising) begin
            if ((clk_count % 10) == 0) begin  // Sample every 10 clocks
                write_sample();
            end
        end
    end

    // NORMAL state with no SR drive
    $display("Phase 1: NORMAL state (2000 samples)...");
    phase = PHASE_NORMAL;
    state_select = 3'd0;
    while (sample_count < 3000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;

        if (clk_en_rising) begin
            if ((clk_count % 10) == 0) begin
                write_sample();
            end
        end
    end

    // MEDITATION state (beta quiets)
    $display("Phase 2: MEDITATION state (2000 samples)...");
    phase = PHASE_MEDITATION;
    state_select = 3'd1;  // MEDITATION
    sensory_input = 18'sd1024;  // Reduce sensory to help beta quiet
    while (sample_count < 5000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;

        if (clk_en_rising) begin
            if ((clk_count % 10) == 0) begin
                write_sample();
            end
        end
    end

    // SR DRIVE phase (apply STRONG external Schumann field)
    $display("Phase 3: STRONG SR DRIVE (3000 samples)...");
    phase = PHASE_SR_DRIVE;
    // Drive all 5 harmonics with STRONG amplitudes (0.75 = 12288)
    // This should force high coherence with internal oscillators
    sr_field_packed = {18'sd12288, 18'sd12288, 18'sd12288, 18'sd12288, 18'sd12288};
    // Reduce sensory input to let cortical activity (and beta) quiet down
    sensory_input = 18'sd512;
    while (sample_count < 8000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;

        if (clk_en_rising) begin
            if ((clk_count % 10) == 0) begin
                write_sample();
            end
        end
    end

    $fclose(csv_file);
    $display("Data exported to continuous_gain_data.csv");
    $display("Run: python3 visualize_continuous_gain.py");
    $finish;
end

task write_sample;
begin
    $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,",
        sample_count,
        phase,
        $signed(theta_x),
        $signed(beta_amplitude),
        $signed(beta_factor)
    );
    $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,",
        $signed(coh_h0),
        $signed(coh_h1),
        $signed(coh_h2),
        $signed(coh_h3),
        $signed(coh_h4)
    );
    $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,",
        $signed(gain_h0),
        $signed(gain_h1),
        $signed(gain_h2),
        $signed(gain_h3),
        $signed(gain_h4)
    );
    $fwrite(csv_file, "%0d,%0d,%0d\n",
        $signed(dynamic_gain),
        sie_per_harmonic,
        beta_quiet
    );
    sample_count = sample_count + 1;

    if (sample_count % 1000 == 0) begin
        $display("  Recorded %0d samples...", sample_count);
    end
end
endtask

endmodule
