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

module jt12_dout(
    // input             rst_n,
    input             clk,        // CPU clock
    input             flag_A,
    input             flag_B,
    input             busy,
    input             sel_chipid,
    input      [5:0]  adpcma_flags,
    input             adpcmb_flag,
    input      [3:0]  adpcmb_flag2,
    input      [7:0]  dout_b,
    input      [7:0]  psg_dout,
    input      [7:0]  ssg_sel,
    input             id_sel,
    input      [7:0]  last_din,
    input      [1:0]  addr,
    output reg [7:0]  dout
);

parameter use_ssg=0, use_adpcm=0, use_chipid=0;
parameter read_bus=0; // 1: bits a register does not drive read as the last byte written to the chip (YM2203, YM2608)

reg [7:0] psg_used; // bits driven by SSG register ssg_sel[3:0]
always @(*)
    case( ssg_sel[3:0] )
        4'h1,4'h3,4'h5,4'hd: psg_used = 8'h0f;
        4'h6,4'h8,4'h9,4'ha: psg_used = 8'h1f;
        default:             psg_used = 8'hff;
    endcase

wire [7:0] bus_dout = (use_chipid==1 && id_sel) ? 8'h1 :
                      (use_ssg==1 && ssg_sel[7:4]==4'd0) ? psg_dout | (last_din & ~psg_used) : last_din;

always @(posedge clk) begin
    casez( addr )
        2'b00: dout <= {busy, 5'd0, flag_B, flag_A }; // YM2203
        2'b01: dout <= (read_bus==1) ? bus_dout :
            (use_chipid==0) ? 
            {(use_ssg==1) ? psg_dout : {busy, 5'd0, flag_B, flag_A }} :
            {(sel_chipid==1'b1)? 8'h1 : psg_dout};
        2'b10: dout <= (use_adpcm==1) ?
            { adpcmb_flag, 1'b0, adpcma_flags } :
            { busy, 1'd0, adpcmb_flag2, flag_B, flag_A };
        2'b11: dout <= (use_adpcm==1) ?
            { adpcmb_flag, 1'b0, adpcma_flags } :
            { dout_b };   // read from ADPCM-B
    endcase
end

endmodule // jt12_dout