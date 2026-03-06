/*  This file is part of JT49.

    JT49 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT49 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT49.  If not, see <http://www.gnu.org/licenses/>.
    
    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 10-Nov-2018
    
    Based on sqmusic, by the same author
    
    */

// Compression vs dynamic range
// 0 -> 43.6dB
// 1 -> 29.1
// 2 -> 21.8
// 3 -> 13.4

module jt49_exp(
    input            clk,
    input      [2:0] comp,  // compression
    input      [4:0] din,
    output reg [9:0] dout 
);

reg [9:0] lut[0:159];

always @(posedge clk)
    dout <= lut[ {comp,din} ];

initial begin
    lut[0] = 10'd0;
    lut[1] = 10'd0;
    lut[2] = 10'd6;
    lut[3] = 10'd7;
    lut[4] = 10'd9;
    lut[5] = 10'd11;
    lut[6] = 10'd13;
    lut[7] = 10'd15;
    lut[8] = 10'd19;
    lut[9] = 10'd22;
    lut[10] = 10'd26;
    lut[11] = 10'd31;
    lut[12] = 10'd38;
    lut[13] = 10'd45;
    lut[14] = 10'd53;
    lut[15] = 10'd63;
    lut[16] = 10'd76;
    lut[17] = 10'd90;
    lut[18] = 10'd107;
    lut[19] = 10'd127;
    lut[20] = 10'd152;
    lut[21] = 10'd180;
    lut[22] = 10'd215;
    lut[23] = 10'd255;
    lut[24] = 10'd304;
    lut[25] = 10'd361;
    lut[26] = 10'd430;
    lut[27] = 10'd511;
    lut[28] = 10'd608;
    lut[29] = 10'd723;
    lut[30] = 10'd860;
    lut[31] = 10'd1023;
    lut[32] = 10'd0;
    lut[33] = 10'd0;
    lut[34] = 10'd35;
    lut[35] = 10'd40;
    lut[36] = 10'd45;
    lut[37] = 10'd50;
    lut[38] = 10'd56;
    lut[39] = 10'd63;
    lut[40] = 10'd71;
    lut[41] = 10'd80;
    lut[42] = 10'd90;
    lut[43] = 10'd101;
    lut[44] = 10'd113;
    lut[45] = 10'd127;
    lut[46] = 10'd143;
    lut[47] = 10'd161;
    lut[48] = 10'd180;
    lut[49] = 10'd202;
    lut[50] = 10'd227;
    lut[51] = 10'd255;
    lut[52] = 10'd287;
    lut[53] = 10'd322;
    lut[54] = 10'd361;
    lut[55] = 10'd405;
    lut[56] = 10'd455;
    lut[57] = 10'd511;
    lut[58] = 10'd574;
    lut[59] = 10'd644;
    lut[60] = 10'd723;
    lut[61] = 10'd811;
    lut[62] = 10'd911;
    lut[63] = 10'd1023;
    lut[64] = 10'd0;
    lut[65] = 10'd0;
    lut[66] = 10'd82;
    lut[67] = 10'd90;
    lut[68] = 10'd98;
    lut[69] = 10'd107;
    lut[70] = 10'd117;
    lut[71] = 10'd127;
    lut[72] = 10'd139;
    lut[73] = 10'd152;
    lut[74] = 10'd165;
    lut[75] = 10'd180;
    lut[76] = 10'd197;
    lut[77] = 10'd215;
    lut[78] = 10'd234;
    lut[79] = 10'd255;
    lut[80] = 10'd278;
    lut[81] = 10'd304;
    lut[82] = 10'd331;
    lut[83] = 10'd361;
    lut[84] = 10'd394;
    lut[85] = 10'd430;
    lut[86] = 10'd469;
    lut[87] = 10'd511;
    lut[88] = 10'd557;
    lut[89] = 10'd608;
    lut[90] = 10'd663;
    lut[91] = 10'd723;
    lut[92] = 10'd788;
    lut[93] = 10'd860;
    lut[94] = 10'd938;
    lut[95] = 10'd1023;
    lut[96] = 10'd0;
    lut[97] = 10'd0;
    lut[98] = 10'd217;
    lut[99] = 10'd229;
    lut[100] = 10'd242;
    lut[101] = 10'd255;
    lut[102] = 10'd269;
    lut[103] = 10'd284;
    lut[104] = 10'd300;
    lut[105] = 10'd316;
    lut[106] = 10'd333;
    lut[107] = 10'd352;
    lut[108] = 10'd371;
    lut[109] = 10'd391;
    lut[110] = 10'd413;
    lut[111] = 10'd435;
    lut[112] = 10'd459;
    lut[113] = 10'd484;
    lut[114] = 10'd511;
    lut[115] = 10'd539;
    lut[116] = 10'd569;
    lut[117] = 10'd600;
    lut[118] = 10'd633;
    lut[119] = 10'd667;
    lut[120] = 10'd704;
    lut[121] = 10'd742;
    lut[122] = 10'd783;
    lut[123] = 10'd826;
    lut[124] = 10'd871;
    lut[125] = 10'd919;
    lut[126] = 10'd969;
    lut[127] = 10'd1023;
    lut[128] = 10'd0;
    lut[129] = 10'd8;
    lut[130] = 10'd10;
    lut[131] = 10'd12;
    lut[132] = 10'd16;
    lut[133] = 10'd22;
    lut[134] = 10'd29;
    lut[135] = 10'd35;
    lut[136] = 10'd44;
    lut[137] = 10'd50;
    lut[138] = 10'd56;
    lut[139] = 10'd60;
    lut[140] = 10'd64;
    lut[141] = 10'd85;
    lut[142] = 10'd97;
    lut[143] = 10'd103;
    lut[144] = 10'd108;
    lut[145] = 10'd120;
    lut[146] = 10'd127;
    lut[147] = 10'd134;
    lut[148] = 10'd141;
    lut[149] = 10'd149;
    lut[150] = 10'd157;
    lut[151] = 10'd166;
    lut[152] = 10'd175;
    lut[153] = 10'd185;
    lut[154] = 10'd195;
    lut[155] = 10'd206;
    lut[156] = 10'd217;
    lut[157] = 10'd229;
    lut[158] = 10'd241;
    lut[159] = 10'd255;

end
endmodule
