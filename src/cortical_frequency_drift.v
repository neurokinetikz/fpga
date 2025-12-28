//=============================================================================
// Cortical Frequency Drift Generator - v2.1
//
// Models frequency variability in cortical oscillators for EEG-realistic output.
// Two components create broad spectral peaks like real EEG:
//
// 1. SLOW DRIFT: Bounded random walk (±0.5 Hz over seconds)
//    - Updates every 0.2s in simulation
//    - Models slow frequency drift seen in EEG
//
// 2. FAST JITTER: Cycle-by-cycle frequency noise (±0.5 Hz per sample)
//    - Updates every clk_en cycle (4 kHz)
//    - Creates significant spectral broadening around oscillator peaks
//    - Models neural timing variability and phase noise
//
// v2.1 CHANGES:
// - Increased jitter range from ±0.15 Hz to ±0.5 Hz for broader peaks
// - Use 5 LFSR bits instead of 3 for wider distribution
// - Creates ~1-2 Hz wide peaks (more EEG-realistic)
//
// v2.0 CHANGES:
// - Added fast jitter outputs for each layer
// - Jitter uses separate LFSRs updating every sample
//
// CORTICAL OSCILLATOR FREQUENCIES (phi^n based):
//   L6:   9.53 Hz  (phi^0.5)  - alpha band
//   L5a:  15.42 Hz (phi^1.5)  - low beta
//   L5b:  24.94 Hz (phi^2.5)  - high beta
//   L4:   31.73 Hz (phi^3)    - low gamma
//   L2/3: 40.36 Hz (phi^3.5)  - gamma (switches to 65.3 Hz in encoding)
//
// Effect: Sharp spectral lines → broad EEG-like peaks (~1-2 Hz width)
//=============================================================================
`timescale 1ns / 1ps

module cortical_frequency_drift #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_LAYERS = 5,
    parameter FAST_SIM = 0
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Slow drift offsets for each layer (bounded random walk, updates slowly)
    output wire signed [WIDTH-1:0] drift_l6,      // L6 alpha drift
    output wire signed [WIDTH-1:0] drift_l5a,     // L5a low-beta drift
    output wire signed [WIDTH-1:0] drift_l5b,     // L5b high-beta drift
    output wire signed [WIDTH-1:0] drift_l4,      // L4 low-gamma drift
    output wire signed [WIDTH-1:0] drift_l23,     // L2/3 gamma drift

    // Fast jitter for each layer (cycle-by-cycle noise, updates every sample)
    output wire signed [WIDTH-1:0] jitter_l6,     // L6 alpha jitter
    output wire signed [WIDTH-1:0] jitter_l5a,    // L5a low-beta jitter
    output wire signed [WIDTH-1:0] jitter_l5b,    // L5b high-beta jitter
    output wire signed [WIDTH-1:0] jitter_l4,     // L4 low-gamma jitter
    output wire signed [WIDTH-1:0] jitter_l23     // L2/3 gamma jitter
);

//-----------------------------------------------------------------------------
// Slow Drift Range
// ±0.5 Hz in OMEGA_DT units: round(2π × 0.5 × 0.00025 × 16384) = ±13
// Cortical oscillators are more stable than SR
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] DRIFT_MAX = 18'sd13;  // ±0.5 Hz

//-----------------------------------------------------------------------------
// Fast Jitter Range
// ±0.5 Hz in OMEGA_DT units: round(2π × 0.5 × 0.00025 × 16384) = ±13
// Larger per-sample frequency noise for significant spectral broadening
// Creates ~1-2 Hz wide peaks instead of sharp lines
//-----------------------------------------------------------------------------
localparam signed [WIDTH-1:0] JITTER_MAX = 18'sd13;  // ±0.5 Hz (was ±0.15 Hz)

//-----------------------------------------------------------------------------
// Update Period
// Slower than SR drift - cortical oscillators are more stable
// FAST_SIM: 800 clk_en = 0.2s at 4kHz
// Real-time: 1920000 clk_en = 8 minutes
//-----------------------------------------------------------------------------
`ifdef FAST_SIM
    localparam [21:0] UPDATE_PERIOD = 22'd800;      // 0.2s updates (slower than SR)
`else
    localparam [21:0] UPDATE_PERIOD = (FAST_SIM != 0) ? 22'd800 : 22'd1920000;
`endif

//-----------------------------------------------------------------------------
// Update Counter
//-----------------------------------------------------------------------------
reg [21:0] update_counter;
wire update_tick;

assign update_tick = (update_counter == UPDATE_PERIOD);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_counter <= 22'd0;
    end else if (clk_en) begin
        if (update_tick) begin
            update_counter <= 22'd0;
        end else begin
            update_counter <= update_counter + 1'b1;
        end
    end
end

//-----------------------------------------------------------------------------
// LFSR Seeds (unique per layer, different from SR seeds)
//-----------------------------------------------------------------------------
localparam [15:0] LFSR_SEED_L6  = 16'h7A3D;
localparam [15:0] LFSR_SEED_L5A = 16'hE5B2;
localparam [15:0] LFSR_SEED_L5B = 16'h29C8;
localparam [15:0] LFSR_SEED_L4  = 16'hD4F1;
localparam [15:0] LFSR_SEED_L23 = 16'h8167;

//-----------------------------------------------------------------------------
// Per-Layer LFSR and Drift State
//-----------------------------------------------------------------------------
reg [15:0] lfsr_l6, lfsr_l5a, lfsr_l5b, lfsr_l4, lfsr_l23;
reg signed [WIDTH-1:0] drift_l6_reg, drift_l5a_reg, drift_l5b_reg, drift_l4_reg, drift_l23_reg;

// LFSR feedback: x^16 + x^14 + x^13 + x^11 + 1
wire fb_l6  = lfsr_l6[15]  ^ lfsr_l6[13]  ^ lfsr_l6[12]  ^ lfsr_l6[10];
wire fb_l5a = lfsr_l5a[15] ^ lfsr_l5a[13] ^ lfsr_l5a[12] ^ lfsr_l5a[10];
wire fb_l5b = lfsr_l5b[15] ^ lfsr_l5b[13] ^ lfsr_l5b[12] ^ lfsr_l5b[10];
wire fb_l4  = lfsr_l4[15]  ^ lfsr_l4[13]  ^ lfsr_l4[12]  ^ lfsr_l4[10];
wire fb_l23 = lfsr_l23[15] ^ lfsr_l23[13] ^ lfsr_l23[12] ^ lfsr_l23[10];

// Step direction from LSB
wire dir_l6  = lfsr_l6[0];
wire dir_l5a = lfsr_l5a[0];
wire dir_l5b = lfsr_l5b[0];
wire dir_l4  = lfsr_l4[0];
wire dir_l23 = lfsr_l23[0];

// Variable step size (1-2 for cortical, smaller than SR)
wire signed [WIDTH-1:0] step_l6  = lfsr_l6[1]  ? 18'sd2 : 18'sd1;
wire signed [WIDTH-1:0] step_l5a = lfsr_l5a[1] ? 18'sd2 : 18'sd1;
wire signed [WIDTH-1:0] step_l5b = lfsr_l5b[1] ? 18'sd2 : 18'sd1;
wire signed [WIDTH-1:0] step_l4  = lfsr_l4[1]  ? 18'sd2 : 18'sd1;
wire signed [WIDTH-1:0] step_l23 = lfsr_l23[1] ? 18'sd2 : 18'sd1;

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L6 Alpha
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l6 <= LFSR_SEED_L6;
        drift_l6_reg <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_l6 <= {lfsr_l6[14:0], fb_l6};
        if (dir_l6) begin
            if (drift_l6_reg + step_l6 <= DRIFT_MAX)
                drift_l6_reg <= drift_l6_reg + step_l6;
            else
                drift_l6_reg <= drift_l6_reg - step_l6;  // Reflect
        end else begin
            if (drift_l6_reg - step_l6 >= -DRIFT_MAX)
                drift_l6_reg <= drift_l6_reg - step_l6;
            else
                drift_l6_reg <= drift_l6_reg + step_l6;  // Reflect
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L5a Low Beta
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l5a <= LFSR_SEED_L5A;
        drift_l5a_reg <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_l5a <= {lfsr_l5a[14:0], fb_l5a};
        if (dir_l5a) begin
            if (drift_l5a_reg + step_l5a <= DRIFT_MAX)
                drift_l5a_reg <= drift_l5a_reg + step_l5a;
            else
                drift_l5a_reg <= drift_l5a_reg - step_l5a;
        end else begin
            if (drift_l5a_reg - step_l5a >= -DRIFT_MAX)
                drift_l5a_reg <= drift_l5a_reg - step_l5a;
            else
                drift_l5a_reg <= drift_l5a_reg + step_l5a;
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L5b High Beta
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l5b <= LFSR_SEED_L5B;
        drift_l5b_reg <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_l5b <= {lfsr_l5b[14:0], fb_l5b};
        if (dir_l5b) begin
            if (drift_l5b_reg + step_l5b <= DRIFT_MAX)
                drift_l5b_reg <= drift_l5b_reg + step_l5b;
            else
                drift_l5b_reg <= drift_l5b_reg - step_l5b;
        end else begin
            if (drift_l5b_reg - step_l5b >= -DRIFT_MAX)
                drift_l5b_reg <= drift_l5b_reg - step_l5b;
            else
                drift_l5b_reg <= drift_l5b_reg + step_l5b;
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L4 Low Gamma
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l4 <= LFSR_SEED_L4;
        drift_l4_reg <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_l4 <= {lfsr_l4[14:0], fb_l4};
        if (dir_l4) begin
            if (drift_l4_reg + step_l4 <= DRIFT_MAX)
                drift_l4_reg <= drift_l4_reg + step_l4;
            else
                drift_l4_reg <= drift_l4_reg - step_l4;
        end else begin
            if (drift_l4_reg - step_l4 >= -DRIFT_MAX)
                drift_l4_reg <= drift_l4_reg - step_l4;
            else
                drift_l4_reg <= drift_l4_reg + step_l4;
        end
    end
end

//-----------------------------------------------------------------------------
// Random Walk Update Logic - L2/3 Gamma
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr_l23 <= LFSR_SEED_L23;
        drift_l23_reg <= 18'sd0;
    end else if (clk_en && update_tick) begin
        lfsr_l23 <= {lfsr_l23[14:0], fb_l23};
        if (dir_l23) begin
            if (drift_l23_reg + step_l23 <= DRIFT_MAX)
                drift_l23_reg <= drift_l23_reg + step_l23;
            else
                drift_l23_reg <= drift_l23_reg - step_l23;
        end else begin
            if (drift_l23_reg - step_l23 >= -DRIFT_MAX)
                drift_l23_reg <= drift_l23_reg - step_l23;
            else
                drift_l23_reg <= drift_l23_reg + step_l23;
        end
    end
end

//=============================================================================
// FAST JITTER - Cycle-by-cycle frequency noise for spectral broadening
//=============================================================================

//-----------------------------------------------------------------------------
// Fast Jitter LFSR Seeds (different from slow drift seeds)
//-----------------------------------------------------------------------------
localparam [15:0] JLFSR_SEED_L6  = 16'hB2C4;
localparam [15:0] JLFSR_SEED_L5A = 16'h4F8E;
localparam [15:0] JLFSR_SEED_L5B = 16'hD1A7;
localparam [15:0] JLFSR_SEED_L4  = 16'h6E39;
localparam [15:0] JLFSR_SEED_L23 = 16'h95CB;

//-----------------------------------------------------------------------------
// Fast Jitter LFSR State (updates every clk_en cycle)
//-----------------------------------------------------------------------------
reg [15:0] jlfsr_l6, jlfsr_l5a, jlfsr_l5b, jlfsr_l4, jlfsr_l23;

// LFSR feedback for fast jitter (same polynomial)
wire jfb_l6  = jlfsr_l6[15]  ^ jlfsr_l6[13]  ^ jlfsr_l6[12]  ^ jlfsr_l6[10];
wire jfb_l5a = jlfsr_l5a[15] ^ jlfsr_l5a[13] ^ jlfsr_l5a[12] ^ jlfsr_l5a[10];
wire jfb_l5b = jlfsr_l5b[15] ^ jlfsr_l5b[13] ^ jlfsr_l5b[12] ^ jlfsr_l5b[10];
wire jfb_l4  = jlfsr_l4[15]  ^ jlfsr_l4[13]  ^ jlfsr_l4[12]  ^ jlfsr_l4[10];
wire jfb_l23 = jlfsr_l23[15] ^ jlfsr_l23[13] ^ jlfsr_l23[12] ^ jlfsr_l23[10];

//-----------------------------------------------------------------------------
// Fast Jitter Update Logic (updates EVERY clk_en cycle)
//-----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        jlfsr_l6  <= JLFSR_SEED_L6;
        jlfsr_l5a <= JLFSR_SEED_L5A;
        jlfsr_l5b <= JLFSR_SEED_L5B;
        jlfsr_l4  <= JLFSR_SEED_L4;
        jlfsr_l23 <= JLFSR_SEED_L23;
    end else if (clk_en) begin
        jlfsr_l6  <= {jlfsr_l6[14:0],  jfb_l6};
        jlfsr_l5a <= {jlfsr_l5a[14:0], jfb_l5a};
        jlfsr_l5b <= {jlfsr_l5b[14:0], jfb_l5b};
        jlfsr_l4  <= {jlfsr_l4[14:0],  jfb_l4};
        jlfsr_l23 <= {jlfsr_l23[14:0], jfb_l23};
    end
end

//-----------------------------------------------------------------------------
// Fast Jitter Value Computation
// Use 5 bits from LFSR to create values in range [-13, +13] (±0.5 Hz)
// Triangular distribution: sum of weighted bits creates bell-curve-ish distribution
// (bit4 ? +8 : -8) + (bit3 ? +4 : -4) + (bit2 ? +2 : -2) + (bit1 ? +1 : -1) + (bit0 ? +1 : 0)
// Range: -15 to +14, clamped to ±13
//-----------------------------------------------------------------------------
wire signed [WIDTH-1:0] jitter_l6_raw  = (jlfsr_l6[4]  ? 18'sd8 : -18'sd8) +
                                          (jlfsr_l6[3]  ? 18'sd4 : -18'sd4) +
                                          (jlfsr_l6[2]  ? 18'sd2 : -18'sd2) +
                                          (jlfsr_l6[1]  ? 18'sd1 : -18'sd1) +
                                          (jlfsr_l6[0]  ? 18'sd1 : 18'sd0);

wire signed [WIDTH-1:0] jitter_l5a_raw = (jlfsr_l5a[4] ? 18'sd8 : -18'sd8) +
                                          (jlfsr_l5a[3] ? 18'sd4 : -18'sd4) +
                                          (jlfsr_l5a[2] ? 18'sd2 : -18'sd2) +
                                          (jlfsr_l5a[1] ? 18'sd1 : -18'sd1) +
                                          (jlfsr_l5a[0] ? 18'sd1 : 18'sd0);

wire signed [WIDTH-1:0] jitter_l5b_raw = (jlfsr_l5b[4] ? 18'sd8 : -18'sd8) +
                                          (jlfsr_l5b[3] ? 18'sd4 : -18'sd4) +
                                          (jlfsr_l5b[2] ? 18'sd2 : -18'sd2) +
                                          (jlfsr_l5b[1] ? 18'sd1 : -18'sd1) +
                                          (jlfsr_l5b[0] ? 18'sd1 : 18'sd0);

wire signed [WIDTH-1:0] jitter_l4_raw  = (jlfsr_l4[4]  ? 18'sd8 : -18'sd8) +
                                          (jlfsr_l4[3]  ? 18'sd4 : -18'sd4) +
                                          (jlfsr_l4[2]  ? 18'sd2 : -18'sd2) +
                                          (jlfsr_l4[1]  ? 18'sd1 : -18'sd1) +
                                          (jlfsr_l4[0]  ? 18'sd1 : 18'sd0);

wire signed [WIDTH-1:0] jitter_l23_raw = (jlfsr_l23[4] ? 18'sd8 : -18'sd8) +
                                          (jlfsr_l23[3] ? 18'sd4 : -18'sd4) +
                                          (jlfsr_l23[2] ? 18'sd2 : -18'sd2) +
                                          (jlfsr_l23[1] ? 18'sd1 : -18'sd1) +
                                          (jlfsr_l23[0] ? 18'sd1 : 18'sd0);

//-----------------------------------------------------------------------------
// Output Assignments
//-----------------------------------------------------------------------------
// Slow drift outputs
assign drift_l6  = drift_l6_reg;
assign drift_l5a = drift_l5a_reg;
assign drift_l5b = drift_l5b_reg;
assign drift_l4  = drift_l4_reg;
assign drift_l23 = drift_l23_reg;

// Fast jitter outputs (clamped to ±JITTER_MAX for safety)
assign jitter_l6  = (jitter_l6_raw  > JITTER_MAX) ? JITTER_MAX :
                    (jitter_l6_raw  < -JITTER_MAX) ? -JITTER_MAX : jitter_l6_raw;
assign jitter_l5a = (jitter_l5a_raw > JITTER_MAX) ? JITTER_MAX :
                    (jitter_l5a_raw < -JITTER_MAX) ? -JITTER_MAX : jitter_l5a_raw;
assign jitter_l5b = (jitter_l5b_raw > JITTER_MAX) ? JITTER_MAX :
                    (jitter_l5b_raw < -JITTER_MAX) ? -JITTER_MAX : jitter_l5b_raw;
assign jitter_l4  = (jitter_l4_raw  > JITTER_MAX) ? JITTER_MAX :
                    (jitter_l4_raw  < -JITTER_MAX) ? -JITTER_MAX : jitter_l4_raw;
assign jitter_l23 = (jitter_l23_raw > JITTER_MAX) ? JITTER_MAX :
                    (jitter_l23_raw < -JITTER_MAX) ? -JITTER_MAX : jitter_l23_raw;

endmodule
