//=============================================================================
// Hopf Oscillator Unit Test
// Tests the basic oscillator functionality
//=============================================================================
`timescale 1ns / 1ps

module tb_hopf_oscillator;

parameter WIDTH = 18;
parameter FRAC = 14;

reg clk, rst, clk_en;
reg signed [WIDTH-1:0] mu_dt;
reg signed [WIDTH-1:0] omega_dt;
reg signed [WIDTH-1:0] input_x;
wire signed [WIDTH-1:0] x, y, amplitude;

// Instantiate DUT
hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .mu_dt(mu_dt),
    .omega_dt(omega_dt),
    .input_x(input_x),
    .x(x),
    .y(y),
    .amplitude(amplitude)
);

// 100 MHz clock
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// Test variables
integer i;
integer zero_crossings;
reg prev_sign;
real freq_hz;

initial begin
    $display("========================================");
    $display("HOPF OSCILLATOR UNIT TEST");
    $display("========================================");

    rst = 1;
    clk_en = 0;
    mu_dt = 18'sd4;  // Standard mu*dt (4 kHz rate)
    omega_dt = 18'sd152;  // Theta frequency (5.89 Hz) at 4 kHz
    input_x = 18'sd0;

    repeat(10) @(posedge clk);
    rst = 0;

    // TEST 1: Startup behavior
    $display("\n[TEST 1] Startup behavior");
    $display("         Initial x: %0d (expect ~8192)", x);
    $display("         Initial y: %0d (expect 0)", y);

    // Let it run for warmup
    for (i = 0; i < 500; i = i + 1) begin
        @(posedge clk); clk_en = 1;
        @(posedge clk); clk_en = 0;
    end

    // TEST 2: Amplitude stability
    $display("\n[TEST 2] Amplitude stability after 500 updates");
    $display("         x: %0d, y: %0d", x, y);
    $display("         amplitude: %0d (expect ~16384-32768)", amplitude);

    // TEST 3: Frequency measurement (4000 updates = 1 second at 4 kHz)
    $display("\n[TEST 3] Frequency measurement (theta = 5.89 Hz)");
    zero_crossings = 0;
    prev_sign = x[WIDTH-1];

    for (i = 0; i < 4000; i = i + 1) begin
        @(posedge clk); clk_en = 1;
        @(posedge clk); clk_en = 0;
        if (x[WIDTH-1] != prev_sign) begin
            zero_crossings = zero_crossings + 1;
            prev_sign = x[WIDTH-1];
        end
    end

    freq_hz = zero_crossings / 2.0;  // 2 zero crossings per period (4000 updates = 1s)
    $display("         Zero crossings in 1s: %0d", zero_crossings);
    $display("         Estimated frequency: %.2f Hz", freq_hz);

    // TEST 4: Different frequency (Gamma = 40.36 Hz)
    $display("\n[TEST 4] Gamma frequency (40.36 Hz)");
    omega_dt = 18'sd1039;  // Gamma omega*dt (4 kHz rate)
    zero_crossings = 0;
    prev_sign = x[WIDTH-1];

    for (i = 0; i < 4000; i = i + 1) begin
        @(posedge clk); clk_en = 1;
        @(posedge clk); clk_en = 0;
        if (x[WIDTH-1] != prev_sign) begin
            zero_crossings = zero_crossings + 1;
            prev_sign = x[WIDTH-1];
        end
    end

    freq_hz = zero_crossings / 2.0;  // 4000 updates = 1s at 4 kHz
    $display("         Zero crossings in 1s: %0d", zero_crossings);
    $display("         Estimated frequency: %.2f Hz", freq_hz);

    // TEST 5: Input coupling
    $display("\n[TEST 5] Input coupling response");
    omega_dt = 18'sd152;  // Back to theta
    input_x = 18'sd2048;  // Add external input

    for (i = 0; i < 200; i = i + 1) begin
        @(posedge clk); clk_en = 1;
        @(posedge clk); clk_en = 0;
    end

    $display("         With input: x=%0d, y=%0d, amp=%0d", x, y, amplitude);
    input_x = 18'sd0;

    $display("\n========================================");
    $display("HOPF OSCILLATOR TEST COMPLETE");
    $display("========================================");

    $finish;
end

// Waveform dump
initial begin
    $dumpfile("tb_hopf_oscillator.vcd");
    $dumpvars(0, tb_hopf_oscillator);
end

endmodule
