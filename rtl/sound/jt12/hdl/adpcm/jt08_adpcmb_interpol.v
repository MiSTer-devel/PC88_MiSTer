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

module jt08_adpcmb_interpol(
    input           rst_n,
    input           clk,
    input           cen,      // 8MHz cen
    input           cen55,    // clk & cen55  =  55 kHz
    input           adv,
    input [15:0]    deltan,
    input           dsign,
    input [15:0]    deltax,
    input  signed [15:0] pcmdec,
    output signed [15:0] pcmout
);

localparam stages=6;

reg signed [15:0] pcmlast;
reg start_div=1'b0;
reg [stages-1:0] adv2;

reg signed [16:0] preout;
reg signed [16:0] step;
reg step_sign;
wire [16:0] ustep, pcminter;

wire [16:0] limpos = { {2{1'b0}}, {15{1'b1}} };
wire [16:0] limneg = { {2{1'b1}}, {15{1'b0}} };

always @(posedge clk) if(cen) begin
    adv2 <= {adv2[stages-2:0], cen55 & adv }; // give some time to get the data from memory
end

always @(posedge clk) if(cen) begin
    start_div <= 1'b0;
    if(adv2[1]) begin
        pcmlast     <= pcmdec;
    end
    if(adv2[2]) begin
        start_div   <= 1'b1;
    end
end

assign pcminter = step_sign ? preout - step : preout + step;
assign pcmout = preout[15:0];

always @(posedge clk) begin
    if(!rst_n) begin
        preout      <= 'd0;
        step        <= 'd0;
        step_sign   <= 'd0;
    end
    if(cen55) begin
        if(adv) begin
            step        <= ustep;
            step_sign   <= dsign;
            preout      <= {pcmlast[15], pcmlast};
        end else begin
            if(pcminter[16] ^ pcminter[15])
                preout  <= step_sign ? limneg : limpos;
            else
                preout  <= pcminter;
        end
    end
end

jt08_adpcm_rmul #(.DW(16)) u_div(
    .rst_n  ( rst_n       ),
    .clk    ( clk         ),
    .cen    ( cen         ),
    .start  ( start_div   ),
    .a      ( deltax      ),
    .b      ( deltan      ),
    .d      ( ustep[15:0] ),
    .working(             )
);
assign ustep[16] = 1'b0;

endmodule // jt08_adpcmb_interpol