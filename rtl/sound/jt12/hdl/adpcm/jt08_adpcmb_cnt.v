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

// ADPCM-B counter

module jt08_adpcmb_cnt(
    input               rst_n,
    input               clk,    // CPU clock
    input               cen,    // 8MHz cen
    input               cen55,  // clk & cen55 = 55 kHz

    // counter control
    input       [15:0]  delta_n,
    input               clr,
    input               on,
    input               acmd_up_b,
    // Address
    input       [20:0]  astart,
    input       [20:0]  aend,
    input               arepeat,
    input       [20:0]  alimit,
    output  reg [20:0]  addr,
    output  reg         nibble_sel,
    // Flag
    output  reg         chon,
    output  reg         flag,
    input               clr_flag,
    output  reg         clr_dec,
    // memory
    input               acmd_ad_b,
    input               stb_rd,
    input               stb_wr,
    input               ram_busy,
    input               ram_stb,
    output              ram_write,
    output  reg         ram_read,

    output  reg         forward,
    output  reg         adv
);

// Counter
reg [15:0] cnt;

always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        cnt <= 'd0;
        adv <= 'b0;
    end else if(cen55) begin
        if( clr) begin
            cnt <= 'd0;
            adv <= 'b0;
        end else begin
            if( on ) 
                {adv, cnt} <= {1'b0, cnt} + {1'b0, delta_n};
            else begin
                cnt <= 'd0;
                adv <= 1'b1; // let the rest of the signal chain advance
                    // when channel is off so all registers go to reset values
            end
        end
    end

reg set_flag, last_set;
reg [1:0] restart;

always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        flag     <= 1'b0;
        last_set <= 'b0;
    end else begin
        last_set <= set_flag;
        if( clr_flag ) flag <= 1'b0;
        if( !last_set && set_flag ) flag <= 1'b1;
    end

// Address
always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        addr       <= 'd0;
        nibble_sel <= 'b0;
        set_flag   <= 'd0;
        chon       <= 'b0;
        restart    <= 'd0;
		clr_dec    <= 'b1;
    end else if (cen) begin
        if (!on || clr) begin
            restart  <= 'd0;
            set_flag <= 'd0;
            chon     <= 'd0;
		    clr_dec  <= 'd1;
        end else if (acmd_up_b && on) begin
            addr <= astart;
            nibble_sel <= 1'b0;
            restart <= 'd1;
        end
        if (!on && acmd_ad_b) begin
            addr <= astart;
            nibble_sel <= 1'b0;
        end
        if (restart[1]) begin
            chon <= 'd1;
            clr_dec <= 'd0;
        end
        if (cen55 && chon && adv) begin
            nibble_sel <= ~nibble_sel;
        end
        // prepare next address
        if (ram_stb) begin
            if (addr != aend) begin
                if (addr == alimit) begin
                    addr <= 21'd0;
                end else begin
                    addr <= addr + 21'd1;
                end
                restart <= {restart[0],1'b0};
                set_flag <= 'd0;
            end else if(arepeat) begin
                addr <= astart;
                nibble_sel <= 1'b0;
                set_flag <= 'd1;
                restart <= 'd1;
                clr_dec <= 'd1;
            end else begin
                set_flag <= 'd1;
                chon <= 'd0;
                clr_dec <= 'd1;
            end
        end
    end // cen

reg pre_wr, pre_rd;
reg reg_write, reg_read;

// detect register access
always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        reg_write   <= 1'b0;
        reg_read    <= 1'b0;
        pre_wr      <= 1'b0;
        pre_rd      <= 1'b0;
    end else if (cen) begin
        pre_wr      <= stb_wr;
        pre_rd      <= stb_rd;
        if (!pre_wr & stb_wr) begin
            reg_write   <= 1'b1;
            reg_read    <= 1'b0;
        end else if (pre_rd & !stb_rd) begin
            reg_write   <= 1'b0;
            reg_read    <= 1'b1;
        end else begin
            reg_write   <= 1'b0;
            reg_read    <= 1'b0;
        end
    end // cen

// ram access, pipeline
always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        ram_read    <= 1'b0;
        forward    <= 'b0;
    end else if (cen) begin
        // register read or fill pipeline
        if (reg_read || (cen55 && chon && adv && !nibble_sel) || (!ram_busy && restart[0])) begin
            ram_read <= 1'b1;
        end else begin
            ram_read <= 1'b0;
        end
        if (reg_read || (cen55 && chon && adv && nibble_sel) || (ram_stb && restart[0])) begin
            forward <= 1'b1;
        end else begin
            forward <= 1'b0;
        end
    end

        // register write
assign  ram_write = reg_write;


endmodule // jt08_adpcmb_cnt
