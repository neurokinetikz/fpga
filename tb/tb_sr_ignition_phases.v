//=============================================================================
// Testbench: SR Ignition Controller - Six-Phase SIE Evolution
//
// Tests the six-phase Schumann Ignition Event state machine:
// 1. Baseline - Low coherence, no ignition
// 2. Coherence-First - PLV rises before amplitude (~3-4s)
// 3. Ignition - Amplitude surge begins
// 4. Plateau - Peak sustained
// 5. Propagation - PAC window, gradual decay
// 6. Decay - Exponential relaxation
// 7. Refractory - No re-ignition
//
// Validation criteria (from empirical 556-582s event):
// - Baseline gain = 0 (v1.1 coherence-gated), PLV ~0.45
// - Coherence phase: PLV rises to ~0.80, gain stays low (~0.20)
// - Peak gain reaches 1.0 during plateau
// - Total event ~21.5s for NORMAL state
// - Refractory prevents immediate re-ignition
//
// Usage:
//   iverilog -o tb_sr_ignition_phases.vvp -s tb_sr_ignition_phases \
//       src/sr_ignition_controller.v tb/tb_sr_ignition_phases.v && \
//   vvp tb_sr_ignition_phases.vvp
//=============================================================================
`timescale 1ns / 1ps

module tb_sr_ignition_phases;

parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 8;  // 125 MHz

reg clk;
reg rst;
reg clk_en;
reg signed [WIDTH-1:0] coherence_in;
reg beta_quiet;

// Phase timing (NORMAL state values from config_controller)
reg [15:0] phase2_dur;  // Coherence-first: 14000 cycles = 3.5s
reg [15:0] phase3_dur;  // Ignition: 10000 cycles = 2.5s
reg [15:0] phase4_dur;  // Plateau: 10000 cycles = 2.5s
reg [15:0] phase5_dur;  // Propagation: 36000 cycles = 9s
reg [15:0] phase6_dur;  // Decay: 16000 cycles = 4s
reg [15:0] refractory;  // Refractory: 40000 cycles = 10s

wire [2:0] ignition_phase;
wire signed [WIDTH-1:0] gain_envelope;
wire signed [WIDTH-1:0] plv_envelope;
wire ignition_active;

// DUT instantiation
sr_ignition_controller #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) dut (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .coherence_in(coherence_in),
    .beta_quiet(beta_quiet),
    .phase2_dur(phase2_dur),
    .phase3_dur(phase3_dur),
    .phase4_dur(phase4_dur),
    .phase5_dur(phase5_dur),
    .phase6_dur(phase6_dur),
    .refractory(refractory),
    .ignition_phase(ignition_phase),
    .gain_envelope(gain_envelope),
    .plv_envelope(plv_envelope),
    .ignition_active(ignition_active)
);

// Clock generation
always #(CLK_PERIOD/2) clk = ~clk;

// Q14 constants for comparison
localparam signed [WIDTH-1:0] Q14_ONE = 18'sd16384;    // 1.0
localparam signed [WIDTH-1:0] Q14_HALF = 18'sd8192;    // 0.5
localparam signed [WIDTH-1:0] Q14_POINT45 = 18'sd7373; // 0.45
localparam signed [WIDTH-1:0] Q14_POINT60 = 18'sd9830; // 0.60
localparam signed [WIDTH-1:0] Q14_POINT75 = 18'sd12288; // 0.75
localparam signed [WIDTH-1:0] Q14_POINT78 = 18'sd12780; // 0.78 - above threshold for triggering
localparam signed [WIDTH-1:0] Q14_POINT80 = 18'sd13107; // 0.80

// Test tracking
integer test_count = 0;
integer pass_count = 0;
integer fail_count = 0;

// 4kHz clock enable counter (for FAST_SIM equivalent)
reg [3:0] clk_div;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_div <= 0;
        clk_en <= 0;
    end else begin
        clk_div <= clk_div + 1;
        clk_en <= (clk_div == 4'd9);  // Every 10 cycles = FAST_SIM mode
    end
end

// Helper task: run N clock enable cycles
task run_cycles;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk);
            while (!clk_en) @(posedge clk);
        end
    end
endtask

// Test task
task check_test;
    input [255:0] name;
    input condition;
    begin
        test_count = test_count + 1;
        if (condition) begin
            pass_count = pass_count + 1;
            $display("  PASS: %s", name);
        end else begin
            fail_count = fail_count + 1;
            $display("  FAIL: %s", name);
        end
    end
endtask

initial begin
    $display("=============================================================================");
    $display("SR Ignition Controller Testbench - Six-Phase SIE Evolution");
    $display("=============================================================================");

    // Initialize
    clk = 0;
    rst = 1;
    coherence_in = 18'sd0;
    beta_quiet = 0;

    // NORMAL state timing
    phase2_dur = 16'd1400;   // 0.35s (scaled down for faster test)
    phase3_dur = 16'd1000;   // 0.25s
    phase4_dur = 16'd1000;   // 0.25s
    phase5_dur = 16'd3600;   // 0.9s
    phase6_dur = 16'd1600;   // 0.4s
    refractory = 16'd4000;   // 1.0s

    // Release reset
    repeat(100) @(posedge clk);
    rst = 0;

    $display("\n--- Test 1: Baseline State ---");
    run_cycles(100);
    check_test("Phase is BASELINE (0)", ignition_phase == 3'd0);
    check_test("Gain at baseline (0, coherence-gated)", gain_envelope == 18'sd0);
    check_test("PLV at baseline (~0.45)", plv_envelope >= Q14_POINT45 - 18'sd500 && plv_envelope <= Q14_POINT45 + 18'sd500);
    check_test("Ignition not active", ignition_active == 1'b0);

    $display("\n--- Test 2: No Ignition Without Beta Quiet ---");
    coherence_in = Q14_POINT78;  // High coherence (above threshold)
    beta_quiet = 0;  // But beta NOT quiet
    run_cycles(200);
    check_test("Still in BASELINE despite high coherence", ignition_phase == 3'd0);

    $display("\n--- Test 3: Trigger Ignition (Coherence + Beta Quiet) ---");
    coherence_in = Q14_POINT78;  // High coherence (above threshold)
    beta_quiet = 1;  // Beta quiet - trigger!
    run_cycles(10);
    check_test("Transitioned to COHERENCE phase (1)", ignition_phase == 3'd1);
    check_test("Ignition now active", ignition_active == 1'b1);

    $display("\n--- Test 4: Coherence-First Phase (PLV Rises Before Gain) ---");
    run_cycles(700);  // Half of coherence phase
    check_test("Still in COHERENCE phase", ignition_phase == 3'd1);
    check_test("PLV increasing toward 0.80", plv_envelope > Q14_POINT60);
    check_test("Gain still low (coherence-first!)", gain_envelope < Q14_HALF);

    // Complete coherence phase
    run_cycles(800);
    check_test("Transitioned to IGNITION phase (2)", ignition_phase == 3'd2);

    $display("\n--- Test 5: Ignition Phase (Amplitude Surge) ---");
    run_cycles(500);  // Half of ignition phase
    check_test("Gain increasing rapidly", gain_envelope > Q14_HALF);
    run_cycles(600);
    check_test("Transitioned to PLATEAU phase (3)", ignition_phase == 3'd3);

    $display("\n--- Test 6: Plateau Phase (Peak Sustained) ---");
    run_cycles(500);
    check_test("Gain near peak (1.0)", gain_envelope > Q14_POINT80);
    check_test("PLV at peak (~0.80)", plv_envelope >= Q14_POINT75);
    run_cycles(600);
    check_test("Transitioned to PROPAGATION phase (4)", ignition_phase == 3'd4);

    $display("\n--- Test 7: Propagation Phase (PAC Window) ---");
    run_cycles(1800);  // Half of propagation
    check_test("Gain decaying from peak", gain_envelope < Q14_ONE);
    check_test("Still in PROPAGATION", ignition_phase == 3'd4);
    run_cycles(2000);
    check_test("Transitioned to DECAY phase (5)", ignition_phase == 3'd5);

    $display("\n--- Test 8: Decay Phase (Exponential Relaxation) ---");
    run_cycles(800);
    check_test("Gain decaying toward baseline", gain_envelope < Q14_POINT60);
    run_cycles(1000);
    check_test("Transitioned to REFRACTORY phase (6)", ignition_phase == 3'd6);
    check_test("Ignition no longer active", ignition_active == 1'b0);

    $display("\n--- Test 9: Refractory Phase (No Re-Ignition) ---");
    coherence_in = Q14_POINT78;  // Try to trigger again (above threshold)
    beta_quiet = 1;
    run_cycles(500);
    check_test("Still in REFRACTORY despite trigger conditions", ignition_phase == 3'd6);

    $display("\n--- Test 10: Return to Baseline After Refractory ---");
    // Clear trigger conditions to observe baseline
    coherence_in = 18'sd0;
    beta_quiet = 0;
    run_cycles(4500);  // Complete refractory (with margin)
    check_test("Returned to BASELINE (0)", ignition_phase == 3'd0);
    check_test("Gain back to baseline", gain_envelope < Q14_HALF);

    $display("\n--- Test 11: Second Ignition Possible After Refractory ---");
    coherence_in = Q14_POINT78;  // Above threshold
    beta_quiet = 1;
    run_cycles(50);
    check_test("Can trigger second ignition", ignition_phase == 3'd1);

    // Summary
    $display("\n=============================================================================");
    $display("Test Summary: %0d/%0d passed", pass_count, test_count);
    if (fail_count == 0) begin
        $display("ALL TESTS PASSED");
    end else begin
        $display("FAILURES: %0d", fail_count);
    end
    $display("=============================================================================");

    $finish;
end

endmodule
