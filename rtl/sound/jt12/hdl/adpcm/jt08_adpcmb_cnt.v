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
    input               acmd_mem_b,
    input               acmd_rec_b,
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
reg [1:0] end_hold;
reg eos_wait;
// CPU read form: START=0, MEMDATA=1, REC=0
wire cpu_rd = ~on & acmd_mem_b & ~acmd_rec_b;

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
        end_hold   <= 'd0;
        eos_wait   <= 'd0;
    end else if (cen) begin
        if (!on || clr) begin
            restart  <= 'd0;
            set_flag <= 'd0;
            chon     <= 'd0;
		    clr_dec  <= 'd1;
            eos_wait <= 'd0;
        end else if (acmd_up_b && on) begin
            addr <= astart;
            nibble_sel <= 1'b0;
            restart <= 'd1;
            eos_wait <= 'd0;
        end
        if (!on && acmd_ad_b) begin
            addr <= astart;
            nibble_sel <= 1'b0;
            end_hold <= 'd0;
        end
        if (restart[1]) begin
            chon <= 'd1;
            clr_dec <= 'd0;
        end
        if (acmd_up_b || clr)
            end_hold <= 'd0;
        if (cen55 && chon && adv) begin
            nibble_sel <= ~nibble_sel;
        end
        // prepare next address
        // CPU read form (START=0): the end address is fetched twice more
        // (once more with repeat) before going back to the start, as on a PC-8801MA
        if (ram_stb && cpu_rd && addr == aend) begin
            set_flag <= 'd1;
            if (end_hold == (arepeat ? 2'd1 : 2'd2)) begin
                addr <= astart;
                end_hold <= 'd0;
            end else
                end_hold <= end_hold + 2'd1;
        end else if (ram_stb) begin
            end_hold <= 'd0;
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
                if (on && !acmd_rec_b && !acmd_up_b && !clr) eos_wait <= 'd1; else set_flag <= 'd1;
                restart <= 'd1;
                clr_dec <= 'd1;
            end else begin
                if (on && !acmd_rec_b && !acmd_up_b && !clr) eos_wait <= 'd1; else set_flag <= 'd1;
                chon <= 'd0;
                clr_dec <= 'd1;
            end
        end
        // playback (START=1, REC=0): EOS one sample after the end address is fetched,
        // as on a PC-8801MA; the end of a CPU write or of a record pass stays immediate
        if (cen55 && adv && eos_wait && on && !clr && !acmd_up_b) begin
            set_flag <= 'd1;
            eos_wait <= 'd0;
        end
    end // cen

reg pre_wr, pre_rd;
reg reg_write, reg_read;

// detect register access
// with START=0, as measured on a PC-8801MA: a write in the read form is
// taken as a read when it ends, and a read moves the latch only in the read form
wire stb_rd_any = stb_rd | (stb_wr & cpu_rd);

always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        reg_write   <= 1'b0;
        reg_read    <= 1'b0;
        pre_wr      <= 1'b0;
        pre_rd      <= 1'b0;
    end else if (cen) begin
        pre_wr      <= stb_wr;
        pre_rd      <= stb_rd_any;
        if (!pre_wr & stb_wr) begin
            reg_write   <= acmd_rec_b;
            reg_read    <= 1'b0;
        end else if (pre_rd & !stb_rd_any) begin
            reg_write   <= 1'b0;
            reg_read    <= on | acmd_mem_b;
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
        if ((reg_read && (on | ~acmd_rec_b)) || (cen55 && chon && adv && nibble_sel) || (ram_stb && restart[0])) begin
            forward <= 1'b1;
        end else begin
            forward <= 1'b0;
        end
    end

        // register write
assign  ram_write = reg_write;


endmodule // jt08_adpcmb_cnt
