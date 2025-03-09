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

// d = a/(2^1)*b[DW-1] + a/(2^2)*b[DW-2] + ... + a/(2^DW)*b[0] ;

module jt08_adpcm_rmul #(parameter DW=16)(
    input               rst_n,
    input               clk,    // CPU clock
    input               cen,
    input               start,  // strobe
    input      [DW-1:0] a,
    input      [DW-1:0] b,
    output reg [DW-1:0] d,
    output              working
);

reg [DW-1:0] sfta, sftb;

assign working = |sfta;

always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        sfta <= 'd0;
        sftb <= 'd0;
        d <= 'd0;
    end else if(cen) begin
        if(start) begin
            sfta    <= {1'b0, a[DW-1:1]};
            sftb    <= b;
            d       <= 'd0;
        end else if(working) begin
            if (sftb[DW-1]) begin
                d <= d + sfta;
            end
            sfta <= {1'b0, sfta[DW-1:1]};
            sftb <= {sftb[DW-2:0], 1'b0};
        end
    end

endmodule // jt08_adpcm_rmul
