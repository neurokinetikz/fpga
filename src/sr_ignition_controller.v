//=============================================================================
// Schumann Resonance Ignition Controller v1.1
//
// Implements six-phase SIE (Schumann Ignition Event) state machine based on
// empirical EEG observations (neurokinetikz 2019-2025).
//
// v1.1 CHANGES: GAIN_BASELINE = 0 for coherence-gated behavior
// - SR only influences brain oscillators during detected ignition events
// - No tonic SR presence in baseline spectrum
//
// Key features:
// - Transient amplification during ignition events (z ~20-25, 10-15× boost)
// - Six-phase evolution matching empirical data:
//   1. Baseline     - Desynchronized (PLV ~0.4-0.5)
//   2. Coherence    - PLV rises BEFORE amplitude (~3-4s) ⭐ Key signature
//   3. Ignition     - Amplitude surge begins (~2-3s)
//   4. Plateau      - Peak sustained (~2-3s)
//   5. Propagation  - PAC peak, sustained activity (~8-10s)
//   6. Decay        - Exponential relaxation (~3-5s)
//   7. Refractory   - No re-ignition period (~8-12s)
//
// The "coherence-first" signature (PLV rises before amplitude) distinguishes
// external SR forcing from internal oscillation, matching the hysteresis loop
// seen in Kuramoto R vs SR Power plots.
//
// Reference: "Continuous Golden Ratio Architecture at Schumann Resonance
// Frequencies with Transient High-Coherence Amplification"
//=============================================================================
`timescale 1ns / 1ps

module sr_ignition_controller #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Coherence input (from sr_harmonic_bank, average or f0)
    input  wire signed [WIDTH-1:0] coherence_in,  // Q14 format, 0-1

    // Beta quiet input (from sr_harmonic_bank)
    input  wire beta_quiet,

    // Phase timing inputs (from config_controller, in 4kHz cycles)
    input  wire [15:0] phase2_dur,   // Coherence-first duration (~14000 = 3.5s)
    input  wire [15:0] phase3_dur,   // Ignition duration (~10000 = 2.5s)
    input  wire [15:0] phase4_dur,   // Plateau duration (~10000 = 2.5s)
    input  wire [15:0] phase5_dur,   // Propagation duration (~36000 = 9s)
    input  wire [15:0] phase6_dur,   // Decay duration (~16000 = 4s)
    input  wire [15:0] refractory,   // Refractory period (~40000 = 10s)

    // Outputs
    output reg [2:0] ignition_phase,              // Current phase (0-7)
    output reg signed [WIDTH-1:0] gain_envelope,  // Amplitude gain (0-1 in Q14)
    output reg signed [WIDTH-1:0] plv_envelope,   // PLV envelope (0-1 in Q14)
    output reg ignition_active                    // High during phases 1-6
);

//-----------------------------------------------------------------------------
// Phase Encoding
//-----------------------------------------------------------------------------
localparam [2:0] PHASE_BASELINE     = 3'd0;
localparam [2:0] PHASE_COHERENCE    = 3'd1;  // PLV rises, gain stays low
localparam [2:0] PHASE_IGNITION     = 3'd2;  // Amplitude surge
localparam [2:0] PHASE_PLATEAU      = 3'd3;  // Peak sustained
localparam [2:0] PHASE_PROPAGATION  = 3'd4;  // PAC peak window
localparam [2:0] PHASE_DECAY        = 3'd5;  // Exponential decay
localparam [2:0] PHASE_REFRACTORY   = 3'd6;  // No re-ignition

//-----------------------------------------------------------------------------
// Thresholds (Q14 format)
//-----------------------------------------------------------------------------
// Coherence threshold to trigger ignition (0.6 = 9830)
localparam signed [WIDTH-1:0] COHERENCE_THRESH = 18'sd9830;

// PLV target values for coherence-first signature
localparam signed [WIDTH-1:0] PLV_BASELINE = 18'sd7373;    // 0.45
localparam signed [WIDTH-1:0] PLV_PEAK = 18'sd13107;       // 0.80

// Gain values - v1.1: ZERO baseline for coherence-gated behavior
localparam signed [WIDTH-1:0] GAIN_BASELINE = 18'sd0;      // 0 - NO baseline gain (was 0.10)
localparam signed [WIDTH-1:0] GAIN_COHERENCE = 18'sd3277;  // 0.20 (slight rise in coherence phase)
localparam signed [WIDTH-1:0] GAIN_PEAK = 18'sd16384;      // 1.00 (full scale during peak)
localparam signed [WIDTH-1:0] GAIN_PROPAGATION = 18'sd9830; // 0.60 (sustained but lower)

//-----------------------------------------------------------------------------
// Envelope Rate Constants (for smooth transitions)
// These determine how fast the envelopes ramp up/down
//-----------------------------------------------------------------------------
// Attack rate for PLV in coherence phase: ramp from 0.45 to 0.80 in ~3.5s
// Delta per step = (0.80 - 0.45) / 14000 = 0.000025 = ~0.41 in Q14
localparam signed [WIDTH-1:0] PLV_ATTACK_ALPHA = 18'sd41;

// Attack rate for gain in ignition phase: ramp from 0.20 to 1.00 in ~2.5s
// Delta per step = (1.00 - 0.20) / 10000 = 0.00008 = ~1.31 in Q14
localparam signed [WIDTH-1:0] GAIN_ATTACK_ALPHA = 18'sd131;

// Decay rate: exponential decay with tau ~4s
// decay_factor = exp(-1/(4000*4)) ≈ 0.99994 per step
// Implemented as: value <= value - (value >> 12)
localparam [3:0] DECAY_SHIFT = 4'd12;  // Gives tau ≈ 4096 steps ≈ 1s at 4kHz

//-----------------------------------------------------------------------------
// Internal Registers
//-----------------------------------------------------------------------------
reg [15:0] phase_counter;  // Counts cycles within current phase
reg coherence_triggered;   // Latches when coherence threshold crossed

//-----------------------------------------------------------------------------
// State Machine
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ignition_phase <= PHASE_BASELINE;
        phase_counter <= 16'd0;
        gain_envelope <= GAIN_BASELINE;
        plv_envelope <= PLV_BASELINE;
        ignition_active <= 1'b0;
        coherence_triggered <= 1'b0;
    end else if (clk_en) begin
        case (ignition_phase)

            //------------------------------------------------------------------
            // PHASE 0: BASELINE
            // Wait for trigger conditions: coherence > threshold AND beta_quiet
            //------------------------------------------------------------------
            PHASE_BASELINE: begin
                ignition_active <= 1'b0;
                gain_envelope <= GAIN_BASELINE;
                plv_envelope <= PLV_BASELINE;
                phase_counter <= 16'd0;

                // Check trigger conditions
                if (coherence_in > COHERENCE_THRESH && beta_quiet) begin
                    ignition_phase <= PHASE_COHERENCE;
                    coherence_triggered <= 1'b1;
                    ignition_active <= 1'b1;
                end
            end

            //------------------------------------------------------------------
            // PHASE 1: COHERENCE-FIRST
            // PLV ramps up quickly, gain rises slowly (~20% of peak)
            // This is the key signature of external SR forcing
            //------------------------------------------------------------------
            PHASE_COHERENCE: begin
                phase_counter <= phase_counter + 1;
                ignition_active <= 1'b1;

                // PLV ramps up quickly toward 0.80
                if (plv_envelope < PLV_PEAK) begin
                    plv_envelope <= plv_envelope + PLV_ATTACK_ALPHA;
                end else begin
                    plv_envelope <= PLV_PEAK;
                end

                // Gain rises slowly (only to ~20% of peak)
                if (gain_envelope < GAIN_COHERENCE) begin
                    gain_envelope <= gain_envelope + (PLV_ATTACK_ALPHA >>> 1);
                end

                // Transition to ignition phase
                if (phase_counter >= phase2_dur) begin
                    ignition_phase <= PHASE_IGNITION;
                    phase_counter <= 16'd0;
                end
            end

            //------------------------------------------------------------------
            // PHASE 2: IGNITION (Amplitude Surge)
            // Gain ramps up rapidly to peak
            //------------------------------------------------------------------
            PHASE_IGNITION: begin
                phase_counter <= phase_counter + 1;
                ignition_active <= 1'b1;

                // Gain ramps up rapidly
                if (gain_envelope < GAIN_PEAK) begin
                    gain_envelope <= gain_envelope + GAIN_ATTACK_ALPHA;
                end else begin
                    gain_envelope <= GAIN_PEAK;
                end

                // PLV maintained at peak
                plv_envelope <= PLV_PEAK;

                // Transition to plateau
                if (phase_counter >= phase3_dur) begin
                    ignition_phase <= PHASE_PLATEAU;
                    phase_counter <= 16'd0;
                end
            end

            //------------------------------------------------------------------
            // PHASE 3: PLATEAU
            // Peak amplitude sustained
            //------------------------------------------------------------------
            PHASE_PLATEAU: begin
                phase_counter <= phase_counter + 1;
                ignition_active <= 1'b1;

                // Hold at peak
                gain_envelope <= GAIN_PEAK;
                plv_envelope <= PLV_PEAK;

                // Transition to propagation
                if (phase_counter >= phase4_dur) begin
                    ignition_phase <= PHASE_PROPAGATION;
                    phase_counter <= 16'd0;
                end
            end

            //------------------------------------------------------------------
            // PHASE 4: PROPAGATION
            // Sustained activity, PAC peaks here
            // Gradual decay begins
            //------------------------------------------------------------------
            PHASE_PROPAGATION: begin
                phase_counter <= phase_counter + 1;
                ignition_active <= 1'b1;

                // Gradual decay toward propagation level
                if (gain_envelope > GAIN_PROPAGATION) begin
                    gain_envelope <= gain_envelope - (gain_envelope >>> DECAY_SHIFT);
                end

                // PLV slowly decreases
                if (plv_envelope > PLV_BASELINE + 18'sd2000) begin
                    plv_envelope <= plv_envelope - (plv_envelope >>> (DECAY_SHIFT + 1));
                end

                // Transition to decay
                if (phase_counter >= phase5_dur) begin
                    ignition_phase <= PHASE_DECAY;
                    phase_counter <= 16'd0;
                end
            end

            //------------------------------------------------------------------
            // PHASE 5: DECAY
            // Exponential relaxation back to baseline
            //------------------------------------------------------------------
            PHASE_DECAY: begin
                phase_counter <= phase_counter + 1;
                ignition_active <= 1'b1;

                // Exponential decay toward baseline
                if (gain_envelope > GAIN_BASELINE + 18'sd100) begin
                    gain_envelope <= gain_envelope - ((gain_envelope - GAIN_BASELINE) >>> DECAY_SHIFT);
                end else begin
                    gain_envelope <= GAIN_BASELINE;
                end

                // PLV decays to baseline
                if (plv_envelope > PLV_BASELINE + 18'sd100) begin
                    plv_envelope <= plv_envelope - ((plv_envelope - PLV_BASELINE) >>> DECAY_SHIFT);
                end else begin
                    plv_envelope <= PLV_BASELINE;
                end

                // Transition to refractory
                if (phase_counter >= phase6_dur) begin
                    ignition_phase <= PHASE_REFRACTORY;
                    phase_counter <= 16'd0;
                end
            end

            //------------------------------------------------------------------
            // PHASE 6: REFRACTORY
            // No re-ignition allowed, baseline maintained
            //------------------------------------------------------------------
            PHASE_REFRACTORY: begin
                phase_counter <= phase_counter + 1;
                ignition_active <= 1'b0;

                // Hold at baseline
                gain_envelope <= GAIN_BASELINE;
                plv_envelope <= PLV_BASELINE;
                coherence_triggered <= 1'b0;

                // Return to baseline after refractory period
                if (phase_counter >= refractory) begin
                    ignition_phase <= PHASE_BASELINE;
                    phase_counter <= 16'd0;
                end
            end

            default: begin
                ignition_phase <= PHASE_BASELINE;
            end

        endcase
    end
end

endmodule
