/* This file is part of JT12.

 
    JT12 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT12 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT12.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 21-03-2019
*/

module jt08_adpcm_cnt(
    input             rst_n,
    input             clk,        // CPU clock
    input             cen,        // 666 kHz
    // pipeline channel
    input      [ 5:0] cur_ch,
    input      [ 5:0] en_ch,
    // Address writes from CPU
    input      [15:0] addr_in,
    input      [ 2:0] addr_ch,
    input             up_start,
    input             up_end,
    // Counter control
    input             aon,
    input             aoff,
    // ROM driver
    output     [19:0] addr_out,
    output     [ 3:0] bank,
    output            sel,
    output            roe_n,
    output            decon,
    output            clr,      // inform the decoder that a new section begins
    //
    output [15:0] start_top,
    output [15:0]   end_top
);

reg [13:0] addr1, addr2, addr3, addr4, addr5, addr6;
reg [12:0] start1, start2, start3, start4, start5, start6,
           end1,   end2,   end3,   end4,   end5,   end6;
reg on1, on2, on3, on4, on5, on6;
reg done1, done2, done3, done4, done5, done6;

reg roe_n1, decon1;

reg clr1, clr2, clr3, clr4, clr5, clr6;
reg skip1, skip2, skip3, skip4, skip5, skip6;
reg half1, half2, half3, half4, half5, half6;
reg gate1, gate2, gate3, gate4, gate5, gate6;

// All outputs from stage 1
assign addr_out = { 7'b0,addr1[13:1] };
assign sel      = addr1[0];
assign bank     = 'd0;
assign roe_n    = roe_n1;
assign clr      = clr1;
assign decon    = decon1;

// Two cycles early:  0            0             1            1             2            2             3            3             4            4             5            5
wire active5 = (en_ch[1] && cur_ch[4]) || (en_ch[2] && cur_ch[5]) || (en_ch[2] && cur_ch[0]) || (en_ch[3] && cur_ch[1]) || (en_ch[4] && cur_ch[2]) || (en_ch[5] && cur_ch[3]);//{ cur_ch[3:0], cur_ch[5:4] } == en_ch;
wire sumup5  = on5 && !done5 && active5;
reg  sumup6;


`ifdef SIMULATION
wire [12:0] addr1_cmp = addr1[13:1];
`endif

assign start_top = {3'b0, start1};
assign   end_top =   {3'b0, end1};


always @(posedge clk or negedge rst_n) 
	// configure ADPCM percussion sounds; these are present in an embedded ROM
	//m_adpcm_a.set_start_end(0, 0x0000, 0x01bf); // bass drum
	//m_adpcm_a.set_start_end(1, 0x01c0, 0x043f); // snare drum
	//m_adpcm_a.set_start_end(2, 0x0440, 0x1b7f); // top cymbal
	//m_adpcm_a.set_start_end(3, 0x1b80, 0x1cff); // high hat
	//m_adpcm_a.set_start_end(4, 0x1d00, 0x1f7f); // tom tom
	//m_adpcm_a.set_start_end(5, 0x1f80, 0x1fff); // rim shot
    if( !rst_n ) begin
        addr1  <= 'd0;    addr2 <= 'd0;    addr3 <= 'd0;
        addr4  <= 'd0;    addr5 <= 'd0;    addr6 <= 'd0;
        done1  <= 'd1;    done2 <= 'd1;    done3 <= 'd1;
        done4  <= 'd1;    done5 <= 'd1;    done6 <= 'd1;
        skip1  <= 'd0;    skip2 <= 'd0;    skip3 <= 'd0;
        skip4  <= 'd0;    skip5 <= 'd0;    skip6 <= 'd0;
        gate1  <= 'd1;    gate2 <= 'd1;    gate3 <= 'd1;
        gate4  <= 'd1;    gate5 <= 'd1;    gate6 <= 'd1;
        on1    <= 'd0;    on2   <= 'd0;    on3   <= 'd0;
        on4    <= 'd0;    on5   <= 'd0;    on6   <= 'd0;
        clr1   <= 'd0;    clr2  <= 'd0;    clr3  <= 'd0;
        clr4   <= 'd0;    clr2  <= 'd0;    clr6  <= 'd0;
        roe_n1 <= 'd1;    decon1<= 'd0;    sumup6<= 'd0;
        start1 <= 'h0000; end1  <= 'h01BF; half1 <= 'd0;  // bass drum
        start6 <= 'h01C0; end6  <= 'h043F; half6 <= 'd0;  // snare drum
        start5 <= 'h0440; end5  <= 'h1B7F; half5 <= 'd0;  // top cymbal
        start4 <= 'h1B80; end4  <= 'h1CFF; half4 <= 'd0;  // hi hat
        start3 <= 'h1D00; end3  <= 'h1F7F; half3 <= 'd1;  // tom tom
        start2 <= 'h1F80; end2  <= 'h1FFF; half2 <= 'd1;  // rim shot
    end else if( cen ) begin
        addr2  <= addr1;
        on2    <= aoff ? 1'b0 : (aon | (on1 && ~done1));
        clr2   <= aoff || aon || done1; // Each time a A-ON is sent the address counter restarts
        done2  <= done1;
        start2 <= start1;
        end2   <= end1;
//      bank2  <= bank1;
        skip2  <= skip1;
        gate2  <= gate1;
        half2  <= half1;

        addr3  <= addr2; // clr2 ? {start2,9'd0} : addr2;
        on3    <= on2;
        clr3   <= clr2;
        done3  <= done2;
        start3 <= start2;
        end3   <= end2;
//      bank3  <= bank2;
        skip3  <= skip2;
        gate3  <= gate2;
        half3  <= half2;

        addr4  <= addr3;
        on4    <= on3;
        clr4   <= clr3;
        done4  <= done3;
        start4 <= start3;
        end4   <= end3;
//      bank4  <= bank3;
        skip4  <= skip3;
        gate4  <= gate3;
        half4  <= half3;

        addr5  <= addr4;
        on5    <= on4;
        clr5   <= clr4;
        done5  <= ~on4 ? done4 : (addr4[13:1] == end4 && addr4[0]==1'b1 && ~clr4);
        start5 <= start4;
        end5   <= end4;
//      bank5  <= bank4;
        skip5  <= skip4;
        gate5  <= gate4;
        half5  <= half4;
        // V
        addr6  <= addr5;
        on6    <= on5;
        clr6   <= clr5;
        done6  <= done5;
        start6 <= start5;
        end6   <= end5;
//      bank6  <= bank5;
        sumup6 <= sumup5 & gate5;
        skip6  <= skip5;
        gate6  <= ~half5 ? 1'b1 : (sumup5 && ~skip5) ? ~gate5 : gate5;
        half6  <= half5;

        addr1  <= (clr6 && on6) ? {start6,1'b0} : (sumup6 && ~skip6 ? addr6+14'd1 :addr6);
        on1    <= on6;
        done1  <= done6;
        start1 <= start6;
        end1   <= end6;
        roe_n1 <= ~sumup6;
        decon1 <= sumup6;
//      bank1  <= bank6;
        clr1   <= clr6;
        skip1  <= (clr6 && on6) ? 1'b1 : sumup6 ? 1'b0 : skip6;
        gate1  <= (clr6 && on6) ? 1'b1 : gate6;
        half1  <= half6;
    end

endmodule // jt08_adpcm_cnt
