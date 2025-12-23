//=============================================================================
// Testbench: Multi-Harmonic SR - CSV Export
//
// Captures detailed multi-harmonic data during NORMAL → MEDITATION transition
// for Python visualization and analysis.
//
// Exports: time, state, f0-f4 x values, coherences, SIE status, beta_quiet
//=============================================================================
`timescale 1ns / 1ps

module tb_multi_harmonic_csv;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter NUM_HARMONICS = 5;
parameter CLK_PERIOD = 8;

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

wire signed [WIDTH-1:0] f0_x, f0_y, f0_amplitude;
wire signed [WIDTH-1:0] sr_coherence;
wire sr_amplification;
wire beta_quiet;

wire signed [NUM_HARMONICS*WIDTH-1:0] sr_f_x_packed;
wire signed [NUM_HARMONICS*WIDTH-1:0] sr_coherence_packed;
wire [NUM_HARMONICS-1:0] sie_per_harmonic;
wire [NUM_HARMONICS-1:0] coherence_mask;

// Instantiate DUT
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

//=============================================================================
// Multi-Harmonic Signal Generation
//=============================================================================

// φⁿ-scaled frequencies: 7.49, 12.12, 19.60, 31.73, 51.33 Hz
localparam F0_PERIOD_CLKS = 53405;  // 7.49 Hz  (φ⁰)
localparam F1_PERIOD_CLKS = 33003;  // 12.12 Hz (φ¹)
localparam F2_PERIOD_CLKS = 20408;  // 19.60 Hz (φ²)
localparam F3_PERIOD_CLKS = 12609;  // 31.73 Hz (φ³)
localparam F4_PERIOD_CLKS = 7793;   // 51.33 Hz (φ⁴)

integer phase_counter [0:NUM_HARMONICS-1];
integer PERIOD_ARRAY [0:NUM_HARMONICS-1];

reg signed [WIDTH-1:0] sin_lut [0:63];

integer lut_i;
initial begin
    for (lut_i = 0; lut_i < 64; lut_i = lut_i + 1) begin
        case (lut_i)
            0:  sin_lut[lut_i] = 18'sd0;
            1:  sin_lut[lut_i] = 18'sd402;
            2:  sin_lut[lut_i] = 18'sd799;
            3:  sin_lut[lut_i] = 18'sd1189;
            4:  sin_lut[lut_i] = 18'sd1567;
            5:  sin_lut[lut_i] = 18'sd1931;
            6:  sin_lut[lut_i] = 18'sd2276;
            7:  sin_lut[lut_i] = 18'sd2602;
            8:  sin_lut[lut_i] = 18'sd2896;
            9:  sin_lut[lut_i] = 18'sd3166;
            10: sin_lut[lut_i] = 18'sd3406;
            11: sin_lut[lut_i] = 18'sd3612;
            12: sin_lut[lut_i] = 18'sd3784;
            13: sin_lut[lut_i] = 18'sd3920;
            14: sin_lut[lut_i] = 18'sd4017;
            15: sin_lut[lut_i] = 18'sd4076;
            16: sin_lut[lut_i] = 18'sd4096;
            17: sin_lut[lut_i] = 18'sd4076;
            18: sin_lut[lut_i] = 18'sd4017;
            19: sin_lut[lut_i] = 18'sd3920;
            20: sin_lut[lut_i] = 18'sd3784;
            21: sin_lut[lut_i] = 18'sd3612;
            22: sin_lut[lut_i] = 18'sd3406;
            23: sin_lut[lut_i] = 18'sd3166;
            24: sin_lut[lut_i] = 18'sd2896;
            25: sin_lut[lut_i] = 18'sd2602;
            26: sin_lut[lut_i] = 18'sd2276;
            27: sin_lut[lut_i] = 18'sd1931;
            28: sin_lut[lut_i] = 18'sd1567;
            29: sin_lut[lut_i] = 18'sd1189;
            30: sin_lut[lut_i] = 18'sd799;
            31: sin_lut[lut_i] = 18'sd402;
            32: sin_lut[lut_i] = 18'sd0;
            33: sin_lut[lut_i] = -18'sd402;
            34: sin_lut[lut_i] = -18'sd799;
            35: sin_lut[lut_i] = -18'sd1189;
            36: sin_lut[lut_i] = -18'sd1567;
            37: sin_lut[lut_i] = -18'sd1931;
            38: sin_lut[lut_i] = -18'sd2276;
            39: sin_lut[lut_i] = -18'sd2602;
            40: sin_lut[lut_i] = -18'sd2896;
            41: sin_lut[lut_i] = -18'sd3166;
            42: sin_lut[lut_i] = -18'sd3406;
            43: sin_lut[lut_i] = -18'sd3612;
            44: sin_lut[lut_i] = -18'sd3784;
            45: sin_lut[lut_i] = -18'sd3920;
            46: sin_lut[lut_i] = -18'sd4017;
            47: sin_lut[lut_i] = -18'sd4076;
            48: sin_lut[lut_i] = -18'sd4096;
            49: sin_lut[lut_i] = -18'sd4076;
            50: sin_lut[lut_i] = -18'sd4017;
            51: sin_lut[lut_i] = -18'sd3920;
            52: sin_lut[lut_i] = -18'sd3784;
            53: sin_lut[lut_i] = -18'sd3612;
            54: sin_lut[lut_i] = -18'sd3406;
            55: sin_lut[lut_i] = -18'sd3166;
            56: sin_lut[lut_i] = -18'sd2896;
            57: sin_lut[lut_i] = -18'sd2602;
            58: sin_lut[lut_i] = -18'sd2276;
            59: sin_lut[lut_i] = -18'sd1931;
            60: sin_lut[lut_i] = -18'sd1567;
            61: sin_lut[lut_i] = -18'sd1189;
            62: sin_lut[lut_i] = -18'sd799;
            63: sin_lut[lut_i] = -18'sd402;
        endcase
    end
    PERIOD_ARRAY[0] = F0_PERIOD_CLKS;
    PERIOD_ARRAY[1] = F1_PERIOD_CLKS;
    PERIOD_ARRAY[2] = F2_PERIOD_CLKS;
    PERIOD_ARRAY[3] = F3_PERIOD_CLKS;
    PERIOD_ARRAY[4] = F4_PERIOD_CLKS;
end

wire [5:0] lut_idx_0, lut_idx_1, lut_idx_2, lut_idx_3, lut_idx_4;
assign lut_idx_0 = phase_counter[0][15:10];
assign lut_idx_1 = phase_counter[1][14:9];
assign lut_idx_2 = phase_counter[2][14:9];
assign lut_idx_3 = phase_counter[3][13:8];
assign lut_idx_4 = phase_counter[4][13:8];

wire signed [WIDTH-1:0] sr_field [0:NUM_HARMONICS-1];
assign sr_field[0] = sin_lut[lut_idx_0];
assign sr_field[1] = sin_lut[lut_idx_1];
assign sr_field[2] = sin_lut[lut_idx_2];
assign sr_field[3] = sin_lut[lut_idx_3];
assign sr_field[4] = sin_lut[lut_idx_4];

integer h;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (h = 0; h < NUM_HARMONICS; h = h + 1)
            phase_counter[h] <= 0;
    end else begin
        for (h = 0; h < NUM_HARMONICS; h = h + 1) begin
            if (phase_counter[h] >= PERIOD_ARRAY[h] - 1)
                phase_counter[h] <= 0;
            else
                phase_counter[h] <= phase_counter[h] + 1;
        end
    end
end

always @(*) begin
    sr_field_packed = {sr_field[4], sr_field[3], sr_field[2], sr_field[1], sr_field[0]};
end

//=============================================================================
// CSV Export
//=============================================================================

integer csv_file;
integer sample_count;
integer clk_count;

reg prev_clk_en;
wire clk_en_rising;
assign clk_en_rising = dut.clk_4khz_en && !prev_clk_en;

// Unpack coherence values
wire signed [WIDTH-1:0] coh0, coh1, coh2, coh3, coh4;
assign coh0 = sr_coherence_packed[0*WIDTH +: WIDTH];
assign coh1 = sr_coherence_packed[1*WIDTH +: WIDTH];
assign coh2 = sr_coherence_packed[2*WIDTH +: WIDTH];
assign coh3 = sr_coherence_packed[3*WIDTH +: WIDTH];
assign coh4 = sr_coherence_packed[4*WIDTH +: WIDTH];

// Unpack f_x values
wire signed [WIDTH-1:0] fx0, fx1, fx2, fx3, fx4;
assign fx0 = sr_f_x_packed[0*WIDTH +: WIDTH];
assign fx1 = sr_f_x_packed[1*WIDTH +: WIDTH];
assign fx2 = sr_f_x_packed[2*WIDTH +: WIDTH];
assign fx3 = sr_f_x_packed[3*WIDTH +: WIDTH];
assign fx4 = sr_f_x_packed[4*WIDTH +: WIDTH];

integer i;
initial begin
    clk = 0;
    rst = 1;
    sensory_input = 18'sd8192;
    sr_field_input = 18'sd0;
    sr_field_packed = 0;
    state_select = 3'd0;
    sample_count = 0;
    clk_count = 0;
    prev_clk_en = 0;

    for (i = 0; i < NUM_HARMONICS; i = i + 1)
        phase_counter[i] = 0;

    csv_file = $fopen("multi_harmonic_data.csv", "w");
    $fwrite(csv_file, "time_ms,state,theta_x,f0_x,f1_x,f2_x,f3_x,f4_x,coh0,coh1,coh2,coh3,coh4,sie_mask,beta_quiet,sie_any\n");

    $display("============================================================================");
    $display("Multi-Harmonic SR Analysis: CSV Export");
    $display("============================================================================");

    repeat(100) @(posedge clk);
    rst = 0;

    // Phase 1: NORMAL (2 seconds)
    $display("Phase 1: NORMAL state (2 seconds)...");
    state_select = 3'd0;

    while (sample_count < 2000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;

        if (clk_en_rising && (clk_count % 10) == 0) begin
            $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                sample_count,
                state_select,
                $signed(debug_theta),
                $signed(fx0), $signed(fx1), $signed(fx2), $signed(fx3), $signed(fx4),
                $signed(coh0), $signed(coh1), $signed(coh2), $signed(coh3), $signed(coh4),
                sie_per_harmonic,
                beta_quiet,
                sr_amplification
            );
            sample_count = sample_count + 1;
        end
    end

    // Phase 2: MEDITATION (3 seconds)
    $display("Phase 2: MEDITATION state (3 seconds)...");
    state_select = 3'd4;

    while (sample_count < 5000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;

        if (clk_en_rising && (clk_count % 10) == 0) begin
            $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                sample_count,
                state_select,
                $signed(debug_theta),
                $signed(fx0), $signed(fx1), $signed(fx2), $signed(fx3), $signed(fx4),
                $signed(coh0), $signed(coh1), $signed(coh2), $signed(coh3), $signed(coh4),
                sie_per_harmonic,
                beta_quiet,
                sr_amplification
            );
            sample_count = sample_count + 1;
        end
    end

    // Phase 3: NORMAL return (2 seconds)
    $display("Phase 3: NORMAL state return (2 seconds)...");
    state_select = 3'd0;

    while (sample_count < 7000) begin
        @(posedge clk);
        prev_clk_en <= dut.clk_4khz_en;
        clk_count = clk_count + 1;

        if (clk_en_rising && (clk_count % 10) == 0) begin
            $fwrite(csv_file, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                sample_count,
                state_select,
                $signed(debug_theta),
                $signed(fx0), $signed(fx1), $signed(fx2), $signed(fx3), $signed(fx4),
                $signed(coh0), $signed(coh1), $signed(coh2), $signed(coh3), $signed(coh4),
                sie_per_harmonic,
                beta_quiet,
                sr_amplification
            );
            sample_count = sample_count + 1;
        end
    end

    $fclose(csv_file);
    $display("");
    $display("Data exported to multi_harmonic_data.csv");
    $display("Total samples: %0d (7 seconds simulated)", sample_count);
    $finish;
end

endmodule
