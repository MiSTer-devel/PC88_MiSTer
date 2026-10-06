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

module jt08_adpcm_drvB(
    input           rst_n,
    input           clk,
    input           cen,      // 8MHz cen
    input           cen55,    // clk & cen55  =  55 kHz
    // Control
    input           acmd_on_b,  // Control - Process start, Key On
    input           acmd_rep_b, // Control - Repeat
    input           acmd_rst_b, // Control - Reset
    input           acmd_up_b,  // Control - New command received
    input           acmd_ad_b,  // Control - Address set
    input           acmd_mem_b, // Control - Access external RAM
    input           acmd_rec_b, // Control - Record
    input           acmd_x8_b,  // Control - Address granularity is 8b
    input           acmd_rom_b, // Control - External memory is ROM
    input    [ 1:0] alr_b,      // Left / Right
    input    [15:0] astart_b,   // Start address
    input    [15:0] aend_b,     // End   address
    input    [15:0] adeltan_b,  // Delta-N
    input    [ 7:0] aeg_b,      // Envelope Generator Control
    input    [15:0] alimit_b,   // Limit address
    output reg [ 3:0] flag,
    input      [ 2:0] mask,
    input      [ 3:0] clr_flag,
    // memory
    output     [23:0] addr,
    input      [ 7:0] ram_din,
    output     [ 7:0] ram_dout,
    output            ram_oe_n,
    output            ram_wr_n,
    input             ram_wait,
    // cpu bus
    input       [7:0] bus_din,
    output      [7:0] bus_dout,
    input             sel_ram,
    input             wr_n,
    input             rd_n,

    output reg signed [15:0]  pcm55_l,
    output reg signed [15:0]  pcm55_r
);

wire nibble_sel;
wire adv;           // advance to next reading
wire clr_dec;
wire chon;
wire dsign;
wire [15:0] deltax;

wire forward;

wire flag_eos;
wire [20:0] laddr;

wire ram_read;
wire ram_write;
wire ram_busy;
wire ram_stb;



// bit assign for flag
localparam  F_EOS   = 0,
            F_BRDY  = 1,
            F_ZERO  = 2,
            F_BUSY  = 3;

// set addresses with 8b/1b granularity
wire        gran_8b = (acmd_x8_b | acmd_rom_b);
wire [20:0] astart  = (gran_8b) ? {astart_b, 5'h00} : {3'h0, astart_b, 2'h0} ;
wire [20:0] astop   = (gran_8b) ? {aend_b,   5'h1F} : {3'h0, aend_b,   2'h3} ; 
wire [20:0] alimit  = (gran_8b) ? {alimit_b, 5'h1F} : {3'h0, alimit_b, 2'h3} ;



// memory data pipeline
reg   [7:0] mem_L1;
reg   [7:0] mem_L2;
reg   [7:0] mem_L3;
reg   [7:0] mem_L4;

always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        mem_L1 <= 8'h00;
        mem_L2 <= 8'h00;
        mem_L3 <= 8'h00;
        mem_L4 <= 8'h00;
    end else if (cen) begin
        if (!ram_oe_n)
            mem_L1 <= ram_din;
        if (ram_stb)
            mem_L2 <= mem_L1;
        if (sel_ram && !wr_n)
            mem_L3 <= bus_din;
        if (forward) begin
            mem_L3 <= mem_L2;
            mem_L4 <= mem_L2;
        end
    end

assign  bus_dout = mem_L3;
assign  ram_dout = mem_L3;

wire [3:0] din  = !nibble_sel ? mem_L4[7:4] : mem_L4[3:0];

always @(posedge clk) begin
    // flags
    flag[F_BRDY] <= (clr_flag[F_BRDY] | ~mask[F_BRDY]) ? 1'b0 : ~ram_busy;
    flag[F_EOS]  <= (clr_flag[F_EOS]  | ~mask[F_EOS] ) ? 1'b0 : (flag[F_EOS] | flag_eos);
    flag[F_ZERO] <= 1'b0; //(clr_flag[F_ZERO] | ~mask[F_ZERO]) ? 1'b0 : (flag[F_ZERO] | adc_zero);
    flag[F_BUSY] <= clr_flag[F_BUSY] ? 1'b0 : acmd_on_b;
end


jt08_adpcmb_mem u_memc(
    .rst_n       ( rst_n           ),
    .clr         ( acmd_rst_b      ),
    .clk         ( clk             ),
    .cen         ( cen             ),

    .ram_mode    ( acmd_mem_b      ),
    .ram_read    ( ram_read        ),
    .ram_write   ( ram_write & acmd_rec_b ),
    .ram_wait    ( ram_wait        ),

    .ram_busy    ( ram_busy        ),
    .ram_stb     ( ram_stb         ),

    .ram_oe_n    ( ram_oe_n        ),
    .ram_wr_n    ( ram_wr_n        )
);

wire stb_wr = sel_ram & !wr_n;
wire stb_rd = sel_ram & !rd_n;
assign addr = {3'b000, laddr};

jt08_adpcmb_cnt u_cnt(
    .rst_n       ( rst_n           ),
    .clk         ( clk             ),
    .cen         ( cen             ),
    .cen55       ( cen55           ),
    .delta_n     ( adeltan_b       ),
	.acmd_up_b   ( acmd_up_b       ),
    .clr         ( acmd_rst_b      ),
    .on          ( acmd_on_b       ),
    .astart      ( astart          ),
    .aend        ( astop           ),
    .arepeat     ( acmd_rep_b      ),
    .alimit      ( alimit          ),
    .addr        ( laddr           ),
    .nibble_sel  ( nibble_sel      ),
    // Flag control
    .chon        ( chon            ),
    .clr_flag    ( clr_flag[F_EOS] ),
    .flag        ( flag_eos        ),
    .clr_dec     ( clr_dec         ),
    // Memory
    .acmd_ad_b   ( acmd_ad_b       ),
    .stb_wr      ( stb_wr          ),
    .stb_rd      ( stb_rd          ),
    .ram_busy    ( ram_busy        ),
    .ram_stb     ( ram_stb         ),
    .ram_read    ( ram_read        ),
    .ram_write   ( ram_write       ),
    .forward     ( forward         ),
    .adv         ( adv             )
);

wire signed [15:0] pcmdec, pcminter, pcmgain;

jt10_adpcmb u_decoder(
    .rst_n  ( rst_n          ),
    .clk    ( clk            ),
    .cen    ( cen            ),
    .adv    ( adv & cen55    ),
    .data   ( din            ),
    .chon   ( chon           ),
    .clr    ( clr_dec        ),
    .dsign  ( dsign          ),
    .dx     ( deltax         ),
    .pcm    ( pcmdec         )
);

`ifndef NOBINTERPOL
jt08_adpcmb_interpol u_interpol(
    .rst_n  ( rst_n          ),
    .clk    ( clk            ),
    .cen    ( cen            ),
    .cen55  ( cen55          ),
    .adv    ( adv            ),
    .deltan ( adeltan_b      ),
    .dsign  ( dsign          ),
    .deltax ( deltax         ),
    .pcmdec ( pcmdec         ),
    .pcmout ( pcminter       )
);
`else 
assign pcminter = pcmdec;
`endif

jt10_adpcmb_gain u_gain(
    .rst_n  ( rst_n          ),
    .clk    ( clk            ),
    .cen55  ( cen55          ),
    .tl     ( aeg_b          ),
    .pcm_in ( pcminter       ),
    .pcm_out( pcmgain        )
);

always @(posedge clk) if(cen55) begin
    pcm55_l <= alr_b[1] ? pcmgain : 16'd0;
    pcm55_r <= alr_b[0] ? pcmgain : 16'd0;
end

endmodule // jt08_adpcm_drvB
