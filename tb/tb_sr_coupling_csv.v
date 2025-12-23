//=============================================================================
// Testbench: SR Coupling with CSV Export for Visualization (v7.2)
//
// Exports theta, f₀, coherence, amplification, and beta_quiet data for Python.
// v7.2: Added sr_field_input and beta_quiet for stochastic resonance model.
//=============================================================================
`timescale 1ns / 1ps

module tb_sr_coupling_csv;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 8;  // 125 MHz

reg clk;
reg rst;
reg signed [WIDTH-1:0] sensory_input;
reg signed [WIDTH-1:0] sr_field_input;  // v7.2: External Schumann field
reg [2:0] state_select;

wire [11:0] dac_output;
wire signed [WIDTH-1:0] debug_motor_l23;
wire signed [WIDTH-1:0] debug_theta;
wire ca3_learning, ca3_recalling;
wire [5:0] ca3_phase_pattern;
wire [5:0] cortical_pattern_out;

// v7.2 SR outputs
wire signed [WIDTH-1:0] f0_x, f0_y, f0_amplitude;
wire signed [WIDTH-1:0] sr_coherence;
wire sr_amplification;
wire beta_quiet;

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
    .sr_field_input(sr_field_input),  // v7.2
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
    .sr_coherence(sr_coherence),
    .sr_amplification(sr_amplification),
    .beta_quiet(beta_quiet)  // v7.2
);

// Clock generation
always #(CLK_PERIOD/2) clk = ~clk;

// CSV file handle
integer csv_file;
integer sample_count;
integer clk_count;

// Track when clk_en fires (every 10 clocks in FAST_SIM)
reg prev_clk_en;
wire clk_en_rising;
assign clk_en_rising = dut.clk_4khz_en && !prev_clk_en;

initial begin
    // Initialize
    clk = 0;
    rst = 1;
    sensory_input = 18'sd8192;  // Constant input for clean visualization
    sr_field_input = 18'sd4096; // v7.2: External field (0.25 amplitude)
    state_select = 3'd0;  // NORMAL state
    sample_count = 0;
    clk_count = 0;
    prev_clk_en = 0;

    // Open CSV file
    csv_file = $fopen("sr_coupling_data.csv", "w");
    $fwrite(csv_file, "time_ms,theta_x,theta_y,f0_x,f0_y,coherence,amplification,beta_quiet,theta_gated_out\n");

    $display("=============================================================================");
    $display("SR Coupling CSV Export - Generating visualization data");
    $display("=============================================================================");

    // Release reset
    repeat(100) @(posedge clk);
    rst = 0;

    // Let oscillators stabilize
    repeat(1000) @(posedge clk);

    $display("Recording 5 seconds of simulated time (5000 samples at 1 kHz)...");

    // Record data for 5 seconds simulated time
    // At 4 kHz update rate, 5 seconds = 20000 updates
    // We'll sample every 4th update to get 1 kHz data rate = 5000 samples
    while (sample_count < 5000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;

        if (clk_en_rising) begin
            // Sample every 4th update (1 kHz effective rate)
            if ((clk_count % 40) == 0) begin  // 40 clocks = 4 updates in FAST_SIM
                // Time in ms (1 sample per ms at 1 kHz)
                $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                    sample_count,
                    $signed(debug_theta),
                    $signed(dut.thal.theta_y_int),
                    $signed(f0_x),
                    $signed(f0_y),
                    $signed(sr_coherence),
                    sr_amplification,
                    beta_quiet,  // v7.2
                    $signed(dut.thal.theta_gated_output)
                );
                sample_count = sample_count + 1;

                if (sample_count % 1000 == 0) begin
                    $display("  Recorded %0d samples...", sample_count);
                end
            end
        end
    end

    $fclose(csv_file);
    $display("Data exported to sr_coupling_data.csv");
    $display("Run: python3 visualize_sr_coupling.py");
    $finish;
end

endmodule
