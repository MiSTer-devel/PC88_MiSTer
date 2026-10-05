//============================================================================
//  PC8801SR - cassette (CMT) playback chain
//
//  Copyright (C) 2026 Yoshiaki Okuyama
//  SPDX-License-Identifier: GPL-2.0-or-later
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

//
// cmt_play - the playback chain in one place: SD slot, format detection, the .t88
// parser where it applies, and the serializer
//
// Kept out of the top level so that a Verilator testbench can run the whole chain.
//
module cmt_play #(
	// clocks in one tick (1/4800 s) minus one
	parameter int TICK_CLK = 4167
)(
	input             clk,
	input             rst_n,

	// transport, from the top level's play_run
	input             run,

	// mount notification (one clock)
	input             mounted,
	input      [63:0] img_size,

	// SD, reaching the host through the cmt_arb arbiter
	output     [31:0] sd_lba,
	output            sd_rd,
	input             sd_ack,
	input       [8:0] sd_buff_addr,
	input       [7:0] sd_buff_dout,
	input             sd_buff_wr,

	// 8251 framing, derived by the top level from the mode the CPU wrote
	input      [15:0] div,
	input       [3:0] data_bits,
	input             parity_en,
	input             parity_odd,
	input       [1:0] stop_bits,

	// outputs
	output            txd,
	output            ser_busy,      // a frame is on the line; the top level masks on this
		// one clock at each frame boundary
	output            ser_load,

	// status
	output            is_t88,
	output            eof,
	output            no_file,
	output            carrier,
	output            t88_done,
	output            t88_bad_tag,
	output            t88_speed_1200
);

wire [7:0] fbyte;
wire       fbyte_valid;
wire       file_ack;      // the "taken" returned to cmt_file
wire       ser_ack;       // cmt_serial's "taken", which is the frame boundary
assign ser_load = ser_ack;

wire [7:0] t88_byte;
wire       t88_valid, t88_fack;


wire mnt_apply;   // a mount or a rewind takes effect in cmt_file

cmt_fmt cmt_fmt_i
(
	.clk(clk),
	.rst_n(rst_n),

	.mounted(mnt_apply),

	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_wr(sd_buff_wr),

	.is_t88(is_t88)
);

cmt_file cmt_file_i
(
	.clk(clk),
	.rst_n(rst_n),

	.run(run),

	.mounted(mounted),
	.img_size(img_size),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_wr(sd_buff_wr),

	.dout(fbyte),
	.dout_valid(fbyte_valid),
	.dout_ack(file_ack),
	.eof(eof),
	.no_file(no_file),
	.mnt_apply(mnt_apply)
);

// The .t88 parser turns GAP, SPACE and MARK into waits; cmt_serial holds txd at mark meanwhile.
cmt_t88 #(.TICK_CLK(TICK_CLK)) cmt_t88_i
(
	.clk(clk),
	.rst_n(rst_n),
	.start(mnt_apply),

	.run(run),

	.fbyte(fbyte),
	.fbyte_valid(fbyte_valid & is_t88),
	.fbyte_ack(t88_fack),
	.eof(eof & is_t88),

	.obyte(t88_byte),
	.obyte_valid(t88_valid),
	.obyte_ack(ser_ack & is_t88),
	.ser_busy(ser_busy),

		// reported only; the rate follows port 30h bit 4
	.speed_1200(t88_speed_1200),
	.carrier(carrier),
	.done(t88_done),
	.bad_tag(t88_bad_tag)
);

// .cmt bypasses the parser.
wire [7:0] ser_byte  = is_t88 ? t88_byte  : fbyte;
wire       ser_valid = is_t88 ? t88_valid : fbyte_valid;
// cmt_file is acknowledged by whichever stage took the byte
assign file_ack = is_t88 ? t88_fack : ser_ack;

cmt_serial cmt_serial_i
(
	.clk(clk),
	.rst_n(rst_n),

	.run(run),

	.div(div),
	.data_bits(data_bits),
	.parity_en(parity_en),
	.parity_odd(parity_odd),
	.stop_bits(stop_bits),

	.din(ser_byte),
	.din_valid(ser_valid),
	.din_ack(ser_ack),

	.txd(txd),
	.busy(ser_busy)
);

endmodule
