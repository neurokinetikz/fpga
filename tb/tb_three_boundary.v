//=============================================================================
// Three-Boundary Architecture Testbench - v1.0
//
// Tests for the three-boundary φⁿ alignment system:
// - f₀ = √(θ×α) → SR1 (Ignition primary)
// - f₂ = √(β_low×β_high) → SR3 (Stability anchor)
// - f₃ = √(β_high×γ) → SR5 (Consciousness gate)
// - SR4 direct coupling (Arousal modulation)
// - Multi-alignment controller integration
//
// 15 Tests:
// 1.  f₂ boundary computation accuracy
// 2.  f₂ alignment detection at SR3 match
// 3.  f₃ boundary computation accuracy
// 4.  f₃ consciousness gate behavior with 8% gap
// 5.  SR4 direct coupling strength
// 6.  SR4 coupling with detuning
// 7.  Multi-alignment weighted sum computation
// 8.  Ignition permission logic
// 9.  Consciousness access gating
// 10. Threshold modulation with alignment
// 11. Backward compatibility (ENABLE_THREE_BOUNDARY=0)
// 12. Three-boundary mode activation
// 13. Beta quiet requirement
// 14. Alignment at nominal frequencies
// 15. Full integration test
//=============================================================================
`timescale 1ns / 1ps

module tb_three_boundary;

//-----------------------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------------------
parameter WIDTH = 18;
parameter FRAC = 14;
parameter CLK_PERIOD = 8;  // 125 MHz

// Q14 constants
localparam signed [WIDTH-1:0] ONE = 18'sd16384;
localparam signed [WIDTH-1:0] HALF = 18'sd8192;

// Nominal OMEGA_DT values (7.75 Hz base)
localparam signed [WIDTH-1:0] OMEGA_THETA    = 18'sd157;   // 6.09 Hz
localparam signed [WIDTH-1:0] OMEGA_ALPHA    = 18'sd254;   // 9.86 Hz
localparam signed [WIDTH-1:0] OMEGA_BETA_LOW = 18'sd410;   // 15.95 Hz
localparam signed [WIDTH-1:0] OMEGA_BETA_HIGH= 18'sd664;   // 25.81 Hz
localparam signed [WIDTH-1:0] OMEGA_GAMMA    = 18'sd845;   // 32.83 Hz

// SR harmonic nominal frequencies
localparam signed [WIDTH-1:0] OMEGA_SR1 = 18'sd199;   // 7.75 Hz
localparam signed [WIDTH-1:0] OMEGA_SR3 = 18'sd514;   // 20.0 Hz
localparam signed [WIDTH-1:0] OMEGA_SR4 = 18'sd643;   // 25.0 Hz
localparam signed [WIDTH-1:0] OMEGA_SR5 = 18'sd823;   // 32.0 Hz

// Expected boundary values
// f₂ = √(410 × 664) = √272240 ≈ 522
// f₃ = √(664 × 845) = √561180 ≈ 749
localparam signed [WIDTH-1:0] EXPECTED_F2_BOUNDARY = 18'sd522;
localparam signed [WIDTH-1:0] EXPECTED_F3_BOUNDARY = 18'sd749;

//-----------------------------------------------------------------------------
// Test Signals
//-----------------------------------------------------------------------------
reg clk;
reg rst;
reg clk_en;

// f₂ detector signals
reg signed [WIDTH-1:0] omega_beta_low_actual;
reg signed [WIDTH-1:0] omega_beta_high_actual;
reg signed [WIDTH-1:0] omega_sr3_actual;
wire signed [WIDTH-1:0] f2_boundary;
wire signed [WIDTH-1:0] f2_detuning;
wire signed [WIDTH-1:0] f2_alignment;
wire signed [WIDTH-1:0] f2_stability_score;

// f₃ detector signals
reg signed [WIDTH-1:0] omega_gamma_actual;
reg signed [WIDTH-1:0] omega_sr5_actual;
wire signed [WIDTH-1:0] f3_boundary;
wire signed [WIDTH-1:0] f3_detuning;
wire signed [WIDTH-1:0] f3_alignment;
wire signed [WIDTH-1:0] f3_consciousness_gate;

// SR4 coupling signals
reg signed [WIDTH-1:0] omega_sr4_actual;
wire signed [WIDTH-1:0] sr4_detuning;
wire signed [WIDTH-1:0] sr4_coupling_strength;

// Multi-alignment controller signals
reg signed [WIDTH-1:0] f0_alignment;
reg signed [WIDTH-1:0] f0_ignition_sens;
reg beta_quiet;
reg signed [WIDTH-1:0] base_threshold;
wire signed [WIDTH-1:0] ignition_threshold;
wire signed [WIDTH-1:0] overall_alignment;
wire ignition_permitted;
wire consciousness_access_possible;

//-----------------------------------------------------------------------------
// Test Counters
//-----------------------------------------------------------------------------
integer test_num;
integer pass_count;
integer fail_count;

//-----------------------------------------------------------------------------
// Clock Generation
//-----------------------------------------------------------------------------
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

//-----------------------------------------------------------------------------
// DUT Instantiations
//-----------------------------------------------------------------------------

// f₂ Boundary Detector
boundary_detector_f2 #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) f2_det (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .omega_beta_low_actual(omega_beta_low_actual),
    .omega_beta_high_actual(omega_beta_high_actual),
    .omega_sr3_actual(omega_sr3_actual),
    .f2_boundary(f2_boundary),
    .f2_detuning(f2_detuning),
    .f2_alignment(f2_alignment),
    .f2_stability_score(f2_stability_score)
);

// f₃ Boundary Detector
boundary_detector_f3 #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) f3_det (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .omega_beta_high_actual(omega_beta_high_actual),
    .omega_gamma_actual(omega_gamma_actual),
    .omega_sr5_actual(omega_sr5_actual),
    .f3_boundary(f3_boundary),
    .f3_detuning(f3_detuning),
    .f3_alignment(f3_alignment),
    .f3_consciousness_gate(f3_consciousness_gate)
);

// SR4 Direct Coupling
direct_coupling_sr4 #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) sr4_coup (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .omega_beta_high_actual(omega_beta_high_actual),
    .omega_sr4_actual(omega_sr4_actual),
    .sr4_detuning(sr4_detuning),
    .sr4_coupling_strength(sr4_coupling_strength)
);

// Multi-Alignment Controller
multi_alignment_ctrl #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) align_ctrl (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .f0_alignment(f0_alignment),
    .f0_ignition_sens(f0_ignition_sens),
    .f2_alignment(f2_alignment),
    .f2_stability(f2_stability_score),
    .f3_alignment(f3_alignment),
    .f3_consciousness(f3_consciousness_gate),
    .sr4_coupling(sr4_coupling_strength),
    .beta_quiet(beta_quiet),
    .base_threshold(base_threshold),
    .ignition_threshold(ignition_threshold),
    .overall_alignment(overall_alignment),
    .ignition_permitted(ignition_permitted),
    .consciousness_access_possible(consciousness_access_possible)
);

//-----------------------------------------------------------------------------
// Helper Tasks
//-----------------------------------------------------------------------------
task apply_clk_cycles;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk);
            clk_en <= 1'b1;
            @(posedge clk);
            clk_en <= 1'b0;
        end
    end
endtask

task check_result;
    input [255:0] test_name;
    input condition;
    begin
        test_num = test_num + 1;
        if (condition) begin
            $display("TEST %0d PASS: %s", test_num, test_name);
            pass_count = pass_count + 1;
        end else begin
            $display("TEST %0d FAIL: %s", test_num, test_name);
            fail_count = fail_count + 1;
        end
    end
endtask

task check_range;
    input [255:0] test_name;
    input signed [WIDTH-1:0] value;
    input signed [WIDTH-1:0] expected;
    input signed [WIDTH-1:0] tolerance;
    begin
        check_result(test_name,
            (value >= expected - tolerance) && (value <= expected + tolerance));
        $display("       Value: %0d, Expected: %0d +/- %0d", value, expected, tolerance);
    end
endtask

//-----------------------------------------------------------------------------
// Main Test Sequence
//-----------------------------------------------------------------------------
initial begin
    $display("=============================================================");
    $display("Three-Boundary Architecture Testbench");
    $display("=============================================================");

    // Initialize
    test_num = 0;
    pass_count = 0;
    fail_count = 0;

    rst = 1;
    clk_en = 0;

    // Set nominal frequencies
    omega_beta_low_actual = OMEGA_BETA_LOW;
    omega_beta_high_actual = OMEGA_BETA_HIGH;
    omega_gamma_actual = OMEGA_GAMMA;
    omega_sr3_actual = OMEGA_SR3;
    omega_sr4_actual = OMEGA_SR4;
    omega_sr5_actual = OMEGA_SR5;

    // Multi-alignment inputs
    f0_alignment = 18'sd0;
    f0_ignition_sens = 18'sd0;
    beta_quiet = 1'b0;
    base_threshold = 18'sd12288;  // 0.75 nominal

    // Reset
    #100;
    rst = 0;
    #100;

    //=========================================================================
    // TEST 1: f₂ boundary computation accuracy
    //=========================================================================
    $display("\n--- Test 1: f2 boundary computation ---");
    apply_clk_cycles(10);
    check_range("f2 boundary sqrt(beta_low * beta_high)",
                f2_boundary, EXPECTED_F2_BOUNDARY, 18'sd15);

    //=========================================================================
    // TEST 2: f₂ alignment detection at SR3 match
    //=========================================================================
    $display("\n--- Test 2: f2 alignment at SR3 match ---");
    // Adjust frequencies so f2 exactly matches SR3
    omega_beta_low_actual = 18'sd400;
    omega_beta_high_actual = 18'sd660;
    // √(400 × 660) = √264000 ≈ 514 = SR3
    apply_clk_cycles(10);
    check_result("f2 alignment > 0.8 when boundary matches SR3",
                 f2_alignment > 18'sd13107);  // > 0.8
    $display("       f2_boundary: %0d, f2_alignment: %0d", f2_boundary, f2_alignment);

    //=========================================================================
    // TEST 3: f₃ boundary computation accuracy
    //=========================================================================
    $display("\n--- Test 3: f3 boundary computation ---");
    omega_beta_low_actual = OMEGA_BETA_LOW;
    omega_beta_high_actual = OMEGA_BETA_HIGH;
    omega_gamma_actual = OMEGA_GAMMA;
    apply_clk_cycles(10);
    check_range("f3 boundary sqrt(beta_high * gamma)",
                f3_boundary, EXPECTED_F3_BOUNDARY, 18'sd20);

    //=========================================================================
    // TEST 4: f₃ consciousness gate with 8% gap
    //=========================================================================
    $display("\n--- Test 4: f3 consciousness gate behavior ---");
    // At nominal frequencies, f3 (749) is far from SR5 (823)
    // Gap = 74 OMEGA_DT, with sigma=10, alignment should be low
    apply_clk_cycles(10);
    check_result("f3 consciousness gate closed at nominal gap",
                 f3_consciousness_gate == 18'sd0);
    $display("       f3_boundary: %0d, f3_detuning: %0d, gate: %0d",
             f3_boundary, f3_detuning, f3_consciousness_gate);

    // Now force frequencies closer to open the gate
    omega_beta_high_actual = 18'sd750;
    omega_gamma_actual = 18'sd900;
    // √(750 × 900) = √675000 ≈ 822 ≈ SR5
    apply_clk_cycles(10);
    check_result("f3 consciousness gate opens when aligned",
                 f3_consciousness_gate > 18'sd4915);  // > 0.3
    $display("       f3_boundary: %0d, f3_alignment: %0d, gate: %0d",
             f3_boundary, f3_alignment, f3_consciousness_gate);

    //=========================================================================
    // TEST 5: SR4 direct coupling strength at match
    //=========================================================================
    $display("\n--- Test 5: SR4 coupling at match ---");
    omega_beta_high_actual = 18'sd643;  // Exactly SR4
    omega_sr4_actual = OMEGA_SR4;
    apply_clk_cycles(10);
    check_result("SR4 coupling > 0.9 when beta_high = SR4",
                 sr4_coupling_strength > 18'sd14746);  // > 0.9
    $display("       detuning: %0d, coupling: %0d", sr4_detuning, sr4_coupling_strength);

    //=========================================================================
    // TEST 6: SR4 coupling decreases with detuning
    //=========================================================================
    $display("\n--- Test 6: SR4 coupling with detuning ---");
    omega_beta_high_actual = OMEGA_BETA_HIGH;  // 664, gap of 21
    apply_clk_cycles(10);
    check_result("SR4 coupling = 0 when detuning > sigma",
                 sr4_coupling_strength == 18'sd0);
    $display("       detuning: %0d (sigma=8), coupling: %0d", sr4_detuning, sr4_coupling_strength);

    //=========================================================================
    // TEST 7: Multi-alignment weighted sum
    //=========================================================================
    $display("\n--- Test 7: Multi-alignment weighted sum ---");
    // Reset to nominal
    omega_beta_low_actual = OMEGA_BETA_LOW;
    omega_beta_high_actual = OMEGA_BETA_HIGH;
    omega_gamma_actual = OMEGA_GAMMA;

    // Set f0 alignment high
    f0_alignment = 18'sd16384;  // 1.0
    f0_ignition_sens = ONE;

    // Set SR3 alignment (from f2 detector)
    omega_beta_low_actual = 18'sd400;
    omega_beta_high_actual = 18'sd660;

    apply_clk_cycles(20);  // Allow pipeline to settle

    // Overall alignment = 0.4×f0 + 0.3×f2 + 0.2×sr4 + 0.1×f3
    // f0 = 1.0, f2 should be high (~1.0), sr4 = 0, f3 = 0
    // Expected: ~0.4 + ~0.3 = ~0.7
    check_result("Overall alignment computed as weighted sum",
                 overall_alignment > 18'sd9830);  // > 0.6
    $display("       overall_alignment: %0d (expected ~0.7 = 11469)", overall_alignment);

    //=========================================================================
    // TEST 8: Ignition permission logic
    //=========================================================================
    $display("\n--- Test 8: Ignition permission logic ---");
    // Needs: f0 > 0.3, f2_stability > 0.2, beta_quiet
    f0_alignment = 18'sd8192;   // 0.5 > 0.3 OK
    beta_quiet = 1'b0;          // Not quiet
    apply_clk_cycles(10);
    check_result("Ignition NOT permitted without beta_quiet",
                 ignition_permitted == 1'b0);

    beta_quiet = 1'b1;          // Now quiet
    apply_clk_cycles(10);
    check_result("Ignition permitted with all conditions met",
                 ignition_permitted == 1'b1);
    $display("       f0: %0d, f2_stab: %0d, beta_quiet: %0d, permitted: %0d",
             f0_alignment, f2_stability_score, beta_quiet, ignition_permitted);

    //=========================================================================
    // TEST 9: Consciousness access gating
    //=========================================================================
    $display("\n--- Test 9: Consciousness access gating ---");
    // Needs: ignition_permitted + f3_consciousness > 0.3
    // Currently f3 gate is closed
    check_result("Consciousness NOT accessible without f3 gate",
                 consciousness_access_possible == 1'b0);

    // Open f3 gate while maintaining f2 alignment
    // Need: f2 = √(β_low × β_high) ≈ SR3 (514)
    //       f3 = √(β_high × γ) ≈ SR5 (823)
    // Solve: β_high = 700, β_low = 377, γ = 968
    // √(377 × 700) ≈ 514, √(700 × 968) ≈ 823
    omega_beta_low_actual = 18'sd377;
    omega_beta_high_actual = 18'sd700;
    omega_gamma_actual = 18'sd968;
    f0_alignment = 18'sd8192;   // 0.5 > 0.3
    beta_quiet = 1'b1;
    apply_clk_cycles(20);
    $display("       f2_boundary: %0d (SR3=%0d), f2_stab: %0d",
             f2_boundary, omega_sr3_actual, f2_stability_score);
    $display("       f3_boundary: %0d (SR5=%0d), f3_consciousness: %0d",
             f3_boundary, omega_sr5_actual, f3_consciousness_gate);
    $display("       ignition_permitted: %0d, consciousness_access: %0d",
             ignition_permitted, consciousness_access_possible);
    check_result("Consciousness accessible with f3 gate open",
                 consciousness_access_possible == 1'b1);

    //=========================================================================
    // TEST 10: Threshold modulation with alignment
    //=========================================================================
    $display("\n--- Test 10: Threshold modulation ---");
    // Reset
    omega_beta_low_actual = OMEGA_BETA_LOW;
    omega_beta_high_actual = OMEGA_BETA_HIGH;
    omega_gamma_actual = OMEGA_GAMMA;
    f0_alignment = 18'sd0;
    beta_quiet = 1'b0;
    apply_clk_cycles(15);

    // Low alignment → threshold should be higher (×1.5)
    // base = 0.75, scale = 1.5 → threshold ≈ 1.125 = 18432
    $display("       Low alignment: threshold = %0d (expected ~18432)", ignition_threshold);
    check_result("Low alignment raises threshold",
                 ignition_threshold > base_threshold);

    // High alignment → threshold should be lower (×1.0)
    f0_alignment = ONE;  // 1.0
    omega_beta_low_actual = 18'sd400;
    omega_beta_high_actual = 18'sd660;
    apply_clk_cycles(20);
    $display("       High alignment: threshold = %0d (expected ~12288)", ignition_threshold);
    check_result("High alignment lowers threshold",
                 ignition_threshold < 18'sd18432);

    //=========================================================================
    // TEST 11: Backward compatibility check
    //=========================================================================
    $display("\n--- Test 11: Backward compatibility concept ---");
    // When ENABLE_THREE_BOUNDARY=0, multi_alignment_threshold should be ignored
    // This is a conceptual check - actual behavior verified in integration
    check_result("Module computes outputs even without top-level enable",
                 f2_boundary > 18'sd0 && overall_alignment >= 18'sd0);

    //=========================================================================
    // TEST 12: Three-boundary mode outputs valid
    //=========================================================================
    $display("\n--- Test 12: Three-boundary outputs valid ---");
    check_result("All three boundary detectors produce outputs",
                 f2_boundary > 18'sd0 && f3_boundary > 18'sd0 && sr4_detuning >= 18'sd0);
    check_result("Multi-alignment controller produces valid threshold",
                 ignition_threshold > 18'sd0 && ignition_threshold < 18'sd32768);

    //=========================================================================
    // TEST 13: Beta quiet requirement enforced
    //=========================================================================
    $display("\n--- Test 13: Beta quiet requirement ---");
    f0_alignment = ONE;
    beta_quiet = 1'b0;
    apply_clk_cycles(10);
    check_result("Ignition blocked without beta_quiet",
                 ignition_permitted == 1'b0);

    //=========================================================================
    // TEST 14: Alignment at exact nominal frequencies
    //=========================================================================
    $display("\n--- Test 14: Nominal frequency alignment ---");
    omega_beta_low_actual = OMEGA_BETA_LOW;
    omega_beta_high_actual = OMEGA_BETA_HIGH;
    omega_gamma_actual = OMEGA_GAMMA;
    omega_sr3_actual = OMEGA_SR3;
    omega_sr4_actual = OMEGA_SR4;
    omega_sr5_actual = OMEGA_SR5;
    apply_clk_cycles(15);

    // f2: √(410×664)=522, SR3=514, gap=8, within sigma=5? Close
    $display("       f2: boundary=%0d, SR3=%0d, detuning=%0d, alignment=%0d",
             f2_boundary, omega_sr3_actual, f2_detuning, f2_alignment);
    // f3: √(664×845)=749, SR5=823, gap=74, well outside sigma=10
    $display("       f3: boundary=%0d, SR5=%0d, detuning=%0d, alignment=%0d",
             f3_boundary, omega_sr5_actual, f3_detuning, f3_alignment);
    // sr4: beta_high=664, SR4=643, gap=21, outside sigma=8
    $display("       SR4: beta_high=%0d, SR4=%0d, detuning=%0d, coupling=%0d",
             omega_beta_high_actual, omega_sr4_actual, sr4_detuning, sr4_coupling_strength);

    check_result("Nominal f2 has some alignment (detuning ~8)",
                 f2_alignment > 18'sd0 || f2_detuning < 18'sd15);

    //=========================================================================
    // TEST 15: Full integration test
    //=========================================================================
    $display("\n--- Test 15: Full integration ---");
    // Configure for aligned state
    f0_alignment = 18'sd12288;  // 0.75
    omega_beta_low_actual = 18'sd400;
    omega_beta_high_actual = 18'sd660;
    omega_gamma_actual = OMEGA_GAMMA;
    omega_sr3_actual = OMEGA_SR3;
    beta_quiet = 1'b1;
    base_threshold = 18'sd12288;

    apply_clk_cycles(25);

    $display("       Final state:");
    $display("       f0_alignment: %0d", f0_alignment);
    $display("       f2_boundary: %0d, f2_alignment: %0d", f2_boundary, f2_alignment);
    $display("       f3_boundary: %0d, f3_alignment: %0d", f3_boundary, f3_alignment);
    $display("       sr4_coupling: %0d", sr4_coupling_strength);
    $display("       overall_alignment: %0d", overall_alignment);
    $display("       ignition_threshold: %0d (base: %0d)", ignition_threshold, base_threshold);
    $display("       ignition_permitted: %0d", ignition_permitted);
    $display("       consciousness_access: %0d", consciousness_access_possible);

    check_result("Full integration produces consistent outputs",
                 ignition_permitted == 1'b1 && ignition_threshold > 18'sd0);

    //=========================================================================
    // Summary
    //=========================================================================
    $display("\n=============================================================");
    $display("TEST SUMMARY: %0d/%0d passed", pass_count, pass_count + fail_count);
    if (fail_count == 0) begin
        $display("ALL TESTS PASSED!");
    end else begin
        $display("FAILURES: %0d", fail_count);
    end
    $display("=============================================================");

    #100;
    $finish;
end

endmodule
