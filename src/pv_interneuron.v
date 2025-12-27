//=============================================================================
// PV+ Interneuron Module - v9.2
//
// Models PV+ (parvalbumin-positive) basket cell dynamics for PING
// (Pyramidal-Interneuron Gamma Network) gamma oscillation.
//
// BIOLOGICAL BASIS:
// - PV+ basket cells are fast-spiking GABAergic interneurons
// - Target soma and proximal dendrites (perisomatic inhibition)
// - Receive excitation from local pyramidal cells
// - Fast time constant (~5ms) enables gamma-frequency firing
// - Create E-I loop essential for gamma oscillation generation
// - Phase relationship: PV+ activity lags pyramidal by ~90°
//
// MODEL:
// Leaky integrator: dPV/dt = -PV/tau + K_E × pyramid_input
// Discrete: pv[n+1] = pv[n] + alpha × (-pv[n] + K_E × input)
// Where alpha = dt/tau = 0.25ms/5ms = 0.05
//
// OUTPUT:
// inhibition = K_I × pv_state (subtractive to pyramidal input)
//
// DIFFERENCE FROM PHASE 1 (v9.0):
// - Phase 1: Instantaneous amplitude-proportional inhibition
// - Phase 3: Dynamic state with temporal evolution and phase lag
// - Creates more realistic PING dynamics
//=============================================================================
`timescale 1ns / 1ps

module pv_interneuron #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,

    // Excitatory input from pyramidal cell (x component)
    input  wire signed [WIDTH-1:0] pyramid_input,

    // Inhibitory output to pyramidal cell
    output wire signed [WIDTH-1:0] inhibition,

    // Debug output: internal state
    output wire signed [WIDTH-1:0] pv_state_out
);

//=============================================================================
// Constants (Q4.14 format)
//=============================================================================
// Time constant: tau = 5ms at 4kHz (dt = 0.25ms)
// alpha = dt/tau = 0.25/5 = 0.05
localparam signed [WIDTH-1:0] TAU_INV = 18'sd819;    // 0.05

// Excitation gain: how much pyramidal input drives PV+ cell
localparam signed [WIDTH-1:0] K_EXCITE = 18'sd8192;  // 0.5

// Inhibition gain: how much PV+ output inhibits pyramidal cell
localparam signed [WIDTH-1:0] K_INHIB = 18'sd4915;   // 0.3

//=============================================================================
// PV+ State Variable
//=============================================================================
reg signed [WIDTH-1:0] pv_state;

//=============================================================================
// Leaky Integrator Dynamics
//=============================================================================
// pv[n+1] = pv[n] + alpha × (-pv[n] + K_E × pyramid_input)
//
// Expanded:
// 1. scaled_input = K_E × pyramid_input
// 2. drive = -pv_state + scaled_input
// 3. delta = alpha × drive
// 4. pv_state += delta

wire signed [2*WIDTH-1:0] scaled_input_full;
wire signed [WIDTH-1:0] scaled_input;
wire signed [WIDTH-1:0] drive;
wire signed [2*WIDTH-1:0] delta_full;
wire signed [WIDTH-1:0] delta;

// Scale pyramidal input by excitation gain
assign scaled_input_full = pyramid_input * K_EXCITE;
assign scaled_input = scaled_input_full >>> FRAC;

// Compute drive: input minus decay
assign drive = scaled_input - pv_state;

// Apply time constant
assign delta_full = drive * TAU_INV;
assign delta = delta_full >>> FRAC;

always @(posedge clk) begin
    if (rst) begin
        pv_state <= 0;
    end else if (clk_en) begin
        pv_state <= pv_state + delta;
    end
end

//=============================================================================
// Output: Inhibition to Pyramidal Cell
//=============================================================================
wire signed [2*WIDTH-1:0] inhib_full;
assign inhib_full = pv_state * K_INHIB;
assign inhibition = inhib_full >>> FRAC;

// Debug output
assign pv_state_out = pv_state;

endmodule
