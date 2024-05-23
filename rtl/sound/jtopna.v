// OPNA with JT12

module jtopna(
    input           rst,
    input           clk,
    input           cen,
    input   [7:0]   din,
    input   [1:0]   addr,
    input           cs_n,
    input           wr_n,

    output  [7:0]   dout,
    output          irq_n,
    // GPIO
    input   [7:0]   IOA_in,
    input   [7:0]   IOB_in,
    output  [7:0]   IOA_out,
    output  [7:0]   IOB_out,
    output          IOA_oe,
    output          IOB_oe,
    // ADPCM
    output  [17:0]  adpcm_addr,
    output          adpcm_roe,
    input   [7:0]   adpcm_din,
    output          adpcm_wr,
    output  [7:0]   adpcm_dout,
    // Output
    output  signed  [15:0] fm_snd_right,
    output  signed  [15:0] fm_snd_left,
    output          [ 9:0] psg_snd
);

// ADPCM-A
wire [19:0] adpcma_addr;
wire        adpcma_roe_n;   // ADPCM-A ROM output enable
wire  [7:0] adpcma_data;    // Data from RAM
// INTERNAL
wire [12:0] rom_addr;
wire        rden;

// ADPCM-B
wire [23:0] adpcmb_addr;
wire        adpcmb_roe_n;
wire        adpcmb_wr_n;

// assign external pin
assign      adpcm_addr  = adpcmb_addr[17:0];
assign      adpcm_roe   = ~adpcmb_roe_n;
assign      adpcm_wr    = ~adpcmb_wr_n;

// assign internal signal
assign      rom_addr    = adpcma_addr[12:0];
assign      rden        = ~adpcma_roe_n;

// JT08 module
jt08 u_jt08(
    .rst            ( rst          ),
    .clk            ( clk          ),
    .cen            ( cen          ),
    .din            ( din          ),
    .addr           ( addr         ),
    .cs_n           ( cs_n         ),
    .wr_n           ( wr_n         ),

    .dout           ( dout         ),
    .irq_n          ( irq_n        ),
    // YM2203 I/O pins
    .IOA_in         ( IOA_in       ),
    .IOB_in         ( IOB_in       ),
    .IOA_out        ( IOA_out      ),
    .IOB_out        ( IOB_out      ),
    .IOA_oe         ( IOA_oe       ),
    .IOB_oe         ( IOB_oe       ),
    // ADPCM pins
    .adpcma_addr    ( adpcma_addr  ),
    .adpcma_roe_n   ( adpcma_roe_n ),
    .adpcma_data    ( adpcma_data  ),
    .adpcmb_addr    ( adpcmb_addr  ),
    .adpcmb_roe_n   ( adpcmb_roe_n ),
    .adpcmb_din     ( adpcm_din    ),
    .adpcmb_wr_n    ( adpcmb_wr_n  ),
    .adpcmb_dout    ( adpcm_dout   ),
    // Separated output
    .psg_A          (              ),
    .psg_B          (              ),
    .psg_C          (              ),
    .fm_snd_left    ( fm_snd_left  ),
    .fm_snd_right   ( fm_snd_right ),
    // Sound output
    .psg_snd        ( psg_snd      ),
    .snd_left       (              ),
    .snd_right      (              ),
    .snd_sample     (              )
);

RHYTHM_ROM u_rhythm_rom (
    .address    ( rom_addr      ),
    .clock      ( clk           ),
    .rden       ( rden          ),
    .q          ( adpcma_data   )
);

endmodule
