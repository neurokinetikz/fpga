//=============================================================================
// Testbench: SIE Emergence During State Transition
//
// Captures the dynamics of Schumann Ignition Events as the model
// transitions from NORMAL → MEDITATION state.
//
// Exports CSV data for analysis:
// - Beta amplitude and quiet status
// - Theta-f₀ coherence
// - SIE (amplification) events
// - State transition timing
//=============================================================================
`timescale 1ns / 1ps

module tb_sie_transition;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 8;  // 125 MHz

reg clk;
reg rst;
reg signed [WIDTH-1:0] sensory_input;
reg signed [WIDTH-1:0] sr_field_input;
reg [2:0] state_select;

wire [11:0] dac_output;
wire signed [WIDTH-1:0] debug_motor_l23;
wire signed [WIDTH-1:0] debug_theta;
wire ca3_learning, ca3_recalling;
wire [5:0] ca3_phase_pattern;
wire [5:0] cortical_pattern_out;

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
    .sr_coherence(sr_coherence),
    .sr_amplification(sr_amplification),
    .beta_quiet(beta_quiet)
);

// Clock generation
always #(CLK_PERIOD/2) clk = ~clk;

// External f₀ signal generator (7.49 Hz)
integer f0_phase_counter;
localparam F0_PERIOD_CLKS = 53400;  // ~7.49 Hz at FAST_SIM rates
reg signed [WIDTH-1:0] f0_sin_lut [0:63];

// Initialize sine LUT (Q14 format, 64 entries for smoother wave)
integer lut_i;
initial begin
    for (lut_i = 0; lut_i < 64; lut_i = lut_i + 1) begin
        // sin(2π × i/64) × 4096 (0.25 amplitude - weak external field)
        case (lut_i)
            0:  f0_sin_lut[lut_i] = 18'sd0;
            1:  f0_sin_lut[lut_i] = 18'sd402;
            2:  f0_sin_lut[lut_i] = 18'sd799;
            3:  f0_sin_lut[lut_i] = 18'sd1189;
            4:  f0_sin_lut[lut_i] = 18'sd1567;
            5:  f0_sin_lut[lut_i] = 18'sd1931;
            6:  f0_sin_lut[lut_i] = 18'sd2276;
            7:  f0_sin_lut[lut_i] = 18'sd2602;
            8:  f0_sin_lut[lut_i] = 18'sd2896;
            9:  f0_sin_lut[lut_i] = 18'sd3166;
            10: f0_sin_lut[lut_i] = 18'sd3406;
            11: f0_sin_lut[lut_i] = 18'sd3612;
            12: f0_sin_lut[lut_i] = 18'sd3784;
            13: f0_sin_lut[lut_i] = 18'sd3920;
            14: f0_sin_lut[lut_i] = 18'sd4017;
            15: f0_sin_lut[lut_i] = 18'sd4076;
            16: f0_sin_lut[lut_i] = 18'sd4096;
            17: f0_sin_lut[lut_i] = 18'sd4076;
            18: f0_sin_lut[lut_i] = 18'sd4017;
            19: f0_sin_lut[lut_i] = 18'sd3920;
            20: f0_sin_lut[lut_i] = 18'sd3784;
            21: f0_sin_lut[lut_i] = 18'sd3612;
            22: f0_sin_lut[lut_i] = 18'sd3406;
            23: f0_sin_lut[lut_i] = 18'sd3166;
            24: f0_sin_lut[lut_i] = 18'sd2896;
            25: f0_sin_lut[lut_i] = 18'sd2602;
            26: f0_sin_lut[lut_i] = 18'sd2276;
            27: f0_sin_lut[lut_i] = 18'sd1931;
            28: f0_sin_lut[lut_i] = 18'sd1567;
            29: f0_sin_lut[lut_i] = 18'sd1189;
            30: f0_sin_lut[lut_i] = 18'sd799;
            31: f0_sin_lut[lut_i] = 18'sd402;
            32: f0_sin_lut[lut_i] = 18'sd0;
            33: f0_sin_lut[lut_i] = -18'sd402;
            34: f0_sin_lut[lut_i] = -18'sd799;
            35: f0_sin_lut[lut_i] = -18'sd1189;
            36: f0_sin_lut[lut_i] = -18'sd1567;
            37: f0_sin_lut[lut_i] = -18'sd1931;
            38: f0_sin_lut[lut_i] = -18'sd2276;
            39: f0_sin_lut[lut_i] = -18'sd2602;
            40: f0_sin_lut[lut_i] = -18'sd2896;
            41: f0_sin_lut[lut_i] = -18'sd3166;
            42: f0_sin_lut[lut_i] = -18'sd3406;
            43: f0_sin_lut[lut_i] = -18'sd3612;
            44: f0_sin_lut[lut_i] = -18'sd3784;
            45: f0_sin_lut[lut_i] = -18'sd3920;
            46: f0_sin_lut[lut_i] = -18'sd4017;
            47: f0_sin_lut[lut_i] = -18'sd4076;
            48: f0_sin_lut[lut_i] = -18'sd4096;
            49: f0_sin_lut[lut_i] = -18'sd4076;
            50: f0_sin_lut[lut_i] = -18'sd4017;
            51: f0_sin_lut[lut_i] = -18'sd3920;
            52: f0_sin_lut[lut_i] = -18'sd3784;
            53: f0_sin_lut[lut_i] = -18'sd3612;
            54: f0_sin_lut[lut_i] = -18'sd3406;
            55: f0_sin_lut[lut_i] = -18'sd3166;
            56: f0_sin_lut[lut_i] = -18'sd2896;
            57: f0_sin_lut[lut_i] = -18'sd2602;
            58: f0_sin_lut[lut_i] = -18'sd2276;
            59: f0_sin_lut[lut_i] = -18'sd1931;
            60: f0_sin_lut[lut_i] = -18'sd1567;
            61: f0_sin_lut[lut_i] = -18'sd1189;
            62: f0_sin_lut[lut_i] = -18'sd799;
            63: f0_sin_lut[lut_i] = -18'sd402;
        endcase
    end
end

// Generate external f₀ signal
wire [5:0] f0_lut_idx;
assign f0_lut_idx = f0_phase_counter[15:10];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        f0_phase_counter <= 0;
    end else begin
        if (f0_phase_counter >= F0_PERIOD_CLKS - 1)
            f0_phase_counter <= 0;
        else
            f0_phase_counter <= f0_phase_counter + 1;
    end
end

// CSV file handle
integer csv_file;
integer sample_count;
integer clk_count;

// Track clk_en
reg prev_clk_en;
wire clk_en_rising;
assign clk_en_rising = dut.clk_4khz_en && !prev_clk_en;

// Beta amplitude tracking (access internal signals)
wire signed [WIDTH-1:0] motor_l5a_x;
wire signed [WIDTH-1:0] motor_l5b_x;
assign motor_l5a_x = dut.motor_l5a_x;
assign motor_l5b_x = dut.motor_l5b_x;

initial begin
    // Initialize
    clk = 0;
    rst = 1;
    sensory_input = 18'sd8192;
    sr_field_input = 18'sd0;
    state_select = 3'd0;  // Start in NORMAL
    sample_count = 0;
    clk_count = 0;
    prev_clk_en = 0;

    // Open CSV file
    csv_file = $fopen("sie_transition_data.csv", "w");
    $fwrite(csv_file, "time_ms,state,theta_x,f0_x,coherence,beta_l5a,beta_l5b,beta_quiet,sie_active,dac_out\n");

    $display("=============================================================================");
    $display("SIE Transition Analysis: NORMAL → MEDITATION");
    $display("=============================================================================");

    // Release reset
    repeat(100) @(posedge clk);
    rst = 0;

    // Phase 1: NORMAL state baseline (2 seconds)
    $display("");
    $display("Phase 1: NORMAL state baseline (2 seconds)...");
    state_select = 3'd0;
    sr_field_input = f0_sin_lut[f0_lut_idx];

    while (sample_count < 2000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;
        sr_field_input = f0_sin_lut[f0_lut_idx];

        if (clk_en_rising && (clk_count % 10) == 0) begin
            $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                sample_count,
                state_select,
                $signed(debug_theta),
                $signed(f0_x),
                $signed(sr_coherence),
                $signed(motor_l5a_x),
                $signed(motor_l5b_x),
                beta_quiet,
                sr_amplification,
                dac_output
            );
            sample_count = sample_count + 1;
        end
    end
    $display("  Recorded %0d samples in NORMAL state", sample_count);

    // Phase 2: Transition to MEDITATION (3 seconds)
    $display("");
    $display("Phase 2: Transitioning to MEDITATION state...");
    state_select = 3'd4;  // MEDITATION

    while (sample_count < 5000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;
        sr_field_input = f0_sin_lut[f0_lut_idx];

        if (clk_en_rising && (clk_count % 10) == 0) begin
            $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                sample_count,
                state_select,
                $signed(debug_theta),
                $signed(f0_x),
                $signed(sr_coherence),
                $signed(motor_l5a_x),
                $signed(motor_l5b_x),
                beta_quiet,
                sr_amplification,
                dac_output
            );
            sample_count = sample_count + 1;
        end
    end
    $display("  Recorded %0d samples total", sample_count);

    // Phase 3: Return to NORMAL (2 seconds)
    $display("");
    $display("Phase 3: Returning to NORMAL state...");
    state_select = 3'd0;

    while (sample_count < 7000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;
        sr_field_input = f0_sin_lut[f0_lut_idx];

        if (clk_en_rising && (clk_count % 10) == 0) begin
            $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                sample_count,
                state_select,
                $signed(debug_theta),
                $signed(f0_x),
                $signed(sr_coherence),
                $signed(motor_l5a_x),
                $signed(motor_l5b_x),
                beta_quiet,
                sr_amplification,
                dac_output
            );
            sample_count = sample_count + 1;
        end
    end

    $fclose(csv_file);
    $display("");
    $display("Data exported to sie_transition_data.csv");
    $display("Total samples: %0d (7 seconds simulated)", sample_count);
    $finish;
end

endmodule
