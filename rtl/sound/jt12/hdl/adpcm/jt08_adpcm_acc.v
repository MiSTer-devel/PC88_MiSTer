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
// same as jt10_adpcm_acc, except no linear interpolation

// Adds all 6 channels
// sampling frequency to 55.5 kHz

module jt08_adpcm_acc(
    input           rst_n,
    input           clk,        // CPU clock
    input           cen,        // 111 kHz
    // pipeline channel
    input   [5:0]   cur_ch,
    input   [5:0]   en_ch,
    input           match,

    input           en_sum,
    input  signed [15:0] pcm_in,    // 18.5 kHz
    output reg signed [15:0] pcm_out    // 55.5 kHz
);

wire signed [17:0] pcm_in_long = en_sum ? { {2{pcm_in[15]}}, pcm_in } : 18'd0;
reg  signed [17:0] acc, pcm_full;


always @(posedge clk or negedge rst_n)
    if( !rst_n ) begin
        acc  <= 18'd0;
    end else if(cen) begin
        if( match )
            acc <= cur_ch[0] ? pcm_in_long : ( pcm_in_long + acc );
        if(en_ch[0] && cur_ch[0])
            pcm_out <= !overflow ? acc[15:0] : acc[17] ? 16'h8000 : 16'h7fff; // saturate
    end
wire overflow = |acc[17:15] & ~&acc[17:15];

endmodule // jt10_adpcm_acc