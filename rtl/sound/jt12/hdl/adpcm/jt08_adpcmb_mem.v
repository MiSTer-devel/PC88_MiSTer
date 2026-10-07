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

// ADPCM-B memory control

module jt08_adpcmb_mem(
    input               rst_n,
    input               clr,
    input               clk,    // CPU clock
    input               cen,    // 8MHz cen

    input               ram_mode,
    input               ram_read,
    input               ram_write,
    input               ram_wait,   // external memory has not finished the access yet

    output  reg         ram_busy,
    output  reg         ram_stb,

    output  reg         ram_oe_n,
    output  reg         ram_wr_n
);

// state
localparam  STATE_IDLE  = 'd0,
            STATE_WAIT  = 'd1,
            STATE_POST  = 'd2,
            STATE_END   = 'd3;

// wait
//localparam  RDWAIT  = 3;
localparam  RDWAIT  = 4;    // for PC88_MiSTer (add 1 wait due to memory access conflict with FDD)
localparam  WRWAIT  = 2;

reg   [1:0] state;
reg [RDWAIT:0] waits;       // indicate wait cycle for RAM read


always @(posedge clk) begin
    if ((rst_n == 1'b0) || (clr)) begin
        state       <= STATE_IDLE;
        ram_busy    <= 1'b0;
        ram_stb     <= 1'b0;
        ram_wr_n    <= 1'b1;
        ram_oe_n    <= 1'b1;
        waits       <= {RDWAIT+1{1'b0}};
    end else if (cen) begin
        if (ram_mode) begin
            // ram access mode
            casez (state)
                STATE_IDLE: begin
                    if (ram_write) begin
                        state   <= STATE_WAIT;
                        ram_busy<= 1'b1;
                        ram_stb <= 1'b0;
                        ram_oe_n<= 1'b1;
                        ram_wr_n<= 1'b0;
                        waits   <= {{RDWAIT+1{1'b1}}, {WRWAIT{1'b0}}};
                    end else if (ram_read) begin
                        state   <= STATE_WAIT;
                        ram_busy<= 1'b1;
                        ram_stb <= 1'b0;
                        ram_oe_n<= 1'b0;
                        ram_wr_n<= 1'b1;
                        waits   <= {1'b1, {RDWAIT{1'b0}}};
                    end else begin
                        ram_busy    <= 1'b0;
                        ram_stb     <= 1'b0;
                        ram_oe_n    <= 1'b1;
                        ram_wr_n    <= 1'b1;
                    end
                end
                STATE_WAIT: begin
                    // external memory with wait
                    ram_busy    <= 1'b1;
                    ram_stb     <= 1'b0;
                    waits       <= {1'b1, waits[RDWAIT:1]};
                    if (waits[0] && !ram_wait) begin
                        state   <= STATE_POST;
                    end else begin
                        state   <= STATE_WAIT;
                    end
                end
                STATE_POST: begin
                    state  <= STATE_END;
                    ram_busy    <= 1'b1;
                    ram_stb     <= 1'b1;
                    ram_oe_n    <= 1'b1;
                    ram_wr_n    <= 1'b1;
                end
                STATE_END: begin
                    state  <= STATE_IDLE;
                    ram_busy    <= 1'b0;
                    ram_stb     <= 1'b0;
                    ram_oe_n    <= 1'b1;
                    ram_wr_n    <= 1'b1;
                end
                default: state  <= STATE_IDLE;
            endcase
        end else begin
            // cpu memory mode
            state       <= STATE_IDLE;
            ram_busy    <= 1'b0;
            ram_stb     <= 1'b0;
            ram_wr_n    <= 1'b1;
            ram_oe_n    <= 1'b1;
        end
    end
end

endmodule // jt08_adpcmb_mem
