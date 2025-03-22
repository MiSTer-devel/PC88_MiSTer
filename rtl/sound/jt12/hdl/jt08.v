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

// YM2608 wrapper
// Clock enabled at 7.5 - 8.5MHz

module jt08(
    input           rst,        // rst should be at least 6 clk&cen cycles long
    input           clk,        // CPU clock
    input           cen,        // optional clock enable, if not needed leave as 1'b1
    input   [7:0]   din,
    input   [1:0]   addr,
    input           cs_n,
    input           wr_n,
    input           rd_n,

    output  [7:0]   dout,
    output          irq_n,
    // I/O pins used by YM2608 embedded YM2149 chip
    input   [7:0]   IOA_in,
    input   [7:0]   IOB_in,
    output  [7:0]   IOA_out,
    output  [7:0]   IOB_out,
    output          IOA_oe,
    output          IOB_oe,
    // ADPCM pins
    output  [19:0]  adpcma_addr,
    output          adpcma_roe_n, // ADPCM-A ROM output enable
    input   [7:0]   adpcma_data,  // Data from ROM
    output  [23:0]  adpcmb_addr,  // real hardware has 9 pins multiplexed through PMPX pin
    output          adpcmb_roe_n, // ADPCM-B RAM output enable
    input   [7:0]   adpcmb_din,
    output          adpcmb_wr_n,  // ADPCM-B RAM write strobe
    output  [7:0]   adpcmb_dout,
    // Separated output
    output          [ 7:0] psg_A,
    output          [ 7:0] psg_B,
    output          [ 7:0] psg_C,
    output  signed  [15:0] fm_snd_right,
    output  signed  [15:0] fm_snd_left,
    // combined output
    output          [ 9:0] psg_snd,
    output  signed  [15:0] snd_right,
    output  signed  [15:0] snd_left,
    output          snd_sample
);

// Uses 6 FM channels, ADPCM-A, ADPCM-B
jt12_top #(
    .use_lfo(1),.use_ssg(1), .num_ch(6), .use_pcm(0), .use_adpcm(2),
    .JT49_COMP(3'd0),.JT49_DIV(3),.use_chipid(1) )
u_jt12(
    .rst            ( rst          ),        // rst should be at least 6 clk&cen cycles long
    .clk            ( clk          ),        // CPU clock
    .cen            ( cen          ),        // optional clock enable, it not needed leave as 1'b1
    .din            ( din          ),
    .addr           ( addr         ),
    .cs_n           ( cs_n         ),
    .wr_n           ( wr_n         ),
    .rd_n           ( rd_n         ),

    .dout           ( dout         ),
    .irq_n          ( irq_n        ),
    // ADPCM pins
    .adpcma_addr    ( adpcma_addr  ),
    .adpcma_bank    (              ),
    .adpcma_roe_n   ( adpcma_roe_n ), // ADPCM-A ROM output enable
    .adpcma_data    ( adpcma_data  ), // Data from ROM
    .adpcmb_addr    ( adpcmb_addr  ), // real hardware has 9 pins multiplexed through PMPX pin
    .adpcmb_roe_n   ( adpcmb_roe_n ), // ADPCM-B RAM output enable
    .adpcmb_data    ( adpcmb_din   ), // Data from RAM
    .adpcmb_wr_n    ( adpcmb_wr_n  ), // ADPCM-B RAM write strobe
    .adpcmb_dout    ( adpcmb_dout  ),
    // Separated output
    .psg_A          ( psg_A        ),
    .psg_B          ( psg_B        ),
    .psg_C          ( psg_C        ),
    .psg_snd        ( psg_snd      ),
    .fm_snd_left    ( fm_snd_left  ), // FM+ADPCM
    .fm_snd_right   ( fm_snd_right ), // FM+ADPCM
    .adpcmA_l       (              ),
    .adpcmA_r       (              ),
    .adpcmB_l       (              ),
    .adpcmB_r       (              ),
    // YM2203 I/O pins, only input supported
    .IOA_in         ( IOA_in       ),
    .IOB_in         ( IOB_in       ),
    .IOA_out        ( IOA_out      ),
    .IOB_out        ( IOB_out      ),
    .IOA_oe         ( IOA_oe       ),
    .IOB_oe         ( IOB_oe       ),
    .debug_bus      ( 8'd0         ),
    // Sound output
    .snd_right      ( snd_right    ),
    .snd_left       ( snd_left     ),
    .snd_sample     ( snd_sample   ),
    .ch_enable      ( 6'b111111    ),
    // unused pins
    .en_hifi_pcm    ( 1'b0         ), // used only on YM2612 mode
    .debug_view     (              )
);

endmodule // jt08
