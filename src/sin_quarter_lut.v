//=============================================================================
// Quarter-Wave Sine LUT - v11.0
//
// Efficient sine lookup table using quarter-wave symmetry.
// Stores only 256 entries covering [0, π/2] and reconstructs full sine
// using symmetry properties:
//   sin(x)        = +sin(x)           for x in [0, π/2]
//   sin(π - x)    = +sin(x)           for x in [π/2, π]
//   sin(x)        = -sin(x - π)       for x in [π, 2π]
//
// Input: 10-bit phase (0-1023 representing 0 to 2π)
// Output: 18-bit signed Q14 sine value in range [-16384, +16384]
//
// Used by energy_landscape.v for force computation: F = -2πA × sin(2πn)
//
// v11.0: Initial implementation with 256-entry quarter-wave LUT
//=============================================================================
`timescale 1ns / 1ps

module sin_quarter_lut #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter LUT_ADDR_WIDTH = 8  // 256 entries for quarter wave
)(
    input  wire clk,
    input  wire [9:0] phase,                // 10-bit phase: 0-1023 = 0 to 2π
    output reg  signed [WIDTH-1:0] sin_out  // Sine value in Q14
);

//-----------------------------------------------------------------------------
// Quarter-wave LUT (256 entries covering phase 0 to π/2)
// Values: sin(i × π/2 / 256) × 16384 for i = 0 to 255
//-----------------------------------------------------------------------------
reg signed [WIDTH-1:0] sin_lut [0:255];

// Integer for initialization loop
integer lut_i;

// Initialize LUT with precomputed quarter-wave sine values
// sin(i × π/512) × 16384 for i = 0 to 255
initial begin
    // These values are computed as: round(sin(i * π / 512) * 16384)
    // Quarter wave: i=0 gives sin(0)=0, i=255 gives sin(π/2 - δ) ≈ 1

    sin_lut[0]   = 18'sd0;
    sin_lut[1]   = 18'sd101;
    sin_lut[2]   = 18'sd201;
    sin_lut[3]   = 18'sd302;
    sin_lut[4]   = 18'sd402;
    sin_lut[5]   = 18'sd503;
    sin_lut[6]   = 18'sd603;
    sin_lut[7]   = 18'sd704;
    sin_lut[8]   = 18'sd804;
    sin_lut[9]   = 18'sd904;
    sin_lut[10]  = 18'sd1005;
    sin_lut[11]  = 18'sd1105;
    sin_lut[12]  = 18'sd1205;
    sin_lut[13]  = 18'sd1306;
    sin_lut[14]  = 18'sd1406;
    sin_lut[15]  = 18'sd1506;
    sin_lut[16]  = 18'sd1606;
    sin_lut[17]  = 18'sd1706;
    sin_lut[18]  = 18'sd1806;
    sin_lut[19]  = 18'sd1906;
    sin_lut[20]  = 18'sd2006;
    sin_lut[21]  = 18'sd2105;
    sin_lut[22]  = 18'sd2205;
    sin_lut[23]  = 18'sd2305;
    sin_lut[24]  = 18'sd2404;
    sin_lut[25]  = 18'sd2503;
    sin_lut[26]  = 18'sd2603;
    sin_lut[27]  = 18'sd2702;
    sin_lut[28]  = 18'sd2801;
    sin_lut[29]  = 18'sd2900;
    sin_lut[30]  = 18'sd2998;
    sin_lut[31]  = 18'sd3097;
    sin_lut[32]  = 18'sd3196;
    sin_lut[33]  = 18'sd3294;
    sin_lut[34]  = 18'sd3393;
    sin_lut[35]  = 18'sd3491;
    sin_lut[36]  = 18'sd3589;
    sin_lut[37]  = 18'sd3687;
    sin_lut[38]  = 18'sd3785;
    sin_lut[39]  = 18'sd3883;
    sin_lut[40]  = 18'sd3980;
    sin_lut[41]  = 18'sd4078;
    sin_lut[42]  = 18'sd4175;
    sin_lut[43]  = 18'sd4272;
    sin_lut[44]  = 18'sd4369;
    sin_lut[45]  = 18'sd4466;
    sin_lut[46]  = 18'sd4563;
    sin_lut[47]  = 18'sd4659;
    sin_lut[48]  = 18'sd4756;
    sin_lut[49]  = 18'sd4852;
    sin_lut[50]  = 18'sd4948;
    sin_lut[51]  = 18'sd5044;
    sin_lut[52]  = 18'sd5139;
    sin_lut[53]  = 18'sd5235;
    sin_lut[54]  = 18'sd5330;
    sin_lut[55]  = 18'sd5425;
    sin_lut[56]  = 18'sd5520;
    sin_lut[57]  = 18'sd5614;
    sin_lut[58]  = 18'sd5708;
    sin_lut[59]  = 18'sd5803;
    sin_lut[60]  = 18'sd5897;
    sin_lut[61]  = 18'sd5990;
    sin_lut[62]  = 18'sd6084;
    sin_lut[63]  = 18'sd6177;
    sin_lut[64]  = 18'sd6270;
    sin_lut[65]  = 18'sd6363;
    sin_lut[66]  = 18'sd6455;
    sin_lut[67]  = 18'sd6547;
    sin_lut[68]  = 18'sd6639;
    sin_lut[69]  = 18'sd6731;
    sin_lut[70]  = 18'sd6823;
    sin_lut[71]  = 18'sd6914;
    sin_lut[72]  = 18'sd7005;
    sin_lut[73]  = 18'sd7096;
    sin_lut[74]  = 18'sd7186;
    sin_lut[75]  = 18'sd7276;
    sin_lut[76]  = 18'sd7366;
    sin_lut[77]  = 18'sd7456;
    sin_lut[78]  = 18'sd7545;
    sin_lut[79]  = 18'sd7635;
    sin_lut[80]  = 18'sd7723;
    sin_lut[81]  = 18'sd7812;
    sin_lut[82]  = 18'sd7900;
    sin_lut[83]  = 18'sd7988;
    sin_lut[84]  = 18'sd8076;
    sin_lut[85]  = 18'sd8163;
    sin_lut[86]  = 18'sd8250;
    sin_lut[87]  = 18'sd8337;
    sin_lut[88]  = 18'sd8423;
    sin_lut[89]  = 18'sd8509;
    sin_lut[90]  = 18'sd8595;
    sin_lut[91]  = 18'sd8680;
    sin_lut[92]  = 18'sd8765;
    sin_lut[93]  = 18'sd8850;
    sin_lut[94]  = 18'sd8935;
    sin_lut[95]  = 18'sd9019;
    sin_lut[96]  = 18'sd9102;
    sin_lut[97]  = 18'sd9186;
    sin_lut[98]  = 18'sd9269;
    sin_lut[99]  = 18'sd9352;
    sin_lut[100] = 18'sd9434;
    sin_lut[101] = 18'sd9516;
    sin_lut[102] = 18'sd9598;
    sin_lut[103] = 18'sd9679;
    sin_lut[104] = 18'sd9760;
    sin_lut[105] = 18'sd9841;
    sin_lut[106] = 18'sd9921;
    sin_lut[107] = 18'sd10001;
    sin_lut[108] = 18'sd10080;
    sin_lut[109] = 18'sd10159;
    sin_lut[110] = 18'sd10238;
    sin_lut[111] = 18'sd10316;
    sin_lut[112] = 18'sd10394;
    sin_lut[113] = 18'sd10471;
    sin_lut[114] = 18'sd10549;
    sin_lut[115] = 18'sd10625;
    sin_lut[116] = 18'sd10702;
    sin_lut[117] = 18'sd10778;
    sin_lut[118] = 18'sd10853;
    sin_lut[119] = 18'sd10928;
    sin_lut[120] = 18'sd11003;
    sin_lut[121] = 18'sd11077;
    sin_lut[122] = 18'sd11151;
    sin_lut[123] = 18'sd11224;
    sin_lut[124] = 18'sd11297;
    sin_lut[125] = 18'sd11370;
    sin_lut[126] = 18'sd11442;
    sin_lut[127] = 18'sd11514;
    sin_lut[128] = 18'sd11585;
    sin_lut[129] = 18'sd11656;
    sin_lut[130] = 18'sd11727;
    sin_lut[131] = 18'sd11797;
    sin_lut[132] = 18'sd11866;
    sin_lut[133] = 18'sd11935;
    sin_lut[134] = 18'sd12004;
    sin_lut[135] = 18'sd12072;
    sin_lut[136] = 18'sd12140;
    sin_lut[137] = 18'sd12207;
    sin_lut[138] = 18'sd12274;
    sin_lut[139] = 18'sd12340;
    sin_lut[140] = 18'sd12406;
    sin_lut[141] = 18'sd12472;
    sin_lut[142] = 18'sd12537;
    sin_lut[143] = 18'sd12601;
    sin_lut[144] = 18'sd12665;
    sin_lut[145] = 18'sd12729;
    sin_lut[146] = 18'sd12792;
    sin_lut[147] = 18'sd12854;
    sin_lut[148] = 18'sd12916;
    sin_lut[149] = 18'sd12978;
    sin_lut[150] = 18'sd13039;
    sin_lut[151] = 18'sd13100;
    sin_lut[152] = 18'sd13160;
    sin_lut[153] = 18'sd13219;
    sin_lut[154] = 18'sd13279;
    sin_lut[155] = 18'sd13337;
    sin_lut[156] = 18'sd13395;
    sin_lut[157] = 18'sd13453;
    sin_lut[158] = 18'sd13510;
    sin_lut[159] = 18'sd13567;
    sin_lut[160] = 18'sd13623;
    sin_lut[161] = 18'sd13678;
    sin_lut[162] = 18'sd13733;
    sin_lut[163] = 18'sd13788;
    sin_lut[164] = 18'sd13842;
    sin_lut[165] = 18'sd13896;
    sin_lut[166] = 18'sd13949;
    sin_lut[167] = 18'sd14001;
    sin_lut[168] = 18'sd14053;
    sin_lut[169] = 18'sd14104;
    sin_lut[170] = 18'sd14155;
    sin_lut[171] = 18'sd14206;
    sin_lut[172] = 18'sd14256;
    sin_lut[173] = 18'sd14305;
    sin_lut[174] = 18'sd14354;
    sin_lut[175] = 18'sd14402;
    sin_lut[176] = 18'sd14449;
    sin_lut[177] = 18'sd14497;
    sin_lut[178] = 18'sd14543;
    sin_lut[179] = 18'sd14589;
    sin_lut[180] = 18'sd14635;
    sin_lut[181] = 18'sd14680;
    sin_lut[182] = 18'sd14724;
    sin_lut[183] = 18'sd14768;
    sin_lut[184] = 18'sd14811;
    sin_lut[185] = 18'sd14854;
    sin_lut[186] = 18'sd14896;
    sin_lut[187] = 18'sd14937;
    sin_lut[188] = 18'sd14978;
    sin_lut[189] = 18'sd15019;
    sin_lut[190] = 18'sd15059;
    sin_lut[191] = 18'sd15098;
    sin_lut[192] = 18'sd15137;
    sin_lut[193] = 18'sd15175;
    sin_lut[194] = 18'sd15212;
    sin_lut[195] = 18'sd15249;
    sin_lut[196] = 18'sd15286;
    sin_lut[197] = 18'sd15322;
    sin_lut[198] = 18'sd15357;
    sin_lut[199] = 18'sd15392;
    sin_lut[200] = 18'sd15426;
    sin_lut[201] = 18'sd15460;
    sin_lut[202] = 18'sd15493;
    sin_lut[203] = 18'sd15525;
    sin_lut[204] = 18'sd15557;
    sin_lut[205] = 18'sd15588;
    sin_lut[206] = 18'sd15619;
    sin_lut[207] = 18'sd15649;
    sin_lut[208] = 18'sd15679;
    sin_lut[209] = 18'sd15707;
    sin_lut[210] = 18'sd15736;
    sin_lut[211] = 18'sd15763;
    sin_lut[212] = 18'sd15791;
    sin_lut[213] = 18'sd15817;
    sin_lut[214] = 18'sd15843;
    sin_lut[215] = 18'sd15868;
    sin_lut[216] = 18'sd15893;
    sin_lut[217] = 18'sd15917;
    sin_lut[218] = 18'sd15941;
    sin_lut[219] = 18'sd15964;
    sin_lut[220] = 18'sd15986;
    sin_lut[221] = 18'sd16008;
    sin_lut[222] = 18'sd16029;
    sin_lut[223] = 18'sd16049;
    sin_lut[224] = 18'sd16069;
    sin_lut[225] = 18'sd16088;
    sin_lut[226] = 18'sd16107;
    sin_lut[227] = 18'sd16125;
    sin_lut[228] = 18'sd16143;
    sin_lut[229] = 18'sd16160;
    sin_lut[230] = 18'sd16176;
    sin_lut[231] = 18'sd16192;
    sin_lut[232] = 18'sd16207;
    sin_lut[233] = 18'sd16221;
    sin_lut[234] = 18'sd16235;
    sin_lut[235] = 18'sd16248;
    sin_lut[236] = 18'sd16261;
    sin_lut[237] = 18'sd16273;
    sin_lut[238] = 18'sd16284;
    sin_lut[239] = 18'sd16295;
    sin_lut[240] = 18'sd16305;
    sin_lut[241] = 18'sd16315;
    sin_lut[242] = 18'sd16324;
    sin_lut[243] = 18'sd16332;
    sin_lut[244] = 18'sd16340;
    sin_lut[245] = 18'sd16347;
    sin_lut[246] = 18'sd16353;
    sin_lut[247] = 18'sd16359;
    sin_lut[248] = 18'sd16364;
    sin_lut[249] = 18'sd16369;
    sin_lut[250] = 18'sd16373;
    sin_lut[251] = 18'sd16376;
    sin_lut[252] = 18'sd16379;
    sin_lut[253] = 18'sd16381;
    sin_lut[254] = 18'sd16383;
    sin_lut[255] = 18'sd16384;  // sin(π/2) = 1.0
end

//-----------------------------------------------------------------------------
// Quarter-wave reconstruction logic
//
// 10-bit phase maps to full circle:
//   phase[9:8] selects quadrant (0-3)
//   phase[7:0] is index within quadrant
//
// Quadrant 0 (0 to π/2):     sin(θ) = +LUT[index]
// Quadrant 1 (π/2 to π):     sin(θ) = +LUT[255 - index]
// Quadrant 2 (π to 3π/2):    sin(θ) = -LUT[index]
// Quadrant 3 (3π/2 to 2π):   sin(θ) = -LUT[255 - index]
//-----------------------------------------------------------------------------

wire [1:0] quadrant = phase[9:8];
wire [7:0] index = phase[7:0];
wire [7:0] lut_addr;
wire sign_neg;

// Determine LUT address and sign based on quadrant
assign lut_addr = (quadrant == 2'b00 || quadrant == 2'b10) ? index : (8'd255 - index);
assign sign_neg = (quadrant == 2'b10 || quadrant == 2'b11);

// Registered output for timing
// Need to delay sign_neg to match lut_value pipeline
reg signed [WIDTH-1:0] lut_value;
reg sign_neg_d1;  // Delayed sign for proper alignment

always @(posedge clk) begin
    // Pipeline stage 1: read LUT and delay sign
    lut_value <= sin_lut[lut_addr];
    sign_neg_d1 <= sign_neg;

    // Pipeline stage 2: apply sign to value (both now aligned)
    sin_out <= sign_neg_d1 ? -lut_value : lut_value;
end

endmodule
