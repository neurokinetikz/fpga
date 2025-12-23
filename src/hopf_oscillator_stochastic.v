//=============================================================================
// Hopf Oscillator (Stochastic Variant) - v1.0
//
// Based on hopf_oscillator.v v6.0, with added noise input for true
// stochastic resonance behavior.
//
// Adds noise_x input which is added to the dx update term, introducing
// small random perturbations to the oscillator phase/amplitude.
//
// For deterministic behavior, set noise_x = 0.
//=============================================================================
`timescale 1ns / 1ps

module hopf_oscillator_stochastic #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,
    input  wire signed [WIDTH-1:0] mu_dt,
    input  wire signed [WIDTH-1:0] omega_dt,
    input  wire signed [WIDTH-1:0] input_x,
    input  wire signed [WIDTH-1:0] noise_x,    // NEW: stochastic noise input
    output reg  signed [WIDTH-1:0] x,
    output reg  signed [WIDTH-1:0] y,
    output reg  signed [WIDTH-1:0] amplitude
);

localparam signed [WIDTH-1:0] DT = 18'sd4;  // dt=0.00025 for 4 kHz update rate
localparam signed [WIDTH-1:0] R_SQ_TARGET = 18'sd16384;
localparam signed [WIDTH-1:0] R_SQ_THRESHOLD = 18'sd17408;
localparam signed [WIDTH-1:0] HALF = 18'sd8192;

// Fast startup initial condition
localparam signed [WIDTH-1:0] INIT_X = 18'sd8192;  // 0.5
localparam signed [WIDTH-1:0] INIT_Y = 18'sd0;

wire signed [2*WIDTH-1:0] x_sq, y_sq, r_sq;
wire signed [WIDTH-1:0] r_sq_scaled;

wire signed [2*WIDTH-1:0] mu_dt_x, mu_dt_y;
wire signed [2*WIDTH-1:0] omega_dt_y, omega_dt_x;
wire signed [2*WIDTH-1:0] r_sq_x, r_sq_y;
wire signed [2*WIDTH-1:0] dt_r_sq_x, dt_r_sq_y;

wire signed [WIDTH-1:0] dx, dy;
wire signed [WIDTH-1:0] x_raw, y_raw;

wire over_threshold;
wire signed [WIDTH-1:0] two_target;
wire signed [WIDTH-1:0] raw_correction;
wire signed [WIDTH-1:0] correction_factor;
wire signed [WIDTH-1:0] correction;
wire signed [2*WIDTH-1:0] x_corrected_full, y_corrected_full;
wire signed [WIDTH-1:0] x_next, y_next;

assign x_sq = x * x;
assign y_sq = y * y;
assign r_sq = x_sq + y_sq;
assign r_sq_scaled = r_sq[FRAC +: WIDTH];

assign mu_dt_x = mu_dt * x;
assign mu_dt_y = mu_dt * y;
assign omega_dt_y = omega_dt * y;
assign omega_dt_x = omega_dt * x;

assign r_sq_x = r_sq_scaled * x;
assign r_sq_y = r_sq_scaled * y;
assign dt_r_sq_x = (r_sq_x[FRAC +: WIDTH]) * DT;
assign dt_r_sq_y = (r_sq_y[FRAC +: WIDTH]) * DT;

// MODIFIED: Add noise_x to the dx update equation
assign dx = ((mu_dt_x - omega_dt_y - dt_r_sq_x) >>> FRAC) + input_x + noise_x;
assign dy = ((mu_dt_y + omega_dt_x - dt_r_sq_y) >>> FRAC);

assign x_raw = x + dx;
assign y_raw = y + dy;

assign over_threshold = (r_sq_scaled > R_SQ_THRESHOLD);
assign two_target = R_SQ_TARGET <<< 1;
assign raw_correction = two_target - r_sq_scaled;

assign correction_factor = (raw_correction < HALF) ? HALF :
                           (raw_correction > R_SQ_TARGET) ? R_SQ_TARGET :
                           raw_correction;

assign correction = over_threshold ? correction_factor : R_SQ_TARGET;

assign x_corrected_full = x_raw * correction;
assign y_corrected_full = y_raw * correction;

assign x_next = x_corrected_full >>> FRAC;
assign y_next = y_corrected_full >>> FRAC;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        x <= INIT_X;
        y <= INIT_Y;
        amplitude <= 18'sd0;
    end else if (clk_en) begin
        x <= x_next;
        y <= y_next;
        amplitude <= (x_next[WIDTH-1] ? -x_next : x_next) +
                     (y_next[WIDTH-1] ? -y_next : y_next);
    end
end

endmodule
