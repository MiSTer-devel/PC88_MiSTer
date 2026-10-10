//============================================================================
//  PC8801SR
//
//  Copyright (C) 2017,2020 Alexey Melnikov
//  Copyright (C) 2020 Puu
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================
module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);
///////// Default values for ports not used in this core /////////

assign {UART_RTS, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_F1 = 0;
wire video24k; // 24kHz or 15kHz video timing, taken at reset
assign VGA_SCALER = 0; // 24kHz, 15kHz: VGA as set in MiSTer.ini (vga_scaler)

assign LED_POWER = 0;
assign BUTTONS = 0;
assign AUDIO_MIX = 0;
assign USER_OUT = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;
assign VGA_DISABLE = 0;
assign UART_TXD = 0;

//////////////////////////////////////////////////////////////////
wire mist_active = |dsk_rd[2:0] || |dsk_wr[2:0];   // before the arbiter, so a waiting disk request still lights it
assign LED_USER  = disk_led;
assign LED_DISK  = {1'b0, mist_active};

wire [1:0] ar = status[2:1];

`include "build_id.v" 
parameter CONF_STR = {
	"PC8801;;",
	"-;",
	"O12,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O34,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"OHJ,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"OOP,Video timing,31kHz,24kHz,15kHz;",
	"-;",
	"O78,Mode,N88V2,N88V1H,N88V1S,N;",
	"O9,Speed,4MHz,8MHz;",
	"-;",
	"S0,D88,FDD0;",
	"S1,D88,FDD1;",
	"S4,CMTT88,Tape;",
	"OE,Tape Record,Off,On;",
	"RF,SYNC FD0;",
	"RG,SYNC FD1;",
	"-;",
	"OA,Basic mode,Basic,Terminal;",
	"OB,Cols,80,40;",
	"OC,Lines,25,20;",
	"OD,Disk boot,Enable,Disable;",
	"-;",
	"OK,Input,Joypad,Mouse;",
	"OLM,Sound Board,Normal(SR),OnBoard(FA/MA+),Add-on (SB2);",
	"OQR,RAM,Fx (SR/FR/FH/FA),Mx (MR/MH/MA/MC),512KB;",
	"-;",
	"R6,Reset;",
	"J,Fire 1,Fire 2;",
	"I,",
	"Tape: recording,",
	"Tape: saved,",
	"Tape: OVERRUN - stopped,",
	"Tape: image full - stopped,",
	"Tape: image changed - stopped,",
	"Tape: no writable image,",
	"Tape: image is read-only,",
	"Tape: not a .t88 image,",
	"Tape: image too small,",
	"Tape: unsupported serial mode;",
	"V,v",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_ram, clk_sys, clk_emu;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_ram),
	.outclk_1(clk_sys),
	.outclk_2(clk_emu),
	.locked(pll_locked)
);

altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk_ram),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);

/////////////////  HPS  ///////////////////////////

wire [63:0] status;
wire  [1:0] buttons;

wire [15:0] joystick_0, joystick_1;

wire  [5:0] joyA = ~{joystick_0[5:4],joystick_0[0],joystick_0[1],joystick_0[2],joystick_0[3]};
wire  [5:0] joyB = ~{joystick_1[5:4],joystick_1[0],joystick_1[1],joystick_1[2],joystick_1[3]};

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
reg  [18:0] ldr_addr;
reg   [7:0] ldr_dout;

wire        ps2_kbd_clk_out;
wire        ps2_kbd_data_out;
wire        ps2_kbd_clk_in;
wire        ps2_kbd_data_in;
wire        ps2_mouse_clk_out;
wire        ps2_mouse_data_out;
wire        ps2_mouse_clk_in;
wire        ps2_mouse_data_in;

wire  [31:0] sd_lba;
wire   [4:0] sd_rd;
wire   [4:0] sd_wr;
// The disk requests and acknowledges, on the core side of cmt_arb.
wire   [3:0] dsk_rd;
wire   [3:0] dsk_wr;
wire   [3:0] dsk_ack;
// The tape image's SD requests (slot 4), before and after cmt_arb.
wire  [31:0] cmt_lba, cmt_host_lba;
wire         cmt_rd, cmt_wr, cmt_ack;
wire   [7:0] cmt_buff_din;
wire         cmt_info_req;
wire   [7:0] cmt_info;
wire         own_disk, own_tape;

wire  [4:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire  [4:0] img_mounted;
wire  [3:0] img_readonly;
wire [63:0] img_size;

wire [65:0] ps2_key;
wire [24:0] ps2_mouse;
wire [64:0] sysrtc;
wire [21:0] gamma_bus;
wire  [7:0] uart1_mode;
wire [31:0] uart1_speed;

hps_io #(.CONF_STR(CONF_STR), .PS2DIV(600), .PS2WE(1), .VDNUM(5)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({en400p}),

	.sd_lba('{sd_lba,sd_lba,sd_lba,sd_lba,cmt_host_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din,cmt_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.info_req(cmt_info_req),
	.info(cmt_info),
 
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ldr_wr),

	.ps2_kbd_clk_out(ps2_kbd_clk_out),
	.ps2_kbd_data_out(ps2_kbd_data_out),
	.ps2_kbd_clk_in(ps2_kbd_clk_in),
	.ps2_kbd_data_in(ps2_kbd_data_in),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),
	
	.RTC(sysrtc),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

/////////////////  RESET  /////////////////////////

reg reset_n = 0;
always @(posedge clk_sys) begin
	reg old_download;
	
	old_download <= ioctl_download;
	if(~old_download & ioctl_download) reset_n <= 1;
end

wire reset = buttons[1] | status[6];
///////////////////////////////////////////////////

wire [1:0] basicmode=~status[8:7];
wire clkmode=status[9];
wire cBT		=~status[10];
wire	c40C	=status[11];
wire	c20L	=status[12];
wire	cDisk	=status[13];
wire	MTSAVE	=1;
wire [1:0]FDsync=status[16:15];
wire	cInDev	=status[20];
wire [1:0]cSB	=status[22:21];
wire [1:0]cVtiming=status[25:24];

assign CLK_VIDEO = clk_ram;
assign AUDIO_S = 1;

wire disk_led;

wire [7:0] red, green, blue;
wire HSync, VSync, ce_pix, vid_de;

//////////////////  CASSETTE (CMT) INPUT  ///////////////////

// The tape reaches the 8251 as an asynchronous serial line, either from an image in the
// Tape slot or from the ADC, where only the tone is decoded.
localparam CLK_SYS_HZ = 20000000;

wire       cmt_mton;
wire [1:0] cmt_bs;
wire [7:0] cmt_mode;   // 8251 mode written by the CPU

// Port 30h is written in the CPU clock domain. Sample the bits twice before they are used.
reg [2:0] cmt_port30_s1 = 0, cmt_port30_s = 0;
always @(posedge clk_sys) begin
	cmt_port30_s1 <= {cmt_mton, cmt_bs};
	cmt_port30_s  <= cmt_port30_s1;
end

wire tape_motor = cmt_port30_s[2];      // 30h bit3
wire tape_sel   = ~cmt_port30_s[1];     // 30h bit5: 0 selects the cassette, 1 RS-232C
wire tape_1200  = cmt_port30_s[0];      // 30h bit4: 1 = 1200 baud, 0 = 600

wire tape_on  = tape_sel;
wire tape_run = tape_on & tape_motor;

wire tape_level;
ltc2308_tape #(.CLK_RATE(CLK_SYS_HZ)) tape_adc
(
	.reset(1'b0),
	.clk(clk_sys),

	.ADC_BUS(ADC_BUS),

	.dout(tape_level)
);

wire tape_rxd;
cmt_demod #(.CLK_HZ(CLK_SYS_HZ)) tape_demod
(
	.clk(clk_sys),
	.reset(1'b0),

	.level(tape_level),
	.rxd(tape_rxd)
);

// Tape image playback (SD slot 4 -> 8251 RxD) and recording (8251 TxD -> SD slot 4).
wire cmt_rst_n = reset_n & ~reset;
wire cmt_rec_on = status[14];   // OSD "Tape Record"

// The frame shape comes from the mode the CPU wrote, so the image is sent the way the
// program expects to receive it.
wire [3:0] cmt_data_bits  = 4'd5 + {2'b0, cmt_mode[5:4]};
wire       cmt_parity_en  = cmt_mode[3];
wire       cmt_parity_odd = ~cmt_mode[2];
// e8251 counts stop bits in halves and its receiver checks only one, so round up.
wire [1:0] cmt_stop_bits  = cmt_mode[1] ? 2'd2 : 2'd1;
// Only the x16 factor is supported: x1 cannot reach 1200 baud with an 11-bit divisor,
// and at x64 the receiver samples at the end of the start bit.
wire cmt_mode_ok = (cmt_mode[7:6] == 2'b10);

// Must match SYSCLK in PC88MiSTer.vhd; CMT_DIV_9600 is the core's own RS-232C divisor.
localparam int CMT_SYSCLK_HZ = CLK_SYS_HZ;
localparam int CMT_OVERSAMP  = 16;
localparam [10:0] CMT_DIV_9600 = 11'(CMT_SYSCLK_HZ/(2*CMT_OVERSAMP*9600) - 1);
localparam [10:0] CMT_DIV_1200 = 11'(CMT_SYSCLK_HZ/(2*CMT_OVERSAMP*1200) - 1);
localparam [10:0] CMT_DIV_600  = 11'(CMT_SYSCLK_HZ/(2*CMT_OVERSAMP*600)  - 1);

// img_mounted can stay high for a while; cmt_file wants a single-clock pulse.
// MiSTer signals an eject with a size of 0. A reset keeps the image in (cmt_file rewinds it).
reg cmt_mnt_d   = 1'b0;
reg cmt_present = 1'b0;
wire cmt_mnt_pulse = img_mounted[4] & ~cmt_mnt_d;
always @(posedge clk_sys) begin
	if (!cmt_rst_n) cmt_mnt_d <= 1'b0;
	else            cmt_mnt_d <= img_mounted[4];
	if (cmt_rst_n && cmt_mnt_pulse) cmt_present <= |img_size;
end

wire cmt_txd, cmt_ser_busy, cmt_cap_busy;
wire cmt_play_run, cmt_rec_run, cmt_rec_active;

// Playback and recording are exclusive; Tape Record selects which one the motor runs.
cmt_deck cmt_deck_i
(
	.clk(clk_sys),
	.rst_n(cmt_rst_n),
	.mton(tape_motor),
	.cmt_sel(tape_on),
	.rec_enable(cmt_rec_on),
	.file_mounted(cmt_present),
	.play_run(cmt_play_run),
	.tape_run(),
	.rec_run(cmt_rec_run),
	.rec_active(cmt_rec_active)
);

// The serializer finishes the byte it is sending after the motor stops, and the capture
// finishes the byte it is receiving, so the line and the USART clock selection stay with
// the tape until that frame is through. While recording, the line idles at mark.
wire cmt_line_hold = cmt_play_run | cmt_rec_run | cmt_ser_busy | cmt_cap_busy;

// Rate and shape are taken only while no frame is being sent; the CPU may rewrite them at
// any time. A change while frames follow each other waits until the line is idle, so the
// image and the 8251's clock change together.
reg       cmt_baud_hold  = 1'b0;
reg [3:0] cmt_fmt_bits_h = 4'd8;
reg       cmt_fmt_pen_h  = 1'b0;
reg       cmt_fmt_podd_h = 1'b0;
reg [1:0] cmt_fmt_stop_h = 2'd2;
always @(posedge clk_sys) begin
	if (!cmt_rst_n) begin
		cmt_baud_hold  <= 1'b0;
		cmt_fmt_bits_h <= 4'd8;
		cmt_fmt_pen_h  <= 1'b0;
		cmt_fmt_podd_h <= 1'b0;
		cmt_fmt_stop_h <= 2'd2;
	end
	else if (!cmt_ser_busy) begin
		cmt_baud_hold  <= tape_1200;
		cmt_fmt_bits_h <= cmt_data_bits;
		cmt_fmt_pen_h  <= cmt_parity_en;
		cmt_fmt_podd_h <= cmt_parity_odd;
		cmt_fmt_stop_h <= cmt_stop_bits;
	end
end

// No frame starts on the clock the held values change.
wire cmt_cfg_new = (tape_1200 != cmt_baud_hold) | (cmt_data_bits != cmt_fmt_bits_h) |
                   (cmt_parity_en != cmt_fmt_pen_h) | (cmt_parity_odd != cmt_fmt_podd_h) |
                   (cmt_stop_bits != cmt_fmt_stop_h);
wire cmt_run      = cmt_play_run & cmt_mode_ok & ~(~cmt_ser_busy & cmt_cfg_new);

// clocks per bit, minus one: (D+1) x 2 x 16
wire [10:0] cmt_com_div = (cmt_line_hold & cmt_mode_ok) ? (cmt_baud_hold ? CMT_DIV_1200 : CMT_DIV_600)
                                                       : CMT_DIV_9600;
wire [15:0] cmt_div     = ((16'(cmt_com_div) + 16'd1) << 5) - 16'd1;

// The USART clock follows the image while it holds the line, otherwise the ADC tape
// while its motor runs, otherwise the RS-232C rate as before.
wire [1:0] cmt_clk_sel = (cmt_line_hold & cmt_mode_ok) ? (cmt_baud_hold ? 2'b10 : 2'b01)
                       : tape_run                      ? (tape_1200     ? 2'b10 : 2'b01)
                       : 2'b00;

// With no image mounted and Tape Record off this is the ADC path exactly as before. A
// mounted image idles at mark, and ejecting it hands the line back to the ADC once neither
// playback nor recording holds it.
wire cmt_line_mark = cmt_present & tape_on;
wire cmt_rxd = cmt_line_hold ? cmt_txd : cmt_line_mark ? 1'b1 : tape_run ? tape_rxd : 1'b0;

// diskemu takes the shared sd_buff_wr without looking at its ack, so tape and disk
// transfers must not overlap. cmt_arb lets one side at a time through to the host.
cmt_arb cmt_arb_i
(
	.clk(clk_sys),
	.rst_n(cmt_rst_n),

	.dsk_rd(dsk_rd),
	.dsk_wr(dsk_wr),
	.dsk_ack(dsk_ack),

	.tap_rd(cmt_rd),
	.tap_wr(cmt_wr),
	.tap_ack(cmt_ack),
	.tap_lba(cmt_lba),
	.host_lba(cmt_host_lba),

	.host_rd(sd_rd),
	.host_wr(sd_wr),
	.host_ack(sd_ack),

	.own_disk(own_disk),
	.own_tape(own_tape)
);

wire [31:0] cmt_play_lba;
wire        cmt_play_rd, cmt_play_ack;

cmt_play #(.TICK_CLK(CMT_SYSCLK_HZ/4800)) cmt_play_i
(
	.clk(clk_sys),
	.rst_n(cmt_rst_n),

	.run(cmt_run),

	.mounted(cmt_mnt_pulse),
	.img_size(img_size),

	.sd_lba(cmt_play_lba),
	.sd_rd(cmt_play_rd),
	.sd_ack(cmt_play_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_wr(sd_buff_wr & own_tape),

	.div(cmt_div),
	.data_bits(cmt_fmt_bits_h),
	.parity_en(cmt_fmt_pen_h),
	.parity_odd(cmt_fmt_podd_h),
	.stop_bits(cmt_fmt_stop_h),

	.txd(cmt_txd),
	.ser_busy(cmt_ser_busy),
	.ser_load(),

	.is_t88(),
	.eof(),
	.no_file(),
	.carrier(),
	.t88_done(),
	.t88_bad_tag(),
	.t88_speed_1200()
);

// Recording: the 8251's transmit line is captured byte by byte and written to the mounted
// .t88 as DATA blocks. cmt_rec also merges the playback requests into the one SD port.
wire       cmt_txd_8251;
wire       cmt_ev_req;
wire [3:0] cmt_ev_code;

cmt_rec #(.TICK_CLK(CMT_SYSCLK_HZ/4800), .FLUSH_CLK(CMT_SYSCLK_HZ)) cmt_rec_i
(
	.clk(clk_sys),
	.rst_n(cmt_rst_n),

	.txd(cmt_txd_8251),
	.div(cmt_div),
	.data_bits(cmt_fmt_bits_h),
	.parity_en(cmt_fmt_pen_h),
	.parity_odd(cmt_fmt_podd_h),
	.cap_busy(cmt_cap_busy),

	.rec_run(cmt_rec_run & cmt_mode_ok),
	.rec_active(cmt_rec_active),
	.rec_enable(cmt_rec_on),
	.speed_1200(cmt_baud_hold),
	.mode_ok(cmt_mode_ok),

	.mounted(cmt_mnt_pulse),
	.img_size(img_size),
	.img_ro(img_readonly[0]),

	.play_lba(cmt_play_lba),
	.play_rd(cmt_play_rd),
	.play_ack(cmt_play_ack),

	.sd_lba(cmt_lba),
	.sd_rd(cmt_rd),
	.sd_wr(cmt_wr),
	.sd_ack(cmt_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_wr(sd_buff_wr & own_tape),
	.sd_buff_din(cmt_buff_din),

	.ev_req(cmt_ev_req),
	.ev_code(cmt_ev_code)
);

// INFO_BASE is the position of the first tape line in the "I," list of CONF_STR.
cmt_ev #(.INFO_BASE(8'd1)) cmt_ev_i
(
	.clk(clk_sys),
	.rst_n(cmt_rst_n),
	.ev_req(cmt_ev_req),
	.ev_code(cmt_ev_code),
	.info_req(cmt_info_req),
	.info(cmt_info)
);

PC88MiSTer PC88_top
(
	.clk21m(clk_sys),
	.rclk(clk_ram),
	.emuclk(clk_emu),
	.plllocked(pll_locked),
	
	.sysrtc(sysrtc),

	.LOADER_ADR(ldr_addr),
	.LOADER_WDAT(ldr_dout),
	.LOADER_OE((ioctl_download | ldr_wr) & ~ldr_done),
	.LOADER_WR(ldr_wr),
	.LOADER_ACK(ldr_ack),
	.LOADER_DONE(ldr_done),
	.RAMTYPE(status[27:26]),

	.pMemCke(SDRAM_CKE),
	.pMemCs_n(SDRAM_nCS),
	.pMemRas_n(SDRAM_nRAS),
	.pMemCas_n(SDRAM_nCAS),
	.pMemWe_n(SDRAM_nWE),
	.pMemUdq(SDRAM_DQMH),
	.pMemLdq(SDRAM_DQML),
	.pMemBa1(SDRAM_BA[1]),
	.pMemBa0(SDRAM_BA[0]),
	.pMemAdr(SDRAM_A),
	.pMemDat(SDRAM_DQ),

	.pPs2Clkin(ps2_kbd_clk_out),
	.pPs2Clkout(ps2_kbd_clk_in),
	.pPs2Datin(ps2_kbd_data_out),
	.pPs2Datout(ps2_kbd_data_in),

	.ps2_mouse(ps2_mouse),

	.pJoyA(joyA),
	.pJoyB(joyB),

	.mist_mounted(img_mounted[3:0]),
	.mist_readonly(img_readonly),
	.mist_imgsize(img_size),

	.mist_lba(sd_lba),
	.mist_rd(dsk_rd),
	.mist_wr(dsk_wr),
	.mist_ack({dsk_ack[3:2], |dsk_ack[1:0], |dsk_ack[1:0]}),

	.mist_buffaddr(sd_buff_addr),
	.mist_buffdout(sd_buff_dout),
	.mist_buffdin(sd_buff_din),
	.mist_buffwr(sd_buff_wr & own_disk),

	.pFd_sync(FDsync),

	.pLed(disk_led),
	.pDip({clkmode,2'b0,cDisk,c20L,c40C,MTSAVE,cBT,basicmode}),
	.pCoreConfig({cVtiming,cSB,cInDev}),
	.pPsw(2'b11),

	.pVideoR(red),
	.pVideoG(green),
	.pVideoB(blue),
	.pVideoHS(HSync),
	.pVideoVS(VSync),
	.pVideoEN(vid_de),
	.pVideoClk(ce_pix),
	.pVideo24k(video24k),

	.pSndL(AUDIO_L),
	.pSndR(AUDIO_R),

	.cmt_mton(cmt_mton),
	.cmt_bs(cmt_bs),
	.cmt_clk_sel(cmt_clk_sel),
	.cmt_mode(cmt_mode),
	.pCOM_RxD(cmt_rxd),
	.pCOM_TxD(cmt_txd_8251),

	.rstn(reset_n & ~reset)
);

wire ldr_ack;
reg ldr_wr = 0;
reg ldr_end = 0;
reg ldr_done = 0;
always @(posedge clk_sys) begin
	reg old_ack, old_download;

	old_download <= ioctl_download;
	old_ack <= ldr_ack;

	if(~old_ack & ldr_ack & ldr_wr) ldr_wr <= 0;
	// The address and data are held until the write is acknowledged: at the end
	// of the download hps_io moves ioctl_addr on without waiting for ioctl_wait.
	if(ioctl_wr & ~ldr_done) begin
		ldr_wr <= 1;
		ldr_addr <= ioctl_addr[18:0];
		ldr_dout <= ioctl_dout;
	end

	// Done only when the last write is acknowledged. Until then LOADER_OE keeps
	// the loader on the SDRAM port, so the last byte is not lost.
	if(old_download & ~ioctl_download) ldr_end <= 1;
	if(ldr_end & ~ldr_wr & ~ioctl_wr) ldr_done <= 1;
end


//////////////////   SD LED   ///////////////////
// reg sd_act;

always @(posedge clk_sys) begin
	reg old_mosi, old_miso;
	integer timeout = 0;

	old_mosi <= SD_MOSI;
	old_miso <= SD_MISO;

	// sd_act <= 0;
	if(timeout < 1000000) begin
		timeout <= timeout + 1;
		// sd_act <= 1;
	end

	if((old_mosi ^ SD_MOSI) || (old_miso ^ SD_MISO)) timeout <= 0;
end

////////////////////////////  VIDEO  ////////////////////////////////////


assign VGA_SL = sl[1:0];
reg en400p = 0;
always @(posedge CLK_VIDEO) en400p <= (HDMI_HEIGHT == 1080 &&  !scale);

wire vga_de;

video_freak video_freak
(
    .*,
    .VGA_DE_IN(vga_de),
    .ARX((!ar) ? 12'd16 : (ar - 1'd1)),
    .ARY((!ar) ? 12'd10 : 12'd0),
    .CROP_SIZE((en400p & ~video24k) ? 10'd400 : 10'd0),
    .CROP_OFF(0),
    .SCALE(status[4:3])
);


wire [2:0] scale = status[19:17];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

// wire freeze = 0;
wire freeze_sync;

assign CE_PIXEL=ce_pix;

gamma_fast gamma
(
    .clk_vid(CLK_VIDEO),
    .ce_pix(CE_PIXEL),

    .gamma_bus(gamma_bus),

    .HSync(HSync),
    .VSync(VSync),
    .DE(vid_de),
    .RGB_in( {red,green,blue}),
   

    .HSync_out(VGA_HS),
    .VSync_out(VGA_VS),
    .DE_out(vga_de),
    .RGB_out({VGA_R,VGA_G,VGA_B})
);

endmodule
